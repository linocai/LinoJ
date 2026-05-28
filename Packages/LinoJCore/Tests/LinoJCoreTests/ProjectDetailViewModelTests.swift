// ProjectDetailViewModelTests.swift
// 验证 ProjectDetailViewModel 在 seed 数据上的派生量与 plan P3.5 验收一致。
//
// 数字推导（对照 SeedData.swift）：
//
// Project "LinoJ for macOS v1"（key "linoj"），members = [L, M, A]（3 个），createdAt = 2026-04-12。
//
// Work todos 中归属 "linoj" 的：
//   - w4 "Finalize macOS sidebar spec"  urgency=.urgent  done=false  → urgent
//   - w7 "Polish empty states"          urgency=.normal  done=false  → normal
//   - w8 "Audit color tokens"           urgency=.normal  done=false  → normal
// 验收要求：urgent count == 1；normal count == 2；completed count == 0；openCount == 3。
//
// Events 中归属 "linoj" 的（按 SeedData EventSpec 的 projectKey == "linoj"）：
//   - e1  "Morning standup"        (Tue)
//   - e3  "Design review — sidebar"(Tue)
//   - e8  "Eng sync"               (Thu)
//   - e10 "Shipping retro"         (Fri)
//   - e15 "LinoJ kickoff v2"       (Mon2)
// 还有 yesterday 的 y1 "Engineering standup" 也归 linoj。
// 总数 = 6（不是 plan 提示中说的 5；plan 描述只列了 e1/e3/e8/e10/e15 这 5 个本周 event，
// 但 y1 同样 project == linoj —— ProjectDetailViewModel 不按「本周」过滤，因此 yesterday
// 那条也会算进 linkedEventsCount）。
//
// → 用 `linkedEventsCount >= 5` 而非 `== 5` 作为下限断言；
//   另外验证「至少包含 5 个 plan 指定的事件标题」。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("ProjectDetailViewModel — seed-driven derived values for 'LinoJ for macOS v1'")
@MainActor
struct ProjectDetailViewModelTests {

    private func makeSeededContext() throws -> ModelContext {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)
        return context
    }

    /// 取出 seed 中的「LinoJ for macOS v1」项目实例。
    private func fetchLinoJProject(_ context: ModelContext) throws -> Project {
        let projects = try context.fetch(FetchDescriptor<Project>())
        guard let linoj = projects.first(where: { $0.title == "LinoJ for macOS v1" }) else {
            throw TestSetupError.linoJProjectMissing
        }
        return linoj
    }

    private enum TestSetupError: Error { case linoJProjectMissing }

    // MARK: - Todo counts

    @Test("LinoJ project: urgent == 1 (w4), normal == 2 (w7+w8), completed == 0")
    func todoCounts() throws {
        let context = try makeSeededContext()
        let linoj = try fetchLinoJProject(context)
        let vm = ProjectDetailViewModel(project: linoj, context: context)

        #expect(vm.urgentCount == 1)
        #expect(vm.urgent.first?.title == "Finalize macOS sidebar spec")

        #expect(vm.normal.count == 2)
        let normalTitles = Set(vm.normal.map(\.title))
        #expect(normalTitles == Set(["Polish empty states", "Audit color tokens"]))

        #expect(vm.doneCount == 0)
        #expect(vm.completed.isEmpty)

        // openCount = urgent + normal = 3
        #expect(vm.openCount == 3)
    }

    // MARK: - Linked events

    @Test("LinoJ project: linked events contain e1/e3/e8/e10/e15 and group by day")
    func linkedEvents() throws {
        let context = try makeSeededContext()
        let linoj = try fetchLinoJProject(context)
        let vm = ProjectDetailViewModel(project: linoj, context: context)

        // plan 在 P3.5 描述中显式提到 e1/e3/e8/e10/e15（共 5 个本周 events），加上 seed 中 y1
        // 也归属 linoj，因此总计 ≥ 5。
        #expect(vm.linkedEventsCount >= 5)

        // 把所有 linkedEventsByDay 的 events flatten 出来，提取 title 集合。
        let allEvents = vm.linkedEventsByDay.values.flatMap { $0 }
        let titles = Set(allEvents.map(\.title))

        let expectedThisWeek: Set<String> = [
            "Morning standup",
            "Design review — sidebar",
            "Eng sync",
            "Shipping retro",
            "LinoJ kickoff v2",
        ]
        #expect(expectedThisWeek.isSubset(of: titles))

        // 分组里每组都至少 1 个、且都按 start 升序。
        for (_, events) in vm.linkedEventsByDay {
            #expect(!events.isEmpty)
            for i in 1..<events.count {
                #expect(events[i - 1].start <= events[i].start)
            }
        }

        // linkedEventsCount 应该 = 所有分组 events 总和。
        let totalFromGroups = vm.linkedEventsByDay.values.reduce(0) { $0 + $1.count }
        #expect(vm.linkedEventsCount == totalFromGroups)
    }

    // MARK: - toggleDone

    @Test("toggleDone on an open todo increments doneCount by 1")
    func toggleDoneIncrementsDone() throws {
        let context = try makeSeededContext()
        let linoj = try fetchLinoJProject(context)
        let vm = ProjectDetailViewModel(project: linoj, context: context)

        let doneBefore = vm.doneCount
        let openBefore = vm.openCount
        guard let firstUrgent = vm.urgent.first else {
            Issue.record("seed should have at least one urgent todo on LinoJ project")
            return
        }
        vm.toggleDone(firstUrgent)

        #expect(vm.doneCount == doneBefore + 1)
        #expect(vm.openCount == openBefore - 1)
    }

    // MARK: - membersSinceText

    @Test("membersSinceText contains '3 members' and includes 'since '")
    func membersSinceText() throws {
        let context = try makeSeededContext()
        let linoj = try fetchLinoJProject(context)
        let vm = ProjectDetailViewModel(project: linoj, context: context)

        let text = vm.membersSinceText
        #expect(text.contains("3 members"))
        #expect(text.contains("since "))
    }
}
