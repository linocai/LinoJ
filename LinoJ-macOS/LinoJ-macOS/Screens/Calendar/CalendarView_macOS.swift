// CalendarView_macOS.swift
// Calendar tab 的 macOS 实现 —— Plan P3.4：
//
// 顶栏（标题 / 计数 / 周 nav / Today / +New event）
//   - 左：大标题 "Calendar" 26pt + 计数 "X events this week"
//   - 中：‹  May 27 — Jun 2  ›  + Today 按钮
//   - 右：`+ New event` ink 按钮（点击翻 router.showQuickAdd —— P3.6 实接 Quick Add 预设 Event）
//
// 主体：7-column 周视图
//   - 左侧 52pt 时间标签列（"7 AM" ... "9 PM"）
//   - 7 列等宽：(geometry.width - 52) / 7
//   - 表头行：每列 weekday label + 日期数字；today 列略加高亮
//   - 主网格：14 行（07:00 - 21:00），46pt/hour
//   - today 列整列背景 lj.bgSoft 微染
//   - today 列叠 "now" 黑线（仅 7AM-9PM 范围内可见）+ 左缘小圆点
//   - 每个 event 渲染为 EventCard(.macWeekGrid) 绝对定位
//
// now 线：Timer.publish(every: 60) 每分钟刷新；仅在 viewing today's week 时启用。
// View lifecycle：用 @State Timer cancellable + .onDisappear cancel 避免 Timer leak。

import SwiftUI
import SwiftData
import LinoJCore

struct CalendarView_macOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(TabRouter.self) private var router

    /// P4：从 RootWindow 注入的 service 容器（提供 YesterdayMissedService）。
    @Environment(AppServices.self) private var services

    /// `@Query` 拉 SwiftData Event 列表，仅用于触发 invalidation（增删改时 SwiftUI 重 render）。
    /// vm computed property 走自己的 fetch + sort。
    @Query private var events: [Event]

    @State private var vm: CalendarViewModel?

    /// W2：本屏自有 SettingsViewModel，用于读 `yesterdayMissedReminderEnabled` 注入到
    /// CalendarViewModel（gate「From yesterday」box）。
    @State private var settings = SettingsViewModel()

    /// 每分钟刷新一次的「现在」时刻 —— 用于驱动 now 线纵向位置。
    /// 用 view-level @State 避免 vm.now 直接驱动 SwiftUI invalidation（vm.now 是从 init 时
    /// 固定下来的）。
    @State private var nowMinuteTick: Date = LinoJTime.now()

    /// Timer 引用，存到 @State 让 lifecycle 能 cancel。Optional 因为 onAppear 之前为 nil。
    @State private var nowTimer: Timer?

    /// W4：当前待删除确认的事件（驱动 `.confirmationDialog`）。nil 表示无弹窗。
    @State private var eventPendingDelete: Event?

    /// 7AM - 9PM 的小时数（14 小时）。
    private let startHour: Int = 7
    private let endHour: Int = 21
    private var hoursVisible: Int { endHour - startHour }   // 14
    // v1.3 R4：对原型重建 —— 行高 44pt（原型 repeating-linear-gradient 44px / (ev.s-7)*44 定位）。
    private let pxPerHour: CGFloat = 44
    private let timeColumnWidth: CGFloat = 52

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                // v1.3 R4：透明占位，让 RootWindow 背景层（底色 + orb）透上来。
                Color.clear
            }
        }
        .task {
            if vm == nil {
                vm = makeVM()
            }
        }
        .onChange(of: services.yesterdayMissed == nil) { _, _ in
            vm = makeVM()
        }
        // W2：Settings 改 yesterdayMissedReminderEnabled → 注入 + refresh（box 即时显隐）。
        .onChange(of: settings.yesterdayMissedReminderEnabled) { _, newValue in
            vm?.showYesterdayMissed = newValue
            vm?.refresh()
        }
        .onChange(of: events.count) { _, _ in vm?.refresh() }
        .onChange(of: events.map(\.attendedConfirmed)) { _, _ in vm?.refresh() }
        // W3：Search 选中 event → 定位到那天（移动窗口 + 设 selectedDay）后清回 nil。
        .onChange(of: router.pendingEventDate) { _, newValue in
            consumePendingEventDate(newValue)
        }
        .onAppear {
            startNowTimer()
            consumePendingEventDate(router.pendingEventDate)
        }
        .onDisappear {
            stopNowTimer()
        }
        // W4：删除事件确认对话框（macOS）。抽成单独 modifier 减轻 body 类型检查负担。
        .modifier(CalendarEventDeleteConfirmModifier(
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

    /// U7：拖拽结束后把「已吸附到 15 分钟刻度的 Δ分钟」应用到事件——整块平移（保持时长），
    /// 写回共享 VM 的 `moveEvent`（save + refresh）。deltaMinutes 由 DraggableEventCard 在
    /// onEnded 时算好并吸附（Δy / pxPerHour * 60 → round 到最近 15 分钟）。
    /// MVP 仅做上下平移改时刻；跨天（左右平移改日期）列为本期可选未做。
    private func applyDragMove(event: Event, deltaMinutes: Int, vm: CalendarViewModel) {
        guard deltaMinutes != 0 else { return }
        let interval = TimeInterval(deltaMinutes * 60)
        let newStart = event.start.addingTimeInterval(interval)
        let newEnd = event.end.addingTimeInterval(interval)
        vm.moveEvent(event, newStart: newStart, newEnd: newEnd)
    }

    /// 事件卡 contextMenu 内容：Edit / Mark|Unmark attended（仅已结束事件）/ Delete。
    /// 「标记已出席」仅对已结束事件（end <= vm.now）出现；已确认则翻转为「取消已出席」。
    @ViewBuilder
    private func eventActions(for event: Event, vm: CalendarViewModel) -> some View {
        Button { openEdit(event) } label: {
            Text(LJStrings.eventEdit)
        }
        if event.end <= vm.now {
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

    /// W3：消费 router.pendingEventDate —— 把 CalendarViewModel 定位到该天后清回 nil。
    /// pendingEventID 预留高亮，本期 CalendarViewModel 无承载字段，不做高亮（仅定位那天）。
    private func consumePendingEventDate(_ date: Date?) {
        guard let date, let vm else { return }
        vm.focus(on: date)
        router.pendingEventDate = nil
        router.pendingEventID = nil
    }

    /// 构造 CalendarViewModel 并注入当前 service 引用 + W2 的 yesterdayMissed 显示开关。
    private func makeVM() -> CalendarViewModel {
        let model = CalendarViewModel(
            context: modelContext,
            yesterdayMissedService: services.yesterdayMissed
        )
        model.showYesterdayMissed = settings.yesterdayMissedReminderEnabled
        return model
    }

    // MARK: - Top-level layout

    @ViewBuilder
    private func content(vm: CalendarViewModel) -> some View {
        // header 用 VStack 正常宽度（= 窗口宽），**不进 GeometryReader**——这是「新建事件」按钮
        // 跑出窗口的根因：header 在 GeometryReader 内会用 geo.width，而该 GeometryReader 拿到的
        // 宽度比可见窗口大（header 填满它就溢出右边）。Main/Personal 的 header 都在普通容器里，所以正常。
        // 仅网格主体进 GeometryReader 拿列宽。RootWindow 的 ZStack 已是 .topLeading、星期表头 Color.clear
        // 已限高，header 移出后不会再有居中/空白问题。
        // P6 响应式：≥1100pt 7 列等分；<1100pt 每列 130pt 横向 scroll；<900pt 3-day。
        VStack(alignment: .leading, spacing: 0) {
            header(vm: vm)
                .padding(.horizontal, LJSpacing.s28)
                .padding(.top, LJSpacing.s22)
                .padding(.bottom, LJSpacing.s16)

            GeometryReader { geo in
                let useThreeDay = geo.size.width < 900
                let needsHorizontalScroll = !useThreeDay && geo.size.width < 1100

                let visibleDays: [Date] = useThreeDay
                    ? threeDayWindow(vm: vm)
                    : vm.weekDays

                // v1.3 R4：标准布局下网格在玻璃面板内 —— 可用宽 = 窗口宽 - 外边距(s28×2)
                // - 面板内边距(s18×2) - 时间 gutter。横向 scroll 模式仍用窗口宽减外边距。
                let outerH = LJSpacing.s28 * 2
                let panelInner = needsHorizontalScroll ? 0 : LJSpacing.s18 * 2
                let availableWidth = geo.size.width - outerH - panelInner - timeColumnWidth
                let evenColumnWidth = max(40, availableWidth / CGFloat(visibleDays.count))
                let columnWidth: CGFloat = needsHorizontalScroll ? 130 : evenColumnWidth

                VStack(alignment: .leading, spacing: 0) {
                    if needsHorizontalScroll {
                        scrollableWeekGrid(vm: vm, visibleDays: visibleDays, columnWidth: columnWidth)
                    } else {
                        // v1.3 R4（对原型重建）：周网格整体 = 容器玻璃面板（圆角 18 + hairline + 顶高光 + 柔投影）。
                        // 内部仍是「表头行 + 0.5px 分隔 + 滚动网格」结构（保留三坑防护：Color.clear 限高 /
                        // GeometryReader 测宽 / ZStack .topLeading）。面板自带 s18 边距，故内部网格 padding 收窄。
                        VStack(alignment: .leading, spacing: 0) {
                            // 星期表头行：紧贴面板顶部。
                            weekdayHeaderRow(vm: vm, visibleDays: visibleDays, columnWidth: columnWidth)
                                .padding(.top, LJSpacing.s4)
                                .padding(.bottom, LJSpacing.s8)

                            Rectangle().fill(Color.lj.border).frame(height: 0.5)

                            // ScrollView 吃剩余高度；weekGrid 顶对齐，多余高度落 9PM 之后（网格底部）。
                            ScrollView(.vertical, showsIndicators: true) {
                                weekGrid(vm: vm, visibleDays: visibleDays, columnWidth: columnWidth)
                                    .padding(.top, LJSpacing.s8)
                                    .padding(.bottom, LJSpacing.s8)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(LJSpacing.s18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .ljGlassPanel(radius: LJRadii.panel, padded: false)
                        .padding(.horizontal, LJSpacing.s28)
                        .padding(.bottom, LJSpacing.s22)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // v1.3 R4：背景透明 —— 让 RootWindow 底色 + orb 透上来，周网格玻璃面板浮起。
    }

    /// < 1100pt：横向 ScrollView 包整组日列；时间标签列保持在最左（不滚），
    /// 通过把它放在外层 HStack 里实现「sticky 周一列」效果（README 要求最左列 sticky）。
    @ViewBuilder
    private func scrollableWeekGrid(
        vm: CalendarViewModel,
        visibleDays: [Date],
        columnWidth: CGFloat
    ) -> some View {
        let totalHeight: CGFloat = CGFloat(hoursVisible) * pxPerHour

        VStack(spacing: 0) {
            // 周表头横向滚动 —— 时间列占位让出对齐空间。
            HStack(spacing: 0) {
                Color.clear.frame(width: timeColumnWidth, height: 1)   // 限高防纵向贪婪
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(visibleDays, id: \.self) { dayStart in
                            weekdayHeaderCell(vm: vm, dayStart: dayStart, columnWidth: columnWidth)
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, LJSpacing.s28)
            .padding(.trailing, LJSpacing.s28)
            .padding(.top, LJSpacing.s6)
            .padding(.bottom, LJSpacing.s8)

            Rectangle().fill(Color.lj.border).frame(height: 0.5)

            // 主体网格：纵向 scroll 套横向 scroll；左 52pt 时间列锁定。
            // 纵向 ScrollView 贪婪吃剩余高度（top-align），网格顶对齐，多余空间留底部。
            ScrollView(.vertical, showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    timeLabelColumn(totalHeight: totalHeight)
                        .frame(width: timeColumnWidth, height: totalHeight, alignment: .topLeading)
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(visibleDays, id: \.self) { dayStart in
                                dayColumn(
                                    vm: vm,
                                    dayStart: dayStart,
                                    columnWidth: columnWidth,
                                    totalHeight: totalHeight
                                )
                            }
                        }
                    }
                }
                .padding(.leading, LJSpacing.s28)
                .padding(.trailing, LJSpacing.s28)
                .padding(.top, LJSpacing.s8)
                .padding(.bottom, LJSpacing.s16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// < 900pt：取 today + 前后各一天，凑成 3-day 窗口。
    /// 如果今天不在当前 vm.weekDays 内（用户切到了非本周），fallback 到 weekDays 前 3 项。
    private func threeDayWindow(vm: CalendarViewModel) -> [Date] {
        let cal = CalendarViewModel.calendar
        let allDays = vm.weekDays
        guard let todayIdx = allDays.firstIndex(where: { cal.isDate($0, inSameDayAs: vm.todayStart) }) else {
            return Array(allDays.prefix(3))
        }
        let lo = max(0, todayIdx - 1)
        let hi = min(allDays.count - 1, lo + 2)
        let start = max(0, hi - 2)
        return Array(allDays[start...hi])
    }

    // MARK: - Header

    @ViewBuilder
    private func header(vm: CalendarViewModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LJStrings.tabCalendar).ljDisplayTitleStyle()
                countsLine(total: vm.weekTotal)
            }
            Spacer()
            weekNav(vm: vm)
            Spacer().frame(width: LJSpacing.s12)
            newEventButton()
        }
    }

    /// "X events · next 7 days" —— 整段走 Counts.eventsNext7Days（含 %d 占位），
    /// 中文 "未来 7 天 N 场事件" 语序与英文不同，因此放弃 raw 拼接的两色数字方案，
    /// 整段统一字色 inkSoft，颜色对比由 .semibold 权重承载。
    @ViewBuilder
    private func countsLine(total: Int) -> some View {
        Text(LJStrings.countsEventsNext7Days(total))
            .font(.system(size: 12.5, weight: .medium, design: .default))
            .foregroundStyle(Color.lj.inkSoft)
    }

    /// 中部：‹  May 27 — Jun 2  ›  + Today 按钮。
    @ViewBuilder
    private func weekNav(vm: CalendarViewModel) -> some View {
        HStack(spacing: 6) {
            Button { vm.goPrevWeek() } label: {
                navIconLabel("‹")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LJStrings.previousWeek))

            Text(weekRangeText(vm: vm))
                .font(.system(size: 12.5, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.ink)
                .frame(minWidth: 124, alignment: .center)

            Button { vm.goNextWeek() } label: {
                navIconLabel("›")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LJStrings.nextWeek))

            Button { vm.goToday() } label: {
                Text(LJStrings.today)
                    .font(.system(size: 12.5, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                    .padding(.horizontal, LJSpacing.s14)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.lj.border, lineWidth: 0.5)
                    )
                    .overlay { LJTopHighlight(radius: 10) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LJStrings.jumpToday))
        }
    }

    /// v1.3 R4（对原型重建）：周区间左右 nav 箭头 —— 26pt 玻璃方块（材质 + hairline + 顶高光，圆角 8）。
    @ViewBuilder
    private func navIconLabel(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: 14, weight: .medium, design: .default))
            .foregroundStyle(Color.lj.inkSoft)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            )
            .overlay { LJTopHighlight(radius: 8) }
    }

    /// v1.3 R4（对原型重建）：`+新建日程` 品牌渐变主按钮（原型 macOS 日历页头部）。
    @ViewBuilder
    private func newEventButton() -> some View {
        LJPrimaryButton(LJStrings.newEventTitle, systemImage: "plus") {
            router.quickAddDefaultKind = .event
            router.showQuickAdd = true
        }
        .accessibilityLabel(Text(LJStrings.newEventAcc))
    }

    /// `May 27 — Jun 2` 这种 range 字符串。本地化短月份名。
    private func weekRangeText(vm: CalendarViewModel) -> String {
        let cal = CalendarViewModel.calendar
        guard let last = cal.date(byAdding: .day, value: 6, to: vm.weekStart) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: vm.weekStart)) — \(f.string(from: last))"
    }

    // MARK: - Weekday header row

    /// 标准布局（≥ 1100pt）下的表头行：时间列占位 + 等分铺满的 visibleDays。
    @ViewBuilder
    private func weekdayHeaderRow(vm: CalendarViewModel, visibleDays: [Date], columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            // 时间列占位（与下方网格对齐）。⚠️ 必须限高：Color.clear 默认纵向无限贪婪，
            // 不限高会把整个 HStack 撑到吃满剩余空间（曾导致星期表头行高 ~500pt、标签被居中夹空白）。
            Color.clear.frame(width: timeColumnWidth, height: 1)
            ForEach(visibleDays, id: \.self) { dayStart in
                weekdayHeaderCell(vm: vm, dayStart: dayStart, columnWidth: columnWidth)
            }
        }
        // 行高由 weekdayHeaderCell 的固有高度决定，绝不纵向膨胀。
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 单日表头单元，复用给标准布局与横向 scroll 模式。
    @ViewBuilder
    private func weekdayHeaderCell(vm: CalendarViewModel, dayStart: Date, columnWidth: CGFloat) -> some View {
        let isToday = CalendarViewModel.calendar.isDate(dayStart, inSameDayAs: vm.todayStart)
        let isWeekend = CalendarViewModel.calendar.isDateInWeekend(dayStart)
        // v1.3 R4（对原型重建）：今日表头 = 紫（accentDeep #5B5BD6）；周末 = inkMute；平日 = ink。
        let headColor: Color = isToday ? Color.lj.accentDeep : (isWeekend ? Color.lj.inkMute : Color.lj.ink)
        VStack(alignment: .leading, spacing: 2) {
            // today 列顶部小标签显示本地化 "TODAY" / "今天"；其余日显示周缩写（MON/TUE…）。
            Text(isToday
                 ? String(localized: LJStrings.calendarTodayUpper)
                 : weekdayShortLabel(for: dayStart))
                .font(.system(size: 10.5, weight: .semibold, design: .default))
                .kerning(0.63)
                .textCase(.uppercase)
                .foregroundStyle(isToday ? Color.lj.accentDeep : Color.lj.inkMute)
            HStack(spacing: 6) {
                Text(dayNumber(for: dayStart))
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .kerning(-0.4)
                    .foregroundStyle(headColor)
                if isToday {
                    Circle()
                        .fill(Color.lj.accentDeep)
                        .frame(width: 5, height: 5)
                }
            }
        }
        // ⚠️ padding 必须在 frame 内侧：若 .padding 在 .frame 外，单元实宽 = columnWidth + 8，
        // 而下方网格列宽 = columnWidth → 表头日期号逐列右漂 8pt（today 列 0、末列 +48pt，对不准网格列）。
        // 先 padding 再 frame：标签在 columnWidth 内左缩 8pt，单元实宽严格 = columnWidth，与网格对齐。
        .padding(.leading, 8)
        .frame(width: columnWidth, alignment: .leading)
    }

    // MARK: - Week grid

    @ViewBuilder
    private func weekGrid(vm: CalendarViewModel, visibleDays: [Date], columnWidth: CGFloat) -> some View {
        // 14 小时 * 46pt = 644pt
        let totalHeight: CGFloat = CGFloat(hoursVisible) * pxPerHour

        // topLeading：网格本身贴左上，绝不被 ZStack 居中（否则整张网格会在容器里漂移）。
        ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 0) {
                // 左侧时间标签列
                timeLabelColumn(totalHeight: totalHeight)
                    .frame(width: timeColumnWidth, height: totalHeight, alignment: .topLeading)

                // 日列（数量由 visibleDays 决定 —— 标准 7 / 3-day 模式 3）
                ForEach(visibleDays, id: \.self) { dayStart in
                    dayColumn(
                        vm: vm,
                        dayStart: dayStart,
                        columnWidth: columnWidth,
                        totalHeight: totalHeight
                    )
                }
            }

            // P5：整周无事件 → EmptyState(.clearWeek) 居中显示在 grid 区域内。
            // 单独用 frame 把 EmptyState 在整网格区内居中，不让它把整张 ZStack 改成居中。
            if vm.weekTotal == 0 {
                EmptyState(variant: .clearWeek, ctaTitle: LJStrings.emptyClearWeekCTA) {
                    router.quickAddDefaultKind = .event
                    router.showQuickAdd = true
                }
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity, maxHeight: totalHeight, alignment: .center)
            }
        }
    }

    /// 左侧 52pt 时间标签列。
    /// 用 `.alignmentGuide` 把每个小时标签的「顶端」对齐到该小时线（再下移约 6pt 内边距），
    /// 取代之前 `.position(y:)` 把标签中心压在 y=0 导致 7AM 顶部被裁的问题。
    @ViewBuilder
    private func timeLabelColumn(totalHeight: CGFloat) -> some View {
        // 标签顶端相对小时线下移的内边距，保证第一个 7AM 标签完整可见。
        let labelTopInset: CGFloat = 6
        ZStack(alignment: .topLeading) {
            // 透明背景占位高度
            Color.clear.frame(height: totalHeight)
            ForEach(0...hoursVisible, id: \.self) { i in
                let h = startHour + i
                let displayHour = h > 12 ? h - 12 : h
                let ampm = h >= 12 ? "PM" : "AM"
                Text("\(displayHour) \(ampm)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .kerning(-0.2)
                    .foregroundStyle(Color.lj.inkMute)
                    // 标签顶端贴在小时线下方 labelTopInset 处（topLeading 对齐基准）。
                    .padding(.leading, LJSpacing.s6)
                    .offset(x: 0, y: CGFloat(i) * pxPerHour + labelTopInset)
            }
        }
    }

    /// 单日列：横向分隔 + today 背景 + events + now 线。
    @ViewBuilder
    private func dayColumn(
        vm: CalendarViewModel,
        dayStart: Date,
        columnWidth: CGFloat,
        totalHeight: CGFloat
    ) -> some View {
        let isToday = CalendarViewModel.calendar.isDate(dayStart, inSameDayAs: vm.todayStart)
        let dayEvents = vm.eventsByDay[dayStart] ?? []
        // U5：该天重叠列分配。每渲染一天调一次，事件卡按所属簇的列序号 / 列数等分列宽。
        let overlap = vm.overlapLayout(forDay: dayStart)

        ZStack(alignment: .topLeading) {
            // 整列左边线
            Rectangle()
                .fill(Color.lj.border)
                .frame(width: 0.5, height: totalHeight)

            // v1.3 R4（对原型重建）：today 列浅紫高亮（原型 colBg rgba(110,110,230,0.05)）。
            if isToday {
                Color.lj.navSelected.opacity(0.4)
                    .frame(width: columnWidth, height: totalHeight)
            }

            // 横向小时分隔线
            ForEach(0...hoursVisible, id: \.self) { i in
                Rectangle()
                    .fill(Color.lj.border)
                    .frame(width: columnWidth, height: 0.5)
                    .offset(x: 0, y: CGFloat(i) * pxPerHour)
            }

            // events：绝对定位。W4：外层套 onTap（打开编辑）+ contextMenu（Edit/Mark/Delete）。
            // U5：重叠事件按 overlap map 的 column / columnCount 等分列宽并排；不重叠仍满列宽。
            // U7：每张卡抽成 DraggableEventCard（自带拖拽预览 @State + DragGesture），
            // 拖动上下平移改期（保持时长，吸附 15 分钟）；轻点仍走 openEdit、右键仍出 contextMenu。
            ForEach(dayEvents, id: \.id) { event in
                let slot = overlap[event.id] ?? (column: 0, columnCount: 1)
                if let layout = eventLayout(
                    event: event,
                    columnWidth: columnWidth,
                    column: slot.column,
                    columnCount: slot.columnCount
                ) {
                    DraggableEventCard(
                        event: event,
                        layout: layout,
                        pxPerHour: pxPerHour,
                        onTap: { openEdit(event) },
                        onMove: { deltaMinutes in
                            applyDragMove(event: event, deltaMinutes: deltaMinutes, vm: vm)
                        },
                        contextMenuContent: { AnyView(eventActions(for: event, vm: vm)) }
                    )
                }
            }

            // now 横线（仅 today 列 + 现在落在 7AM..9PM 范围内）
            if isToday, let nowY = nowLineY() {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.lj.ink)
                        .frame(width: columnWidth, height: 1)
                    Circle()
                        .fill(Color.lj.ink)
                        .frame(width: 7, height: 7)
                        .offset(x: -3, y: 0)
                }
                .offset(x: 0, y: nowY)
                .zIndex(3)
            }
        }
        .frame(width: columnWidth, height: totalHeight, alignment: .topLeading)
        .clipped()
    }

    /// 给定一个 event 算出在日列中的位置 + 尺寸。返回 nil 表示落在可视范围之外。
    /// U5：`column` / `columnCount` 为该事件在所属重叠簇内的列序号（0-based）与簇总列数。
    /// 不重叠事件 `columnCount == 1` → 仍满列宽（行为同旧）。MVP 等宽，不做向右扩展吃空列。
    private func eventLayout(
        event: Event,
        columnWidth: CGFloat,
        column: Int,
        columnCount: Int
    ) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)? {
        let cal = CalendarViewModel.calendar
        let startComps = cal.dateComponents([.hour, .minute], from: event.start)
        let endComps = cal.dateComponents([.hour, .minute], from: event.end)
        let startH = Double(startComps.hour ?? 0) + Double(startComps.minute ?? 0) / 60.0
        let endH = Double(endComps.hour ?? 0) + Double(endComps.minute ?? 0) / 60.0

        // 完全早于 7AM 或完全晚于 9PM → 不渲染。
        // 部分溢出则 clamp 到边界。
        if endH <= Double(startHour) || startH >= Double(endHour) { return nil }
        let clampedStart = max(startH, Double(startHour))
        let clampedEnd = min(endH, Double(endHour))
        let topY = CGFloat(clampedStart - Double(startHour)) * pxPerHour + 2
        let height = CGFloat(clampedEnd - clampedStart) * pxPerHour - 4
        // U5：列宽等分。可用宽度 = columnWidth - 8（左右各 4pt 边距），按 columnCount 等分；
        // 每列再减 2pt 列间隙。column==0/columnCount==1 时回到旧的「满列宽」行为。
        let safeColumnCount = max(1, columnCount)
        let laneWidth = (columnWidth - 8) / CGFloat(safeColumnCount)
        let x = 4 + CGFloat(column) * laneWidth
        let width = laneWidth - 2
        return (x: x, y: topY, width: max(20, width), height: max(20, height))
    }

    /// now 线的 Y 坐标。落在 7AM..9PM 范围外时返回 nil（不画线）。
    private func nowLineY() -> CGFloat? {
        let cal = CalendarViewModel.calendar
        let comps = cal.dateComponents([.hour, .minute], from: nowMinuteTick)
        let nowH = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
        guard nowH >= Double(startHour), nowH <= Double(endHour) else { return nil }
        return CGFloat(nowH - Double(startHour)) * pxPerHour
    }

    // MARK: - Date helpers

    /// "MON" / "TUE" / ... 周缩写。
    private func weekdayShortLabel(for day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: day).uppercased()
    }

    /// "26" / "27" 等单纯日期数字。
    private func dayNumber(for day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: day)
    }

    // MARK: - now Timer lifecycle

    /// 启动每分钟刷新 nowMinuteTick 的 Timer。重复 schedule 时旧的先 invalidate。
    /// 不强引 self（Timer 用 weak 引用即可；但因为这是 SwiftUI View struct + @State，
    /// 直接在 closure 内对 @State 赋值是安全的）。
    private func startNowTimer() {
        nowTimer?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: true) { _ in
            // SwiftUI View struct 是 value，@State 内部是 reference，这里读 / 写都没问题。
            Task { @MainActor in
                nowMinuteTick = LinoJTime.now()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        nowTimer = timer
        // 立即同步一次，避免等满 60s 后才更新一次。
        nowMinuteTick = LinoJTime.now()
    }

    /// 停掉 Timer，避免 View 离开后还持续 tick（防止 Timer leak）。
    private func stopNowTimer() {
        nowTimer?.invalidate()
        nowTimer = nil
    }
}

// MARK: - U7 可拖拽事件卡（拖拽改期）

/// U7：单张周视图事件卡，封装拖拽改期手势 + 预览偏移。
///
/// 抽成独立 struct 的原因（见 CLAUDE.md）：拖拽手势 + 绝对定位 + 预览偏移叠在
/// dayColumn 的 ForEach 长链里极易触发 Swift「unable to type-check this expression in
/// reasonable time」；把单卡逻辑与本地 `@State` 提出来后 dayColumn body 恢复简单。
///
/// 点击/拖拽消歧（决策定死）：`DragGesture(minimumDistance: 4)` + `.highPriorityGesture`——
///   - 拖动距离 < 4pt：drag 不触发，`.onTapGesture` 正常打开编辑（W4）。
///   - 拖动距离 ≥ 4pt：highPriority 的 drag 抢占，进入拖拽预览；松手按 Δy 改期。
/// 右键 `.contextMenu` 与 tap / drag 并存（contextMenu 走右键，不与左键 drag 冲突）。
///
/// 吸附：onEnded 时 Δy → Δ分钟 = `Δy / pxPerHour * 60`，round 到最近 15 分钟刻度
/// （15min = 11.5pt @ pxPerHour 46）。MVP 仅上下平移（保持时长）；跨天为可选未做。
private struct DraggableEventCard: View {
    let event: Event
    let layout: (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    let pxPerHour: CGFloat
    let onTap: () -> Void
    /// 传入「已吸附到 15 分钟刻度」的 Δ分钟（正=往后/下，负=往前/上）。
    let onMove: (Int) -> Void
    let contextMenuContent: () -> AnyView

    /// 拖拽中的临时纵向偏移（仅视觉预览，不每帧 save）。松手清零。
    @State private var dragOffsetY: CGFloat = 0
    /// 是否正在拖拽（拖拽中略提亮卡片，给手感反馈）。
    @State private var isDragging = false

    var body: some View {
        EventCard(event: event, variant: .macWeekGrid)
            .frame(width: layout.width, height: layout.height)
            .contentShape(Rectangle())
            .opacity(isDragging ? 0.85 : 1)
            .zIndex(isDragging ? 5 : 0)
            .onTapGesture { onTap() }
            .highPriorityGesture(dragGesture)
            .contextMenu { contextMenuContent() }
            .offset(x: layout.x, y: layout.y + dragOffsetY)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                isDragging = true
                dragOffsetY = value.translation.height
            }
            .onEnded { value in
                let deltaMinutes = snappedDeltaMinutes(forY: value.translation.height)
                // 先清预览偏移，再写回——写回后 VM refresh，layout.y 落到新位置（无回弹闪烁）。
                dragOffsetY = 0
                isDragging = false
                onMove(deltaMinutes)
            }
    }

    /// Δy（pt）→ Δ分钟，吸附到最近 15 分钟刻度。
    private func snappedDeltaMinutes(forY deltaY: CGFloat) -> Int {
        let rawMinutes = Double(deltaY) / Double(pxPerHour) * 60.0
        let snapped = (rawMinutes / 15.0).rounded() * 15.0
        return Int(snapped)
    }
}

// MARK: - W4 删除事件确认对话框 modifier

/// 把 `.confirmationDialog` 抽成独立 modifier —— 直接挂在 CalendarView_macOS 的 body 长链上易触发
/// Swift「unable to type-check this expression in reasonable time」。抽出后 body 链恢复简单。
private struct CalendarEventDeleteConfirmModifier: ViewModifier {
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
