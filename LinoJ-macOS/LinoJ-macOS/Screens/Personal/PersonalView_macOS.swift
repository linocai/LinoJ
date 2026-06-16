// PersonalView_macOS.swift
// Personal tab 的 macOS 实现 —— Plan P3.3：
//   - 大标题 "Personal" 26pt + 副标 "X open · Y done"
//   - 两列 kanban（Urgent / Normal），仅 scope == .personal
//   - 底部 CompletedBox（dashed-border，可折叠 chevron 旋转 90°）
//   - 空状态：urgent 列空时在 dashed-border 灰列内显示 EmptyState(.urgentEmpty)
//
// 数据：PersonalViewModel。Refresh 模式与 MainView 一致 —— `@Query` 触发 invalidation，
// `.onChange` 调 vm.refresh()。

import SwiftUI
import SwiftData
import LinoJCore

struct PersonalView_macOS: View {

    @Environment(\.modelContext) private var modelContext
    /// W3：Search 选中 personal todo → scrollTo 到该 bubble，需监听 router.pendingTodoID。
    @Environment(TabRouter.self) private var router

    @Query private var todos: [Todo]

    @State private var vm: PersonalViewModel?

    /// W2：本屏自有 SettingsViewModel，用于读 `showCompletedInCounts` 注入到 PersonalViewModel
    /// （影响 "X open" 计数）。
    @State private var settings = SettingsViewModel()

    var body: some View {
        Group {
            if let vm {
                // W3：ScrollViewReader 让 pendingTodoID 能 scrollTo 到具体 bubble。
                ScrollViewReader { proxy in
                    content(vm: vm)
                        .onChange(of: router.pendingTodoID) { _, newValue in
                            consumePendingTodo(newValue, proxy: proxy)
                        }
                        .onAppear {
                            consumePendingTodo(router.pendingTodoID, proxy: proxy)
                        }
                }
            } else {
                Color.lj.bg.ignoresSafeArea()
            }
        }
        .task {
            if vm == nil {
                let model = PersonalViewModel(context: modelContext)
                model.includeCompletedInCounts = settings.showCompletedInCounts
                vm = model
            }
        }
        // W2：Settings 改 showCompletedInCounts → 注入新值 + refresh（计数即时切换）。
        .onChange(of: settings.showCompletedInCounts) { _, newValue in
            vm?.includeCompletedInCounts = newValue
            vm?.refresh()
        }
        .onChange(of: todos.count) { _, _ in vm?.refresh() }
        .onChange(of: todos.map(\.done)) { _, _ in vm?.refresh() }
        .onChange(of: todos.map(\.urgencyRaw)) { _, _ in vm?.refresh() }
    }

    /// W3：消费 router.pendingTodoID —— 若目标 todo 属 personal scope，滚动到该 bubble 后清回 nil。
    /// Personal 屏无 chip filter，无需重置 filter。
    private func consumePendingTodo(_ id: UUID?, proxy: ScrollViewProxy) {
        guard let id else { return }
        guard let todo = todos.first(where: { $0.id == id }), todo.scope == .personal else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .center)
            }
            router.pendingTodoID = nil
        }
    }

    @ViewBuilder
    private func content(vm: PersonalViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: LJSpacing.s22) {
                header(vm: vm)

                // 两列 kanban
                HStack(alignment: .top, spacing: LJSpacing.s18) {
                    bubbleColumn(
                        label: LJStrings.urgent,
                        isUrgent: true,
                        items: vm.urgent,
                        onToggle: { vm.toggleDone($0) }
                    )
                    bubbleColumn(
                        label: LJStrings.normal,
                        isUrgent: false,
                        items: vm.normal,
                        onToggle: { vm.toggleDone($0) }
                    )
                }
                .frame(maxWidth: 1100, alignment: .leading)

                // 底部 CompletedBox（v1.2 P5：近 30 天 recent 默认展开 + 更早 archive 二级折叠）
                CompletedBox(
                    count: vm.completed.count,
                    archiveCount: vm.completedArchive.count,
                    content: {
                        if vm.completed.isEmpty {
                            Text(LJStrings.nothingFinishedYet)
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .italic()
                                .foregroundStyle(Color.lj.inkDim)
                                .padding(.vertical, LJSpacing.s8)
                        } else {
                            ForEach(vm.completedRecent, id: \.id) { todo in
                                completedRow(todo: todo, onToggle: { vm.toggleDone(todo) })
                            }
                        }
                    },
                    archiveContent: {
                        ForEach(vm.completedArchive, id: \.id) { todo in
                            completedRow(todo: todo, onToggle: { vm.toggleDone(todo) })
                        }
                    }
                )
                .frame(maxWidth: 1100, alignment: .leading)
            }
            .padding(.horizontal, LJSpacing.s28)
            .padding(.top, LJSpacing.s22)
            .padding(.bottom, LJSpacing.s28)
        }
        .background(Color.lj.bg)
    }

    // MARK: - Header

    @ViewBuilder
    private func header(vm: PersonalViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LJStrings.tabPersonal).ljDisplayTitleStyle()
            HStack(spacing: 0) {
                Text("\(vm.openCount) ")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.ink)
                Text(LJStrings.statOpen)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                Text(" · ")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkDim)
                Text("\(vm.doneCount) ")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.ink)
                Text(LJStrings.statDone)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
            }
        }
    }

    // MARK: - Bubble column

    @ViewBuilder
    private func bubbleColumn(
        label: LocalizedStringResource,
        isUrgent: Bool,
        items: [Todo],
        onToggle: @escaping (Todo) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: LJSpacing.s10) {
            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s10) {
                if isUrgent {
                    Circle()
                        .fill(Color.lj.blue)
                        .frame(width: 8, height: 8)
                        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 4 }
                }
                Text(label)
                    .font(.lj.sectionHeader)
                    .foregroundStyle(isUrgent ? Color.lj.blueInk : Color.lj.ink)
                    .kerning(-0.25)
                Text("\(items.count)")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
            }

            if items.isEmpty && isUrgent {
                // 空 urgent 列：dashed-border 灰列内显示 EmptyState
                EmptyState(variant: .urgentEmpty)
                    .ljDashedBorder()
            } else if items.isEmpty {
                Text(LJStrings.nothingHere)
                    .font(.system(size: 12.5, weight: .medium, design: .default))
                    .italic()
                    .foregroundStyle(Color.lj.inkDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LJSpacing.s16)
            } else {
                VStack(spacing: LJSpacing.s8) {
                    ForEach(items, id: \.id) { todo in
                        TodoBubble(todo: todo, onToggleDone: { onToggle(todo) })
                            .id(todo.id) // W3：ScrollViewReader 锚点（Search 定位用）。
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Completed row

    @ViewBuilder
    private func completedRow(todo: Todo, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: LJSpacing.s10) {
                // 已完成 checkbox（实心方框）
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.lj.inkMute, lineWidth: 1.2)
                        .frame(width: 13, height: 13)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.lj.ink)
                        .frame(width: 8, height: 8)
                }
                .padding(.top, 2)

                Text(todo.title)
                    .font(.system(size: 12.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkMute)
                    .strikethrough(true, color: Color.lj.inkDim)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(LJStrings.doneSuffix)
                    .font(.system(size: 10.5, weight: .medium, design: .default))
                    .italic()
                    .foregroundStyle(Color.lj.inkDim)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // P6：macOS list row hover 背景。
        .ljHoverBackground()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    do {
        let container = try LinoJStore.makeContainer(inMemory: true)
        try SeedData.seedIfEmpty(container.mainContext)
        return PersonalView_macOS()
            .environment(TabRouter())
            .modelContainer(container)
            .frame(width: 1200, height: 720)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
#endif
