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

/// Heads-up alert 的展示数据。`HeadsUpService`（v1.0 P4）在事件 60min 内 fire 时构造此模型。
public struct HeadsUpAlertModel: Equatable, Sendable {
    /// 事件实体的 `id`（用 UUID 而非 `Event` 引用，避免跨 actor 传递 `@Model` 类型）。
    public let eventID: UUID
    public let title: String
    public let location: String
    public let minutesUntil: Int

    /// v1.2 P4：窗口 `[now, now+60min] && end>now` 内符合条件的事件数 - 1（即「除当前这条外还有几条」）。
    /// >0 时 Main 在 heads-up pill 上显示「+N 更多」角标。单条不堆叠（pill 仍只渲染 currentAlert 这条）。
    public let moreCount: Int

    /// v1.2 P4：事件是否进行中（`now >= start && now < end`）。
    /// true 时文案走「now · 还剩 Y 分」分支，避免 start 已过显示「in 0 min」的语义错。
    public let isOngoing: Bool

    /// v1.2 P4：进行中事件距 end 的剩余分钟（`ceil((end-now)/60)`）。仅 `isOngoing == true` 时有意义。
    public let remainingMinutes: Int

    public init(
        eventID: UUID,
        title: String,
        location: String,
        minutesUntil: Int,
        moreCount: Int = 0,
        isOngoing: Bool = false,
        remainingMinutes: Int = 0
    ) {
        self.eventID = eventID
        self.title = title
        self.location = location
        self.minutesUntil = minutesUntil
        self.moreCount = moreCount
        self.isOngoing = isOngoing
        self.remainingMinutes = remainingMinutes
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

    /// U6：今日时间冲突提示。computed 直接转发 service.conflictAlert —— @Observable 自动追踪。
    /// service 未注入时（mock / 早期 Phase）为 nil，Main 不渲染冲突 pill。
    public var conflict: ConflictAlertModel? { headsUpService?.conflictAlert }

    /// YesterdayMissedService 实例（可选）。P4 起由 App 入口注入；不传时回退到本地 fetch
    /// （与 P3.2 行为一致）。
    private let yesterdayMissedService: YesterdayMissedService?

    /// W2：Settings 的 `showCompletedInCounts` 注入值（View 在构造 / onChange 时灌入）。
    /// 为 true 时 `openCount` 改为「全部 todo（含 done）」计数；false 维持「仅未完成」。
    /// 注入式而非读 UserDefaults，保持 VM 可测（与 `headsUpLeadMinutes` 注入同模式）。
    public var includeCompletedInCounts: Bool = false

    /// W2：Settings 的 `yesterdayMissedReminderEnabled` 注入值（View 灌入）。
    /// 为 false 时 `yesterdayMissed` getter 短路返回 `[]`，从而「From yesterday」box 不渲染。
    public var showYesterdayMissed: Bool = true

    /// v1.2 P3：urgent 软反思 nudge 的阈值（注入式，可测、未来可放 Settings）。
    /// 决策 D4：默认 `5` —— `urgentTodos.count > threshold`（即 6 件起）才出现 nudge。
    /// 与 `includeCompletedInCounts` 同注入模式。
    public var urgentNudgeThreshold: Int = 5

    /// v1.2 P3：nudge 的 dismiss 态（**会话级**内存态，不持久化）。
    /// 用户点 nudge 上的小 × 触发 `dismissUrgentNudge()` → true，本次会话内不再出现；
    /// 下次启动若仍超阈值会再现（「定期照镜子」的预期行为，非烦扰，因为 nudge 非阻塞）。
    private var nudgeDismissed: Bool = false

    /// 该 VM 视角下的「今天」时刻。默认 = `LinoJTime.today()`（真实今天，生产行为不变）；
    /// 测试注入 `SeedData.todaySimulated()` 让 seed 数据落入「今天」窗口、断言确定性。
    /// 与 `CalendarViewModel` 的 `today:` 注入设计对称。
    private let today: Date

    // MARK: Init

    public init(
        context: ModelContext,
        headsUpService: HeadsUpService? = nil,
        yesterdayMissedService: YesterdayMissedService? = nil,
        today: Date = LinoJTime.today()
    ) {
        self.context = context
        self.headsUpService = headsUpService
        self.yesterdayMissedService = yesterdayMissedService
        self.today = today
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

    /// open todos 的实时计数。
    /// W2：`includeCompletedInCounts == true` 时改为「全部 todo（含 done）」计数；
    /// false 时维持「仅未完成」（done == false）。
    public var openCount: Int {
        _ = tick
        if includeCompletedInCounts {
            return allTodos().count
        }
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

    /// v1.2 P3：是否显示 urgent 软反思 nudge。
    /// 规则（决策 D2：仅 Main；D4：阈值默认 >5）：`urgentTodos.count > urgentNudgeThreshold && !nudgeDismissed`。
    /// **非阻塞、无降级、无倒计时**：它只是面镜子，不改任何 todo 的 urgency。
    /// dismiss 后本次会话内为 false；urgentCount 降到 ≤ 阈值时自然为 false。
    public var urgentReflectionNudge: Bool {
        _ = tick
        return urgentTodos.count > urgentNudgeThreshold && !nudgeDismissed
    }

    /// 今天落地的所有事件，按 start 升序。
    /// 用注入的 `self.today`：生产 = 真实今天；测试注入 SeedData.todaySimulated() 锚定。
    public var todayEvents: [Event] {
        _ = tick
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return []
        }
        return allEvents()
            .filter { $0.start >= startOfToday && $0.start < startOfTomorrow }
            .sorted { $0.start < $1.start }
    }

    /// 「Next 7 days」分组：以今天为第 1 天，向后 7 天；每天的 events 按 start 升序。
    /// 始终返回 7 项（即使某天为空也保留 `events: []`），保证 UI 7-row 骨架稳定。
    /// 用注入的 `self.today`：生产 = 真实今天起算 7 天；测试注入锚定让 seed 数据可见。
    public var next7DaysGrouped: [(day: Date, events: [Event])] {
        _ = tick
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
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
    /// 两条路径都用注入的 `self.today`：生产 = 真实今天；测试注入锚定让 yesterday 窗口对齐。
    public var yesterdayMissed: [Event] {
        _ = tick
        // W2：Settings 关掉「yesterday missed」提醒时短路返回空（box 自然不渲染）。
        guard showYesterdayMissed else { return [] }
        if let service = yesterdayMissedService {
            // 用注入的 self.today 作为「现在」锚点：生产 = 真实今天；测试注入
            // SeedData.todaySimulated() 让 seed 的 yesterday=05-26 事件被识别为「昨天」。
            return service.computeMissed(now: today)
        }
        // v1.2 P2：fallback 路径与 service 同步 —— 窗口扩为「全部过去未了结」
        // （去掉 startOfYesterday 下界），并追加 `dismissedFromYesterday == false`。
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        return allEvents()
            .filter {
                $0.end < startOfToday
                && $0.attendedConfirmed == false
                && $0.dismissedFromYesterday == false
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
        // v1.2 P5：维护 completedAt —— 置完成时写 .now，取消完成时清 nil。
        todo.completedAt = todo.done ? LinoJTime.now() : nil
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }

    /// 把 yesterday-missed 中的事件标为「已参加」。
    /// W4：复用为事件卡的「标记已出席」。
    /// P6：iOS 真机触发 light haptic。
    public func confirmAttended(_ event: Event) {
        event.attendedConfirmed = true
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }

    /// v1.2 P2：「From yesterday」第三态出口 —— 忽略 / 没去（不撒谎打勾）。
    /// 优先委托 service；service 未注入时直接置字段 + save（fallback 行为与 service 等价）。
    public func dismissMissed(_ event: Event) {
        if let service = yesterdayMissedService {
            service.dismissMissed(event)
        } else {
            event.dismissedFromYesterday = true
            try? context.save()
        }
        LinoJHaptics.lightTap()
        refresh()
    }

    /// W4：「取消已出席」—— 把 `attendedConfirmed` 翻回 false（可逆），与 confirmAttended 对称。
    public func unconfirmAttended(_ event: Event) {
        event.attendedConfirmed = false
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }

    /// W4：删除事件。`context.delete` + save + refresh（与 confirmAttended 同 VM、同模式）。
    public func deleteEvent(_ event: Event) {
        context.delete(event)
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }

    /// HeadsUp snooze 10 分钟。P4 起转发到 HeadsUpService；service 未注入时 noop。
    public func snoozeHeadsUp() {
        headsUpService?.snooze()
    }

    /// v1.2 P3：dismiss urgent 反思 nudge（点小 × 触发）。会话级 —— 不持久化。
    /// **不做任何破坏性动作**（不改 todo urgency）；仅把本次会话的 nudge 关掉。
    public func dismissUrgentNudge() {
        nudgeDismissed = true
        refresh()
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

    /// 拉全部 todo（含已完成）。W2 的 `includeCompletedInCounts == true` 计数路径用。
    private func allTodos() -> [Todo] {
        (try? context.fetch(FetchDescriptor<Todo>())) ?? []
    }

    /// 拉全部事件。failure 静默退回空数组（UI 上表现为「没东西」，不崩）。
    private func allEvents() -> [Event] {
        (try? context.fetch(FetchDescriptor<Event>())) ?? []
    }
}
