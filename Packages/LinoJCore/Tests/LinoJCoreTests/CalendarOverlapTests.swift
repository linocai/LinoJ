// CalendarOverlapTests.swift
// U5：验证 `CalendarViewModel.computeOverlapLayout(events:)` 纯函数的重叠归簇 + 贪心列分配。
//
// 该函数纯函数、不依赖 SwiftData / tick / ModelContext，单测直接调（无需起 ViewModel / 容器）。
// 重叠定义：A、B 重叠 ⇔ `A.start < B.end && B.start < A.end`（区间相交，端点相接不算）。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("CalendarOverlap — computeOverlapLayout 归簇 + 列分配")
@MainActor
struct CalendarOverlapTests {

    /// 给定基准日 + 时:分 构造一个 Event（同一天，分钟精度）。
    private func event(_ startHM: (Int, Int), _ endHM: (Int, Int), title: String = "E") -> Event {
        let cal = CalendarViewModel.calendar
        var dc = DateComponents()
        dc.year = 2026; dc.month = 5; dc.day = 27
        dc.hour = startHM.0; dc.minute = startHM.1
        let start = cal.date(from: dc) ?? .now
        dc.hour = endHM.0; dc.minute = endHM.1
        let end = cal.date(from: dc) ?? .now
        return Event(title: title, start: start, end: end, location: "")
    }

    // MARK: - 用例 1：相邻不重叠（端点相接）

    @Test("相邻不重叠（A 9-10, B 10-11，端点相接）→ 各 (0,1)")
    func adjacentNonOverlapping() {
        let a = event((9, 0), (10, 0), title: "A")
        let b = event((10, 0), (11, 0), title: "B")
        let layout = CalendarViewModel.computeOverlapLayout(events: [a, b])
        #expect(layout[a.id]?.column == 0)
        #expect(layout[a.id]?.columnCount == 1)
        #expect(layout[b.id]?.column == 0)
        #expect(layout[b.id]?.columnCount == 1)
    }

    // MARK: - 用例 2：完全重叠

    @Test("完全重叠（A 9-11, B 9-11）→ 一个 (0,2)、一个 (1,2)")
    func fullOverlap() {
        let a = event((9, 0), (11, 0), title: "A")
        let b = event((9, 0), (11, 0), title: "B")
        let layout = CalendarViewModel.computeOverlapLayout(events: [a, b])
        // columnCount 必须一致 = 2。
        #expect(layout[a.id]?.columnCount == 2)
        #expect(layout[b.id]?.columnCount == 2)
        // 两者列序号必须 {0, 1} 各占其一。
        let cols = Set([layout[a.id]?.column, layout[b.id]?.column])
        #expect(cols == Set([0, 1]))
    }

    // MARK: - 用例 3：链式重叠（C 复用 col0）

    @Test("链式重叠（A 9-10:30, B 10-11, C 10:45-12）→ A col0 / B col1 / C 复用 col0，columnCount=2")
    func chainedOverlap() {
        let a = event((9, 0), (10, 30), title: "A")
        let b = event((10, 0), (11, 0), title: "B")
        let c = event((10, 45), (12, 0), title: "C")
        let layout = CalendarViewModel.computeOverlapLayout(events: [a, b, c])
        // 同簇 columnCount 一致 = 2。
        #expect(layout[a.id]?.columnCount == 2)
        #expect(layout[b.id]?.columnCount == 2)
        #expect(layout[c.id]?.columnCount == 2)
        // A col0、B col1、C 复用 col0（A 已结束于 10:30 <= C.start 10:45）。
        #expect(layout[a.id]?.column == 0)
        #expect(layout[b.id]?.column == 1)
        #expect(layout[c.id]?.column == 0)
    }

    // MARK: - 用例 4：三件同时叠

    @Test("三件同时叠（A/B/C 都 9-10）→ 各 (0,3)/(1,3)/(2,3)")
    func tripleOverlap() {
        let a = event((9, 0), (10, 0), title: "A")
        let b = event((9, 0), (10, 0), title: "B")
        let c = event((9, 0), (10, 0), title: "C")
        let layout = CalendarViewModel.computeOverlapLayout(events: [a, b, c])
        #expect(layout[a.id]?.columnCount == 3)
        #expect(layout[b.id]?.columnCount == 3)
        #expect(layout[c.id]?.columnCount == 3)
        // 三列各占其一。
        let cols = Set([layout[a.id]?.column, layout[b.id]?.column, layout[c.id]?.column])
        #expect(cols == Set([0, 1, 2]))
    }

    // MARK: - 用例 5：两个独立簇互不影响

    @Test("两个独立簇（A/B 上午叠、C/D 下午叠，两簇不相交）→ 各自 columnCount 互不影响")
    func twoIndependentClusters() {
        let a = event((9, 0), (10, 0), title: "A")
        let b = event((9, 0), (10, 0), title: "B")
        let c = event((14, 0), (15, 0), title: "C")
        let d = event((14, 0), (15, 0), title: "D")
        let layout = CalendarViewModel.computeOverlapLayout(events: [a, b, c, d])
        // 上午簇 columnCount = 2，下午簇 columnCount = 2，互不影响。
        #expect(layout[a.id]?.columnCount == 2)
        #expect(layout[b.id]?.columnCount == 2)
        #expect(layout[c.id]?.columnCount == 2)
        #expect(layout[d.id]?.columnCount == 2)
        // 各簇内列序号 {0,1} 各占其一。
        #expect(Set([layout[a.id]?.column, layout[b.id]?.column]) == Set([0, 1]))
        #expect(Set([layout[c.id]?.column, layout[d.id]?.column]) == Set([0, 1]))
    }

    // MARK: - 用例 6：空天 / 单事件

    @Test("空天 → 空 map")
    func emptyDay() {
        let layout = CalendarViewModel.computeOverlapLayout(events: [])
        #expect(layout.isEmpty)
    }

    @Test("单事件 → (0,1)")
    func singleEvent() {
        let a = event((9, 0), (10, 0), title: "A")
        let layout = CalendarViewModel.computeOverlapLayout(events: [a])
        #expect(layout[a.id]?.column == 0)
        #expect(layout[a.id]?.columnCount == 1)
    }

    // MARK: - 附加：实例方法 overlapLayout(forDay:) 包装正确

    @Test("实例 overlapLayout(forDay:) 委托纯函数核心，与该天事件一致")
    func instanceWrapperMatchesPureCore() throws {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let a = event((9, 0), (11, 0), title: "A")
        let b = event((10, 0), (12, 0), title: "B")
        context.insert(a)
        context.insert(b)
        try context.save()
        // 事件锚定在 2026-05-27（见 event() 助手）；显式注入同一天作为「今天」，
        // 让 7 天窗口包含这两个事件、断言与系统真实日期无关、确定性。
        let vm = CalendarViewModel(context: context, today: SeedData.todaySimulated())
        vm.refresh()
        let cal = CalendarViewModel.calendar
        let dayStart = cal.startOfDay(for: a.start)
        let layout = vm.overlapLayout(forDay: dayStart)
        #expect(layout[a.id]?.columnCount == 2)
        #expect(layout[b.id]?.columnCount == 2)
        #expect(Set([layout[a.id]?.column, layout[b.id]?.column]) == Set([0, 1]))
        // 窗口外的某一天（无事件）→ 空 map。
        let emptyDay = cal.date(byAdding: .day, value: 3, to: dayStart) ?? dayStart
        #expect(vm.overlapLayout(forDay: emptyDay).isEmpty)
    }
}
