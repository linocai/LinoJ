// CompanyView_macOS.swift
// Company tab 的 macOS 实现 —— Plan P3.3：
//   - 大标题 "Company" 26pt + 副标 "X todos · Y projects"
//   - Scope chips pill row（All work / Standalone / 每个 project 一个 chip）
//     - 选中 chip 填充 ink、字 panel；未选中 transparent + border
//   - 两列 kanban（Urgent / Normal，按 chip 过滤）
//   - Projects 子区：3 张 full-width ProjectCard(.macFull)
//
// 数据：CompanyViewModel。chip 切换通过 vm.setFilter。
// 点击 ProjectCard 暂时只 print（P3.5 接 Project Detail）。

import SwiftUI
import SwiftData
import LinoJCore

struct CompanyView_macOS: View {

    @Environment(\.modelContext) private var modelContext

    @Query private var todos: [Todo]
    @Query private var projects: [Project]
    @Query private var events: [Event]

    @State private var vm: CompanyViewModel?

    /// NavigationStack 的 path —— 用 `UUID` 作为 destination value，避免给 `@Model Project`
    /// 实现 Hashable（@Model 派生 Identifiable 但不 Hashable）。详见 plan P3.5。
    @State private var navigationPath: [UUID] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let vm {
                    // P6：用 GeometryReader 读 NavigationStack 内容区的宽度，
                    // < 1200pt 时把 compact=true 透给 ProjectCard，触发 2-row 布局。
                    GeometryReader { geo in
                        let projectCardCompact = geo.size.width < 1200
                        content(vm: vm, projectCardCompact: projectCardCompact)
                    }
                } else {
                    Color.lj.bg.ignoresSafeArea()
                }
            }
            .task {
                if vm == nil {
                    vm = CompanyViewModel(context: modelContext)
                }
            }
            .onChange(of: todos.count) { _, _ in vm?.refresh() }
            .onChange(of: todos.map(\.done)) { _, _ in vm?.refresh() }
            .onChange(of: projects.count) { _, _ in vm?.refresh() }
            .onChange(of: events.count) { _, _ in vm?.refresh() }
            .navigationDestination(for: UUID.self) { projectID in
                if let project = projects.first(where: { $0.id == projectID }) {
                    ProjectDetailView_macOS(project: project)
                } else {
                    Text(LJStrings.projectNotFound)
                        .foregroundStyle(Color.lj.inkMute)
                }
            }
        }
    }

    @ViewBuilder
    private func content(vm: CompanyViewModel, projectCardCompact: Bool) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: LJSpacing.s18) {
                header(vm: vm)

                // Scope chips
                scopeChips(vm: vm)

                // Kanban
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

                // Projects 子区
                projectsSection(vm: vm, projectCardCompact: projectCardCompact)
            }
            .padding(.horizontal, LJSpacing.s28)
            .padding(.top, LJSpacing.s22)
            .padding(.bottom, LJSpacing.s32)
        }
        .background(Color.lj.bg)
    }

    // MARK: - Header

    @ViewBuilder
    private func header(vm: CompanyViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LJStrings.tabCompany).ljDisplayTitleStyle()
            HStack(spacing: 0) {
                Text("\(vm.todosCount) ")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.ink)
                Text(LJStrings.todos)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                Text(" · ")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkDim)
                Text("\(vm.projectsCount) ")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.ink)
                Text(LJStrings.projects)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
            }
        }
    }

    // MARK: - Scope chips

    @ViewBuilder
    private func scopeChips(vm: CompanyViewModel) -> some View {
        // 构造 chip 列表：All work / Standalone / 每个 project。
        // 前两个用本地化 label，后续 chip 用 project.title（用户数据，不本地化）。
        HStack(spacing: LJSpacing.s6) {
            chipLocalized(label: LJStrings.filterAllWork, selected: vm.filter == .allWork) {
                vm.setFilter(.allWork)
            }
            chipLocalized(label: LJStrings.filterStandalone, selected: vm.filter == .standalone) {
                vm.setFilter(.standalone)
            }
            ForEach(vm.projects) { project in
                chip(label: project.title, selected: vm.filter == project.filterValue) {
                    vm.setFilter(project.filterValue)
                }
            }
            Spacer()
        }
    }

    /// 接 LocalizedStringResource 的 chip 版本（用于固定标签）。
    @ViewBuilder
    private func chipLocalized(
        label: LocalizedStringResource,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: selected ? .semibold : .medium, design: .default))
                .foregroundStyle(selected ? Color.lj.panel : Color.lj.inkSoft)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background {
                    Capsule(style: .continuous)
                        .fill(selected ? Color.lj.ink : Color.clear)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            selected ? Color.lj.ink : Color.lj.border,
                            lineWidth: 0.5
                        )
                }
        }
        .buttonStyle(.plain)
    }

    /// 接 String 的 chip 版本（用于用户数据如 project.title）。
    @ViewBuilder
    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: selected ? .semibold : .medium, design: .default))
                .foregroundStyle(selected ? Color.lj.panel : Color.lj.inkSoft)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background {
                    Capsule(style: .continuous)
                        .fill(selected ? Color.lj.ink : Color.clear)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            selected ? Color.lj.ink : Color.lj.border,
                            lineWidth: 0.5
                        )
                }
        }
        .buttonStyle(.plain)
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
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Projects section

    @ViewBuilder
    private func projectsSection(vm: CompanyViewModel, projectCardCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: LJSpacing.s12) {
            // 上边线
            Rectangle().fill(Color.lj.border).frame(height: 0.5)
                .padding(.top, LJSpacing.s4)

            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s10) {
                Text(LJStrings.projects)
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .kerning(-0.4)
                    .foregroundStyle(Color.lj.ink)
                Text(LJStrings.allBuckets)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
            }

            VStack(spacing: LJSpacing.s12) {
                ForEach(vm.projects, id: \.id) { project in
                    Button {
                        navigationPath.append(project.id)
                    } label: {
                        // P6：< 1200pt 时切到 2-row 布局；≥ 1200pt 保持原 3-col。
                        ProjectCard(project: project, variant: .macFull, compact: projectCardCompact)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Project filter helper

private extension Project {
    /// 把 Project 转成对应的 `CompanyViewModel.ScopeFilter.project(id)`。
    /// 写在 View 模块的私有 extension，方便 chip 构造段拿语义化值。
    var filterValue: CompanyViewModel.ScopeFilter { .project(self.id) }
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    do {
        let container = try LinoJStore.makeContainer(inMemory: true)
        try SeedData.seedIfEmpty(container.mainContext)
        return CompanyView_macOS()
            .environment(TabRouter())
            .modelContainer(container)
            .frame(width: 1200, height: 800)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
#endif
