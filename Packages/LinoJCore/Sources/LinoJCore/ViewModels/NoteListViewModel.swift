// NoteListViewModel.swift
// U2（v1.1）：灵感版块列表的 ViewModel —— 负责排序 / 搜索 / 增删改置顶。
//
// 数据流照搬 MainViewModel / CalendarViewModel 模式：
//   - `@Observable @MainActor` final class；
//   - init 拿 ModelContext（View 通过 `@Environment(\.modelContext)` 注入）；
//   - `tick` 用于驱动所有 computed property 在 View `.onChange`（@Query 变化）时重新 fetch；
//   - 增删改置顶走 `context.insert/delete` + `try? context.save()` + `refresh()`（与既有 VM 同模式）。
//
// 排序契约（plan U2，定死）：
//   - 置顶（`isPinned == true`）组恒在列表上方；
//   - 每组内按 `updatedAt` 倒序（最近编辑在前）；
//   - 两组拼接（pinned 组 + 非 pinned 组）。
//
// `updatedAt` 写回纪律（U1 硬约束⑤ → U2 落地）：
//   - 任何对 `isPinned` 的变更（togglePinned）都必须重写 `updatedAt = .now`
//     —— 它是列表倒序排序键 + CloudKit 冲突 last-writer-wins，不可旁路。
//   - 正文编辑的 `updatedAt` 写回在 `NoteEditorViewModel.body` 的 setter 里负责。

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class NoteListViewModel {

    // MARK: - Stored

    /// SwiftData 上下文。View 通过 `@Environment(\.modelContext)` 拿到后注入。
    private let context: ModelContext

    /// Refresh tick —— 任意写入都让 Observation 把所有 computed property 标记为脏，
    /// 下一次 SwiftUI re-render 重新走 fetch。
    private var tick: Int = 0

    /// 搜索框文本。setter 直接驱动 `results` 重算（computed 依赖 `searchText`，无需 tick）。
    public var searchText: String = ""

    // MARK: - Init

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Refresh hook

    /// View 层在 `@Query` 数据变化时调用，让所有 computed property 在下一帧重新 fetch。
    public func refresh() {
        tick &+= 1
    }

    // MARK: - Derived

    /// 全部 note，按排序契约排列：置顶组在上，各组内 `updatedAt` 倒序。
    public var sortedNotes: [Note] {
        _ = tick
        let all = allNotes()
        let pinned = all
            .filter { $0.isPinned }
            .sorted { $0.updatedAt > $1.updatedAt }
        let others = all
            .filter { !$0.isPinned }
            .sorted { $0.updatedAt > $1.updatedAt }
        return pinned + others
    }

    /// 应用 `searchText` 后的列表。空 query（trim 后为空）返回 `sortedNotes` 全量；
    /// 否则按 `displayTitle` + 正文纯文本做大小写不敏感 contains 过滤（与 SearchViewModel 同风格）。
    /// 过滤后仍保持 `sortedNotes` 的排序（置顶在上 + updatedAt 倒序）。
    public var results: [Note] {
        _ = tick
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sortedNotes }
        let needle = trimmed.lowercased()
        return sortedNotes.filter {
            $0.displayTitle.lowercased().contains(needle)
                || String($0.body.characters).lowercased().contains(needle)
        }
    }

    /// `sortedNotes` 前 N 条，供 Main 右栏「最近灵感」缩略卡用（默认 3 条）。
    public func recentNotes(limit: Int = 3) -> [Note] {
        Array(sortedNotes.prefix(max(0, limit)))
    }

    // MARK: - Mutations

    /// 新建一条空 note：`insert` + save + refresh，返回新实例（供 UI 立即打开编辑器）。
    @discardableResult
    public func createNote() -> Note {
        let note = Note()
        context.insert(note)
        try? context.save()
        refresh()
        return note
    }

    /// 删除一条 note：`context.delete` + save + refresh（与既有 VM 同模式）。
    public func delete(_ note: Note) {
        context.delete(note)
        try? context.save()
        refresh()
    }

    /// 翻转置顶态：翻 `isPinned` + **重写 `updatedAt = .now`** + save + refresh。
    /// 置顶 / 取消置顶算一次编辑（影响列表排序），故必须刷新 `updatedAt`（U1 硬约束⑤）。
    public func togglePinned(_ note: Note) {
        note.isPinned.toggle()
        note.updatedAt = .now
        try? context.save()
        refresh()
    }

    // MARK: - Internal helpers

    /// 拉全部 Note。failure 静默退回空数组（UI 上表现为「没东西」，不崩）。
    private func allNotes() -> [Note] {
        (try? context.fetch(FetchDescriptor<Note>())) ?? []
    }
}
