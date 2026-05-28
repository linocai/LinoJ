// PersonalView_iOS.swift
// Personal tab 的 iOS 实现 —— Plan P3.3：
//   - 大标题 "Personal" 34pt + 副标 "X open · Y done"
//   - "Urgent" section header（蓝点 + label） + 蓝色 TodoBubble 堆叠
//     - urgent 空时显示 "Nothing urgent. Nice." italic
//   - "Normal" section header + 单张白卡 compact list
//   - 底部 CompletedBox（dashed-border 14pt radius，可折叠）
//   - 底部 padding 100pt 让出 tab bar

import SwiftUI
import SwiftData
import LinoJCore

struct PersonalView_iOS: View {

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
                Color.lj.iosMainBg.ignoresSafeArea()
            }
        }
        .task {
            if vm == nil {
                let model = PersonalViewModel(context: modelContext)
                model.includeCompletedInCounts = settings.showCompletedInCounts
                vm = model
            }
        }
        // W2：Settings 改 showCompletedInCounts → 注入 + refresh（计数即时切换）。
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
        ZStack {
            Color.lj.iosMainBg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero header（让出 FloatingActions）
                    header(vm: vm)
                        .padding(.top, 64)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)

                    // Urgent section
                    urgentSection(vm: vm)
                        .padding(.horizontal, 16)

                    // Normal section
                    normalSection(vm: vm)
                        .padding(.horizontal, 16)
                        .padding(.top, 22)

                    // Completed box
                    CompletedBox(count: vm.completed.count) {
                        if vm.completed.isEmpty {
                            Text(LJStrings.completedUntilCrossOff)
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .italic()
                                .foregroundStyle(Color.lj.inkDim)
                                .padding(.vertical, LJSpacing.s8)
                        } else {
                            ForEach(vm.completed, id: \.id) { todo in
                                completedRow(todo: todo, onToggle: { vm.toggleDone(todo) })
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                    // 让出 tab bar
                    Color.clear.frame(height: 110)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(vm: PersonalViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LJStrings.tabPersonal).ljDisplayTitleStyle()
            HStack(spacing: 0) {
                Text("\(vm.openCount) ")
                    .font(.system(size: 13.5, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.ink)
                Text(LJStrings.statOpen)
                    .font(.system(size: 13.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                Text(" · ")
                    .font(.system(size: 13.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkDim)
                Text("\(vm.doneCount) ")
                    .font(.system(size: 13.5, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.ink)
                Text(LJStrings.statDone)
                    .font(.system(size: 13.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
            }
        }
    }

    // MARK: - Urgent

    @ViewBuilder
    private func urgentSection(vm: PersonalViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: LJStrings.urgent, count: vm.urgent.count, withBlueDot: true)
            if vm.urgent.isEmpty {
                Text(LJStrings.nothingUrgentNice)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .italic()
                    .foregroundStyle(Color.lj.inkDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, LJSpacing.s14)
            } else {
                ForEach(vm.urgent, id: \.id) { todo in
                    TodoBubble(todo: todo, onToggleDone: { vm.toggleDone(todo) })
                        .id(todo.id) // W3：ScrollViewReader 锚点（Search 定位用）。
                }
            }
        }
    }

    // MARK: - Normal compact list

    @ViewBuilder
    private func normalSection(vm: PersonalViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: LJStrings.normal, count: vm.normal.count, withBlueDot: false)
            VStack(spacing: 0) {
                ForEach(Array(vm.normal.enumerated()), id: \.element.id) { index, todo in
                    if index > 0 {
                        Rectangle().fill(Color.lj.border).frame(height: 0.5)
                    }
                    compactNormalRow(todo: todo, onToggle: { vm.toggleDone(todo) })
                        .id(todo.id) // W3：ScrollViewReader 锚点（Search 定位用）。
                }
                if vm.normal.isEmpty {
                    Text(LJStrings.nothingInNormal)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .italic()
                        .foregroundStyle(Color.lj.inkDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LJSpacing.s14)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.lj.panel)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
        }
    }

    @ViewBuilder
    private func compactNormalRow(todo: Todo, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.lj.inkMute, lineWidth: 1.4)
                        .frame(width: 16, height: 16)
                    if todo.done {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.lj.ink)
                            .frame(width: 10, height: 10)
                    }
                }
                Text(todo.title)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .strikethrough(todo.done, color: Color.lj.inkMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .opacity(todo.done ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completed row

    @ViewBuilder
    private func completedRow(todo: Todo, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: LJSpacing.s10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.lj.inkMute, lineWidth: 1.4)
                        .frame(width: 14, height: 14)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.lj.ink)
                        .frame(width: 9, height: 9)
                }
                .padding(.top, 2)
                Text(todo.title)
                    .font(.system(size: 13, weight: .medium, design: .default))
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section header

    @ViewBuilder
    private func sectionHeader(label: LocalizedStringResource, count: Int, withBlueDot: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if withBlueDot {
                Circle()
                    .fill(Color.lj.blue)
                    .frame(width: 7, height: 7)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 3.5 }
            }
            Text(label)
                .font(.system(size: 17, weight: .bold, design: .default))
                .kerning(-0.34)
                .foregroundStyle(withBlueDot ? Color.lj.blueInk : Color.lj.ink)
            Text("\(count)")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkMute)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    do {
        let container = try LinoJStore.makeContainer(inMemory: true)
        try SeedData.seedIfEmpty(container.mainContext)
        return PersonalView_iOS()
            .environment(TabRouter())
            .modelContainer(container)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
#endif
