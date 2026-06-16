// HeadsUpService.swift
// 每分钟扫描一次即将到来的事件，输出 HeadsUpAlertModel 给 Main 视图渲染。
//
// 行为（design_handoff README「Heads-up alert logic」+ plan P4 验收）：
//   - 在 Main 上显示一个事件，当：
//       event.start ∈ [now, now + 60min]
//       event.end > now（事件还没结束）
//   - 选择「最早即将开始」的那场；只显示一条 alert，不堆叠。
//   - minutesUntil = max(0, ceil((event.start - now) / 60))
//       事件已经开始（now > start）但未结束时 minutesUntil = 0，仍显示 alert
//       直到 event.end <= now 才置 nil。
//   - snooze(for:)：把当前 alert 置 nil，并设置 `snoozeUntil`；
//                  在 snoozeUntil 之前的所有 tick 强制 currentAlert = nil。
//
// 暴露方式：`@Observable @MainActor` 类，`currentAlert` 是 `@Observable` 属性。
// MainViewModel 持 service 实例，把 `headsUp` 用 computed property 暴露 `service?.currentAlert`，
// 这样 SwiftUI 通过 Observation 自动追踪到 currentAlert 变化即可触发重渲。
//
// Timer 设计：
//   - Timer.scheduledTimer 每 60s 调一次 tick()，立即 + 周期性。
//   - start() 时先调一次 tick()，让首次渲染不必等 60s。
//   - 注册到 .main RunLoop，与 MainActor 线程一致；闭包内 self 弱引用避免循环。
//
// 不要做（plan P4 明确）：
//   - 远程通知 / APNs
//   - BGTaskScheduler（免费证书）
//   - UNNotificationAction button —— v0.9 不做

import Foundation
import Observation
import SwiftData

/// U6：今日时间冲突提示数据。`HeadsUpService` 在 tick 内扫描「今天」事件，找出
/// 重叠簇（`computeOverlapLayout` 的 `columnCount > 1`），取最早一个簇生成此模型。
///
/// 与 `HeadsUpAlertModel`（「即将开始」）语义独立：一个是「头顶上即将发生」的紧急提示，
/// 一个是「今天有日程撞车」的被动中性提示。Main 上两条并列渲染、互不吞掉。
public struct ConflictAlertModel: Equatable, Sendable {
    /// 冲突簇内最早一件事件的 start（提示展示的冲突起始时刻）。
    public let atTime: Date
    /// 冲突簇 size（撞车的事件数，≥ 2）。
    public let count: Int

    public init(atTime: Date, count: Int) {
        self.atTime = atTime
        self.count = count
    }
}

@Observable
@MainActor
public final class HeadsUpService {

    // MARK: Stored

    /// SwiftData 上下文。tick 时 fetch 事件。
    private let context: ModelContext

    /// 提前多少分钟开始显示 alert。plan 接口契约默认 30，但 README 给的窗口是 60 min；
    /// 这里采用更宽的 60 min 作为「显示窗口」（README 的硬契约），把 leadMinutes 视为
    /// 「通知调度」用（NotificationService 负责），UI 显示窗口固定 60 min。
    ///
    /// 也就是说 leadMinutes 在本 service 内未直接用于「是否显示」判定（窗口固定 60），
    /// 但保留入参以满足 plan 接口契约，并供调用方查询 / 未来扩展。
    private let leadMinutes: Int

    /// 暂停结束时刻；nil = 未 snooze。tick 时若 `Date() < snoozeUntil` 则 currentAlert 强制 nil。
    /// snoozeUntil 过期后 tick 会重新计算 currentAlert。
    private var snoozeUntil: Date?

    /// 内部 Timer 引用，stop() 时 invalidate。Timer 不是 Sendable，所以用 `nonisolated(unsafe)`
    /// 也不行；MainActor 隔离让我们安全持有它而无需 Sendable。
    private var timer: Timer?

    /// 当前 alert。`@Observable` 让 SwiftUI 自动追踪。
    public var currentAlert: HeadsUpAlertModel? = nil

    /// U6：今日时间冲突提示（与 `currentAlert` 并列，语义独立）。tick 内一并计算。
    /// 无冲突 / 不在窗口内时为 nil。snooze 不影响冲突（冲突是被动提示，不参与 snooze）。
    public var conflictAlert: ConflictAlertModel? = nil

    // MARK: Init

    /// - Parameters:
    ///   - context: SwiftData 上下文，用于 fetch 事件。
    ///   - leadMinutes: 通知调度的提前分钟数（默认 30）。本 service 内 UI 显示窗口固定 60 min，
    ///                  leadMinutes 主要给 NotificationService 用，但允许外部统一传一次。
    public init(context: ModelContext, leadMinutes: Int = 30) {
        self.context = context
        self.leadMinutes = leadMinutes
    }

    // MARK: Lifecycle

    /// 启动每 60s tick 的 Timer，并立即调一次 tick() 让 UI 首帧就有正确状态。
    /// 重复调用幂等：已有 timer 时先 invalidate 再重建。
    public func start() {
        stop()
        // 立即 tick 一次。
        tick()
        // 每 60s 周期 tick。
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            // Timer 回调在 main RunLoop（我们 add 到 .common），但闭包本身不在
            // MainActor 隔离上下文中。用 Task { @MainActor } 跳回 MainActor。
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    /// 停止 tick。invalidate 后 timer 释放，currentAlert 保持上次值（不主动清空）。
    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 暂停当前 alert 指定分钟数。snoozeUntil 期间所有 tick 都强制 currentAlert = nil；
    /// 到期后 tick 会重新计算（如果事件还在窗口内会再次出现）。
    /// - Parameter minutes: 暂停的分钟数，默认 10。
    public func snooze(for minutes: Int = 10) {
        let until = LinoJTime.now().addingTimeInterval(TimeInterval(minutes) * 60)
        snoozeUntil = until
        currentAlert = nil
    }

    // MARK: Tick

    /// 重新计算 currentAlert。每分钟由 Timer 调一次；snooze 与 start 时也调。
    ///
    /// 算法：
    ///   1. 如果还在 snooze 窗口内 → currentAlert = nil，结束。
    ///   2. 否则 fetch 所有事件，过滤出 `start ∈ [now, now+60min] && end > now`。
    ///   3. 取 start 最小的那一条，构造 HeadsUpAlertModel。
    ///   4. 没有符合条件的事件 → currentAlert = nil。
    public func tick() {
        let now = LinoJTime.now()

        // 1. snooze 检查
        if let snoozeUntil, snoozeUntil > now {
            currentAlert = nil
            return
        } else if snoozeUntil != nil {
            // snooze 已过期，清掉以避免下一次还误判
            snoozeUntil = nil
        }

        // 2. 拉所有事件，找窗口内最早的那场
        let windowEnd = now.addingTimeInterval(60 * 60) // now + 60 min
        let all = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let imminent = all
            .filter { event in
                // event 已经开始但未结束 → 仍在「头顶上」窗口
                // event 还未开始但 start 在 60 min 内
                event.end > now && event.start <= windowEnd
            }
            .sorted { $0.start < $1.start }
        let candidate = imminent.first

        // 3 / 4. 构造或清空
        if let event = candidate {
            let secondsUntil = event.start.timeIntervalSince(now)
            // 向上取整到分钟。已开始（secondsUntil ≤ 0）的事件 minutesUntil = 0。
            let minutesUntil = max(0, Int(ceil(secondsUntil / 60.0)))
            // v1.2 P4：进行中判定 + 剩余分钟 + 「+N 更多」角标。
            let isOngoing = now >= event.start && now < event.end
            let remainingSeconds = event.end.timeIntervalSince(now)
            let remainingMinutes = max(0, Int(ceil(remainingSeconds / 60.0)))
            // moreCount = 窗口内事件数 - 1（除当前这条外还有几条）。单条不堆叠，pill 仍只渲染这条。
            let moreCount = max(0, imminent.count - 1)
            currentAlert = HeadsUpAlertModel(
                eventID: event.id,
                title: event.title,
                location: event.location,
                minutesUntil: minutesUntil,
                moreCount: moreCount,
                isOngoing: isOngoing,
                remainingMinutes: remainingMinutes
            )
        } else {
            currentAlert = nil
        }

        // I9：一致性兜底 —— 如果 currentAlert 引用的 event 已不在 context 中（被删除），
        // 上面 candidate 重算逻辑已经会让 currentAlert 自然变 nil（candidate 找不到）。
        // 但为了防范上面逻辑因任何原因没清掉而 stale，再加一次硬一致性检查。
        if let current = currentAlert,
           !all.contains(where: { $0.id == current.eventID }) {
            currentAlert = nil
        }

        // U6：今日时间冲突扫描（与上面「即将开始」并列，语义独立，不受 snooze 影响）。
        // 复用上面已 fetch 的 `all`，避免二次 fetch。
        conflictAlert = Self.computeConflictAlert(events: all, now: now)
    }

    // MARK: - U6 冲突扫描

    /// U6：在「今天」（`now` 所在日历日）的事件里找最早一个重叠簇，生成 `ConflictAlertModel`。
    ///
    /// **纯函数**（不读 `@Observable` 属性、不 mutate、不 fetch），便于单测直接调；
    /// `tick()` 把 fetch 到的全量事件 + `now` 传进来。
    ///
    /// 算法：
    ///   1. 过滤出 `start` 落在「今天」（`now` 的 startOfDay ≤ start < 次日 startOfDay）的事件。
    ///   2. 调 **U5 的 `CalendarViewModel.computeOverlapLayout(events:)`** 算列分配
    ///      （不重复实现归簇逻辑），`columnCount > 1` 即处于冲突簇中。
    ///   3. 在所有处于冲突簇的事件里取 **start 最早** 的那件，回溯它所在簇的全部成员，
    ///      `atTime` = 簇内最早 start，`count` = 簇 size。只输出一条（最早簇），不堆叠。
    ///   4. 无任何冲突 → nil。
    static func computeConflictAlert(events: [Event], now: Date) -> ConflictAlertModel? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return nil
        }
        let todayEvents = events.filter { $0.start >= startOfToday && $0.start < startOfTomorrow }
        guard !todayEvents.isEmpty else { return nil }

        // U5 列分配：columnCount > 1 = 处于冲突簇。
        let layout = CalendarViewModel.computeOverlapLayout(events: todayEvents)

        // 处于冲突簇的事件（按 start 升序，确定性），取最早一件锚定「最早簇」。
        let conflicting = todayEvents
            .filter { (layout[$0.id]?.columnCount ?? 1) > 1 }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.end < $1.end }
        guard let earliest = conflicting.first else { return nil }

        // 回溯 earliest 所在簇：传递性重叠（A.start < B.end && B.start < A.end）。
        // 从 earliest 起向后扩张簇的最大 end，凡 start < clusterMaxEnd 的并入。
        // todayEvents 先按 start 排序后线性归簇，与 computeOverlapLayout 同口径。
        let sortedToday = todayEvents.sorted {
            $0.start != $1.start ? $0.start < $1.start : $0.end < $1.end
        }
        guard let anchorIndex = sortedToday.firstIndex(where: { $0.id == earliest.id }) else {
            return nil
        }
        var clusterMaxEnd = sortedToday[anchorIndex].end
        var clusterCount = 1
        var i = anchorIndex + 1
        while i < sortedToday.count && sortedToday[i].start < clusterMaxEnd {
            clusterMaxEnd = max(clusterMaxEnd, sortedToday[i].end)
            clusterCount += 1
            i += 1
        }

        return ConflictAlertModel(atTime: earliest.start, count: clusterCount)
    }
}
