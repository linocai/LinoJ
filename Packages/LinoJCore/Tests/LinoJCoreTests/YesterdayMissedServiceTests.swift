// YesterdayMissedServiceTests.swift
// 验证 YesterdayMissedService.computeMissed(now:) 的过滤窗口与 confirmAttended 的副作用。
//
// 用 SeedData 完整 seed 一遍，然后断言：
//   - 注入 now = SeedData.todaySimulated()（2026-05-27 09:00）时，结果包含且仅包含 yesterday 的 y1/y2；
//   - confirmAttended(y1) 后再 compute，y1 不再出现，剩下 y2。
//
// 注：computeMissed(now:) 的窗口完全由注入的 now 决定。测试显式传
// `SeedData.todaySimulated()`（而非 LinoJTime.today() 真实今天）让窗口对齐 2026-05-26
// yesterday seed，断言与系统真实日期无关、确定性。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("YesterdayMissedService — filter & confirm")
@MainActor
struct YesterdayMissedServiceTests {

    private func makeService() throws -> (YesterdayMissedService, ModelContext) {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)
        let service = YesterdayMissedService(context: context)
        return (service, context)
    }

    /// y1 与 y2 都是「昨天 2026-05-26」的事件 + attendedConfirmed == false。
    /// 其它本周事件（今天 / 未来）都不应该出现；上周事件也不应该出现（虽然 seed 数据里没有
    /// 更早的事件，但断言「only y1/y2」也覆盖了这个 case）。
    @Test("computeMissed returns exactly yesterday's unconfirmed events (y1, y2)")
    func testFiltersOnlyYesterday() throws {
        let (service, _) = try makeService()
        let missed = service.computeMissed(now: SeedData.todaySimulated())
        // SeedData 中昨日事件标题：y1 = "Engineering standup", y2 = "Coffee with Andrew"
        let titles = Set(missed.map(\.title))
        #expect(titles.contains("Engineering standup"))
        #expect(titles.contains("Coffee with Andrew"))
        #expect(missed.count == 2)
        // 不应包含今天的事件
        #expect(!titles.contains("Morning standup"))
    }

    /// confirmAttended 后该事件从 computeMissed 结果中消失。
    @Test("confirmAttended removes that event from subsequent compute")
    func testConfirmAttendedRemoves() throws {
        let (service, _) = try makeService()
        var missed = service.computeMissed(now: SeedData.todaySimulated())
        #expect(missed.count == 2)

        // 取第一条标为已参加
        let first = try #require(missed.first)
        service.confirmAttended(first)

        missed = service.computeMissed(now: SeedData.todaySimulated())
        #expect(missed.count == 1)
        #expect(!missed.contains(where: { $0.id == first.id }))
    }

    /// 注入特定 now（往后 30 天）—— seed 中所有事件（最晚是 today+7d 的 Mon2）现在全部成为
    /// 「过去未了结」（end < startOfToday + 未确认）。v1.2 窗口扩为「全部过去未了结」后，
    /// 旧版「只到昨天」会让结果为空（漏），新版应返回**全部** 16+2 条 = 18 条。
    @Test("P2: computeMissed with now = today + 30d returns ALL past unconfirmed (window widened)")
    func testComputeMissedWithFutureNowReturnsAllPast() throws {
        let (service, _) = try makeService()
        let monthLater = SeedData.todaySimulated().addingTimeInterval(30 * 24 * 60 * 60)
        let missed = service.computeMissed(now: monthLater)
        // 16 个本周事件 + 2 个 yesterday 事件全部成为过去未了结（均 attendedConfirmed=false）。
        #expect(missed.count == 18)
        // 仍按 start 升序。
        for i in 1..<missed.count {
            #expect(missed[i - 1].start <= missed[i].start)
        }
    }

    // MARK: - v1.2 P2: 前天结束的事件现在能出现（旧逻辑会漏）

    /// 隔离构造：一个「前天」结束的未确认事件，旧窗口（只到昨天）会漏掉，新窗口应包含。
    @Test("P2: an event that ended the day-before-yesterday now appears (old logic missed it)")
    func testDayBeforeYesterdayAppears() throws {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let service = YesterdayMissedService(context: context)

        let cal = Calendar.current
        let now = SeedData.todaySimulated()
        let startOfToday = cal.startOfDay(for: now)
        // 前天（startOfToday - 2 天）10:00–11:00。
        let dayBeforeYesterday = cal.date(byAdding: .day, value: -2, to: startOfToday)!
        let start = cal.date(byAdding: DateComponents(hour: 10), to: dayBeforeYesterday)!
        let end = cal.date(byAdding: DateComponents(hour: 11), to: dayBeforeYesterday)!
        let e = Event(title: "Old meeting", start: start, end: end, location: "")
        context.insert(e)
        try context.save()

        let missed = service.computeMissed(now: now)
        #expect(missed.count == 1)
        #expect(missed.first?.title == "Old meeting")
    }

    // MARK: - v1.2 P2: dismissMissed 第三态出口

    /// dismissMissed 后该事件从结果消失，且 attendedConfirmed 仍为 false（不撒谎打勾）。
    @Test("P2: dismissMissed removes event but keeps attendedConfirmed == false")
    func testDismissMissedKeepsAttendedFalse() throws {
        let (service, _) = try makeService()
        var missed = service.computeMissed(now: SeedData.todaySimulated())
        #expect(missed.count == 2)

        let first = try #require(missed.first)
        #expect(first.attendedConfirmed == false)
        service.dismissMissed(first)

        // 从结果中消失。
        missed = service.computeMissed(now: SeedData.todaySimulated())
        #expect(missed.count == 1)
        #expect(!missed.contains(where: { $0.id == first.id }))
        // attendedConfirmed 仍为 false —— 没被污染成「真出席」。
        #expect(first.attendedConfirmed == false)
        #expect(first.dismissedFromYesterday == true)
    }

    // MARK: - v1.2 P2: truncateForDisplay 纯函数

    /// 工具：构造 n 个升序 start 的事件（不入库，纯函数直测用）。
    private func makeSortedEvents(_ n: Int) -> [Event] {
        let base = SeedData.todaySimulated().addingTimeInterval(-100 * 24 * 60 * 60)
        return (0..<n).map { i in
            let start = base.addingTimeInterval(TimeInterval(i) * 3600)
            return Event(title: "E\(i)", start: start, end: start.addingTimeInterval(1800), location: "")
        }
    }

    @Test("P2: truncateForDisplay — count <= limit returns all, earlierCount 0")
    func testTruncateUnderLimit() {
        let events = makeSortedEvents(3)
        let (visible, earlier) = YesterdayMissedService.truncateForDisplay(events, limit: 5)
        #expect(visible.count == 3)
        #expect(earlier == 0)
        #expect(visible.map(\.title) == ["E0", "E1", "E2"])
    }

    @Test("P2: truncateForDisplay — count > limit keeps most-recent limit, earlierCount = rest")
    func testTruncateOverLimit() {
        // 8 条，limit 5 → 取 start 最大的 5 条（E3..E7），earlier = 3。
        let events = makeSortedEvents(8)
        let (visible, earlier) = YesterdayMissedService.truncateForDisplay(events, limit: 5)
        #expect(visible.count == 5)
        #expect(earlier == 3)
        // 仍按 start 升序；保留的是离今天最近（start 最大）的 5 条。
        #expect(visible.map(\.title) == ["E3", "E4", "E5", "E6", "E7"])
    }

    @Test("P2: truncateForDisplay — exactly at limit returns all, earlierCount 0")
    func testTruncateAtLimit() {
        let events = makeSortedEvents(5)
        let (visible, earlier) = YesterdayMissedService.truncateForDisplay(events, limit: 5)
        #expect(visible.count == 5)
        #expect(earlier == 0)
    }
}
