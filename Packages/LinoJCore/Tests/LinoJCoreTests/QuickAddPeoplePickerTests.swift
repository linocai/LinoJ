// QuickAddPeoplePickerTests.swift
// W1 验收 —— Quick Add 选人器（Attendees / Members）VM 操作。
//
// 覆盖 plan W1「关键接口契约」+「验收标准」最后一条（LinoJCoreTests 新增 QuickAddPeoplePickerTests）：
//   1. toggleAttendee / toggleMember 去重（按 Person.id，重复 toggle 加/删，不重复堆积）。
//   2. isAttendeeSelected / isMemberSelected 反映当前选中态（按 id）。
//   3. addPerson 查重名：命中既有同名（trim + case-insensitive）则复用，不 insert 新 Person。
//   4. addPerson 未命中则新建并 insert + 选中。
//   5. addPerson 空白名返回 nil 且不创建。
//   6. members 经 submit 后 Project.memberCount 与 members.count 一致（含临时新建路径）。
//
// 测试用 inMemory container —— 不污染开发机持久存储。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("QuickAddViewModel — W1 people picker")
@MainActor
struct QuickAddPeoplePickerTests {

    private func makeEmptyContext() throws -> ModelContext {
        let container = try LinoJStore.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    // MARK: 1. toggleAttendee 去重

    @Test("toggleAttendee 加入/移除按 id 去重，不重复堆积")
    func toggleAttendeeDedup() throws {
        let context = try makeEmptyContext()
        let vm = QuickAddViewModel(context: context, defaultKind: .event)

        let alice = Person(name: "Alice")
        context.insert(alice)

        // 初始未选。
        #expect(vm.isAttendeeSelected(alice) == false)

        // 第一次 toggle → 加入。
        vm.toggleAttendee(alice)
        #expect(vm.eventAttendees.count == 1)
        #expect(vm.isAttendeeSelected(alice) == true)

        // 再 toggle 同一人 → 移除。
        vm.toggleAttendee(alice)
        #expect(vm.eventAttendees.isEmpty)
        #expect(vm.isAttendeeSelected(alice) == false)

        // 加两次同一 id（构造两个 id 相同的 Person 引用模拟）→ 仍只一条。
        vm.toggleAttendee(alice)
        let sameID = Person(id: alice.id, name: "Alice")
        // sameID 与 alice 同 id → isSelected 应判已选 → toggle 应移除。
        #expect(vm.isAttendeeSelected(sameID) == true)
        vm.toggleAttendee(sameID)
        #expect(vm.eventAttendees.isEmpty)
    }

    // MARK: 2. toggleMember 去重

    @Test("toggleMember 加入/移除按 id 去重")
    func toggleMemberDedup() throws {
        let context = try makeEmptyContext()
        let vm = QuickAddViewModel(context: context, defaultKind: .project)

        let bob = Person(name: "Bob")
        context.insert(bob)

        #expect(vm.isMemberSelected(bob) == false)
        vm.toggleMember(bob)
        #expect(vm.projectMembers.count == 1)
        #expect(vm.isMemberSelected(bob) == true)
        vm.toggleMember(bob)
        #expect(vm.projectMembers.isEmpty)
        #expect(vm.isMemberSelected(bob) == false)
    }

    // MARK: 3. addPerson 命中既有同名 → 复用（不 insert 新 Person）

    @Test("addPerson 命中既有同名（trim + case-insensitive）复用，不新增 Person")
    func addPersonReusesExistingByName() throws {
        let context = try makeEmptyContext()
        let existingPerson = Person(name: "Andrew")
        context.insert(existingPerson)
        try context.save()

        let vm = QuickAddViewModel(context: context, defaultKind: .event)
        let allBefore = try context.fetch(FetchDescriptor<Person>())
        #expect(allBefore.count == 1)

        // 大小写 + 前后空格不同，但应命中既有同名。
        let result = vm.addPerson(named: "  andrew ", existing: allBefore, target: .attendee)

        #expect(result?.id == existingPerson.id)
        // 没有新增 Person。
        let allAfter = try context.fetch(FetchDescriptor<Person>())
        #expect(allAfter.count == 1)
        // 既有那条被选中。
        #expect(vm.isAttendeeSelected(existingPerson) == true)
        #expect(vm.eventAttendees.count == 1)
    }

    // MARK: 4. addPerson 未命中 → 新建 + insert + 选中

    @Test("addPerson 未命中既有同名则新建 Person 并选中（落到 members）")
    func addPersonCreatesNew() throws {
        let context = try makeEmptyContext()
        let other = Person(name: "Beth")
        context.insert(other)
        try context.save()

        let vm = QuickAddViewModel(context: context, defaultKind: .project)
        let allBefore = try context.fetch(FetchDescriptor<Person>())

        let result = vm.addPerson(named: "Carl", existing: allBefore, target: .member)
        #expect(result != nil)
        #expect(result?.name == "Carl")

        // 新 Person 已 insert 进 context（save 后可查到）。
        try context.save()
        let allAfter = try context.fetch(FetchDescriptor<Person>())
        #expect(allAfter.count == 2)
        #expect(allAfter.contains { $0.name == "Carl" })

        // 落到 members 并被选中。
        #expect(vm.projectMembers.count == 1)
        #expect(vm.isMemberSelected(result!) == true)
    }

    // MARK: 5. addPerson 空白名返回 nil 且不创建

    @Test("addPerson 空白名返回 nil 且不新增 Person")
    func addPersonBlankReturnsNil() throws {
        let context = try makeEmptyContext()
        let vm = QuickAddViewModel(context: context, defaultKind: .event)
        let before = try context.fetch(FetchDescriptor<Person>()).count

        #expect(vm.addPerson(named: "", existing: [], target: .attendee) == nil)
        #expect(vm.addPerson(named: "   ", existing: [], target: .member) == nil)

        try context.save()
        let after = try context.fetch(FetchDescriptor<Person>()).count
        #expect(after == before)
        #expect(vm.eventAttendees.isEmpty)
        #expect(vm.projectMembers.isEmpty)
    }

    // MARK: 6. members 经 submit 后 memberCount == members.count（含临时新建路径）

    @Test("项目 create：选 members + 临时新建后 submit，memberCount 与 members.count 一致")
    func submitProjectSyncsMemberCount() throws {
        let context = try makeEmptyContext()
        let a = Person(name: "Existing A")
        let b = Person(name: "Existing B")
        context.insert(a)
        context.insert(b)
        try context.save()

        let vm = QuickAddViewModel(context: context, defaultKind: .project)
        vm.projectTitle = "Launch crew"

        // 选两个既有 + 临时新建一个。
        vm.toggleMember(a)
        vm.toggleMember(b)
        let all = try context.fetch(FetchDescriptor<Person>())
        vm.addPerson(named: "Fresh Hire", existing: all, target: .member)
        #expect(vm.projectMembers.count == 3)

        _ = try vm.submit()

        let project = try context.fetch(FetchDescriptor<Project>()).first
        #expect((project?.members ?? []).count == 3)
        // F2 冗余字段：memberCount 必须经 submit 重算等于 members.count。
        #expect(project?.memberCount == 3)
        #expect(project?.memberCount == (project?.members ?? []).count)
    }

    // MARK: 7. Event create：选 attendees 后 submit 落库

    @Test("Event create：选 attendees 后 submit，attendees 落库")
    func submitEventPersistsAttendees() throws {
        let context = try makeEmptyContext()
        let p1 = Person(name: "Mom")
        let p2 = Person(name: "Andrew")
        context.insert(p1)
        context.insert(p2)
        try context.save()

        let vm = QuickAddViewModel(context: context, defaultKind: .event)
        vm.eventTitle = "Dinner"
        vm.toggleAttendee(p1)
        vm.toggleAttendee(p2)
        #expect(vm.eventAttendees.count == 2)

        _ = try vm.submit()

        let event = try context.fetch(FetchDescriptor<Event>()).first
        #expect((event?.attendees ?? []).count == 2)
        let ids = Set((event?.attendees ?? []).map(\.id))
        #expect(ids == Set([p1.id, p2.id]))
    }

    // MARK: 8. V5 edit project：增删 members 后 submit，memberCount 重算（回归守卫）

    @Test("项目 edit：预填 members 删减后 submit，memberCount 经 submit 重算（不沿用旧值）")
    func editProjectResyncsMemberCount() throws {
        let context = try makeEmptyContext()
        let a = Person(name: "Alpha")
        let b = Person(name: "Bravo")
        let c = Person(name: "Charlie")
        context.insert(a)
        context.insert(b)
        context.insert(c)
        // 初始 project：3 个成员，memberCount 由 init 算为 3。
        let project = Project(title: "Crew", intro: "", notes: "", tag: "",
                              members: [a, b, c], createdAt: .now)
        context.insert(project)
        try context.save()
        #expect(project.memberCount == 3)

        // V5 edit 模式：VM 预填既有 members。
        let vm = QuickAddViewModel(context: context, defaultKind: .project, editingProject: project)
        #expect(vm.isEditing)
        #expect(vm.projectMembers.count == 3)

        // 删一个（a）→ 净 [b, c]，count 从 3 降到 2（若 submit 未重算会错误地保留 3）。
        vm.toggleMember(a)
        #expect(vm.projectMembers.count == 2)

        _ = try vm.submit()

        let edited = try context.fetch(FetchDescriptor<Project>()).first
        #expect((edited?.members ?? []).count == 2)
        // F2 冗余字段：edit 路径必须经 submit 重算为 2，而非沿用旧 memberCount 3。
        #expect(edited?.memberCount == 2)
        #expect(edited?.memberCount == (edited?.members ?? []).count)
        let ids = Set((edited?.members ?? []).map(\.id))
        #expect(ids == Set([b.id, c.id]))
    }
}
