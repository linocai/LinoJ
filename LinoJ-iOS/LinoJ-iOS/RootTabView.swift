// RootTabView.swift
// iOS 顶层根视图。P3.1 实现：
//   - `TabView` 作为状态 + 内容 swap 容器，绑 `router.current`。
//   - 隐藏系统 tab bar（`.toolbar(.hidden, for: .tabBar)`），自己渲染浮动 capsule。
//   - 浮动 capsule：4 个 SF Symbol 按钮，外壳 `.glassEffect(in: Capsule())` —— 这是 iOS 26 原生
//     Liquid Glass，不能用手搓 Material 或 UIVisualEffectView。capsule 距左右各 14pt，
//     距 home indicator 24pt（README NON-NEGOTIABLE）。
//   - 右上叠 `FloatingActions`（搜索 / + 两枚 40pt 圆形 glass 按钮）。
//
// 内容区先 placeholder，P3.2 / P3.3 / P3.4 接入真实屏幕。
//
// 设计决策（方案 B）：iOS 26 默认 TabView 自带 floating Liquid Glass tab bar，但其
// margin / 内容 / 颜色完全由系统决定，无法精确做到 README 要求的「14pt 左右内边距 + 24pt
// 距 home indicator + 仅 4 个 SF Symbol（无 label 文字）」。因此选择隐藏系统 tab bar，
// 自己叠加一层 capsule + glassEffect 完成视觉。这是 README 第 357 行明确指定的做法。
//
// P4：与 RootWindow（macOS）对称 —— 持有 AppServices 容器，`.task` 中初始化
// HeadsUpService / YesterdayMissedService 并启动 tick；申请通知授权并 scheduleAll。

import SwiftUI
import SwiftData
import LinoJCore

struct RootTabView: View {

    @Environment(TabRouter.self) private var router

    /// 从环境拿 SwiftData ModelContext（由 `.modelContainer(...)` 注入）。
    @Environment(\.modelContext) private var modelContext

    /// P4：service 容器。`.task` 中拿到 modelContext 后填字段。
    @State private var services = AppServices()

    /// P4：Settings VM，用于读 `headsUpLeadMinutes`。
    @State private var settings = SettingsViewModel()

    /// `@Query` 当前所有 Event —— 仅用于 onChange 触发 re-schedule。
    @Query private var allEvents: [Event]

    var body: some View {
        @Bindable var router = router

        // 用 ZStack 把 TabView（提供内容 swap）+ 自定义 floating capsule + 右上 actions 三层叠起。
        // bottom 的 capsule 不占布局空间（用 overlay 不挤压内容）；
        // 内容区底部需要让出 ~100pt 给浮动 capsule，留到 P3.2 起在屏幕内部自行 padding。
        ZStack {
            // 1) TabView 仅负责承载内容与「当前 tab 是哪个」的状态。
            //    用 value-based `Tab` API（iOS 18+）。
            TabView(selection: $router.current) {
                Tab(value: AppTab.main) {
                    MainView_iOS()
                } label: {
                    Label {
                        Text(LJStrings.tabMain)
                    } icon: {
                        Image(systemName: "house")
                    }
                }
                Tab(value: AppTab.personal) {
                    PersonalView_iOS()
                } label: {
                    Label {
                        Text(LJStrings.tabPersonal)
                    } icon: {
                        Image(systemName: "person")
                    }
                }
                Tab(value: AppTab.company) {
                    CompanyView_iOS()
                } label: {
                    Label {
                        Text(LJStrings.tabCompany)
                    } icon: {
                        Image(systemName: "briefcase")
                    }
                }
                Tab(value: AppTab.calendar) {
                    CalendarView_iOS()
                } label: {
                    Label {
                        Text(LJStrings.tabCalendar)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
            }
            // 用 iOS 26 原生 Liquid Glass tab bar（带文字 label 那条）。
            // 不再 `.toolbar(.hidden, for: .tabBar)` + 自渲浮动 capsule —— 二者在 iOS 26
            // 会叠加成两条 tab bar（原生没被隐藏 + 手搓 capsule）。原生 bar 本身就是 Liquid Glass。
        }
        // 右上：两枚 floating glass 按钮（search / + / gear）。
        .overlay(alignment: .topTrailing) {
            FloatingActions()
                .padding(.horizontal, LJSpacing.s14)
                .padding(.top, LJSpacing.s10)
        }
        // P4：service 容器注入子树。
        .environment(services)
        // P4：初始化 services + 启动 HeadsUp tick + 申请通知授权 + 首次 scheduleAll。
        .task {
            if services.headsUp == nil {
                let svc = HeadsUpService(context: modelContext, leadMinutes: settings.headsUpLeadMinutes)
                svc.start()
                services.headsUp = svc
            }
            if services.yesterdayMissed == nil {
                services.yesterdayMissed = YesterdayMissedService(context: modelContext)
            }
            // V1：按启动期读到的 iCloud sync 开关创建 CloudSyncMonitor 并 start()。
            // 与 App init 给 makeContainer 的 cloudSyncEnabled 同源（读同一 UserDefaults key）。
            if SettingsViewModel.readICloudSyncOn() {
                if services.cloudSyncMonitor == nil {
                    let monitor = CloudSyncMonitor(cloudSyncEnabled: true)
                    monitor.start()
                    services.cloudSyncMonitor = monitor
                }
                // V2：iCloud sync 开启时注册远程通知，让 CloudKit 的 content-available 静默推送
                // 能在后台唤醒 App 触发 SwiftData 自动同步。SwiftData 已内置 CKDatabaseSubscription，
                // 此处只注册、不手搓订阅。注册不弹授权弹窗（静默推送无需用户授权），与本地通知授权（下方）互不替代。
                RemoteNotificationRegistrar.register()
            } else if services.cloudSyncMonitor == nil {
                // 纯本地模式：monitor 仍创建（静默 idle），但不注册远程通知。
                services.cloudSyncMonitor = CloudSyncMonitor(cloudSyncEnabled: false)
            }
            // V3：Sign in with Apple 登录态服务。AppServices 长生命周期持有（不随 Settings sheet 重建）。
            // 启动先从持久化恢复展示态（restoreState），再异步校验凭据是否被撤销（refreshCredentialState）。
            if services.appleSignIn == nil {
                let auth = AppleSignInService()
                auth.restoreState()
                services.appleSignIn = auth
                await auth.refreshCredentialState()
            }
            let notifier = NotificationService()
            let granted = await notifier.requestAuthorization()
            if granted {
                await notifier.scheduleAll(events: allEvents, leadMinutes: settings.headsUpLeadMinutes)
            }
        }
        .onChange(of: settings.headsUpLeadMinutes) { _, newValue in
            Task {
                await NotificationService().scheduleAll(events: allEvents, leadMinutes: newValue)
            }
        }
        .onChange(of: allEvents.count) { _, _ in
            Task {
                await NotificationService().scheduleAll(events: allEvents, leadMinutes: settings.headsUpLeadMinutes)
            }
        }
        // I8: 额外监听所有 event.start 变化（覆盖 "事件被编辑了 start 时间" 场景）。
        // v0.9 没有事件编辑入口，但 monitor 已就位；NotificationService 内部全量
        // removeAll + add，无重复触发问题。
        .onChange(of: allEvents.map(\.start)) { _, _ in
            Task {
                await NotificationService().scheduleAll(events: allEvents, leadMinutes: settings.headsUpLeadMinutes)
            }
        }
        // P3.6：Quick Add bottom sheet。`.presentationDetents` 与 grab handle 在
        // QuickAddSheet_iOS 内部设置；这里只绑 isPresented。
        .sheet(isPresented: $router.showQuickAdd) {
            QuickAddSheet_iOS()
                .environment(router)
        }
        // P3.7：Search full-screen sheet。`.presentationDetents([.large])` 在 SearchSheet_iOS 内部。
        .sheet(isPresented: $router.showSearch) {
            SearchSheet_iOS()
                .environment(router)
        }
        // P3.8：Settings full-screen sheet。`.presentationDetents([.large])` 在 SettingsSheet_iOS 内部。
        // FloatingActions 第三枚 gear 按钮翻 router.showSettings。
        .sheet(isPresented: $router.showSettings) {
            SettingsSheet_iOS()
                .environment(router)
                .environment(services)
        }
    }

    /// 占位内容。背景 `lj.iosMainBg`（README 指定 iOS Main 用 #f4f3ef 暖灰）。
    /// 真实屏幕在后续 Phase 替换。
    @ViewBuilder
    private func placeholder(for tab: AppTab) -> some View {
        // P0 占位（被替换为真实 Screen 后保留作为 fallback）。
        ZStack {
            Color.lj.iosMainBg.ignoresSafeArea()
            Text(tab.localizedDisplayName)
                .ljSectionHeaderStyle()
                .foregroundStyle(Color.lj.inkMute)
        }
    }
}

