// YesterdayMissedService.swift
// 计算「过去已结束 + 未了结」的事件列表 —— 给 Main 与 Calendar 的
// 「From yesterday」dashed-border box 使用。
//
// v1.2 P2：窗口从「昨日单天」扩为「**所有过去未了结**」（去掉「只到昨天」的下界），并新增
// 第三态出口 `dismissMissed(_:)`（忽略 / 没去，不撒谎打勾）。方法名 `computeMissed` 保留，
// 避免大改调用点；语义现为「过去未了结」。
//
// plan P2 接口契约：
//   - @MainActor public final class YesterdayMissedService
//   - init(context: ModelContext)
//   - computeMissed(now: Date = LinoJTime.now()) -> [Event]
//     调用方（MainViewModel / CalendarViewModel）传各自注入的 `today`（生产 = 真实今天；
//     测试注入 SeedData.todaySimulated() 让 seed 数据能被识别）。
//     Service 自身默认用 `now()`（真实时间）保持服务接口的「物理时间」语义干净。
//   - confirmAttended(_ event: Event)   —— 标「已参加」（attendedConfirmed = true）
//   - dismissMissed(_ event: Event)     —— v1.2 第三态：标「已处理但未必出席」（dismissedFromYesterday = true）
//
// 筛选条件（v1.2 P2 验收）：
//   - event.end < startOfToday（已经结束，含昨天及更早的「过去未了结」）
//   - event.attendedConfirmed == false（用户还没勾「我参加了」）
//   - event.dismissedFromYesterday == false（用户也还没「忽略 / 没去」第三态出口）
//
// 显示截断在 UI 层：service 返回**全部**过去未了结事件（按 start 升序）。决策 D1：默认显示
// 最近 5 条（start 最大的 5 条），更早的折成「+N 更早」一行。截断由纯函数
// `truncateForDisplay(_:limit:)` 提供（可单测），UI 调用它拆 visible / earlierCount。

import Foundation
import SwiftData

@MainActor
public final class YesterdayMissedService {

    /// SwiftData 上下文。生命周期与 service 同步，不需要替换。
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// 计算「过去已结束且未了结」的事件，按 start 升序返回**全部**（截断在 UI 层）。
    ///
    /// - Parameter now: 用来推算「今天」的时刻；默认 `LinoJTime.now()`（始终真实时间）。
    ///                  调用方传各自注入的 `today`（生产 = 真实今天；测试注入
    ///                  `SeedData.todaySimulated()` 让 seed 数据可见）。
    ///
    /// v1.2 P2：去掉「只到昨天」的下界（`end >= startOfYesterday`），凡 `end < startOfToday`
    /// 且未确认出席、未被第三态忽略的事件都返回。
    public func computeMissed(now: Date = LinoJTime.now()) -> [Event] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        let all = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        return all
            .filter {
                $0.end < startOfToday
                && $0.attendedConfirmed == false
                && $0.dismissedFromYesterday == false
            }
            .sorted { $0.start < $1.start }
    }

    /// 把一条 yesterday-missed 事件标记为「已参加」并立即持久化。
    /// UI 上勾选 checkbox 后调用，调用方下一次 `computeMissed()` 时它会自动从结果中消失。
    public func confirmAttended(_ event: Event) {
        event.attendedConfirmed = true
        try? context.save()
    }

    /// v1.2 P2 第三态：把一条 yesterday-missed 事件「忽略 / 没去」—— 移出该框但**不撒谎打勾**。
    /// 置 `dismissedFromYesterday = true`（不动 `attendedConfirmed`，保「真出席」语义干净）。
    /// 调用方下一次 `computeMissed()` 时它会从结果中消失，但 Calendar 出席态不会误亮。
    public func dismissMissed(_ event: Event) {
        event.dismissedFromYesterday = true
        try? context.save()
    }

    // MARK: - 显示截断（纯函数，可单测）

    /// 把「过去未了结」全量列表（已按 start 升序）拆成 UI 要显示的两段：
    ///   - `visible`：离今天最近的 `limit` 条（即 start 最大的 limit 条），**仍按 start 升序**；
    ///   - `earlierCount`：更早的那些（被折叠成「+N 更早」一行）的条数。
    ///
    /// 决策 D1：默认 `limit == 5`。`events` 数 ≤ limit 时 `earlierCount == 0`、`visible == events`。
    ///
    /// - Parameters:
    ///   - events: `computeMissed` 的返回（按 start 升序）。
    ///   - limit: 最多直接显示的条数，默认 5。
    /// - Returns: `(visible: [Event], earlierCount: Int)`。
    public static func truncateForDisplay(
        _ events: [Event],
        limit: Int = 5
    ) -> (visible: [Event], earlierCount: Int) {
        guard events.count > limit else {
            return (events, 0)
        }
        // 取 start 最大（离今天最近）的 limit 条 —— 即尾部 limit 条；仍保持升序。
        let visible = Array(events.suffix(limit))
        let earlierCount = events.count - limit
        return (visible, earlierCount)
    }
}
