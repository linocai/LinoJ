// NoteEditorViewModel.swift
// U2（v1.1）：单条 Note 富文本编辑的 ViewModel —— 负责正文写回与置顶/删除转发。
//
// 数据流照搬既有 VM 模式（`@Observable @MainActor` + ModelContext 注入）。
//
// 编辑即存（对齐备忘录交互，无显式保存按钮）的写回决策（plan U2，定死）：
//   - `body` 的 setter 立即把新值写回 `note.body`，并**重写 `note.updatedAt = .now`**
//     —— 保证列表顺序在退出编辑器时已正确（updatedAt 是 U2 列表倒序排序键 + CloudKit
//     last-writer-wins，写回纪律见 U1 硬约束⑤，不可旁路）。
//   - `context.save()` 不在每次 set body 时调（避免高频 save 卡 CloudKit），而是由编辑器
//     `onDisappear` 调一次 `save()` 兜底；但 `updatedAt` 在 setter 里实时更新。
//
// togglePinned / deleteSelf 供编辑器顶栏 `⋯` 菜单用，直接对该 note 操作并 save。

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class NoteEditorViewModel {

    // MARK: - Stored

    /// SwiftData 上下文。View 通过 `@Environment(\.modelContext)` 拿到后注入。
    private let context: ModelContext

    /// 正在编辑的 note（@Model 引用，与编辑器生命周期同步）。
    private let note: Note

    // MARK: - Init

    public init(context: ModelContext, note: Note) {
        self.context = context
        self.note = note
    }

    // MARK: - Body editing

    /// 富文本正文。get 转发 `note.body`；set 立即写回 `note.body` 并重写 `note.updatedAt = .now`。
    /// 不在 setter 里 save —— save 由编辑器 `onDisappear` 调一次（见类型注释）。
    public var body: AttributedString {
        get { note.body }
        set {
            note.body = newValue
            note.updatedAt = .now
        }
    }

    /// 当前 note 的置顶态（供编辑器顶栏菜单显示 Pin / Unpin）。
    public var isPinned: Bool {
        note.isPinned
    }

    // MARK: - Persistence

    /// 把内存中对 `note` 的改动落库。编辑器 `onDisappear` 调一次（避免高频 save）。
    public func save() {
        try? context.save()
    }

    // MARK: - Mutations（编辑器顶栏菜单）

    /// 翻转置顶态：翻 `isPinned` + **重写 `updatedAt = .now`** + save（与 NoteListViewModel
    /// 同纪律：置顶算一次编辑，必须刷新排序键）。
    public func togglePinned() {
        note.isPinned.toggle()
        note.updatedAt = .now
        try? context.save()
    }

    /// 删除当前 note：`context.delete` + save（编辑器关闭后由列表 refresh 反映）。
    public func deleteSelf() {
        context.delete(note)
        try? context.save()
    }
}
