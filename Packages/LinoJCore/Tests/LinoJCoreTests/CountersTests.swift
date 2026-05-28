// CountersTests.swift
// 用 in-memory container + seedIfEmpty 验证 seed 数据的整体计数。
//
// 数字以 data.js 真理源为准；如果 plan 验收标准与实际不符，照实表达，由主会话决定要不要改 plan。
// 当前事实：
//   - personalTodos = 7（含 1 个 done）
//   - workTodos = 9（含 1 个 done）
//   - Todo 总数 = 16 ✓ 与 plan 一致
//   - Project 总数 = 3 ✓ 与 plan 一致
//   - Event 总数 = 16 (本周) + 2 (yesterday) = 18，与 plan「Event = 16」不符
//   - Person 去重总数 = 8 (L/M/A/J/K/Mom/Dad/Andrew)，与 plan「≥ 10」不符

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("Seeded counters")
@MainActor
struct CountersTests {

    private func makeSeededContext() throws -> ModelContext {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)
        return context
    }

    @Test("Todo total = 16 (personal 7 + work 9)")
    func todoTotal() throws {
        let context = try makeSeededContext()
        let count = try context.fetchCount(FetchDescriptor<Todo>())
        #expect(count == 16)
    }

    @Test("Project total = 3")
    func projectTotal() throws {
        let context = try makeSeededContext()
        let count = try context.fetchCount(FetchDescriptor<Project>())
        #expect(count == 3)
    }

    @Test("Event total = 18 (16 this week + 2 yesterday)")
    func eventTotal() throws {
        let context = try makeSeededContext()
        let count = try context.fetchCount(FetchDescriptor<Event>())
        // data.js 共 16 个 events + 2 个 yesterdayEvents = 18。
        // plan 中写「Event 总数 = 16」，是把 yesterdayEvents 漏算了 —— 见 PR 汇报。
        #expect(count == 18)
    }

    @Test("Person dedup ≥ 8 (includes Mom/Dad/Andrew/L/M/A/J/K)")
    func personDedup() throws {
        let context = try makeSeededContext()
        let people = try context.fetch(FetchDescriptor<Person>())
        let names = Set(people.map(\.name))
        // 与 plan「≥ 10」不符：data.js 仅含 8 个独立 token，照实写。
        #expect(people.count >= 8)
        for required in ["Mom", "Dad", "Andrew", "L", "M", "A", "J", "K"] {
            #expect(names.contains(required), "缺少必需 person token: \(required)")
        }
    }

    @Test("Urgent open todos: counts by scope")
    func urgentOpenBreakdown() throws {
        let context = try makeSeededContext()
        let allTodos = try context.fetch(FetchDescriptor<Todo>())
        let urgentOpen = allTodos.filter { $0.urgency == .urgent && !$0.done }
        let urgentPersonal = urgentOpen.filter { $0.scope == .personal }
        let urgentCompany = urgentOpen.filter { $0.scope == .company }

        // 事实记录：
        //   personalTodos 中 urgent && !done：p5 (Reply to mom)、p6 (HYSA) = 2
        //   workTodos 中 urgent && !done：w1 (expense)、w4 (sidebar)、w5 (onboarding copy) = 3
        //   合计 5。plan P3.2 验收文案是 "5 张"，与此一致。
        #expect(urgentOpen.count == 5)
        #expect(urgentPersonal.count == 2)
        #expect(urgentCompany.count == 3)
    }
}
