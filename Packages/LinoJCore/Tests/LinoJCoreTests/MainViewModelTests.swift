// MainViewModelTests.swift
// 验证 MainViewModel 在 seed 数据上的派生量与 plan P3.2 验收数字一致。
//
// 数字来源（PROJECT_PLAN.md 变更日志）：
//   - openCount == 14（personal 7 + work 9 - 2 done = 14；plan 列表里只有 schedule dentist 与
//     Draft Q3 OKR doc 是 done = true）。
//   - urgentCount == 5（personal urgent open 2 + company urgent open 3，见 CountersTests.urgentOpenBreakdown）。
//   - todayEventsCount == 4（Tue 的 4 场会议）。
//   - next7DaysGrouped.count == 7（永远 7 项）。
//
// 注：plan P3.2 hint 文案给出「openCount == 16」是把 done 算进去了；
// 实际 ViewModel 的 openCount 定义是 `done == false`，所以等于 14（16 - 2）。
// 照实写测试，并在汇报里说明此差异。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("MainViewModel — seed-driven derived counts")
@MainActor
struct MainViewModelTests {

    private func makeSeededVM() throws -> (MainViewModel, ModelContext) {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)
        let vm = MainViewModel(context: context)
        return (vm, context)
    }

    @Test("openCount == 14 after seed (16 todos - 2 done)")
    func openCountAfterSeed() throws {
        let (vm, _) = try makeSeededVM()
        #expect(vm.openCount == 14)
    }

    @Test("urgentCount == 5 after seed")
    func urgentCountAfterSeed() throws {
        let (vm, _) = try makeSeededVM()
        #expect(vm.urgentCount == 5)
    }

    @Test("todayEventsCount == 4 (Tue events)")
    func todayEventsCountAfterSeed() throws {
        let (vm, _) = try makeSeededVM()
        #expect(vm.todayEventsCount == 4)
    }

    @Test("next7DaysGrouped has exactly 7 entries")
    func next7DaysHasSevenEntries() throws {
        let (vm, _) = try makeSeededVM()
        let groups = vm.next7DaysGrouped
        #expect(groups.count == 7)
        // 第一项应该 = startOfToday；之后每项严格 + 1 day。
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: LinoJTime.today())
        #expect(groups.first?.day == startOfToday)
        for index in 1..<groups.count {
            let prev = groups[index - 1].day
            let curr = groups[index].day
            let dayDiff = calendar.dateComponents([.day], from: prev, to: curr).day
            #expect(dayDiff == 1, "day \(index) should be +1 from day \(index - 1)")
        }
    }

    @Test("urgentTodos + normalTodos = openCount; no completed leaks")
    func urgentNormalPartition() throws {
        let (vm, _) = try makeSeededVM()
        let urgent = vm.urgentTodos
        let normal = vm.normalTodos
        #expect(urgent.count + normal.count == vm.openCount)
        for todo in urgent + normal {
            #expect(todo.done == false)
        }
    }

    @Test("toggleDone flips state, openCount drops, refresh re-reads")
    func toggleDoneMutation() throws {
        let (vm, _) = try makeSeededVM()
        let before = vm.openCount
        guard let firstNormal = vm.normalTodos.first else {
            Issue.record("seed should have at least one normal open todo")
            return
        }
        vm.toggleDone(firstNormal)
        #expect(vm.openCount == before - 1)
    }

    @Test("yesterdayMissed contains 2 unconfirmed events from yesterday")
    func yesterdayMissedFromSeed() throws {
        let (vm, _) = try makeSeededVM()
        let missed = vm.yesterdayMissed
        #expect(missed.count == 2)
        let titles = Set(missed.map(\.title))
        #expect(titles == Set(["Engineering standup", "Coffee with Andrew"]))
    }

    @Test("headsUp is nil in P3.2 (HeadsUpService comes in P4)")
    func headsUpStaysNilInP3_2() throws {
        let (vm, _) = try makeSeededVM()
        #expect(vm.headsUp == nil)
    }

    // MARK: - W2: includeCompletedInCounts

    @Test("W2: openCount includes done todos when includeCompletedInCounts == true (14 → 16)")
    func openCountIncludesCompletedWhenFlagOn() throws {
        let (vm, _) = try makeSeededVM()
        // 默认 flag = false → 仅未完成 = 14。
        #expect(vm.includeCompletedInCounts == false)
        #expect(vm.openCount == 14)
        // 打开 flag → 含 done 的全部 = 16（seed 总 16 todos，含 2 done）。
        vm.includeCompletedInCounts = true
        #expect(vm.openCount == 16)
        // 关回 false 恢复。
        vm.includeCompletedInCounts = false
        #expect(vm.openCount == 14)
    }

    // MARK: - W2: showYesterdayMissed gate

    @Test("W2: yesterdayMissed is empty when showYesterdayMissed == false (fallback path)")
    func yesterdayMissedGatedOffFallback() throws {
        let (vm, _) = try makeSeededVM()
        // 默认 true → seed 有 2 条。
        #expect(vm.showYesterdayMissed == true)
        #expect(vm.yesterdayMissed.count == 2)
        // 关掉 → 短路为空。
        vm.showYesterdayMissed = false
        #expect(vm.yesterdayMissed.isEmpty)
        // 打开恢复。
        vm.showYesterdayMissed = true
        #expect(vm.yesterdayMissed.count == 2)
    }

    @Test("W2: yesterdayMissed gate also short-circuits the service-backed path")
    func yesterdayMissedGatedOffWithService() throws {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)
        let service = YesterdayMissedService(context: context)
        let vm = MainViewModel(context: context, yesterdayMissedService: service)
        #expect(vm.yesterdayMissed.count == 2)
        vm.showYesterdayMissed = false
        #expect(vm.yesterdayMissed.isEmpty)
    }

    // MARK: - W4: deleteEvent / unconfirmAttended

    @Test("W4: deleteEvent removes the event from context")
    func deleteEventRemovesFromContext() throws {
        let (vm, context) = try makeSeededVM()
        guard let target = vm.todayEvents.first else {
            Issue.record("seed should produce at least one event today")
            return
        }
        let targetID = target.id
        let before = vm.todayEventsCount
        vm.deleteEvent(target)

        let remaining = try context.fetch(FetchDescriptor<Event>())
        #expect(remaining.contains(where: { $0.id == targetID }) == false)
        #expect(vm.todayEventsCount == before - 1)
    }

    @Test("W4: confirmAttended → unconfirmAttended flips attendedConfirmed back")
    func unconfirmAttendedReverts() throws {
        let (vm, _) = try makeSeededVM()
        guard let target = vm.todayEvents.first else {
            Issue.record("seed should produce at least one event today")
            return
        }
        #expect(target.attendedConfirmed == false)
        vm.confirmAttended(target)
        #expect(target.attendedConfirmed == true)
        vm.unconfirmAttended(target)
        #expect(target.attendedConfirmed == false)
    }
}
