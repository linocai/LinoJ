// SettingsSheet_iOS.swift
// iOS Settings full-screen sheet —— plan P3.8 范围。
//
// 入口：FloatingActions 第三枚 gear 按钮 → router.showSettings = true → RootTabView 的
// `.sheet(isPresented: $router.showSettings) { SettingsSheet_iOS() }`。
//
// 视觉决策（依据 design_handoff_linoj_frontend/LinoJ 主页.dc.html（iOS Settings））：
//   - `.presentationDetents([.large])` —— 全屏 sheet。
//   - 顶部 sticky bar：Cancel / "Settings" / Done。`Done` 调 dismiss。
//     背景 `.regularMaterial` 20pt blur（设计稿要求）。
//   - iOS 系统 grouped List 风格：不用 SwiftUI `List`（控制粒度有限），自己堆 Section card
//     + row（每行 0.5pt divider）。这样能完整还原设计稿的 corner radius 12pt + 0.5pt border。
//   - 按设计稿分 5 组：Account / General / Notifications / Sync to other apps / About。
//     plan 明确 iOS **不显示 Shortcuts**。
//   - 底部红色 "Sign out" 按钮（print 占位）。

import SwiftUI
import AuthenticationServices
import LinoJCore

struct SettingsSheet_iOS: View {

    @Environment(\.dismiss) private var dismiss

    /// W3：About 区 Feedback(mailto) / Privacy(URL) 点击打开。
    @Environment(\.openURL) private var openURL

    /// V1：App 级 service 容器，用来取 CloudSyncMonitor 注入到本 view 的 vm。
    /// V3：同时取 AppleSignInService 驱动 Account 行 + 底部 Sign out 按钮。
    @Environment(AppServices.self) private var services

    /// V3：SignInWithAppleButton 样式随系统外观（dark → 白按钮 / light → 黑按钮）。
    @Environment(\.colorScheme) private var colorScheme

    /// VM 用 .standard UserDefaults。测试代码用 isolated suite 传参绕开。
    @State private var vm = SettingsViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            // 背景：iOS Settings 用 bg（不是 iosMainBg —— 因为这是 sheet，非主面板）。
            Color.lj.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶栏占位：因为顶栏是 overlay 不占布局，这里留出与 top bar 等高的空白
                    // 让首个 section 不被遮。72pt = 大致 status + bar 内容。
                    Color.clear.frame(height: 56)

                    VStack(spacing: LJSpacing.s22) {
                        accountGroup
                        generalGroup
                        notificationsGroup
                        syncGroup
                        aboutGroup

                        VStack(spacing: 8) {
                            // V3：底部红色 Sign out 按钮接真 —— 仅当已登录时显示；登出只清 SIWA 身份，
                            // 不动 SwiftData / CloudKit（plan V3 决策）。未登录时隐藏（用 Account 行的
                            // SignInWithAppleButton 登录）。
                            if let auth = services.appleSignIn, auth.isSignedIn {
                                Button {
                                    auth.signOut()
                                } label: {
                                    Text(LJStrings.settingsSignOut)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color(red: 1.0, green: 0.373, blue: 0.341))
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            // App name + version：app name 不本地化（品牌名）；
                            // 版本号 mono 不本地化。整段写成 verbatim 避免格式化插值参与翻译。
                            Text(verbatim: "LinoJ · v\(LinoJCore.version)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.lj.inkMute)
                                .padding(.top, 8)
                        }
                        .padding(.top, LJSpacing.s12)
                    }
                    .padding(.horizontal, LJSpacing.s16)
                    .padding(.bottom, 40)
                }
            }

            // 顶部 sticky bar（plan: regularMaterial 20pt blur）。
            topBar
        }
        // v1.3 R7：bottom sheet 观感 —— grabber + 顶圆角 28（内容较多，仍用 .large 全高）。
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        // V1：把 App 级 CloudSyncMonitor 注入本 view 自有的 vm，驱动 Last-synced pill 实时刷新。
        .task {
            if let monitor = services.cloudSyncMonitor, vm.syncMonitor == nil {
                vm.attachSyncMonitor(monitor)
            }
        }
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Button {
                    dismiss()
                } label: {
                    Text(LJStrings.quickAddCancel)
                }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.lj.inkSoft)

                Spacer()

                Text(LJStrings.settingsTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.lj.ink)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text(LJStrings.commonDone)
                }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.lj.ink)
            }
            .padding(.horizontal, LJSpacing.s16)
            .padding(.top, LJSpacing.s12)
            .padding(.bottom, LJSpacing.s12)
        }
        .background(.regularMaterial)
    }

    // MARK: - Groups

    @ViewBuilder
    private var accountGroup: some View {
        group(label: LJStrings.settingsSectionAccount) {
            // V3：Account 行接真 —— 未登录显示 SignInWithAppleButton，已登录显示姓名 / email。
            accountRow
            divider
            // V1：iCloud sync toggle 接真。hint 显示「重启后生效」（OFF 不热切容器，下次启动生效）。
            toggleRow(label: LJStrings.settingsICloudSync,
                      hint: LJStrings.settingsICloudRestartHint,
                      isOn: $vm.iCloudSyncOn)
            divider
            // V1：Last-synced status pill 行 —— 文案由 CloudSyncMonitor 实时驱动。
            lastSyncedRow
        }
    }

    /// V3：Account 行 —— Sign in with Apple 接真。
    /// 未登录：label「Account」+ 次级提示 + 右侧原生 `SignInWithAppleButton`。
    /// 已登录：label「Account」+ 姓名 / email（首次授权缓存）。Sign out 由底部红色按钮触发。
    @ViewBuilder
    private var accountRow: some View {
        rowContainer {
            if let auth = services.appleSignIn, auth.isSignedIn {
                HStack(spacing: 6) {
                    Text(LJStrings.settingsAppleAccount)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lj.ink)
                    Spacer()
                    Text(verbatim: auth.displayName ?? auth.email ?? String(localized: LJStrings.settingsAccountNotSignedIn))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Color.lj.inkSoft)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LJStrings.settingsAppleAccount)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.lj.ink)
                        Text(LJStrings.settingsAccountSignedOutHint)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.lj.inkMute)
                    }
                    Spacer()
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        services.appleSignIn?.handleAuthorization(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(width: 150, height: 36)
                    .accessibilityLabel(Text(LJStrings.settingsSignInWithApple))
                }
            }
        }
    }

    /// V1：Last-synced 状态行（状态点 + 文案）。
    @ViewBuilder
    private var lastSyncedRow: some View {
        rowContainer {
            HStack(spacing: 8) {
                Circle()
                    .fill(syncDotColor)
                    .frame(width: 6, height: 6)
                Text(vm.lastSyncedText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lj.inkSoft)
                Spacer()
            }
        }
    }

    /// V1：Last-synced 状态点颜色 —— 跟随 CloudSyncMonitor 状态。
    private var syncDotColor: Color {
        guard let status = vm.syncMonitor?.status else {
            return vm.iCloudSyncOn ? Color(red: 0.098, green: 0.764, blue: 0.196) : Color.lj.inkDim
        }
        switch status {
        case .syncing:   return Color.lj.blue
        case .synced:    return Color(red: 0.098, green: 0.764, blue: 0.196)
        case .error:     return Color(red: 0.86, green: 0.18, blue: 0.18)
        case .idle:      return vm.iCloudSyncOn ? Color(red: 0.098, green: 0.764, blue: 0.196) : Color.lj.inkDim
        }
    }

    @ViewBuilder
    private var generalGroup: some View {
        group(label: LJStrings.settingsSectionGeneral) {
            // Appearance：只读，跟系统。value = "System"，valueMute = "locked"，附 hint。
            staticRowLocalized(
                label: LJStrings.settingsAppearance,
                value: LJStrings.settingsAppearanceValue,
                valueMute: LJStrings.settingsAppearanceLocked,
                hint: LJStrings.settingsAppearanceHintIOS
            )
            divider
            // Default tab：用 Picker 包装成 menu。
            pickerRowLocalized(label: LJStrings.settingsDefaultTab, selection: $vm.defaultTab) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Text(tab.localizedDisplayName).tag(tab)
                }
            } valueText: {
                vm.defaultTab.localizedDisplayName
            }
            divider
            pickerRowLocalized(label: LJStrings.settingsDefaultScope, selection: $vm.defaultTodoScope) {
                Text(LJStrings.scopePersonal).tag(Scope.personal)
                Text(LJStrings.scopeCompany).tag(Scope.company)
            } valueText: {
                vm.defaultTodoScope == .personal ? LJStrings.scopePersonal : LJStrings.scopeCompany
            }
            divider
            // W2: showCompletedInCounts 已真接通（影响各屏 open 计数），去掉 "(coming later)" hint。
            toggleRow(label: LJStrings.settingsShowCompleted, hint: nil, isOn: $vm.showCompletedInCounts)
        }
    }

    @ViewBuilder
    private var notificationsGroup: some View {
        group(label: LJStrings.settingsSectionNotifications,
              footerHint: LJStrings.settingsNotificationsHint) {
            pickerRowRawValue(label: LJStrings.settingsHeadsUpShort, selection: $vm.headsUpLeadMinutes) {
                Text(verbatim: "5 min").tag(5)
                Text(verbatim: "10 min").tag(10)
                Text(verbatim: "15 min").tag(15)
                Text(verbatim: "30 min").tag(30)
            } valueText: {
                "\(vm.headsUpLeadMinutes) min"
            }
            divider
            // W2: systemBanner（NotificationService.scheduleAll 总闸门）与 yesterdayMissed
            //（「From yesterday」box 显示闸门）已真接通，去掉 "(coming later)" hint。
            toggleRow(label: LJStrings.settingsSystemBannerShort, hint: nil, isOn: $vm.systemBannerEnabled)
            divider
            toggleRow(label: LJStrings.settingsYesterdayMissed, hint: nil, isOn: $vm.yesterdayMissedReminderEnabled)
            // W2: Daily summary / Quiet hours 延后到 v1.1+（需每日定时调度 + 静音窗口判断），
            // 整行隐藏。VM 字段 / UserDefaults key / 测试全部保留，仅不再展示 UI。
        }
    }

    @ViewBuilder
    private var syncGroup: some View {
        group(label: LJStrings.settingsSectionSyncOtherApps) {
            // V3 / W2：EventKit mirror —— v1.0 不接 EventKit（plan V3 决策），保留 "(coming later)"
            // 占位 hint。W2 追加 `disabled: true`：无消费方，可拨会误导用户，置灰不可拨。
            toggleRow(label: LJStrings.settingsAppleCalendarShort,
                      hint: LJStrings.settingsAppleCalendarShortHint,
                      isOn: $vm.calendarMirrorOn,
                      eventKitHint: true,
                      disabled: true)
            divider
            toggleRow(label: LJStrings.settingsAppleRemindersShort,
                      hint: LJStrings.settingsAppleRemindersShortHint,
                      isOn: $vm.remindersMirrorOn,
                      eventKitHint: true,
                      disabled: true)
        }
    }

    @ViewBuilder
    private var aboutGroup: some View {
        group(label: LJStrings.settingsSectionAbout) {
            staticRowRaw(
                label: LJStrings.aboutVersion,
                value: LinoJCore.version,
                valueMono: true
            )
            divider
            // W3：Feedback → mailto 拉起邮件 compose；Privacy → 浏览器打开隐私 URL。
            // Release notes / Acknowledgements 两行已砍掉（无真实页面）。
            chevronRow(label: LJStrings.aboutFeedback) {
                if let url = URL(string: "mailto:\(LinoJLinks.feedbackEmail)") {
                    openURL(url)
                }
            }
            divider
            chevronRow(label: LJStrings.aboutPrivacy) {
                if let url = URL(string: LinoJLinks.privacyPolicy) {
                    openURL(url)
                }
            }
        }
    }

    // MARK: - Group container

    @ViewBuilder
    private func group<Content: View>(
        label: LocalizedStringResource,
        footerHint: LocalizedStringResource? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.lj.inkMute)
                .textCase(.uppercase)
                .kerning(0.88)
                .padding(.horizontal, 6)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            // v1.3 R7：分组卡 = 玻璃材质 + hairline + 顶高光（原型 rgba(255,255,255,0.6) 软玻璃）。
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
            .overlay { LJTopHighlight(radius: 14) }

            if let footerHint {
                Text(footerHint)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// 行间分割线（设计稿用 0.5pt border-bottom）。
    private var divider: some View {
        Rectangle()
            .fill(Color.lj.border)
            .frame(height: 0.5)
    }

    // MARK: - Row primitives

    /// 带 Toggle 控件的行（设计稿 iOS toggle）。
    /// I5: `v1Hint` 为 true 时在 label 右边加 "(coming in v1.0)" 提示。
    /// V3: `eventKitHint` 为 true 时在 label 右边加 "(coming later)" 提示（EventKit mirror 占位）。
    /// W2: `disabled` 为 true 时 Toggle 置灰不可拨（用于无消费方的占位开关，如 EventKit mirror）。
    @ViewBuilder
    private func toggleRow(label: LocalizedStringResource, hint: LocalizedStringResource?, isOn: Binding<Bool>, v1Hint: Bool = false, eventKitHint: Bool = false, disabled: Bool = false) -> some View {
        rowContainer {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.lj.ink)
                        if v1Hint {
                            Text(LJStrings.settingsV1OnlyHint)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.lj.inkDim)
                        } else if eventKitHint {
                            Text(LJStrings.settingsEventKitLaterHint)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.lj.inkDim)
                        }
                    }
                    if let hint {
                        Text(hint)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.lj.inkMute)
                            .frame(maxWidth: 280, alignment: .leading)
                    }
                }
                Spacer()
                // v1.3 R7：ON 态品牌紫（原型 iCloud toggle 用品牌渐变，SwiftUI Toggle tint 取单色紫近似）。
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(Color.lj.accent)
                    .disabled(disabled)
            }
        }
    }

    /// 带 raw value 字符串 + chevron 的行（点击触发回调）。
    /// value 是 raw（如 email 地址）—— 用于 Apple Account 这种场景。
    @ViewBuilder
    private func chevronRow(label: LocalizedStringResource, rawValue: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowContainer {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lj.ink)
                    Spacer()
                    if let rawValue {
                        Text(verbatim: rawValue)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(Color.lj.inkSoft)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.lj.inkDim)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 只读 value 行 —— label & value & valueMute & hint 全本地化。
    @ViewBuilder
    private func staticRowLocalized(
        label: LocalizedStringResource,
        value: LocalizedStringResource,
        valueMute: LocalizedStringResource? = nil,
        valueMono: Bool = false,
        hint: LocalizedStringResource? = nil
    ) -> some View {
        rowContainer {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lj.ink)
                    Spacer()
                    Text(value)
                        .font(.system(
                            size: 13.5,
                            weight: .medium,
                            design: valueMono ? .monospaced : .default
                        ))
                        .foregroundStyle(Color.lj.inkSoft)
                    if let valueMute {
                        Text(valueMute)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.lj.inkDim)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.lj.chip)
                            }
                    }
                }
                if let hint {
                    Text(hint)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.lj.inkMute)
                        .frame(maxWidth: 280, alignment: .leading)
                }
            }
        }
    }

    /// 只读 value 行 —— value 是 raw（如版本号）。
    @ViewBuilder
    private func staticRowRaw(
        label: LocalizedStringResource,
        value: String,
        valueMono: Bool = false
    ) -> some View {
        rowContainer {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                Spacer()
                Text(verbatim: value)
                    .font(.system(
                        size: 13.5,
                        weight: .medium,
                        design: valueMono ? .monospaced : .default
                    ))
                    .foregroundStyle(Color.lj.inkSoft)
            }
        }
    }

    /// 带 Picker（menu 风格）的行，value label 为 LocalizedStringResource。
    @ViewBuilder
    private func pickerRowLocalized<SelectionValue: Hashable, PickerContent: View>(
        label: LocalizedStringResource,
        selection: Binding<SelectionValue>,
        @ViewBuilder pickerContent: () -> PickerContent,
        valueText: () -> LocalizedStringResource
    ) -> some View {
        rowContainer {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                Spacer()
                Picker(selection: selection) {
                    pickerContent()
                } label: {
                    HStack(spacing: 4) {
                        Text(valueText())
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(Color.lj.inkSoft)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Color.lj.inkSoft)
            }
        }
    }

    /// 带 Picker（menu 风格）的行，value label 为 raw 字符串（数字 + 时间格式不本地化）。
    /// I5: `v1Hint` 为 true 时在 label 右边加 "(coming in v1.0)" 提示。
    @ViewBuilder
    private func pickerRowRawValue<SelectionValue: Hashable, PickerContent: View>(
        label: LocalizedStringResource,
        selection: Binding<SelectionValue>,
        v1Hint: Bool = false,
        @ViewBuilder pickerContent: () -> PickerContent,
        valueText: () -> String
    ) -> some View {
        rowContainer {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                if v1Hint {
                    Text(LJStrings.settingsV1OnlyHint)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.lj.inkDim)
                }
                Spacer()
                Picker(selection: selection) {
                    pickerContent()
                } label: {
                    HStack(spacing: 4) {
                        Text(verbatim: valueText())
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(Color.lj.inkSoft)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Color.lj.inkSoft)
            }
        }
    }

    // W2：移除 `quietHoursRow`（Quiet hours 单行 + 双 picker）—— Quiet hours 整行隐藏到 v1.1+。
    // VM 字段 / UserDefaults key / 测试全部保留，仅不再展示 UI。

    /// 每行通用容器：14pt padding + 撑满宽。
    @ViewBuilder
    private func rowContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    // W2：移除 `formatHour`（小时 12h 格式化）—— 仅 Daily summary / Quiet hours 两个已隐藏
    // 的 Picker 用过它，删除以免留死代码。
}

// `AppTab.localizedDisplayName` 已在 LinoJCore 提供，无需本地 extension。
