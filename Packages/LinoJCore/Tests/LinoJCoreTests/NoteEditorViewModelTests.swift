// NoteEditorViewModelTests.swift
// U2（v1.1）：验证 NoteEditorViewModel 的正文写回（set body → note.body + note.updatedAt
// 同步刷新）、save()、togglePinned（翻 isPinned + 重写 updatedAt）、deleteSelf。
//
// 用 inMemory 容器。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("NoteEditorViewModel — body 写回 / updatedAt 刷新 / 置顶 / 删除")
@MainActor
struct NoteEditorViewModelTests {

    private func makeContext() throws -> ModelContext {
        let container = try LinoJStore.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    // MARK: - body 写回 + updatedAt 刷新

    @Test("set body → note.body 内容更新，note.updatedAt 比 set 前更晚")
    func setBodyWritesBackAndBumpsUpdatedAt() throws {
        let context = try makeContext()
        // 用一个明显早于 .now 的 updatedAt，确保 set 后被刷新到更晚。
        let note = Note(body: AttributedString("old"))
        note.updatedAt = Date(timeIntervalSinceReferenceDate: 0)
        context.insert(note)
        try context.save()

        let editor = NoteEditorViewModel(context: context, note: note)
        let before = note.updatedAt

        editor.body = AttributedString("new content")

        // note.body 已被写回。
        #expect(String(note.body.characters) == "new content")
        // getter 与 note.body 一致。
        #expect(String(editor.body.characters) == "new content")
        // updatedAt 被刷新到更晚。
        #expect(note.updatedAt > before)
    }

    @Test("body getter 转发 note.body")
    func bodyGetterReflectsNote() throws {
        let context = try makeContext()
        let note = Note(body: AttributedString("hello"))
        context.insert(note)
        let editor = NoteEditorViewModel(context: context, note: note)
        #expect(String(editor.body.characters) == "hello")
    }

    @Test("save() 持久化内存改动（re-fetch 能读到新正文）")
    func savePersists() throws {
        let context = try makeContext()
        let note = Note(body: AttributedString("draft"))
        context.insert(note)
        try context.save()

        let editor = NoteEditorViewModel(context: context, note: note)
        editor.body = AttributedString("saved body")
        editor.save()

        let id = note.id
        var descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        let fetched = try #require(try context.fetch(descriptor).first)
        #expect(String(fetched.body.characters) == "saved body")
    }

    // MARK: - togglePinned

    @Test("togglePinned 翻转 isPinned 并刷新 updatedAt")
    func togglePinnedFlipsAndBumps() throws {
        let context = try makeContext()
        let note = Note(body: AttributedString("x"))
        note.updatedAt = Date(timeIntervalSinceReferenceDate: 0)
        context.insert(note)
        try context.save()

        let editor = NoteEditorViewModel(context: context, note: note)
        #expect(editor.isPinned == false)
        let before = note.updatedAt

        editor.togglePinned()
        #expect(editor.isPinned == true)
        #expect(note.isPinned == true)
        #expect(note.updatedAt > before)

        editor.togglePinned()
        #expect(editor.isPinned == false)
        #expect(note.isPinned == false)
    }

    // MARK: - deleteSelf

    @Test("deleteSelf 从 context 移除该 note")
    func deleteSelfRemoves() throws {
        let context = try makeContext()
        let note = Note(body: AttributedString("doomed"))
        context.insert(note)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 1)

        let editor = NoteEditorViewModel(context: context, note: note)
        editor.deleteSelf()
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 0)
    }
}
