// NotificationService.swift
// 用 UNUserNotificationCenter 调度本地通知，每个未来 Event 在 start - leadMinutes 时
// 弹一条 banner + sound。免费证书可用（plan §免费证书约束 "允许" 段）。
//
// plan P4 接口契约：
//   - public final class NotificationService
//   - requestAuthorization() async -> Bool
//   - scheduleAll(events: [Event], leadMinutes: Int) async
//   - cancel(eventID: UUID) async
//   - cancelAll() async
//
// 设计要点：
//   - identifier 格式 "event-<UUID>"，UUID 是 Event.id；不含任何 PII（标题/地点都不入 id）。
//   - schedule 前 removeAllPendingNotificationRequests() 把旧的清掉，保证一次 schedule
//     代表当前 Event 集合的完整快照（最简语义）。需要细粒度增量时再优化。
//   - 触发器用 UNCalendarNotificationTrigger（按 dateComponents 触发，repeats: false）。
//     plan 给的是「UNCalendarNotificationTrigger」与「UNTimeIntervalNotificationTrigger」
//     都允许，但 Calendar 更稳：用户改系统时间后通知会按目标时刻触发，不会受 boot time 漂移
//     影响。
//   - 只 schedule `event.start > now` 的事件；start - leadMinutes 已落到过去则跳过。
//   - 标题 / 正文走英文常量字符串，P5 时会迁移到 Localizable.xcstrings。这里先写英文。

import Foundation
import UserNotifications

/// 注 `@MainActor` 隔离：scheduleAll 接收 `[Event]`（SwiftData @Model 非 Sendable），
/// 调用方都在 MainActor 上，保持隔离一致避免跨 actor 数据竞争。
/// UNUserNotificationCenter 本身线程安全，无强制 actor 要求。
@MainActor
public final class NotificationService {

    public init() {}

    /// 弹出系统授权弹窗（仅首次）并返回用户的选择。
    /// - Returns: true 表示用户允许了 alert + sound；false 表示拒绝或出错。
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            return granted
        } catch {
            // 授权被拒 / 系统错误时返回 false。不抛出 —— 调用方不需要区分原因，
            // 后续 schedule 也会因为没授权而 silently skip。
            return false
        }
    }

    /// 用一组 Event 重新调度所有本地通知。
    /// 先 removeAllPendingNotificationRequests() 再 add，所以每次调用都是「完整快照」。
    ///
    /// - Parameters:
    ///   - events: 当前持久层的全部 Event。
    ///   - leadMinutes: 提前多少分钟触发；从 SettingsViewModel.headsUpLeadMinutes 来。
    public func scheduleAll(events: [Event], leadMinutes: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        // 用 LinoJTime.now()（真实时间）—— 与 HeadsUpService 一致，避免时间源不一致引发
        // 「DEBUG 下 schedule 用真实时间、service 比较用冻结时间」这种 F1 时代的 bug。
        let now = LinoJTime.now()
        let lead = TimeInterval(leadMinutes) * 60

        for event in events {
            // 跳过已经开始 / 已经结束的事件。
            guard event.start > now else { continue }

            let triggerDate = event.start.addingTimeInterval(-lead)
            // 触发时刻必须在未来；如果 lead 时间已经过去则跳过（提前提醒已无意义）。
            guard triggerDate > now else { continue }

            let content = UNMutableNotificationContent()
            // 标题 / 正文用英文（plan P5 才迁移本地化）。
            content.title = "Heads up — \(event.title)"
            content.body = "in \(leadMinutes) min · \(event.location)"
            content.sound = .default

            // 拆出日历组件构造 UNCalendarNotificationTrigger。
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let request = UNNotificationRequest(
                identifier: Self.identifier(for: event.id),
                content: content,
                trigger: trigger
            )

            // add 用 async 版本；失败时静默吞掉（单条失败不影响其它）。
            do {
                try await center.add(request)
            } catch {
                // 无 logging 子系统；plan 未要求，先 swallow。
            }
        }
    }

    /// 取消单个 Event 的 pending 通知。
    public func cancel(eventID: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.identifier(for: eventID)]
        )
    }

    /// 取消所有 pending 通知。
    public func cancelAll() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// identifier 工厂。统一前缀 "event-"，方便后续如果有别的来源（如 daily summary）共存时区分。
    private static func identifier(for eventID: UUID) -> String {
        "event-\(eventID.uuidString)"
    }
}
