// CalendarViewModel.swift
// Calendar 视图的 ViewModel —— 把 SwiftData 中所有 Event 按「未来 7 天」整理给 macOS 周视图
// 与 iOS 单日 list 使用。
//
// 周起点策略（对齐设计稿）：固定为「today 起算的滚动 7 天窗口」——`weekStart = startOfDay(today)`，
// 展示 today / today+1 / … / today+6。**不再回退到周一**（设计稿 Calendar 是 rolling next 7 days，
// 第一列 TODAY，nav 范围 "May 27 — Jun 2" = today..today+6）。goPrev/Next 整体平移 7 天，goToday
// 把窗口 reset 回 today 起点。
//
// 数据流照搬 MainViewModel 模式：
//   - `@Observable @MainActor` final class；
//   - init 拿 ModelContext + 可选的 `today`（默认 LinoJTime.today()：DEBUG = 2026-05-27 09:00；Release = 真实今天）；
//   - `tick` 用于驱动所有 computed property 在 View `.onChange` 时重新 fetch；
//   - 状态变更（goNext / goPrev / goToday / selectDay / confirmAttended）写入 stored prop
//     或 mutate Event，然后 refresh()。
//
// yesterday-missed 已在 P4 抽到 `YesterdayMissedService.computeMissed(now:)`。
// 这里通过可选注入：service 给了就委托；没给就 fallback 本地 fetch（保证既有测试不变）。

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class CalendarViewModel {

    // MARK: Stored

    /// SwiftData 上下文。View 通过 `@Environment(\.modelContext)` 拿到后注入。
    private let context: ModelContext

    /// 该 vm 视角下的「今天」时刻。DEBUG 默认 = LinoJTime.today()（2026-05-27 09:00），
    /// Release 默认 = `.now`。测试时可注入特定 Date。
    private let today: Date

    /// YesterdayMissedService 实例（可选）。P4 起由 App 注入；不传时 fallback 到本地 fetch。
    private let yesterdayMissedService: YesterdayMissedService?

    /// 当前展示的「7 天窗口」起点（默认 = today 的 00:00）。`goPrevWeek`/`goNextWeek`/`goToday` 改写它。
    public var weekStart: Date

    /// iOS 单日 list 当前选中的日期（startOfDay）。`selectDay(_)` 改写。
    /// 默认 = today 所在的 startOfDay（落在 `weekStart..<weekStart+7d` 之内）。
    public var selectedDay: Date

    /// Refresh tick —— 任意写入都让 Observation 把 computed property 标记为脏，下一次
    /// SwiftUI re-render 重新走 fetch。
    private var tick: Int = 0

    // MARK: Init

    /// - Parameters:
    ///   - context: SwiftData 上下文。
    ///   - today: 可注入的「今天」时刻；测试用。默认值通过 `LinoJTime.today()` 计算
    ///            （DEBUG → 2026-05-27 09:00；Release → `.now`）。
    public init(
        context: ModelContext,
        today: Date = LinoJTime.today(),
        yesterdayMissedService: YesterdayMissedService? = nil
    ) {
        self.context = context
        self.today = today
        self.yesterdayMissedService = yesterdayMissedService
        // 窗口起点 = today 的 startOfDay（滚动「未来 7 天」，today 落在第一列）。
        self.weekStart = Self.startOfWeek(containing: today)
        self.selectedDay = Self.calendar.startOfDay(for: today)
    }

    // MARK: Refresh hook

    /// View 层在 `@Query` 数据变化时调用，让所有 computed property 在下一帧重新 fetch。
    public func refresh() {
        tick &+= 1
    }

    // MARK: - Derived

    /// 窗口 7 天的 startOfDay 数组（today, today+1, …, today+6；切窗口后整体平移）。
    public var weekDays: [Date] {
        _ = tick
        return (0..<7).compactMap {
            Self.calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    /// 本周每天 → 事件列表的 dictionary。**始终 7 个 key**（即使某天为空，也保留 `[]`），
    /// 与 plan 验收契约一致。
    public var eventsByDay: [Date: [Event]] {
        _ = tick
        let events = allEvents()
        var result: [Date: [Event]] = [:]
        for dayStart in weekDays {
            guard let nextDayStart = Self.calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                result[dayStart] = []
                continue
            }
            let dayEvents = events
                .filter { $0.start >= dayStart && $0.start < nextDayStart }
                .sorted { $0.start < $1.start }
            result[dayStart] = dayEvents
        }
        return result
    }

    /// 窗口内事件总数（macOS 顶栏「X events · next 7 days」副标用）。
    public var weekTotal: Int {
        _ = tick
        return eventsByDay.values.reduce(0) { $0 + $1.count }
    }

    /// 昨日已结束 + 未确认参加的事件，按 start 升序。
    /// 仅当 weekStart 包含 today 时 UI 才显示「From yesterday」box，但本属性本身始终可读。
    /// P4 起优先委托 YesterdayMissedService；service 未注入时 fallback 到本地计算。
    public var yesterdayMissed: [Event] {
        _ = tick
        if let service = yesterdayMissedService {
            return service.computeMissed(now: today)
        }
        let startOfToday = Self.calendar.startOfDay(for: today)
        guard let startOfYesterday = Self.calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
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

    /// 当前 weekStart 是否 = today 起算窗口（决定 iOS 是否渲染 yesterday-missed box）。
    public var isViewingTodayWeek: Bool {
        let todayWeekStart = Self.startOfWeek(containing: today)
        return Self.calendar.isDate(weekStart, inSameDayAs: todayWeekStart)
    }

    /// 「今天」的 startOfDay。macOS today-column 高亮 / iOS Today pill / now 线判定都用它。
    public var todayStart: Date {
        Self.calendar.startOfDay(for: today)
    }

    /// 「现在」的精确时刻（用于 now 线的小数小时位置）。
    public var now: Date { today }

    // MARK: - Mutations

    /// 上一周。
    public func goPrevWeek() {
        guard let prev = Self.calendar.date(byAdding: .day, value: -7, to: weekStart) else { return }
        weekStart = prev
        // 切周时不改 selectedDay 的「日期数字」语义，但需要让它落在新周内：取新周的同一星期几。
        selectedDay = clampedSelectedDay(in: prev)
        refresh()
    }

    /// 下一周。
    public func goNextWeek() {
        guard let next = Self.calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }
        weekStart = next
        selectedDay = clampedSelectedDay(in: next)
        refresh()
    }

    /// reset 到 today 起算的 7 天窗口，selectedDay 重置为 today。
    public func goToday() {
        weekStart = Self.startOfWeek(containing: today)
        selectedDay = Self.calendar.startOfDay(for: today)
        refresh()
    }

    /// iOS 7-day strip 点击某天。传入的 Date 会被 normalized 到 startOfDay。
    public func selectDay(_ day: Date) {
        selectedDay = Self.calendar.startOfDay(for: day)
        // 不改 weekStart —— UI 调用方应保证选中的 day 落在当前周内。
        refresh()
    }

    /// 把 yesterday-missed box 中的某条事件标记为「已参加」。
    public func confirmAttended(_ event: Event) {
        event.attendedConfirmed = true
        try? context.save()
        refresh()
    }

    // MARK: - Internal helpers

    /// 拉全部 Event。failure 静默退回空数组。
    private func allEvents() -> [Event] {
        (try? context.fetch(FetchDescriptor<Event>())) ?? []
    }

    /// 切窗口时把 selectedDay 平移到新窗口内的同一「列偏移」。
    /// 例如旧 selectedDay 在窗口第 3 天，切下一周后映射到新窗口的第 3 天（平移 ±7）。
    /// 落不到（窗口跳变等极端情况）就退回新窗口起点。
    private func clampedSelectedDay(in newWeekStart: Date) -> Date {
        let cal = Self.calendar
        let oldOffset = cal.dateComponents([.day], from: weekStart, to: selectedDay).day ?? 0
        let clamped = min(max(oldOffset, 0), 6)
        return cal.date(byAdding: .day, value: clamped, to: newWeekStart) ?? newWeekStart
    }

    // MARK: - Static helpers (today 起算的滚动窗口)

    /// 本地化日历拷贝。Locale 跟系统走（确保 startOfDay 时区正确）。
    /// 注：窗口已改为 today 起算的滚动 7 天，不再依赖 `firstWeekday`；但保留 `firstWeekday = 2`
    /// 以维持 weekday 组件读取的一致性（不影响窗口计算，仅遗留无害设置）。
    public static let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday（窗口不依赖此值，保留以求一致）
        return cal
    }()

    /// 给定任意一个时刻，返回它的「滚动 7 天窗口」起点 —— 即该日的 startOfDay。
    /// （设计稿 Calendar 是 rolling next 7 days，窗口第一列就是 today；不回退到周一。）
    public static func startOfWeek(containing date: Date) -> Date {
        Self.calendar.startOfDay(for: date)
    }
}
