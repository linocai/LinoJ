// MainViewModel.swift
// Main 视图的 ViewModel —— 把 SwiftData 里散落的 Todo / Event / Project 整理为 Main 视图需要的形状。
//
// 设计取舍（与 PROJECT_PLAN.md P3.2「Query 方式」一致）：
//   - 保留 plan 给出的接口：所有过滤 / 派生量都是 `@Observable` 类型上的 computed property，
//     在 init 时拿到 `ModelContext`，内部用 `try? context.fetch(...)` 拉数据。
//   - View 层用 `@Query` 拉一份原始集合，仅用于触发 invalidation；变化时调 `vm.refresh()`。
//     `refresh()` 本身只是把 `tick` 自增一下，让所有 computed property 重算（Observation
//     依赖追踪 → `tick` 写入触发 View 重读，从而重新走 fetch）。
//   - 数据量 v0.9 ≤ 100 条，每次重算的 N×N 过滤完全没有性能压力。
//
// HeadsUp 在 P4 接通：通过可选注入的 `HeadsUpService` 暴露 `currentAlert`。如果调用方
// 不传 service（mock / 老测试场景），`headsUp` 永远是 nil，行为与 P3.2 一致。

import Foundation
import Observation
import SwiftData

/// Heads-up alert 的展示数据。`HeadsUpService`（P4）在事件 60min 内 fire 时构造此模型。
public struct HeadsUpAlertModel: Equatable, Sendable {
    /// 事件实体的 `id`（用 UUID 而非 `Event` 引用，避免跨 actor 传递 `@Model` 类型）。
    public let eventID: UUID
    public let title: String
    public let location: String
    public let minutesUntil: Int

    public init(eventID: UUID, title: String, location: String, minutesUntil: Int) {
        self.eventID = eventID
        self.title = title
        self.location = location
        self.minutesUntil = minutesUntil
    }
}

@Observable
@MainActor
public final class MainViewModel {

    // MARK: Stored

    /// SwiftData 上下文。View 通过 `@Environment(\.modelContext)` 拿到后注入。
    /// 用 `let` 因为生命周期与 ViewModel 同步，不需要替换。
    private let context: ModelContext

    /// Refresh tick —— 任意写入都让 Observation 把所有 computed property 标记为脏。
    /// 这是「@Query 触发 View 重算」与「ViewModel computed property 重新 fetch」之间的桥。
    private var tick: Int = 0

    /// HeadsUpService 实例（可选）。P4 起由 App 入口在 RootWindow / RootTabView 注入；
    /// 不传时 `headsUp` 永远 nil（用于测试 mock 与早期 Phase 兼容）。
    private let headsUpService: HeadsUpService?

    /// 当前 Heads-up alert。computed 直接转发 service.currentAlert —— @Observable 自动追踪。
    public var headsUp: HeadsUpAlertModel? { headsUpService?.currentAlert }

    /// YesterdayMissedService 实例（可选）。P4 起由 App 入口注入；不传时回退到本地 fetch
    /// （与 P3.2 行为一致）。
    private let yesterdayMissedService: YesterdayMissedService?

    // MARK: Init

    public init(
        context: ModelContext,
        headsUpService: HeadsUpService? = nil,
        yesterdayMissedService: YesterdayMissedService? = nil
    ) {
        self.context = context
        self.headsUpService = headsUpService
        self.yesterdayMissedService = yesterdayMissedService
    }

    // MARK: Refresh hook

    /// View 层在 `@Query` 数据变化时调用，让所有 computed property 在下一帧重新 fetch。
    ///
    /// 没有这个 hook 时，computed property 不会自动重新求值（Observation 不知道 SwiftData
    /// 内部 entity 变化），UI 显示的就是 init 时刻的旧快照。
    public func refresh() {
        tick &+= 1
    }

    // MARK: - Derived data (computed)

    /// 全部 open（done == false）todos 的实时计数。
    public var openCount: Int {
        _ = tick
        return openTodos().count
    }

    /// open + urgent 的实时计数（plan P3.2 验收：seed 后 == 5）。
    public var urgentCount: Int {
        _ = tick
        return openTodos().filter { $0.urgency == .urgent }.count
    }

    /// 今日事件计数（plan P3.2 验收：seed 后 Tue 有 4 场）。
    public var todayEventsCount: Int {
        _ = tick
        return todayEvents.count
    }

    /// open + urgent，按 createdAt 升序。
    public var urgentTodos: [Todo] {
        _ = tick
        return openTodos()
            .filter { $0.urgency == .urgent }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// open + normal，按 createdAt 升序。
    public var normalTodos: [Todo] {
        _ = tick
        return openTodos()
            .filter { $0.urgency == .normal }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 今天落地的所有事件，按 start 升序。
    /// 用 `LinoJTime.today()`：DEBUG 下取 2026-05-27 让 seed 数据落入今天。
    public var todayEvents: [Event] {
        _ = tick
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: LinoJTime.today())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return []
        }
        return allEvents()
            .filter { $0.start >= startOfToday && $0.start < startOfTomorrow }
            .sorted { $0.start < $1.start }
    }

    /// 「Next 7 days」分组：以今天为第 1 天，向后 7 天；每天的 events 按 start 升序。
    /// 始终返回 7 项（即使某天为空也保留 `events: []`），保证 UI 7-row 骨架稳定。
    /// 用 `LinoJTime.today()`：DEBUG 下从 2026-05-27 开始的 7 天，让 seed 数据可见。
    public var next7DaysGrouped: [(day: Date, events: [Event])] {
        _ = tick
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: LinoJTime.today())
        let events = allEvents()

        var result: [(day: Date, events: [Event])] = []
        for offset in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }
            let dayEvents = events
                .filter { $0.start >= dayStart && $0.start < nextDayStart }
                .sorted { $0.start < $1.start }
            result.append((day: dayStart, events: dayEvents))
        }
        return result
    }

    /// 昨日已结束 + 未确认参加的事件，按 start 升序。
    /// P4 起优先委托 YesterdayMissedService；service 未注入时 fallback 到本地计算（保证
    /// 既有测试与 mock 路径不变）。
    /// fallback 路径用 `LinoJTime.today()`：DEBUG 下取 2026-05-27 让 yesterday=05-26 的
    /// seed 事件被识别。
    public var yesterdayMissed: [Event] {
        _ = tick
        if let service = yesterdayMissedService {
            // 显式传 LinoJTime.today()：DEBUG 下用 2026-05-27 让 seed 的 yesterday=05-26
            // 事件能被识别为「昨天」；Release 下与真实 now 等价。
            return service.computeMissed(now: LinoJTime.today())
        }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: LinoJTime.today())
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return []
        }
        return allEvents()
            .filter {
                $0.end < startOfToday
                && $0.end >= startOfYesterday
                && $0.attendedConfirmed == false
            }
            .sorted { $0.start < $1.start }
    }

    /// 全部 projects，按 createdAt 升序。
    public var projects: [Project] {
        _ = tick
        return (try? context.fetch(FetchDescriptor<Project>()))?
            .sorted { $0.createdAt < $1.createdAt } ?? []
    }

    // MARK: - Mutations

    /// 切换 todo 的 done 状态并持久化。失败时静默吞掉 —— UI 已经把 done 状态绑到 Todo
    /// 引用属性，下一次 fetch 会拿到正确值。
    /// P6：iOS 真机触发 light haptic。
    public func toggleDone(_ todo: Todo) {
        todo.done.toggle()
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }

    /// 把 yesterday-missed 中的事件标为「已参加」。
    /// P6：iOS 真机触发 light haptic。
    public func confirmAttended(_ event: Event) {
        event.attendedConfirmed = true
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }

    /// HeadsUp snooze 10 分钟。P4 起转发到 HeadsUpService；service 未注入时 noop。
    public func snoozeHeadsUp() {
        headsUpService?.snooze()
    }

    /// HeadsUp open。P4 阶段仍 noop —— 与 Calendar 的「跳到那天」跳转留给 P5+（依赖
    /// TabRouter / CalendarViewModel.selectDay 联动，目前 MainViewModel 不持 router）。
    /// UI 层可以传 onOpen closure 直接处理跳转，不需要绕 VM。
    public func openHeadsUpEvent() {
        // noop：跳转交给 UI 层 closure（HeadsUpAlert 的 onOpen 参数）
    }

    // MARK: - Internal helpers

    /// 拉所有 open（未完成）todo。SwiftData fetch 失败时返回空数组。
    private func openTodos() -> [Todo] {
        let descriptor = FetchDescriptor<Todo>(predicate: #Predicate<Todo> { $0.done == false })
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 拉全部事件。failure 静默退回空数组（UI 上表现为「没东西」，不崩）。
    private func allEvents() -> [Event] {
        (try? context.fetch(FetchDescriptor<Event>())) ?? []
    }
}
