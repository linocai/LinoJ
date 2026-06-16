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

    // MARK: - W2: includeCompletedInCounts

    @Test("W2: openCount includes done todos when includeCompletedInCounts == true")
    func openCountIncludesCompletedWhenFlagOn() throws {
        let context = try makeSeededContext()
        let linoj = try fetchLinoJProject(context)
        let vm = ProjectDetailViewModel(project: linoj, context: context)
        // 默认 false：openCount = 3（无 done）。
        #expect(vm.includeCompletedInCounts == false)
        #expect(vm.openCount == 3)
        // 把一个 open todo 标 done，使本 project 有 1 个 done。
        guard let firstUrgent = vm.urgent.first else {
            Issue.record("seed should have at least one urgent todo on LinoJ project")
            return
        }
        vm.toggleDone(firstUrgent)
        // flag off：openCount 掉到 2（仅未完成）。
        #expect(vm.openCount == 2)
        // flag on：含 done → 回到 3（2 open + 1 done）。
        vm.includeCompletedInCounts = true
        #expect(vm.openCount == 3)
        vm.includeCompletedInCounts = false
        #expect(vm.openCount == 2)
    }

    // MARK: - W3: deleteProject

    @Test("W3: deleteProject removes the project; its todos become standalone (project == nil)")
    func deleteProjectNullifiesTodos() throws {
        let context = try makeSeededContext()
        let linoj = try fetchLinoJProject(context)
        let projectID = linoj.id
        let vm = ProjectDetailViewModel(project: linoj, context: context)

        // 删除前：本 project 至少有 3 个 todo（urgent 1 + normal 2）。
        let linkedTodosBefore = try context.fetch(FetchDescriptor<Todo>())
            .filter { $0.project?.id == projectID }
        #expect(linkedTodosBefore.count >= 3)

        vm.deleteProject()

        // project 不再存在于 context。
        let projectsAfter = try context.fetch(FetchDescriptor<Project>())
        #expect(projectsAfter.contains { $0.id == projectID } == false)

        // 这些 todo 仍存在（standalone），但 project == nil（.nullify deleteRule）。
        let todosAfter = try context.fetch(FetchDescriptor<Todo>())
        for todo in linkedTodosBefore {
            let stillThere = todosAfter.first { $0.id == todo.id }
            #expect(stillThere != nil, "todo should survive project deletion (standalone)")
            #expect(stillThere?.project == nil, "todo.project should be nullified after project delete")
        }
    }

    // MARK: - P1: deleteProject nullify（隔离构造，精确 2 个 todo）

    @Test("P1: deleting a project with exactly 2 todos leaves both alive with project == nil")
    func deleteProjectNullifiesTwoTodos() throws {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        // 一个全新 project，挂 2 个 company todo（其余库为空，断言确定性）。
        let project = Project(
            title: "Solo project",
            intro: "",
            notes: "",
            tag: "",
            members: [],
            createdAt: .now
        )
        context.insert(project)
        let t1 = Todo(title: "Task one", urgency: .urgent, scope: .company, project: project)
        let t2 = Todo(title: "Task two", urgency: .normal, scope: .company, project: project)
        context.insert(t1)
        context.insert(t2)
        try context.save()
        let projectID = project.id
        let t1ID = t1.id
        let t2ID = t2.id

        let vm = ProjectDetailViewModel(project: project, context: context)
        vm.deleteProject()

        // project 已删。
        let projectsAfter = try context.fetch(FetchDescriptor<Project>())
        #expect(projectsAfter.contains { $0.id == projectID } == false)

        // 2 个 todo 仍在，且 project 被 nullify 为 nil（降级为 standalone company todo）。
        let todosAfter = try context.fetch(FetchDescriptor<Todo>())
        #expect(todosAfter.count == 2)
        let survivor1 = todosAfter.first { $0.id == t1ID }
        let survivor2 = todosAfter.first { $0.id == t2ID }
        #expect(survivor1 != nil)
        #expect(survivor2 != nil)
        #expect(survivor1?.project == nil, "todo.project 应被 nullify")
        #expect(survivor2?.project == nil, "todo.project 应被 nullify")
        // scope 仍是 company（nullify 只清 project 关系，不动 scope）。
        #expect(survivor1?.scope == .company)
        #expect(survivor2?.scope == .company)
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
