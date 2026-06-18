// InspirationView_macOS.swift
// v1.3 R5（对原型重建）：灵感版块 macOS 改为 **masonry 笔记墙**（决策 D-Inspiration）。
//
// 结构差异核对（U3 旧双栏列表+编辑器 → 原型 masonry 笔记墙）：
//   旧：左列表（320pt：标题 + 计数 + 搜索 + 「+New note」+ note 行）| 右常驻富文本编辑器。
//   原型：单列 **column-count:3 瀑布流**——头部（标题「灵感」+ 副标「随手记下的念头、清单与片段」+
//        品牌渐变「记录灵感」按钮）+ 多色调浅底笔记卡（左 3px 色条 + 标题 + 正文 + mono 日期 + 置顶标记）。
//   → 浏览态按原型重建为 masonry 墙（NoteCard 件，3 列轮转分配近似 column-count:3）。
//
// 编辑能力保留（最小改动方案，写进实施记录）：富文本编辑机制（NoteEditorPane = TextEditor(AttributedString)
//   + 加粗/斜体/标题/项目符号/勾选清单 工具条 + ⋯ 菜单 Pin/Delete）**完整保留不丢**，改为
//   **点击卡片 / 「记录灵感」→ 打开编辑 `.sheet`**（detail-on-demand），而非旧的常驻右栏。
//   删除二次确认 `.confirmationDialog`（抽成 ViewModifier 防 body type-check 超时）+ note 卡 contextMenu
//   Pin/Delete 全保留。正文存储仍走 U1 `Note.bodyData`（AttributedString JSON），U1/U2 契约不破。
//
// 数据流：自持 NoteListViewModel（排序 / 搜索 / 增删置顶）；编辑用 NoteEditorViewModel（NoteEditorPane 内）。
// 编辑目标用 note.id（UUID）跟踪 —— note 被删除 / 列表刷新后能稳健失效。

import SwiftUI
import SwiftData
import LinoJCore

struct InspirationView_macOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(TabRouter.self) private var router

    /// 列表 ViewModel —— `.task` 中由 modelContext 实例化（Optional 兜底让 body 在 task fire 前可编译）。
    @State private var listVM: NoteListViewModel?

    /// `@Query` 拉所有 Note，仅用于触发 invalidation（数据变化 → onChange → listVM.refresh()）。
    @Query private var notes: [Note]

    /// 当前编辑中的 note id（nil = 未打开编辑 sheet）。用 id 而非引用，删除后能稳健失效。
    @State private var editingNoteID: UUID?

    /// W4 同模式：待删除确认的 note（驱动 `.confirmationDialog`）。nil = 无弹窗。
    @State private var notePendingDelete: Note?

    /// masonry 列数。
    private let columnCount = 3

    var body: some View {
        Group {
            if let listVM {
                content(listVM: listVM)
            } else {
                // v1.3 R5：透明占位，让 RootWindow 背景层（底色 + orb）透上来。
                Color.clear
            }
        }
        .task {
            if listVM == nil {
                listVM = NoteListViewModel(context: modelContext)
            }
        }
        // SwiftData 数据变化时让 ViewModel 重算 computed property。
        .onChange(of: notes.count) { _, _ in listVM?.refresh() }
        .onChange(of: notes.map(\.updatedAt)) { _, _ in listVM?.refresh() }
        // 编辑 sheet（detail-on-demand）：点击卡片 / 「记录灵感」打开；保留完整富文本编辑能力。
        .sheet(item: editingNoteBinding) { note in
            noteEditorSheet(note: note)
        }
        // 删除笔记二次确认（抽成 modifier 减轻 body 类型检查负担，见 CLAUDE.md）。
        .modifier(NoteDeleteConfirmModifier(
            pending: $notePendingDelete,
            onConfirm: { note in
                if editingNoteID == note.id { editingNoteID = nil }
                listVM?.delete(note)
            }
        ))
    }

    /// 把 editingNoteID（UUID?）桥接成 `.sheet(item:)` 需要的 `Binding<Note?>`。
    /// note 在 notes 查不到（被删）时自动回 nil，sheet 关闭。
    private var editingNoteBinding: Binding<Note?> {
        Binding(
            get: { editingNoteID.flatMap { id in notes.first { $0.id == id } } },
            set: { editingNoteID = $0?.id }
        )
    }

    // MARK: - masonry 笔记墙布局

    @ViewBuilder
    private func content(listVM: NoteListViewModel) -> some View {
        @Bindable var vm = listVM
        let results = vm.results
        let total = vm.sortedNotes.count

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: LJSpacing.s22) {
                header(listVM: listVM)

                if total == 0 {
                    emptyWall(listVM: listVM)
                } else {
                    masonryWall(notes: results, listVM: listVM)
                }
            }
            .padding(.horizontal, LJSpacing.s28)
            .padding(.top, LJSpacing.s22)
            .padding(.bottom, LJSpacing.s28)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        // v1.3 R5：背景透明 —— 让 RootWindow 底色 + orb 透上来。
    }

    // MARK: - Header（标题 + 副标 + 品牌渐变「记录灵感」）

    @ViewBuilder
    private func header(listVM: NoteListViewModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LJStrings.inspirationTitle).ljDisplayTitleStyle()
                Text(LJStrings.inspirationSubtitle)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
            }
            Spacer(minLength: LJSpacing.s16)
            LJPrimaryButton(LJStrings.recordIdea, systemImage: "plus") {
                createAndEdit(listVM: listVM)
            }
        }
    }

    // MARK: - masonry 墙（3 列轮转分配近似 column-count:3）

    @ViewBuilder
    private func masonryWall(notes: [Note], listVM: NoteListViewModel) -> some View {
        // 轮转分配：第 i 张卡进第 (i % columnCount) 列，逐列纵向堆叠（近似 CSS column-count 的列内 top-down 流）。
        let columns: [[Note]] = (0..<columnCount).map { col in
            notes.enumerated().compactMap { idx, n in idx % columnCount == col ? n : nil }
        }
        HStack(alignment: .top, spacing: LJSpacing.s16) {
            ForEach(0..<columnCount, id: \.self) { col in
                VStack(alignment: .leading, spacing: LJSpacing.s16) {
                    ForEach(columns[col], id: \.id) { note in
                        NoteCard(note: note) {
                            editingNoteID = note.id
                        }
                        .contextMenu {
                            noteCardActions(note: note, listVM: listVM)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    /// note 卡 contextMenu：Pin / Unpin + Delete（二次确认）。
    @ViewBuilder
    private func noteCardActions(note: Note, listVM: NoteListViewModel) -> some View {
        Button {
            listVM.togglePinned(note)
        } label: {
            Text(note.isPinned ? LJStrings.noteUnpin : LJStrings.notePin)
        }
        Divider()
        Button(role: .destructive) {
            notePendingDelete = note
        } label: {
            Text(LJStrings.noteDelete)
        }
    }

    // MARK: - 空状态

    @ViewBuilder
    private func emptyWall(listVM: NoteListViewModel) -> some View {
        VStack {
            Spacer(minLength: LJSpacing.s32)
            EmptyState(
                variant: .inboxZero,
                ctaTitle: LJStrings.recordIdea,
                action: { createAndEdit(listVM: listVM) }
            )
            Spacer(minLength: LJSpacing.s32)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    // MARK: - 编辑 sheet（保留完整富文本编辑能力）

    @ViewBuilder
    private func noteEditorSheet(note: Note) -> some View {
        VStack(spacing: 0) {
            NoteEditorPane(
                note: note,
                onTogglePin: { listVM?.togglePinned(note) },
                onRequestDelete: { notePendingDelete = note }
            )
            .id(note.id)

            // 底部「完成」收口（macOS .sheet ESC 不自动 dismiss，需绑 .cancelAction，见 CLAUDE.md）。
            Divider().overlay(Color.lj.border)
            HStack {
                Spacer()
                Button {
                    editingNoteID = nil
                } label: {
                    Text(LJStrings.commonDone)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.lj.bg)
                        .padding(.horizontal, LJSpacing.s14)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.lj.ink)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, LJSpacing.s16)
            .padding(.vertical, LJSpacing.s12)
            .background(Color.lj.bgSoft)
        }
        .frame(width: 560, height: 520)
        .background(Color.lj.panel)
    }

    // MARK: - Helpers

    /// 新建 note 并立即打开编辑 sheet。
    private func createAndEdit(listVM: NoteListViewModel) {
        let note = listVM.createNote()
        editingNoteID = note.id
    }
}

// MARK: - 编辑器面板（独立 View，持有 NoteEditorViewModel）

/// 单条 note 富文本编辑面板：顶栏（`⋯` 菜单）+ 富文本工具条 + TextEditor。
/// 拆成独立 View 让 NoteEditorViewModel 随 note 生命周期重建（外层用 `.id(note.id)`）。
private struct NoteEditorPane: View {
    let note: Note
    let onTogglePin: () -> Void
    let onRequestDelete: () -> Void

    @Environment(\.modelContext) private var modelContext

    /// 编辑器 VM —— `.task` 中由 modelContext + note 实例化。
    @State private var editorVM: NoteEditorViewModel?

    /// 富文本绑定的本地副本（与 editorVM.body 双向同步）。
    @State private var text = AttributedString()

    /// 选区 —— transformAttributes / replaceSelection 都需要它。
    @State private var selection = AttributedTextSelection()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶栏：占位标题预览 + `⋯` 菜单
            editorHeader

            Divider().overlay(Color.lj.border)

            // 富文本工具条
            formatToolbar

            Divider().overlay(Color.lj.border)

            // TextEditor 富文本区
            TextEditor(text: $text, selection: $selection)
                .font(.system(size: 14, weight: .regular))
                .scrollContentBackground(.hidden)
                .background(Color.lj.bg)
                .padding(.horizontal, LJSpacing.s22)
                .padding(.vertical, LJSpacing.s16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.lj.bg)
        .task {
            let vm = NoteEditorViewModel(context: modelContext, note: note)
            editorVM = vm
            text = vm.body
        }
        // 用户编辑 → 写回 VM（VM 内部重写 updatedAt）。
        .onChange(of: text) { _, newValue in
            editorVM?.body = newValue
        }
        // 退出编辑器 / 切 note 时 save 一次（避免高频 save，见 NoteEditorViewModel 注释）。
        .onDisappear {
            editorVM?.save()
        }
    }

    // MARK: 顶栏

    @ViewBuilder
    private var editorHeader: some View {
        HStack(alignment: .center, spacing: LJSpacing.s10) {
            // 标题预览（取 displayTitle；空正文显示占位）。
            Text(displayTitlePreview)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isUntitled ? Color.lj.inkMute : Color.lj.ink)
                .lineLimit(1)
            Spacer()
            // `⋯` 菜单：Pin/Unpin + Delete
            Menu {
                Button {
                    onTogglePin()
                } label: {
                    Text(note.isPinned ? LJStrings.noteUnpin : LJStrings.notePin)
                }
                Divider()
                Button(role: .destructive) {
                    onRequestDelete()
                } label: {
                    Text(LJStrings.noteDelete)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.lj.inkSoft)
                    .frame(width: 28, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, LJSpacing.s22)
        .frame(height: 44)
    }

    private var displayTitlePreview: String {
        let plain = String(text.characters)
        for line in plain.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return String(localized: LJStrings.inspirationTitlePlaceholder)
    }

    private var isUntitled: Bool {
        String(text.characters).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: 富文本工具条

    @ViewBuilder
    private var formatToolbar: some View {
        HStack(spacing: LJSpacing.s4) {
            toolbarButton(systemName: "bold", label: LJStrings.formatBold) { applyBold() }
            toolbarButton(systemName: "italic", label: LJStrings.formatItalic) { applyItalic() }
            toolbarButton(systemName: "textformat.size.larger", label: LJStrings.formatHeading) { applyHeading() }
            Divider().frame(height: 16).overlay(Color.lj.border)
            toolbarButton(systemName: "list.bullet", label: LJStrings.formatBullet) { insertBullet() }
            toolbarButton(systemName: "checklist", label: LJStrings.formatChecklist) { insertChecklist() }
            Spacer()
        }
        .padding(.horizontal, LJSpacing.s18)
        .frame(height: 36)
    }

    @ViewBuilder
    private func toolbarButton(
        systemName: String,
        label: LocalizedStringResource,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.lj.inkSoft)
                .frame(width: 28, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .ljHoverBackground()
        .help(Text(label))
        .accessibilityLabel(Text(label))
    }

    // MARK: 格式化动作（原生富文本 API，U3 验证可用）

    /// 加粗：对选区 font 翻 bold（已 bold 则去 bold）。
    private func applyBold() {
        text.transformAttributes(in: &selection) { container in
            let resolved = container.font ?? .system(size: 14)
            container.font = resolved.bold()
        }
    }

    /// 斜体。
    private func applyItalic() {
        text.transformAttributes(in: &selection) { container in
            let resolved = container.font ?? .system(size: 14)
            container.font = resolved.italic()
        }
    }

    /// 标题：选区字号放大 + semibold。
    private func applyHeading() {
        text.transformAttributes(in: &selection) { container in
            container.font = .system(size: 20, weight: .semibold)
        }
    }

    /// 项目符号：在选区位置插入「• 」前缀（可编辑 TextEditor 用行前缀方案）。
    private func insertBullet() {
        text.replaceSelection(&selection, withCharacters: "• ")
    }

    /// 勾选清单：插入「☐ 」前缀（勾选切换由用户手动改 ☐/☑ 字形，MVP）。
    private func insertChecklist() {
        text.replaceSelection(&selection, withCharacters: "☐ ")
    }
}

// MARK: - 删除笔记确认对话框 modifier

/// 把 `.confirmationDialog` 抽成独立 modifier —— 直接挂在长 body 链上会触发
/// 「unable to type-check this expression in reasonable time」（见 CLAUDE.md）。
/// confirm message / 按钮文案复用 W4 的 Event.deleteConfirm*（plan U3 指明可复用）。
private struct NoteDeleteConfirmModifier: ViewModifier {
    @Binding var pending: Note?
    let onConfirm: (Note) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text(LJStrings.noteDeleteConfirmTitle),
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            titleVisibility: .visible,
            presenting: pending
        ) { note in
            Button(role: .destructive) {
                onConfirm(note)
                pending = nil
            } label: {
                Text(LJStrings.eventDeleteConfirmConfirm)
            }
            Button(role: .cancel) {
                pending = nil
            } label: {
                Text(LJStrings.quickAddCancel)
            }
        } message: { _ in
            Text(LJStrings.eventDeleteConfirmMessage)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    do {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let ctx = container.mainContext
        // 塞几条 note 让 preview 有内容。
        let n1 = Note(body: AttributedString("Renovate the moon\nNeed a bigger ladder"))
        n1.isPinned = true
        let n2 = Note(body: AttributedString("Standup notes\n- ship v1.1"))
        ctx.insert(n1); ctx.insert(n2)
        try? ctx.save()
        return InspirationView_macOS()
            .environment(TabRouter())
            .modelContainer(container)
            .frame(width: 1000, height: 700)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
#endif
