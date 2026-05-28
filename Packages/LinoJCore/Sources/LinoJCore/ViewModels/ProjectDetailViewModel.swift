// ProjectDetailViewModel.swift
// Project detail 视图的 ViewModel —— 围绕一个具体 Project 暴露派生数据：
//   - urgent / normal / completed todos（仅本 project 内的 work todos）
//   - openCount / urgentCount / doneCount
//   - linkedEventsByDay：本 project 的 events，按 startOfDay 分组并按 start 升序
//   - membersSinceText：例如 "3 members · since Apr 12"
//
// 数据流照搬 Personal/Company/Calendar ViewModel：`@Observable @MainActor`，
// init 拿 (project, context)，computed property 用 fetch + 过滤；`refresh()` 触发重算。
//
// 设计选择：
//   - `project` 暴露为 public let，方便 View 直接读 title / intro / notes / tag / members；
//   - 不通过 project.todos / project.events 直接读关系数组 —— 因为这些数组的
//     Observation 通知颗粒不可靠（mutate Todo.done 后不一定立刻让 project.todos
//     重新触发），改成 fetch 全部 Todo / Event 后按 project.id 过滤。
//   - linkedEventsByDay 用 `[Date: [Event]]`，key 是该天的 startOfDay。View 用
//     `keys.sorted()` 自行排序。
//   - membersSinceText 用 `"\(count) members · since \(MMM d formatter.string(from: createdAt))"`。
//     与设计稿 "3 members · since Apr 12" 对齐 —— 即「短月名 + 日数」，无年份。

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class ProjectDetailViewModel {

    // MARK: Stored

    /// 详情页围绕的 Project（View 直接读 title / intro / tag / notes / members）。
    public let project: Project

    private let context: ModelContext

    /// Refresh tick —— 任意写入都让 Observation 把所有 computed property 标记为脏。
    private var tick: Int = 0

    // MARK: Init

    public init(project: Project, context: ModelContext) {
        self.project = project
        self.context = context
    }

    // MARK: Refresh

    /// View 层在 `@Query` 数据变化时调用，让 computed property 在下一帧重新 fetch。
    public func refresh() {
        tick &+= 1
    }

    // MARK: - Internal helpers

    /// 拉本 project 下的所有 Todo（不区分 done / urgency），按 createdAt 升序。
    private func projectTodos() -> [Todo] {
        let all = (try? context.fetch(FetchDescriptor<Todo>())) ?? []
        return all
            .filter { $0.project?.id == project.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 拉本 project 下的所有 Event，按 start 升序。
    private func projectEvents() -> [Event] {
        let all = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        return all
            .filter { $0.project?.id == project.id }
            .sorted { $0.start < $1.start }
    }

    // MARK: - Derived: todos

    /// open + urgent，按 createdAt 升序。
    public var urgent: [Todo] {
        _ = tick
        return projectTodos().filter { !$0.done && $0.urgency == .urgent }
    }

    /// open + normal，按 createdAt 升序。
    public var normal: [Todo] {
        _ = tick
        return projectTodos().filter { !$0.done && $0.urgency == .normal }
    }

    /// 已完成（done）的本 project todos，按 createdAt 升序。
    public var completed: [Todo] {
        _ = tick
        return projectTodos().filter { $0.done }
    }

    /// open todos 数量（urgent + normal）。
    public var openCount: Int {
        _ = tick
        return projectTodos().filter { !$0.done }.count
    }

    /// open + urgent 数量。
    public var urgentCount: Int {
        _ = tick
        return urgent.count
    }

    /// 已完成数量。
    public var doneCount: Int {
        _ = tick
        return completed.count
    }

    // MARK: - Derived: events

    /// 本 project 的事件按 day(startOfDay) 分组，每组内已按 start 升序。
    /// View 用 `keys.sorted()` 自行决定显示顺序。
    public var linkedEventsByDay: [Date: [Event]] {
        _ = tick
        let cal = Calendar.current
        var result: [Date: [Event]] = [:]
        for event in projectEvents() {
            let key = cal.startOfDay(for: event.start)
            result[key, default: []].append(event)
        }
        // projectEvents 已按 start 升序，分组后每组天然保持升序，无需再排序。
        return result
    }

    /// 本 project 的总事件数（meta row + iOS stats card 使用）。
    public var linkedEventsCount: Int {
        _ = tick
        return projectEvents().count
    }

    // MARK: - Derived: meta

    /// "3 members · since Apr 12" 这样的副标。
    /// 月份用 `en_US_POSIX` locale 锁英文短月名（与 plan P3.5 验收的 "Apr 12" 对齐）。
    ///
    /// F2 修复：count 走 `project.memberCount`（Project 上的冗余 Int 字段），不再读
    /// `project.members.count`。后者因 SwiftData to-many 关系 fault 行为偶发返回 0/2/3，
    /// 在 v0.9 没有项目编辑入口的前提下 memberCount 一次性 init 时写定，永远准确。
    public var membersSinceText: String {
        _ = tick
        let count = project.memberCount
        let dateText = Self.shortDateFormatter.string(from: project.createdAt)
        let memberWord = count == 1 ? "member" : "members"
        return "\(count) \(memberWord) · since \(dateText)"
    }

    // MARK: - Mutations

    /// 切换 todo 的 done 状态并持久化。
    /// P6：iOS 真机触发 light haptic。
    public func toggleDone(_ todo: Todo) {
        todo.done.toggle()
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }

    /// 切换 todo 的 urgency（urgent ↔ normal）并持久化。
    /// P6：iOS 真机触发 light haptic。
    public func toggleUrgency(_ todo: Todo) {
        todo.urgency = (todo.urgency == .urgent) ? .normal : .urgent
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }

    /// 删除 todo。失败时静默吞掉（UI 会自动重新 fetch）。
    public func delete(_ todo: Todo) {
        context.delete(todo)
        try? context.save()
        refresh()
    }

    // MARK: - Statics

    /// 共享日期格式化器，避免每次 computed property 求值都重建。
    /// 格式 "MMM d" → "Apr 12" 风格。
    ///
    /// F2 修复：用 `en_US_POSIX` 锁英文输出，与 plan P3.5 验收 `"Apr 12"` 对齐，
    /// 与系统语言无关。`membersSinceText` 仅在测试 + 设计稿对齐时使用，不暴露给本地化
    /// 终端用户（UI 上展示「3 members · since Apr 12」副标，按设计稿原文，不需要中文化）。
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}
