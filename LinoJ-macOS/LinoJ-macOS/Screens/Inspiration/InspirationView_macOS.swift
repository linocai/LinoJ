// InspirationView_macOS.swift
// U3（v1.1）：灵感版块 macOS 双栏实现 —— 左列表（~320pt）+ 右富文本编辑器。
//
// 视觉 / 交互契约（plan U3，定死）：
//   - 左列表：大标题「Inspiration」+ 计数副标「X notes」+ 搜索框（chip 样式，绑 vm.searchText）
//     + note 行（displayTitle + 正文摘要单行截断 + updatedAt mono 时间 + 置顶 pin 标记）
//     + 「+ New note」按钮（ink 观感）+ 空状态用 EmptyState。
//   - 右编辑器：标题占位 + 富文本工具条（加粗/斜体/标题/项目符号/勾选清单）+ `⋯` 菜单（Pin/Unpin/Delete）
//     + TextEditor 富文本区（绑 AttributedString）。
//   - 删除走二次确认 `.confirmationDialog`（抽成 ViewModifier 防 body type-check 超时，见 CLAUDE.md）。
//   - note 行 `.contextMenu` 含 Pin / Delete。
//
// 富文本 API 结论（U3 施工首步验证，落地原生方案）：
//   macOS 26.5 下 `TextEditor(text: $attributedString, selection: $selection)` 编译 + 运行可用。
//   - 加粗 / 斜体 / 标题：`selectedText.transformAttributes(in:&selection) { $0.font = ... }`。
//   - 项目符号 / 勾选清单：编辑器内 `replaceSelection(&selection, withCharacters:)` 在行首插入
//     「• 」/「☐ 」前缀（可编辑 TextEditor 不交互渲染 presentationIntent 列表，故用前缀方案）。
//   正文存储仍走 U1 `Note.bodyData`（AttributedString JSON）不变，U1/U2 契约不破。
//
// 数据流：左列表自持 NoteListViewModel；选中某 note 后右侧用 NoteEditorViewModel 编辑。
// selection 用 note.id（UUID）跟踪 —— note 被删除 / 列表刷新后能稳健失效回 nil。

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

    /// 当前选中的 note id（nil = 未选中，右侧显示空态）。用 id 而非引用，删除后能稳健失效。
    @State private var selectedNoteID: UUID?

    /// W4 同模式：待删除确认的 note（驱动 `.confirmationDialog`）。nil = 无弹窗。
    @State private var notePendingDelete: Note?

    var body: some View {
        Group {
            if let listVM {
                content(listVM: listVM)
            } else {
                Color.lj.bg
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
        // 删除笔记二次确认（抽成 modifier 减轻 body 类型检查负担，见 CLAUDE.md）。
        .modifier(NoteDeleteConfirmModifier(
            pending: $notePendingDelete,
            onConfirm: { note in
                if selectedNoteID == note.id { selectedNoteID = nil }
                listVM?.delete(note)
            }
        ))
    }

    // MARK: - 双栏布局

    @ViewBuilder
    private func content(listVM: NoteListViewModel) -> some View {
        HStack(spacing: 0) {
            // 左列表 320pt
            noteList(listVM: listVM)
                .frame(width: 320)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.lj.border)
                        .frame(width: 0.5)
                }

            // 右编辑器（flex）
            editorPane(listVM: listVM)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.lj.bg)
    }

    // MARK: - 左列表

    @ViewBuilder
    private func noteList(listVM: NoteListViewModel) -> some View {
        @Bindable var vm = listVM
        let results = vm.results
        let total = vm.sortedNotes.count

        VStack(alignment: .leading, spacing: LJSpacing.s12) {
            // 大标题 + 计数副标
            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s10) {
                Text(LJStrings.inspirationTitle).ljDisplayTitleStyle()
                Text(LJStrings.inspirationNotesCount(total))
                    .font(.system(size: 12.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
            }

            // 搜索框（chip 样式）
            searchField(vm: vm)

            // 「+ New note」按钮（ink 观感）
            newNoteButton(listVM: listVM)

            // 列表 / 空状态
            if total == 0 {
                Spacer()
                EmptyState(
                    variant: .inboxZero,
                    ctaTitle: LJStrings.inspirationNewNote,
                    action: { createAndSelect(listVM: listVM) }
                )
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: LJSpacing.s4) {
                        ForEach(results, id: \.id) { note in
                            noteRow(note: note, listVM: listVM)
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
        }
        .padding(.horizontal, LJSpacing.s18)
        .padding(.top, LJSpacing.s22)
        .padding(.bottom, LJSpacing.s18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.lj.bg)
    }

    /// chip 样式搜索输入框。
    @ViewBuilder
    private func searchField(vm: NoteListViewModel) -> some View {
        @Bindable var vm = vm
        HStack(spacing: LJSpacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.lj.inkMute)
            TextField(text: $vm.searchText) {
                Text(LJStrings.inspirationSearchPlaceholder)
            }
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Color.lj.ink)
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.lj.inkMute)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, LJSpacing.s10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.lj.chip)
        )
    }

    /// 「+ New note」ink 按钮。
    @ViewBuilder
    private func newNoteButton(listVM: NoteListViewModel) -> some View {
        Button {
            createAndSelect(listVM: listVM)
        } label: {
            Text(LJStrings.inspirationNewNote)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.lj.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.lj.ink)
                )
        }
        .buttonStyle(.plain)
    }

    /// 单个 note 行：displayTitle + 正文摘要 + updatedAt mono 时间 + 置顶标记。
    @ViewBuilder
    private func noteRow(note: Note, listVM: NoteListViewModel) -> some View {
        let isSelected = selectedNoteID == note.id
        let snippet = bodySnippet(note)

        Button {
            selectedNoteID = note.id
        } label: {
            HStack(alignment: .top, spacing: LJSpacing.s8) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.lj.inkMute)
                        .padding(.top, 3)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s8) {
                        Text(note.displayTitle)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Color.lj.ink)
                            .lineLimit(1)
                        Spacer(minLength: LJSpacing.s8)
                        Text(timeText(note.updatedAt))
                            .font(.lj.mono)
                            .foregroundStyle(Color.lj.inkMute)
                    }
                    Text(snippet.isEmpty ? " " : snippet)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.lj.inkSoft)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, LJSpacing.s10)
            .padding(.vertical, LJSpacing.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.lj.chip : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            noteRowActions(note: note, listVM: listVM)
        }
    }

    /// note 行 contextMenu：Pin / Unpin + Delete（二次确认）。
    @ViewBuilder
    private func noteRowActions(note: Note, listVM: NoteListViewModel) -> some View {
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

    // MARK: - 右编辑器

    @ViewBuilder
    private func editorPane(listVM: NoteListViewModel) -> some View {
        if let id = selectedNoteID, let note = notes.first(where: { $0.id == id }) {
            // 用 .id(note.id) 强制在切换 note 时重建编辑器（NoteEditorViewModel 持有具体 note）。
            NoteEditorPane(
                note: note,
                onTogglePin: { listVM.togglePinned(note) },
                onRequestDelete: { notePendingDelete = note }
            )
            .id(note.id)
        } else {
            // 未选中：温和提示。
            VStack(spacing: LJSpacing.s14) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Color.lj.inkDim)
                Text(LJStrings.inspirationEmptySubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.lj.bg)
        }
    }

    // MARK: - Helpers

    /// 新建 note 并立即选中（右侧打开编辑器）。
    private func createAndSelect(listVM: NoteListViewModel) {
        let note = listVM.createNote()
        selectedNoteID = note.id
    }

    /// 正文摘要单行：取纯文本去掉首行（displayTitle 已用首行）后的第一段非空文本；无则空串。
    private func bodySnippet(_ note: Note) -> String {
        let plain = String(note.body.characters)
        let lines = plain.split(separator: "\n", omittingEmptySubsequences: false)
        var seenTitle = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if !seenTitle { seenTitle = true; continue }  // 跳过首行（= displayTitle）
            return trimmed
        }
        return ""
    }

    /// "09:30" 等 mono 时间（与 MainView 同格式）。
    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
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
