// NoteModelTests.swift
// U1（v1.1）：验证 `@Model Note` 的富文本编解码 round-trip、displayTitle 派生、updatedAt 默认值，
// 以及 Note 已注册进 schema（in-memory 容器能 insert / fetch）。
//
// ⚠️ CloudKit 关系 / 约束校验只在真机加载 `.private` 容器时触发（本 Note 无关系字段，
// 但 schema 注册仍需真机确认 `.private` 容器接受新 record type）—— inMemory + .none 单测抓不到，
// 详见 plan U1 验收标准「必须真机验证容器加载」。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("Note model — 富文本编解码 / displayTitle / schema")
@MainActor
struct NoteModelTests {

    private func makeContext() throws -> ModelContext {
        let container = try LinoJStore.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    // MARK: - 默认值（CloudKit 约束①）

    @Test("Note 默认值：空正文 / 未置顶 / createdAt≈updatedAt≈now")
    func defaultValues() {
        let before = Date.now
        let note = Note()
        let after = Date.now

        #expect(note.isPinned == false)
        #expect(String(note.body.characters).isEmpty)
        // updatedAt / createdAt 默认 .now，落在构造前后的时间窗内。
        #expect(note.updatedAt >= before && note.updatedAt <= after)
        #expect(note.createdAt >= before && note.createdAt <= after)
    }

    // MARK: - 富文本编解码 round-trip（含加粗 / 项目符号）

    @Test("body round-trip：纯文本写入→bodyData 非空→读回内容一致")
    func plainTextRoundTrip() throws {
        let context = try makeContext()
        let note = Note(body: AttributedString("Hello world"))
        context.insert(note)
        try context.save()

        #expect(note.bodyData.isEmpty == false, "非空正文写入后 bodyData 应非空")

        let id = note.id
        var descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        let fetched = try #require(try context.fetch(descriptor).first)
        #expect(String(fetched.body.characters) == "Hello world")
    }

    @Test("body round-trip：含加粗属性 + 项目符号文本，属性保留")
    func attributedRoundTrip() throws {
        let context = try makeContext()

        // 用 Foundation 作用域的 inlinePresentationIntent = .stronglyEmphasized（即「加粗」）——
        // 这是 AttributedString 默认 Codable 覆盖的属性，能真正经 JSONEncoder/Decoder round-trip。
        // 同时含一行项目符号（• 前缀的纯文本行），验证特殊字符 + 换行保留。
        var attributed = AttributedString("Bold here\n• bullet item")
        if let range = attributed.range(of: "Bold") {
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
        }
        let note = Note(body: attributed)
        context.insert(note)
        try context.save()

        let id = note.id
        var descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        let fetched = try #require(try context.fetch(descriptor).first)

        // 纯文本内容一致（含项目符号字符 + 换行）。
        #expect(String(fetched.body.characters) == "Bold here\n• bullet item")

        // 加粗（stronglyEmphasized）属性在 round-trip 后仍然存在。
        let decoded = fetched.body
        if let range = decoded.range(of: "Bold") {
            #expect(
                decoded[range].inlinePresentationIntent == .stronglyEmphasized,
                "加粗 run 的 inlinePresentationIntent 应在 round-trip 后保留"
            )
        } else {
            Issue.record("解码后找不到 'Bold' 区段")
        }
    }

    @Test("body 损坏数据兜底空串")
    func corruptedBodyDataFallsBackEmpty() {
        let note = Note()
        note.bodyData = Data([0x00, 0x01, 0x02])   // 非法 JSON
        #expect(String(note.body.characters).isEmpty, "损坏 bodyData 应解码兜底为空串")
    }

    // MARK: - displayTitle 派生

    @Test("displayTitle：取正文首个非空行（trim）")
    func displayTitleFirstLine() {
        let note = Note(body: AttributedString("  First line  \nSecond line"))
        #expect(note.displayTitle == "First line")
    }

    @Test("displayTitle：跳过开头空行，取首个非空行")
    func displayTitleSkipsLeadingBlankLines() {
        let note = Note(body: AttributedString("\n   \nReal title\nbody"))
        #expect(note.displayTitle == "Real title")
    }

    @Test("displayTitle：空正文回退本地化「新笔记 / New note」")
    func displayTitleEmptyFallback() {
        let note = Note()
        let untitled = String(localized: LJStrings.noteUntitled)
        #expect(note.displayTitle == untitled)
        // 双语回退非空（确认 key 存在、未 fallback 到 raw key）。
        #expect(untitled.isEmpty == false)
        #expect(untitled != "Note.untitled", "displayTitle 回退不应是 raw key —— 说明本地化未解析")
    }

    @Test("displayTitle：全空白正文也回退占位")
    func displayTitleWhitespaceOnlyFallback() {
        let note = Note(body: AttributedString("   \n  \t  "))
        #expect(note.displayTitle == String(localized: LJStrings.noteUntitled))
    }

    // MARK: - schema 注册（Note 已入 Schema，可 insert / fetch / delete）

    @Test("Note CRUD：insert / fetch / delete（验证 schema 已注册 Note）")
    func noteCRUD() throws {
        let context = try makeContext()
        let note = Note(body: AttributedString("Note A"), isPinned: true)
        context.insert(note)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Note>())
        try #require(fetched.count == 1)
        #expect(fetched[0].isPinned == true)
        #expect(fetched[0].displayTitle == "Note A")

        context.delete(fetched[0])
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 0)
    }
}
