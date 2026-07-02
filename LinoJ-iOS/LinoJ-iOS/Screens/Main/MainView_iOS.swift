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
    /// U4：Main 角块「最近灵感」用 —— @Query 触发 invalidation，noteListVM 取 recentNotes(3)。
    @Query private var notes: [Note]

    @State private var vm: MainViewModel?

    /// U4：Main 角块「最近灵感」自持的轻量 NoteListViewModel（**不污染 MainViewModel**，与 macOS 同模式）。
    @State private var noteListVM: NoteListViewModel?

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
                Color.clear.ljScreenBackground(.iOS)
            }
        }
        .task {
            if vm == nil {
                vm = makeVM()
            }
            // U4：Main 角块自持的 NoteListViewModel（轻量，不进 MainViewModel）。
            if noteListVM == nil {
                noteListVM = NoteListViewModel(context: modelContext)
            }
        }
        // U4：note 数据变化 → 让角块 VM 重算。抽成 modifier 减轻 body 类型检查负担（见 CLAUDE.md）。
        .modifier(NoteInvalidationModifier_iOS(
            noteCount: notes.count,
            noteUpdatedAts: notes.map(\.updatedAt),
            onChange: { noteListVM?.refresh() }
        ))
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
        // v1.3 R7：底色暖渐变 + bloom orb（替换 iosMainBg 实心遮挡），玻璃材质才显半透浮起。
        ZStack {
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
                                // v1.2 P4：进行中文案 + 「+N 更多」角标。
                                isOngoing: alert.isOngoing,
                                remainingMinutes: alert.remainingMinutes,
                                moreCount: alert.moreCount,
                                onSnooze: { vm.snoozeHeadsUp() },
                                // I3: Open 通过 router 跳到 Calendar tab。
                                onOpen:   { router.current = .calendar }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }

                        // v1.2 P3：urgent 软反思 nudge（仅 Main，决策 D2）。非阻塞镜子 + 小 ×。
                        if vm.urgentReflectionNudge {
                            urgentNudge(count: vm.urgentCount, onDismiss: { vm.dismissUrgentNudge() })
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }

                        // U6：今日时间冲突提示（中性色变体）。蓝色 heads-up 在上、conflict 在下，
                        // 两者都有时都显示、不互相吞。conflict 是被动提示，无按钮。
                        if let conflict = vm.conflict {
                            ConflictAlert(atTime: conflict.atTime, count: conflict.count)
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

                        // U4：「最近灵感」角块（在 Projects 之后、底部留白之前）。
                        recentInspirationSection()
                            .padding(.top, 22)

                        // U8：原生 tab bar 已由系统安全区让位，仅保留小段视觉呼吸。
                        Color.clear.frame(height: 24)
                    }
                }
            }
        }
        // v1.3 R7：iOS 底色渐变 + bloom orb（玻璃可见的前提）。
        .ljScreenBackground(.iOS)
    }

    // MARK: - Header

    @ViewBuilder
    private func header(vm: MainViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LJStrings.mainTitle).ljDisplayTitleStyle()
            statsLine(open: vm.openCount, urgent: vm.urgentCount, events: vm.todayEventsCount)
        }
    }

    // MARK: - v1.2 P3 urgent 软反思 nudge

    /// 被动反思 pill：「N 件都标急了——还都急吗？」+ 一个小 ×。非阻塞，点 × 仅本次会话隐藏。
    @ViewBuilder
    private func urgentNudge(count: Int, onDismiss: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.lj.blueInk)
            Text(LJStrings.nudgeUrgentReflection(count))
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lj.inkSoft)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LJStrings.fromYesterdayDismiss))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous)
                .fill(Color.lj.blueSofter)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous)
                .strokeBorder(Color.lj.blueBorder, lineWidth: 0.5)
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
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: LJStrings.urgent, count: vm.urgentTodos.count, withBlueDot: true)
            // v1.3 R7：主页待办来源标签胶囊（showSource: true，仅主页）。
            ForEach(vm.urgentTodos, id: \.id) { todo in
                TodoBubble(todo: todo, showSource: true, onToggleDone: { vm.toggleDone(todo) })
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
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: LJStrings.normal, count: vm.normalTodos.count, withBlueDot: false)
            // v1.3 R7：整组玻璃卡（.regularMaterial + hairline + 顶高光 + 柔投影），行内 0.5px hairline。
            VStack(spacing: 0) {
                ForEach(Array(vm.normalTodos.enumerated()), id: \.element.id) { index, todo in
                    if index > 0 {
                        Rectangle().fill(Color.lj.border).frame(height: 0.5)
                    }
                    // v1.3 R7：主页 normal 行也显来源标签胶囊（showSource: true）。
                    compactNormalRow(todo: todo, showSource: true, onToggle: { vm.toggleDone(todo) })
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
            .ljGlassPanel(radius: 16, padded: false)
        }
    }

    /// 主页 / 同 scope 页通用的 compact normal 行。
    /// - showSource: true（主页）显示来源标签胶囊（个人灰 / 公司紫）；false 时仅显项目名（若有）。
    @ViewBuilder
    private func compactNormalRow(todo: Todo, showSource: Bool = false, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // checkbox 占位
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

                // v1.3 签收前修复（🟡-5）：来源标签胶囊 + 项目名胶囊并排（仅主页，§E 契约 / 原型 728-734 行）；
                // 非主页仅显项目名。复用 LJSourceLabel（与 TodoBubble urgent 行同款），修前只渲 scope、
                // 项目名分支误落 else-if 导致挂 project 的公司待办不显示项目名。
                if showSource {
                    LJSourceLabel(scope: todo.scope, projectName: todo.project?.title)
                } else if let project = todo.project {
                    Text(project.title.split(separator: " ").first.map(String.init) ?? project.title)
                        .font(.system(size: 10.5, weight: .medium, design: .default))
                        .foregroundStyle(Color.lj.inkMute)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
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

    // MARK: - U4 最近灵感角块

    /// 「最近灵感」section：小节头 + 横向 1-3 条 note 卡（点击 → 切 Inspiration tab）
    /// + 「随手记一条」入口（→ 切 tab + createNote 打开新编辑器）。
    /// 数据用自持的 noteListVM.recentNotes(3)，**不污染 MainViewModel**。
    @ViewBuilder
    private func recentInspirationSection() -> some View {
        let recent = noteListVM?.recentNotes(limit: 3) ?? []
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader(label: LJStrings.inspirationRecent, count: recent.count, withBlueDot: false)
            }
            .padding(.horizontal, 16)

            if recent.isEmpty {
                // 无 note：只给「随手记一条」入口（单卡）。
                jotEntryCard()
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recent, id: \.id) { note in
                            recentNoteCard(note: note)
                        }
                        jotEntryCard()
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    /// 单条「最近灵感」mini 卡（点击 → 切到 Inspiration tab）。
    @ViewBuilder
    private func recentNoteCard(note: Note) -> some View {
        Button {
            router.current = .inspiration
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.lj.inkMute)
                    }
                    Image(systemName: "lightbulb")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.lj.inkMute)
                    Spacer()
                }
                Text(note.displayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.lj.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 150, height: 86, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
            .overlay { LJTopHighlight(radius: 14) }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// 「随手记一条」入口卡（→ 切 Inspiration tab + createNote 打开新编辑器）。
    @ViewBuilder
    private func jotEntryCard() -> some View {
        Button {
            noteListVM?.createNote()
            router.current = .inspiration
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lj.inkSoft)
                Spacer(minLength: 0)
                Text(LJStrings.inspirationQuickJot)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.lj.inkSoft)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(width: 150, height: 86, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.lj.chip)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.lj.border, style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section header helper

    @ViewBuilder
    private func sectionHeader(label: LocalizedStringResource, count: Int, withBlueDot: Bool) -> some View {
        // v1.3 R7：urgent 段标小圆点 = 品牌渐变（原型）；normal = 灰点。标题统一 ink（不再染蓝）。
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

// MARK: - U4 note 数据变化观察 modifier（iOS）

/// 把「最近灵感」角块的两条 `@Query` note 失效观察抽成 modifier —— 直接挂在 MainView_iOS
/// 已经很长的 body 链上会把它推过 Swift 类型检查阈值（unable to type-check in reasonable time）。
private struct NoteInvalidationModifier_iOS: ViewModifier {
    let noteCount: Int
    let noteUpdatedAts: [Date]
    let onChange: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: noteCount) { _, _ in onChange() }
            .onChange(of: noteUpdatedAts) { _, _ in onChange() }
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
