// LinoJTime.swift
// 统一的「现在 / 今天」时间源。
//
// 设计：
//   - `now()` —— **永远** 返回真实的 `Date.now`，DEBUG/Release 一致。
//     用于：HeadsUpService.tick / NotificationService.scheduleAll / Calendar now 线 /
//          YesterdayMissedService.computeMissed —— 这些地方需要「真实物理时间」决定
//          alert 是否在 60min 窗内、now 线 Y 坐标、通知触发时刻是否在未来。
//   - `today()` —— **永远** 返回真实的 `Date.now`，DEBUG/Release 一致。
//     旧实现在 DEBUG 下返回冻结的 `SeedData.todaySimulated()`（2026-05-27），导致日常
//     Debug 包「不知道今天几号」。现已根治：today() 始终是真实日期。
//
// 确定性测试改为 **显式注入** `SeedData.todaySimulated()`：ViewModel（MainViewModel /
// CalendarViewModel）的 `today:` 注入参数默认 = `LinoJTime.today()`（真实今天，生产行为
// 不变），测试构造时传 `SeedData.todaySimulated()` 让 seed 数据落入「今天」窗口、断言
// 与系统真实日期无关。
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
    /// **始终** 返回 `Date.now`（真实今天），DEBUG/Release 一致。日常 Debug 包也显示
    /// 真实日期。确定性测试不依赖此函数的返回值，而是向 ViewModel 显式注入
    /// `SeedData.todaySimulated()`（见文件头注释）。
    ///
    /// 适用于：
    /// - MainViewModel.todayEvents / next7DaysGrouped 决定哪些事件归「今天」
    /// - CalendarViewModel.weekStart / todayStart / now 决定今天属于哪一周
    /// - ProjectDetailView 计算 todayStart 做事件分组
    public static func today() -> Date {
        Date()
    }

    /// 今天的 startOfDay（00:00）。基于 `today()`，始终是真实今天的 00:00。
    public static func startOfToday(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: today())
    }
}
