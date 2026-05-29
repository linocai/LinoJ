// MainView_iOS.swift
// Main tab 的 iOS 实现 —— 单列 ScrollView，背景 lj.iosMainBg。
//
// 顺序（README + ios-main.jsx）：
//   - 顶部 padding 64pt 让出 FloatingActions
//   - "To do" 34pt 大标题
//   - 单行统计 "X open · Y urgent · Z events today"
//   - 可选 HeadsUpAlert full-width（P3.2 vm.headsUp == nil → 不渲染）
//   - "Urgent" section header（蓝点 + label） + 蓝色 TodoBubble 堆叠
//   - "Normal" section header + 单张白卡内 compact rows
//   - "Upcoming today" 横向 ScrollView 之 iosMini EventCard × N
//   - "Projects" 横向 ScrollView 之 iosMini ProjectCard × N
//   - 底部 padding 100pt 让出 tab bar

import SwiftUI
import SwiftData
import LinoJCore

struct MainView_iOS: View {

    @Environment(\.modelContext) private var modelContext

    /// P4：从 RootTabView 注入的 service 容器。
    @Environment(AppServices.self) private var services

    /// I3/I4：从环境拿 router，用于 HeadsUp Open 跳 Calendar、EmptyState CTA 打开 Quick Add。
    @Environment(TabRouter.self) private var router

    /// `@Query` 拉 SwiftData 数据触发 invalidation；vm computed property 走 fetch。
    @Query private var todos: [Todo]
    @Query private var events: [Event]
    @Query private var projects: [Project]

    @State private var vm: MainViewModel?

    /// W2：本屏自有 SettingsViewModel，用于读 `showCompletedInCounts`（影响 open 计数）与
    /// `yesterdayMissedReminderEnabled`（影响 yesterday-missed 短路）注入到 MainViewModel。
    @State private var settings = SettingsViewModel()

    /// W4：当前待删除确认的事件（驱动 `.confirmationDialog`）。nil 表示无弹窗。
    @State private var eventPendingDelete: Event?

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
                vm = makeVM()
            }
        }
        // services.headsUp 从 nil 变成实际 service 时重建 vm。
        .onChange(of: services.headsUp == nil) { _, _ in
            vm = makeVM()
        }
        // W2：Settings 改 showCompletedInCounts → 注入 + refresh（计数即时切换）。
        .onChange(of: settings.showCompletedInCounts) { _, newValue in
            vm?.includeCompletedInCounts = newValue
            vm?.refresh()
        }
        // W2：Settings 改 yesterdayMissedReminderEnabled → 注入 + refresh。
        .onChange(of: settings.yesterdayMissedReminderEnabled) { _, newValue in
            vm?.showYesterdayMissed = newValue
            vm?.refresh()
        }
        .onChange(of: todos.count) { _, _ in vm?.refresh() }
        .onChange(of: events.count) { _, _ in vm?.refresh() }
        .onChange(of: projects.count) { _, _ in vm?.refresh() }
        .onChange(of: todos.map(\.done)) { _, _ in vm?.refresh() }
        .onChange(of: events.map(\.attendedConfirmed)) { _, _ in vm?.refresh() }
        // W4：删除事件确认对话框（iOS）。抽成单独 modifier 减轻 body 类型检查负担。
        .modifier(MainEventDeleteConfirmModifier_iOS(
            pending: $eventPendingDelete,
            onConfirm: { vm?.deleteEvent($0) }
        ))
    }

    // MARK: - W4 事件操作（onTap 编辑 / contextMenu）

    /// 打开事件编辑：设 router 信号让 Quick Add sheet 以 event edit 模式打开。
    private func openEdit(_ event: Event) {
        router.quickAddEditingEvent = event
        router.showQuickAdd = true
    }

    /// 事件卡 contextMenu（长按菜单）：Edit / Mark|Unmark attended（仅已结束事件）/ Delete。
    /// 「现在」用 `LinoJTime.today()`（DEBUG = 2026-05-27，与 MainViewModel 的 today 语义一致）。
    @ViewBuilder
    private func eventActions(for event: Event, vm: MainViewModel) -> some View {
        Button { openEdit(event) } label: {
            Label { Text(LJStrings.eventEdit) } icon: { Image(systemName: "pencil") }
        }
        if event.end <= LinoJTime.today() {
            if event.attendedConfirmed {
                Button { vm.unconfirmAttended(event) } label: {
                    Label { Text(LJStrings.eventUnmarkAttended) } icon: { Image(systemName: "checkmark.circle.badge.xmark") }
                }
            } else {
                Button { vm.confirmAttended(event) } label: {
                    Label { Text(LJStrings.eventMarkAttended) } icon: { Image(systemName: "checkmark.circle") }
                }
            }
        }
        Button(role: .destructive) {
            eventPendingDelete = event
        } label: {
            Label { Text(LJStrings.eventDelete) } icon: { Image(systemName: "trash") }
        }
    }

    /// 构造 MainViewModel 并注入当前 service 引用 + W2 的 Settings 派生开关。
    private func makeVM() -> MainViewModel {
        let model = MainViewModel(
            context: modelContext,
            headsUpService: services.headsUp,
            yesterdayMissedService: services.yesterdayMissed
        )
        model.includeCompletedInCounts = settings.showCompletedInCounts
        model.showYesterdayMissed = settings.yesterdayMissedReminderEnabled
        return model
    }

    @ViewBuilder
    private func content(vm: MainViewModel) -> some View {
        ZStack {
            Color.lj.iosMainBg.ignoresSafeArea()

            let isEmpty = vm.openCount == 0 && vm.todayEventsCount == 0
            if isEmpty {
                // I4: CTA 打开 Quick Add，预选 .todo。
                EmptyState(
                    variant: .inboxZero,
                    ctaTitle: LJStrings.emptyInboxZeroCTA,
                    action: {
                        router.quickAddDefaultKind = .todo
                        router.showQuickAdd = true
                    }
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Hero header（让出 FloatingActions）
                        header(vm: vm)
                            .padding(.top, 64)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)

                        // Heads-up（P3.2 vm.headsUp == nil → 跳过）
                        if let alert = vm.headsUp,
                           let event = events.first(where: { $0.id == alert.eventID }) {
                            HeadsUpAlert(
                                event: event,
                                minutesUntil: alert.minutesUntil,
                                onSnooze: { vm.snoozeHeadsUp() },
                                // I3: Open 通过 router 跳到 Calendar tab。
                                onOpen:   { router.current = .calendar }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }

                        // Urgent bubbles
                        urgentSection(vm: vm)
                            .padding(.horizontal, 16)

                        // Normal compact list
                        normalSection(vm: vm)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)

                        // Upcoming today
                        upcomingTodaySection(vm: vm)
                            .padding(.top, 22)

                        // Projects
                        projectsSection(vm: vm)
                            .padding(.top, 22)

                        // 底部让出 tab bar
                        Color.clear.frame(height: 100)
                    }
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(vm: MainViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LJStrings.mainTitle).ljDisplayTitleStyle()
            statsLine(open: vm.openCount, urgent: vm.urgentCount, events: vm.todayEventsCount)
        }
    }

    /// "X open · Y urgent · Z events today"
    /// P5：拆分成 number + word，urgent 数字蓝色。整段语序在中文里基本一致
    /// （"N 待办 · M 紧急 · 今日 K 场事件" —— 后段语序不同），所以单复杂拼接：
    /// 前两段保留数字+词的两色拼，第三段用 Counts.* 整串本地化。
    @ViewBuilder
    private func statsLine(open: Int, urgent: Int, events: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(open) ")
                .font(.system(size: 13.5, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.ink)
            Text(LJStrings.statOpen)
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
            Text("\(events) ")
                .font(.system(size: 13.5, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.ink)
            // "events today" 没有专门 string；复用 statEvents（"事件"/"events"）+
            // Day.today（"今天"/"Today"） —— 但视觉是 "events today"。
            // 简洁策略：保留 "events" 单词（中英都用 statEvents），不额外加 today，
            // 因为 Main 顶部所有计数本来就是 today 上下文。
            Text(LJStrings.statEvents)
                .font(.system(size: 13.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
        }
    }

    // MARK: - Urgent

    @ViewBuilder
    private func urgentSection(vm: MainViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(label: LJStrings.urgent, count: vm.urgentTodos.count, withBlueDot: true)
            ForEach(vm.urgentTodos, id: \.id) { todo in
                TodoBubble(todo: todo, onToggleDone: { vm.toggleDone(todo) })
            }
            if vm.urgentTodos.isEmpty {
                Text(LJStrings.nothingUrgentNice)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .italic()
                    .foregroundStyle(Color.lj.inkDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, LJSpacing.s14)
            }
        }
    }

    // MARK: - Normal compact list

    @ViewBuilder
    private func normalSection(vm: MainViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(label: LJStrings.normal, count: vm.normalTodos.count, withBlueDot: false)
            VStack(spacing: 0) {
                ForEach(Array(vm.normalTodos.enumerated()), id: \.element.id) { index, todo in
                    if index > 0 {
                        Rectangle().fill(Color.lj.border).frame(height: 0.5)
                    }
                    compactNormalRow(todo: todo, onToggle: { vm.toggleDone(todo) })
                }
                if vm.normalTodos.isEmpty {
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
                // checkbox 占位
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

                if let project = todo.project {
                    Text(project.title.split(separator: " ").first.map(String.init) ?? project.title)
                        .font(.system(size: 10.5, weight: .medium, design: .default))
                        .foregroundStyle(Color.lj.inkMute)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .opacity(todo.done ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Upcoming today

    @ViewBuilder
    private func upcomingTodaySection(vm: MainViewModel) -> some View {
        // 用 LinoJTime.today() 而非 now()：DEBUG 下 today=2026-05-27 09:00，让 seed 内 09:30
        // 之后的事件被识别为 "upcoming"；如果用真实 now()，DEBUG 下 todayEvents 全部在
        // 2026-05-27 09:00 附近、real now 可能跨越数年，整段会变空。
        let now = LinoJTime.today()
        let upcoming = vm.todayEvents.filter { $0.start > now }
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    sectionHeader(label: LJStrings.upcomingToday, count: upcoming.count, withBlueDot: false)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 0)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(upcoming, id: \.id) { event in
                            // W4：mini 卡外层套 onTap（打开编辑）+ contextMenu（长按）。
                            EventCard(event: event, variant: .iosMini)
                                .contentShape(Rectangle())
                                .onTapGesture { openEdit(event) }
                                .contextMenu { eventActions(for: event, vm: vm) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Projects

    @ViewBuilder
    private func projectsSection(vm: MainViewModel) -> some View {
        let projects = vm.projects
        if !projects.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    sectionHeader(label: LJStrings.projects, count: projects.count, withBlueDot: false)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(projects, id: \.id) { project in
                            ProjectCard(project: project, variant: .iosMini)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Section header helper

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

// MARK: - W4 删除事件确认对话框 modifier（iOS）

/// 把 `.confirmationDialog` 抽成独立 modifier —— 直接挂在 MainView_iOS 的 body 长链上易触发
/// Swift「unable to type-check this expression in reasonable time」。抽出后 body 链恢复简单。
private struct MainEventDeleteConfirmModifier_iOS: ViewModifier {
    @Binding var pending: Event?
    let onConfirm: (Event) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text(LJStrings.eventDeleteConfirmTitle),
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            titleVisibility: .visible,
            presenting: pending
        ) { event in
            Button(role: .destructive) {
                onConfirm(event)
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
        try SeedData.seedIfEmpty(container.mainContext)
        return MainView_iOS()
            .environment(AppServices())   // P4：Preview 注入空 service 容器
            .modelContainer(container)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
#endif
