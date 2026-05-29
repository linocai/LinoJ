// CalendarView_iOS.swift
// Calendar tab 的 iOS 实现 —— Plan P3.4：
//
//   - 顶部 padding（让出 FloatingActions）+ "Calendar" 34pt + 副标 "X events this week"
//   - 单行 nav ‹ / ›（中间显示 week range）+ Today 按钮
//   - 横向 7-day strip（每天一个 pill，等宽 / 48pt 高）；today pill 上方加 "Today" 小 label
//   - 单日 list：垂直堆叠 iosFull EventCard
//   - 看 today 时底部加 "From yesterday" 灰底 box（每行 checkbox 调 vm.confirmAttended）
//   - 底部 padding 100pt 让出 tab bar
//
// 数据模式：照搬 PersonalView_iOS / MainView_iOS：
//   - @Environment(\.modelContext) + @Query(Event) 触发 invalidation
//   - @State 持 CalendarViewModel；.task 初始化；.onChange 触发 vm.refresh()

import SwiftUI
import SwiftData
import LinoJCore

struct CalendarView_iOS: View {

    @Environment(\.modelContext) private var modelContext

    /// P4：从 RootTabView 注入的 service 容器（提供 YesterdayMissedService）。
    @Environment(AppServices.self) private var services

    /// I4：从环境拿 router，用于 EmptyState CTA 打开 Quick Add（kind=.event）。
    @Environment(TabRouter.self) private var router

    @Query private var events: [Event]

    @State private var vm: CalendarViewModel?

    /// W2：本屏自有 SettingsViewModel，用于读 `yesterdayMissedReminderEnabled` 注入到
    /// CalendarViewModel（gate「From yesterday」box 显示）。
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
            consumePendingEventDate(router.pendingEventDate)
        }
        // W4：删除事件确认对话框（iOS）。抽成单独 modifier 减轻 body 类型检查负担。
        .modifier(CalendarEventDeleteConfirmModifier_iOS(
            pending: $eventPendingDelete,
            onConfirm: { vm?.deleteEvent($0) }
        ))
    }

    /// W3：消费 router.pendingEventDate —— 把 CalendarViewModel 定位到该天后清回 nil。
    /// pendingEventID 预留高亮，本期 CalendarViewModel 无承载字段，不做高亮（仅定位那天）。
    private func consumePendingEventDate(_ date: Date?) {
        guard let date, let vm else { return }
        vm.focus(on: date)
        router.pendingEventDate = nil
        router.pendingEventID = nil
    }

    // MARK: - W4 事件操作（onTap 编辑 / contextMenu）

    /// 打开事件编辑：设 router 信号让 Quick Add sheet 以 event edit 模式打开。
    private func openEdit(_ event: Event) {
        router.quickAddEditingEvent = event
        router.showQuickAdd = true
    }

    /// 事件卡 contextMenu（长按菜单）：Edit / Mark|Unmark attended（仅已结束事件）/ Delete。
    /// 「标记已出席」仅对已结束事件（end <= vm.now）出现；已确认则翻转为「取消已出席」。
    @ViewBuilder
    private func eventActions(for event: Event, vm: CalendarViewModel) -> some View {
        Button { openEdit(event) } label: {
            Label { Text(LJStrings.eventEdit) } icon: { Image(systemName: "pencil") }
        }
        if event.end <= vm.now {
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

    /// 构造 CalendarViewModel 并注入当前 service 引用 + W2 的 yesterdayMissed 显示开关。
    private func makeVM() -> CalendarViewModel {
        let model = CalendarViewModel(
            context: modelContext,
            yesterdayMissedService: services.yesterdayMissed
        )
        model.showYesterdayMissed = settings.yesterdayMissedReminderEnabled
        return model
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(vm: CalendarViewModel) -> some View {
        ZStack {
            Color.lj.iosMainBg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero header（让出 FloatingActions）
                    header(vm: vm)
                        .padding(.top, 64)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    // 周 nav 行
                    weekNavRow(vm: vm)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)

                    // 7-day strip
                    weekStrip(vm: vm)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 18)

                    // 单日 list 标题（"Today" / "Tomorrow" / weekday, May d）
                    dayHeader(vm: vm)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    // 整周无事件 → EmptyState(.clearWeek)，chrome（7-day strip / dayHeader）保留可见。
                    // 单日有事件时走 dayEvents 正常 list；单日无但整周有事件时仍走 dayEvents（显示
                    // "Nothing on the books." 短句，不替换为整周 empty state）。
                    if vm.weekTotal == 0 {
                        // I4: CTA 打开 Quick Add，预选 .event。
                        EmptyState(
                            variant: .clearWeek,
                            ctaTitle: LJStrings.emptyClearWeekCTA,
                            action: {
                                router.quickAddDefaultKind = .event
                                router.showQuickAdd = true
                            }
                        )
                            .padding(.horizontal, 16)
                            .padding(.top, 32)
                    } else {
                        dayEvents(vm: vm)
                            .padding(.horizontal, 16)
                    }

                    // 看 today 时显示 "From yesterday"
                    let selectedIsToday = CalendarViewModel.calendar
                        .isDate(vm.selectedDay, inSameDayAs: vm.todayStart)
                    if selectedIsToday, !vm.yesterdayMissed.isEmpty {
                        yesterdayBox(vm: vm)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    }

                    // 让出 tab bar
                    Color.clear.frame(height: 110)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(vm: CalendarViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LJStrings.tabCalendar).ljDisplayTitleStyle()
            Text(LJStrings.countsEventsNext7Days(vm.weekTotal))
                .font(.system(size: 13.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
        }
    }

    // MARK: - Week nav

    @ViewBuilder
    private func weekNavRow(vm: CalendarViewModel) -> some View {
        HStack(spacing: 8) {
            Button { vm.goPrevWeek() } label: {
                navChevron("chevron.left")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LJStrings.previousWeek))

            Text(weekRangeText(vm: vm))
                .font(.system(size: 13.5, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.ink)
                .frame(maxWidth: .infinity, alignment: .center)

            Button { vm.goNextWeek() } label: {
                navChevron("chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LJStrings.nextWeek))

            Button { vm.goToday() } label: {
                // I6: 视觉保留 30pt 高 chip，触摸区扩大到 44pt（HIG）。
                Text(LJStrings.today)
                    .font(.system(size: 12.5, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.lj.border, lineWidth: 0.5)
                    )
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LJStrings.jumpToday))
        }
    }

    @ViewBuilder
    private func navChevron(_ name: String) -> some View {
        // I6: 视觉 30pt 圆角方框，但触摸区扩大到 44pt（HIG 最小 hit target）。
        // 用 contentShape 让 button 接收整个 44pt 内的点击。
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.lj.inkSoft)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            )
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    private func weekRangeText(vm: CalendarViewModel) -> String {
        let cal = CalendarViewModel.calendar
        guard let last = cal.date(byAdding: .day, value: 6, to: vm.weekStart) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: vm.weekStart)) — \(f.string(from: last))"
    }

    // MARK: - 7-day strip

    @ViewBuilder
    private func weekStrip(vm: CalendarViewModel) -> some View {
        HStack(spacing: 6) {
            ForEach(vm.weekDays, id: \.self) { day in
                dayPill(day: day, vm: vm)
            }
        }
    }

    @ViewBuilder
    private func dayPill(day: Date, vm: CalendarViewModel) -> some View {
        let cal = CalendarViewModel.calendar
        let isSelected = cal.isDate(vm.selectedDay, inSameDayAs: day)
        let isToday = cal.isDate(day, inSameDayAs: vm.todayStart)
        let count = vm.eventsByDay[day]?.count ?? 0

        Button {
            vm.selectDay(day)
        } label: {
            VStack(spacing: 2) {
                Text(isToday
                     ? String(localized: LJStrings.today)
                     : weekdayShortLabel(for: day))
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .kerning(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(isSelected ? Color.lj.panel.opacity(0.75) : Color.lj.inkMute)
                Text(dayNumber(for: day))
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .kerning(-0.36)
                    .foregroundStyle(isSelected ? Color.lj.panel : Color.lj.ink)
                // 占位 dot：有事件时显示，确保所有 pill 高度一致。
                Circle()
                    .fill(count > 0 ? (isSelected ? Color.lj.panel.opacity(0.8) : Color.lj.ink) : Color.clear)
                    .frame(width: 4, height: 4)
                    .padding(.top, 1)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.lj.ink : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.lj.ink : Color.lj.border, lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day header

    @ViewBuilder
    private func dayHeader(vm: CalendarViewModel) -> some View {
        let cal = CalendarViewModel.calendar
        let isToday = cal.isDate(vm.selectedDay, inSameDayAs: vm.todayStart)
        let isTomorrow: Bool = {
            if let tomorrow = cal.date(byAdding: .day, value: 1, to: vm.todayStart) {
                return cal.isDate(vm.selectedDay, inSameDayAs: tomorrow)
            }
            return false
        }()
        let title: String = {
            if isToday { return String(localized: LJStrings.today) }
            if isTomorrow { return String(localized: LJStrings.tomorrow) }
            let f = DateFormatter()
            f.locale = .current
            f.setLocalizedDateFormatFromTemplate("EEE, MMM d")
            return f.string(from: vm.selectedDay)
        }()
        let count = vm.eventsByDay[vm.selectedDay]?.count ?? 0

        HStack(alignment: .lastTextBaseline, spacing: 10) {
            Text(verbatim: title)
                .font(.system(size: 17, weight: .bold, design: .default))
                .kerning(-0.26)
                .foregroundStyle(Color.lj.ink)
            Text(
                count == 1
                    ? String(localized: "Counts.eventCount.one",
                             defaultValue: "1 event",
                             bundle: LinoJCoreBundle.bundle)
                    : String(localized: "Counts.eventsCount",
                             defaultValue: "\(count) events",
                             bundle: LinoJCoreBundle.bundle)
            )
                .font(.system(size: 12.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkMute)
            Spacer()
        }
    }

    // MARK: - Day events list

    @ViewBuilder
    private func dayEvents(vm: CalendarViewModel) -> some View {
        let dayEvents = vm.eventsByDay[vm.selectedDay] ?? []
        VStack(spacing: 10) {
            if dayEvents.isEmpty {
                Text(LJStrings.nothingOnBooksDot)
                    .font(.system(size: 13.5, weight: .medium, design: .default))
                    .italic()
                    .foregroundStyle(Color.lj.inkDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(dayEvents, id: \.id) { event in
                    // W4：外层套 onTap（打开编辑）+ contextMenu（长按：Edit/Mark/Delete）。
                    EventCard(event: event, variant: .iosFull)
                        .contentShape(Rectangle())
                        .onTapGesture { openEdit(event) }
                        .contextMenu { eventActions(for: event, vm: vm) }
                }
            }
        }
    }

    // MARK: - From yesterday box

    @ViewBuilder
    private func yesterdayBox(vm: CalendarViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(LJStrings.fromYesterday)
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .kerning(0.88)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
                Text(LJStrings.tapToConfirm)
                    .font(.system(size: 10.5, weight: .medium, design: .default))
                    .italic()
                    .foregroundStyle(Color.lj.inkMute)
            }
            VStack(spacing: 6) {
                ForEach(vm.yesterdayMissed, id: \.id) { event in
                    Button {
                        vm.confirmAttended(event)
                    } label: {
                        yesterdayRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.lj.chip)
        }
    }

    @ViewBuilder
    private func yesterdayRow(event: Event) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Checkbox 占位（点击整行即 confirm；勾选后 vm 把 attendedConfirmed=true，
            // 整条事件下次就不在 vm.yesterdayMissed 里了，所以这里 done 状态恒为 false）。
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Color.lj.inkMute, lineWidth: 1.4)
                .frame(width: 14, height: 14)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                Text("\(timeText(event.start)) · \(event.location)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.lj.inkMute)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Date helpers

    private func weekdayShortLabel(for day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: day).uppercased()
    }

    private func dayNumber(for day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: day)
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - W4 删除事件确认对话框 modifier（iOS）

/// 把 `.confirmationDialog` 抽成独立 modifier —— 直接挂在 CalendarView_iOS 的 body 长链上易触发
/// Swift「unable to type-check this expression in reasonable time」。抽出后 body 链恢复简单。
private struct CalendarEventDeleteConfirmModifier_iOS: ViewModifier {
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
