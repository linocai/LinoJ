// CloudKitConfigTests.swift
// V1：验证 LinoJStore.makeContainer 的 CloudKit 配置分支。
//
// 重要约束：测试**绝不连真实 CloudKit**。
//   - `inMemory: true` 路径强制 `.none`（容器只在内存，不触网）—— 这是测试唯一安全路径。
//   - `inMemory: false, cloudSyncEnabled: false`（纯本地磁盘）理论上不连云，但会落真实磁盘
//     文件（默认在 Application Support）。在 CI / 测试机上反复建磁盘 store 不干净，且 SwiftData
//     磁盘 store 名冲突会污染。因此「纯本地配置分支不崩」用 `inMemory: true` 等价覆盖（两者
//     cloudKitDatabase 都解析为 .none，差异仅 isStoredInMemoryOnly），并在此说明。
//   - `cloudSyncEnabled: true` 的 `.private` 分支**不在单测构造**（会尝试连
//     `iCloud.com.linocai.linoj` 容器，无 iCloud 账号 / entitlement 的测试进程会挂起或失败）。
//     该分支的正确性靠模型 CloudKit 约束（已在模型层逐条满足）+ iOS/macOS 真机验收覆盖。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("V1 CloudKit makeContainer 配置分支")
@MainActor
struct CloudKitConfigTests {

    @Test("inMemory: true 仍可用 —— 容器构造成功、可 insert / fetch")
    func inMemoryContainerUsable() throws {
        // 默认 cloudSyncEnabled = true，但 inMemory 优先：强制 .none，不连云。
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let todo = Todo(title: "ping", urgency: .urgent, scope: .company)
        context.insert(todo)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 1)
    }

    @Test("inMemory: true + cloudSyncEnabled: true 不触网（inMemory 优先 .none）")
    func inMemoryOverridesCloudSyncEnabled() throws {
        // 关键回归：即使显式传 cloudSyncEnabled: true，inMemory == true 也必须落 .none，
        // 否则测试会尝试连真实 CloudKit 容器导致挂起。能构造 + 立即 fetch 即证明没卡在网络。
        let container = try LinoJStore.makeContainer(inMemory: true, cloudSyncEnabled: true)
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Person>()) == 0)
    }

    @Test("inMemory seed 后计数正确（CloudKit 模型约束改造未破坏 seed）")
    func seedCountsAfterModelChanges() throws {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)

        // plan P1 验收：Todo 16 / Project 3 / Event 18 / Person 去重 8。
        // V1 改了模型（标量加默认值、to-many = []、Person 加 inverse 关系）后这些计数必须不变。
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 16)
        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<Event>()) == 18)
        #expect(try context.fetchCount(FetchDescriptor<Person>()) == 8)
    }

    @Test("纯本地配置分支（cloudSyncEnabled: false）不抛异常 —— inMemory 等价覆盖")
    func localOnlyConfigBranchDoesNotThrow() throws {
        // 见文件头说明：不在测试里建真实磁盘 store，用 inMemory 等价验证「.none 分支」可构造。
        // inMemory: true 时 cloudKitDatabase 永远 .none，与 (false, false) 的 cloudKitDatabase
        // 解析结果一致，故能覆盖「非 CloudKit 配置分支不崩」。
        let container = try LinoJStore.makeContainer(inMemory: true, cloudSyncEnabled: false)
        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Event>()) == 0)
    }

    @Test("Person inverse 关系双向可遍历（CloudKit inverse 约束）")
    func personInverseRelationships() throws {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let alice = Person(name: "Alice")
        let project = Project(
            id: UUID(), title: "P", intro: "", notes: "", tag: "",
            members: [alice], createdAt: .now
        )
        let event = Event(
            title: "E", start: .now, end: .now, location: "Zoom", attendees: [alice]
        )
        context.insert(project)
        context.insert(event)
        try context.save()

        // 正向：project.members / event.attendees 含 alice。
        // V1：关系已改 optional（[Person]?），统一 `?? []` 兜底读。
        #expect((project.members ?? []).contains { $0.id == alice.id })
        #expect((event.attendees ?? []).contains { $0.id == alice.id })

        // 反向（V1 新增 inverse）：alice.memberOf / alice.attending 回指 project / event。
        let fetched = try context.fetch(FetchDescriptor<Person>())
        let fetchedAlice = try #require(fetched.first { $0.id == alice.id })
        #expect((fetchedAlice.memberOf ?? []).contains { $0.id == project.id })
        #expect((fetchedAlice.attending ?? []).contains { $0.id == event.id })
    }

    // MARK: - V1 CloudKit to-many optional 改造的逼近验证

    @Test("所有 to-many 关系改 optional 后读写路径自洽（建 project + todos + members + events）")
    func toManyOptionalRelationshipsReadWrite() throws {
        // 说明：真实 CloudKit `.private` 容器加载才会触发 schema 校验
        //   "CloudKit integration requires that all relationships be optional"，
        //   该校验需 entitlement + 签名，headless `swift test` 无法构造（会挂起 / 失败）。
        //   只能在用户 Xcode 真机重跑验证。
        // 替代覆盖：用 inMemory 容器把 6 个关系（Project.members/todos/events、
        //   Event.attendees、Person.memberOf/attending）全部写入再读出，断言 count 正确，
        //   确保模型改 optional 后业务逻辑自洽、无关系遍历崩溃。
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let alice = Person(name: "Alice")
        let bob = Person(name: "Bob")
        let project = Project(
            id: UUID(), title: "Launch", intro: "", notes: "", tag: "",
            members: [alice, bob], createdAt: .now
        )
        context.insert(project)

        // 通过 to-one 反向关系挂上 todos / events（Project.todos / events 是 inverse 自动维护）。
        let t1 = Todo(title: "spec", urgency: .urgent, scope: .company, project: project)
        let t2 = Todo(title: "polish", urgency: .normal, scope: .company, project: project)
        let e1 = Event(title: "kickoff", start: .now, end: .now, location: "Zoom",
                       attendees: [alice], project: project)
        context.insert(t1)
        context.insert(t2)
        context.insert(e1)
        try context.save()

        // 重新 fetch 验证关系读取（统一 `?? []` 兜底）。
        let fetchedProject = try #require(
            try context.fetch(FetchDescriptor<Project>()).first { $0.id == project.id }
        )
        #expect((fetchedProject.members ?? []).count == 2)
        #expect((fetchedProject.todos ?? []).count == 2)
        #expect((fetchedProject.events ?? []).count == 1)
        #expect((fetchedProject.todos ?? []).filter { !$0.done }.count == 2)

        let fetchedEvent = try #require(
            try context.fetch(FetchDescriptor<Event>()).first { $0.id == e1.id }
        )
        #expect((fetchedEvent.attendees ?? []).count == 1)

        // Person 侧 inverse to-many。
        let fetchedAlice = try #require(
            try context.fetch(FetchDescriptor<Person>()).first { $0.id == alice.id }
        )
        #expect((fetchedAlice.memberOf ?? []).count == 1)
        #expect((fetchedAlice.attending ?? []).count == 1)

        // 空关系（无 todos/events/members 的 Person）读出来是空数组而非崩溃。
        let lonely = Person(name: "Lonely")
        context.insert(lonely)
        try context.save()
        let fetchedLonely = try #require(
            try context.fetch(FetchDescriptor<Person>()).first { $0.id == lonely.id }
        )
        #expect((fetchedLonely.memberOf ?? []).isEmpty)
        #expect((fetchedLonely.attending ?? []).isEmpty)
    }
}
