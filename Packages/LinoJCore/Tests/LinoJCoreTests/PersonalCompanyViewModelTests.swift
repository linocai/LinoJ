// PersonalCompanyViewModelTests.swift
// 验证 PersonalViewModel / CompanyViewModel 在 seed 数据上的派生量与 plan P3.3 验收一致。
//
// 数字推导（与 SeedData.swift 字面一致）：
//
// Personal todos（scope = .personal）：
//   - urgent open: "Reply to mom" (p5), "Move savings into HYSA" (p6) → 2
//   - completed:   "Schedule dentist" (p7) → 1
//
// Company / work todos（scope = .company）：
//   - urgent open (all work):
//       w1 "Submit Q1 expense report" (standalone, urgent)
//       w4 "Finalize macOS sidebar spec" (linoj, urgent)
//       w5 "Review onboarding copy v2" (onboarding, urgent)
//     → 3
//   - urgent open filter .project(linoj.id): 仅 w4 → 1
//   - urgent open filter .standalone:        仅 w1 → 1

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("Personal/Company ViewModels — seed-driven derived counts")
@MainActor
struct PersonalCompanyViewModelTests {

    private func makeSeededContext() throws -> ModelContext {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)
        return context
    }

    // MARK: - Personal

    @Test("Personal urgent count == 2 (p5 + p6)")
    func personalUrgentCount() throws {
        let context = try makeSeededContext()
        let vm = PersonalViewModel(context: context)
        #expect(vm.urgent.count == 2)
        let titles = Set(vm.urgent.map(\.title))
        #expect(titles == Set(["Reply to mom", "Move savings into HYSA"]))
    }

    @Test("Personal completed count == 1 (p7 schedule dentist)")
    func personalCompletedCount() throws {
        let context = try makeSeededContext()
        let vm = PersonalViewModel(context: context)
        #expect(vm.completed.count == 1)
        #expect(vm.completed.first?.title == "Schedule dentist")
        #expect(vm.doneCount == 1)
    }

    // MARK: - Company

    @Test("Company .allWork urgent count == 3 (w1 + w4 + w5)")
    func companyAllWorkUrgent() throws {
        let context = try makeSeededContext()
        let vm = CompanyViewModel(context: context)
        // 默认 filter == .allWork
        #expect(vm.urgent.count == 3)
        let titles = Set(vm.urgent.map(\.title))
        #expect(titles == Set([
            "Submit Q1 expense report",
            "Finalize macOS sidebar spec",
            "Review onboarding copy v2",
        ]))
    }

    @Test("Company .project(linoj) urgent count == 1 (w4)")
    func companyProjectLinoJUrgent() throws {
        let context = try makeSeededContext()
        let vm = CompanyViewModel(context: context)
        // 通过 projects 列表反查 LinoJ 项目的 id
        guard let linoj = vm.projects.first(where: { $0.title == "LinoJ for macOS v1" }) else {
            Issue.record("seed should include 'LinoJ for macOS v1' project")
            return
        }
        vm.setFilter(.project(linoj.id))
        #expect(vm.urgent.count == 1)
        #expect(vm.urgent.first?.title == "Finalize macOS sidebar spec")
    }

    @Test("Company .standalone urgent count == 1 (w1)")
    func companyStandaloneUrgent() throws {
        let context = try makeSeededContext()
        let vm = CompanyViewModel(context: context)
        vm.setFilter(.standalone)
        #expect(vm.urgent.count == 1)
        #expect(vm.urgent.first?.title == "Submit Q1 expense report")
    }

    // MARK: - Bonus invariants

    @Test("Company todosCount + projectsCount independent of chip filter")
    func companyStatsIndependentOfFilter() throws {
        let context = try makeSeededContext()
        let vm = CompanyViewModel(context: context)
        let openBefore = vm.todosCount
        let projectsBefore = vm.projectsCount
        // 切到一个会过滤掉大量项的 chip，counts 不应该变。
        vm.setFilter(.standalone)
        #expect(vm.todosCount == openBefore)
        #expect(vm.projectsCount == projectsBefore)
    }

    @Test("Personal toggleDone flips state and updates counts")
    func personalToggleDone() throws {
        let context = try makeSeededContext()
        let vm = PersonalViewModel(context: context)
        let openBefore = vm.openCount
        guard let firstUrgent = vm.urgent.first else {
            Issue.record("seed should have at least one urgent personal todo")
            return
        }
        vm.toggleDone(firstUrgent)
        #expect(vm.openCount == openBefore - 1)
        #expect(vm.doneCount == 2)
    }

    // MARK: - Personal: urgency toggle + delete + normal

    @Test("Personal toggleUrgency moves a todo between urgent and normal lists")
    func personalToggleUrgency() throws {
        let context = try makeSeededContext()
        let vm = PersonalViewModel(context: context)
        guard let urgentTodo = vm.urgent.first else {
            Issue.record("seed should have at least one urgent personal todo")
            return
        }
        let normalBefore = vm.normal.count
        let urgentBefore = vm.urgent.count

        vm.toggleUrgency(urgentTodo)
        // 该 todo 现在应在 normal 列、不在 urgent 列。
        #expect(vm.urgent.count == urgentBefore - 1)
        #expect(vm.normal.count == normalBefore + 1)
        #expect(urgentTodo.urgency == .normal)

        // 再切回 urgent。
        vm.toggleUrgency(urgentTodo)
        #expect(urgentTodo.urgency == .urgent)
        #expect(vm.urgent.count == urgentBefore)
    }

    @Test("Personal delete removes a todo and drops open count")
    func personalDelete() throws {
        let context = try makeSeededContext()
        let vm = PersonalViewModel(context: context)
        let openBefore = vm.openCount
        guard let victim = vm.normal.first ?? vm.urgent.first else {
            Issue.record("seed should have at least one open personal todo")
            return
        }
        vm.delete(victim)
        #expect(vm.openCount == openBefore - 1)
    }

    @Test("Personal normal list is non-empty in seed data")
    func personalNormalNonEmpty() throws {
        let context = try makeSeededContext()
        let vm = PersonalViewModel(context: context)
        #expect(vm.normal.isEmpty == false)
        #expect(vm.normal.allSatisfy { $0.urgency == .normal && !$0.done })
    }

    // MARK: - Company: normal list + toggleDone + empty project filter

    @Test("Company .allWork normal list contains only open normal company todos")
    func companyNormalList() throws {
        let context = try makeSeededContext()
        let vm = CompanyViewModel(context: context)
        #expect(vm.normal.isEmpty == false)
        #expect(vm.normal.allSatisfy { $0.scope == .company && $0.urgency == .normal && !$0.done })
    }

    @Test("Company toggleDone reduces todosCount")
    func companyToggleDone() throws {
        let context = try makeSeededContext()
        let vm = CompanyViewModel(context: context)
        let before = vm.todosCount
        guard let victim = vm.urgent.first ?? vm.normal.first else {
            Issue.record("seed should have at least one open company todo")
            return
        }
        vm.toggleDone(victim)
        #expect(vm.todosCount == before - 1)
        // 重新打开后恢复。
        vm.toggleDone(victim)
        #expect(vm.todosCount == before)
    }

    @Test("Company filter to a project with no urgent todos yields empty urgent list")
    func companyProjectFilterEmpty() throws {
        let context = try makeSeededContext()
        let vm = CompanyViewModel(context: context)
        // Q3 planning project has no urgent company todos linked.
        guard let q3 = vm.projects.first(where: { $0.title.contains("Q3") }) else {
            Issue.record("seed should include a Q3 project")
            return
        }
        vm.setFilter(.project(q3.id))
        #expect(vm.urgent.isEmpty)
        // 但整体 todosCount / projectsCount 不受 filter 影响。
        #expect(vm.projectsCount == 3)
    }
}
