// InspirationView_iOS.swift
// U4（v1.1）：灵感版块 iOS 实现 —— 单列 push 导航（NavigationStack）。
//
// 视觉 / 交互契约（plan U4，定死；沿用 U3 macOS 视觉契约，iOS 适配为单列 push）：
//   - 导航：NavigationStack，根为 note 列表（大标题「灵感」34pt + 计数 + 搜索栏绑 vm.searchText）；
//     点 note 行 push 进富文本编辑器（全屏）。
//   - 列表：单列 note 行（白卡 14pt radius）：displayTitle 16pt/600 + 正文摘要 inkSoft 单行截断
//     + updatedAt mono 时间 + 置顶 pin 标记。置顶组在上（NoteListViewModel.results 已排好序）。
//   - 新建：列表顶醒目 ink 按钮「+ New note」（搜索框下方、note 列表之上，对齐 macOS 版）
//     → createNote() → push 编辑器。**不放导航栏 trailing**——会与 RootTabView 全局 Floating
//     Actions（.overlay(.topTrailing)）在右上角重叠被遮挡（模拟器实测无法新建）。
//     **不复用全局 Quick Add `+`**（Quick Add 专属 Todo/Event/Project）。
//   - 删除 / 置顶：note 行用 `.contextMenu`（长按 Pin/Unpin/Delete + 二次确认，v1.3 签收前修复
//     🟡-4 由 `.swipeActions` 迁来——该 API 挂在 ScrollView+ForEach 上仅 List 行内生效，原实现静默无效）
//     + 编辑器导航栏 `⋯` 菜单（Pin/Unpin/Delete，删除 `.confirmationDialog`）。编辑器 push 期间
//     隐藏 RootTabView 全局 FloatingActions（router.hideFloatingActions），避免与 `⋯` 几何重叠。
//   - 空状态：复用 EmptyState 组件 + CTA。
//
// 富文本 API 结论（沿用 U3 —— iOS 26 同属一套 SDK，原生 TextEditor(AttributedString) 可用）：
//   `TextEditor(text: $attributedString, selection: $selection)` + transformAttributes / replaceSelection。
//   加粗/斜体/标题走 transformAttributes；项目符号/勾选清单走行前缀插入（「• 」/「☐ 」），MVP 不做可点击复选框（A 方案）。
//   正文存储仍走 U1 Note.bodyData（AttributedString JSON）不变，U1/U2 契约不破。
//
// 数据流：列表自持 NoteListViewModel；@Query 拉所有 Note 仅用于触发 invalidation。
// push 目标用 navigationDestination(item:) 绑 selectedNoteID（UUID）—— note 删除后能稳健失效。

import SwiftUI
import SwiftData
import LinoJCore

struct InspirationView_iOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(TabRouter.self) private var router

    /// 列表 ViewModel —— `.task` 中由 modelContext 实例化（Optional 兜底让 body 在 task fire 前可编译）。
    @State private var listVM: NoteListViewModel?

    /// `@Query` 拉所有 Note，仅用于触发 invalidation（数据变化 → onChange → listVM.refresh()）。
    @Query private var notes: [Note]

    /// push 进编辑器的目标 note id（nil = 在列表根）。用 id 而非引用，删除后能稳健失效。
    @State private var pushedNoteID: UUID?

    /// v1.3 签收前修复（🟡-4）：列表 contextMenu 删除的二次确认（迁自 `.swipeActions`，
    /// ScrollView+ForEach 下 swipeActions 静默无效，改长按 contextMenu 后误触风险更高，
    /// 与 macOS 版 `notePendingDelete` 同模式补确认框）。nil = 无弹窗。
    @State private var notePendingDelete: Note?

    var body: some View {
        NavigationStack {
            Group {
                if let listVM {
                    listContent(listVM: listVM)
                } else {
                    Color.clear.ljScreenBackground(.iOS)
                }
            }
            // v1.3 R7：H1 段标题改为内容内渲染（让出 FloatingActions），隐藏系统大标题导航栏。
            .toolbar(.hidden, for: .navigationBar)
            // push 编辑器（全屏）。绑 pushedNoteID，对应的 note 从 @Query 取（删除后失效回列表）。
            .navigationDestination(item: $pushedNoteID) { id in
                if let note = notes.first(where: { $0.id == id }) {
                    NoteEditorScreen_iOS(
                        note: note,
                        onDeleted: { pushedNoteID = nil }
                    )
                } else {
                    // note 已不存在（被删）—— 回退到列表。
                    Color.lj.iosMainBg
                        .onAppear { pushedNoteID = nil }
                }
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
        // v1.3 签收前修复（🟡-4）：push/pop 编辑器（含删除后自动回列表）都经过 pushedNoteID 变化，
        // 用 onChange 统一同步 router.hideFloatingActions，避免多个设值点各自维护漏更新。
        .onChange(of: pushedNoteID) { _, newValue in
            router.hideFloatingActions = newValue != nil
        }
        .onDisappear {
            router.hideFloatingActions = false
        }
        // v1.3 签收前修复（🟡-4）：contextMenu 删除二次确认（与 macOS 版 NoteDeleteConfirmModifier 同结构）。
        .modifier(NoteListDeleteConfirmModifier(
            pending: $notePendingDelete,
            onConfirm: { note in
                if pushedNoteID == note.id { pushedNoteID = nil }
                listVM?.delete(note)
            }
        ))
    }

    // MARK: - 列表根

    @ViewBuilder
    private func listContent(listVM: NoteListViewModel) -> some View {
        @Bindable var vm = listVM
        // v1.3 签收前修复：恢复内嵌搜索框（🔴-1，接回既有 NoteListViewModel.searchText/results）。
        let total = vm.sortedNotes.count
        let results = vm.results

        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero header（让出 FloatingActions）= H1 + 副标 + 记录灵感主按钮。
                    header(listVM: listVM)
                        .padding(.top, 64)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 22)

                    searchField(listVM: listVM)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    if total == 0 {
                        // 空状态：EmptyState + CTA（新建并 push 编辑器）。
                        EmptyState(
                            variant: .inboxZero,
                            ctaTitle: LJStrings.inspirationNewNote,
                            action: { createAndPush(listVM: listVM) }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    } else if results.isEmpty {
                        // 搜索无结果（复用既有 EmptyState.noResults variant）。
                        EmptyState(variant: .noResults(vm.searchText))
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                    } else {
                        // v1.3 R7：单列笔记墙 —— 复用 R0 `NoteCard` 件（多色调浅底 + 左渐变色条 + mono 日期）。
                        // swipe actions（置顶 / 删除）包在 NoteCard 外层保留。
                        VStack(spacing: 12) {
                            ForEach(results, id: \.id) { note in
                                noteCardRow(note: note, listVM: listVM)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // U8：原生 tab bar 已由系统安全区让位，仅保留小段视觉呼吸。
                    Color.clear.frame(height: 24)
                }
            }
        }
        // v1.3 R7：iOS 底色渐变 + bloom orb。
        .ljScreenBackground(.iOS)
    }

    // MARK: - Header

    /// v1.3 R7（对原型重建）：H1 标题「灵感」+ 副标 + 记录灵感品牌渐变主按钮。
    @ViewBuilder
    private func header(listVM: NoteListViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LJStrings.inspirationTitle).ljDisplayTitleStyle()
                Text(LJStrings.inspirationSubtitle)
                    .font(.system(size: 13.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
            }
            LJPrimaryButton(LJStrings.recordIdea) {
                createAndPush(listVM: listVM)
            }
        }
    }

    // MARK: - 搜索框（v1.3 签收前修复：恢复内嵌搜索，接回既有 NoteListViewModel.searchText）

    /// 小玻璃输入框（`.ultraThinMaterial`），贴合紫蓝玻璃体系；不破坏单列笔记墙布局。
    @ViewBuilder
    private func searchField(listVM: NoteListViewModel) -> some View {
        @Bindable var vm = listVM
        HStack(spacing: LJSpacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.lj.inkMute)
            TextField(text: $vm.searchText) {
                Text(LJStrings.inspirationSearchPlaceholder)
            }
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.lj.ink)
            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.lj.inkMute)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, LJSpacing.s14)
        .frame(height: 38)
        .background {
            Capsule(style: .continuous).fill(.ultraThinMaterial)
        }
        .overlay {
            Capsule(style: .continuous).strokeBorder(Color.lj.borderStrong, lineWidth: 0.5)
        }
        .overlay { LJTopHighlight(radius: 999) }
    }

    /// 单条笔记卡（NoteCard 件 + contextMenu：Pin/Unpin + Delete）。
    /// v1.3 签收前修复（🟡-4）：原 `.swipeActions` 挂在 ScrollView+ForEach 上，该 API 仅 List 行内
    /// 生效，此处静默无效——迁到 `.contextMenu`（长按，ScrollView 下可用，与 macOS 版对齐）。
    @ViewBuilder
    private func noteCardRow(note: Note, listVM: NoteListViewModel) -> some View {
        NoteCard(note: note, onOpen: { pushedNoteID = note.id })
            .contextMenu {
                Button {
                    listVM.togglePinned(note)
                } label: {
                    Label {
                        Text(note.isPinned ? LJStrings.noteUnpin : LJStrings.notePin)
                    } icon: {
                        Image(systemName: note.isPinned ? "pin.slash" : "pin")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    notePendingDelete = note
                } label: {
                    Label { Text(LJStrings.noteDelete) } icon: { Image(systemName: "trash") }
                }
            }
    }

    // MARK: - Helpers

    /// 新建 note 并立即 push 编辑器。
    private func createAndPush(listVM: NoteListViewModel) {
        let note = listVM.createNote()
        pushedNoteID = note.id
    }
}

// MARK: - 编辑器全屏（push 目标，持有 NoteEditorViewModel）

/// 单条 note 富文本编辑全屏：富文本工具条 + TextEditor + 导航栏 `⋯` 菜单（Pin/Unpin/Delete）。
/// 拆成独立 View 让 NoteEditorViewModel 随 note 生命周期重建（外层用 navigationDestination(item:)）。
private struct NoteEditorScreen_iOS: View {
    let note: Note
    /// 删除后回调（让外层把 pushedNoteID 清 nil，pop 回列表）。
    let onDeleted: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// 编辑器 VM —— `.task` 中由 modelContext + note 实例化。
    @State private var editorVM: NoteEditorViewModel?

    /// 富文本绑定的本地副本（与 editorVM.body 双向同步）。
    @State private var text = AttributedString()

    /// 选区 —— transformAttributes / replaceSelection 都需要它。
    @State private var selection = AttributedTextSelection()

    /// 删除二次确认。
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 富文本工具条
            formatToolbar

            Divider().overlay(Color.lj.border)

            // TextEditor 富文本区
            TextEditor(text: $text, selection: $selection)
                .font(.system(size: 16, weight: .regular))
                .scrollContentBackground(.hidden)
                .background(Color.lj.iosMainBg)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.lj.iosMainBg)
        .navigationTitle(Text(displayTitlePreview))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editorVM?.togglePinned()
                    } label: {
                        Label {
                            Text(note.isPinned ? LJStrings.noteUnpin : LJStrings.notePin)
                        } icon: {
                            Image(systemName: note.isPinned ? "pin.slash" : "pin")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label { Text(LJStrings.noteDelete) } icon: { Image(systemName: "trash") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .modifier(NoteDeleteConfirmModifier_iOS(
            isPresented: $showDeleteConfirm,
            onConfirm: {
                editorVM?.deleteSelf()
                onDeleted()
                dismiss()
            }
        ))
        .task {
            let vm = NoteEditorViewModel(context: modelContext, note: note)
            editorVM = vm
            text = vm.body
        }
        // 用户编辑 → 写回 VM（VM 内部重写 updatedAt）。
        .onChange(of: text) { _, newValue in
            editorVM?.body = newValue
        }
        // 退出编辑器时 save 一次（避免高频 save，见 NoteEditorViewModel 注释）。
        .onDisappear {
            editorVM?.save()
        }
    }

    private var displayTitlePreview: String {
        let plain = String(text.characters)
        for line in plain.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return String(localized: LJStrings.inspirationTitlePlaceholder)
    }

    // MARK: 富文本工具条

    @ViewBuilder
    private var formatToolbar: some View {
        HStack(spacing: 6) {
            toolbarButton(systemName: "bold", label: LJStrings.formatBold) { applyBold() }
            toolbarButton(systemName: "italic", label: LJStrings.formatItalic) { applyItalic() }
            toolbarButton(systemName: "textformat.size.larger", label: LJStrings.formatHeading) { applyHeading() }
            Divider().frame(height: 18).overlay(Color.lj.border)
            toolbarButton(systemName: "list.bullet", label: LJStrings.formatBullet) { insertBullet() }
            toolbarButton(systemName: "checklist", label: LJStrings.formatChecklist) { insertChecklist() }
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
    }

    @ViewBuilder
    private func toolbarButton(
        systemName: String,
        label: LocalizedStringResource,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.lj.inkSoft)
                .frame(width: 36, height: 30)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    // MARK: 格式化动作（原生富文本 API，沿用 U3 验证可用）

    /// 加粗：对选区 font 翻 bold。
    private func applyBold() {
        text.transformAttributes(in: &selection) { container in
            let resolved = container.font ?? .system(size: 16)
            container.font = resolved.bold()
        }
    }

    /// 斜体。
    private func applyItalic() {
        text.transformAttributes(in: &selection) { container in
            let resolved = container.font ?? .system(size: 16)
            container.font = resolved.italic()
        }
    }

    /// 标题：选区字号放大 + semibold。
    private func applyHeading() {
        text.transformAttributes(in: &selection) { container in
            container.font = .system(size: 22, weight: .semibold)
        }
    }

    /// 项目符号：在选区位置插入「• 」前缀（可编辑 TextEditor 用行前缀方案）。
    private func insertBullet() {
        text.replaceSelection(&selection, withCharacters: "• ")
    }

    /// 勾选清单：插入「☐ 」前缀（勾选切换由用户手动改 ☐/☑ 字形，MVP A 方案）。
    private func insertChecklist() {
        text.replaceSelection(&selection, withCharacters: "☐ ")
    }
}

// MARK: - 列表 contextMenu 删除确认对话框 modifier（iOS，v1.3 签收前修复 🟡-4）

/// 列表页 contextMenu 删除用的 item 版确认框（与 macOS `NoteDeleteConfirmModifier` 同结构）。
/// 与下方 `NoteDeleteConfirmModifier_iOS`（Bool 版，编辑器页专用）分离——两处呈现源独立，
/// 互不干扰。抽成独立 modifier 减轻 body 类型检查负担（见 CLAUDE.md）。
private struct NoteListDeleteConfirmModifier: ViewModifier {
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

// MARK: - 删除笔记确认对话框 modifier（iOS）

/// 把 `.confirmationDialog` 抽成独立 modifier —— 直接挂在长 body 链上易触发
/// 「unable to type-check this expression in reasonable time」（见 CLAUDE.md）。
/// confirm message / 按钮文案复用 W4 的 Event.deleteConfirm*（plan U3/U4 指明可复用）。
private struct NoteDeleteConfirmModifier_iOS: ViewModifier {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text(LJStrings.noteDeleteConfirmTitle),
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                onConfirm()
            } label: {
                Text(LJStrings.eventDeleteConfirmConfirm)
            }
            Button(role: .cancel) {
                isPresented = false
            } label: {
                Text(LJStrings.quickAddCancel)
            }
        } message: {
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
        let n1 = Note(body: AttributedString("Renovate the moon\nNeed a bigger ladder"))
        n1.isPinned = true
        let n2 = Note(body: AttributedString("Standup notes\n- ship v1.1"))
        ctx.insert(n1); ctx.insert(n2)
        try? ctx.save()
        return InspirationView_iOS()
            .environment(TabRouter())
            .modelContainer(container)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
#endif
