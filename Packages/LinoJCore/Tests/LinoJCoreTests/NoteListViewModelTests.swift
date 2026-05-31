// NoteListViewModelTests.swift
// U2（v1.1）：验证 NoteListViewModel 的排序（置顶在上 + updatedAt 倒序）、置顶翻转（重写
// updatedAt + 排序立即变化）、搜索过滤（displayTitle / 正文纯文本，空 query 全量）、增删。
//
// 用 inMemory 容器（不连真实 CloudKit）。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("NoteListViewModel — 排序 / 置顶 / 搜索 / 增删")
@MainActor
struct NoteListViewModelTests {

    private func makeVM() throws -> (NoteListViewModel, ModelContext) {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let vm = NoteListViewModel(context: context)
        return (vm, context)
    }

    /// 插入一条 note，显式设置 body / isPinned / updatedAt（绕过编辑入口直接造测试数据）。
    @discardableResult
    private func insertNote(
        _ context: ModelContext,
        title: String,
        pinned: Bool = false,
        updatedAt: Date
    ) -> Note {
        let note = Note(body: AttributedString(title), isPinned: pinned)
        note.updatedAt = updatedAt
        context.insert(note)
        try? context.save()
        return note
    }

    private func date(_ offsetSeconds: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: 1_000_000 + offsetSeconds)
    }

    // MARK: - 排序：置顶组在上 + 组内 updatedAt 倒序

    @Test("sortedNotes：2 置顶 + 3 非置顶，置顶组恒在前，组内 updatedAt 倒序")
    func sortedNotesOrdering() throws {
        let (vm, context) = try makeVM()

        // 非置顶 3 条，updatedAt 递增（n1 最早，n3 最新）。
        insertNote(context, title: "n1", pinned: false, updatedAt: date(10))
        insertNote(context, title: "n2", pinned: false, updatedAt: date(20))
        insertNote(context, title: "n3", pinned: false, updatedAt: date(30))
        // 置顶 2 条，updatedAt：p1 较早、p2 较新。
        insertNote(context, title: "p1", pinned: true, updatedAt: date(5))
        insertNote(context, title: "p2", pinned: true, updatedAt: date(40))
        vm.refresh()

        let titles = vm.sortedNotes.map(\.displayTitle)
        // 置顶组在前（按 updatedAt 倒序：p2(40) > p1(5)），后跟非置顶组（n3 > n2 > n1）。
        #expect(titles == ["p2", "p1", "n3", "n2", "n1"])
    }

    // MARK: - togglePinned：重写 updatedAt + 排序立即变化

    @Test("togglePinned 把非置顶 note 顶到顶部，并刷新其 updatedAt")
    func togglePinnedJumpsToTopAndBumpsUpdatedAt() throws {
        let (vm, context) = try makeVM()
        insertNote(context, title: "a", pinned: false, updatedAt: date(30))
        insertNote(context, title: "b", pinned: false, updatedAt: date(20))
        let c = insertNote(context, title: "c", pinned: false, updatedAt: date(10))
        vm.refresh()

        // 初始：a(30) > b(20) > c(10)，c 在最后。
        #expect(vm.sortedNotes.map(\.displayTitle) == ["a", "b", "c"])

        let before = c.updatedAt
        vm.togglePinned(c)

        // c 现在置顶，updatedAt 被刷新到更晚的时间。
        #expect(c.isPinned == true)
        #expect(c.updatedAt > before)
        // 置顶组（仅 c）在最上，其余非置顶按原 updatedAt 倒序。
        #expect(vm.sortedNotes.map(\.displayTitle) == ["c", "a", "b"])
    }

    @Test("togglePinned 取消置顶后该 note 回到非置顶组")
    func togglePinnedUnpins() throws {
        let (vm, context) = try makeVM()
        let p = insertNote(context, title: "p", pinned: true, updatedAt: date(10))
        insertNote(context, title: "n", pinned: false, updatedAt: date(100))
        vm.refresh()
        // 置顶恒在上：p 在前（即使 updatedAt 比 n 早）。
        #expect(vm.sortedNotes.map(\.displayTitle) == ["p", "n"])

        vm.togglePinned(p) // 取消置顶，updatedAt 刷新到 .now（> n 的 date(100)）
        #expect(p.isPinned == false)
        // 现在全是非置顶，按 updatedAt 倒序：p（刚刷新成 now）> n。
        #expect(vm.sortedNotes.map(\.displayTitle) == ["p", "n"])
    }

    // MARK: - results：搜索过滤

    @Test("results：空 query 返回全量 sortedNotes")
    func resultsEmptyQueryReturnsAll() throws {
        let (vm, context) = try makeVM()
        insertNote(context, title: "alpha", updatedAt: date(20))
        insertNote(context, title: "beta", updatedAt: date(10))
        vm.refresh()
        vm.searchText = "   "  // 全空白 trim 后为空 → 全量
        #expect(vm.results.count == 2)
        #expect(vm.results.map(\.displayTitle) == ["alpha", "beta"])
    }

    @Test("results：按 displayTitle 匹配（大小写不敏感）")
    func resultsMatchByTitle() throws {
        let (vm, context) = try makeVM()
        insertNote(context, title: "Grocery list", updatedAt: date(20))
        insertNote(context, title: "Meeting notes", updatedAt: date(10))
        vm.refresh()
        vm.searchText = "GROCERY"
        #expect(vm.results.map(\.displayTitle) == ["Grocery list"])
    }

    @Test("results：匹配正文非首行（纯文本 body）")
    func resultsMatchByBodyText() throws {
        let (vm, context) = try makeVM()
        // 首行是标题，第二行含关键词 abc —— 搜索应命中正文。
        insertNote(context, title: "Title only\nhidden abc word", updatedAt: date(20))
        insertNote(context, title: "Unrelated", updatedAt: date(10))
        vm.refresh()
        vm.searchText = "abc"
        #expect(vm.results.count == 1)
        #expect(vm.results.first?.displayTitle == "Title only")
    }

    @Test("results：无匹配返回空")
    func resultsNoMatch() throws {
        let (vm, context) = try makeVM()
        insertNote(context, title: "alpha", updatedAt: date(10))
        vm.refresh()
        vm.searchText = "zzz"
        #expect(vm.results.isEmpty)
    }

    // MARK: - createNote / delete

    @Test("createNote 返回新 Note 且已 insert 进 context（再 fetch 能查到）")
    func createNoteInserts() throws {
        let (vm, context) = try makeVM()
        let created = vm.createNote()
        let fetched = try context.fetch(FetchDescriptor<Note>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == created.id)
    }

    @Test("delete 从 context 移除该 note")
    func deleteRemovesFromContext() throws {
        let (vm, context) = try makeVM()
        let a = insertNote(context, title: "a", updatedAt: date(20))
        insertNote(context, title: "b", updatedAt: date(10))
        vm.refresh()
        #expect(vm.sortedNotes.count == 2)

        vm.delete(a)
        let remaining = try context.fetch(FetchDescriptor<Note>())
        #expect(remaining.contains(where: { $0.id == a.id }) == false)
        #expect(vm.sortedNotes.count == 1)
        #expect(vm.sortedNotes.first?.displayTitle == "b")
    }

    // MARK: - recentNotes

    @Test("recentNotes(limit:) 返回 sortedNotes 前 N 条")
    func recentNotesPrefix() throws {
        let (vm, context) = try makeVM()
        insertNote(context, title: "n1", updatedAt: date(10))
        insertNote(context, title: "n2", updatedAt: date(20))
        insertNote(context, title: "n3", updatedAt: date(30))
        insertNote(context, title: "n4", updatedAt: date(40))
        vm.refresh()
        // sortedNotes 倒序：n4 > n3 > n2 > n1。
        #expect(vm.recentNotes(limit: 3).map(\.displayTitle) == ["n4", "n3", "n2"])
        // 默认 limit == 3。
        #expect(vm.recentNotes().count == 3)
        // limit 大于总数时返回全部，不越界。
        #expect(vm.recentNotes(limit: 10).count == 4)
    }
}
