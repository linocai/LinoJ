// YesterdayMissedService.swift
// 计算「昨日已结束 + 未确认参加」的事件列表 —— 给 Main 与 Calendar 的
// 「From yesterday」dashed-border box 使用。
//
// plan P4 接口契约：
//   - @MainActor public final class YesterdayMissedService
//   - init(context: ModelContext)
//   - computeMissed(now: Date = LinoJTime.now()) -> [Event]
//     调用方（MainViewModel / CalendarViewModel）传各自注入的 `today`（生产 = 真实今天；
//     测试注入 SeedData.todaySimulated() 让 2026-05-26 yesterday-missed seed 数据能被识别）。
//     Service 自身默认用 `now()`（真实时间）保持服务接口的「物理时间」语义干净。
//   - confirmAttended(_ event: Event)
//
// 筛选条件（README 与 PROJECT_PLAN.md P4 验收一致）：
//   - event.end < startOfToday（昨日及更早已经结束）
//   - event.end >= startOfYesterday（限制只到昨天，不显示前天及更早）
//   - event.attendedConfirmed == false（用户还没勾「我参加了」）
//
// 与 MainViewModel / CalendarViewModel 之前临时各自 fetch 的逻辑等价；这两个 VM 在 P4
// 接通时把临时实现替换为调用本 service。

import Foundation
import SwiftData

@MainActor
public final class YesterdayMissedService {

    /// SwiftData 上下文。生命周期与 service 同步，不需要替换。
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// 计算昨日已结束且未确认参加的事件，按 start 升序返回。
    ///
    /// - Parameter now: 用来推算「今天」与「昨天」的时刻；默认 `LinoJTime.now()`（始终真实时间）。
    ///                  调用方传各自注入的 `today`（生产 = 真实今天；测试注入
    ///                  `SeedData.todaySimulated()` = 2026-05-27 让 seed 数据可见）。
    ///                  测试时可注入特定 Date 来覆盖边界 case。
    public func computeMissed(now: Date = LinoJTime.now()) -> [Event] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return []
        }

        let all = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        return all
            .filter {
                $0.end < startOfToday
                && $0.end >= startOfYesterday
                && $0.attendedConfirmed == false
            }
            .sorted { $0.start < $1.start }
    }

    /// 把一条 yesterday-missed 事件标记为「已参加」并立即持久化。
    /// UI 上勾选 checkbox 后调用，调用方下一次 `computeMissed()` 时它会自动从结果中消失。
    public func confirmAttended(_ event: Event) {
        event.attendedConfirmed = true
        try? context.save()
    }
}
