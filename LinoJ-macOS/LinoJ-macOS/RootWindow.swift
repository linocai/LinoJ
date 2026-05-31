// RootWindow.swift
// macOS 顶层窗口内容。P3.3 起：
//   - 顶栏中心 segmented Picker（Main / Personal / Company / Calendar），绑定到 TabRouter.current；
//   - 主内容区按 router.current 分发：
//       .main      → MainView_macOS（P3.2 实现）
//       .personal  → PersonalView_macOS（P3.3 实现）
//       .company   → CompanyView_macOS（P3.3 实现）
//       .calendar  → CalendarView_macOS（P3.4 实现）
//
// P4 起：在 `.task` 中初始化 HeadsUpService / YesterdayMissedService（拿到 modelContext 后）
// + NotificationService（无状态，每次用都现 new 也行）。HeadsUpService 与
// YesterdayMissedService 通过 `.environment` 注入到 subviews，MainView_macOS 在构造
// MainViewModel 时取出注入到 VM 里。NotificationService 启动时申请授权 +
// scheduleAll；后续 SettingsViewModel.headsUpLeadMinutes 变化 / Event CRUD 时
// 重新 scheduleAll（订阅在本 View 用 `.onChange` 实现）。

import SwiftUI
import SwiftData
import AppKit
import LinoJCore

struct RootWindow: View {

    /// 从环境拿 router（由 LinoJ_macOSApp 注入）。
    @Environment(TabRouter.self) private var router

    /// 从环境拿 SwiftData ModelContext（由 `.modelContainer(...)` 注入）。
    @Environment(\.modelContext) private var modelContext

    /// P4：service 容器。`.task` 中拿到 modelContext 后填字段。
    /// 用 @State 让 SwiftUI 持有同一实例；wrapper 自身是 @Observable，
    /// 字段变化时子 View 自动刷新。
    @State private var services = AppServices()

    /// P4：SettingsViewModel 实例 —— 用于读 `headsUpLeadMinutes` 给 NotificationService。
    /// 这里只读 lead minutes，不绑 UI（Settings sheet 自己 own 一个 vm）。
    @State private var settings = SettingsViewModel()

    /// `@Query` 当前所有 Event —— 仅用于 onChange 触发 re-schedule。
    @Query private var allEvents: [Event]

    var body: some View {
        // 需要把 router 的属性给 Picker 做 `selection:` Binding；
        // `@Environment(TabRouter.self)` 拿到的是只读视角，
        // `@Bindable` 把 `@Observable` 引用类型暴露成可 binding 的 wrapper。
        @Bindable var router = router

        VStack(spacing: 0) {
            // V4：顶栏三段式，对齐 direction-a.jsx 的 macOS window chrome（AWindow 顶栏）。
            // 设计稿原结构是单行 HStack（traffic lights → wordmark → tabs → flex spacer →
            // Search pill → + New），其中彩色 dot 是 macOS 系统红绿灯（由窗口系统原生提供，
            // 我们不绘制）。V4 在 wordmark 右侧补一个语义状态 dot（v1.0 暂为中性色）。
            //
            // 设计稿数值：顶栏 height 44；padding 0 16；wordmark 13pt/600/-0.01em；
            // tab marginLeft 16；Search pill chip 背景 + radius 7 + minWidth 200 + ⌘K mono hint；
            // + New ink 按钮（背景 ink、文字 bg、radius 7、"+" 14pt）。
            toolbar(router: router)

            // 主内容区：按 router.current switch。切 tab 不要动画（README NON-NEGOTIABLE: instant）。
            // ⚠️ 必须 .topLeading：默认 ZStack 是 .center，会把「没填满容器」的子视图垂直/水平居中
            // （Calendar 曾因此出现星期表头上下均等空白）。topLeading 对已填满的 Main/Personal/Company 无副作用。
            ZStack(alignment: .topLeading) {
                Color.lj.bg.ignoresSafeArea()
                switch router.current {
                case .main:
                    MainView_macOS()
                case .personal:
                    PersonalView_macOS()
                case .company:
                    CompanyView_macOS()
                case .calendar:
                    CalendarView_macOS()
                case .inspiration:
                    // U0：第 5 个 case 的最小占位，保持 switch 穷举编译绿。
                    // 顶栏暂未接线第 5 个 tabButton（U3 接），故该分支当前不可达；
                    // 真实灵感 UI 在 U3/U4 实现。占位仅渲背景，避免空 body 类型问题。
                    Color.lj.bg.ignoresSafeArea()
                }
            }
        }
        // W7.3 迭代：顶栏 VStack 必须吃掉顶部 title-bar 安全区，让 44pt 顶栏带贴到窗口最顶。
        // 否则即使 hiddenTitleBar，VStack 仍尊重顶部安全区 → 顶栏带被下推 ~28pt（title bar 高度），
        // 红绿灯浮在带之上形成「交错」（调试边框截图实证）。吃掉后带 content 中线≈22pt 与红绿灯对齐。
        .ignoresSafeArea(.container, edges: .top)
        // V4 修订：把系统红绿灯垂直居中到 44pt 顶栏中线（hiddenTitleBar 下默认偏上）。
        // 零尺寸 NSView accessor，clamp 保证最坏情况不把按钮挪出标题栏。
        .background(TrafficLightConfigurator(barHeight: 44))
        // P4：service 容器注入子树。AppServices 是 @Observable，子 View 在 services.headsUp
        // 从 nil 变成实际 service 时会自动重渲。
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
            // 通知授权 + 首次 scheduleAll。
            // W2：systemBannerEnabled 是本地通知横幅的总闸门 —— OFF 时既不申请也不调度，
            // 并清掉可能已排队的（防御性，覆盖上次启动 ON、本次关掉的场景）。
            let notifier = NotificationService()
            if settings.systemBannerEnabled {
                let granted = await notifier.requestAuthorization()
                if granted {
                    await notifier.scheduleAll(events: allEvents, leadMinutes: settings.headsUpLeadMinutes)
                }
            } else {
                await notifier.cancelAll()
            }
        }
        // W2：systemBannerEnabled 切换闸门 —— ON 重新 scheduleAll；OFF cancelAll 清空 pending。
        .onChange(of: settings.systemBannerEnabled) { _, enabled in
            Task {
                let notifier = NotificationService()
                if enabled {
                    let granted = await notifier.requestAuthorization()
                    if granted {
                        await notifier.scheduleAll(events: allEvents, leadMinutes: settings.headsUpLeadMinutes)
                    }
                } else {
                    await notifier.cancelAll()
                }
            }
        }
        // Settings 中 lead minutes 改变时 re-schedule。SettingsViewModel 的字段是
        // @Observable 属性 —— `.onChange(of:)` 能追踪到。
        // W2：systemBannerEnabled OFF 时不重排（总闸门关着，调度无意义）。
        .onChange(of: settings.headsUpLeadMinutes) { _, newValue in
            guard settings.systemBannerEnabled else { return }
            Task {
                await NotificationService().scheduleAll(events: allEvents, leadMinutes: newValue)
            }
        }
        // Event CRUD（新增 / 删除）后 re-schedule。监听总数变化即可覆盖增删；
        // I8: 额外监听所有 event.start 数组变化，覆盖 "事件被编辑了 start 时间" 的场景。
        // 即使 v0.9 没有事件编辑入口，未来 P6 之后追加编辑界面时这套监听已经就位。
        // 注意：[Date] 是 Equatable & Hashable 可被 onChange 追踪。每次任意事件 start
        // 改变都会触发 re-schedule，这是预期行为（NotificationService.scheduleAll 内部
        // 也是全量 removeAll + add）。
        // W2：同样受 systemBannerEnabled 总闸门约束。
        .onChange(of: allEvents.count) { _, _ in
            guard settings.systemBannerEnabled else { return }
            Task {
                await NotificationService().scheduleAll(events: allEvents, leadMinutes: settings.headsUpLeadMinutes)
            }
        }
        .onChange(of: allEvents.map(\.start)) { _, _ in
            guard settings.systemBannerEnabled else { return }
            Task {
                await NotificationService().scheduleAll(events: allEvents, leadMinutes: settings.headsUpLeadMinutes)
            }
        }
        // P3.6：Quick Add modal。系统 .sheet 自带遮罩与阴影；尺寸由 QuickAddModal_macOS
        // 内部 `.frame(width: 520, height: 480)` 锁定。esc 默认 dismiss，⌘↵ 由 Create 按钮接管。
        .sheet(isPresented: $router.showQuickAdd) {
            QuickAddModal_macOS()
                .environment(router)
        }
        // P3.7：Search palette。⌘K 翻 router.showSearch；内部 640×540 锁尺寸。
        // ↑↓ 切高亮、↵ open、esc 默认 dismiss。
        .sheet(isPresented: $router.showSearch) {
            SearchPalette_macOS()
                .environment(router)
        }
        // P3.8：Settings sheet。⌘, 翻 router.showSettings；内部 760×540 锁尺寸。
        // esc 默认 dismiss。VM 自带 UserDefaults 持久化。
        .sheet(isPresented: $router.showSettings) {
            SettingsView_macOS()
                .environment(router)
                // V1/V3：显式把 AppServices 传给 Settings sheet（CloudSyncMonitor + AppleSignInService）。
                // sheet 默认继承环境，这里显式传一份保证可读性与与 iOS 路径对称。
                .environment(services)
        }
    }

    // MARK: - V4 顶栏

    /// macOS 顶栏单行布局（左聚簇）：左 wordmark + 状态 dot + 紧跟的 4-tab Picker；
    /// 中间单个 Spacer；右 Search pill + "+ New" ink 按钮。对齐 direction-a.jsx 的 AWindow chrome。
    @ViewBuilder
    private func toolbar(router: TabRouter) -> some View {
        // Picker selection 需要一个 Binding<AppTab>；@Bindable 把 @Observable 引用暴露成可 binding。
        @Bindable var router = router
        HStack(spacing: LJSpacing.s12) {
            // 左：wordmark + 状态 dot。
            wordmark()

            // 左聚簇：自定义 4-tab 按钮（对齐 direction-a.jsx 第 94-112 行）。
            // active = chip 灰底 + ink 字 + 600；inactive = 透明 + inkSoft + 500；
            // padding 5×11、radius 7、fontSize 12.5、tab 间距 2。
            // 不用 .pickerStyle(.segmented)——那是 macOS 蓝底系统控件，与设计稿不符。
            HStack(spacing: 2) {
                tabButton(.main, LJStrings.tabMain, router: router)
                tabButton(.personal, LJStrings.tabPersonal, router: router)
                tabButton(.company, LJStrings.tabCompany, router: router)
                tabButton(.calendar, LJStrings.tabCalendar, router: router)
            }
            .padding(.leading, LJSpacing.s4)   // wordmark→tab ≈16pt（HStack spacing 12 + 4）

            // 单个 Spacer 把 Search + New 推到最右；tabs 留在左侧。
            Spacer(minLength: LJSpacing.s16)

            // 右：Search or jump + New。
            searchButton(router: router)
            newButton(router: router)
        }
        // 左侧留出 macOS 红绿灯（traffic lights）宽度，让 wordmark 紧跟其右、同排融合。
        // 窗口用 .hiddenTitleBar，红绿灯浮在内容左上；~78pt 足够清开三枚按钮。
        .padding(.leading, 78)
        .padding(.trailing, LJSpacing.s16)
        .frame(height: 44)
        .background(Color.lj.bg)
        // 顶栏下沿一条极细分隔线，与设计稿 chrome 一致（0.5px solid border）。
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.lj.border)
                .frame(height: 0.5)
        }
    }

    /// 单个 tab 按钮。对齐 direction-a.jsx：active=chip 底+ink 字+semibold，inactive=透明+inkSoft+medium。
    @ViewBuilder
    private func tabButton(_ tab: AppTab, _ label: LocalizedStringResource, router: TabRouter) -> some View {
        let isActive = router.current == tab
        Button {
            router.current = tab
        } label: {
            Text(label)
                .font(.system(size: 12.5, weight: isActive ? .semibold : .medium))
                .tracking(-0.06)   // -0.005em @ 12.5pt
                .foregroundStyle(isActive ? Color.lj.ink : Color.lj.inkSoft)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isActive ? Color.lj.chip : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// 左侧：「LinoJ」文字 logo（品牌名不翻译）+ 语义状态 dot。
    /// 设计稿 wordmark：A_DISPLAY 13pt / weight 600 / letterSpacing -0.01em / 色 ink。
    /// 状态 dot：设计稿顶栏的彩色圆点是系统红绿灯（不由 App 绘制），V4 plan 要求另置一个
    /// 反映同步状态的语义 dot。0.9.1：接上 CloudSyncMonitor.status（与 SettingsView_macOS 的
    /// sync pill dot 同一套颜色映射）。还原 6pt 小圆点。
    @ViewBuilder
    private func wordmark() -> some View {
        HStack(spacing: LJSpacing.s6) {
            Text(verbatim: "LinoJ")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .tracking(-0.13)   // -0.01em @ 13pt ≈ -0.13pt
                .foregroundStyle(Color.lj.ink)
            // 状态 dot —— 接 CloudSyncMonitor：syncing=蓝 / synced=绿 / error=红 / idle / nil / 本地=中性。
            Circle()
                .fill(syncDotColor)
                .frame(width: 6, height: 6)
        }
    }

    /// 0.9.1：顶栏状态 dot 颜色 —— 跟随 services.cloudSyncMonitor.status。
    /// 与 SettingsView_macOS.syncDotColor 同一套映射；monitor 为 nil / idle / 本地模式时用中性色。
    private var syncDotColor: Color {
        guard let status = services.cloudSyncMonitor?.status else {
            return Color.lj.inkDim
        }
        switch status {
        case .syncing:  return Color.lj.blue
        case .synced:   return Color(red: 0.098, green: 0.764, blue: 0.196)   // #19c332
        case .error:    return Color(red: 0.86, green: 0.18, blue: 0.18)
        case .idle:     return Color.lj.inkDim
        }
    }

    /// 右侧 Search pill：放大镜 icon + "Search or jump" + ⌘K mono hint。
    /// 点击翻 router.showSearch（与 ⌘K 同路径）。设计稿：chip 背景 / radius 7 / minWidth 200。
    @ViewBuilder
    private func searchButton(router: TabRouter) -> some View {
        Button {
            router.showSearch = true
        } label: {
            HStack(spacing: LJSpacing.s8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.lj.inkSoft)
                Text(LJStrings.toolbarSearchOrJump)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lj.inkSoft)
                Spacer(minLength: LJSpacing.s8)
                Text(verbatim: "⌘K")
                    .font(.lj.mono)
                    .foregroundStyle(Color.lj.inkMute)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.lj.chip)
                    )
            }
            .padding(.horizontal, LJSpacing.s10)
            .frame(width: 200, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.lj.chip)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LJStrings.a11ySearch))
    }

    /// 右侧 "+ New" ink 按钮：点击翻 router.showQuickAdd（默认 Todo，与 ⌘N 同路径）。
    /// 设计稿：背景 ink、文字 bg、radius 7、"+" 14pt。
    @ViewBuilder
    private func newButton(router: TabRouter) -> some View {
        Button {
            router.quickAddDefaultKind = .todo
            router.showQuickAdd = true
        } label: {
            HStack(spacing: LJSpacing.s6) {
                Text(verbatim: "+")
                    .font(.system(size: 14, weight: .semibold))
                Text(LJStrings.toolbarNew)
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(Color.lj.bg)
            .padding(.horizontal, LJSpacing.s12)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.lj.ink)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LJStrings.a11yQuickAdd))
    }

    @ViewBuilder
    private func placeholder(label: LocalizedStringResource) -> some View {
        // P0 占位渲染 —— P5 之后已经替换为真实 Screen，但保留这个 helper 以防未来回滚使用。
        Text(label)
            .ljSectionHeaderStyle()
            .foregroundStyle(Color.lj.inkMute)
    }
}

// MARK: - 红绿灯垂直居中（hiddenTitleBar unified chrome）

/// 把窗口的三枚 traffic light 按钮垂直居中到指定高度的顶栏中线。
/// `.hiddenTitleBar` 下系统默认把红绿灯放在标准 ~28pt 标题栏中线（偏上），
/// 这里把它们下移到 44pt 自定义顶栏的视觉中线，与 wordmark / tabs 同排对齐。
/// 零尺寸 NSView，拿到 window 后重排；监听 didResize / 进出全屏重新应用。
private struct TrafficLightConfigurator: NSViewRepresentable {
    var barHeight: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.barHeight = barHeight
        DispatchQueue.main.async { context.coordinator.attach(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.barHeight = barHeight
        DispatchQueue.main.async { context.coordinator.attach(nsView.window) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var barHeight: CGFloat = 44
        private weak var window: NSWindow?
        private var tokens: [NSObjectProtocol] = []

        func attach(_ window: NSWindow?) {
            guard let window else { return }
            if window !== self.window {
                tokens.forEach { NotificationCenter.default.removeObserver($0) }
                tokens.removeAll()
                self.window = window
                // W7.3：消除窗口最左/顶部边缘的细线伪影 —— hiddenTitleBar 下 AppKit 仍可能在
                // titlebar 容器与内容交界处绘制一条 separator/border。强制关闭 titlebar 分隔线。
                window.titlebarSeparatorStyle = .none
                let nc = NotificationCenter.default
                for name in [NSWindow.didResizeNotification,
                             NSWindow.didEnterFullScreenNotification,
                             NSWindow.didExitFullScreenNotification] {
                    tokens.append(nc.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                        self?.reposition()
                    })
                }
            }
            reposition()
        }

        private func reposition() {
            guard let window, let contentView = window.contentView else { return }
            let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            let buttons = types.compactMap { window.standardWindowButton($0) }
            guard let container = buttons.first?.superview else { return }

            // W7.3：以「窗口内容顶部」为基准把红绿灯中心对齐到 44pt 顶栏视觉中线（顶向下 barHeight/2），
            // 而非相对红绿灯所在容器（系统 titlebar 容器，真实高 ≈28pt、与 44pt 顶栏顶部不重合）的中线居中。
            // 旧实现用 container.bounds.height 当 44pt 顶栏高度 → 按钮被定位到系统标题栏中线（偏上、像两层交错）。
            // contentView 在 hiddenTitleBar / fullSizeContentView 下铺满整窗，其 bounds 顶即窗口内容顶。
            // AppKit 自下而上：view.frame.origin.y 是底边，center = origin.y + height/2，顶边 = bounds.maxY。
            let contentTopY = contentView.bounds.maxY                 // 窗口内容顶部（contentView 坐标系）
            let desiredCenterInContent = NSPoint(x: 0, y: contentTopY - barHeight / 2)
            // 转换到红绿灯容器坐标系，逐枚把按钮垂直中心对齐到该点。
            let desiredCenterInContainer = container.convert(desiredCenterInContent, from: contentView)

            for button in buttons {
                let bh = button.frame.height
                let raw = desiredCenterInContainer.y - bh / 2
                // clamp 放宽：仅防止把按钮挪到容器底之下（负值）或顶之上溢出；正常 22pt 中线落在容器内。
                let upperBound = max(0, container.bounds.height - bh)
                let newY = max(0, min(upperBound, raw))
                if abs(button.frame.origin.y - newY) > 0.5 {
                    button.setFrameOrigin(NSPoint(x: button.frame.origin.x, y: newY))
                }
            }
        }
    }
}
