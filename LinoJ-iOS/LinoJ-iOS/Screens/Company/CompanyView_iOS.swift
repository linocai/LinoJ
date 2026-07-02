// CompanyView_iOS.swift
// Company tab 的 iOS 实现 —— Plan P3.3：
//   - 大标题 "Company" 34pt + 副标 "X todos · Y projects"
//   - 横向 scroll scope chips（All work / Standalone / 每个 project）
//   - Urgent + Normal 两个 section（同 Personal 模式）
//   - Projects section：每个 project 一张 stacked ProjectCard(.iosFull)
//   - 点击 ProjectCard 暂时只 print（P3.5 接 Project Detail）
//   - 底部 padding 110pt 让出 tab bar

import SwiftUI
import SwiftData
import LinoJCore

struct CompanyView_iOS: View {

    @Environment(\.modelContext) private var modelContext
    /// W3：Search 精确定位需要监听 router.pendingProjectID / pendingTodoID。
    @Environment(TabRouter.self) private var router

    @Query private var todos: [Todo]
    @Query private var projects: [Project]
    @Query private var events: [Event]

    @State private var vm: CompanyViewModel?

    /// W2：本屏自有 SettingsViewModel，用于读 `showCompletedInCounts` 注入到 CompanyViewModel
    /// （影响 "X todos" 计数）。
    @State private var settings = SettingsViewModel()

    /// NavigationStack 的 path —— 用 `UUID` 作为 destination value，避免给 `@Model Project`
    /// 实现 Hashable。详见 plan P3.5。
    @State private var navigationPath: [UUID] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let vm {
                    // W3：ScrollViewReader 让 pendingTodoID 能 scrollTo 到具体 bubble。
                    ScrollViewReader { proxy in
                        content(vm: vm)
                            .onChange(of: router.pendingTodoID) { _, newValue in
                                consumePendingTodo(newValue, vm: vm, proxy: proxy)
                            }
                            .onAppear {
                                consumePendingTodo(router.pendingTodoID, vm: vm, proxy: proxy)
                            }
                    }
                } else {
                    Color.clear.ljScreenBackground(.iOS)
                }
            }
            .task {
                if vm == nil {
                    let model = CompanyViewModel(context: modelContext)
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
            .onChange(of: projects.count) { _, _ in vm?.refresh() }
            .onChange(of: events.count) { _, _ in vm?.refresh() }
            // W3：Search 选中 project → push 到该 ProjectDetail（append path）后清回 nil。
            .onChange(of: router.pendingProjectID) { _, newValue in
                consumePendingProject(newValue)
            }
            .onAppear {
                consumePendingProject(router.pendingProjectID)
            }
            .navigationDestination(for: UUID.self) { projectID in
                if let project = projects.first(where: { $0.id == projectID }) {
                    ProjectDetailView_iOS(project: project)
                } else {
                    Text(LJStrings.projectNotFound)
                        .foregroundStyle(Color.lj.inkMute)
                }
            }
        }
    }

    // MARK: - W3 pending consumption

    /// W3：消费 router.pendingProjectID —— 把目标 project push 进 NavigationStack 后清回 nil。
    private func consumePendingProject(_ id: UUID?) {
        guard let id, projects.contains(where: { $0.id == id }) else { return }
        if navigationPath.last != id {
            navigationPath.append(id)
        }
        router.pendingProjectID = nil
    }

    /// W3：消费 router.pendingTodoID —— 若目标 todo 属 company scope，先把 filter 重置为 All
    /// （避免被某个 project chip 隐藏），再滚动到该 bubble，最后清回 nil。
    private func consumePendingTodo(_ id: UUID?, vm: CompanyViewModel, proxy: ScrollViewProxy) {
        guard let id else { return }
        guard let todo = todos.first(where: { $0.id == id }), todo.scope == .company else { return }
        if vm.filter != .allWork {
            vm.setFilter(.allWork)
        }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .center)
            }
            router.pendingTodoID = nil
        }
    }

    @ViewBuilder
    private func content(vm: CompanyViewModel) -> some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header(vm: vm)
                        .padding(.top, 64)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // 横向 scope chips
                    scopeChips(vm: vm)
                        .padding(.bottom, 18)

                    // Urgent
                    urgentSection(vm: vm)
                        .padding(.horizontal, 16)

                    // Normal
                    normalSection(vm: vm)
                        .padding(.horizontal, 16)
                        .padding(.top, 22)

                    // Projects
                    projectsSection(vm: vm)
                        .padding(.top, 26)

                    // U8：原生 tab bar 已由系统安全区让位，仅保留小段视觉呼吸。
                    Color.clear.frame(height: 24)
                }
            }
        }
        // v1.3 R7：iOS 底色渐变 + bloom orb。
        .ljScreenBackground(.iOS)
    }

    // MARK: - Header

    /// v1.3 R7（对原型重建）：H1 标题 + 三段计数（N 待办 · N 紧急 · N 项目）+ ＋新建公司事项主按钮。
    @ViewBuilder
    private func header(vm: CompanyViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LJStrings.tabCompany).ljDisplayTitleStyle()
                countsLine(todos: vm.todosCount, urgent: vm.urgentTotal, projects: vm.projectsCount)
            }
            LJPrimaryButton(LJStrings.newCompanyItem) {
                router.quickAddDefaultKind = .todo
                router.quickAddDefaultScope = .company
                router.showQuickAdd = true
            }
        }
    }

    /// 「N 待办 · N 紧急 · N 项目」计数行（紧急数字紫蓝；urgent 用 urgentTotal 不被 chip filter 影响）。
    @ViewBuilder
    private func countsLine(todos: Int, urgent: Int, projects: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(todos) ")
                .font(.system(size: 13.5, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.ink)
            Text(LJStrings.todos)
                .font(.system(size: 13.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
            Text(" · ")
                .font(.system(size: 13.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkDim)
            Text("\(urgent) ")
                .font(.system(size: 13.5, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.blue)
            Text(LJStrings.statUrgent)
                .font(.system(size: 13.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
            Text(" · ")
                .font(.system(size: 13.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkDim)
            Text("\(projects) ")
                .font(.system(size: 13.5, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.ink)
            Text(LJStrings.projects)
                .font(.system(size: 13.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
        }
    }

    // MARK: - Scope chips

    @ViewBuilder
    private func scopeChips(vm: CompanyViewModel) -> some View {
        // 横向 scroll，左右各 16pt margin。
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
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
            }
            .padding(.horizontal, 16)
        }
    }

    /// 接 LocalizedStringResource 的 chip。
    @ViewBuilder
    private func chipLocalized(
        label: LocalizedStringResource,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            chipLabel(Text(label), selected: selected)
        }
        .buttonStyle(.plain)
    }

    /// 接 String 的 chip（用于用户数据 project.title）。
    @ViewBuilder
    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            chipLabel(Text(label), selected: selected)
        }
        .buttonStyle(.plain)
    }

    /// chip 造型：选中 ink 黑底白字 / 未选半透玻璃 + hairline + 顶高光（原型 c.bg/fg/bd）。
    @ViewBuilder
    private func chipLabel(_ text: Text, selected: Bool) -> some View {
        text
            .font(.system(size: 13, weight: selected ? .semibold : .medium, design: .default))
            .foregroundStyle(selected ? Color.lj.panel : Color.lj.inkSoft)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background {
                if selected {
                    Capsule(style: .continuous).fill(Color.lj.ink)
                } else {
                    Capsule(style: .continuous).fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(selected ? Color.clear : Color.lj.border, lineWidth: 0.5)
            }
            .overlay {
                if !selected {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.6), Color.white.opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                        .mask(
                            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .center)
                        )
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - Urgent

    @ViewBuilder
    private func urgentSection(vm: CompanyViewModel) -> some View {
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
    private func normalSection(vm: CompanyViewModel) -> some View {
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
            // v1.3 R7：整组玻璃卡（.regularMaterial + hairline + 顶高光 + 柔投影）。
            .ljGlassPanel(radius: 16, padded: false)
        }
    }

    @ViewBuilder
    private func compactNormalRow(todo: Todo, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.lj.inkMute, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if todo.done {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LJGradients.brand)
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(todo.title)
                    .font(.system(size: 14.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .strikethrough(todo.done, color: Color.lj.inkMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // 项目名小胶囊（原型 company normal 行右侧灰底）。
                if let project = todo.project {
                    Text(project.title.split(separator: " ").first.map(String.init) ?? project.title)
                        .font(.system(size: 10.5, weight: .semibold, design: .default))
                        .foregroundStyle(Color.lj.inkSoft)
                        .padding(.horizontal, LJSpacing.s8)
                        .padding(.vertical, 3)
                        .background {
                            RoundedRectangle(cornerRadius: LJRadii.sourceLabel, style: .continuous)
                                .fill(Color.lj.chip)
                        }
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .opacity(todo.done ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Projects section

    @ViewBuilder
    private func projectsSection(vm: CompanyViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // v1.3 R7：项目区标题行 = 「项目」H2 + 右侧「＋新建项目」次级按钮（新功能件）。
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LJStrings.projects)
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .kerning(-0.34)
                    .foregroundStyle(Color.lj.ink)
                Spacer()
                LJSecondaryButton(LJStrings.newProject) {
                    router.quickAddDefaultKind = .project
                    router.showQuickAdd = true
                }
            }
            .padding(.horizontal, 16)

            VStack(spacing: 12) {
                ForEach(vm.projects, id: \.id) { project in
                    Button {
                        navigationPath.append(project.id)
                    } label: {
                        ProjectCard(project: project, variant: .iosFull)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Section header

    @ViewBuilder
    private func sectionHeader(label: LocalizedStringResource, count: Int, withBlueDot: Bool) -> some View {
        // v1.3 R7：urgent 段标小圆点 = 品牌渐变；normal = 灰点。标题统一 ink。
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Circle()
                .fill(withBlueDot ? AnyShapeStyle(LJGradients.brand) : AnyShapeStyle(Color.lj.inkMute))
                .frame(width: 9, height: 9)
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 4 }
            Text(label)
                .font(.system(size: 17, weight: .bold, design: .default))
                .kerning(-0.34)
                .foregroundStyle(Color.lj.ink)
            Text("\(count)")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkMute)
            Spacer()
        }
        .padding(.horizontal, 4)
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
        return CompanyView_iOS()
            .environment(TabRouter())
            .modelContainer(container)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
#endif
