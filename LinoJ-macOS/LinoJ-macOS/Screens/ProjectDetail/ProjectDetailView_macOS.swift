// ProjectDetailView_macOS.swift
// Project detail 视图 macOS 实现 —— Plan P3.5：
//   - Breadcrumb（← Company / 项目名）+ 右上 `⋯`
//   - Hero（标题 30pt + tag pill + intro maxWidth=720 + "Edit project" outline button）
//   - Meta row（avatars + divider + open/urgent/done stats + divider + linked events / created stats）
//   - 两列 body（1.3fr 1fr，spacing 0，中间靠 right border 隔开）：
//     - 左：Urgent + Normal bubbles + CompletedBox（filter 到本 project）
//     - 右：Linked events 按 day 分组（小 uppercase header + 事件 row：time + title + where + avatars）
//           + Notes section（white-space pre-line，即保留换行）
//
// 数据：ProjectDetailViewModel。
// 入口：CompanyView_macOS 用 NavigationStack push 到本 View，传入 project.id（UUID），
//   本 View 在 init 内反查 project 实例并构造 vm —— 这样 navigationDestination(for: UUID.self)
//   不需要 Project 实现 Hashable。
// ⋯ 与 "Edit project" 按钮暂时只 print（P3.5 范围外）。

import SwiftUI
import SwiftData
import LinoJCore

struct ProjectDetailView_macOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// V5：打开 Quick Add 的 Project edit 模式需要 router。
    @Environment(TabRouter.self) private var router

    /// 调用方传入 project 引用（来自 Company 视图的 @Query）。
    let project: Project

    @Query private var todos: [Todo]
    @Query private var events: [Event]

    @State private var vm: ProjectDetailViewModel?

    /// W2：本屏自有 SettingsViewModel，用于读 `showCompletedInCounts` 注入到 ProjectDetailViewModel
    /// （影响 meta row / 左列 header 的 open 计数）。
    @State private var settings = SettingsViewModel()

    /// W3：⋯ 菜单「Delete project」的确认对话框开关。
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                Color.lj.bg.ignoresSafeArea()
            }
        }
        .task {
            if vm == nil {
                let model = ProjectDetailViewModel(project: project, context: modelContext)
                model.includeCompletedInCounts = settings.showCompletedInCounts
                vm = model
            }
        }
        // W2：Settings 改 showCompletedInCounts → 注入 + refresh（计数即时切换）。
        .onChange(of: settings.showCompletedInCounts) { _, newValue in
            vm?.includeCompletedInCounts = newValue
            vm?.refresh()
        }
        // 任何 todo / event 写入都让 vm 重算（done flag / project 重指 / 新增等）。
        .onChange(of: todos.count) { _, _ in vm?.refresh() }
        .onChange(of: todos.map(\.done)) { _, _ in vm?.refresh() }
        .onChange(of: events.count) { _, _ in vm?.refresh() }
        // 隐藏系统返回 chevron（我们自己画 breadcrumb 返回按钮）。
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: ProjectDetailViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                breadcrumb
                hero(vm: vm)
                bodyGrid(vm: vm)
            }
        }
        .background(Color.lj.bg)
    }

    // MARK: - Breadcrumb

    @ViewBuilder
    private var breadcrumb: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text(LJStrings.tabCompany)
                        .font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(Color.lj.inkSoft)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("/")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.lj.inkDim)
            Text(project.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.lj.ink)
            Spacer()
            // W3：空 Button → Menu（Edit project 复用 V5 路径 + Delete project 弹确认）。
            Menu {
                Button {
                    router.quickAddEditingProject = project
                    router.showQuickAdd = true
                } label: {
                    Label(String(localized: LJStrings.editProject), systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(String(localized: LJStrings.projectDetailDelete), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.lj.inkSoft)
                    .frame(width: 26, height: 26)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.lj.border, lineWidth: 0.5)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(Text(LJStrings.projectMore))
            // W3：Delete 确认对话框 —— 确认后删除 project 并 pop 回 Company。
            .confirmationDialog(
                Text(LJStrings.projectDetailDeleteConfirmTitle),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    vm?.deleteProject()
                    dismiss()
                } label: {
                    Text(LJStrings.projectDetailDeleteConfirmConfirm)
                }
                Button(role: .cancel) {} label: {
                    Text(LJStrings.quickAddCancel)
                }
            } message: {
                Text(LJStrings.projectDetailDeleteConfirmMessage)
            }
        }
        .padding(.top, LJSpacing.s14)
        .padding(.horizontal, LJSpacing.s28)
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(vm: ProjectDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题 + tag + Edit button
            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s14) {
                Text(project.title)
                    .font(.system(size: 30, weight: .semibold, design: .default))
                    .kerning(-0.75)
                    .foregroundStyle(Color.lj.ink)
                Text(project.tag).ljTagPill()
                Spacer()
                Button {
                    // V5：打开 Quick Add 的 Project edit 模式（预填本 project 字段）。
                    router.quickAddEditingProject = project
                    router.showQuickAdd = true
                } label: {
                    Text(LJStrings.editProject)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.lj.inkSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.lj.borderStrong, lineWidth: 0.5)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            // intro
            Text(project.intro)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.lj.inkSoft)
                .lineSpacing(3)
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.bottom, LJSpacing.s16)

            // Meta row
            metaRow(vm: vm)
        }
        .padding(.top, LJSpacing.s12)
        .padding(.horizontal, LJSpacing.s28)
        .padding(.bottom, LJSpacing.s22)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.lj.border)
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func metaRow(vm: ProjectDetailViewModel) -> some View {
        HStack(spacing: LJSpacing.s22) {
            // Members
            HStack(spacing: 10) {
                AvatarStack(people: project.members ?? [])
                // F2：用 project.memberCount（冗余 Int）替代 project.members.count，
                // 避免 SwiftData to-many fault 偶发返回 0。
                let memberCount = project.memberCount
                Text(
                    String(
                        localized: memberCount == 1 ? "Counts.member.one" : "Counts.members",
                        defaultValue: memberCount == 1
                            ? "1 member"
                            : "\(memberCount) members",
                        bundle: LinoJCoreBundle.bundle
                    )
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
            }
            metaDivider
            metaStat(value: "\(vm.openCount)", label: LJStrings.statOpenTodos)
            if vm.urgentCount > 0 {
                metaStat(value: "\(vm.urgentCount)", label: LJStrings.urgent, colorOverride: Color.lj.blue)
            }
            metaStat(value: "\(vm.doneCount)", label: LJStrings.statDone, colorOverride: Color.lj.inkSoft)
            metaDivider
            metaStat(value: "\(vm.linkedEventsCount)", label: LJStrings.statLinkedEvents)
            metaDivider
            metaStat(
                value: Self.createdFormatter.string(from: project.createdAt),
                label: LJStrings.statCreated,
                colorOverride: Color.lj.inkSoft,
                small: true
            )
            Spacer(minLength: 0)
        }
    }

    private var metaDivider: some View {
        Rectangle()
            .fill(Color.lj.borderStrong)
            .frame(width: 0.5, height: 14)
    }

    @ViewBuilder
    private func metaStat(
        value: String,
        label: LocalizedStringResource,
        colorOverride: Color? = nil,
        small: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: small ? 12 : 16, weight: .bold, design: .monospaced))
                .kerning(-0.32)
                .monospacedDigit()
                .foregroundStyle(colorOverride ?? Color.lj.ink)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.lj.inkMute)
        }
    }

    // MARK: - Body grid

    @ViewBuilder
    private func bodyGrid(vm: ProjectDetailViewModel) -> some View {
        // SwiftUI 没有原生「列权重 1.3 : 1」的 grid；用 GeometryReader + 比例宽度。
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let leftWidth = totalWidth * (1.3 / 2.3)
            HStack(alignment: .top, spacing: 0) {
                leftColumn(vm: vm)
                    .frame(width: leftWidth, alignment: .topLeading)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(Color.lj.border).frame(width: 0.5)
                    }
                rightColumn(vm: vm)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        // GeometryReader 默认不传递 ideal height —— 这里给一个 minHeight 让 ScrollView 测量稳定。
        .frame(minHeight: 600)
    }

    // MARK: - Left column (todos)

    @ViewBuilder
    private func leftColumn(vm: ProjectDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LJStrings.todos)
                    .font(.system(size: 16, weight: .semibold))
                    .kerning(-0.24)
                    .foregroundStyle(Color.lj.ink)
                Text(
                    String(
                        localized: "Counts.openDone",
                        defaultValue: "\(vm.openCount) open · \(vm.doneCount) done",
                        bundle: LinoJCoreBundle.bundle
                    )
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
                Button {
                    // 0.9.1：add todo 尚未接通（占位）。去掉 print，beta 可接受点击静默无反应。
                } label: {
                    Text(LJStrings.addTodo)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.lj.inkSoft)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, LJSpacing.s14)

            VStack(alignment: .leading, spacing: LJSpacing.s18) {
                if !vm.urgent.isEmpty {
                    bubbleColumn(
                        label: LJStrings.urgent,
                        isUrgent: true,
                        items: vm.urgent,
                        onToggle: { vm.toggleDone($0) }
                    )
                }
                bubbleColumn(
                    label: LJStrings.normal,
                    isUrgent: false,
                    items: vm.normal,
                    onToggle: { vm.toggleDone($0) }
                )
                if !vm.completed.isEmpty {
                    CompletedBox(count: vm.completed.count) {
                        ForEach(vm.completed, id: \.id) { todo in
                            HStack(spacing: 8) {
                                Text(todo.title)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .strikethrough(true, color: Color.lj.inkMute)
                                    .foregroundStyle(Color.lj.inkMute)
                                Text(LJStrings.doneSuffix)
                                    .font(.system(size: 11, weight: .medium))
                                    .italic()
                                    .foregroundStyle(Color.lj.inkDim)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { vm.toggleDone(todo) }
                        }
                    }
                }
            }
        }
        .padding(.vertical, LJSpacing.s22)
        .padding(.horizontal, LJSpacing.s28)
    }

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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
            }

            if items.isEmpty && isUrgent {
                EmptyState(variant: .urgentEmpty)
                    .ljDashedBorder()
            } else if items.isEmpty {
                Text(LJStrings.nothingInNormal)
                    .font(.system(size: 12.5, weight: .medium))
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
    }

    // MARK: - Right column (events + notes)

    @ViewBuilder
    private func rightColumn(vm: ProjectDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: LJSpacing.s22) {
            // Linked events
            VStack(alignment: .leading, spacing: LJSpacing.s14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(LJStrings.linkedEvents)
                        .font(.system(size: 16, weight: .semibold))
                        .kerning(-0.24)
                        .foregroundStyle(Color.lj.ink)
                    Text("\(vm.linkedEventsCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.lj.inkMute)
                    Spacer()
                    Button {
                        // 0.9.1：add event 尚未接通（占位）。去掉 print，beta 可接受点击静默无反应。
                    } label: {
                        Text(LJStrings.addTodo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.lj.inkSoft)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                let sortedDays = vm.linkedEventsByDay.keys.sorted()
                // 用 LinoJTime.today()：DEBUG 下取 2026-05-27，让 seed 项目内的 today 事件
                // 能被识别并显示为 "Today" 标签。
                let todayStart = Calendar.current.startOfDay(for: LinoJTime.today())

                VStack(alignment: .leading, spacing: LJSpacing.s16) {
                    ForEach(sortedDays, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            let isToday = Calendar.current.isDate(day, inSameDayAs: todayStart)
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(isToday
                                     ? String(localized: LJStrings.todayUpper)
                                     : Self.dayHeaderFormatter.string(from: day))
                                    .font(.system(size: 11, weight: .bold))
                                    .kerning(0.88)
                                    .textCase(.uppercase)
                                    .foregroundStyle(isToday ? Color.lj.ink : Color.lj.inkMute)
                                if isToday {
                                    Circle()
                                        .fill(Color.lj.ink)
                                        .frame(width: 5, height: 5)
                                        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 2.5 }
                                }
                            }
                            VStack(spacing: 6) {
                                ForEach(vm.linkedEventsByDay[day] ?? [], id: \.id) { event in
                                    eventRow(event)
                                }
                            }
                        }
                    }
                }
            }

            // Notes
            if !project.notes.isEmpty {
                Rectangle().fill(Color.lj.border).frame(height: 0.5)
                VStack(alignment: .leading, spacing: 10) {
                    Text(LJStrings.notes)
                        .font(.system(size: 14, weight: .semibold))
                        .kerning(-0.14)
                        .foregroundStyle(Color.lj.ink)
                    Text(project.notes)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.lj.inkSoft)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, LJSpacing.s22)
        .padding(.horizontal, LJSpacing.s28)
    }

    @ViewBuilder
    private func eventRow(_ event: Event) -> some View {
        HStack(alignment: .center, spacing: LJSpacing.s12) {
            Text(Self.timeFormatter.string(from: event.start))
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .kerning(-0.12)
                .monospacedDigit()
                .foregroundStyle(Color.lj.ink)
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                    .lineLimit(1)
                Text(event.location)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AvatarStack(people: event.attendees ?? [], max: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.lj.panel)
        }
        .overlay(alignment: .leading) {
            // 左侧 2pt 黑色 accent —— 设计稿一致
            Rectangle()
                .fill(Color.lj.ink)
                .frame(width: 2)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 6, bottomLeadingRadius: 6,
                        bottomTrailingRadius: 0, topTrailingRadius: 0,
                        style: .continuous
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.lj.border, lineWidth: 0.5)
        }
    }

    // MARK: - Formatters

    /// "Apr 12" 这种短月名 + 日数。
    private static let createdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMM d")
        return f
    }()

    /// 事件 day header："TUE, MAY 27" 这种格式（设计稿 g.day.label + ", May " + g.day.date）。
    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return f
    }()

    /// 事件起始时刻："09:30"。
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
}

// MARK: - Preview

#if DEBUG
#Preview("Light") {
    do {
        let container = try LinoJStore.makeContainer(inMemory: true)
        try SeedData.seedIfEmpty(container.mainContext)
        let projects = try container.mainContext.fetch(FetchDescriptor<Project>())
        let linoj = projects.first(where: { $0.title == "LinoJ for macOS v1" })!
        return NavigationStack {
            ProjectDetailView_macOS(project: linoj)
        }
        .modelContainer(container)
        .frame(width: 1200, height: 800)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
#endif
