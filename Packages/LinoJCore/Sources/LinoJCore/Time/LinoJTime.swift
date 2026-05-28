// LinoJTime.swift
// 统一的「现在 / 今天」时间源。
//
// 设计（v0.9 reviewer F1 修复后）：
//   - `now()` —— **永远** 返回真实的 `Date.now`，DEBUG/Release 一致。
//     用于：HeadsUpService.tick / NotificationService.scheduleAll / Calendar now 线 /
//          YesterdayMissedService.computeMissed —— 这些地方需要「真实物理时间」决定
//          alert 是否在 60min 窗内、now 线 Y 坐标、通知触发时刻是否在未来。
//   - `today()` —— DEBUG 返回 `SeedData.todaySimulated()`（2026-05-27 09:00），
//     Release 返回 `.now`。用于 ViewModel 决定「今天属于哪个 Date / weekStart」，让
//     DEBUG 下 seed 出来的 2026-05-27 事件能在 Main / Calendar 显示。Release 则与
//     真实日期一致。
//
// 旧 `LinoJTime.now()` 在 DEBUG 下返回冻结时间，导致 alert 永不更新 / now 线永不移动 /
// 通知服务时间源不一致 —— 这是 F1 致命 bug。本拆分把语义清晰分开。
//
// 用 `enum` 作为命名空间（无实例），公共 API 只暴露两个静态方法。

import Foundation

public enum LinoJTime {

    /// 当前真实时刻。**始终** 返回 `Date.now`，不分 DEBUG/Release。
    ///
    /// 适用于：
    /// - HeadsUpService tick 时判断 alert 是否在窗口内
    /// - NotificationService schedule 时判断触发时刻是否未过期
    /// - Calendar 视图 now 线 Y 坐标计算
    /// - YesterdayMissedService 算 startOfToday / startOfYesterday
    public static func now() -> Date {
        Date()
    }

    /// 「今天」的语义锚点 —— ViewModel / 设计稿展示用。
    ///
    /// - DEBUG：返回 `SeedData.todaySimulated()`（固定 2026-05-27 09:00 local），
    ///         让 seed 事件落在「今天」窗口。
    /// - Release：返回 `Date.now`（真实今天）。
    ///
    /// 适用于：
    /// - MainViewModel.todayEvents / next7DaysGrouped 决定哪些事件归「今天」
    /// - CalendarViewModel.weekStart / todayStart / now 决定今天属于哪一周
    /// - ProjectDetailView 计算 todayStart 做事件分组
    public static func today() -> Date {
        #if DEBUG
        return SeedData.todaySimulated()
        #else
        return Date()
        #endif
    }

    /// 今天的 startOfDay（00:00）。基于 `today()`，DEBUG 下落在 2026-05-27 00:00。
    public static func startOfToday(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: today())
    }
}
