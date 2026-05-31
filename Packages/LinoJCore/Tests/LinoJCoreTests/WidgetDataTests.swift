// WidgetDataTests.swift
// U9.3（v1.1）验收：widget timeline 的纯计算函数。
//
// 只测**纯函数**（输入值类型 → 输出值类型）：`upcomingEventsToday` / `counts` / `nextReloadDate`
// / `nextHourBoundary`。真实 App Group 容器 + `makeWidgetContainer` headless 取不到，留真机验收。

import Foundation
import Testing
@testable import LinoJCore

@Suite("U9.3 — Widget timeline 纯计算")
struct WidgetDataTests {

    /// 固定一个有 DST 稳定性的日历（用 current；测试都用相对偏移，不依赖绝对时区）。
    private let cal = Calendar.current

    private func item(_ title: String, startOffsetMinutes: Int, durationMinutes: Int = 60, now: Date) -> WidgetEventItem {
        let start = now.addingTimeInterval(TimeInterval(startOffsetMinutes * 60))
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        return WidgetEventItem(id: UUID(), title: title, location: "Rm", start: start, end: end)
    }

    // MARK: upcomingEventsToday

    @Test("今日接下来事件：过滤已过去 + 截到上限 + 升序")
    func upcomingFiltersAndSorts() {
        // 锚定到「今天中午」，留足前后 look-ahead 空间不跨日。
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date.now)!
        let events = [
            item("已过去", startOffsetMinutes: -30, now: noon),   // start < now → 排除
            item("第三", startOffsetMinutes: 180, now: noon),
            item("第一", startOffsetMinutes: 20, now: noon),
            item("第二", startOffsetMinutes: 90, now: noon),
            item("第四", startOffsetMinutes: 200, now: noon),     // 超过上限 3 → 截掉
        ]
        let result = WidgetData.upcomingEventsToday(from: events, now: noon, calendar: cal)
        #expect(result.count == 3, "上限 3")
        #expect(result.map(\.title) == ["第一", "第二", "第三"], "按 start 升序、排除已过去、截到 3")
    }

    @Test("明天的事件不算今日 look-ahead")
    func excludesTomorrow() {
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date.now)!
        // +20h 一定落到明天。
        let events = [item("明天", startOffsetMinutes: 20 * 60, now: noon)]
        let result = WidgetData.upcomingEventsToday(from: events, now: noon, calendar: cal)
        #expect(result.isEmpty, "跨日事件不进今日 look-ahead")
    }

    @Test("无事件 → 空")
    func emptyWhenNoEvents() {
        let result = WidgetData.upcomingEventsToday(from: [], now: .now, calendar: cal)
        #expect(result.isEmpty)
    }

    @Test("正在进行（start == now）算「接下来」（>= now）")
    func includesStartingNow() {
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date.now)!
        let events = [item("此刻开始", startOffsetMinutes: 0, now: noon)]
        let result = WidgetData.upcomingEventsToday(from: events, now: noon, calendar: cal)
        #expect(result.count == 1, "start == now 视为接下来（>= now）")
    }

    // MARK: counts（复用 Main 语义）

    @Test("open / urgent 计数：只数未完成，urgent 是未完成子集")
    func countsOpenAndUrgent() {
        let todos: [(done: Bool, urgency: Urgency)] = [
            (false, .urgent),
            (false, .urgent),
            (false, .normal),
            (true, .urgent),    // done → 不计 open，也不计 urgent
            (true, .normal),
        ]
        let c = WidgetData.counts(fromTodos: todos)
        #expect(c.open == 3, "未完成 3 个")
        #expect(c.urgent == 2, "未完成且 urgent 2 个（done 的 urgent 不计）")
    }

    @Test("全空 → zero")
    func countsZero() {
        #expect(WidgetData.counts(fromTodos: []) == .zero)
    }

    // MARK: nextHourBoundary / nextReloadDate

    @Test("下一个整点严格晚于 now（整点也前进一格）")
    func nextHourStrictlyAfter() {
        let onHour = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date.now)!
        let next = WidgetData.nextHourBoundary(after: onHour, calendar: cal)
        #expect(next > onHour)
        let comps = cal.dateComponents([.hour, .minute, .second], from: next)
        #expect(comps.hour == 10 && comps.minute == 0 && comps.second == 0, "9:00 → 10:00")

        let midHour = cal.date(bySettingHour: 9, minute: 37, second: 0, of: Date.now)!
        let next2 = WidgetData.nextHourBoundary(after: midHour, calendar: cal)
        let comps2 = cal.dateComponents([.hour, .minute], from: next2)
        #expect(comps2.hour == 10 && comps2.minute == 0, "9:37 → 10:00")
    }

    @Test("nextReloadDate：取整点与下一个事件起点中较早者")
    func reloadDatePicksEarlier() {
        let nine = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date.now)!
        let nextHour = WidgetData.nextHourBoundary(after: nine, calendar: cal) // 10:00
        // 事件在 9:20（早于 10:00）→ 取 9:20。
        let eventEarly = nine.addingTimeInterval(20 * 60)
        let r1 = WidgetData.nextReloadDate(after: nine, upcomingEventStarts: [eventEarly], calendar: cal)
        #expect(r1 == eventEarly, "事件早于整点 → 取事件起点")

        // 事件在 11:30（晚于 10:00）→ 取整点 10:00。
        let eventLate = nine.addingTimeInterval(150 * 60)
        let r2 = WidgetData.nextReloadDate(after: nine, upcomingEventStarts: [eventLate], calendar: cal)
        #expect(r2 == nextHour, "事件晚于整点 → 取整点")

        // 无未来事件 → 退化整点。
        let r3 = WidgetData.nextReloadDate(after: nine, upcomingEventStarts: [], calendar: cal)
        #expect(r3 == nextHour, "无事件 → 退化整点")

        // 只有过去事件 → 退化整点。
        let past = nine.addingTimeInterval(-30 * 60)
        let r4 = WidgetData.nextReloadDate(after: nine, upcomingEventStarts: [past], calendar: cal)
        #expect(r4 == nextHour, "只有过去事件 → 退化整点")
    }

    // MARK: 快照兜底

    @Test("placeholder 是空事件 + 0 计数")
    func placeholderIsEmpty() {
        let p = WidgetSnapshot.placeholder()
        #expect(p.upcomingEvents.isEmpty)
        #expect(p.counts == .zero)
    }
}
