// HeadsUpServiceTests.swift
// 验证 HeadsUpService.tick() 在 in-memory context + 手工 seed 的几个边界场景下计算正确。
//
// 注意「now」：HeadsUpService 内部用 LinoJTime.now() 取「现在」时刻。DEBUG 构建下
// LinoJTime.now() == SeedData.todaySimulated() == 2026-05-27 09:00 local。
//
// 因此测试方法是：插入一个 Event，让它的 start = LinoJTime.now() + N 分钟，
// 然后 tick() 后断言 currentAlert.minutesUntil ≈ N。
// 不需要 mock 时间源，也不需要等 Timer 周期触发 —— tick() 是 public 的。

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
}
