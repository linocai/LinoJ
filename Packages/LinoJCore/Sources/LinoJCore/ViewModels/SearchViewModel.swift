// SearchViewModel.swift
// Plan P3.7 唯一实体。驱动 macOS Search palette / iOS Search sheet。
//
// 设计要点：
//   - VM 不缓存 @Model 引用，只缓存 ID（ResultItem 全部用 UUID / QuickAction 枚举包装）。
//     原因：@Model 实例非 Sendable，未来若把 search 移到 background actor 会爆 strict
//     concurrency；用 UUID 既 Sendable 又方便 Equatable / Hashable。
//   - 路由：vm 直接持有 TabRouter 引用。openFirst() / open(_:) 触发 router.current = .xxx 切 tab。
//     W3：精确定位到某个 bubble / day / project detail 通过 router.pending* 信号实现
//     （open(.todo) 设 pendingTodoID → 目标屏 scrollTo；open(.event) 设 pendingEventDate →
//     CalendarView.focus(on:)；open(.project) 设 pendingProjectID → CompanyView push path）。
//     另一种选项是 callback 注入，但 router 在 @MainActor 链里 + 已是单例 + 已被 QuickAdd 等
//     共享，直接持有最简洁。
//   - debounce：query 的 didSet 启动一个 Task，sleep 100ms 后 performSearch。再次输入会取消
//     上一个未触发的任务。不用 Combine 因为 @Observable 没原生 publisher，Task 路径足够简单。
//   - 性能：query 非空时遍历所有 Todo / Event / Project 做 case-insensitive contains 比对。
//     100 条数据 << 50ms 验收（plan P3.7），无需 FTS / Spotlight。

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class SearchViewModel {

    // MARK: - Nested types

    /// 搜索范围 chip。
    public enum Scope: Hashable, CaseIterable, Sendable {
        case all
        case todos
        case events
        case projects
    }

    /// 单条结果。用 UUID 引用 @Model 实例 —— Sendable + 跨 actor 安全。
    public enum ResultItem: Hashable, Sendable {
        case todo(UUID)
        case event(UUID)
        case project(UUID)
        case quickAction(QuickAction)
    }

    /// 命令型快捷动作（query 为空时显示在 Quick actions group）。
    public enum QuickAction: Hashable, Sendable {
        case newTodo
        case newEvent
        case newProject
        case jumpTo(AppTab)
    }

    // MARK: - Stored

    private let context: ModelContext
    private let router: TabRouter

    /// 当前正在 debounce 等待中的搜索任务。下次输入会 cancel 它。
    private var debounceTask: Task<Void, Never>?

    /// 当前查询字符串。setter 启动 debounce。
    public var query: String = "" {
        didSet {
            scheduleDebouncedSearch()
        }
    }

    /// 当前 scope chip 选中项。setter 立即（无 debounce）重算结果 —— UX 上用户点 chip 应即时反馈。
    public var scope: Scope = .all {
        didSet {
            performSearch()
        }
    }

    /// 分组结果，按 group label 顺序排列。每组至少 1 项；空组不出现。
    public var grouped: [(group: String, items: [ResultItem])] = []

    /// 最近一次搜索耗时（毫秒，向上取整）。用于 footer 的 "X results in Y ms"。
    public var elapsedMs: Int = 0

    // MARK: - Init

    public init(context: ModelContext, router: TabRouter) {
        self.context = context
        self.router = router
        // 初次构造时立即跑一次 —— 空 query 会显示 Quick actions group。
        performSearch()
    }

    // MARK: - Debounce

    private func scheduleDebouncedSearch() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            // plan: 100ms debounce
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            self?.performSearch()
        }
    }

    // MARK: - Search

    /// 执行一次搜索 + 装配 grouped + 计 elapsedMs。同步调用。
    public func performSearch() {
        let clock = ContinuousClock()
        let start = clock.now

        defer {
            let elapsed = clock.now - start
            // 转毫秒，向上取整（< 1ms 也至少显示 0ms，但用 max(0, ...) 即可）。
            // .components.seconds + .attoseconds，attoseconds = 1e-18 s。
            // 简单做法：转 Double 秒 × 1000。
            let comps = elapsed.components
            let secs = Double(comps.seconds) + Double(comps.attoseconds) / 1e18
            self.elapsedMs = max(0, Int((secs * 1000.0).rounded(.up)))
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            // 空 query 显示 Quick actions + Jump to。
            grouped = emptyQueryGroups()
            return
        }

        // 全量 fetch 后内存过滤。100 条数据下远低于 50ms 验收线。
        // FetchDescriptor 不带 predicate —— SwiftData 的 string predicate 在
        // case-insensitive contains 上跨平台行为不稳，用内存 lowercased contains 更可控。
        let needle = trimmed.lowercased()

        let allTodos = (try? context.fetch(FetchDescriptor<Todo>())) ?? []
        let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let allProjects = (try? context.fetch(FetchDescriptor<Project>())) ?? []

        let matchedTodos = allTodos.filter {
            $0.title.lowercased().contains(needle)
        }
        let matchedEvents = allEvents.filter {
            $0.title.lowercased().contains(needle)
                || $0.location.lowercased().contains(needle)
        }
        let matchedProjects = allProjects.filter {
            $0.title.lowercased().contains(needle)
                || $0.intro.lowercased().contains(needle)
        }

        var out: [(group: String, items: [ResultItem])] = []

        let includeTodos = (scope == .all || scope == .todos)
        let includeEvents = (scope == .all || scope == .events)
        let includeProjects = (scope == .all || scope == .projects)

        if includeTodos && !matchedTodos.isEmpty {
            out.append((
                group: "Todos",
                items: matchedTodos.map { .todo($0.id) }
            ))
        }
        if includeEvents && !matchedEvents.isEmpty {
            out.append((
                group: "Events",
                items: matchedEvents.map { .event($0.id) }
            ))
        }
        if includeProjects && !matchedProjects.isEmpty {
            out.append((
                group: "Projects",
                items: matchedProjects.map { .project($0.id) }
            ))
        }

        grouped = out
    }

    /// query 为空时的 group：Quick actions + Jump to。
    private func emptyQueryGroups() -> [(group: String, items: [ResultItem])] {
        let quickActions: [ResultItem] = [
            .quickAction(.newTodo),
            .quickAction(.newEvent),
            .quickAction(.newProject)
        ]
        let jumpTo: [ResultItem] = AppTab.allCases.map { .quickAction(.jumpTo($0)) }

        // 按 scope 过滤：scope != .all 时 Quick actions 仍展示（命令型），但 Jump to 也保留。
        // 视觉上 Quick actions 始终是 entry 点，不被 scope 过滤掉。
        return [
            (group: "Quick actions", items: quickActions),
            (group: "Jump to", items: jumpTo)
        ]
    }

    // MARK: - Open

    /// 打开 grouped 中的第一个结果。空结果 → noop。
    public func openFirst() {
        guard let firstGroup = grouped.first, let first = firstGroup.items.first else {
            return
        }
        open(first)
    }

    /// 根据 ResultItem 触发对应路由 / 动作。
    /// 调用方负责在调用前后关闭 search palette（router.showSearch = false）。
    public func open(_ item: ResultItem) {
        switch item {
        case .todo(let id):
            // W3：反查 Todo，按 scope 切到 Personal 或 Company，并设 router.pendingTodoID
            // 让目标屏（ScrollViewReader）滚动到该 bubble（被 filter 隐藏则目标屏先重置 filter）。
            let descriptor = FetchDescriptor<Todo>(predicate: #Predicate { $0.id == id })
            if let todo = (try? context.fetch(descriptor))?.first {
                router.current = (todo.scope == .personal) ? .personal : .company
                router.pendingTodoID = todo.id
            } else {
                router.current = .main
            }
            router.showSearch = false

        case .event(let id):
            // W3：反查 Event 拿 start，切 Calendar tab 并设 pendingEventDate（= startOfDay）
            // 让 CalendarView 定位到那天（CalendarViewModel.focus(on:)）。pendingEventID 预留高亮，
            // 当前各 VM 无承载字段，本期不做高亮（写进变更日志）。
            let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == id })
            router.current = .calendar
            if let event = (try? context.fetch(descriptor))?.first {
                router.pendingEventDate = Calendar.current.startOfDay(for: event.start)
                router.pendingEventID = event.id
            }
            router.showSearch = false

        case .project(let id):
            // W3：切 Company tab 并设 pendingProjectID。CompanyView 监听非 nil 时把它 append
            // 进 NavigationStack path（path 是 [UUID]，destination 已按 UUID 解析 ProjectDetail），
            // 直接 push 到该 ProjectDetail，消费后清回 nil。
            router.current = .company
            router.pendingProjectID = id
            router.showSearch = false

        case .quickAction(let action):
            handle(action)
        }
    }

    /// 处理 QuickAction：翻 router flag / 切 tab，并关闭 search。
    private func handle(_ action: QuickAction) {
        switch action {
        case .newTodo:
            router.showSearch = false
            router.quickAddDefaultKind = .todo
            router.showQuickAdd = true
        case .newEvent:
            router.showSearch = false
            router.quickAddDefaultKind = .event
            router.showQuickAdd = true
        case .newProject:
            router.showSearch = false
            router.quickAddDefaultKind = .project
            router.showQuickAdd = true
        case .jumpTo(let tab):
            router.current = tab
            router.showSearch = false
        }
    }

    // MARK: - Helpers (for View layer)

    /// 给 View 用：把 ResultItem 转成可渲染的 display info（避免 View 直接 fetch）。
    /// View 在渲染每行前调一次。
    public func display(for item: ResultItem) -> DisplayInfo {
        switch item {
        case .todo(let id):
            let descriptor = FetchDescriptor<Todo>(predicate: #Predicate { $0.id == id })
            if let todo = (try? context.fetch(descriptor))?.first {
                let hint: String
                if let project = todo.project {
                    hint = "\(todo.scope == .personal ? "Personal" : "Company") · \(project.title)"
                } else {
                    hint = "\(todo.scope == .personal ? "Personal" : "Company") · Standalone"
                }
                return DisplayInfo(
                    iconSystemName: "checkmark.square",
                    title: todo.title,
                    hint: hint,
                    urgent: todo.urgency == .urgent
                )
            }
            return DisplayInfo(iconSystemName: "checkmark.square", title: "—", hint: nil, urgent: false)

        case .event(let id):
            let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == id })
            if let event = (try? context.fetch(descriptor))?.first {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE · h:mm a"
                let when = formatter.string(from: event.start)
                let hint = event.location.isEmpty ? when : "\(when) · \(event.location)"
                return DisplayInfo(
                    iconSystemName: "calendar",
                    title: event.title,
                    hint: hint,
                    urgent: false
                )
            }
            return DisplayInfo(iconSystemName: "calendar", title: "—", hint: nil, urgent: false)

        case .project(let id):
            let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })
            if let project = (try? context.fetch(descriptor))?.first {
                // F2：用 project.memberCount（冗余 Int 字段）避免 to-many fault 不稳定。
                let hint = "\((project.todos ?? []).count) todos · \((project.events ?? []).count) events · \(project.memberCount) members"
                return DisplayInfo(
                    iconSystemName: "folder",
                    title: project.title,
                    hint: hint,
                    urgent: false
                )
            }
            return DisplayInfo(iconSystemName: "folder", title: "—", hint: nil, urgent: false)

        case .quickAction(let action):
            switch action {
            case .newTodo:
                return DisplayInfo(iconSystemName: "checkmark.square", title: "New todo…", hint: "⌘N", urgent: false)
            case .newEvent:
                return DisplayInfo(iconSystemName: "calendar", title: "New event…", hint: "⌘⇧E", urgent: false)
            case .newProject:
                return DisplayInfo(iconSystemName: "folder", title: "New project…", hint: "⌘⇧P", urgent: false)
            case .jumpTo(let tab):
                let label: String
                let shortcut: String
                switch tab {
                case .main:        label = "Jump to Main";        shortcut = "⌘1"
                case .personal:    label = "Jump to Personal";    shortcut = "⌘2"
                case .company:     label = "Jump to Company";     shortcut = "⌘3"
                case .calendar:    label = "Jump to Calendar";    shortcut = "⌘4"
                case .inspiration: label = "Jump to Inspiration"; shortcut = "⌘5"
                }
                return DisplayInfo(
                    iconSystemName: "arrow.right",
                    title: label,
                    hint: shortcut,
                    urgent: false
                )
            }
        }
    }

    /// 给 View 的渲染包。
    public struct DisplayInfo: Sendable, Equatable {
        public let iconSystemName: String
        public let title: String
        public let hint: String?
        public let urgent: Bool
    }

    /// 给 View 的便利：总结果数（不算 group header），用于 footer "X results in Y ms"。
    public var totalCount: Int {
        grouped.reduce(0) { $0 + $1.items.count }
    }

    /// 给 View 的便利：扁平化所有 ResultItem，用于 ↑↓ 高亮跨 group 移动。
    public var flatItems: [ResultItem] {
        grouped.flatMap { $0.items }
    }
}
