// SeedDataTests.swift
// 单测 SeedData 的辅助函数与幂等性，以及 yesterdayEvents 的时间约束。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("SeedData helpers & invariants")
@MainActor
struct SeedDataTests {

    private func makeSeededContext() throws -> ModelContext {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)
        return context
    }

    @Test("hoursDecimalToDate 精度")
    func hoursDecimalConversion() throws {
        let calendar = Calendar.current
        // 锚点选 todaySimulated() 的日历日（2026-05-27），但取 startOfDay 让小时清零。
        let day = calendar.startOfDay(for: SeedData.todaySimulated())

        let cases: [(decimal: Double, expectedHour: Int, expectedMinute: Int)] = [
            (0.0, 0, 0),
            (9.5, 9, 30),
            (14.0, 14, 0),
            (19.5, 19, 30),
            (23.99, 23, 59),
        ]
        for c in cases {
            let date = SeedData.hoursDecimalToDate(day: day, decimal: c.decimal)
            let components = calendar.dateComponents([.hour, .minute], from: date)
            #expect(components.hour == c.expectedHour,
                    "decimal \(c.decimal) hour 应为 \(c.expectedHour)，实际 \(components.hour ?? -1)")
            #expect(components.minute == c.expectedMinute,
                    "decimal \(c.decimal) minute 应为 \(c.expectedMinute)，实际 \(components.minute ?? -1)")
        }
    }

    @Test("idempotent seed: 连续两次调用计数不翻倍")
    func idempotentSeed() throws {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)
        let firstTodoCount = try context.fetchCount(FetchDescriptor<Todo>())
        let firstEventCount = try context.fetchCount(FetchDescriptor<Event>())
        let firstProjectCount = try context.fetchCount(FetchDescriptor<Project>())

        try SeedData.seedIfEmpty(context)
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == firstTodoCount)
        #expect(try context.fetchCount(FetchDescriptor<Event>()) == firstEventCount)
        #expect(try context.fetchCount(FetchDescriptor<Project>()) == firstProjectCount)
    }

    @Test("yesterday events end before today start, attendedConfirmed == false")
    func yesterdayEventsInvariants() throws {
        let context = try makeSeededContext()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: SeedData.todaySimulated())
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday

        let events = try context.fetch(FetchDescriptor<Event>())
        let yesterdayEvents = events.filter { $0.end < startOfToday && $0.end > startOfYesterday }
        // data.js 中明确的 yesterdayEvents = y1 (Engineering standup) + y2 (Coffee with Andrew) = 2 项
        try #require(yesterdayEvents.count == 2)
        for event in yesterdayEvents {
            #expect(event.end < startOfToday)
            #expect(event.attendedConfirmed == false)
        }

        let titles = Set(yesterdayEvents.map(\.title))
        #expect(titles == Set(["Engineering standup", "Coffee with Andrew"]))
    }
}
