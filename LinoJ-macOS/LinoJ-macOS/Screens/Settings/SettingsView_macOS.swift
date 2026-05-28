// SettingsView_macOS.swift
// macOS Settings sheet —— plan P3.8 范围。
//
// 入口：⌘, → router.showSettings = true → RootWindow 的 `.sheet`。
//
// 视觉决策（依据 design_handoff_linoj/macos-settings.jsx）：
//   - 760×540 sheet（与 QuickAdd/Search 用同一 `.sheet` 思路，不做自定义 NSWindow）。
//   - 左侧 188pt sidebar：5 个 section（General / Notifications / Sync / Shortcuts / About），
//     bgSoft 背景，选中项 chip 填充。
//   - 右侧 ScrollView：按 section 切换内容；每行 plan-spec 的 label + hint + control。
//   - Appearance 行 plan 明文：「System」 + mono kbd "locked" badge + 副标，整行只读，
//     不做 light/dark toggle —— 严格跟随系统设置。
//
// 设置持久化：所有 Toggle/Picker/Stepper 直接绑 `vm.<field>`，VM 的 didSet 自动 persist。
// VM 用 router.showSettings 的生命周期一致：onAppear 创建，sheet dismiss 时 SwiftUI 自动释放。

import SwiftUI
import AuthenticationServices
import LinoJCore

struct SettingsView_macOS: View {

    @Environment(\.dismiss) private var dismiss

    /// V1：App 级 service 容器，用来取 CloudSyncMonitor 注入到本 view 的 vm 驱动 Last-synced pill。
    /// V3：同时取 AppleSignInService 驱动 Account 行登录态。
    @Environment(AppServices.self) private var services

    /// V3：SignInWithAppleButton 样式随系统外观（dark → 白按钮 / light → 黑按钮）。
    @Environment(\.colorScheme) private var colorScheme

    /// VM 用 .standard UserDefaults。测试代码用 isolated suite 传参绕开。
    @State private var vm = SettingsViewModel()

    /// 当前 sidebar 选中段。默认 General。
    @State private var selection: Section = .general

    /// 五大 section。
    enum Section: String, CaseIterable, Hashable {
        case general, notifications, sync, shortcuts, about

        var label: LocalizedStringResource {
            switch self {
            case .general:       return LJStrings.settingsSectionGeneral
            case .notifications: return LJStrings.settingsSectionNotifications
            case .sync:          return LJStrings.settingsSectionSync
            case .shortcuts:     return LJStrings.settingsSectionShortcuts
            case .about:         return LJStrings.settingsSectionAbout
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
                .overlay(Color.lj.border)
            content
        }
        .frame(width: 760, height: 540)
        .background(Color.lj.panel)
        // 关闭按钮：macOS .sheet 不会因 ESC 自动 dismiss（需绑 .cancelAction），
        // 且本面板原先没有任何关闭入口 → 打开后退不出去。右上「完成」按钮 + ESC 兜底。
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Text(LJStrings.commonDone)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.lj.bg)
                    .padding(.horizontal, LJSpacing.s12)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.lj.ink)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)   // ESC 也能关
            .padding(LJSpacing.s14)
            .accessibilityLabel(Text(LJStrings.commonDone))
        }
        // V1：把 App 级 CloudSyncMonitor 注入本 view 自有的 vm，驱动 Last-synced pill 实时刷新。
        .task {
            if let monitor = services.cloudSyncMonitor, vm.syncMonitor == nil {
                vm.attachSyncMonitor(monitor)
            }
        }
    }

    /// V1：Last-synced 状态点颜色 —— 跟随 CloudSyncMonitor 状态。
    /// syncing=蓝 / synced=绿 / error=红 / 其它（idle/纯本地）=中性。
    private var syncDotColor: Color {
        guard let status = vm.syncMonitor?.status else {
            // 无 monitor（纯本地 / 未注入）：ON 视为绿、OFF 视为中性。
            return vm.iCloudSyncOn ? Color(red: 0.098, green: 0.764, blue: 0.196) : Color.lj.inkDim
        }
        switch status {
        case .syncing:   return Color.lj.blue
        case .synced:    return Color(red: 0.098, green: 0.764, blue: 0.196)   // #19c332
        case .error:     return Color(red: 0.86, green: 0.18, blue: 0.18)
        case .idle:      return vm.iCloudSyncOn ? Color(red: 0.098, green: 0.764, blue: 0.196) : Color.lj.inkDim
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 顶部 "Settings" 小标题。设计稿在这里画的是 traffic lights —— macOS 系统 sheet 自带
            // window control，不需要我们手画。这里仅留小标题，与设计稿等效。
            Text(LJStrings.settingsTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.lj.ink)
                .padding(.horizontal, 10)
                .padding(.top, LJSpacing.s14)
                .padding(.bottom, LJSpacing.s12)

            ForEach(Section.allCases, id: \.self) { section in
                Button {
                    selection = section
                } label: {
                    Text(section.label)
                        .font(.system(
                            size: 12.5,
                            weight: selection == section ? .semibold : .medium
                        ))
                        .foregroundStyle(
                            selection == section ? Color.lj.ink : Color.lj.inkSoft
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == section ? Color.lj.chip : Color.clear)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(section.label))
            }

            Spacer()
        }
        .padding(.horizontal, LJSpacing.s8)
        .frame(width: 188)
        .background(Color.lj.bgSoft)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selection {
                case .general:       generalSection
                case .notifications: notificationsSection
                case .sync:          syncSection
                case .shortcuts:     shortcutsSection
                case .about:         aboutSection
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - General

    @ViewBuilder
    private var generalSection: some View {
        sectionHeader(label: LJStrings.settingsSectionGeneral, hint: LJStrings.settingsGeneralHint)

        // Appearance: 只读，严格跟系统。
        row(
            label: LJStrings.settingsAppearance,
            hint: LJStrings.settingsAppearanceHint,
            control: {
                HStack(spacing: 6) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.lj.inkSoft)
                    Text(LJStrings.settingsAppearanceValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.lj.inkSoft)
                    Text(LJStrings.settingsAppearanceLocked)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.lj.inkDim)
                        .padding(.horizontal, 4)
                        .padding(.leading, 2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.lj.chip)
                }
            }
        )

        row(
            label: LJStrings.settingsDefaultTab,
            hint: LJStrings.settingsDefaultTabHint,
            control: {
                Picker("", selection: $vm.defaultTab) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        Text(tab.localizedDisplayName).tag(tab)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }
        )

        row(
            label: LJStrings.settingsDefaultScope,
            hint: LJStrings.settingsDefaultScopeHint,
            control: {
                Picker("", selection: $vm.defaultTodoScope) {
                    Text(LJStrings.scopePersonal).tag(Scope.personal)
                    Text(LJStrings.scopeCompany).tag(Scope.company)
                }
                .labelsHidden()
                .frame(width: 140)
            }
        )

        // I5: showCompletedInCounts 是 v0.9 占位字段（VM 写 UserDefaults 但无 view 消费），
        // 加 "(coming in v1.0)" 提示，让用户知道这是 placeholder。
        rowWithV1Hint(
            label: LJStrings.settingsShowCompleted,
            hint: LJStrings.settingsShowCompletedHint,
            control: {
                Toggle("", isOn: $vm.showCompletedInCounts)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        )

        row(
            label: LJStrings.settingsStartWeek,
            hint: LJStrings.settingsStartWeekHint,
            control: {
                Picker("", selection: $vm.startWeekOn) {
                    Text(LJStrings.weekdaySunday).tag(Weekday.sunday)
                    Text(LJStrings.weekdayMonday).tag(Weekday.monday)
                }
                .labelsHidden()
                .frame(width: 140)
            }
        )
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationsSection: some View {
        sectionHeader(
            label: LJStrings.settingsSectionNotifications,
            hint: LJStrings.settingsNotificationsHint
        )

        row(
            label: LJStrings.settingsHeadsUp,
            hint: LJStrings.settingsHeadsUpHint,
            control: {
                // plan: Stepper 5/10/15/30。用自定 Picker 实现 4 选项，比 Stepper 体验更顺。
                // 数字 + " min" 不本地化（mono kbd-like 数字格式，与时间显示风格一致）。
                Picker("", selection: $vm.headsUpLeadMinutes) {
                    Text(verbatim: "5 min").tag(5)
                    Text(verbatim: "10 min").tag(10)
                    Text(verbatim: "15 min").tag(15)
                    Text(verbatim: "30 min").tag(30)
                }
                .labelsHidden()
                .frame(width: 140)
            }
        )

        // I5: systemBannerEnabled / yesterdayMissedReminderEnabled / dailySummaryHour /
        // quietHours 都是 v0.9 占位字段（VM 写 UserDefaults 但无 view 消费），
        // 加 "(coming in v1.0)" 提示。
        rowWithV1Hint(
            label: LJStrings.settingsSystemBanner,
            hint: LJStrings.settingsSystemBannerHint,
            control: {
                Toggle("", isOn: $vm.systemBannerEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        )

        rowWithV1Hint(
            label: LJStrings.settingsYesterdayMissed,
            hint: LJStrings.settingsYesterdayMissedHint,
            control: {
                Toggle("", isOn: $vm.yesterdayMissedReminderEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        )

        rowWithV1Hint(
            label: LJStrings.settingsDailySummary,
            hint: LJStrings.settingsDailySummaryHint,
            control: {
                // 小时选择器，0..23。Picker 列出 12 AM / 1 AM / ...
                Picker("", selection: $vm.dailySummaryHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(verbatim: formatHour(h)).tag(h)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }
        )

        rowWithV1Hint(
            label: LJStrings.settingsQuietHours,
            hint: LJStrings.settingsQuietHoursHint,
            control: {
                HStack(spacing: 6) {
                    Picker("", selection: $vm.quietHoursStart) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(verbatim: formatHour(h)).tag(h)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 90)
                    Text(verbatim: "—")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.lj.inkMute)
                    Picker("", selection: $vm.quietHoursEnd) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(verbatim: formatHour(h)).tag(h)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 90)
                }
            }
        )
    }

    // MARK: - Sync

    @ViewBuilder
    private var syncSection: some View {
        sectionHeader(
            label: LJStrings.settingsSectionSync,
            hint: LJStrings.settingsSyncHint
        )

        // V1：iCloud sync toggle 接真。OFF 不热切容器（SwiftData 不支持运行时改
        // cloudKitDatabase），切换写 UserDefaults，下次启动 makeContainer 读取生效。
        // toggle 旁加 mono caption "Restart to apply" 提示「重启后生效」。
        row(
            label: LJStrings.settingsICloudSync,
            hint: LJStrings.settingsICloudSyncHint,
            control: {
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("", isOn: $vm.iCloudSyncOn)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    Text(LJStrings.settingsICloudRestartHint)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.lj.inkDim)
                }
            }
        )

        // V3：Account 行接真 —— 未登录显示 SignInWithAppleButton，已登录显示姓名 / email + Sign out。
        accountRow

        // V3：EventKit mirror 两个 toggle —— v1.0 不接 EventKit（plan V3 决策），hint 改为
        // "(coming later)" 占位，toggle 仍可拨但无运行时副作用（写 UserDefaults，不接 EKEventStore）。
        rowWithEventKitHint(
            label: LJStrings.settingsAppleCalendar,
            hint: LJStrings.settingsAppleCalendarHint,
            control: {
                Toggle("", isOn: $vm.calendarMirrorOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        )

        rowWithEventKitHint(
            label: LJStrings.settingsAppleReminders,
            hint: LJStrings.settingsAppleRemindersHint,
            control: {
                Toggle("", isOn: $vm.remindersMirrorOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        )

        // V1：Last synced status pill 接真 —— 文案由 vm.lastSyncedText 实时驱动
        // （CloudSyncMonitor 状态：Syncing… / Synced just now / Sync paused / Local only）。
        HStack(spacing: 8) {
            Circle()
                .fill(syncDotColor)
                .frame(width: 6, height: 6)
            Text(vm.lastSyncedText)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.lj.inkSoft)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.lj.chip)
        }
        .padding(.top, LJSpacing.s18)
    }

    // MARK: - Shortcuts

    @ViewBuilder
    private var shortcutsSection: some View {
        sectionHeader(
            label: LJStrings.settingsSectionShortcuts,
            hint: LJStrings.settingsShortcutsHint
        )

        ForEach(Self.shortcutGroups, id: \.id) { group in
            shortcutGroupView(label: group.label, items: group.items)
                .padding(.bottom, LJSpacing.s22)
        }
    }

    /// 设计稿 ASettingsShortcuts 中的 3 组键位（plan: Navigation / Create / On a todo）。
    /// `id` 用 raw string 让 ForEach 稳定；label 与 item.label 走 LocalizedStringResource。
    private struct ShortcutGroup {
        let id: String
        let label: LocalizedStringResource
        let items: [ShortcutItem]
    }
    private struct ShortcutItem {
        let keys: String
        let label: LocalizedStringResource
    }
    private static let shortcutGroups: [ShortcutGroup] = [
        ShortcutGroup(
            id: "navigation",
            label: LJStrings.settingsShortcutsNavigation,
            items: [
                .init(keys: "\u{2318} 1",  label: LJStrings.tabMain),
                .init(keys: "\u{2318} 2",  label: LJStrings.tabPersonal),
                .init(keys: "\u{2318} 3",  label: LJStrings.tabCompany),
                .init(keys: "\u{2318} 4",  label: LJStrings.tabCalendar),
                .init(keys: "\u{2318} K",  label: LJStrings.shortcutOpenSearch),
                .init(keys: "\u{2318} ,",  label: LJStrings.shortcutOpenSettings),
            ]
        ),
        ShortcutGroup(
            id: "create",
            label: LJStrings.settingsShortcutsCreate,
            items: [
                .init(keys: "\u{2318} N",         label: LJStrings.shortcutNewDefault),
                .init(keys: "\u{2318} \u{21E7} T", label: LJStrings.shortcutNewTodo),
                .init(keys: "\u{2318} \u{21E7} E", label: LJStrings.shortcutNewEvent),
                .init(keys: "\u{2318} \u{21E7} P", label: LJStrings.shortcutNewProject),
            ]
        ),
        ShortcutGroup(
            id: "onTodo",
            label: LJStrings.settingsShortcutsOnTodo,
            items: [
                .init(keys: "\u{2318} \u{23CE}", label: LJStrings.shortcutToggleDone),
                .init(keys: "\u{2318} U",         label: LJStrings.shortcutToggleUrgent),
                .init(keys: "\u{232B}",            label: LJStrings.shortcutDelete),
            ]
        ),
    ]

    @ViewBuilder
    private func shortcutGroupView(
        label: LocalizedStringResource,
        items: [ShortcutItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.lj.inkMute)
                .textCase(.uppercase)
                .kerning(0.88)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 16) {
                        Text(verbatim: item.keys)
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.lj.ink)
                            .kerning(0.46)
                            .frame(width: 120, alignment: .leading)
                        Text(item.label)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color.lj.inkSoft)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(alignment: .top) {
                        if idx > 0 {
                            Rectangle()
                                .fill(Color.lj.border)
                                .frame(height: 0.5)
                        }
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.lj.bgSoft)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        sectionHeader(label: LJStrings.settingsSectionAbout, hint: nil)

        VStack(alignment: .leading, spacing: 6) {
            Text(LJStrings.aboutAppName)
                .font(.system(size: 22, weight: .semibold))
                .kerning(-0.55)
                .foregroundStyle(Color.lj.ink)
            Text(LJStrings.aboutTagline)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.lj.inkSoft)
            Text(verbatim: "v\(LinoJCore.version)")
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.lj.inkMute)
                .padding(.top, 4)
        }
        .padding(.bottom, LJSpacing.s22)

        ForEach(Self.aboutLinks, id: \.id) { item in
            aboutLinkRow(label: item.label, hint: item.hint, raw: item.rawHint)
        }
    }

    /// About 链接 row 模型：label 本地化；hint 大多本地化，但 feedback 的 email 是 raw。
    private struct AboutLink {
        let id: String
        let label: LocalizedStringResource
        let hint: LocalizedStringResource?
        let rawHint: String?
    }
    private static let aboutLinks: [AboutLink] = [
        .init(id: "release",   label: LJStrings.aboutReleaseNotes,    hint: LJStrings.aboutReleaseNotesHint, rawHint: nil),
        .init(id: "feedback",  label: LJStrings.aboutFeedback,        hint: nil, rawHint: "feedback@linoj.app"),
        .init(id: "privacy",   label: LJStrings.aboutPrivacy,         hint: LJStrings.aboutPrivacyHint, rawHint: nil),
        .init(id: "acks",      label: LJStrings.aboutAcknowledgements, hint: LJStrings.aboutAcknowledgementsHint, rawHint: nil),
    ]

    @ViewBuilder
    private func aboutLinkRow(
        label: LocalizedStringResource,
        hint: LocalizedStringResource?,
        raw: String?
    ) -> some View {
        Button {
            // 0.9.1：About 链接尚未接通（占位）。去掉 print，beta 可接受点击静默无反应。
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.lj.ink)
                    if let hint {
                        Text(hint)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.lj.inkMute)
                    } else if let raw {
                        Text(verbatim: raw)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.lj.inkMute)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.lj.inkDim)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.lj.border)
                    .frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Row primitives

    @ViewBuilder
    private func sectionHeader(label: LocalizedStringResource, hint: LocalizedStringResource?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 19, weight: .semibold))
                .kerning(-0.38)
                .foregroundStyle(Color.lj.ink)
            if let hint {
                Text(hint)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
            }
        }
        .padding(.bottom, LJSpacing.s18)
    }

    @ViewBuilder
    private func row<Control: View>(
        label: LocalizedStringResource,
        hint: LocalizedStringResource?,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                if let hint {
                    Text(hint)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.lj.inkMute)
                }
            }
            Spacer()
            control()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.lj.border)
                .frame(height: 0.5)
        }
    }

    /// I5：与 `row()` 等价，但在 label 右侧加 "(coming in v1.0)" hint 提示
    /// 该字段在 v0.9 不接通。仅给 SettingsViewModel 中持久化但无 view 消费的字段使用。
    @ViewBuilder
    private func rowWithV1Hint<Control: View>(
        label: LocalizedStringResource,
        hint: LocalizedStringResource?,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.lj.ink)
                    Text(LJStrings.settingsV1OnlyHint)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.lj.inkDim)
                }
                if let hint {
                    Text(hint)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.lj.inkMute)
                }
            }
            Spacer()
            control()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.lj.border)
                .frame(height: 0.5)
        }
    }

    /// V3：Account 行 —— Sign in with Apple 接真。
    /// 未登录：label「Account」+ 次级提示 + 右侧原生 `SignInWithAppleButton`。
    /// 已登录：label「Account」+ 姓名 / email（来自首次授权缓存）+ 右侧 "Sign out" 按钮。
    @ViewBuilder
    private var accountRow: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(LJStrings.settingsAccount)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                accountSubtitle
            }
            Spacer()
            accountControl
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.lj.border)
                .frame(height: 0.5)
        }
    }

    /// Account 行次级文字：已登录显示姓名 / email；未登录显示「Sign in to show your identity」。
    @ViewBuilder
    private var accountSubtitle: some View {
        if let auth = services.appleSignIn, auth.isSignedIn {
            if let display = auth.displayName ?? auth.email {
                Text(verbatim: display)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
            } else {
                // 极端：已登录但 Apple 未回传姓名 / email（非首次登录且未缓存）。
                Text(LJStrings.settingsAccountNotSignedIn)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
            }
        } else {
            Text(LJStrings.settingsAccountSignedOutHint)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.lj.inkMute)
        }
    }

    /// Account 行右侧控件：未登录 SignInWithAppleButton，已登录 Sign out 按钮。
    @ViewBuilder
    private var accountControl: some View {
        if let auth = services.appleSignIn, auth.isSignedIn {
            Button {
                // V3：登出仅清 SIWA 身份，不动 SwiftData / CloudKit（plan V3 决策）。
                auth.signOut()
            } label: {
                Text(LJStrings.settingsSignOut)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Color.lj.inkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.lj.borderStrong, lineWidth: 0.5)
            }
        } else {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                services.appleSignIn?.handleAuthorization(result)
            }
            // 外观随系统 colorScheme：dark 用白按钮、light 用黑按钮，符合 Apple HIG。
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(width: 180, height: 30)
            .accessibilityLabel(Text(LJStrings.settingsSignInWithApple))
        }
    }

    /// V3：与 `row()` 等价，但在 label 右侧加 "(coming later)" 提示该字段在 v1.0 不接 EventKit。
    /// 用于 Apple Calendar / Reminders mirror 两个占位 toggle。
    @ViewBuilder
    private func rowWithEventKitHint<Control: View>(
        label: LocalizedStringResource,
        hint: LocalizedStringResource?,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.lj.ink)
                    Text(LJStrings.settingsEventKitLaterHint)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.lj.inkDim)
                }
                if let hint {
                    Text(hint)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.lj.inkMute)
                }
            }
            Spacer()
            control()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.lj.border)
                .frame(height: 0.5)
        }
    }

    // MARK: - Helpers

    /// 把 24h 整数转成「8 AM」「12 PM」「3 PM」等显示。
    private func formatHour(_ h: Int) -> String {
        switch h {
        case 0:        return "12 AM"
        case 1...11:   return "\(h) AM"
        case 12:       return "12 PM"
        default:       return "\(h - 12) PM"
        }
    }
}

// `AppTab.localizedDisplayName` 已挪到 LinoJCore/Localization/Strings.swift —— 跨 macOS/iOS 共用。
