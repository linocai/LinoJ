// QuickAddViewModelEventEditTests.swift
// W4：事件编辑模式（QuickAddViewModel editingEvent）测试。
//
// 覆盖 plan W4「验收标准」的可测部分：
//  1. editingEvent init 后 kind 强制 .event + 各字段预填既有 event 值（title/start/end/location/
//     attendees/project + editingEventID + isEditingEvent + isEditingAny）。
//  2. edit 模式 submit 走 update（既有 event 原地更新，Event 总数不变、返回原 id）。
//  3. edit 模式改 attendees 后 submit，回写正确（attendee 数对、id 对）。
//  4. fetch 不到（edit 期间 event 被删）回退创建，不静默丢输入。
//  5. attendedConfirmed 不在编辑表单内，edit 后保留既有值（true 仍 true）。
//  6. isEditing 语义保持不变（event edit 模式下 isEditing == false，isEditingEvent == true）。
//
// 测试用 inMemory container —— 不污染开发机持久存储。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("QuickAddViewModel — event edit mode (W4)")
@MainActor
struct QuickAddViewModelEventEditTests {

    private func makeEmptyContext() throws -> ModelContext {
        let container = try LinoJStore.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    private func makeEvent(
        in context: ModelContext,
        title: String = "Design review",
        attendees: [Person] = [],
        project: Project? = nil,
        attendedConfirmed: Bool = false
    ) throws -> Event {
        let cal = Calendar.current
        let day = cal.date(from: DateComponents(year: 2026, month: 6, day: 3))!
        let start = cal.date(byAdding: .hour, value: 14, to: day)!
        let end = cal.date(byAdding: .hour, value: 15, to: day)!
        let event = Event(
            title: title,
            start: start,
            end: end,
            location: "Conf Rm A",
            attendees: attendees,
            project: project,
            attendedConfirmed: attendedConfirmed
        )
        context.insert(event)
        try context.save()
        return event
    }

    // MARK: 1. edit 模式 init 预填

    @Test("editingEvent init 后 kind=.event + 各字段预填既有 event 值")
    func editEventInitPrefillsFields() throws {
        let context = try makeEmptyContext()
        let mei = Person(name: "Mei")
        let proj = Project(title: "Calendar v2", intro: "", notes: "", tag: "", members: [], createdAt: .now)
        context.insert(proj)
        let event = try makeEvent(in: context, title: "1:1 with Mei", attendees: [mei], project: proj)

        // 即便 defaultKind 给 .todo，也应被强制为 .event。
        let vm = QuickAddViewModel(context: context, defaultKind: .todo, editingEvent: event)

        #expect(vm.isEditingEvent == true)
        #expect(vm.isEditing == false, "isEditing 语义保持 = project edit；event edit 下应为 false")
        #expect(vm.isEditingAny == true)
        #expect(vm.editingEventID == event.id)
        #expect(vm.kind == .event)
        #expect(vm.eventTitle == "1:1 with Mei")
        #expect(vm.eventLocation == "Conf Rm A")
        #expect(vm.eventAttendees.count == 1)
        #expect(vm.eventAttendees.first?.id == mei.id)
        #expect(vm.eventProject?.id == proj.id)
        // 时间拆装：start/end 应被预填进 eventStart/eventEnd（时分对得上）。
        let cal = Calendar.current
        #expect(cal.component(.hour, from: vm.eventStart) == 14)
        #expect(cal.component(.hour, from: vm.eventEnd) == 15)
        // eventDate 的日期应等于 event.start 的日期。
        #expect(cal.isDate(vm.eventDate, inSameDayAs: event.start))
        // 标题非空 + end>start → canSubmit。
        #expect(vm.canSubmit == true)
    }

    // MARK: 2. edit 模式 submit 走 update（不新增）

    @Test("edit 模式 submit 后既有 event 原地更新，Event 总数不变，返回原 id")
    func editEventSubmitUpdatesInPlace() throws {
        let context = try makeEmptyContext()
        let event = try makeEvent(in: context, title: "Old title")
        let originalID = event.id

        let before = try context.fetch(FetchDescriptor<Event>()).count
        #expect(before == 1)

        let vm = QuickAddViewModel(context: context, editingEvent: event)
        vm.eventTitle = "New title"
        vm.eventLocation = "Zoom"

        let returnedID = try vm.submit()

        let after = try context.fetch(FetchDescriptor<Event>())
        // 不新增 —— Event 总数仍为 1。
        #expect(after.count == before)
        let updated = after.first
        #expect(updated?.id == originalID)
        #expect(updated?.title == "New title")
        #expect(updated?.location == "Zoom")
        #expect(returnedID == AnyHashable(originalID))
    }

    // MARK: 3. edit 改 attendees 回写

    @Test("edit 模式改 attendees 后 submit，回写正确")
    func editEventSubmitRewritesAttendees() throws {
        let context = try makeEmptyContext()
        let a = Person(name: "Andrew")
        let b = Person(name: "Beth")
        let c = Person(name: "Carl")
        let event = try makeEvent(in: context, attendees: [a])
        #expect((event.attendees ?? []).count == 1)

        // 增到 3 人。
        let vm = QuickAddViewModel(context: context, editingEvent: event)
        vm.eventAttendees = [a, b, c]
        _ = try vm.submit()

        let updated = try context.fetch(FetchDescriptor<Event>()).first
        #expect((updated?.attendees ?? []).count == 3)

        // 再 edit：减回 1 人。
        let vm2 = QuickAddViewModel(context: context, editingEvent: updated!)
        vm2.eventAttendees = [b]
        _ = try vm2.submit()

        let updated2 = try context.fetch(FetchDescriptor<Event>()).first
        #expect((updated2?.attendees ?? []).count == 1)
        #expect((updated2?.attendees ?? []).first?.id == b.id)
    }

    // MARK: 4. fetch 不到回退创建

    @Test("edit 期间 event 被删，submit 回退为创建（不静默丢输入）")
    func editEventSubmitFallsBackToCreateWhenMissing() throws {
        let context = try makeEmptyContext()
        let event = try makeEvent(in: context, title: "Will be deleted")

        let vm = QuickAddViewModel(context: context, editingEvent: event)
        vm.eventTitle = "Recovered title"

        // 模拟 edit 期间被删（如跨端同步删除）。
        context.delete(event)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Event>()).isEmpty)

        // submit 应回退为创建一条新 event，而非静默丢输入。
        _ = try vm.submit()
        let after = try context.fetch(FetchDescriptor<Event>())
        #expect(after.count == 1)
        #expect(after.first?.title == "Recovered title")
    }

    // MARK: 5. attendedConfirmed 编辑后保留

    @Test("edit 模式 submit 后 attendedConfirmed 保留既有值（不被表单清空）")
    func editEventSubmitPreservesAttendedConfirmed() throws {
        let context = try makeEmptyContext()
        let event = try makeEvent(in: context, attendedConfirmed: true)
        #expect(event.attendedConfirmed == true)

        let vm = QuickAddViewModel(context: context, editingEvent: event)
        vm.eventTitle = "Edited but still attended"
        _ = try vm.submit()

        let updated = try context.fetch(FetchDescriptor<Event>()).first
        #expect(updated?.attendedConfirmed == true, "attendedConfirmed 不在编辑表单内，edit 后应保留既有值")
    }

    // MARK: 6. editingProject 与 editingEvent 互斥（create 模式默认两者皆 nil）

    @Test("create 模式（无 editing*）下 isEditing / isEditingEvent / isEditingAny 全 false")
    func createModeNoEditFlags() throws {
        let context = try makeEmptyContext()
        let vm = QuickAddViewModel(context: context, defaultKind: .event)
        #expect(vm.isEditing == false)
        #expect(vm.isEditingEvent == false)
        #expect(vm.isEditingAny == false)
        #expect(vm.editingEventID == nil)
    }
}
