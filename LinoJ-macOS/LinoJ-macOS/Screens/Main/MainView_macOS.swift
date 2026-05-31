// MainView_macOS.swift
// Main tab 的 macOS 实现 —— 两列 grid `1fr 360pt`。
//
// 左列（flex 列，16pt gap）：
//   - 可选 HeadsUpAlert（vm.headsUp != nil 时；P3.2 始终 nil → 不渲染）
//   - 标题 "To do" 26pt + 计数 "X open · Y urgent"（urgent 数字 blue）
//   - 两列 kanban：Urgent + Normal 各占 1fr，内部 ScrollView，flex 1 高度
//   - 底部 pinned Projects strip：top-border + 每个 project 一行 1fr 200pt 110pt
//
// 右栏 360pt：
//   - "Next 7 days" 标题 + 7 行 day-row（Today / Tomorrow / Wed 28...）
//   - 每行：day 字 + 前 3 个事件（macRail variant）+ "+N more"
//   - 底部 pinned "From yesterday" dashed-border 灰 box（checkable rows）
//
// 数据：MainViewModel 从 SwiftData 拉。View 同时 `@Query` 三类模型，仅用来触发 invalidation：
// 数据变化时 onChange → vm.refresh()，让 ViewModel 的 computed property 重新 fetch。

import SwiftUI
import SwiftData
import LinoJCore

struct MainView_macOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(TabRouter.self) private var router

    /// P4：从 RootWindow 注入的 service 容器；用 services.headsUp / services.yesterdayMissed
    /// 给 MainViewModel 提供 `headsUp` 与 `yesterdayMissed` 数据源。
    @Environment(AppServices.self) private var services

    /// `@Query` 拉所有 Todo / Event / Project，仅用于触发 invalidation（SwiftData 变化时
    /// SwiftUI 自动重算依赖了 query 的 View）。`vm` 内部仍走 fetch 拿到强类型 + 自己排序的列表。
    @Query private var todos: [Todo]
    @Query private var events: [Event]
    @Query private var projects: [Project]

    /// U3：Main 右栏「最近灵感」缩略卡的数据源。`@Query` 拉所有 Note，下面按排序契约取最近 3 条。
    /// 不污染 MainViewModel（角块自持轻量 NoteListViewModel）。
    @Query private var notes: [Note]

    /// U3：角块自持的 NoteListViewModel —— 仅用其 `createNote()`（「快速记一条」入口）。
    /// 排序/取前 3 条直接在 View 里用 `@Query` 的 notes 排闭包，避免与 listVM 的 tick 刷新耦合。
    @State private var noteListVM: NoteListViewModel?

    /// MainViewModel 在 `.task` 中由 modelContext 实例化。这里用 Optional 兜底，
    /// 让 View body 在 task fire 之前也能编译过。
    @State private var vm: MainViewModel?

    /// W2：本屏自有一个 SettingsViewModel 实例，用于读 `showCompletedInCounts`
    /// （影响 open 计数）与 `yesterdayMissedReminderEnabled`（影响「From yesterday」box 显示），
    /// 注入到 MainViewModel。与 RootWindow 各 own 一份同模式（VM 自带 UserDefaults 持久化）。
    @State private var settings = SettingsViewModel()

    /// W4：当前待删除确认的事件（驱动 `.confirmationDialog`）。nil 表示无弹窗。
    @State private var eventPendingDelete: Event?

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                Color.lj.bg.ignoresSafeArea()
            }
        }
        .task {
            // 首次构造。services.headsUp / yesterdayMissed 此刻可能还是 nil（RootWindow
            // 的 .task 与本 .task 是并行的）；当 services 字段被填充后，下面 onChange 会
            // 再构造一次，VM 拿到最新的 service 引用。
            if vm == nil {
                vm = makeVM()
            }
            // U3：角块用的轻量 NoteListViewModel（仅 createNote）。
            if noteListVM == nil {
                noteListVM = NoteListViewModel(context: modelContext)
            }
        }
        // services.headsUp 从 nil → 实际 service 时（RootWindow .task 完成），重建 vm。
        // 用「nil-ness」作为变化信号 —— 一旦 RootWindow 把 service 灌进来，vm 就持有它。
        .onChange(of: services.headsUp == nil) { _, _ in
            vm = makeVM()
        }
        // W2：Settings 改 showCompletedInCounts → 注入新值 + refresh（计数即时切换）。
        .onChange(of: settings.showCompletedInCounts) { _, newValue in
            vm?.includeCompletedInCounts = newValue
            vm?.refresh()
        }
        // W2：Settings 改 yesterdayMissedReminderEnabled → 注入 + refresh（box 即时显隐）。
        .onChange(of: settings.yesterdayMissedReminderEnabled) { _, newValue in
            vm?.showYesterdayMissed = newValue
            vm?.refresh()
        }
        // SwiftData 数据变化时让 ViewModel 重算 computed property。
        .onChange(of: todos.count) { _, _ in vm?.refresh() }
        .onChange(of: events.count) { _, _ in vm?.refresh() }
        .onChange(of: projects.count) { _, _ in vm?.refresh() }
        .onChange(of: todos.map(\.done)) { _, _ in vm?.refresh() }
        .onChange(of: events.map(\.attendedConfirmed)) { _, _ in vm?.refresh() }
        // W4：删除事件确认对话框（macOS）。抽成单独 modifier 减轻 body 类型检查负担。
        .modifier(EventDeleteConfirmModifier(
            pending: $eventPendingDelete,
            onConfirm: { vm?.deleteEvent($0) }
        ))
    }

    // MARK: - W4 事件操作（onTap 编辑 / contextMenu）

    /// 打开事件编辑：设 router 信号让 Quick Add modal 以 event edit 模式打开。
    private func openEdit(_ event: Event) {
        router.quickAddEditingEvent = event
        router.showQuickAdd = true
    }

    /// 事件卡 contextMenu 内容：Edit / Mark|Unmark attended（仅已结束事件）/ Delete。
    /// 「标记已出席」仅对已结束事件（end <= 现在）出现；已确认则翻转为「取消已出席」。
    /// 「现在」用 `LinoJTime.today()`（DEBUG = 2026-05-27，与 MainViewModel 的 today 语义一致）。
    @ViewBuilder
    private func eventActions(for event: Event, vm: MainViewModel) -> some View {
        Button { openEdit(event) } label: {
            Text(LJStrings.eventEdit)
        }
        if event.end <= LinoJTime.today() {
            if event.attendedConfirmed {
                Button { vm.unconfirmAttended(event) } label: {
                    Text(LJStrings.eventUnmarkAttended)
                }
            } else {
                Button { vm.confirmAttended(event) } label: {
                    Text(LJStrings.eventMarkAttended)
                }
            }
        }
        Divider()
        Button(role: .destructive) {
            eventPendingDelete = event
        } label: {
            Text(LJStrings.eventDelete)
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

    // MARK: - Layout

    @ViewBuilder
    private func content(vm: MainViewModel) -> some View {
        // P6：用 GeometryReader 读窗口宽度做响应式布局。
        // < 900pt：隐藏右栏 360pt（左列占满窗口）。
        // 其它宽度：保持原 1fr | 360pt 双列。
        GeometryReader { geo in
            let hideRightRail = geo.size.width < 900

            HStack(spacing: 0) {
                leftColumn(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !hideRightRail {
                    // 360pt 右栏 + 左边线分隔
                    rightRail(vm: vm)
                        .frame(width: 360)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.lj.border)
                                .frame(width: 0.5)
                        }
                }
            }
            .background(Color.lj.bg)
        }
    }

    // MARK: - Left column

    @ViewBuilder
    private func leftColumn(vm: MainViewModel) -> some View {
        // 空状态：所有 todo 都关 + 今天没事件
        let isEmpty = vm.openCount == 0 && vm.todayEventsCount == 0

        VStack(alignment: .leading, spacing: LJSpacing.s16) {
            // P3.2 vm.headsUp == nil，但占位检查保留：P4 接通后此分支自然 render。
            if let alert = vm.headsUp {
                // Heads-up 需要 Event 引用。从 events 里查一遍，没找到就跳过 render。
                if let event = events.first(where: { $0.id == alert.eventID }) {
                    HeadsUpAlert(
                        event: event,
                        minutesUntil: alert.minutesUntil,
                        onSnooze: { vm.snoozeHeadsUp() },
                        // I3: Open 按钮直接通过 router 跳转到 Calendar tab（不必经过 VM）。
                        onOpen:   { router.current = .calendar }
                    )
                }
            }

            // 标题 + 计数
            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s16) {
                Text(LJStrings.mainTitle).ljDisplayTitleStyle()
                countsLine(open: vm.openCount, urgent: vm.urgentCount)
                Spacer()
            }

            if isEmpty {
                Spacer()
                EmptyState(
                    variant: .inboxZero,
                    ctaTitle: LJStrings.emptyInboxZeroCTA,
                    action: { router.showQuickAdd = true }
                )
                Spacer()
            } else {
                // 两列 kanban，内部各自滚动
                HStack(alignment: .top, spacing: LJSpacing.s18) {
                    bubbleColumn(
                        label: LJStrings.urgent,
                        isUrgent: true,
                        items: vm.urgentTodos,
                        onToggle: { vm.toggleDone($0) }
                    )
                    bubbleColumn(
                        label: LJStrings.normal,
                        isUrgent: false,
                        items: vm.normalTodos,
                        onToggle: { vm.toggleDone($0) }
                    )
                }
                .frame(maxHeight: .infinity)
            }

            // 底部 pinned projects strip
            projectsStrip(vm: vm)
        }
        .padding(.horizontal, LJSpacing.s28)
        .padding(.top, LJSpacing.s22)
        .padding(.bottom, LJSpacing.s22)
    }

    /// "X open · Y urgent" 计数行。urgent 数字蓝色。
    ///
    /// P5：拆分成数字 + 词的组合，urgent 数字蓝色。因为这里要分色，
    /// 不能用 Counts.openUrgent 整串 —— 改用 `Stat.open` / `Stat.urgent` 单词级 token，
    /// 数字本身仍是 raw（不本地化）。
    @ViewBuilder
    private func countsLine(open: Int, urgent: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(open) ")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.ink)
            Text(LJStrings.statOpen)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
            Text(" · ")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkDim)
            Text("\(urgent) ")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.blue)
            Text(LJStrings.statUrgent)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
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
            // Section header：蓝点（urgent 列）+ label + count
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

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: LJSpacing.s8) {
                    ForEach(items, id: \.id) { todo in
                        TodoBubble(todo: todo, onToggleDone: { onToggle(todo) })
                    }
                    if items.isEmpty {
                        Text(LJStrings.nothingHere)
                            .font(.system(size: 12.5, weight: .medium, design: .default))
                            .italic()
                            .foregroundStyle(Color.lj.inkDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, LJSpacing.s16)
                    }
                }
                .padding(.trailing, 4)  // 让出 scroll bar 槽
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Projects strip

    @ViewBuilder
    private func projectsStrip(vm: MainViewModel) -> some View {
        let projects = vm.projects
        VStack(alignment: .leading, spacing: 0) {
            // 上边线
            Rectangle().fill(Color.lj.border).frame(height: 0.5)
                .padding(.bottom, LJSpacing.s12)

            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s10) {
                Text(LJStrings.projects)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .kerning(-0.24)
                    .foregroundStyle(Color.lj.ink)
                Text(String(localized: "Counts.projectsActive", defaultValue: "live in Company · \(projects.count) active", bundle: LinoJCoreBundle.bundle))
                    .font(.system(size: 11.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
            }
            .padding(.bottom, LJSpacing.s10)

            ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                if index > 0 {
                    Rectangle().fill(Color.lj.border).frame(height: 0.5)
                }
                projectRow(project)
            }
        }
    }

    /// Projects strip 单行：title+tag+intro / mono stats / AvatarStack。
    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        // 计数：用 project.todos / project.events 直接读关系，省得再走 fetch。
        let openTodos = (project.todos ?? []).filter { !$0.done }.count
        let urgentTodos = (project.todos ?? []).filter { !$0.done && $0.urgency == .urgent }.count
        let eventCount = (project.events ?? []).count

        HStack(alignment: .top, spacing: LJSpacing.s22) {
            // 左：title + tag + intro (flex)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s10) {
                    Text(project.title).ljCardTitleStyle()
                    Text(project.tag).ljTagPill()
                }
                Text(project.intro)
                    .font(.system(size: 12.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 中：mono stats（200pt 固定）
            //
            // P5：单复数复杂语义（中文不区分单复数）—— 采用纯 word token，单复数差异
            // 由 Stat.events / Section.todos 词条吞掉（en 用 "events"/"Todos"，
            // 中文一律 "事件"/"待办"）。urgent 后缀单独本地化。
            HStack(spacing: LJSpacing.s18) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(openTodos)")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(urgentTodos > 0 ? Color.lj.blue : Color.lj.ink)
                        .monospacedDigit()
                    if urgentTodos > 0 {
                        // "todos · X urgent" / "待办 · X 紧急"
                        Text("\(String(localized: LJStrings.todos)) · \(urgentTodos) \(String(localized: LJStrings.statUrgent))")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundStyle(Color.lj.inkSoft)
                    } else {
                        Text(LJStrings.todos)
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundStyle(Color.lj.inkSoft)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(eventCount)")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.lj.ink)
                        .monospacedDigit()
                    Text(LJStrings.statEvents)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundStyle(Color.lj.inkSoft)
                }
            }
            .frame(width: 200, alignment: .leading)

            // 右：AvatarStack（110pt）
            AvatarStack(people: project.members ?? [], max: 4)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.vertical, LJSpacing.s10)
        .contentShape(Rectangle())
        .ljHoverLift()
    }

    // MARK: - Right rail

    @ViewBuilder
    private func rightRail(vm: MainViewModel) -> some View {
        let groups = vm.next7DaysGrouped

        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s10) {
                Text(LJStrings.next7Days)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .kerning(-0.24)
                    .foregroundStyle(Color.lj.ink)
                Spacer()
            }
            .padding(.bottom, LJSpacing.s8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        Rectangle().fill(Color.lj.border).frame(height: 0.5)
                        dayRow(vm: vm, day: group.day, events: group.events)
                    }
                }
            }

            // pinned "From yesterday"
            if !vm.yesterdayMissed.isEmpty {
                yesterdayBox(events: vm.yesterdayMissed, onConfirm: { vm.confirmAttended($0) })
                    .padding(.top, LJSpacing.s22)
            }

            // U3：右栏最底「最近灵感」缩略卡。
            recentInspirationCard()
                .padding(.top, LJSpacing.s22)
        }
        .padding(.horizontal, LJSpacing.s18)
        .padding(.vertical, LJSpacing.s22)
    }

    // MARK: - U3 「最近灵感」缩略卡

    /// 右栏最底「最近灵感」缩略卡：小节头 + 最近 3 条 note 标题（点击整卡 → 切 Inspiration tab）
    /// + 「快速记一条」入口（切 tab + 打开新编辑器）。复用 `.ljCardStyle()` 卡片观感。
    @ViewBuilder
    private func recentInspirationCard() -> some View {
        // 排序契约：置顶组在上，各组内 updatedAt 倒序，取前 3 条。
        let pinned = notes.filter { $0.isPinned }.sorted { $0.updatedAt > $1.updatedAt }
        let others = notes.filter { !$0.isPinned }.sorted { $0.updatedAt > $1.updatedAt }
        let recent = Array((pinned + others).prefix(3))

        VStack(alignment: .leading, spacing: LJSpacing.s8) {
            // 小节头：点击整卡区域切到 Inspiration tab（用透明按钮包标题行）。
            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s8) {
                Text(LJStrings.inspirationRecent)
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .kerning(0.88)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.lj.inkDim)
            }

            if recent.isEmpty {
                Text(LJStrings.inspirationEmpty)
                    .font(.system(size: 12, weight: .medium))
                    .italic()
                    .foregroundStyle(Color.lj.inkDim)
                    .padding(.vertical, 2)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(recent, id: \.id) { note in
                        HStack(spacing: LJSpacing.s8) {
                            if note.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.lj.inkMute)
                            }
                            Text(note.displayTitle)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Color.lj.inkSoft)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            // 「快速记一条」入口
            Button {
                router.current = .inspiration
                noteListVM?.createNote()
            } label: {
                HStack(spacing: LJSpacing.s6) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text(LJStrings.inspirationQuickJot)
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(Color.lj.inkSoft)
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .ljHoverBackground()
        }
        .ljCardStyle()
        // 点击卡片主体（标题区）切到 Inspiration tab；「快速记一条」按钮已独立处理。
        .contentShape(RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous))
        .onTapGesture { router.current = .inspiration }
        .ljHoverLift()
    }

    @ViewBuilder
    private func dayRow(vm: MainViewModel, day: Date, events: [Event]) -> some View {
        let label = dayLabel(for: day)
        let dateNumber = dayDateNumber(for: day)
        let isToday = Calendar.current.isDateInToday(day)

        HStack(alignment: .top, spacing: LJSpacing.s12) {
            // 左 60pt：day label + 日期
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold, design: .default))
                    .kerning(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(isToday ? Color.lj.ink : Color.lj.inkMute)
                HStack(spacing: 5) {
                    Text(dateNumber)
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .kerning(-0.36)
                        .foregroundStyle(isToday ? Color.lj.ink : Color.lj.ink)
                    if isToday {
                        Circle()
                            .fill(Color.lj.ink)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(width: 60, alignment: .leading)

            // 右：前 3 场事件 + "+N more"
            VStack(alignment: .leading, spacing: 5) {
                if events.isEmpty {
                    Text(LJStrings.nothingOnBooks)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .italic()
                        .foregroundStyle(Color.lj.inkDim)
                        .padding(.top, 3)
                }
                ForEach(events.prefix(3), id: \.id) { event in
                    // W4：macRail row 外层套 onTap（打开编辑）+ contextMenu（Edit/Mark/Delete）。
                    EventCard(event: event, variant: .macRail)
                        .contentShape(Rectangle())
                        .onTapGesture { openEdit(event) }
                        .contextMenu { eventActions(for: event, vm: vm) }
                }
                if events.count > 3 {
                    Text(String(localized: "Counts.moreEvents", defaultValue: "+\(events.count - 3) more", bundle: LinoJCoreBundle.bundle))
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundStyle(Color.lj.inkMute)
                        .padding(.leading, 52)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, LJSpacing.s10)
    }

    // MARK: - "From yesterday"

    @ViewBuilder
    private func yesterdayBox(events: [Event], onConfirm: @escaping (Event) -> Void) -> some View {
        VStack(alignment: .leading, spacing: LJSpacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s8) {
                Text(LJStrings.fromYesterday)
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .kerning(0.88)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.lj.inkMute)
                Text(LJStrings.tapToConfirm)
                    .font(.system(size: 10.5, weight: .medium, design: .default))
                    .italic()
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(events, id: \.id) { event in
                    Button {
                        onConfirm(event)
                    } label: {
                        yesterdayRow(event: event)
                    }
                    .buttonStyle(.plain)
                    // P6：macOS list row hover 背景。
                    .ljHoverBackground()
                }
            }
        }
        .padding(.horizontal, LJSpacing.s14)
        .padding(.vertical, LJSpacing.s12)
        .background {
            RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous)
                .fill(Color.lj.chip)
        }
        .ljDashedBorder()
    }

    @ViewBuilder
    private func yesterdayRow(event: Event) -> some View {
        HStack(alignment: .top, spacing: LJSpacing.s10) {
            // 简化 checkbox：小方框
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Color.lj.inkMute, lineWidth: 1.2)
                .frame(width: 13, height: 13)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                Text("\(timeText(event.start)) · \(event.location)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.lj.inkMute)
            }
            Spacer()
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    // MARK: - Date helpers

    /// 「Today / Tomorrow / Wed / Thu / Fri / Sat / Sun / Mon」等短 label。
    /// P5：Today / Tomorrow 本地化，其它由 DateFormatter 按当前 locale 自动产出短星期。
    private func dayLabel(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: LJStrings.today) }
        if calendar.isDateInTomorrow(day) { return String(localized: LJStrings.tomorrow) }
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f.string(from: day)
    }

    /// 单数字日期（"27" / "28"）。
    private func dayDateNumber(for day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: day)
    }

    /// "09:30" 等。
    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - W4 删除事件确认对话框 modifier

/// 把 `.confirmationDialog` 抽成独立 modifier —— 直接挂在 MainView_macOS 的 body 长链上会触发
/// Swift「unable to type-check this expression in reasonable time」。抽出后 body 链恢复简单。
private struct EventDeleteConfirmModifier: ViewModifier {
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
        return MainView_macOS()
            .environment(TabRouter())
            .environment(AppServices())          // P4：Preview 也要注入 service 容器
            .modelContainer(container)
            .frame(width: 1200, height: 720)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
#endif
