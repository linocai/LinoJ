// QuickAddViewModelTests.swift
// Plan P3.6 验收 + plan P7 测试覆盖范围。
//
// 五条断言覆盖 plan「关键接口契约」与「验收标准」：
//  1. canSubmit 在空 title 时 == false（todo kind）。
//  2. canSubmit 在 event kind 且 end <= start 时 == false。
//  3. submit() 创建 Todo 后 context 中 Todo 数 +1。
//  4. submit() 创建 Event 后 Event 数 +1，Todo 数不变。
//  5. scope==.personal 时 todoProject 自动置 nil（先 .company + project 再切回 .personal）。
//
// 额外 sanity：6. submit() 创建 Project 后 Project 数 +1。
//  7. prefilledProject(.todo) 把 scope 设为 .company 并预填 todoProject。
//
// V5 Edit project（8-10）：
//  8. edit 模式 init 后 kind 强制 .project 且 projectTitle 预填既有 title。
//  9. edit 模式 submit 后既有 project 被原地更新（不新增；notes 保留）。
// 10. edit 模式改 members 后 submit，memberCount 与 members.count 同步（Reviewer F2 冗余字段）。
//
// 测试用 inMemory container —— 不污染开发机持久存储。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("QuickAddViewModel — validation & persistence")
@MainActor
struct QuickAddViewModelTests {

    private func makeEmptyContext() throws -> ModelContext {
        let container = try LinoJStore.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    // MARK: 1. Empty title

    @Test("todo: canSubmit == false when title is empty / whitespace")
    func todoCanSubmitFalseOnEmptyTitle() throws {
        let context = try makeEmptyContext()
        let vm = QuickAddViewModel(context: context, defaultKind: .todo)

        #expect(vm.canSubmit == false)

        // 纯空白也算空
        vm.todoTitle = "   "
        #expect(vm.canSubmit == false)

        vm.todoTitle = "Outline retro"
        #expect(vm.canSubmit == true)
    }

    // MARK: 2. Event end <= start

    @Test("event: canSubmit == false when end <= start")
    func eventCanSubmitFalseOnInvertedTime() throws {
        let context = try makeEmptyContext()
        let vm = QuickAddViewModel(context: context, defaultKind: .event)

        vm.eventTitle = "Q3 retro review"

        // 强制把 end 设到 start 之前（同一日期，时分倒置）。
        let cal = Calendar.current
        let baseDay = cal.date(from: DateComponents(year: 2026, month: 5, day: 30))!
        vm.eventDate = baseDay
        vm.eventStart = cal.date(byAdding: .hour, value: 15, to: baseDay)!  // 15:00
        vm.eventEnd   = cal.date(byAdding: .hour, value: 14, to: baseDay)!  // 14:00

        #expect(vm.canSubmit == false)

        // end == start：仍然不行（plan: end > start）
        vm.eventEnd = vm.eventStart
        #expect(vm.canSubmit == false)

        // end > start：可提交
        vm.eventEnd = cal.date(byAdding: .hour, value: 16, to: baseDay)!  // 16:00
        #expect(vm.canSubmit == true)
    }

    // MARK: 3. submit() Todo

    @Test("submit() with Todo kind inserts one Todo into context")
    func submitTodoIncrementsTodoCount() throws {
        let context = try makeEmptyContext()
        let before = try context.fetch(FetchDescriptor<Todo>()).count
        #expect(before == 0)

        let vm = QuickAddViewModel(context: context, defaultKind: .todo)
        vm.todoTitle = "Send invoice"
        vm.todoUrgency = .urgent
        vm.todoScope = .company

        let id = try vm.submit()
        let after = try context.fetch(FetchDescriptor<Todo>())
        #expect(after.count == before + 1)

        // 返回 id 应能反查到刚插入的 todo
        let inserted = after.first
        #expect(inserted?.title == "Send invoice")
        #expect(inserted?.urgency == .urgent)
        #expect(inserted?.scope == .company)
        #expect(id == AnyHashable(inserted!.id))
    }

    // MARK: 4. submit() Event

    @Test("submit() with Event kind increments Event count; Todo count unchanged")
    func submitEventIncrementsEventCountOnly() throws {
        let context = try makeEmptyContext()
        let todosBefore = try context.fetch(FetchDescriptor<Todo>()).count
        let eventsBefore = try context.fetch(FetchDescriptor<Event>()).count

        let vm = QuickAddViewModel(context: context, defaultKind: .event)
        vm.eventTitle = "Design review"
        let cal = Calendar.current
        let day = cal.date(from: DateComponents(year: 2026, month: 6, day: 3))!
        vm.eventDate = day
        vm.eventStart = cal.date(byAdding: .hour, value: 14, to: day)!
        vm.eventEnd   = cal.date(byAdding: .hour, value: 15, to: day)!
        vm.eventLocation = "Conf Rm A"

        _ = try vm.submit()

        let todosAfter = try context.fetch(FetchDescriptor<Todo>()).count
        let eventsAfter = try context.fetch(FetchDescriptor<Event>())
        #expect(todosAfter == todosBefore)
        #expect(eventsAfter.count == eventsBefore + 1)
        #expect(eventsAfter.first?.title == "Design review")
        #expect(eventsAfter.first?.location == "Conf Rm A")
    }

    // MARK: 5. scope=.personal 清空 todoProject

    @Test("scope=.personal automatically clears todoProject")
    func personalScopeClearsProject() throws {
        let context = try makeEmptyContext()

        // 准备一个 Project，先放进 context
        let p = Project(
            title: "Demo project",
            intro: "",
            notes: "",
            tag: "",
            members: [],
            createdAt: .now
        )
        context.insert(p)
        try context.save()

        let vm = QuickAddViewModel(context: context, defaultKind: .todo)

        // 先 scope=.company + 设 project
        vm.todoScope = .company
        vm.todoProject = p
        #expect(vm.todoProject?.id == p.id)

        // 切回 .personal → didSet 应清空 todoProject
        vm.todoScope = .personal
        #expect(vm.todoProject == nil)
    }

    // MARK: 6. submit() Project (sanity)

    @Test("submit() with Project kind increments Project count")
    func submitProjectIncrementsProjectCount() throws {
        let context = try makeEmptyContext()
        let before = try context.fetch(FetchDescriptor<Project>()).count

        let vm = QuickAddViewModel(context: context, defaultKind: .project)
        vm.projectTitle = "Calendar v2"
        vm.projectIntro = "Calmer week view."
        vm.projectTag = "Shipping July"

        _ = try vm.submit()

        let after = try context.fetch(FetchDescriptor<Project>())
        #expect(after.count == before + 1)
        #expect(after.contains(where: { $0.title == "Calendar v2" }))
    }

    // MARK: 7. prefilledProject for todo sets scope to company

    @Test("prefilledProject for todo kind sets scope=.company and todoProject")
    func prefilledProjectForTodo() throws {
        let context = try makeEmptyContext()
        let p = Project(
            title: "X",
            intro: "",
            notes: "",
            tag: "",
            members: [],
            createdAt: .now
        )
        context.insert(p)
        try context.save()

        let vm = QuickAddViewModel(context: context, defaultKind: .todo, prefilledProject: p)
        #expect(vm.todoScope == .company)
        #expect(vm.todoProject?.id == p.id)
    }

    // MARK: 8. V5 — edit 模式 init 预填既有 project 字段

    @Test("edit 模式 init 后 kind=.project + projectTitle 预填为既有 project.title")
    func editModeInitPrefillsFields() throws {
        let context = try makeEmptyContext()
        let alice = Person(name: "Alice")
        let p = Project(
            title: "Onboarding redesign",
            intro: "Smoother first-run.",
            notes: "Some long notes.\n\nSecond paragraph.",
            tag: "In review",
            members: [alice],
            createdAt: .now
        )
        context.insert(p)
        try context.save()

        // edit 模式即便 defaultKind 给 .todo，也应被强制为 .project。
        let vm = QuickAddViewModel(context: context, defaultKind: .todo, editingProject: p)

        #expect(vm.isEditing == true)
        #expect(vm.editingProjectID == p.id)
        #expect(vm.kind == .project)
        #expect(vm.projectTitle == "Onboarding redesign")
        #expect(vm.projectIntro == "Smoother first-run.")
        #expect(vm.projectTag == "In review")
        #expect(vm.projectMembers.count == 1)
        #expect(vm.projectMembers.first?.id == alice.id)
        // edit 模式 title 非空 → canSubmit 应为 true。
        #expect(vm.canSubmit == true)
    }

    // MARK: 9. V5 — edit 模式 submit 更新既有 project（不新增）

    @Test("edit 模式 submit 后既有 project.title 被更新，project 总数不变")
    func editModeSubmitUpdatesInPlace() throws {
        let context = try makeEmptyContext()
        let p = Project(
            title: "Old title",
            intro: "Old intro.",
            notes: "Keep these notes.",
            tag: "Old tag",
            members: [],
            createdAt: .now
        )
        context.insert(p)
        try context.save()
        let originalID = p.id

        let before = try context.fetch(FetchDescriptor<Project>()).count
        #expect(before == 1)

        let vm = QuickAddViewModel(context: context, editingProject: p)
        vm.projectTitle = "New title"
        vm.projectIntro = "New intro."
        vm.projectTag = "New tag"

        let returnedID = try vm.submit()

        let after = try context.fetch(FetchDescriptor<Project>())
        // 不新增 —— project 总数仍为 1。
        #expect(after.count == before)
        let updated = after.first
        #expect(updated?.id == originalID)
        #expect(updated?.title == "New title")
        #expect(updated?.intro == "New intro.")
        #expect(updated?.tag == "New tag")
        // notes 不在表单内，edit 后应保留既有值。
        #expect(updated?.notes == "Keep these notes.")
        // 返回的 id 应是原 project id（非新建）。
        #expect(returnedID == AnyHashable(originalID))
    }

    // MARK: 10. V5 — edit 模式 submit 后 memberCount 与 members.count 一致

    @Test("edit 模式改 members 后 submit，memberCount 与 members.count 同步")
    func editModeSubmitSyncsMemberCount() throws {
        let context = try makeEmptyContext()
        let a = Person(name: "Andrew")
        let b = Person(name: "Beth")
        let c = Person(name: "Carl")
        // 起始 1 个成员，memberCount=1。
        let p = Project(
            title: "Q3 planning",
            intro: "",
            notes: "",
            tag: "",
            members: [a],
            createdAt: .now
        )
        context.insert(p)
        try context.save()
        #expect(p.memberCount == 1)

        // edit：增加到 3 个成员。
        let vm = QuickAddViewModel(context: context, editingProject: p)
        vm.projectMembers = [a, b, c]
        _ = try vm.submit()

        let updated = try context.fetch(FetchDescriptor<Project>()).first
        // V1：members 改 optional（[Person]?），统一 `?? []` 兜底。
        #expect((updated?.members ?? []).count == 3)
        // F2 冗余字段必须与实际 members.count 一致。
        #expect(updated?.memberCount == 3)
        #expect(updated?.memberCount == (updated?.members ?? []).count)

        // 再 edit：减回 1 个成员，验证向下也同步。
        let vm2 = QuickAddViewModel(context: context, editingProject: updated!)
        vm2.projectMembers = [b]
        _ = try vm2.submit()

        let updated2 = try context.fetch(FetchDescriptor<Project>()).first
        #expect((updated2?.members ?? []).count == 1)
        #expect(updated2?.memberCount == 1)
        #expect(updated2?.memberCount == (updated2?.members ?? []).count)
    }
}
