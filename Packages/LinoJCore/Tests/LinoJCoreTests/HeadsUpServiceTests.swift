// HeadsUpServiceTests.swift
// 验证 HeadsUpService.tick() 在 in-memory context + 手工 seed 的几个边界场景下计算正确。
//
// 注意「now」：HeadsUpService 内部用 LinoJTime.now() 取「现在」时刻。LinoJTime.now()
// **始终** 返回真实物理时间（DEBUG/Release 一致，不冻结）。
//
// 因此测试方法是：插入一个 Event，让它的 start = LinoJTime.now() + N 分钟（相对真实
// now 锚定），然后 tick() 后断言 currentAlert.minutesUntil ≈ N。这套相对锚定与系统真实
// 日期无关、自洽，不需要 mock 时间源，也不需要等 Timer 周期触发 —— tick() 是 public 的。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("HeadsUpService — tick & window logic")
@MainActor
struct HeadsUpServiceTests {

    /// 构造一个空 in-memory context + service + 注入若干 Event。
    /// - Parameter events: (offsetSecondsFromNow: 偏移量, durationSeconds: 时长) 列表。
    ///                     start 越靠前的越早；location/title 自动编号。
    private func makeService(events specs: [(offset: TimeInterval, duration: TimeInterval, title: String, location: String)])
    throws -> (HeadsUpService, ModelContext, [Event]) {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let now = LinoJTime.now()
        var insertedEvents: [Event] = []
        for spec in specs {
            let start = now.addingTimeInterval(spec.offset)
            let end = start.addingTimeInterval(spec.duration)
            let event = Event(
                title: spec.title,
                start: start,
                end: end,
                location: spec.location
            )
            context.insert(event)
            insertedEvents.append(event)
        }
        try context.save()
        let service = HeadsUpService(context: context, leadMinutes: 30)
        return (service, context, insertedEvents)
    }

    // MARK: - 在 60 分钟窗口内

    /// plan 验收：now=09:20，e1 start=09:30 → minutesUntil == 10。
    /// 我们用「now = LinoJTime.now()，event start = now + 600s（10 分钟）」等价构造。
    @Test("Event 10 min from now → currentAlert.minutesUntil == 10")
    func testWithin60Min() throws {
        let (service, _, events) = try makeService(events: [
            (offset: 600, duration: 1800, title: "Morning standup", location: "Zoom"),
        ])
        service.tick()
        let alert = try #require(service.currentAlert)
        #expect(alert.minutesUntil == 10)
        #expect(alert.title == "Morning standup")
        #expect(alert.location == "Zoom")
        #expect(alert.eventID == events[0].id)
    }

    /// 多事件时取最早 start。
    @Test("Multiple upcoming events → picks earliest start")
    func testPicksEarliestUpcoming() throws {
        let (service, _, events) = try makeService(events: [
            (offset: 1800, duration: 1800, title: "Later", location: "L2"),
            (offset: 300,  duration: 1800, title: "Sooner", location: "L1"),
            (offset: 3000, duration: 1800, title: "Latest", location: "L3"),
        ])
        service.tick()
        let alert = try #require(service.currentAlert)
        // index 1 的 "Sooner" 是 offset 最小的那个
        #expect(alert.eventID == events[1].id)
        #expect(alert.minutesUntil == 5)
    }

    // MARK: - 60 分钟窗口外

    /// plan 验收：start - now > 60 min → currentAlert == nil。
    @Test("Event > 60 min away → currentAlert == nil")
    func testOutsideWindow() throws {
        let (service, _, _) = try makeService(events: [
            // 90 分钟后才开始
            (offset: 5400, duration: 1800, title: "Far future", location: "Room"),
        ])
        service.tick()
        #expect(service.currentAlert == nil)
    }

    /// 事件已结束 → currentAlert == nil。
    @Test("Event already ended → currentAlert == nil")
    func testEventAlreadyEnded() throws {
        let (service, _, _) = try makeService(events: [
            // 2 小时前开始，1 小时前结束
            (offset: -7200, duration: 3600, title: "Past meeting", location: "Past"),
        ])
        service.tick()
        #expect(service.currentAlert == nil)
    }

    /// 事件正在进行中（start < now < end） → 仍显示 alert，minutesUntil == 0。
    @Test("Event in progress → currentAlert.minutesUntil == 0")
    func testEventInProgress() throws {
        let (service, _, events) = try makeService(events: [
            // 5 分钟前开始，半小时后结束
            (offset: -300, duration: 1800, title: "Standup", location: "Zoom"),
        ])
        service.tick()
        let alert = try #require(service.currentAlert)
        #expect(alert.minutesUntil == 0)
        #expect(alert.eventID == events[0].id)
    }

    // MARK: - Snooze

    /// plan 验收：snooze() 后 currentAlert == nil。
    @Test("snooze() clears currentAlert and subsequent tick keeps it nil")
    func testSnooze() throws {
        let (service, _, _) = try makeService(events: [
            (offset: 600, duration: 1800, title: "Standup", location: "Zoom"),
        ])
        service.tick()
        #expect(service.currentAlert != nil)

        service.snooze()
        #expect(service.currentAlert == nil)

        // snooze 10 分钟内，tick 仍然保持 nil
        service.tick()
        #expect(service.currentAlert == nil)
    }

    // MARK: - U6 今日时间冲突扫描

    /// 工具：构造一个含 N 件「今天」事件的 service，并返回 (service, context, events)。
    ///
    /// 事件锚定到 **`LinoJTime.now()` 所在日历日的固定时-分**（startOfDay + hour:minute），
    /// 而非「相对 now 的偏移」—— 这样无论测试在一天的什么时刻跑，事件都稳定落在「今天」
    /// 这一日历日内（不跨午夜），冲突扫描的日过滤口径确定。
    /// `events` spec：(hour, minute, durationMinutes, title)。
    private func makeServiceWithTodayEvents(
        _ specs: [(hour: Int, minute: Int, durationMinutes: Int, title: String)]
    ) throws -> (HeadsUpService, ModelContext, [Event]) {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: LinoJTime.now())
        var inserted: [Event] = []
        for spec in specs {
            let start = calendar.date(
                byAdding: DateComponents(hour: spec.hour, minute: spec.minute),
                to: startOfToday
            )!
            let end = start.addingTimeInterval(TimeInterval(spec.durationMinutes) * 60)
            let event = Event(title: spec.title, start: start, end: end, location: "")
            context.insert(event)
            inserted.append(event)
        }
        try context.save()
        let service = HeadsUpService(context: context, leadMinutes: 30)
        return (service, context, inserted)
    }

    /// plan 验收：今天两件时间撞车 → conflictAlert 非 nil、count == 2、atTime = 较早 start。
    @Test("Two overlapping events today → conflictAlert count == 2, atTime = earlier start")
    func testConflictTwoOverlapping() throws {
        let (service, _, events) = try makeServiceWithTodayEvents([
            (hour: 16, minute: 0,  durationMinutes: 60, title: "Supermarket"),  // 16:00–17:00
            (hour: 16, minute: 30, durationMinutes: 60, title: "444"),          // 16:30–17:30（重叠）
        ])
        service.tick()
        let conflict = try #require(service.conflictAlert)
        #expect(conflict.count == 2)
        #expect(conflict.atTime == events[0].start)   // 簇内最早 start（16:00）
    }

    /// 今天无冲突（两件事件不重叠）→ conflictAlert == nil。
    @Test("Non-overlapping events today → conflictAlert == nil")
    func testNoConflict() throws {
        let (service, _, _) = try makeServiceWithTodayEvents([
            (hour: 9,  minute: 0, durationMinutes: 30, title: "A"),  // 09:00–09:30
            (hour: 14, minute: 0, durationMinutes: 30, title: "B"),  // 14:00–14:30（不重叠）
        ])
        service.tick()
        #expect(service.conflictAlert == nil)
    }

    /// 没有任何今天事件 → conflictAlert == nil。
    @Test("No events at all → conflictAlert == nil")
    func testNoEventsNoConflict() throws {
        let (service, _, _) = try makeServiceWithTodayEvents([])
        service.tick()
        #expect(service.conflictAlert == nil)
    }

    /// 最早簇选取：今天有两个冲突簇（早簇 size 2 + 晚簇 size 3），取**最早**那个簇。
    @Test("Two conflict clusters today → picks earliest cluster")
    func testEarliestClusterPicked() throws {
        let (service, _, events) = try makeServiceWithTodayEvents([
            // 早簇 09:00–10:00 + 09:20–10:20（重叠）
            (hour: 9,  minute: 0,  durationMinutes: 60, title: "Early-A"),
            (hour: 9,  minute: 20, durationMinutes: 60, title: "Early-B"),
            // 晚簇 15:00 / 15:10 / 15:20 各 60min（三件传递重叠），与早簇不相接
            (hour: 15, minute: 0,  durationMinutes: 60, title: "Late-A"),
            (hour: 15, minute: 10, durationMinutes: 60, title: "Late-B"),
            (hour: 15, minute: 20, durationMinutes: 60, title: "Late-C"),
        ])
        service.tick()
        let conflict = try #require(service.conflictAlert)
        #expect(conflict.count == 2)                   // 早簇 size 2，不是晚簇的 3
        #expect(conflict.atTime == events[0].start)    // 早簇最早 start（Early-A，09:00）
    }

    /// 三件传递性重叠的事件 → count == 3（复用 U5 computeOverlapLayout 的归簇语义）。
    @Test("Three transitively overlapping events today → count == 3")
    func testThreeOverlapCluster() throws {
        let (service, _, events) = try makeServiceWithTodayEvents([
            (hour: 10, minute: 0,  durationMinutes: 60, title: "A"),  // 10:00–11:00
            (hour: 10, minute: 10, durationMinutes: 60, title: "B"),  // 10:10–11:10
            (hour: 10, minute: 20, durationMinutes: 60, title: "C"),  // 10:20–11:20
        ])
        service.tick()
        let conflict = try #require(service.conflictAlert)
        #expect(conflict.count == 3)
        #expect(conflict.atTime == events[0].start)
    }

    /// 端点相接（A.end == B.start）不算冲突 —— 与 U5 computeOverlapLayout 一致（区间相交，端点相接不算）。
    @Test("Adjacent events (A.end == B.start) → no conflict")
    func testAdjacentNoConflict() throws {
        let (service, _, _) = try makeServiceWithTodayEvents([
            (hour: 11, minute: 0, durationMinutes: 60, title: "A"),  // 11:00–12:00
            (hour: 12, minute: 0, durationMinutes: 60, title: "B"),  // 12:00–13:00（端点相接）
        ])
        service.tick()
        #expect(service.conflictAlert == nil)
    }

    /// computeConflictAlert 纯函数直测：注入空数组 → nil（不依赖 SwiftData）。
    @Test("computeConflictAlert(events: []) → nil (pure function)")
    func testComputeConflictAlertEmpty() {
        #expect(HeadsUpService.computeConflictAlert(events: [], now: LinoJTime.now()) == nil)
    }

    // MARK: - v1.2 P4: +N 更多角标 + 进行中文案

    /// 窗口内 3 个事件 → moreCount == 2，currentAlert 仍是最早那条（单条不堆叠）。
    @Test("P4: three events in window → moreCount == 2, currentAlert is earliest")
    func testMoreCountThreeInWindow() throws {
        let (service, _, events) = try makeService(events: [
            (offset: 600,  duration: 1800, title: "First",  location: "L1"),  // +10 min
            (offset: 1200, duration: 1800, title: "Second", location: "L2"),  // +20 min
            (offset: 1800, duration: 1800, title: "Third",  location: "L3"),  // +30 min
        ])
        service.tick()
        let alert = try #require(service.currentAlert)
        // 仍只渲染最早那条。
        #expect(alert.eventID == events[0].id)
        #expect(alert.title == "First")
        // 窗口内 3 条 → moreCount = 3 - 1 = 2。
        #expect(alert.moreCount == 2)
        // 未开始 → 非进行中。
        #expect(alert.isOngoing == false)
    }

    /// 单个即将开始事件 → moreCount == 0（窗口内只有 1 条）。
    @Test("P4: single upcoming event → moreCount == 0")
    func testMoreCountSingle() throws {
        let (service, _, _) = try makeService(events: [
            (offset: 600, duration: 1800, title: "Solo", location: "L"),
        ])
        service.tick()
        let alert = try #require(service.currentAlert)
        #expect(alert.moreCount == 0)
    }

    /// 进行中事件（start 已过、end 未到）→ isOngoing == true，remainingMinutes 正确，
    /// minutesUntil == 0（不出现负数 / 误导）。
    @Test("P4: ongoing event → isOngoing true, remainingMinutes correct, minutesUntil 0")
    func testOngoingRemainingMinutes() throws {
        // 5 分钟前开始，总时长 30 分钟 → 还剩 ~25 分钟。
        let (service, _, events) = try makeService(events: [
            (offset: -300, duration: 1800, title: "Standup", location: "Zoom"),
        ])
        service.tick()
        let alert = try #require(service.currentAlert)
        #expect(alert.eventID == events[0].id)
        #expect(alert.isOngoing == true)
        #expect(alert.minutesUntil == 0)
        // 还剩 25 分钟（ceil((1800-300)/60) = 25）。允许 ±1 容忍真实 now 漂移。
        #expect(alert.remainingMinutes >= 24 && alert.remainingMinutes <= 25)
        // 进行中事件唯一时不该有 +N。
        #expect(alert.moreCount == 0)
    }
}
