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

    /// 注入特定 now（往后 30 天）—— seed 中所有事件（最晚是 today+7d 的 Mon2）都已经成为
    /// 23+ 天前的事，全部落在 yesterday 窗口之外，结果应为空。
    @Test("computeMissed with now = today + 30d returns empty (all seed events far past)")
    func testComputeMissedWithFutureNow() throws {
        let (service, _) = try makeService()
        let monthLater = SeedData.todaySimulated().addingTimeInterval(30 * 24 * 60 * 60)
        let missed = service.computeMissed(now: monthLater)
        #expect(missed.isEmpty)
    }
}
