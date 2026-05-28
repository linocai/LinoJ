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
        let candidate = all
            .filter { event in
                // event 已经开始但未结束 → 仍在「头顶上」窗口
                // event 还未开始但 start 在 60 min 内
                event.end > now && event.start <= windowEnd
            }
            .sorted { $0.start < $1.start }
            .first

        // 3 / 4. 构造或清空
        if let event = candidate {
            let secondsUntil = event.start.timeIntervalSince(now)
            // 向上取整到分钟。已开始（secondsUntil ≤ 0）的事件 minutesUntil = 0。
            let minutesUntil = max(0, Int(ceil(secondsUntil / 60.0)))
            currentAlert = HeadsUpAlertModel(
                eventID: event.id,
                title: event.title,
                location: event.location,
                minutesUntil: minutesUntil
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
    }
}
