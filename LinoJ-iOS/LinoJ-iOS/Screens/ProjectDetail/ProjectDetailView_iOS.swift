// ProjectDetailView_iOS.swift
// Project detail 视图 iOS 实现 —— Plan P3.5：
//   - 顶部两枚 floating glass 按钮：左 `← Company`（含 chevron）触发 pop 回 Company；
//     右 `⋯`（暂时只 print）。用 `.glassEffect(in: Capsule())` 包 HStack。
//   - Hero：tag pill → 标题 30pt → intro → AvatarStack + "X members · since Apr 12"
//   - Stats 卡片：白卡 4-column (open / urgent / done / events)，cell 之间 thin divider，
//     数字 mono 20pt。
//   - Sections（在白卡之外）：
//       Urgent bubbles → Normal compact list → Linked events 按 day 分组（白卡 + rows）
//       → Notes 白卡 → CompletedBox
//   - 底部 110pt padding 让出 tab bar。
//
// 数据：ProjectDetailViewModel。
// 入口：CompanyView_iOS 用 NavigationStack push 到本 View，传入 project.id（UUID），
//   本 View 在 init 内反查 project 并构造 vm —— 同 macOS 策略。

import SwiftUI
import SwiftData
import LinoJCore

struct ProjectDetailView_iOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// V5：打开 Quick Add 的 Project edit 模式需要 router。
    @Environment(TabRouter.self) private var router

    let project: Project

    @Query private var todos: [Todo]
    @Query private var events: [Event]

    @State private var vm: ProjectDetailViewModel?

    /// W2：本屏自有 SettingsViewModel，用于读 `showCompletedInCounts` 注入到 ProjectDetailViewModel
    /// （影响 stats card 的 open 计数）。
    @State private var settings = SettingsViewModel()

    /// W3：⋯ 菜单「Delete project」的确认对话框开关。
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                Color.lj.iosMainBg.ignoresSafeArea()
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
        .onChange(of: todos.count) { _, _ in vm?.refresh() }
        .onChange(of: todos.map(\.done)) { _, _ in vm?.refresh() }
        .onChange(of: events.count) { _, _ in vm?.refresh() }
        // 隐藏系统 navigation bar back button + 整个 nav bar（顶部用自己的浮动 glass 按钮）。
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: ProjectDetailViewModel) -> some View {
        ZStack(alignment: .top) {
            Color.lj.iosMainBg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    hero(vm: vm)
                        .padding(.horizontal, 20)
                        .padding(.top, 112)
                        .padding(.bottom, 18)

                    statsCard(vm: vm)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)

                    // Urgent
                    if !vm.urgent.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader(label: LJStrings.urgent, count: vm.urgent.count, withBlueDot: true)
                            ForEach(vm.urgent, id: \.id) { todo in
                                TodoBubble(todo: todo, onToggleDone: { vm.toggleDone(todo) })
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Normal
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(label: LJStrings.normal, count: vm.normal.count, withBlueDot: false)
                        normalCompactList(vm: vm)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                    // Linked events
                    linkedEventsSection(vm: vm)
                        .padding(.top, 24)

                    // Notes
                    if !project.notes.isEmpty {
                        notesSection
                            .padding(.top, 26)
                    }

                    // Completed
                    if !vm.completed.isEmpty {
                        CompletedBox(count: vm.completed.count) {
                            ForEach(vm.completed, id: \.id) { todo in
                                HStack(spacing: 8) {
                                    Text(todo.title)
                                        .font(.system(size: 13, weight: .medium))
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
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    }

                    Color.clear.frame(height: 110)
                }
            }

            // 浮动顶栏按钮（覆盖在 ScrollView 之上）
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 58)
        }
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 8) {
            // Back to Company
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text(LJStrings.tabCompany)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Color.lj.ink)
                .padding(.leading, 10)
                .padding(.trailing, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(in: Capsule())
            .accessibilityLabel(Text(LJStrings.backToCompany))

            Spacer()

            // More —— V5：菜单含「Edit project」，触发 Quick Add 的 Project edit 模式。
            // W3：追加「Delete project」项（与 macOS 对齐，确认后删除 + pop）。
            Menu {
                Button {
                    router.quickAddEditingProject = project
                    router.showQuickAdd = true
                } label: {
                    Label {
                        Text(LJStrings.editProject)
                    } icon: {
                        Image(systemName: "pencil")
                    }
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label {
                        Text(LJStrings.projectDetailDelete)
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.lj.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(in: Capsule())
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
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(vm: ProjectDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(project.tag)
                .font(.system(size: 10, weight: .bold))
                .kerning(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.lj.inkSoft)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.lj.chip)
                }
                .padding(.bottom, 10)

            Text(project.title)
                .font(.system(size: 30, weight: .bold))
                .kerning(-0.9)
                .foregroundStyle(Color.lj.ink)
                .padding(.bottom, 8)

            Text(project.intro)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(Color.lj.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                AvatarStack(people: project.members ?? [])
                Text(vm.membersSinceText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
            }
            .padding(.top, 14)
        }
    }

    // MARK: - Stats card

    @ViewBuilder
    private func statsCard(vm: ProjectDetailViewModel) -> some View {
        HStack(spacing: 0) {
            statCell(value: "\(vm.openCount)", label: LJStrings.statOpen)
            if vm.urgentCount > 0 {
                statDivider
                statCell(value: "\(vm.urgentCount)", label: LJStrings.statUrgent, color: Color.lj.blue)
            }
            statDivider
            statCell(value: "\(vm.doneCount)", label: LJStrings.statDone, color: Color.lj.inkSoft)
            statDivider
            statCell(value: "\(vm.linkedEventsCount)", label: LJStrings.statEvents)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.lj.panel)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.lj.border, lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private func statCell(value: String, label: LocalizedStringResource, color: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .kerning(-0.5)
                .monospacedDigit()
                .foregroundStyle(color ?? Color.lj.ink)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.lj.inkMute)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.lj.border)
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Normal compact list

    @ViewBuilder
    private func normalCompactList(vm: ProjectDetailViewModel) -> some View {
        VStack(spacing: 0) {
            if vm.normal.isEmpty {
                Text(LJStrings.nothingInNormal)
                    .font(.system(size: 13, weight: .medium))
                    .italic()
                    .foregroundStyle(Color.lj.inkDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LJSpacing.s14)
            } else {
                ForEach(Array(vm.normal.enumerated()), id: \.element.id) { index, todo in
                    if index > 0 {
                        Rectangle().fill(Color.lj.border).frame(height: 0.5)
                    }
                    compactNormalRow(todo: todo, onToggle: { vm.toggleDone(todo) })
                }
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
                    .font(.system(size: 14, weight: .medium))
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
                .font(.system(size: 17, weight: .bold))
                .kerning(-0.34)
                .foregroundStyle(withBlueDot ? Color.lj.blueInk : Color.lj.ink)
            Text("\(count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.lj.inkMute)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Linked events section

    @ViewBuilder
    private func linkedEventsSection(vm: ProjectDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LJStrings.linkedEvents)
                    .font(.system(size: 17, weight: .bold))
                    .kerning(-0.34)
                    .foregroundStyle(Color.lj.ink)
                Text("\(vm.linkedEventsCount)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
                Button {
                    // W5：接通「+ 添加事件」→ 打开 QuickAdd 并预填本项目（.event 设 eventProject）。
                    router.quickAddPrefilledProject = project
                    router.quickAddDefaultKind = .event
                    router.showQuickAdd = true
                } label: {
                    Text(LJStrings.addEvent)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.lj.inkSoft)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            let sortedDays = vm.linkedEventsByDay.keys.sorted()
            // 用 LinoJTime.today()：DEBUG 下取 2026-05-27 让 seed 项目的今日事件被识别。
            let todayStart = Calendar.current.startOfDay(for: LinoJTime.today())

            VStack(alignment: .leading, spacing: 14) {
                ForEach(sortedDays, id: \.self) { day in
                    let isToday = Calendar.current.isDate(day, inSameDayAs: todayStart)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
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
                        .padding(.leading, 4)

                        let dayEvents = vm.linkedEventsByDay[day] ?? []
                        VStack(spacing: 0) {
                            ForEach(Array(dayEvents.enumerated()), id: \.element.id) { idx, event in
                                eventRow(event)
                                if idx < dayEvents.count - 1 {
                                    Rectangle().fill(Color.lj.border).frame(height: 0.5)
                                }
                            }
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.lj.panel)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.lj.border, lineWidth: 0.5)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func eventRow(_ event: Event) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(Self.timeFormatter.string(from: event.start))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .kerning(-0.12)
                .monospacedDigit()
                .foregroundStyle(Color.lj.ink)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13.5, weight: .medium))
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        // W7.2：点击事件行 → 打开 QuickAdd 事件编辑模式（复用 W4 基建）。
        .onTapGesture {
            router.quickAddEditingEvent = event
            router.showQuickAdd = true
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LJStrings.notes)
                .font(.system(size: 17, weight: .bold))
                .kerning(-0.34)
                .foregroundStyle(Color.lj.ink)
                .padding(.horizontal, 4)

            Text(project.notes)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(Color.lj.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.lj.panel)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.lj.border, lineWidth: 0.5)
                }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Formatters

    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return f
    }()

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
            ProjectDetailView_iOS(project: linoj)
        }
        .modelContainer(container)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
#endif
