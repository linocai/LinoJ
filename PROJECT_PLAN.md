# LinoJ — PROJECT_PLAN

## 项目概述

LinoJ 是一款 macOS + iOS 原生 SwiftUI 个人规划器，核心理念是把「有时间的事件 (Calendar)」与「无时间的待办 (Todos)」清晰分开。四个 Tab：Main（聚合日视图）、Personal（个人 Todos）、Company（工作 Todos + Projects）、Calendar（事件）。设计稿与功能规范以 `design_handoff_linoj/README.md` 为唯一真理源；本计划忠实于其 NON-NEGOTIABLE 设计原则（Todos 永不带时间；Events 必带时间、地点、人；Urgency 只有 urgent/normal 两级；Projects 只属于 Company；时间只通过 Heads-up 渗入 Main；外观跟随系统）。

## 目标版本

- **v0.9**（本计划全部 Phase 范围）：所有 UI / 交互 / 本地数据 / 本地通知跑通，不带任何云能力。在免费个人 Apple ID 证书下可在真机和模拟器运行。
- **v1.0**（本计划文末「v1.0 待办」清单，不展开 Phase）：付费 Developer 账号下发后追加 CloudKit 同步、远程推送、EventKit 真接入、Sign in with Apple 等。

---

## 技术选型（已敲定，不留给施工 agent 选择）

1. **项目结构**：Xcode workspace `LinoJ.xcworkspace` + 两个独立 App target `LinoJ-macOS` / `LinoJ-iOS` + 一个共享 Swift Package `LinoJCore`（models / persistence / view models / design tokens / shared view modifiers）。手工用 Xcode 创建 `.xcodeproj` 与 `.xcworkspace` 并提交到仓库，不使用 XcodeGen / Tuist。
2. **最低系统**：iOS 26.0 + macOS 26.0（为获得原生 `.glassEffect()` / Liquid Glass —— README NON-NEGOTIABLE）。Swift 语言版本：Swift 6（在 LinoJCore 用 Swift Concurrency strict mode）。
3. **持久化**：SwiftData（`@Model` 声明式）。所有持久层 API 在 LinoJCore 中以 `ModelContainer` / `ModelContext` 暴露；UI 用 `@Query` 读取。
4. **外部集成**：v0.9 全部仅 UI 占位 —— Settings 中的 iCloud sync / Apple Calendar mirror / Apple Reminders mirror toggle 都只是展示态，不真接通；本地通知 (`UNUserNotificationCenter`) **真接通** 用于 Heads-up 提醒。
5. **Bundle ID**：`com.example.linoj.macos` / `com.example.linoj.ios`（上架前再改）。
6. **本地化**：中英双语，用 String Catalog (`Localizable.xcstrings`)，资源放在 LinoJCore。所有用户可见字符串走 `LocalizedStringKey` / `String(localized:)`；不允许 raw `String` 字面量出现在 UI 文本上。
7. **示例数据**：DEBUG 构建启动时自动 seed，把 `design_handoff_linoj/data.js` 内容翻译成 Swift fixtures，放在 LinoJCore 的 `#if DEBUG` 编译块中（`SeedData.swift`）。Release 构建启动 Inbox zero。
8. **iCloud toggle 默认状态**：UI 上默认 ON（视觉为开），底层不接 CloudKit。
9. **测试**：仅 LinoJCore 加一个 Unit Test target `LinoJCoreTests`，覆盖：数据模型（Todo/Project/Event CRUD、scope 约束）、计数器（open / urgent / done / events today）、Heads-up 触发逻辑、Yesterday-missed 计算、状态机（todo 切换 done / urgency、project 删除级联）。App target 不加 UI Test。
10. **施工顺序**：先把 macOS 全部 Phase 跑通，再启动 iOS。共享 Phase（LinoJCore、Design Tokens）服务两端，但首次实现验收以 macOS 为准；iOS 复用时若发现需要扩展 LinoJCore，回到共享 Phase 增量。

辅助决策（贯穿全 Phase）：
- 视图层架构：MVVM。ViewModel 是 `@Observable` final class（Swift Macros），不放在 SwiftData `@Model` 上。
- 颜色定义：在 `LinoJCore/DesignSystem/Colors.swift` 集中，所有色值通过 `Color.lj.*` 访问，按 light/dark 双 set 自动响应 `colorScheme`。
- 字体：在 `LinoJCore/DesignSystem/Typography.swift` 定义 `Font.lj.*` 静态成员，按平台返回不同 size。
- 间距：在 `LinoJCore/DesignSystem/Spacing.swift` 暴露 `LJSpacing.s4 / s8 / s12 / s16 / s18 / s22 / s28 / s32` 等。
- View modifier：`.bubbleStyle(urgent:)` / `.cardStyle()` / `.completedBoxStyle()` 等放 `LinoJCore/DesignSystem/Modifiers.swift`。

---

## 免费证书约束

**禁用（v0.9 不得引入）：**
- CloudKit / iCloud key-value / iCloud Documents（任何 `iCloud.*` entitlement）
- Push Notifications / APNs / Remote Notifications
- Sign in with Apple
- App Groups
- Associated Domains（Universal Links / Web Credentials）
- Network Extensions / Family Controls / HomeKit 等付费能力
- 任何会让 provisioning profile 包含付费 capability 的 entitlement

**允许（v0.9 可用）：**
- `UNUserNotificationCenter` 本地通知（用于 Heads-up 提前 30 分钟提醒，配合 `UNTimeIntervalNotificationTrigger` / `UNCalendarNotificationTrigger`）
- App Sandbox（macOS 强制开启，标准沙盒文件 IO 即可）
- 本地文件系统、`UserDefaults`、SwiftData 本地容器
- EventKit 框架（v0.9 不接，但 import 不会触发付费 entitlement）
- SF Symbols、StoreKit local config 文件
- macOS Hardened Runtime（默认开）

**Capability 配置硬规则：**
- LinoJ-macOS.entitlements：`com.apple.security.app-sandbox = YES`，其它一律不开。
- LinoJ-iOS.entitlements：留空文件（不开任何 capability）。
- v1.0 单开 PR 引入云相关 entitlement，v0.9 PR 一旦发现误开必须 revert。

---

## 文件 / 模块结构总览

```
LinoJ/
├── LinoJ.xcworkspace
├── LinoJ-macOS/                       # macOS App target
│   ├── LinoJ_macOSApp.swift           # @main，注入 ModelContainer
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── LinoJ-macOS.entitlements   # 仅 app-sandbox
│   ├── App/
│   │   ├── RootWindow.swift           # NSWindow 配置 + 顶栏 Picker
│   │   ├── TabRouter.swift            # macOS Tab 路由 (@Observable)
│   │   └── KeyboardShortcuts.swift    # ⌘1..4 / ⌘K / ⌘N 等
│   └── Screens/
│       ├── Main/MainView_macOS.swift
│       ├── Personal/PersonalView_macOS.swift
│       ├── Company/CompanyView_macOS.swift
│       ├── Calendar/CalendarView_macOS.swift
│       ├── ProjectDetail/ProjectDetailView_macOS.swift
│       ├── QuickAdd/QuickAddModal_macOS.swift
│       ├── Search/SearchPalette_macOS.swift
│       └── Settings/SettingsView_macOS.swift
├── LinoJ-iOS/                         # iOS App target
│   ├── LinoJ_iOSApp.swift
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── LinoJ-iOS.entitlements     # 空
│   ├── App/
│   │   ├── RootTabView.swift          # TabView + glass tab bar
│   │   └── FloatingActions.swift      # 右上两枚 glass 按钮
│   └── Screens/
│       ├── Main/MainView_iOS.swift
│       ├── Personal/PersonalView_iOS.swift
│       ├── Company/CompanyView_iOS.swift
│       ├── Calendar/CalendarView_iOS.swift
│       ├── ProjectDetail/ProjectDetailView_iOS.swift
│       ├── QuickAdd/QuickAddSheet_iOS.swift
│       ├── Search/SearchSheet_iOS.swift
│       └── Settings/SettingsSheet_iOS.swift
└── Packages/
    └── LinoJCore/
        ├── Package.swift
        ├── Sources/LinoJCore/
        │   ├── Models/
        │   │   ├── Todo.swift          # @Model
        │   │   ├── Project.swift       # @Model
        │   │   ├── Event.swift         # @Model
        │   │   ├── Person.swift        # @Model
        │   │   └── Enums.swift         # Urgency, Scope, AppTab
        │   ├── Persistence/
        │   │   ├── ModelContainer+LinoJ.swift
        │   │   └── SeedData.swift      # #if DEBUG fixtures
        │   ├── ViewModels/
        │   │   ├── MainViewModel.swift
        │   │   ├── PersonalViewModel.swift
        │   │   ├── CompanyViewModel.swift
        │   │   ├── CalendarViewModel.swift
        │   │   ├── ProjectDetailViewModel.swift
        │   │   ├── QuickAddViewModel.swift
        │   │   ├── SearchViewModel.swift
        │   │   └── SettingsViewModel.swift
        │   ├── Services/
        │   │   ├── HeadsUpService.swift
        │   │   ├── NotificationService.swift
        │   │   └── YesterdayMissedService.swift
        │   ├── DesignSystem/
        │   │   ├── Colors.swift
        │   │   ├── Typography.swift
        │   │   ├── Spacing.swift
        │   │   ├── Radii.swift
        │   │   ├── Modifiers.swift
        │   │   └── Components/
        │   │       ├── TodoBubble.swift
        │   │       ├── ProjectCard.swift
        │   │       ├── EventCard.swift
        │   │       ├── HeadsUpAlert.swift
        │   │       ├── CompletedBox.swift
        │   │       ├── EmptyState.swift
        │   │       └── AvatarStack.swift
        │   └── Localization/
        │       └── Localizable.xcstrings   # 中英 string catalog
        └── Tests/LinoJCoreTests/
            ├── ModelTests.swift
            ├── CountersTests.swift
            ├── HeadsUpServiceTests.swift
            ├── YesterdayMissedTests.swift
            └── SeedDataTests.swift
```

---

## Phase 列表

依赖关系示意：P0 → P1 → P2 → (P3a..P3e 串行，每个里 macOS 先做完再做 iOS 对应小节) → P4 → P5 → P6 → P7。

每个 Phase 内若涉及 iOS 与 macOS，先完成 macOS 验收，再做 iOS。

---

### P0 — 项目骨架与 capability 净化  [全栈 / 共享]

**范围：**
- 用 Xcode 手工创建 `LinoJ.xcworkspace`，内含：
  - `LinoJ-macOS.xcodeproj`（macOS App，SwiftUI lifecycle，Min deployment 26.0）
  - `LinoJ-iOS.xcodeproj`（iOS App，SwiftUI lifecycle，Min deployment 26.0）
  - `Packages/LinoJCore`（Swift Package，platforms: `.macOS(.v26), .iOS(.v26)`，Swift 6 strict concurrency）
- 两个 App target 都依赖 `LinoJCore`。
- macOS entitlements 只开 `com.apple.security.app-sandbox`；iOS entitlements 留空。
- 配置 Bundle ID：`com.example.linoj.macos` / `com.example.linoj.ios`。
- 配置 Signing：Team = Personal Team / "Sign to Run Locally"，所有 capability 列表为空（macOS 仅 sandbox）。
- 提交 `.xcworkspace` / `.xcodeproj` / `Package.swift` 到仓库；`.gitignore` 标准 Xcode 排除（DerivedData、`xcuserdata`、`*.xcuserstate`）。
- LinoJCore 暴露一个空 `public struct LinoJCore { public static let version = "0.9.0" }`。
- 两个 App `ContentView` 显示 "LinoJ <version>" 文本，验证 LinoJCore 链接成功。

**关键接口 / 类型契约：**

```swift
// Packages/LinoJCore/Sources/LinoJCore/LinoJCore.swift
public enum LinoJCore {
    public static let version: String = "0.9.0"
}
```

```swift
// LinoJ-macOS/LinoJ_macOSApp.swift
@main
struct LinoJ_macOSApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .windowStyle(.titleBar)
            .defaultSize(width: 1200, height: 720)
            .windowResizability(.contentMinSize)
    }
}
```

**验收标准：**
- macOS App 在本地 Xcode 用免费个人 Apple ID 签名后可在真机 Mac 上运行，显示 "LinoJ 0.9.0"。
- iOS App 在免费个人 Apple ID 签名后可在模拟器与已注册的真机 iPhone 上运行，显示 "LinoJ 0.9.0"。
- `LinoJCoreTests` 跑通空 test（仅证明 test target 链接成功）。
- Xcode Capabilities 页面：macOS 仅显示 App Sandbox（默认勾），iOS 列表为空，无任何 iCloud / Push 等条目。
- `swift build` 在 LinoJCore 目录单独跑得通（不依赖 Xcode）。

**前置依赖：** 无。

---

### P1 — 数据模型 + SwiftData 持久层 + 示例数据 seed  [共享]

**范围：**
- 在 LinoJCore 定义所有 `@Model` 类型：`Todo`, `Project`, `Event`, `Person`，以及枚举 `Urgency`, `Scope`, `AppTab`。
- 定义 `ModelContainer+LinoJ` 工厂，App 启动时调用注入。
- `#if DEBUG` 实现 `SeedData.seedIfEmpty(_:)`：检测容器为空时把 `data.js` 全部内容写入（包含 yesterday events）。Release 构建该函数体为空。
- 单元测试覆盖 CRUD、关系完整性。

**关键接口 / 类型契约：**

```swift
public enum Urgency: String, Codable, CaseIterable, Sendable { case urgent, normal }
public enum Scope: String, Codable, CaseIterable, Sendable { case personal, company }
public enum AppTab: String, Codable, CaseIterable, Sendable { case main, personal, company, calendar }

@Model public final class Person {
    public var id: UUID
    public var name: String               // 首字母作为 avatar initial
    public init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
    public var initial: String { String(name.prefix(1)).uppercased() }
}

@Model public final class Project {
    public var id: UUID
    public var title: String
    public var intro: String              // 1-2 句
    public var notes: String              // 长文，white-space pre-line
    public var tag: String                // free-form 状态标签
    @Relationship public var members: [Person]
    public var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \Todo.project) public var todos: [Todo]
    @Relationship(deleteRule: .nullify, inverse: \Event.project) public var events: [Event]
    public init(id: UUID = UUID(), title: String, intro: String, notes: String, tag: String, members: [Person], createdAt: Date)
}

@Model public final class Todo {
    public var id: UUID
    public var title: String
    public var urgencyRaw: String         // store enum raw
    public var scopeRaw: String
    @Relationship public var project: Project?    // nil = standalone or personal
    public var done: Bool
    public var createdAt: Date
    public var urgency: Urgency { get set }       // computed wrapper
    public var scope: Scope { get set }
    public init(id: UUID = UUID(), title: String, urgency: Urgency, scope: Scope, project: Project? = nil, done: Bool = false, createdAt: Date = .now)
}

@Model public final class Event {
    public var id: UUID
    public var title: String
    public var start: Date
    public var end: Date
    public var location: String
    @Relationship public var attendees: [Person]
    @Relationship public var project: Project?
    public var attendedConfirmed: Bool    // for "From yesterday" check
    public init(id: UUID = UUID(), title: String, start: Date, end: Date, location: String, attendees: [Person] = [], project: Project? = nil, attendedConfirmed: Bool = false)
}

public enum LinoJStore {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer
}

#if DEBUG
public enum SeedData {
    public static func seedIfEmpty(_ context: ModelContext) throws
    public static func todaySimulated() -> Date    // 2026-05-27 09:00 local
}
#endif
```

**验收标准：**
- LinoJCoreTests `ModelTests` 通过：能创建/读取/删除每种类型；删除 Project 后其 todos.project 自动变 nil；attendees / members 关系双向可遍历。
- DEBUG 构建启动后查询 `Todo` 数量 = 16（personal 7 + work 9），`Project` = 3，`Event` = 18（本周 e1-e16 共 16 + yesterday y1/y2 共 2），`Person` 去重后 = 8（L、M、A、J、K、Mom、Dad、Andrew —— data.js 实际 token 总数）。
- Release 构建启动后查询全部 = 0（Inbox zero）。
- `Event.start.day` 与 `data.js` 中 `day: 'Tue'..'Mon2'` 一一对应（Tue=2026-05-27，按 weekDays 表推算），小数小时转 `HH:mm`（如 9.5 → 09:30）。
- 测试 `SeedDataTests.testHoursDecimalConversion()` 通过。

**前置依赖：** P0。

---

### P2 — Design System：colors / typography / spacing / 共享 modifier / 基础组件  [共享]

**范围：**
- 在 LinoJCore/DesignSystem 实现 README 中所有 design token（双 mode color set、type ramp、spacing、radii、shadow）。
- 实现可跨平台的基础 SwiftUI 组件 + view modifier。组件 API 必须既适用 macOS 也适用 iOS（用 `#if os(...)` 切换尺寸）。
- 不实现具体业务视图，只交付原子组件。组件需要一个 SwiftUI Preview Sample 文件（`#Preview` macros），方便施工时目检。

**关键接口 / 类型契约：**

```swift
public extension Color {
    enum LJ {                       // 通过 Color.lj.bg 访问
        public static var bg: Color
        public static var bgSoft: Color
        public static var panel: Color
        public static var border: Color
        public static var borderStrong: Color
        public static var ink: Color
        public static var inkSoft: Color
        public static var inkMute: Color
        public static var inkDim: Color
        public static var chip: Color
        public static var blue: Color
        public static var blueInk: Color
        public static var blueSoft: Color
        public static var blueSofter: Color
        public static var blueBorder: Color
        public static var iosMainBg: Color    // #f4f3ef
    }
    static var lj: LJ.Type { LJ.self }
}

public extension Font {
    enum LJ {
        public static func displayTitle() -> Font           // 26 macOS / 34 iOS
        public static func sectionHeader() -> Font          // 17
        public static func cardTitle() -> Font              // 13-17 macOS / 13-16 iOS
        public static func bubbleUrgent() -> Font           // 14.5 / 15.5 weight .semibold
        public static func bubbleNormal() -> Font           // 13.5 / 14.5 weight .medium
        public static func body() -> Font
        public static func caption() -> Font
        public static func tag() -> Font                    // uppercase
        public static func mono() -> Font                   // SF Mono, tabular-nums
    }
    static var lj: LJ.Type { LJ.self }
}

public enum LJSpacing {
    public static let s4: CGFloat = 4
    public static let s6: CGFloat = 6
    public static let s8: CGFloat = 8
    public static let s10: CGFloat = 10
    public static let s12: CGFloat = 12
    public static let s14: CGFloat = 14
    public static let s16: CGFloat = 16
    public static let s18: CGFloat = 18
    public static let s22: CGFloat = 22
    public static let s28: CGFloat = 28
    public static let s32: CGFloat = 32
}

public enum LJRadii {
    public static let chip: CGFloat = 8
    public static let card: CGFloat = 12
    public static let modalMac: CGFloat = 14
    public static let modalIOS: CGFloat = 24
    public static let pill: CGFloat = 999
}

public extension View {
    func ljBubbleStyle(urgent: Bool) -> some View
    func ljCardStyle() -> some View
    func ljCompletedBoxStyle() -> some View
    func ljDashedBorder(color: Color = .lj.borderStrong, radius: CGFloat = LJRadii.card) -> some View
    func ljTagPill() -> some View                   // 灰 chip + UPPERCASE
    func ljHoverLift() -> some View                 // macOS 鼠标 hover -1pt
}

// Components
public struct TodoBubble: View {
    public init(todo: Todo, onToggleDone: @escaping () -> Void)
}
public struct ProjectCard: View {
    public enum Variant { case macStrip, macFull, iosMini, iosFull }
    public init(project: Project, variant: Variant)
}
public struct EventCard: View {
    public enum Variant { case macWeekGrid, macRail, iosMini, iosFull }
    public init(event: Event, variant: Variant)
}
public struct AvatarStack: View {
    public init(people: [Person], max: Int = 5)
}
public struct HeadsUpAlert: View {
    public init(event: Event, minutesUntil: Int, onSnooze: () -> Void, onOpen: () -> Void)
}
public struct CompletedBox<Content: View>: View {
    public init(count: Int, @ViewBuilder content: () -> Content)
}
public struct EmptyState: View {
    public enum Variant { case inboxZero, urgentEmpty, clearWeek, noResults(String) }
    public init(variant: Variant, ctaTitle: String? = nil, action: (() -> Void)? = nil)
}
```

**验收标准：**
- 所有 token 在 light / dark mode 下与 README 的色值一一对应（写一个 `ColorTokensTests.swift` 比对 hex）。
- 每个组件有 SwiftUI Preview，在 macOS 与 iOS 双模拟器（手动各开一次）下能渲染。
- `.bubbleStyle(urgent: true)` 在 light 下背景为 `blueSoft`、左侧 3pt blue accent；在 dark 下颜色对应 dark token set。
- `.ljDashedBorder` 渲染为 1.5pt 虚线。
- LinoJCoreTests 不验证 SwiftUI（无 UI test），但 `ColorTokensTests` 验证 hex 解析正确。

**前置依赖：** P0。可以与 P1 并行，但施工 agent 应先做 P1 再做 P2，便于组件 Preview 直接用 SeedData。

---

### P3 — 各平台屏幕实现（按顺序逐个 Phase）

每个 P3.x 子 Phase 都遵守：**先 macOS 完成验收 → 再 iOS 实现验收**。`SubPhase 3.x-macOS` 与 `SubPhase 3.x-iOS` 视为两段顺序里程碑。

---

#### P3.1 — Tab navigation shell  [macOS → iOS]

**范围 (macOS)：**
- `RootWindow` 内顶部一行 `Picker` segmented control（Main / Personal / Company / Calendar），宽度自适应居中。`TabRouter: @Observable` 持有当前 `AppTab`。
- 键盘快捷键：⌘1..⌘4 切 tab、⌘K（占位打开空 Search palette）、⌘N（占位 Quick Add）、⌘,（占位 Settings）。每个目前路由到空 `Text("\(tab) placeholder")` 视图。
- 最小窗口 1200×720，标题栏样式 `.titleBar`，背景 `Color.lj.bg`。

**范围 (iOS)：**
- `RootTabView` 使用 `TabView` 但隐藏系统 tab bar，自定义底部浮动 capsule（`.glassEffect()`）含四个 SF Symbol 按钮（house / person / briefcase / calendar）。capsule 距左右各 14pt，距 home indicator 24pt。
- 右上角两枚 40pt 圆形 glass 按钮：`magnifyingglass` + `+`（点击占位 print）。
- 内容区先放 `Text("\(tab) placeholder")`。

**关键接口 / 类型契约：**

```swift
@Observable public final class TabRouter {
    public var current: AppTab = .main
    public var showSearch: Bool = false
    public var showQuickAdd: Bool = false
    public var showSettings: Bool = false
    public init() {}
}
```

**验收标准：**
- macOS：⌘1..⌘4 切换有效；窗口缩放到 1200×720 以下被阻止；segmented control 选中状态与 router 同步。
- iOS：底部 capsule 在 light/dark 均显示原生 Liquid Glass（不能是手搓 blur）；选中 tab 的 SF Symbol 颜色变 `.lj.ink`，未选中 `.lj.inkMute`。
- 两端切 tab 无动画（README 指定 instant）。

**前置依赖：** P0, P2。

---

#### P3.2 — Main view  [macOS → iOS]

**范围 (macOS)：**
- 两列 grid `1fr 360pt`。左列 vertical stack 16pt gap：可选 HeadsUpAlert（由 `HeadsUpService.currentAlert` 驱动）→ 标题 "To do" 26pt + 计数行（"12 open · 3 urgent"，urgent 数字蓝色）→ 两列 bubble kanban（Urgent / Normal，列内 ScrollView，flex 1 高度）→ 底部 pinned Projects strip（top-border rule，3 行内联条目 `1fr 200pt 110pt`：title+tag+intro / mono stats / AvatarStack）。
- 右栏 360pt：标题 "Next 7 days" + 7 行 day-row（label + date mono + 前 3 个事件，超出 "+N more"）+ 底部 pinned "From yesterday" dashed-border 灰 box（含 checkable rows）。

**范围 (iOS)：**
- 单列 ScrollView。背景 `Color.lj.iosMainBg`。顺序：顶部 padding（让出 floating buttons）→ "To do" 34pt → 单行统计 "X open · Y urgent · Z events today" → 可选 HeadsUpAlert full-width → "Urgent" section header（含 blue dot）+ 蓝色 bubbles 堆叠 → "Normal" section header + 单张白卡内若干 compact row → "Upcoming today" 水平 ScrollView（200pt mini event cards × N）→ "Projects" 水平 ScrollView（240pt mini project cards × N）→ 底部预留 100pt 让出 tab bar。

**关键接口 / 类型契约：**

```swift
@Observable public final class MainViewModel {
    public init(context: ModelContext)
    public var headsUp: HeadsUpAlertModel?
    public var openCount: Int
    public var urgentCount: Int
    public var todayEventsCount: Int
    public var urgentTodos: [Todo]            // scope 不限，done == false, urgency == .urgent
    public var normalTodos: [Todo]            // 同上 normal
    public var todayEvents: [Event]
    public var next7DaysGrouped: [(day: Date, events: [Event])]    // 7 项
    public var yesterdayMissed: [Event]
    public var projects: [Project]
    public func toggleDone(_ todo: Todo)
    public func confirmAttended(_ event: Event)
    public func snoozeHeadsUp()
    public func openHeadsUpEvent()
}

public struct HeadsUpAlertModel: Equatable, Sendable {
    public let eventID: UUID          // 反查 @Model 实例，便于跨 actor 传递
    public let title: String
    public let location: String
    public let minutesUntil: Int      // ≤ 60
}
```

**验收标准：**
- DEBUG 启动 macOS：左列 Urgent 列显示 3 张蓝色 bubble（p5 reply mom、p6 HYSA、w1 expense、w4 sidebar、w5 onboarding 中的 urgent，按 scope 全显示 = 5 张；以 ViewModel 输出为准），Normal 列显示对应 normal 项；Projects strip 显示 LinoJ for macOS v1 / Onboarding redesign / Q3 planning 三行；右栏 Next 7 days 第一行 Today/Tue 27 显示 e1/e2/e3 三场会议 + "+1 more"（because Tue 有 4 场）。
- 模拟时间到 9:20（在 e1 09:30 起的 10 分钟前）：HeadsUpAlert 出现，文案 "Heads up · in 10 min · Morning standup · Zoom"。
- iOS 同等 DEBUG 数据下显示对应内容；底部 tab bar 不遮盖最后一张 project mini card。
- Release 构建（空数据）显示 EmptyState.inboxZero 居中，kanban 列骨架仍可见。
- LinoJCoreTests `CountersTests` 通过：openCount / urgentCount / todayEventsCount 与种子数据匹配。

**前置依赖：** P1, P2, P3.1。

---

#### P3.3 — Personal + Company views  [macOS → iOS]

**范围 (macOS)：**
- **Personal**：大标题 "Personal" + 统计 "X open · Y done" + 两列 kanban (Urgent / Normal bubbles，仅 `scope == .personal`) + 底部 CompletedBox（折叠/展开 chevron 旋转 90° 0.18s）。空状态：urgent 列空时显示 "Nothing urgent. Nice." 在 dashed-border 列里。
- **Company**：大标题 "Company" + 统计 "X todos · Y projects" + 第一行 scope chips pill row（All work / Standalone / 每个 project 一个 chip，选中 fill ink）+ 两列 kanban（按当前 chip 过滤）+ Projects 子区：3 张 full-width rich card，每张 3 列布局 `1.4fr 1fr 1fr` —— 左：title+intro+tag+members；中：Todos 计数 + 4 行预览；右：Linked events 计数 + 按时间排序的事件 row。点击卡片打开 Project Detail（P3.5 实现，本 Phase 先 wire 一个空 view stub）。

**范围 (iOS)：**
- **Personal**：大标题 + 统计 + 两个 section（Urgent bubbles 堆叠 + Normal 单白卡 compact list） + iOS CompletedBox（dashed-border 14pt radius，可折叠）。
- **Company**：大标题 + 统计 + 横向 scroll scope chips + 两个 section（Urgent / Normal，同 Personal 模式） + 「Projects」section：每个 project 一张 stacked detailed card（title + tag + intro + stats row + linked events preview）。点击 push 到 Project Detail（P3.5）。

**关键接口 / 类型契约：**

```swift
@Observable public final class PersonalViewModel {
    public init(context: ModelContext)
    public var urgent: [Todo]
    public var normal: [Todo]
    public var completed: [Todo]
    public var openCount: Int
    public var doneCount: Int
    public func toggleDone(_ todo: Todo)
    public func toggleUrgency(_ todo: Todo)
    public func delete(_ todo: Todo)
}

@Observable public final class CompanyViewModel {
    public enum ScopeFilter: Hashable {
        case allWork
        case standalone
        case project(Project.ID)
    }
    public init(context: ModelContext)
    public var filter: ScopeFilter
    public var urgent: [Todo]              // filter 后
    public var normal: [Todo]
    public var todosCount: Int
    public var projectsCount: Int
    public var projects: [Project]
    public func setFilter(_ filter: ScopeFilter)
    public func toggleDone(_ todo: Todo)
}
```

**验收标准：**
- Personal 大标题字号 macOS 26pt / iOS 34pt（视觉对照设计稿）。
- Personal CompletedBox 默认折叠；展开后 schedule dentist 这一行带 strikethrough + inkMute 颜色 + " · done" 斜体后缀。
- Company chip 切换 "LinoJ for macOS v1" 后，Urgent 列只显示 w4 (Finalize macOS sidebar spec)；Normal 列只显示 w7 + w8；其余隐藏。
- Company chip "Standalone" 选中后只显示 w1/w2/w3。
- 任一空 urgent 列在 dashed-border 灰框中显示 "Nothing urgent. Nice."。

**前置依赖：** P3.2（复用 bubble / kanban 渲染）。

---

#### P3.4 — Calendar view  [macOS → iOS]

**范围 (macOS)：**
- 标题栏：大标题 "Calendar" + 计数（"X events this week"）+ 中部 `‹ May 27 — Jun 2 ›` nav + Today 按钮 + 右侧 `+ New event`（ink 按钮，点击打开 Quick Add 预设 Event tab，由 P3.6 wire）。
- 主体：7-column 周视图。左侧 52pt 时间标签列，纵向 14 小时（7AM-9PM），46pt/hour。Today 列背景 `bgSoft` 微染 + 一条黑色 "now" 横线 + 左缘黑色小圆点。事件渲染为 cards within hour-span，左侧 2px 黑 accent，内容显示 mono 时间 + 标题（截断）。

**范围 (iOS)：**
- 顶部大标题 "Calendar" + 计数 + nav。
- 横向 7-day strip：每天一个 pill；选中的那天 fill ink、字 panel；today 显示 "Today" label + 日期数字。
- 下方为选中日单日 list：垂直堆叠大 iOS event card（mono 时间 + 标题 + where + AvatarStack）。
- 看 today 时，底部加一个 "From yesterday" dashed-border box。

**关键接口 / 类型契约：**

```swift
@Observable public final class CalendarViewModel {
    public init(context: ModelContext, today: Date = .now)
    public var weekStart: Date              // 周一为起点（Settings 默认；本期固定 Monday）
    public var selectedDay: Date            // iOS 用
    public var eventsByDay: [Date: [Event]] // 7 项
    public var yesterdayMissed: [Event]
    public func goPrevWeek()
    public func goNextWeek()
    public func goToday()
    public func selectDay(_ day: Date)
    public func confirmAttended(_ event: Event)
}
```

**验收标准：**
- macOS：Tue 27 列背景显示染色；"now" 横线位置 = (now - 07:00) / 14h × 14×46pt，与系统时钟联动每分钟更新。
- macOS：4 个 Tue events 分别渲染在正确小时槽（09:30-10:00 / 11:00-11:30 / 14:00-15:00 / 19:00-20:30）。
- iOS：选中 Tue → 列出 4 张 event card；选中 Sat → 列出 e12 + e13；切到看 Today 时显示 yesterday-missed box。
- nav `‹ / ›` 切换上下周；Today 按钮 reset 到包含 now 的周。

**前置依赖：** P1, P2, P3.1。

---

#### P3.5 — Project detail view  [macOS → iOS]

**范围 (macOS)：**
- 进入方式：Company 项目卡片点击 → push 到独立 `ProjectDetailView_macOS`（用 `NavigationStack`，path 由 `CompanyView` 内部 state 管理；也支持窗口式打开，本期用 NavigationStack 即可）。
- Breadcrumb top-left：`← Company / 项目名`；top-right `⋯` 按钮（暂时只 print）。
- Hero：标题 30pt + tag pill + intro 段落（maxWidth 720）+ "Edit project" outline button（暂时只 print）。
- Meta row：avatars | divider | open/urgent/done stats | divider | linked events / created stats。
- 主体两列 `1.3fr 1fr`：
  - 左：Urgent + Normal bubbles（filter 到本 project）+ CompletedBox。
  - 右：Linked events 按 day 分组（小 uppercase header + 事件 row：time + title + where + avatars）+ 下方 Notes section（`white-space: pre-line` 渲染，即保留换行）。

**范围 (iOS)：**
- 进入方式：Company 项目卡片点击 push。
- 顶部两枚 floating glass 按钮：左 `← Company`（含 chevron）+ 右 `⋯`。
- Hero：tag pill → 标题 30pt → intro → AvatarStack + "X members · since Apr 12"。
- 4-column stats card：open / urgent / done / events，cell 之间 thin divider，数字 mono 20pt。
- Sections：Urgent bubbles → Normal compact list → Linked events 按 day 分组 → Notes 白卡 → CompletedBox。

**关键接口 / 类型契约：**

```swift
@Observable public final class ProjectDetailViewModel {
    public init(project: Project, context: ModelContext)
    public let project: Project
    public var urgent: [Todo]
    public var normal: [Todo]
    public var completed: [Todo]
    public var openCount: Int
    public var urgentCount: Int
    public var doneCount: Int
    public var linkedEventsByDay: [Date: [Event]]
    public var membersSinceText: String        // "3 members · since Apr 12"
    public func toggleDone(_ todo: Todo)
    public func toggleUrgency(_ todo: Todo)
    public func delete(_ todo: Todo)
}
```

**验收标准：**
- 打开 "LinoJ for macOS v1"：左列 Urgent = w4；Normal = w7+w8；CompletedBox count = 0。右列 Linked events 显示 e1/e3/e8/e10/e15（按日期 group），Notes 段保留双换行（"Open questions:" 上面有空行）。
- iOS stats card 显示 "2 open · 1 urgent · 0 done · 5 events"。
- Breadcrumb / 返回按钮可正确 pop 回 Company。

**前置依赖：** P3.3（Company 卡片提供入口）。

---

#### P3.6 — Quick Add modal/sheet  [macOS → iOS]

**范围 (macOS)：**
- 中央 modal 520pt 宽 + backdrop（70% black）+ corner radius 14。顶部 3-way segmented control（Todo / Event / Project，含 SF symbol icon）。
- **Todo form**：title input（22pt display）+ Urgency 双选 toggle（Urgent 蓝 / Normal） + Scope 双选（Personal / Company） + Project 横向 chip row（"None" + 每个 project）。Scope == Personal 时 Project picker disable + 提示。
- **Event form**：title + Date picker + Start time + End time + Location TextField + Attendees AvatarStack + "+ Add" dashed chip（弹出 sub-picker 选已有 Person 或新建）+ optional Link to project chip row。
- **Project form**：title + multiline 描述 textarea + tag TextField + Members chip row + "+ Invite" dashed chip。
- Footer：kbd hints `esc cancel · ⌘↵ create` + Cancel + Create 按钮。
- 入口：⌘N（默认 Todo）/ ⌘⇧T / ⌘⇧E / ⌘⇧P / Calendar 的 + New event 按钮。

**范围 (iOS)：**
- 底部 sheet（presentationDetents `.large`），grab handle，顶部一行：Cancel（左）/ "New" 标题（中）/ Create ink pill（右）。然后 segmented control，下方 ScrollView 装表单。
- 入口：右上 `+` floating button → 弹此 sheet。

**关键接口 / 类型契约：**

```swift
@Observable public final class QuickAddViewModel {
    public enum Kind: Hashable { case todo, event, project }
    public init(context: ModelContext, defaultKind: Kind = .todo, prefilledProject: Project? = nil)
    public var kind: Kind
    // Todo
    public var todoTitle: String
    public var todoUrgency: Urgency
    public var todoScope: Scope
    public var todoProject: Project?
    // Event
    public var eventTitle: String
    public var eventDate: Date
    public var eventStart: Date
    public var eventEnd: Date
    public var eventLocation: String
    public var eventAttendees: [Person]
    public var eventProject: Project?
    // Project
    public var projectTitle: String
    public var projectIntro: String
    public var projectTag: String
    public var projectMembers: [Person]
    public var canSubmit: Bool { get }
    public func submit() throws -> AnyHashable    // 返回创建的对象 id
}
```

**验收标准：**
- macOS ⌘N 弹出 modal，默认 Todo；esc 关；⌘↵ 提交（title 为空时按钮 disable）。
- 创建一个 urgent + Company + project = LinoJ 的 Todo，关闭后 Main 的 Urgent 列立刻出现新 bubble。
- 创建 Event：Date + Start + End 时间组合存入 SwiftData，重启后仍可见。
- iOS sheet 用 `.glassEffect()` 是不对的，sheet 自身用系统 sheet；但顶部 Cancel/Create 行不需要 glass（纯 inline）。

**前置依赖：** P3.1（路由）、P3.2（Main 显示效果）、P3.3（Company chip / project list）。

---

#### P3.7 — Search / Command palette  [macOS → iOS]

**范围 (macOS)：**
- ⌘K 触发居中浮动 modal（约 640pt 宽）。顶部搜索 TextField 自动 focus + Scope chips（All / Todos / Events / Projects）。
- 主体按 group 显示结果：Quick actions / Todos / Events / Projects，每组小 uppercase header。
- 每行：type icon in chip + 标题 + meta hint。Urgent 行：标题前蓝点 + bold。
- 第一条结果高亮（subtle bg）+ 右侧显示 `↵` kbd hint。↑↓ 改变高亮，↵ 打开。
- Footer：kbd hints + perf "X results in Y ms"。

**范围 (iOS)：**
- 右上 magnifying-glass floating button → full-screen `.sheet`。
- 搜索 TextField（含 × clear）+ 右上 Cancel 链接。
- Scope chips 横向 scroll。
- 每个 group 一张白色 card，内含 rows。

**关键接口 / 类型契约：**

```swift
@Observable public final class SearchViewModel {
    public enum Scope: Hashable, CaseIterable { case all, todos, events, projects }
    public enum ResultItem: Hashable {
        case todo(Todo)
        case event(Event)
        case project(Project)
        case quickAction(QuickAction)
    }
    public enum QuickAction: Hashable {
        case newTodo, newEvent, newProject
        case jumpTo(AppTab)
    }
    public init(context: ModelContext)
    public var query: String { get set }       // didSet triggers debounced search
    public var scope: Scope
    public var grouped: [(group: String, items: [ResultItem])]
    public var elapsedMs: Int                  // for "X in Y ms"
    public func performSearch()                // 同步触发，内部 debounce 100ms
    public func openFirst()
}
```

**验收标准：**
- 输入 "side"：Todos 组返回 w4 "Finalize macOS sidebar spec"（urgent，蓝点）；Projects 组返回 LinoJ for macOS v1（含 "sidebar" intro 命中？根据匹配规则）。
- 空 query 时显示 Quick actions（New todo / New event / New project / Jump to Personal..Calendar）。
- macOS ↑↓ 可换行高亮，↵ 打开对应结果（Todo → focus 到 Main 那张 bubble；Event → 跳 Calendar 选中那天；Project → push detail）。
- 性能读数：100 条数据下 < 50ms。

**前置依赖：** P3.1。

---

#### P3.8 — Settings  [macOS → iOS]

**范围 (macOS)：**
- 760×540 sheet-style window（用 `.sheet` 或 `Settings` scene 均可，本期用 `.sheet`），左侧 sidebar nav 切 section：General / Notifications / Sync / Shortcuts / About。
- **General**：Appearance 行（System，旁边 mono kbd "locked" badge，旁注 "Switch in System Settings to change"）/ Default tab Picker / Default todo scope Picker / Show completed in counts Toggle / Start week on Picker（Sun/Mon）。
- **Notifications**：Heads-up timing（Stepper 5/10/15/30 min，default 30）/ System banner Toggle / Yesterday missed reminder Toggle / Daily summary time（DatePicker hour-only）/ Quiet hours range（双 DatePicker）。
- **Sync**（UI only）：iCloud sync Toggle（默认 ON，无任何后台动作）/ Account 行（显示占位 email）/ Apple Calendar mirror Toggle（默认 OFF）/ Apple Reminders mirror Toggle（默认 OFF）/ Last synced status pill（显示 "Synced just now · placeholder"）。
- **Shortcuts**：mono kbd table 列出 README 的快捷键表，分 3 组 Navigation / Create / On a todo。纯展示。
- **About**：App name + version `LinoJCore.version` + tagline "Calm planning, separated." + 4 个 link：Release notes / Feedback / Privacy / Acknowledgements（点击 print）。

**范围 (iOS)：**
- full-screen `.sheet`，顶部 Cancel / Done。
- iOS 系统 grouped List（`.insetGrouped`）渲染同样 5 个 section（少 Shortcuts）。
- 底部红色 "Sign out" 按钮（点击 print）。
- 顶部 sticky bar 用 `.regularMaterial` 20pt blur。

**关键接口 / 类型契约：**

```swift
@Observable public final class SettingsViewModel {
    public init()
    // General
    public var defaultTab: AppTab
    public var defaultTodoScope: Scope
    public var showCompletedInCounts: Bool
    public var startWeekOn: Weekday                       // .sunday / .monday
    // Notifications
    public var headsUpLeadMinutes: Int                    // 5/10/15/30
    public var systemBannerEnabled: Bool
    public var yesterdayMissedReminderEnabled: Bool
    public var dailySummaryHour: Int                      // 0..23
    public var quietHoursStart: Int
    public var quietHoursEnd: Int
    // Sync (UI placeholder only)
    public var iCloudSyncOn: Bool = true                  // default ON, no effect
    public var accountEmail: String = "you@example.com"
    public var calendarMirrorOn: Bool = false
    public var remindersMirrorOn: Bool = false
    public var lastSyncedText: String = "Synced just now · placeholder"
    public func persist()
}

public enum Weekday: String, Codable { case sunday, monday }
```

存储后端：`UserDefaults`（key prefix `linoj.settings.*`）。每次 setter 后调用 `persist()`。

**验收标准：**
- macOS：sidebar 切换 5 个 section 不丢状态；Appearance 行的 mono kbd 显示 "locked"；改 headsUpLeadMinutes 后 P4 的 HeadsUpService 立刻使用新值。
- iOS：Settings sheet 滑动顺畅；Toggle 状态写入 UserDefaults 重启不丢。
- iCloud Toggle 切换无任何运行时副作用（不报错、不卡顿）。
- LinoJCoreTests `SettingsPersistenceTests` 通过：set 值 → 重建实例 → 读到相同值。

**前置依赖：** P0。可在 P3 任何位置插入，但施工放在 P3.8 是为了让 P4 能复用 `headsUpLeadMinutes`。

---

### P4 — Heads-up 服务 + 本地通知 + Yesterday-missed 服务  [共享 + macOS 验收 + iOS 验收]

**范围：**
- `HeadsUpService`：每分钟 tick（macOS 用 `Timer.publish`，iOS 用 `Timer.publish` + `BGTaskScheduler`-free，毕竟免费证书；前台 tick 即可），扫描 `Event.start` 在 `now ... now+60min` 且 `now < end`，输出 `HeadsUpAlertModel`。MainViewModel 订阅。
- `NotificationService`：App 启动时调用 `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])`。为每个未过期的 Event schedule 一条本地 `UNCalendarNotificationTrigger`，触发时间 = `start - headsUpLeadMinutes`。Settings 改 lead minutes 后重新 schedule。Event 删除 / 修改时 cancel + re-schedule。
- `YesterdayMissedService`：每次 App 进入前台时计算 `events where end < startOfToday() AND end > startOfYesterday() AND attendedConfirmed == false`，输出 `[Event]`。

**关键接口 / 类型契约：**

```swift
public final class HeadsUpService {
    public init(context: ModelContext, leadMinutes: Int = 30)
    public var currentAlert: HeadsUpAlertModel? { get }
    public func start()
    public func stop()
    public func snooze(for minutes: Int = 10)
}

public final class NotificationService {
    public init()
    public func requestAuthorization() async -> Bool
    public func scheduleAll(events: [Event], leadMinutes: Int) async
    public func cancel(eventID: UUID) async
    public func cancelAll() async
}

public final class YesterdayMissedService {
    public init(context: ModelContext)
    public func computeMissed(now: Date = .now) -> [Event]
    public func confirmAttended(_ event: Event)
}
```

**验收标准：**
- 单元测试 `HeadsUpServiceTests.testWithin60Min`：给定 now=09:20，e1 start=09:30 → alert.minutesUntil == 10。
- `HeadsUpServiceTests.testOutsideWindow`：start - now > 60 min → alert == nil。
- `YesterdayMissedTests.testFiltersOnlyYesterday`：y1/y2 出现在结果中，今天 / 前天 / 已 confirmed 的被排除。
- macOS / iOS 真机：授权弹窗出现一次；将系统时间调到 e1 前 31 分钟 → 收到本地通知。
- HeadsUpAlert 在 Main 上显示，Snooze 按钮使 alert 消失 10 分钟。

**前置依赖：** P1, P3.2（Main 显示位）、P3.8（lead minutes 来源）。

---

### P5 — Empty states 收尾 + 本地化（中英双语）  [共享]

**范围：**
- 把所有用户可见字符串迁移到 `Localizable.xcstrings`，中英双填。
- 完成所有 EmptyState variant：
  - Main inbox zero：`EmptyState(variant: .inboxZero, ctaTitle: "+ New todo")` 在 Main 主区中央。
  - Personal urgent 列空：`.urgentEmpty` 在 dashed-border 列内显示 "Nothing urgent. Nice."。
  - Calendar 整周无事件：`.clearWeek` 在 week grid 中央显示 "A clear week."。
  - Search 无结果：`.noResults("xxx")` 在结果区显示 'No matches for "xxx"'。
- 关键：empty state 不替换 chrome（kanban / 7-day strip / search field 仍可见），只在内容区居中。

**关键接口 / 类型契约：**

```swift
public extension LocalizedStringResource {
    enum LJ {
        public static let todoTitle: LocalizedStringResource
        public static let urgent: LocalizedStringResource
        public static let normal: LocalizedStringResource
        public static let inboxZero: LocalizedStringResource
        public static let nothingUrgent: LocalizedStringResource
        public static let clearWeek: LocalizedStringResource
        public static let noMatches: LocalizedStringResource     // with %@
        public static let headsUpFormat: LocalizedStringResource // "Heads up · in %d min · %@ · %@"
        public static let nextSevenDays: LocalizedStringResource
        public static let fromYesterday: LocalizedStringResource
        public static let appearance: LocalizedStringResource
        public static let switchInSystemSettings: LocalizedStringResource
        // ... 完整列表见施工 PR
    }
}
```

**验收标准：**
- 系统语言切到中文：Main 标题显示 "待办"，section "Urgent" → "紧急" / "Normal" → "常规"，Heads-up 文案中文，Settings 全中文。
- 系统语言切到英文：恢复 README 原文。
- 没有 raw `"..."` 字符串残留在 UI 文件中（grep 检查，允许 `print(...)` 调试残留但提交前清理）。
- 全部 EmptyState 变体在对应空数据下出现，且 kanban / 7-day chrome 不消失。

**前置依赖：** P3 全部完成（要把现有 UI 字符串迁移）。

---

### P6 — 响应式 + macOS 窗口适配 + 键盘 / 鼠标 / 触屏行为打磨  [macOS + iOS]

**范围：**
- macOS 窗口宽度响应：
  - < 1200pt：Company project cards 内部从 3 列变 2 行 layout。
  - < 1100pt：Calendar 横向 scroll + sticky day header。
  - < 900pt：Calendar 周视图降级为 3-day；Main 右栏可隐藏（用 `.sceneSize` 监听）。
- macOS hover：todo bubble `translateY(-1)`（用 `.onHover` + `.offset` animation 0.12s）；list row hover 背景 `rgba(10,10,10,0.04)`。
- macOS cursor pointer：可点击元素加 `.help("...")` + `.onHover { NSCursor.pointingHand.push() }` 视情。
- iOS haptics：每次 toggle done / urgency / 创建项目 → `UIImpactFeedbackGenerator(style: .light)`。
- iOS tap 按压态：list row 加 `.contentShape(Rectangle())` + `.buttonStyle(.plain)` 短暂明色。
- Heads-up 脉冲动画：dot opacity 0.4 ↔ 0.9 + scale 0.7 ↔ 1.0，2s ease-in-out infinite。
- 折叠 CompletedBox chevron 旋转 90° 0.18s + content slide。
- Sheet/modal open：依赖系统 spring（默认）。
- Empty state appearance：fade-in 0.2s。

**验收标准：**
- macOS 把窗口拖到 1050pt：Calendar 出现横向 scroll bar + sticky 周一列在最左。
- macOS 把窗口拖到 850pt：Calendar 显示 3 天 + Main 右栏消失。
- 在 macOS bubble 上悬停明显抬起；list row 悬停背景轻变。
- iOS 真机 toggle todo done 时有轻 haptic。
- Heads-up dot 真的在脉动。

**前置依赖：** P3 全部。

---

### P7 — 收尾：测试补全 + Release 构建验证 + 文档化  [共享]

**范围：**
- 把 LinoJCoreTests 补齐至覆盖：
  - `ModelTests`、`CountersTests`、`HeadsUpServiceTests`、`YesterdayMissedTests`、`SeedDataTests`、`SettingsPersistenceTests`、`ColorTokensTests`、`SearchViewModelTests`、`QuickAddViewModelTests`。
  - 目标覆盖率：核心 ViewModel + Service ≥ 70% lines。
- 在 LinoJCore 根目录加 `README.md`（简短，不与本计划重叠，只说"如何在 Xcode 打开 workspace + 跑测试"）。
- Release scheme 构建 macOS + iOS：确认启动 Inbox zero、无任何 `print` 残留、无 capability 报错。
- Archive 一次 macOS App，确认免费个人证书可签出 `.app`（不公证、不上架）。
- iOS App 真机部署一次（已注册的 iPhone），免费证书可启动并 7 天内可用。

**验收标准：**
- `swift test --package-path Packages/LinoJCore` 全绿。
- macOS Release 启动屏 = Inbox zero EmptyState。
- iOS Release 真机启动 = Inbox zero。
- 两端均能创建一个 Todo + 重启后仍存在。
- Heads-up 本地通知在 macOS / iOS 真机都触发过一次。

**前置依赖：** P0..P6 全部。

---

## v1.0 Phase 列表（付费 Developer 账号下发后正式施工）

> 本节由 v0.9 的「v1.0 待办清单」展开而成（2026-05-28 规划）。v0.9 P0-P7 保持原样不动。v1.0 Phase 用 **V** 前缀编号（V0..V7），避免与 P0-P7 混淆。
> 施工原则同 v0.9：每个 Phase 内若涉及两端，**先 macOS 验收 → 再 iOS 验收**；本节标注 [macOS] / [iOS] / [共享] 表示 Phase 主体平台归属。

### v1.0 技术选型 / 约束（已敲定，覆盖 v0.9「免费证书约束」节）

付费 Apple Developer 账号已下发（同一 Apple ID `linocai@hotmail.com` 原地升级，Team ID `HX73DFL88G` 不变）。以下为 v1.0 范围与选型，凡与 v0.9「免费证书约束」节冲突处以本节为准。

**解除的 v0.9 约束（v1.0 现在允许引入）：**
- ✅ **CloudKit / iCloud**：`iCloud.com.linocai.linoj` 单一 container，macOS / iOS 共用，跨端同步。SwiftData `cloudKitDatabase: .automatic`。
- ✅ **Push Notifications（仅 CloudKit 订阅式静默推送）**：`aps-environment` entitlement + `CKDatabaseSubscription`，用于跨设备「toggle done / 改动后实时刷新」。**不自建 APNs 服务端**，不发自定义可见推送。
- ✅ **Sign in with Apple**：`com.apple.developer.applesignin` entitlement，Settings → Account 行接通。
- ✅ **App Groups**：**仅当 CloudKit / Push 需要时才开**（实测 SwiftData + CloudKit 不强制要求 App Group；只有 Widget / 跨进程共享容器才需要）。默认不开，V0 验证签名时若 Xcode automatic signing 报缺 App Group 再补，并在变更日志记录。**绝不为 Widget 开。**

**v1.0 仍保留的约束（明确不做）：**
- ❌ **Widget / WidgetKit**：用户明确 out of scope，不做（即使 README empty-states 提到，也不实现）。
- ❌ **自建 APNs 服务端 / 自定义可见远程推送**：v0.9「远程推送（Daily summary 跨设备）」待办降级——v1.0 只做 CloudKit 静默推送同步，不做 server-push 的 Daily summary。Daily summary 仍走本地 `UNUserNotificationCenter`（v0.9 已留 Settings 项，v1 不强制接）。
- ❌ **EventKit 真接通（Apple Calendar / Reminders mirror）**：v0.9 待办里的 EventKit 镜像在 v1.0 **暂不做**，Settings 两个 mirror toggle 维持 v0.9 的 "(coming in v1.0)" hint 占位形态（见下方 V3 决策）。理由：聚焦「云同步 + 登录」核心闭环，EventKit 双向镜像是独立大模块，留 v1.1。
- ❌ **Background refresh（iOS BGTask）/ Spotlight 索引 / Shortcuts intent**：v1.0 不做。CloudKit 静默推送已能覆盖「跨设备改动刷新」的核心诉求；BGTask 预算 Heads-up 留后续。
- ❌ **macOS 公证（notarize）/ 实际提审上架**：v1.0 建 App Store Connect 记录 + 配 provisioning + 加隐私 manifest，但**不强制走完公证与提审**（用户：建记录即可，是否立刻上架另议）。Archive 走通 + Organizer 校验 valid 即满足 V7 验收。

**v1.0 正式 Bundle ID（覆盖 v0.9 技术选型第 5 条）—— 统一为 Universal Purchase：**
- macOS 与 iOS **共用同一 Bundle ID** `com.linocai.linoj`（去掉 `.macos` / `.ios` 后缀）。
  - 理由：App Store Connect 一个 App 记录只能绑一个 Bundle ID；iOS + macOS 共用同一 ID 才能挂在**单个 App 记录**下走 Universal Purchase（用户在商店看到一个「支持 iPhone + Mac」的 App，买一次两端通用）。
  - 两个独立 Xcode target 用相同 Bundle ID 合法：iOS 设备装 iOS build、Mac 装 macOS build，互不冲突。
  - 之前误规划的 `com.linocai.linoj.macos` / `.ios` 作废。
- `DEVELOPMENT_TEAM` 保持 `HX73DFL88G`（付费后同一 team 解锁付费 capability，无需改 team）。

**README 4 个开放问题——v1.0 最终决策：**
1. **iCloud sync toggle 默认 on/off** → **默认 ON**（沿用 v0.9 视觉默认，v1.0 接真）。见 V1。
2. **Edit project 复用 New Project modal 的 edit 模式？** → **是。** 复用 `QuickAddViewModel`，新增 edit 模式（传入既有 `Project` 预填字段，submit 走 update 而非 insert）。见 V5。
3. **"From yesterday" 出勤确认是否要** → **保留，标记为已确认。** v0.9 已实现（`attendedConfirmed` + `YesterdayMissedService`），v1.0 不动逻辑，确认为正式行为。
4. **Widget** → **明确不做**（out of scope，见上方 v1.0 约束）。

---

### V0 — 付费迁移与 capability 开启  [全栈 / 共享 / pbxproj + entitlements]

**范围：**
- 改两端 Bundle ID（**统一为 `com.linocai.linoj`，两端相同**）：
  - `LinoJ-macOS.xcodeproj/project.pbxproj`：所有 `PRODUCT_BUNDLE_IDENTIFIER = com.example.linoj.macos` → `com.linocai.linoj`（Debug + Release 两处）。
  - `LinoJ-iOS.xcodeproj/project.pbxproj`：`com.example.linoj.ios` → `com.linocai.linoj`（Debug + Release）。
  - 注意两端 `PRODUCT_BUNDLE_IDENTIFIER` 改成**完全相同**的 `com.linocai.linoj`。
  - `DEVELOPMENT_TEAM = HX73DFL88G` 保持不变，无需改。
- 改 entitlements（**先确认网页端 App ID / Container 已创建**，见文末「用户网页操作清单」V0 项，否则 automatic signing 会失败）：
  - `LinoJ-macOS/.../LinoJ-macOS.entitlements`：在现有 `com.apple.security.app-sandbox = true` 基础上**追加**以下 key：
    ```xml
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array><string>iCloud.com.linocai.linoj</string></array>
    <key>com.apple.developer.icloud-services</key>
    <array><string>CloudKit</string></array>
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)iCloud.com.linocai.linoj</string>
    <key>com.apple.developer.aps-environment</key>
    <string>development</string>
    <key>com.apple.developer.applesignin</key>
    <array><string>Default</string></array>
    <key>com.apple.security.network.client</key>
    <true/>
    ```
    （`network.client` 因 sandbox 下 CloudKit 需要出站网络；保留 `app-sandbox`。`aps-environment` 在 Release / archive 时 Xcode 自动切 `production`，dev 用 `development`。）
  - `LinoJ-iOS/.../LinoJ-iOS.entitlements`（v0.9 为空 dict）：填入与 macOS **相同的 iCloud / CloudKit / aps-environment / applesignin** 四组 key（iOS 不需要 `app-sandbox` 与 `network.client`）。
  - **App Groups 默认不加**：仅当 V0 验证签名报「missing App Group」或 V2 CloudKit 订阅实测需要时才追加 `com.apple.security.application-groups = [group.com.linocai.linoj]`，并在变更日志记录原因。
- 验证付费 team 签名：两端 Debug build + 一次 archive，确认 provisioning profile 已含 iCloud / Push / Sign in with Apple capability，signed by 付费 team。

**关键接口 / 类型契约：** 无新增代码类型。本 Phase 全部为工程配置（pbxproj + entitlements plist）。CloudKit container 标识符常量建议集中到 `LinoJCore`：
```swift
public enum LinoJCloudKit {
    public static let containerID = "iCloud.com.linocai.linoj"
}
```

**验收标准：**
- 两端 `xcodebuild ... build`（Debug）BUILD SUCCEEDED，signed by 付费 Team `HX73DFL88G`。
- Xcode Signing & Capabilities 页：两端均显示 iCloud (CloudKit, container `iCloud.com.linocai.linoj`) + Push Notifications + Sign in with Apple 三项 capability，无红色错误。
- 一次 macOS archive + 一次 iOS archive 成功（Organizer 中 profile 含上述三 capability）。
- `swift build`（LinoJCore package 单独）仍通过；95 个既有测试全绿（V0 不改业务逻辑）。

**前置依赖：** 无代码前置，但**强依赖**文末「用户网页操作清单」中 developer.apple.com 的 App ID + CloudKit Container 创建（否则 automatic signing 拿不到含付费 capability 的 profile）。V0 是 V1/V2/V3 的硬前置。

---

### V1 — CloudKit 同步（SwiftData `cloudKitDatabase: .automatic`）  [共享]

**范围：**
- 把 `LinoJStore.makeContainer` 的 `ModelConfiguration` 从 v0.9 的 `cloudKitDatabase: .none` 切到 `.automatic`（指定 `iCloud.com.linocai.linoj`）。`inMemory: true`（测试用）保持 `.none`，不连云。
- **改造现有 `@Model` 以满足 CloudKit 硬约束**（见下方「CloudKit 对现有 @Model 的硬约束清单」——这是 V1 最大技术风险，逐条修）。
- 首次启动 schema 迁移：v0.9 已有本地 store 的用户升级时，SwiftData 需把现有 local-only schema 迁移到 CloudKit-backed schema。提供轻量迁移路径（若模型改动只是「加默认值 / 关系转 optional」，SwiftData 多为自动 lightweight migration；若改了 `@Attribute(.unique)` 需手动处理，见约束清单）。
- Settings → Sync 的 iCloud sync Toggle 接真：ON = 使用 `.automatic` container；OFF = 该如何处理需明确（见下方决策）。
- Last-synced status pill 显示真实状态：监听 `NSPersistentCloudKitContainer` 事件（通过 `NSPersistentCloudKitContainer.eventChangedNotification`）更新 "Synced just now" / "Syncing…" / "Sync error"。

**CloudKit 对现有 `@Model` 的硬约束清单（V1 最关键技术风险，逐条核对并修改）：**

> SwiftData + CloudKit (`.automatic`) 对 `@Model` 有强制约束，违反会在运行时 crash 或拒绝同步。现有模型（P1 定义 + Reviewer F2 加的 `memberCount`）需逐条审：

1. **所有非 optional 标量属性必须有默认值。** CloudKit 记录字段允许缺失，SwiftData 要求能用默认值填充。
   - `Todo.title/urgencyRaw/scopeRaw/done/createdAt`、`Project.title/intro/notes/tag/createdAt/memberCount`、`Event.title/start/end/location/attendedConfirmed`、`Person.name` —— 全部需要在声明处给默认值（如 `var title: String = ""`、`var done: Bool = false`、`var createdAt: Date = .now`、`var memberCount: Int = 0`）。`id: UUID` 已有 `= UUID()` 默认，OK。
2. **所有 `@Relationship` 必须 optional —— 包括 to-many。** CloudKit 要求 to-one **和** to-many 关系全部 optional（`var rel: [X]?`）；非 optional to-many（`[X] = []`）会在真实 `.private` 容器加载时 crash：`CloudKit integration requires that all relationships be optional`。
   - `Todo.project: Project?` ✅ 已 optional（to-one，不动）。
   - `Event.project: Project?` ✅ 已 optional（to-one，不动）。
   - `Project.members: [Person]?`、`Project.todos: [Todo]?`、`Project.events: [Event]?`、`Event.attendees: [Person]?`、`Person.memberOf: [Project]?`、`Person.attending: [Event]?` —— 6 个 to-many，**类型必须 `[X]?`**（init 默认值给空数组 `= []`，存储空数组而非 nil，行为更自然；CloudKit 校验的是类型 optional，不是值非空）。全访问点用 `(rel ?? [])` 兜底。
3. **禁止 `@Attribute(.unique)`。** CloudKit 不支持唯一约束。核对：现有模型用 `var id: UUID` 但**未**标 `@Attribute(.unique)`（P1 契约里没有），✅ 若 builder 在 v0.9 私自加了 `.unique`，V1 必须移除（去重逻辑改由业务层 / `id` 自然唯一保证）。
4. **inverse 关系必须双向声明且都 optional/默认。** v0.9 用 `@Relationship(deleteRule: .nullify, inverse: \Todo.project)`。CloudKit 下 `inverse` 仍支持，但 **deleteRule 在 CloudKit 同步下行为需验证**——`.nullify` OK；若用了 `.cascade` 需测跨设备删除传播。`Project.todos` / `Project.events` 的 `.nullify` 保留，验证删除 Project 后子项 project 置 nil 能跨端同步。
5. **不能用 SwiftData 的 `#Unique` 宏 / 复合唯一索引。** 同 3，核对无使用。
6. **enum 存储用 raw String 已合规**（`urgencyRaw` / `scopeRaw`），CloudKit 视作 String 字段，无需改。
7. **`memberCount` 冗余字段（Reviewer F2 引入）的同步语义**：它是手写冗余计数，跨设备同步时若 A 设备改了 members 但 memberCount 没重算，会出现两端不一致。V1 决策：**保留 memberCount 但在 V5 Edit project 流程里确保每次改 members 都重写 memberCount**；CloudKit 同步它作为普通 Int 字段，最后写入者胜（last-writer-wins，CloudKit 默认）。
8. **历史 store 迁移风险**：若约束 1/2 的「加默认值」改动触发 schema 变更，SwiftData 通常做 lightweight migration（加字段带默认值是兼容变更）。但「关系从 non-optional 转 optional」可能需要 `SchemaMigrationPlan`。V1 施工时先在干净模拟器（删 app 重装）验证，再测 v0.9 升级路径（保留旧 store 启动）。

**iCloud sync Toggle OFF 的语义决策：**
- v1.0 决策：Toggle 默认 **ON**。Toggle 切 OFF 时 **不切换 container**（SwiftData 不支持运行时热切 `cloudKitDatabase`，切换需重建 container 并重启）。OFF 的语义改为：**仅停止 UI 上的 "syncing" 状态展示 + 提示「重启 App 生效」**，或更简单——v1.0 把该 Toggle 标记为「sync 状态指示」而非「热开关」，OFF 时弹提示「Disabling sync requires restart」。施工选最简稳妥方案：Toggle 持久化到 UserDefaults，下次启动 `makeContainer` 时读取决定 `.automatic` / `.none`，当次会话不热切。在 Toggle 旁加 mono caption "Restart to apply"。

**关键接口 / 类型契约：**
```swift
public enum LinoJStore {
    // v0.9 签名保留；v1.0 行为变更：cloudSyncEnabled 决定 cloudKitDatabase
    public static func makeContainer(inMemory: Bool = false, cloudSyncEnabled: Bool = true) throws -> ModelContainer
}

@Observable @MainActor public final class CloudSyncMonitor {
    public enum Status: Equatable { case idle, syncing, synced(Date), error(String) }
    public init(container: ModelContainer)
    public var status: Status { get }            // 驱动 Settings Last-synced pill
    public var lastSyncedText: String { get }    // 本地化 "Synced just now" / "Syncing…" / "Sync paused"
    public func start()                          // 订阅 NSPersistentCloudKitContainer.eventChangedNotification
}
```
- `SettingsViewModel.iCloudSyncOn`（v0.9 已存在，UI 占位）→ v1.0 接真：setter 写 UserDefaults `linoj.settings.icloudSync`，`makeContainer` 启动时读取。
- `SettingsViewModel.lastSyncedText` → 由 `CloudSyncMonitor.lastSyncedText` 实时驱动，移除 v0.9 的 "· placeholder" 后缀。

**验收标准：**
- 两端同一 iCloud 账号登录：macOS 上新建 Todo，约数秒内 iOS 端 `@Query` 自动出现该 Todo（反向亦然）。
- macOS 删除一个 Project，iOS 端该 Project 消失且其下 Todo 的 project 关系变 nil（验证 `.nullify` 跨端传播）。
- Settings Last-synced pill 在同步发生时显示 "Syncing…"，完成后 "Synced just now"（不再是 placeholder）。
- 干净安装（删 app）启动不 crash；从 v0.9 旧 store 升级启动不 crash、数据不丢。
- `LinoJCoreTests` 全绿（测试仍走 `inMemory: true` + `.none`，不连真云）；新增 `CloudSyncMonitorTests`（mock status 流转）。
- DEBUG seed 行为：seed 仍仅在容器为空时写入；CloudKit 已有数据时 `seedIfEmpty` 不重复写（验证 seed 与云数据不打架——若云已有数据，本地首次同步下来后 `isEmpty` 为 false，不 seed）。

**前置依赖：** V0（entitlements + container 已配）。

---

### V2 — Push（CloudKit 订阅式静默推送）  [共享]

**范围：**
- 注册 remote notifications：两端 App 启动 `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` / `registerForRemoteNotifications()`（macOS 用 `NSApplication`，iOS 用 `UIApplication`；SwiftUI 用 `@UIApplicationDelegateAdaptor` / `@NSApplicationDelegateAdaptor`）。
- 创建 `CKDatabaseSubscription`（private database）+ silent push（`shouldSendContentAvailable = true`，不带 alert/badge/sound——纯静默）。CloudKit 在另一设备改动时下发静默推送，触发本设备 `NSPersistentCloudKitContainer` 拉取，进而 `@Query` 自动刷新 UI。
- 处理收到静默推送：`didReceiveRemoteNotification` → 触发 CloudKit fetch（多数情况 `NSPersistentCloudKitContainer` 自动处理，本 Phase 主要确保 entitlement + 注册链路通，UI 因 `@Query` 自动更新）。
- iOS：因不做 BGTask，静默推送在 App 前台 / 后台被系统唤醒时刷新即可（不保证 App 完全 kill 时刷新——可接受，README 无此要求）。

**关键接口 / 类型契约：**
```swift
public final class RemoteNotificationCoordinator {
    public init(container: ModelContainer)
    public func registerSubscriptionsIfNeeded() async throws   // 创建 CKDatabaseSubscription（幂等，存 UserDefaults flag 避免重复建）
    public func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async
}
```
- 两端各一个 AppDelegate adaptor（macOS `AppDelegate_macOS` / iOS `AppDelegate_iOS`），在 `didRegisterForRemoteNotifications` 成功后调用 `registerSubscriptionsIfNeeded()`。

**验收标准：**
- 两端真机（同一 iCloud）：A 设备 toggle 一个 Todo done，B 设备**未主动操作**情况下，数秒内 B 的 UI 该 Todo 自动变 done 态（验证静默推送 → 自动同步 → `@Query` 刷新闭环）。
- CloudKit Dashboard 中可见为该 container 创建的 subscription 记录。
- `registerSubscriptionsIfNeeded` 幂等：多次启动不重复创建 subscription（用 UserDefaults flag 或捕获 "subscription already exists" 错误）。
- 无可见推送横幅弹出（确认是 silent push，`content-available` only）。
- App 启动注册 remote notification 不报错（entitlement 由 V0 提供）。

**前置依赖：** V0（aps-environment entitlement）、V1（CloudKit container + NSPersistentCloudKitContainer 已起）。

---

### V3 — Sign in with Apple  [共享]

**范围：**
- Settings → Sync → Account 行接真：未登录时显示 "Sign in with Apple" 按钮（`SignInWithAppleButton`，SwiftUI 原生）；已登录显示 Apple 返回的姓名 / email（首次授权才给 email，之后只给 user identifier，需本地缓存首次结果）。
- 走 `ASAuthorizationController` + `ASAuthorizationAppleIDProvider`。请求 scope `[.fullName, .email]`。
- 存储 user identifier（`credential.user`，稳定不变的字符串）到 Keychain（不是 UserDefaults——敏感）；姓名 / email 首次拿到也缓存（Keychain 或 UserDefaults）。
- 启动时用 `ASAuthorizationAppleIDProvider.getCredentialState(forUserID:)` 校验登录态（`.authorized` / `.revoked` / `.notFound`），revoked 则登出。
- Sign out 真行为（v0.9 是 print 占位）：清 Keychain 里的 user identifier + 缓存的姓名/email，Account 行回到 "Sign in with Apple" 态。**注意**：v1.0 决策——Sign out **不清空本地 SwiftData 数据、不关 CloudKit 订阅**（CloudKit 走的是系统 iCloud 账号，与 Sign in with Apple 是两套身份；本 App 的 SwiftData 同步绑定系统 iCloud，不绑 SIWA 身份）。SIWA 在 v1.0 仅作「展示登录身份 / 未来账号体系预留」，不驱动数据归属。这一点写清楚避免 builder 误把 sign out 接成清库。

**关键接口 / 类型契约：**
```swift
@Observable @MainActor public final class AppleSignInService {
    public enum State: Equatable {
        case signedOut
        case signedIn(userID: String, displayName: String?, email: String?)
    }
    public init()
    public var state: State { get }
    public func handleAuthorization(_ result: Result<ASAuthorization, Error>)  // SignInWithAppleButton onCompletion
    public func refreshCredentialState() async                                  // 启动时校验 .authorized/.revoked
    public func signOut()                                                       // 清 Keychain，state → .signedOut（不动 SwiftData / CloudKit）
}

enum AppleIDKeychain {   // 内部
    static func save(userID: String, name: String?, email: String?)
    static func load() -> (userID: String, name: String?, email: String?)?
    static func clear()
}
```
- `SettingsViewModel.accountEmail`（v0.9 占位 "you@example.com"）→ v1.0 由 `AppleSignInService.state` 驱动；未登录显示按钮，已登录显示真实 email/name。

**EventKit mirror 决策（在本 Phase 一并明确）：**
- Settings → Sync 的 "Apple Calendar mirror" / "Apple Reminders mirror" 两个 toggle：**v1.0 不接 EventKit**，维持 v0.9 Reviewer I5 加的 "(coming in v1.0)" hint 占位形态——但因 v1.0 已到，hint 文案改为 "(coming later)" 或 "(not yet available)"，仍为 disabled/占位。施工只改 hint 文案，不接 EKEventStore。

**验收标准：**
- macOS / iOS 真机：点 "Sign in with Apple" → 系统授权弹窗 → 授权后 Account 行显示姓名 + email（首次）。
- 重启 App 仍显示已登录态（`getCredentialState` == `.authorized`，从 Keychain 读身份）。
- 在系统设置里撤销该 App 的 Apple ID 授权后，下次启动 App 检测到 `.revoked`，Account 行回到登出态。
- Sign out 按钮：点击后 Account 行回到 "Sign in with Apple"；**重要验证**：Sign out 后本地 Todo/Project/Event 数据仍在、CloudKit 同步仍工作（确认未误清库）。
- Calendar / Reminders mirror toggle 仍为占位 + hint，点击不接 EventKit、不崩。
- `LinoJCoreTests` 新增 `AppleSignInServiceTests`（state 流转 mock；Keychain 部分可用内存桩或跳过真 Keychain）。

**前置依赖：** V0（applesignin entitlement）。可与 V1/V2 并行（不依赖 CloudKit）。

---

### V4 — macOS 顶栏 toolbar 修复  [macOS]

**范围（修复 v0.9 验收偏离）：**
- v0.9 macOS 顶栏只有居中 4-tab Picker，缺设计稿（README Navigation → macOS + `direction-a.jsx`）要求的其它顶栏元素。V4 补齐 `RootWindow` 顶栏为：
  - **左侧**：LinoJ wordmark（文字 logo）+ 状态 dot（小圆点，颜色反映 CloudSyncMonitor 状态：synced=绿/灰、syncing=蓝、error=红；若 V1 未先做则 dot 固定中性色，V4 不硬依赖 V1）。
  - **中部 / 左**：现有 4-tab segmented `Picker`（Main / Personal / Company / Calendar）保留。
  - **右侧**：
    - "Search or jump" 按钮（看起来像搜索框入口，点击 = 触发 ⌘K，打开 Search palette；显示 mono "⌘K" hint）。
    - "+ New" 按钮（ink 样式，点击 = 触发 ⌘N，打开 Quick Add；显示 mono "⌘N" hint）。
- 用 SwiftUI `.toolbar` + `ToolbarItem(placement:)`（`.navigation` 放 wordmark、`.principal` 放 Picker、`.primaryAction` 放 Search + New），或在 `RootWindow` 顶部自绘一行 HStack（与 v0.9 当前实现方式对齐，避免大改窗口结构——builder 按现有 RootWindow 结构选最小改动路径）。
- 两按钮的 action 复用既有 `TabRouter.showSearch` / `showQuickAdd` + `quickAddDefaultKind = .todo`，与 ⌘K / ⌘N 快捷键走同一路径（不重复实现逻辑）。
- **iOS 对照检查**：iOS 已有右上两枚 floating glass 按钮（search + `+`，P3.1 实现）。V4 核对 iOS 是否也需调整——结论：iOS 顶栏设计稿即两枚 floating 按钮，**无 wordmark / segmented picker 需求**（iOS 用底部 glass tab bar 切 tab），故 **iOS 无需改动**，仅 macOS 补齐。若核对发现 iOS floating 按钮 action 有缺（应已在 P3.1/I4 接通），顺手验证。

**关键接口 / 类型契约：** 无新增类型。复用 `TabRouter`（v0.9 已有 `showSearch` / `showQuickAdd` / `quickAddDefaultKind`）。状态 dot 颜色可选接 `CloudSyncMonitor.status`（V1 产物），未做 V1 时传中性色。

**验收标准：**
- macOS 顶栏左侧显示 "LinoJ" wordmark + 状态 dot；中部 4-tab Picker；右侧 "Search or jump (⌘K)" + "+ New (⌘N)" 两按钮，视觉对齐 `direction-a.jsx`。
- 点右侧 Search 按钮 = 打开 Search palette（与按 ⌘K 等效）；点 "+ New" = 打开 Quick Add 默认 Todo（与按 ⌘N 等效）。
- 状态 dot 在 V1 已做时随同步状态变色；V1 未做时为中性色不报错。
- wordmark / 按钮文案走本地化（xcstrings 新增 key，中英）。
- iOS 顶栏经核对无变更（floating 按钮 action 正常）。

**前置依赖：** 无付费能力依赖（不依赖 V0/V1）。**可提前 / 并行施工**（建议放在 V1 之前或并行，作为「不阻塞」的纯 UI 修复）。状态 dot 若要接同步状态则软依赖 V1。

---

### V5 — Edit project 流程  [共享]

**范围（回答 README 开放问题 2）：**
- v0.9 Project Detail 的 "Edit project" 按钮是 print 占位。V5 接真：点击打开 Quick Add（Project 模式）的 **edit 变体**，预填既有 Project 的 title / intro / notes / tag / members，submit 走 **update** 而非新建。
- 复用 `QuickAddViewModel`，新增 edit 模式：init 接收一个可选 `editingProject: Project?`，非 nil 时进入编辑态，`submit()` 更新该实例而非 `context.insert` 新对象。
- 编辑保存后：**重算 `Project.memberCount`**（Reviewer F2 的冗余字段，编辑 members 后必须同步，否则 CloudKit 同步出脏数据——见 V1 约束第 7 条）。
- macOS：从 ProjectDetailView_macOS 的 "Edit project" outline button 打开（sheet，复用 QuickAddModal_macOS 的 Project 表单，标题改 "Edit project"，按钮 "Save"）。
- iOS：从 ProjectDetailView_iOS 的 `⋯` 菜单或 Edit 入口打开 QuickAddSheet_iOS 的 Project edit 变体。

**关键接口 / 类型契约：**
```swift
@Observable public final class QuickAddViewModel {
    // v0.9 既有签名保留；v1.0 新增 editingProject
    public init(context: ModelContext,
                defaultKind: Kind = .todo,
                prefilledProject: Project? = nil,
                defaultScope: Scope = .personal,
                editingProject: Project? = nil)   // 新增：非 nil → Project edit 模式
    public var isEditing: Bool { get }            // editingProject != nil
    // submit()：isEditing 时更新 editingProject 字段 + 重算 memberCount，否则 insert 新对象
    public func submit() throws -> AnyHashable
}
```
- `TabRouter` 新增 `quickAddEditingProject: Project? = nil`（打开 edit sheet 前设置，sheet onDisappear 清回 nil，与 v0.9 quickAddPrefilledProject 同模式）。

**验收标准：**
- ProjectDetailView "Edit project" 打开预填表单（title/intro/notes/tag/members 已填既有值），改 title 后 Save → detail 页标题立即更新、SwiftData 持久化、重启仍在。
- 改 members（加/减人）后 Save → `Project.memberCount` 同步更新，detail 页 "X members · since …" 数字正确。
- 跨端验证（若 V1/V2 已做）：A 端编辑 project，B 端同步刷新到新值。
- 新建 Project 路径（editingProject == nil）行为与 v0.9 完全一致，无回归。
- `LinoJCoreTests` 新增 `QuickAddViewModelEditTests`（edit 模式 update + memberCount 重算）。

**前置依赖：** v0.9 P3.5（Project Detail）+ P3.6（QuickAdd）。无付费能力依赖，**可并行 / 提前**。memberCount 同步逻辑与 V1 约束 7 关联。

---

### V6 — App Store Connect 配置 + 隐私 manifest + 收尾  [全栈 / 共享]

**范围：**
- 隐私清单 `PrivacyInfo.xcprivacy`（两端各一份，或放 LinoJCore 资源）：声明所用 Required Reason API（如 `UserDefaults` 访问 reason `CA92.1`、File timestamp 等）+ 数据收集类型（CloudKit 同步用户内容、Sign in with Apple 收 email/name）。CloudKit 数据存用户自己的 iCloud，通常归为「不离开设备 / 用户控制」，但 SIWA 的 email 需如实声明。
- App Store Connect App 记录（**用户网页操作**，见文末清单；本 Phase 配合）：确认统一 Bundle ID `com.linocai.linoj` 已在 ASC 关联、Name=LinoJ / SKU=LINOJ001 / 主语言=简中，iOS + macOS 两平台 build 挂同一记录。
- Archive 验证：两端 archive + Organizer 中 "Validate App"（不强制 "Distribute"）。确认 profile / capability / 隐私清单无校验错误。
- 收尾把 v0.9 未完成的 **P7（测试补全 / 文档 / Release 验证）** 中与 v1.0 相关的部分并入：v1.0 新增的 service（CloudSyncMonitor / AppleSignInService / RemoteNotificationCoordinator / QuickAddViewModel edit）补单测；Release scheme 两端 build + 启动验证（CloudKit 在 Release 用 production environment）。
- xcstrings 同步：V0-V5 新增的所有用户可见字符串（wordmark、Search/New 按钮、Sign in、sync 状态、Edit project / Save）中英双填，与 v0.9 P5 的 xcstrings + .lproj 双轨一致（见 Reviewer 修复记录 P5 双轨）。

**关键接口 / 类型契约：** 无新增代码类型；产物为 `PrivacyInfo.xcprivacy` plist + ASC 配置。

**验收标准：**
- 两端 Release scheme build BUILD SUCCEEDED，`swift build -Xswiftc -warnings-as-errors` 0 warning。
- 两端 archive → Organizer "Validate App" 通过（无 capability / 隐私清单 / profile 错误）。
- ASC 中存在 App 记录，Bundle ID 关联正确。
- 全量测试（v0.9 的 95 + v1.0 新增）全绿。
- Release 构建 CloudKit 走 production container（`aps-environment` = production）；干净安装登录同一 iCloud 仍能跨端同步（production schema 已部署，见网页清单 CloudKit Dashboard deploy to production）。
- 中英切换：v1.0 新增 UI 文案随系统语言正确切换。

**前置依赖：** V0..V5。CloudKit Dashboard "Deploy Schema to Production"（网页操作）是 Release 跨端同步的前置。

---

### V7 —（可选）v0.9 P7 遗留收尾  [共享]

**范围：** v0.9 P7（测试覆盖 ≥70% / LinoJCore README / Release 双端验证 / archive）若在 v0.9 收尾时未完全做完，在此补齐。与 V6 有重叠——**若 V6 已覆盖测试与 Release 验证，则 V7 仅剩 LinoJCore README 文档化一项**，builder 可将 V7 并入 V6 执行，不单独立里程碑。

**验收标准：** `swift test` 全绿且核心 ViewModel + Service ≥ 70% 行覆盖；LinoJCore 根 `README.md`（仅说明如何打开 workspace + 跑测试，不与本 plan 重叠）。

**前置依赖：** V6。

---

## v1.0 收口 Phase 列表（W 组：公开上线前最后缺口补齐）

> 本节由 2026-05-28「🚀 v1.0 公开上线剩余清单 ▸ 未实现的功能缺口」展开而成（用户已确认三块全做）。用 **W** 前缀编号（W1..W3），避免与 P0-P7 / V0-V7 混淆。施工原则同前：每个 Phase 内若涉及两端，**先 macOS 验收 → 再 iOS 验收**。本组三个 Phase 互相独立，可任意顺序，但都依赖 v0.9 + V5 已落地。
>
> **三条贯穿全 W 组的硬约束（builder 必须遵守，否则踩坑）：**
> 1. **CloudKit 约束**：所有 `@Model` 关系（含 to-many）必须 optional 类型 `[X]?`（不是 `[X] = []`）；禁用 `@Attribute(.unique)`；去重靠 UUID/业务层。选人器落库**只走既有** `Project.members: [Person]?` / `Event.attendees: [Person]?` 关系，访问点一律 `(rel ?? [])` 兜底。**本组不新增任何 `@Model`、不改任何模型 schema**（避免触发 CloudKit 迁移；W 组纯 UI + VM + 既有字段读写）。
> 2. **memberCount 冗余字段**：`Project.memberCount` 跨端 last-writer-wins，**每次编辑 members 后必须重算** `existing.memberCount = (members ?? []).count`。W1 的 Project 选人入口（含 V5 edit 路径）每次提交都要保证这点（V5 的 submit() 已重算，W1 复用同一 submit，不要新开旁路写 members）。
> 3. **本地化双轨**：任何新 UI 文案禁止 raw String 字面量。新增 key 三步——① 编辑 `Localizable.xcstrings`（manual extractionState，中英双填）② `xcrun xcstringstool compile Packages/LinoJCore/Sources/LinoJCore/Resources/Localizable.xcstrings -o Packages/LinoJCore/Sources/LinoJCore/Resources/` 重生两 lproj ③ `Strings.swift` 加 `LJStrings` 静态成员。各 Phase「需新增的本地化 key」小节已逐条列出；漏第②步 `swift test` 的 LocalizationTests（zh≠en 断言）会挂。

---

### W1 — Quick Add 的 Attendees / Members 选人器  [全栈 / 共享 VM + 两端 UI]

**范围（补 0.9.1 隐藏的最大缺口）：**
- 0.9.1 把 Quick Add 的 Attendees「+ Add」/ Members「+ Invite」两个空 stub 按钮隐藏成「整节仅在数组非空时渲染」（恒空 = 整节隐藏），导致**建 Event 加不了参会人、建 Project 加不了成员**。W1 接真：提供「从已有 Person 记录里多选」的选人器 UI + 落库。
- **作用域三处**：① Quick Add `.event` 表单的 Attendees 节；② Quick Add `.project` 表单的 Members 节；③ **复用同一选人器** 给 V5 Project edit 模式（edit 进来时 `projectMembers` 已预填既有 members，选人器要支持「在已选基础上增删」）。
- **本期范围裁剪（明确决策，builder 不要自由发挥）：**
  - **只做「从现有 Person 多选」**。是否「新建 Person」：**本期允许在选人器内「临时新建一个 Person」**（最小实现，下详），但**不做** Person 编辑 / 删除 / 头像 / 详情管理面板（v1.1+）。
  - **不新增模型 / 不改 schema**：候选人来自既有 `Person` 表（`@Query` 全部 Person），落库走既有 `Event.attendees` / `Project.members` 关系，VM 既有 `eventAttendees: [Person]` / `projectMembers: [Person]` 数组已存在（见 `QuickAddViewModel`），W1 只是给它们接上「增删入口」。
  - **去重**：选人列表内同一 Person 不可重复选（按 `Person.id` 去重）；「临时新建」时按 `name`（trim 后 case-insensitive）若已存在同名 Person 则复用既有那条、不再 insert（CloudKit 无唯一约束，靠此业务层去重避免重名 Person 堆积）。

**技术选型 / 决策：**
- **VM 落点**：在 `QuickAddViewModel` 上新增选人操作方法（见契约），**不新建独立 PeoplePickerViewModel**——选人状态（已选数组）本就是 QuickAddViewModel 的字段，加方法最内聚，且 V5 edit 路径已在该 VM 里。
- **候选人来源**：两端选人 UI 用 `@Query(sort: \Person.name) private var allPeople: [Person]` 拉全部 Person（与 QuickAdd 拉 `projects` 同模式），传进选人器；VM 不持有 `@Query`（@Model 非 Sendable，VM 只收 `[Person]` 快照或具体 Person 引用做增删）。
- **临时新建 Person**：选人器顶部一个搜索/输入框，输入 name 后若候选列表无匹配，提供一行「+ 新建『<name>』」。点击 → VM `addPerson(named:existing:target:)`：先按 trim+小写在传入的 allPeople 里查重名，命中则直接选中既有那条；否则 `Person(name:)` + `context.insert` + 立即选中（**不在此处 save**——随 Quick Add 整体 submit 一起 save）。
  - ⚠️ **事务边界注意**：QuickAddViewModel 用的是注入的 `modelContext`（与 App 主 context 同一个）。`context.insert(Person)` 后若用户取消 Quick Add，该 Person 仍在内存 context 里。**决策：临时新建的 Person 在「选中后立即 insert」**，并在 `submit()` 成功时随整体 save 落库；若用户取消（dismiss 未 submit），W1 **不强制回滚**（个人级数据，残留一条无引用 Person 可接受，下一版 People 管理面板可清）。builder 若想更严谨可在 onDisappear 未 submit 时 `context.rollback()`，但需确认不影响其它未保存改动——**默认采用「不回滚」最小实现**，把此权衡写进变更日志。
- **UI 形态**：
  - **macOS**：选人器做成 Quick Add modal 内的**内联展开区**（点 Attendees/Members 节的「+ 选择」按钮，原地展开一个 max-height 限高的可滚动 Person 列表 + 顶部输入框 + 已选 AvatarStack）。不另开二级 sheet（macOS `.sheet` 套 `.sheet` 体验差）。复用既有 `chip` / `AvatarStack` 组件视觉。
  - **iOS**：选人器做成从 Quick Add sheet **再 present 的二级 picker**（`.sheet` 叠 `.sheet` 在 iOS 26 可用，或用 `NavigationLink` push）。列表用原生 List 多选（每行 trailing checkmark），顶部 searchable 输入框 + 「+ 新建」行，右上「完成」回传已选。
  - 两端选完后回到 Quick Add，Attendees/Members 节渲染已选 `AvatarStack`（**移除 0.9.1 的「仅非空才渲染整节」隐藏逻辑**，恢复为始终渲染该节 + 一个「+ 选择 / + 添加」入口按钮；空态显示入口按钮 + 占位提示文案）。

**关键接口 / 类型契约：**
```swift
@Observable @MainActor public final class QuickAddViewModel {
    // 既有字段（W1 复用，不改类型）：
    //   public var eventAttendees: [Person] = []
    //   public var projectMembers: [Person] = []

    // W1 新增 —— Attendees（Event）增删：
    /// 切换某 Person 的选中态（已选则移除、未选则加入），按 Person.id 去重。
    public func toggleAttendee(_ person: Person)
    /// 当前 Person 是否已在 eventAttendees 中（按 id）。
    public func isAttendeeSelected(_ person: Person) -> Bool

    // W1 新增 —— Members（Project）增删：
    public func toggleMember(_ person: Person)
    public func isMemberSelected(_ person: Person) -> Bool

    // W1 新增 —— 临时新建 Person（在 existing 内查重名，命中则复用并选中）：
    /// - Parameters:
    ///   - name: 用户输入的名字（内部 trim；空白返回 nil 不创建）。
    ///   - existing: 当前 @Query 拉到的全部 Person（用于查重名）。
    ///   - target: 加到 attendees 还是 members。
    /// - Returns: 选中的 Person（既有复用或新建），nil 表示 name 空白未创建。
    @discardableResult
    public func addPerson(named name: String, existing: [Person], target: PersonTarget) -> Person?

    public enum PersonTarget: Sendable { case attendee, member }
}
```
- **落库路径不变**：`submit()` 的 `.event` 分支已把 `attendees: eventAttendees` 传给 `Event(...)`；`.project` 分支（create + V5 edit）已把 `members: projectMembers` 写入并 `memberCount = projectMembers.count` 重算。W1 **不改 submit()**（除非临时新建 Person 的 insert 需要——insert 在 `addPerson` 内做，submit 仍只负责整体 save）。
- **TabRouter / Person / Project / Event 模型：不改**。

**需新增的本地化 key（中英双填）：**
- `QuickAdd.attendeesAdd` = "+ Add attendee" / "+ 添加参会人"
- `QuickAdd.membersAdd` = "+ Add member" / "+ 添加成员"
- `QuickAdd.attendeesEmpty` = "No attendees yet" / "暂无参会人"
- `QuickAdd.membersEmpty` = "No members yet" / "暂无成员"
- `QuickAdd.peoplePickerTitle` = "Select people" / "选择人员"
- `QuickAdd.peopleSearchPlaceholder` = "Search or type a name…" / "搜索或输入名字…"
- `QuickAdd.peopleCreateNew` = "Create new person" / "新建人员"（实际行显示 "Create『<name>』"，name 由布局拼接，不进 key）
- `QuickAdd.peopleDone` = "Done" / "完成"
- `QuickAdd.peopleNoResults` = "No matching people" / "没有匹配的人员"

**拆分（共享 / macOS / iOS）：**
- **共享（先做）**：`QuickAddViewModel` 加 4 个 toggle/is 方法 + `addPerson` + `PersonTarget` 枚举；`LJStrings` 加上列 9 个 key + xcstrings 双填 + 重生 lproj。
- **macOS（次做，先验收）**：`QuickAddModal_macOS.swift` 的 `eventForm` Attendees 节 + `projectForm` Members 节，去掉「仅非空才渲染」逻辑，加内联展开选人区（输入框 + 限高滚动 Person 列表 + 选中 chip 行 + 已选 AvatarStack）。
- **iOS（末做，后验收）**：`QuickAddSheet_iOS.swift` 同两节，加二级 picker（List 多选 + searchable + 新建行 + 完成回传）。

**验收标准：**
- macOS：建 Event → 打开 Attendees 选人器 → 选 2 个既有 Person → 创建 → Calendar/Search 中该 event 显示 2 个 attendee 头像；建 Project → 选 3 个 Member → 创建 → ProjectDetail "X members" = 3 且 `Project.memberCount == 3`。
- macOS：输入一个不存在的名字 → 点「+ 新建」→ 该 Person 被选中并落库；再次建另一个 Event 时该 Person 出现在候选列表（去重生效，无重复条目）。
- macOS：V5 Edit project 进入 → Members 节预填既有成员 → 增删后 Save → `memberCount` 同步、ProjectDetail 数字正确、重启仍在。
- iOS：上述同等行为全部通过（attendees / members / 临时新建 / edit 增删 / memberCount 重算）。
- 取消 Quick Add（未 submit）后再建同类实体：上次选的人/输入不残留在表单（VM 随 sheet 重建）。
- `LinoJCoreTests` 新增 `QuickAddPeoplePickerTests`：toggle 去重、isSelected、addPerson 查重名复用 vs 新建、addPerson 空白名返回 nil、memberCount 经 submit 后等于 members.count。
- `swift test` 全绿（含 LocalizationTests zh≠en 对新 key）；`swift build -Xswiftc -warnings-as-errors` 0 warning；两端 build SUCCEEDED。

**前置依赖：** v0.9 P3.5/P3.6 + V5（复用 QuickAddViewModel edit 路径与 memberCount 重算）。无付费能力依赖。

---

### W2 — Settings 占位开关逐项收口（消费 or 隐藏）  [全栈 / 共享 VM 消费点 + 两端 UI]

**范围：** 当前一批 Settings 开关只写 UserDefaults、无任何消费方，UI 上标 "(coming later)"。W2 对每一项做明确决策——**能廉价真正接通的就接通并消费**，**依赖 EventKit 等重活的继续延后但明确隐藏**，避免上线像坏功能。

**逐项决策（已敲定，builder 严格执行）：**

| 字段 | 决策 | 做法 |
|---|---|---|
| `showCompletedInCounts` | ✅ **真接通并消费** | 计数受其影响（下详） |
| `systemBannerEnabled` | ✅ **真接通并消费** | 作为 `NotificationService.scheduleAll` 的总开关（下详） |
| `yesterdayMissedReminderEnabled` | ✅ **真接通并消费** | 作为 Main/Calendar「From yesterday」box 显示开关（下详） |
| `headsUpLeadMinutes` | （已消费，不在 W2 范围） | NotificationService 已用，去掉它的 "(coming later)" hint |
| `dailySummaryHour`（Daily summary） | ⏸ **延后 → 隐藏整行** | 需调度每日定时本地通知 + 内容聚合，重活，v1.1+。**从两端 Settings 隐藏该行**（连 Picker 一起），不留占位 |
| `quietHoursStart/End`（Quiet hours） | ⏸ **延后 → 隐藏整行** | 需在所有 schedule 路径套静音窗口判断，跨多处，v1.1+。**隐藏整行** |
| `calendarMirrorOn` / `remindersMirrorOn`（Apple Calendar/Reminders 镜像） | ⏸ **延后但保留并明确标注** | 依赖 EventKit（已是 V3 明确延后项，有 `Settings.eventKitLaterHint` = "(coming later)"）。**保留开关 + 保留 "(coming later)" hint** + **追加 `.disabled(true)`** 让 toggle 不可拨（写 UserDefaults 但无消费，可拨会误导用户以为生效）|

**三项「真接通」的消费契约：**

1. **`showCompletedInCounts`**——影响「计数」是否含已完成 todo：
   - 受影响的计数（当前都只数 `!done`）：`MainViewModel.openCount`、`PersonalViewModel.openCount`、`CompanyViewModel.todosCount`、`ProjectDetailViewModel.openCount`。
   - **决策**：当 `showCompletedInCounts == true`，这些「open 计数」改为「全部（含 done）」即 `.count`；false 时维持现状 `.filter { !$0.done }.count`。**urgentCount / doneCount / kanban 列内容不变**（urgent 永远只数未完成，done 列本就是 done；本开关只动「总数/open 计数」语义）。
   - **VM 怎么拿到这个 bool**：各 ViewModel **新增一个 `includeCompletedInCounts: Bool = false` 存储属性**，由 View 在构造 / `refresh()` 时从 `SettingsViewModel.showCompletedInCounts` 注入（与现有 `headsUpLeadMinutes` 注入同模式）。VM 不直接读 UserDefaults（保持可测、注入式）。计数 getter 内按此 flag 分支。
   - View 侧：Settings 改这个开关后，对应屏幕的计数需刷新——在各屏 `.onChange(of: settings.showCompletedInCounts)` 里调 `vm.includeCompletedInCounts = settings.showCompletedInCounts; vm.refresh()`（或重建 VM）。

2. **`systemBannerEnabled`**——本地通知横幅总开关：
   - **决策**：作为 `NotificationService.scheduleAll(...)` 的**前置闸门**。两端 RootWindow/RootTabView 现有「申请授权 + scheduleAll」与「headsUpLeadMinutes onChange 重排」逻辑，全部加判断：`systemBannerEnabled == false` → **不 scheduleAll 且 `cancelAll()` 清掉已排队的**；`true` → 维持现状调度。
   - 新增 `.onChange(of: settings.systemBannerEnabled)`：true→重新 scheduleAll；false→`NotificationService().cancelAll()`。
   - `NotificationService` 已有清空入口（`removeAllPendingNotificationRequests`，见现有代码），W2 不改 service，只在两端 App 壳层加闸门。

3. **`yesterdayMissedReminderEnabled`**——「From yesterday」未确认 box 显示开关：
   - **决策**：作为 Main / Calendar 的「From yesterday」dashed-border box 的**显示闸门**。当 false 时不渲染该 box（不影响数据，只是不催）。
   - **怎么接**：`MainViewModel` / `CalendarViewModel` 新增 `showYesterdayMissed: Bool = true` 存储属性，View 从 `settings.yesterdayMissedReminderEnabled` 注入；VM 暴露的 `yesterdayMissed` 列表 getter 在 flag 为 false 时返回 `[]`（最省——下游渲染「非空才显示」逻辑不变，box 自然消失）。
   - `.onChange(of: settings.yesterdayMissedReminderEnabled)` 注入新值 + `refresh()`。

**技术选型 / 决策：**
- **不改 `SettingsViewModel`**（字段、默认值、persist 全保留——SettingsPersistenceTests 仍断言这些字段存在）。W2 只在「消费方」接通三项 + UI 隐藏/禁用四项。dailySummary/quietHours 字段保留在 VM（仅 UI 不再展示），避免动测试与持久化。
- **隐藏 ≠ 删字段**：dailySummary / quietHours 只从两端 Settings View 移除 UI 行，VM 字段 + UserDefaults key + 测试全留（向后兼容 + 不破坏 SettingsPersistenceTests）。
- 各 ViewModel 加注入 bool 属性而非读 UserDefaults，保持单测注入式（现有测试模式）。

**需新增 / 调整的本地化 key：**
- 无需新增用户可见文案 key（接通三项不引入新文案；隐藏 dailySummary/quietHours 是删 UI，不加 key）。
- **调整**：去掉 `showCompletedInCounts` / `systemBannerEnabled` / `yesterdayMissedReminderEnabled` 三行的 `Settings.v1OnlyHint`（"(coming later)"）展示（它们现在真生效了，挂 "(coming later)" 是错的）。`Settings.v1OnlyHint` key 本身保留（其它地方或未来用），仅这三行 UI 不再传 `v1Hint: true`。`headsUpLeadMinutes` 行若挂了该 hint 也一并去掉（它早已生效）。

**拆分（共享 / macOS / iOS）：**
- **共享（先做）**：`MainViewModel` / `PersonalViewModel` / `CompanyViewModel` / `ProjectDetailViewModel` 加 `includeCompletedInCounts` 并改对应 open 计数 getter；`MainViewModel` / `CalendarViewModel` 加 `showYesterdayMissed` 并让 `yesterdayMissed` getter 据此短路。
- **macOS（次做，先验收）**：`SettingsView_macOS.swift` —— 三行去 "(coming later)"、`calendarMirrorOn/remindersMirrorOn` 两行 `.disabled(true)`、删 dailySummary + quietHours 两块 UI；`RootWindow.swift` —— scheduleAll 加 `systemBannerEnabled` 闸门 + onChange；各屏 View 注入 `includeCompletedInCounts` / `showYesterdayMissed` + onChange 刷新。
- **iOS（末做，后验收）**：`SettingsSheet_iOS.swift` 同 macOS 的 UI 改动；`RootTabView.swift` 同 RootWindow 的闸门与 onChange；各屏 View 同注入。

**验收标准：**
- `showCompletedInCounts` ON：Main/Personal/Company/ProjectDetail 的「总数/open 计数」含已完成 todo（数字变大）；OFF：恢复只数未完成。切换即时反映（无需重启）。urgent 列计数与 kanban 内容不受影响。
- `systemBannerEnabled` OFF：再建未来 Event 不再排本地通知（`UNUserNotificationCenter.getPendingNotificationRequests` 为空 / 不增）；ON：恢复调度。
- `yesterdayMissedReminderEnabled` OFF：Main 与 Calendar 不再显示「From yesterday」box；ON：恢复显示。
- 两端 Settings 中 **dailySummary / quietHours 行已消失**；`calendarMirrorOn`/`remindersMirrorOn` 仍在、带 "(coming later)"、且**不可拨动**（`.disabled`）。
- 三个已接通开关行**不再显示 "(coming later)"**。
- `LinoJCoreTests` 新增/扩充：各 ViewModel `includeCompletedInCounts` true/false 下计数差异；`MainViewModel`/`CalendarViewModel` `showYesterdayMissed=false` 时 `yesterdayMissed` 为空。SettingsPersistenceTests 不回归（字段全在）。
- `swift test` 全绿；`swift build -Xswiftc -warnings-as-errors` 0 warning；两端 build SUCCEEDED。

**前置依赖：** v0.9 P3.8（Settings）+ P4（通知 / YesterdayMissed 服务）+ V3（EventKit 镜像延后决策）。无付费能力依赖。

---

### W3 — ProjectDetail ⋯ 菜单 / Search 精确定位 / Settings About 链接 收口  [全栈]

**范围：** 三个零散 no-op 收口，逐项实现或合理砍掉。

**逐项决策：**

1. **ProjectDetail ⋯ 菜单**：
   - **现状**：iOS 的 `⋯` 已是 `Menu` 含「Edit project」（V5 已接，**不动**）；macOS 的 `⋯` 仍是空 `Button`（点击 no-op，0.9.1 占位）。
   - **决策（macOS）**：把 macOS 的 `⋯` 空 Button **改为 SwiftUI `Menu`**，菜单项与 iOS 对齐：
     - 「Edit project」→ `router.quickAddEditingProject = project; router.showQuickAdd = true`（复用 V5 路径，与 iOS 一致）。
     - 「Delete project」→ 弹确认（macOS `.confirmationDialog` 或 alert），确认后删除 + 从 NavigationStack pop 回 Company（`navigationPath` 清空/removeLast）。Delete 是 W3 新增能力（两端都加，见下）。
   - **决策（iOS）**：iOS 的 `⋯` Menu **追加「Delete project」项**（与 macOS 对齐），确认后删除 + pop。
   - **删除语义**：`Project` 的 `todos`/`events` 反向关系 deleteRule 是 `.nullify`（删 Project 不级联删 Todo/Event，它们变 standalone——见 Project.swift）。W3 删除沿用此既有语义，**不改 deleteRule**，删完这些 todo/event 仍在（scope/standalone），符合既有设计。

2. **Search 结果精确定位**：
   - **现状**：`SearchViewModel.open(_:)` 对 todo/event/project 只切 tab（带 3 个 `TODO P3+ 跨视图`），不定位到具体 bubble/事件/项目详情。
   - **决策（全部实现，按性价比分级）：**
     - **project**：✅ **精确 push 到 ProjectDetail**。TabRouter 新增 `pendingProjectID: UUID?`；`open(.project(id))` 切 `.company` tab + 设 `pendingProjectID = id`。CompanyView 监听 `router.pendingProjectID`，非 nil 时把它 append 进 `navigationPath`（既有 NavigationStack path 是 `[UUID]`，destination 已按 UUID 解析 ProjectDetail——天然契合）+ 清回 nil。
     - **event**：✅ **定位到事件那天**。TabRouter 新增 `pendingEventDate: Date?` + `pendingEventID: UUID?`；`open(.event(id))` 反查 event 拿 `start`，切 `.calendar` tab + 设 `pendingEventDate = startOfDay(start)`、`pendingEventID = id`。CalendarView 监听 `pendingEventDate`，非 nil 时把 `selectedDay`（CalendarViewModel 既有）设过去 + 清回 nil。**高亮具体事件卡**：本期**做到「定位到那天」即可**，事件卡高亮（闪一下/选中态）作为可选增强——若 CalendarViewModel 已有 `selectedEventID` 之类则接上，否则**砍掉高亮，只滚动/切到那天**（写进验收）。
     - **todo**：✅ **定位到正确 tab + 滚动到该 bubble（尽力）**。TabRouter 新增 `pendingTodoID: UUID?`；`open(.todo(id))` 反查 scope 切 `.personal`/`.company` + 设 `pendingTodoID`。对应屏用 `ScrollViewReader` + `.id(todo.id)`，监听 `pendingTodoID` 非 nil 时 `proxy.scrollTo(id, anchor: .center)` + 清回 nil。**若该 todo 被当前 chip filter 隐藏**（如 Company 选了某 project chip 而 todo 属另一 project）：先把 filter 重置为「全部」再滚动（最小实现：切 tab 时一并重置该屏 filter 到 All）。bubble 高亮同 event——**有就接、没有就只滚动**。
   - **统一清理**：`SearchViewModel.open` 在切 tab/设 pending 后仍 `router.showSearch = false`（不变）。移除三处 `TODO P3+` 注释，换成实现说明。

3. **Settings About 链接**：
   - **现状**：macOS `aboutLinkRow` / iOS About 行点击 no-op（0.9.1 占位）；含 Release notes / Feedback(email) / Privacy / Acknowledgements。
   - **决策（逐条）：**
     - **Feedback（email）**：✅ 实现——点击 `openURL(URL(string: "mailto:feedback@linoj.app")!)`（两端 `@Environment(\.openURL)`）。这是最有用且零成本的。
     - **Privacy（隐私政策）**：✅ 实现——指向一个真实 URL。**决策：用户需提供隐私政策 URL**（上架 App Store 本就必须有隐私政策页）；builder 把 URL 设为 `LinoJCore` 里一个常量 `LinoJLinks.privacyPolicy`，**默认填占位 `https://linoj.app/privacy`**，并在变更日志标注「待用户替换为真实 URL」。点击 `openURL`。
     - **Release notes**：⏸ **本期砍掉该行**（没有真实 release notes 页 / app 内更新日志体系，留个死链或假页更糟）。两端移除 Release notes 行。
     - **Acknowledgements（致谢/开源许可）**：⏸ **本期砍掉该行**（无第三方依赖需致谢——项目纯 Apple SDK + 自有代码；放空页无意义）。两端移除该行。
   - 结果：About 链接区**只剩 Feedback + Privacy 两行**，都真能点开。

**技术选型 / 决策：**
- **导航定位走 TabRouter 的 `pending*` 信号 + 各屏 onChange 消费**（与既有 `quickAddPrefilledProject` / `quickAddEditingProject` 同模式：router 设值 → 目标 View 监听消费后清回 nil）。**不引入新的全局 navigation 框架 / Coordinator**。
- 高亮（bubble/event 选中闪烁）**列为可选**——builder 评估各 VM 是否已有承载字段；**无则本期不做高亮，只做滚动/切换定位**，把「未做高亮」写进变更日志，不算缺验收。
- 链接常量集中到 `LinoJCore`：新增 `public enum LinoJLinks`（含 `feedbackEmail` / `privacyPolicy`，后者待用户替换真实 URL）。
- Delete project 的确认对话框文案需本地化。

**需新增的本地化 key（中英双填）：**
- `ProjectDetail.delete` = "Delete project" / "删除项目"
- `ProjectDetail.deleteConfirmTitle` = "Delete this project?" / "删除该项目？"
- `ProjectDetail.deleteConfirmMessage` = "Its todos and events will become standalone. This can't be undone." / "其下的待办和事件将变为独立项。此操作无法撤销。"
- `ProjectDetail.deleteConfirmConfirm` = "Delete" / "删除"
- 取消按钮若已有通用 Cancel key（如 `quickAddCancel`）则复用，不重复加。
- About 的 Feedback/Privacy 行 label 已有既有 key `aboutFeedback` / `aboutPrivacy`，不新增；移除 Release notes/Acknowledgements 行不需删 key，留着无害。

**关键接口 / 类型契约：**
```swift
// TabRouter 新增（精确定位信号；目标 View 监听消费后清回 nil）
@Observable @MainActor public final class TabRouter {
    public var pendingProjectID: UUID? = nil   // CompanyView push ProjectDetail
    public var pendingEventDate: Date? = nil    // CalendarView 设 selectedDay
    public var pendingEventID: UUID? = nil      // 可选高亮（无承载字段则忽略）
    public var pendingTodoID: UUID? = nil       // 目标屏 scrollTo
}

// LinoJCore 新增链接常量
public enum LinoJLinks {
    public static let feedbackEmail = "feedback@linoj.app"
    public static let privacyPolicy = "https://linoj.app/privacy" // ⚠️ 待用户替换真实 URL
}

// SearchViewModel.open(_:) 改写三分支：切 tab 同时设 router.pending*；不再只切 tab。
// ProjectDetailViewModel 新增 deleteProject()：context.delete(project) + try save()，供两端复用。
```

**拆分（共享 / macOS / iOS）：**
- **共享（先做）**：`TabRouter` 加 4 个 `pending*`；`SearchViewModel.open` 三分支接 `pending*`（移除 TODO 注释）；`LinoJLinks` 常量；`ProjectDetailViewModel` 加 `deleteProject()`；`LJStrings` 加上列 delete 相关 key + xcstrings 双填 + 重生 lproj。
- **macOS（次做，先验收）**：`ProjectDetailView_macOS.swift` 空 `⋯` Button → `Menu`（Edit + Delete + 确认弹窗 + pop）；`CompanyView_macOS.swift` 监听 `pendingProjectID` append path；`CalendarView_macOS.swift` 监听 `pendingEventDate` 设 selectedDay；Personal/Company/Main 屏接 `pendingTodoID` 滚动；`SettingsView_macOS.swift` About 区删 Release/Acks 两行、Feedback/Privacy 接 openURL。
- **iOS（末做，后验收）**：`ProjectDetailView_iOS.swift` Menu 加 Delete 项 + 确认 + pop；`CompanyView_iOS.swift` / `CalendarView_iOS.swift` / 各屏同 macOS 监听 `pending*`；`SettingsSheet_iOS.swift` About 区同改。

**验收标准：**
- Search 选一个 project 结果 → 直接进入该 ProjectDetail 页（不是停在 Company 列表）。
- Search 选一个 event 结果 → 切到 Calendar 且定位到该事件所在那天（selectedDay 正确）。
- Search 选一个 todo 结果 → 切到正确 tab（personal/company）并滚动到该 bubble（若被 filter 隐藏则 filter 已重置为 All）。
- macOS ProjectDetail `⋯` → 出现 Edit project + Delete project 菜单；Delete → 确认弹窗 → 确认后项目删除、回到 Company 列表、其 todos/events 变 standalone 仍存在。
- iOS ProjectDetail `⋯` → Edit + Delete 两项，Delete 行为同 macOS。
- Settings About：Feedback 点击拉起邮件 compose（mailto）；Privacy 点击打开浏览器到隐私 URL；**Release notes / Acknowledgements 两行已移除**。
- `LinoJCoreTests`：`SearchViewModelTests` 扩充 open 设置正确的 `router.pending*`；`ProjectDetailViewModelTests` 加 `deleteProject()`（删除后 project 不在 context、其 todos.project == nil）。
- `swift test` 全绿（含新 key LocalizationTests）；`swift build -Xswiftc -warnings-as-errors` 0 warning；两端 build SUCCEEDED。

**前置依赖：** v0.9 P3.5/P3.7/P3.8 + V5（Edit project 路径）。无付费能力依赖。

---

## v1.0 真机问题修复 Phase 列表（W 组续：W4..W6）

> 本节由 2026-05-28 用户在真机/桌面（**主用 macOS**）实际使用 0.9.1 后反馈的「不能操作」批量问题展开（主控已逐条定点到代码）。延续 **W** 前缀编号（W4..W6）。施工原则不变：每个 Phase 内涉及两端时**先 macOS 实现并验收 → 再 iOS**（用户优先 macOS）。三条贯穿全 W 组的硬约束（见上方 W1..W3 引言）**继续完全适用**，逐条复述供 W4..W6 直接对照：
>
> 1. **CloudKit 约束**：所有 `@Model` 关系（含 to-many）必须 optional `[X]?`；禁用 `@Attribute(.unique)`；去重靠 UUID/业务层。**本组不新增任何 `@Model`、不改任何模型 schema**——事件 CRUD 全部基于既有 `Event` 字段（`title/start/end/location/attendees?/project?/attendedConfirmed`）。访问关系一律 `(rel ?? [])` 兜底。
> 2. **memberCount 冗余字段**：W4..W6 不触碰 `Project.members` 写入路径（事件编辑只动 `Event.attendees`，不动 Project；W5 接通 ProjectDetail 的 add-event/add-todo 也只是设 router 信号打开 QuickAdd，落库仍走既有 submit），故 memberCount 重算责任仍在 W1/V5 既有 submit 内，本组无新旁路。
> 3. **本地化双轨**：任何新 UI 文案禁止 raw String 字面量。新增 key 三步——① 编辑 `Packages/LinoJCore/Sources/LinoJCore/Resources/Localizable.xcstrings`（manual extractionState，中英双填）② `xcrun xcstringstool compile Packages/LinoJCore/Sources/LinoJCore/Resources/Localizable.xcstrings -o Packages/LinoJCore/Sources/LinoJCore/Resources/` 重生两 lproj ③ `Strings.swift` 加 `LJStrings` 静态成员。各 Phase「需新增的本地化 key」小节已逐条列出；漏第②步 `swift test` 的 LocalizationTests（zh≠en 断言）会挂。
>
> **关于「已实现、仅需重新部署到 macOS 桌面验证」的两点澄清**（用户测的是旧 0.9.1 build，W1/V5/W3 尚未部署到他桌面上）：
> - **问题②「项目删除 / ⋯」**：**已由 W3 实现**（两端 ProjectDetail 的 ⋯ 已接 Edit + Delete，`ProjectDetailView_macOS.swift:112`/`ProjectDetailView_iOS.swift:180` 一带）。用户旧版本看到的空 stub 是 0.9.1 占位。**无需新 Phase**，只需把 W3 build 重新部署到 macOS 桌面后实测「⋯ → Delete project → 确认 → pop 回 Company」即生效。
> - **问题④的「成员选人器」部分**：编辑项目表单的「成员选人器」**已由 W1 实现**（`QuickAddModal_macOS.swift` projectForm Members 节内联展开选人区）。用户测的旧版本无选人器，**重新部署 W1 build 即恢复**，不需重新规划成员。④ 真正还需做的只剩下方 W6 的「编辑模式隐藏分段控件」小 UX 项。

---

### W4 — 事件可操作：编辑 / 删除 / 标记已出席  [全栈 / 共享 VM + 两端 UI]

**范围（补真机反馈①——最重要、macOS 优先）：**
- **现状定点**：`EventCard.swift` 四个 variant 全是纯展示，无任何点击/编辑/完成入口；事件卡在各屏裸渲染（macOS 周视图 `CalendarView_macOS.swift:495` `.macWeekGrid`、macOS Main 右栏 `MainView_macOS.swift:434` `.macRail`；iOS `CalendarView_iOS.swift:342` `.iosFull`、iOS Main `.iosMini`），均未套点击。全工程无任何「事件编辑」路径（`QuickAddViewModel` 只有 `editingProjectID`，事件仅能新建）。「完成」语义 = `Event.attendedConfirmed`，VM/Service 已有 `confirmAttended(_:)`（`CalendarViewModel:197`/`MainViewModel:218`/`YesterdayMissedService:59`），但只接在「From yesterday」漏确认 box（`CalendarView_iOS.swift:368` / `MainView_macOS.swift:388`），正常事件卡上无完成入口。
- W4 接真，给事件补齐三类操作：**编辑**（改 title/时间/location/attendees/project）、**删除**、**标记已出席**（attendedConfirmed）。复用 V5「Project 编辑」成熟模式，给 `QuickAddViewModel` 增 event edit 模式。

**「完成」语义最终决策（最小合理实现，不过度设计）：**
- 事件「完成」= `attendedConfirmed = true`，语义为「我参加了这个事件」。对日历 app，这只对**已结束的事件**（`event.end <= now`）有意义——给未来事件标「已出席」无逻辑。**决策**：
  - **「标记已出席 / Mark attended」操作仅在事件已结束（`end <= 现在时间，DEBUG 走 LinoJTime.today()`）时出现**；未来 / 进行中事件不显示该操作（避免无意义勾选）。
  - 已 `attendedConfirmed == true` 的过去事件，该操作翻转为「取消已出席 / Unmark attended」（调 VM 把 `attendedConfirmed` 设回 false），保证可逆、不卡死。
  - 编辑 / 删除两个操作**不分过去未来，恒可用**（编辑和删除覆盖了用户绝大多数「操作不了」的诉求；标记已出席只是补「过去事件」这一窄场景）。

**技术选型 / 决策：**
- **事件编辑落点（复用 V5 模式，不新建 VM）**：`QuickAddViewModel` 新增 event edit 模式，与既有 `editingProject` 完全对称：
  - init 新增可选参 `editingEvent: Event?`；非 nil → 强制 `kind = .event`（无视 defaultKind），把既有 event 的 title/start/end/location/attendees/project 预填进 `eventTitle`/`eventDate`/`eventStart`/`eventEnd`/`eventLocation`/`eventAttendees`/`eventProject`，记录 `editingEventID: UUID?`。
  - **时间拆装**：现有 VM 把 event 时间拆成 `eventDate`(y/m/d) + `eventStart`/`eventEnd`(h/m)，submit 时 `compose` 回单一 Date。预填时把 `editing.start` 同时灌进 `eventDate`（取日期）与 `eventStart`（取时分）、`editing.end` 灌进 `eventEnd`。
  - `isEditingEvent: Bool { editingEventID != nil }`；既有 `isEditing` 维持「= 是否 project edit」语义不变（避免改动 V5 既有判断），W4 另引入 `isEditingEvent` 与（可选）一个聚合 `isEditingAny`（见契约）。
  - `submit()` 的 `.event` 分支：`editingEventID` 非 nil 时按 ID `#Predicate` fetch 既有 event，原地回写 title/start/end/location/attendees/project（`attendees` 直接赋 `eventAttendees`，类型 `[Person]?` 兜底）、`context.save()`、返回原 id；fetch 不到（极端：edit 期间被删/跨端同步删除）回退为创建，避免静默丢输入（与 V5 project edit 完全同构）。**不改 memberCount**（事件编辑不动 Project.members）。
- **删除事件落点**：复用既有 VM 上事件删除能力——`CalendarViewModel` / `MainViewModel` 各新增 `deleteEvent(_ event: Event)`：`context.delete(event)` + `try? context.save()` + `refresh()`（与既有 `confirmAttended` 同模式、同 VM）。
- **标记已出席落点**：复用既有 `confirmAttended(_:)`；新增对称的 `unconfirmAttended(_ event: Event)`（`attendedConfirmed = false` + save + refresh），供「取消已出席」用。两端 Main/Calendar 屏已持有对应 VM。
- **事件卡如何变可操作（UI 形态）——`EventCard` 本身保持纯展示（不在组件内塞回调，避免污染四 variant 的纯渲染语义），由各屏在外层套交互：**
  - **macOS（先做先验收，用户优先）**：
    - 周视图卡（`.macWeekGrid`）：外层套 `.onTapGesture` 打开**事件编辑**（设 `router` 信号打开 QuickAdd edit-event 模式，见下「编辑入口走 router」）；同时套 `.contextMenu`（右键菜单）含 Edit / Mark attended(过去且未确认) or Unmark attended(过去且已确认) / Delete（带二次确认）三项。macOS 右键菜单是桌面用户最自然的多操作入口。
    - Main 右栏 row（`.macRail`）：同样套 `.onTapGesture` 打开编辑 + `.contextMenu` 同上。
  - **iOS（后做后验收）**：
    - Calendar 大卡（`.iosFull`）：外层套 `.onTapGesture` 打开编辑 + `.contextMenu`（长按菜单）同上三项。
    - Main mini 卡（`.iosMini`）：套 `.onTapGesture` 打开编辑 + `.contextMenu`。
  - 删除确认：macOS 用 `.confirmationDialog`/alert，iOS 用 `.confirmationDialog`（文案见本地化 key）。
- **编辑入口走 router（与 V5 quickAddEditingProject 同模式）**：`TabRouter` 新增 `quickAddEditingEvent: Event? = nil`。事件卡点击 / 菜单 Edit → `router.quickAddEditingEvent = event; router.showQuickAdd = true`。两端 QuickAdd sheet 在构造 VM 时传 `editingEvent: router.quickAddEditingEvent`；sheet `onDisappear` 清回 nil（与 `quickAddEditingProject` 完全同模式，两个 editing 字段互斥——同一时刻只设一个）。
- **不改 schema、不新增 @Model**：事件 CRUD 全部基于既有 `Event` 字段；`attendees` 编辑回写走 W1 既有选人器（QuickAdd 事件表单 Attendees 节已有，edit 模式预填既有 attendees 后可增删）。

**关键接口 / 类型契约：**
```swift
@Observable @MainActor public final class QuickAddViewModel {
    // 既有：editingProjectID / isEditing（= project edit）保持不变。

    // W4 新增 —— Event edit 模式：
    public private(set) var editingEventID: UUID?
    /// 是否处于 Event edit 模式。
    public var isEditingEvent: Bool { editingEventID != nil }
    /// 是否处于任一 edit 模式（project 或 event）。UI 用它统一判断「标题/按钮文案切 Edit/Save」+「隐藏/锁分段控件」。
    public var isEditingAny: Bool { isEditing || isEditingEvent }

    // init 新增参数（与 editingProject 对称，二者互斥；都为 nil 则 create 模式）：
    public init(context: ModelContext,
                defaultKind: Kind = .todo,
                prefilledProject: Project? = nil,
                defaultScope: Scope = .personal,
                editingProject: Project? = nil,
                editingEvent: Event? = nil)   // 新增：非 nil → Event edit 模式（强制 kind=.event，预填字段）
    // submit() 的 .event 分支：editingEventID 非 nil 时 fetch 既有 event 回写 + save 返回原 id；
    //                          fetch 不到回退创建；editingEventID == nil 时维持既有 insert 新 Event。
}

@Observable @MainActor public final class TabRouter {
    // W4 新增（与 quickAddEditingProject 同模式：入口设值 → sheet onDisappear 清回 nil）：
    public var quickAddEditingEvent: Event? = nil
}

// CalendarViewModel / MainViewModel 各新增（与既有 confirmAttended 同 VM、同 save+refresh 模式）：
public func deleteEvent(_ event: Event)        // context.delete + save + refresh
public func unconfirmAttended(_ event: Event)  // attendedConfirmed = false + save + refresh
// 既有 confirmAttended(_:) 复用为「标记已出席」。
```

**需新增的本地化 key（中英双填）：**
- `Event.edit` = "Edit event" / "编辑事件"
- `Event.delete` = "Delete event" / "删除事件"
- `Event.markAttended` = "Mark attended" / "标记已出席"
- `Event.unmarkAttended` = "Unmark attended" / "取消已出席"
- `Event.deleteConfirmTitle` = "Delete this event?" / "删除该事件？"
- `Event.deleteConfirmMessage` = "This can't be undone." / "此操作无法撤销。"
- `Event.deleteConfirmConfirm` = "Delete" / "删除"
- `QuickAdd.editEventTitle` = "Edit event" / "编辑事件"
- 取消按钮复用既有 `QuickAdd.cancel`（`quickAddCancel`），不重复加；Save 复用既有 `QuickAdd.save`（`quickAddSave`）。

**拆分（共享 / macOS / iOS）：**
- **共享（先做）**：`QuickAddViewModel` 加 `editingEvent` init 参 + `editingEventID` + `isEditingEvent` + `isEditingAny` + submit `.event` edit 分支 + 预填逻辑；`TabRouter` 加 `quickAddEditingEvent`；`CalendarViewModel` / `MainViewModel` 加 `deleteEvent` + `unconfirmAttended`；`Strings.swift` 加上列 8 key + xcstrings 双填 + 重生两 lproj。`EventCard.swift` **不改**（保持纯展示）。
- **macOS（次做，先验收）**：`CalendarView_macOS.swift`（周视图 `.macWeekGrid` 套 onTap + contextMenu）；`MainView_macOS.swift`（`.macRail` row 套 onTap + contextMenu）；`QuickAddModal_macOS.swift`（VM 构造传 `editingEvent: router.quickAddEditingEvent`、标题/按钮 edit-event 文案、onDisappear 清 `quickAddEditingEvent`、edit-event 模式不显未来事件的标记已出席）；删除确认弹窗。两屏需 `@Environment(TabRouter.self)`（核对是否已有）。
- **iOS（末做，后验收）**：`CalendarView_iOS.swift`（`.iosFull` 套 onTap + contextMenu + 删除确认）；`MainView_iOS.swift`（`.iosMini` 同）；`QuickAddSheet_iOS.swift`（同 macOS 的 VM 构造 / 文案 / onDisappear）。

**验收标准：**
- macOS：周视图点事件卡 → 打开 QuickAdd（事件编辑模式，标题「编辑事件」、按钮「保存」），title/时间/location/attendees/project 已预填既有值；改 title 后保存 → 周视图该卡标题立即更新、SwiftData 持久化、重启仍在。
- macOS：周视图右键事件卡 → 出现 Edit / Delete（+ 过去事件出现 Mark/Unmark attended）；Delete → 确认弹窗 → 确认后该事件从周视图消失、重启不复现。
- macOS：对一个**已结束**事件右键 → 出现「标记已出席」，点击后 `attendedConfirmed = true`（再次右键变「取消已出席」，可逆）；对一个**未来**事件右键 → **不出现**标记已出席项（只有 Edit / Delete）。
- macOS Main 右栏 row 同样可点编辑、右键删除/标记。
- iOS：Calendar `.iosFull` 与 Main `.iosMini` 点击进编辑、长按菜单 Edit/Delete/Mark(过去)，行为与 macOS 一致。
- 编辑事件改 attendees（经 W1 选人器增删）后保存 → 该事件 attendee 头像数正确、重启仍在。
- 取消 QuickAdd（未 submit）后再点同一事件：表单仍正确预填该事件既有值（VM 随 sheet 重建、router 信号未清前提下）。
- `LinoJCoreTests` 新增 `QuickAddViewModelEventEditTests`（event edit 模式预填字段、submit 走 update 而非新建、fetch 不到回退创建、attendees 回写）+ `CalendarViewModelTests`/`MainViewModelTests` 扩 `deleteEvent`（删后 event 不在 context）/ `unconfirmAttended`（true→false）；`LocalizationTests` 加 W4 8 key 的 zh≠en 断言。
- `swift test` 全绿；`swift build -Xswiftc -warnings-as-errors` 0 warning；两端 build SUCCEEDED。

**前置依赖：** v0.9 P3.2/P3.3/P3.6 + W1（事件 Attendees 选人器，edit 模式增删 attendees 复用它）+ V5（QuickAddViewModel edit 模式与 router editing 字段同模式）。无付费能力依赖。

---

### W5 — ProjectDetail「关联事件 + 添加」/「添加待办」接通  [全栈]

**范围（补真机反馈③）：**
- **现状定点**：ProjectDetail 的「+ 添加事件」按钮（`ProjectDetailView_macOS.swift:438` / `ProjectDetailView_iOS.swift:420`）是空 stub（注释「0.9.1：add event 尚未接通」），**且文案误用了 `LJStrings.addTodo`**（应是「添加事件」）；同屏的「+ 添加待办」按钮（`ProjectDetailView_macOS.swift:325`）同为空 stub。W5 接通这两个按钮 + 修正误用文案。
- **不在范围**：ProjectDetail 内的事件卡 / 待办 bubble 的点击编辑——若 W4（事件可操作）已落地，ProjectDetail 内若也裸渲事件卡可顺带复用 W4 的 onTap（builder 评估，**非 W5 必做**，写进验收为可选）。W5 只确保「+ 添加事件 / + 添加待办」两个入口能打开预填了该 project 的 QuickAdd。

**技术选型 / 决策：**
- **接通方式（复用既有 `prefilledProject` 能力，无新逻辑）**：`QuickAddViewModel` 既有 `prefilledProject` 已支持 `.event`（设 `eventProject = p`）与 `.todo`（设 `todoScope = .company` + `todoProject = p`）。所以接通 = 按钮 action 设 `router.quickAddPrefilledProject = project` + `router.quickAddDefaultKind = .event`（或 `.todo`）+ `router.showQuickAdd = true`（三字段名已存在于 `TabRouter`，无需新增）。
  - 「+ 添加事件」→ `quickAddDefaultKind = .event`。
  - 「+ 添加待办」→ `quickAddDefaultKind = .todo`。
- **sheet onDisappear 清理**：两端 QuickAdd sheet 既有 onDisappear 已把 `quickAddDefaultKind` 复位 `.todo`、清 `quickAddEditingProject`；W5 需确认 `quickAddPrefilledProject` 也在 onDisappear 清回 nil（核对：若 V5/W1 未清则补上，避免下次打开 QuickAdd 残留预填 project）。
- **文案修正**：「+ 添加事件」按钮的 label 从误用的 `LJStrings.addTodo` 改为新增 `LJStrings.addEvent`（`Project.addEvent`）；「+ 添加待办」按钮维持 `LJStrings.addTodo`（语义正确）。
- ProjectDetail 两端是否已 `@Environment(TabRouter.self)`：V5/W3 已为「Edit project」入口加过 router env（`ProjectDetailView_macOS.swift:114` 已用 `router.quickAddEditingProject`），W5 直接复用同一 router 引用，无需新加注入。

**需新增的本地化 key（中英双填）：**
- `Project.addEvent` = "+ Add event" / "+ 添加事件"
- 「+ 添加待办」复用既有 `Project.addTodo`（`addTodo`），不新增。

**关键接口 / 类型契约：** 无新增类型。复用 `TabRouter.quickAddPrefilledProject` / `quickAddDefaultKind` / `showQuickAdd`（均已存在）+ `QuickAddViewModel.prefilledProject` 既有分支（init 已实现 `.event`/`.todo` 预填）。

**拆分（共享 / macOS / iOS）：**
- **共享（先做）**：`Strings.swift` 加 `addEvent`（`Project.addEvent`）+ xcstrings 双填 + 重生两 lproj。`TabRouter` / `QuickAddViewModel` **不改**（复用既有字段与分支）。若 `quickAddPrefilledProject` 的 onDisappear 清理缺失，归到对应端 UI 修。
- **macOS（次做，先验收）**：`ProjectDetailView_macOS.swift` —— 「+ 添加待办」按钮（:325）action 接 `router.quickAddPrefilledProject = project; quickAddDefaultKind = .todo; showQuickAdd = true`；「+ 添加事件」按钮（:438）action 同上但 `.event`，并把 label `LJStrings.addTodo` 改 `LJStrings.addEvent`。
- **iOS（末做，后验收）**：`ProjectDetailView_iOS.swift` —— 「+ 添加事件」按钮（:420）同 macOS（接通 + 改 label 为 `addEvent`）；核对 iOS 是否也有独立「+ 添加待办」入口，有则一并接通 `.todo`。

**验收标准：**
- macOS：ProjectDetail 点「+ 添加待办」→ 打开 QuickAdd，kind 预选 Todo、scope 预选 Company、Project chip 已预填为当前 project；创建后该 todo 出现在此 ProjectDetail 的待办列。
- macOS：ProjectDetail 点「+ 添加事件」→ 打开 QuickAdd，kind 预选 Event、Project 预填为当前 project；创建后该事件出现在此 ProjectDetail 的「关联事件」列、`linkedEventsCount` +1。
- 「+ 添加事件」按钮**文案显示「+ 添加事件 / + Add event」**（不再错显「添加待办」）。
- 关闭 QuickAdd 后再从顶栏 `+ New` 打开：不残留上次预填的 project（`quickAddPrefilledProject` 已清回 nil）。
- iOS：上述同等行为通过。
- `LinoJCoreTests`：`LocalizationTests` 加 `addEvent` 的 zh≠en 断言（无新 VM 逻辑需测——复用既有 prefilledProject 分支，QuickAddViewModelTests 既有 prefill 测试已覆盖）。
- `swift test` 全绿；`swift build -Xswiftc -warnings-as-errors` 0 warning；两端 build SUCCEEDED。

**前置依赖：** v0.9 P3.5（ProjectDetail）+ P3.6（QuickAdd prefilledProject 已实现）+ V5/W3（ProjectDetail 已注入 TabRouter）。无付费能力依赖。

---

### W6 — 编辑模式隐藏分段控件（小 UX 收口）  [前端 / 两端 UI]

**范围（补真机反馈④的「待办按钮灰着像坏功能」）：**
- **现状定点**：编辑模式下 QuickAdd 的 todo/event/project 三段分段控件被 `.disabled(vm.isEditing)` 锁死灰显（`QuickAddModal_macOS.swift:160` / `QuickAddSheet_iOS.swift:171`）——这是 V5 有意为之（编辑态 kind 已固定），但「灰着一排」像功能坏了。用户反馈「待办按钮是灰的、只能改描述」即源于此。
- W6 决策：**编辑模式下直接隐藏整个分段控件**（不再灰显），只显示「编辑项目 / 编辑事件」标题——比灰一排干净。create 模式照常显示三段控件不变。

**技术选型 / 决策：**
- 两端 header 里把分段 `Picker` 从「`.disabled(vm.isEditing)`」改为「仅在非编辑模式渲染」：`if !vm.isEditingAny { Picker(...) }`（用 W4 引入的聚合 `isEditingAny`，覆盖 project edit 与 event edit 两种编辑态；若 W4 未先落地则退化用 `vm.isEditing`，但 W4/W6 同属本组、建议 W4 先做）。
- 标题文案：保持既有 `vm.isEditing ? quickAddEditProjectTitle : quickAddNew`，W4 落地后扩为 `isEditingEvent ? quickAddEditEventTitle : (isEditing ? quickAddEditProjectTitle : quickAddNew)`（W6 与 W4 共同维护此三态标题；若 W6 在 W4 之后做，直接用三态）。
- **不新增本地化 key**（标题 key 已由 V5 + W4 提供：`quickAddEditProjectTitle` / `quickAddEditEventTitle` / `quickAddNew`）。
- 隐藏分段控件后，header 的 layout（标题 + Spacer + 原 Picker 位置）需保证编辑态不留空洞——builder 让 Picker 整块条件渲染即可（SwiftUI 自动收拢布局）。

**关键接口 / 类型契约：** 无新增类型。复用 `QuickAddViewModel.isEditing` / `isEditingEvent` / `isEditingAny`（W4 提供）。

**拆分（共享 / macOS / iOS）：**
- **共享**：无（仅消费 W4 已加的 `isEditingAny`；若 W6 早于 W4 落地则临时用 `isEditing`）。
- **macOS（次做，先验收）**：`QuickAddModal_macOS.swift` header 把 `Picker(...).disabled(vm.isEditing)` 改为 `if !vm.isEditingAny { Picker(...) }`。
- **iOS（末做，后验收）**：`QuickAddSheet_iOS.swift` 同改。

**验收标准：**
- macOS / iOS：从 ProjectDetail「编辑项目」进入 QuickAdd → 顶部**不再显示**灰色三段分段控件，只显示「编辑项目」标题 + 表单。
- W4 落地后：从事件卡「编辑事件」进入 → 同样不显示分段控件，标题显示「编辑事件」。
- create 模式（顶栏 `+ New` / ⌘N）→ 三段分段控件正常显示可切，无回归。
- `swift build -Xswiftc -warnings-as-errors` 0 warning；两端 build SUCCEEDED。（W6 纯 UI，无新增单测；`swift test` 不回归。）

**前置依赖：** V5（project edit 模式）+ **建议 W4 先做**（提供 `isEditingEvent` / `isEditingAny` 与事件编辑标题；W6 与 W4 协同维护三态 header）。无付费能力依赖。

---

## 用户需在网页端手动操作的清单（v1.0）

> 以下操作 Claude / builder **无法代做**（涉及 Apple 网页控制台 / 账号交互）。请用户在对应 Phase **施工前**完成（尤其 V0 前置的 App ID + Container）。每项标注「Xcode 能否自动建」以免白点。

### 1. developer.apple.com — Certificates, Identifiers & Profiles（V0 前置，**必做**）
路径：https://developer.apple.com/account → 左侧 "Certificates, Identifiers & Profiles" → "Identifiers"
- **注册 App ID（1 个，显式 ID，非 wildcard，两端共用）**：
  - `com.linocai.linoj`（**统一 ID，macOS 与 iOS 共用，走 Universal Purchase**）
  - 勾选 Capabilities：**iCloud (含 CloudKit)** / **Push Notifications** / **Sign in with Apple**。
  - 说明：Xcode automatic signing **能自动创建** App ID 和 provisioning profile，但**自动创建的 App ID 默认不一定勾全付费 capability**。为稳妥，建议手动注册并显式勾选三项；或在 Xcode 里逐个开 capability 后让它同步回 portal（开了之后回这里确认三项都在）。
  - **清理**：如果你之前已经注册了 `com.linocai.linoj.ios` 与 `com.linocai.linoj.macos` 两个带后缀的 App ID，可以删掉（或留着不用，无害）。Universal 只需要 `com.linocai.linoj` 这一个。
- **创建 CloudKit Container**：路径 → "Identifiers" → 右上类型筛选切到 "iCloud Containers" → "+" → 新建 `iCloud.com.linocai.linoj`。
  - 说明：CloudKit Container **必须手动创建**（Xcode automatic signing **不会自动建 container**，只会引用）。先建好 container，再回 App ID 把 iCloud capability 关联到这个 container。

### 2. icloud.developer.apple.com — CloudKit Dashboard（V1 / V6 相关，**必做**）
路径：https://icloud.developer.apple.com → 选择 container `iCloud.com.linocai.linoj`
- 确认 container 已创建、可见。
- V1 开发期：schema 由 SwiftData 首次运行时在 **Development** 环境自动生成（record types 自动建）。无需手填 schema。
- **V6 上线前（Release 跨端同步前置）**：在 Dashboard 把 schema 从 **Development → Production** 部署（"Deploy Schema Changes…"）。Release 构建走 production 环境，未部署则 production 端无 record types，同步失败。
  - 说明：schema 自动生成是 Xcode/SwiftData 做的；**Deploy to Production 必须手动点**。

### 3. appstoreconnect.apple.com — My Apps（V6 相关，用户要求建记录）
路径：https://appstoreconnect.apple.com → "My Apps" → "+" → "New App"
- 填：Platforms（勾 **iOS + macOS** 两个，同一记录下挂两平台 build）、Name = **LinoJ**、Primary Language = **Chinese (Simplified)**、Bundle ID（从下拉选 **`com.linocai.linoj`**——需先在 portal 注册好这个**统一** App ID 才会出现在下拉里；带 `.ios`/`.macos` 后缀的旧 ID 不要选）、SKU = **LINOJ001**。
  - 关键：选了统一 Bundle ID 后，这**一个** App 记录就同时承载 iOS 与 macOS，不再需要建两个 App。
  - 说明：App Store Connect 记录**必须手动创建**（Xcode / automatic signing 不会建 ASC 记录）。

### Xcode 能自动 vs 必须手动 对照
| 项 | Xcode automatic signing 能自动？ | 谁来做 |
|---|---|---|
| App ID（Identifier） | 能自动建，但付费 capability 勾选不保证齐全 | 建议网页手动建并勾全三项 |
| Provisioning Profile | ✅ 能自动建 | Xcode 自动（V0 build 时） |
| Development / Distribution 证书 | ✅ 能自动建 | Xcode 自动 |
| **CloudKit Container** | ❌ 不会自动建 | **网页手动建** |
| **CloudKit schema Deploy to Production** | ❌ 不会自动 | **CloudKit Dashboard 手动** |
| **App Store Connect App 记录** | ❌ 不会自动 | **ASC 手动建** |
| Push Notifications key / APNs | CloudKit 静默推送不需单独 APNs key（CloudKit 托管） | 无需手动建 APNs key |

**清单共 3 大网页 / 5 项必做手动操作**：(1) 注册 2 个 App ID 并勾三 capability、(2) 创建 CloudKit Container、(3) CloudKit Dashboard Deploy 到 Production（V6 前）、(4) App Store Connect 建 App 记录、(5) 等价确认（container 关联到 App ID 的 iCloud capability）。

---

## 变更日志

> 格式：每次 plan 变更追加一节，标题为 `### [YYYY-MM-DD] 变更主题`，列出动机 + 涉及 Phase + 影响范围。Phase 内容直接在上半部分原地修改，本区域不保留旧版本全文，只记录差异。

### [2026-05-27] 初版

- 初始规划完成，覆盖 v0.9 全部范围。
- 技术选型 10 条 + 免费证书禁用/允许清单 + 8 个 Phase（P0..P7，其中 P3 拆 8 个子 Phase）。
- v1.0 待办仅列条目，不展开。

### [2026-05-27] P0 施工偏离记录

- **swift-tools-version**：技术选型示例片段提的 "Swift tools version 6.0" 调整为 `6.2`（PackageDescription 6.2 才暴露 `.macOS(.v26)` / `.iOS(.v26)` enum case，否则 platforms 约束无法成立）。Swift 6 strict concurrency 仍默认启用，语义不变。
- **`enableUpcomingFeature("StrictConcurrency")` 不写**：Swift 6 已默认开启 strict concurrency，显式开启会出 "already enabled" 警告。`Package.swift` 仅保留 `.enableUpcomingFeature("ExistentialAny")` 一项。
- 涉及 Phase：P0。后续 Phase 无影响。

### [2026-05-27] P0 GUI 部分由主会话直接编辑 pbxproj 完成

- 原计划 P0 的 Xcode GUI 部分（创建 workspace + 两个 `.xcodeproj` + 挂 package + 配 capability）让用户手工点。用户做到 §3 左右后委托主会话接手；主会话改为**直接编辑 `.xcodeproj/project.pbxproj` 与 `.xcworkspace/contents.xcworkspacedata` 文本**完成剩余部分。
- 已修复用户 GUI 残留偏差：Bundle ID（`com.example.linoj.LinoJ-macOS` → `com.example.linoj.macos`）、`MACOSX_DEPLOYMENT_TARGET`（26.5 → 26.0）、移除 `REGISTER_APP_GROUPS = YES`（App Groups 是付费 capability，违反免费证书约束）、移除空 bridging header 引用、`SWIFT_VERSION` 5.0 → 6.0、补 `CODE_SIGN_ENTITLEMENTS` 路径。
- iOS 工程从零生成 pbxproj（结构镜像 macOS，`SDKROOT = iphoneos`、`IPHONEOS_DEPLOYMENT_TARGET = 26.0`、`TARGETED_DEVICE_FAMILY = "1,2"`、`GENERATE_INFOPLIST_FILE = YES` + scene/launch screen keys）。
- workspace 三个顶级条目就位：LinoJ-macOS / LinoJ-iOS / Packages/LinoJCore。
- 验收通过：`xcodebuild -workspace LinoJ.xcworkspace -scheme LinoJ-macOS build` 与 `-scheme LinoJ-iOS -destination 'iPhone 17 Pro Sim' build` 均 BUILD SUCCEEDED；`swift test` 在 LinoJCore package 内 1 个 test 全绿；macOS signed by "Apple Development: linocai@hotmail.com" (Personal Team HX73DFL88G)。
- **重要副作用**：iOS 源文件目录从 `LinoJ-iOS/` 一级移动到嵌套 `LinoJ-iOS/LinoJ-iOS/`，与 macOS 工程结构对齐。后续 Phase 新增 iOS Swift 文件请放在 `LinoJ-iOS/LinoJ-iOS/` 内（macOS 同理在 `LinoJ-macOS/LinoJ-macOS/`），因 pbxproj 用 `PBXFileSystemSynchronizedRootGroup` 自动发现，无需改 pbxproj。
- 涉及 Phase：P0。后续 Phase 无影响。

### [2026-05-27] P3.2 偏离与小修正

- **openCount 语义校正**：plan P3.2 验收 hint 写 `openCount == 16`，但接口契约 `urgentTodos` 注释明确 "done == false"。data.js 实际 16 个 todo 中 p7（Schedule dentist）与 w9（Draft Q3 OKR doc）的 `done: true`，所以 `openCount = 14`。已在 `MainViewModelTests` 中以 14 为准。
- **HeadsUpAlertModel 字段调整**：plan 原写 `event: Event`，改为 `eventID: UUID + title + location`（已就地修正 plan P3.2 接口契约段）。理由：`@Model` 实例非 Sendable，HeadsUpService 在 Timer 闭包中需要跨 actor 传递。View 渲染时通过 eventID 反查 ModelContext。
- **`next7DaysGrouped` 始终返回 7 项**：即使某天 events 为空，保留 `(day, [])`，保证设计稿中 7-row 骨架稳定。
- 涉及 Phase：P3.2。下游 P4 HeadsUpService 用新 HeadsUpAlertModel 形态实现。

### [2026-05-27] P1 fixture 数字校正

- P1 验收标准原写 "Event = 16，Person 去重后 ≥ 10"，与 `design_handoff_linoj/data.js`（事实真理源）实际不符。Builder 翻译 data.js 时如实计数并回报。
- 正确数字：Event = **18**（e1-e16 共 16 + yesterdayEvents y1/y2 共 2），Person = **8**（L、M、A、J、K、Mom、Dad、Andrew —— data.js 中所有 `who:` 与 `members:` 字段使用到的 token 去重）。
- 已就地修正 P1「验收标准」中对应一行。
- 涉及 Phase：P1。下游 P3.2 Main 视图的 "Next 7 days" 计数、P4 yesterday-missed 服务的事件源会以 18 件事件为基础，但 P3.2 内部计数 "X open · Y urgent · Z events today" 中 Z = today（Tue）事件数 = 4，不变；plan 中其它 P3 节内已正确引用具体事件名而非总数，无需联动修改。

### [2026-05-27] P3.4 周一/周二 真实日历偏移

- 设计稿与 plan 均把 today (2026-05-27) 叙述为「Tuesday」，但真实 Gregorian 下 2026-05-27 = **Wednesday**（weekday=4）。`Calendar.current` 的 weekday 计算不会被 seed 的 day 标签 (`Tue`/`Wed`/...) 影响 —— 这些标签仅是 SeedData 内部用来分组 fixtures 的字符串，无任何 Calendar API 接入点。
- 因此 `CalendarViewModel.weekStart`（Monday-start）实际值 = **2026-05-25 (Mon)**，而非 plan 验收文本说的 May 26：
  - 真实 weekStart Mon 2026-05-25
  - week = May 25 (Mon, 空) / May 26 (Tue, y1+y2 yesterday-missed=2) / May 27 (Wed = seed 'Tue', 4 events) / May 28 (Thu = seed 'Wed', 3) / May 29 (Fri = seed 'Thu', 2) / May 30 (Sat = seed 'Fri', 2) / May 31 (Sun = seed 'Sat', 2)
  - **weekTotal = 15**（seed 中 e14 'Sun' 落到下周 Mon, e15/e16 'Mon2' 落到下周 Tue，故不计入当前周）
- 这只影响 plan 中 P3.4 描述里那条「today=Tue 27 → 对应 Monday=26」的字面误判。功能行为（Today 列高亮、Tue events 4 张渲染在正确小时槽）仍按设计稿运作，因为 vm 暴露的是真实日期 Date，View 不依赖 seed 的 day 字符串标签。
- 涉及 Phase：P3.4。下游 P4 yesterday-missed（依赖 today.startOfDay - 1d）与 P6 响应式（基于 weekStart 的 7 列布局）不受影响 —— 它们都吃绝对日期，不吃 seed 标签。

### [2026-05-27] P3.5 NavigationStack 用 UUID 而非 Project 作 destination；linkedEvents 含 yesterday

- **NavigationStack 路由**：plan P3.5 建议给 `@Model Project` 实现 `@retroactive Hashable`，再用 `navigationDestination(for: Project.self)`。实际施工选了更保守的方案 —— 用 `Project.ID`（UUID）作 destination value、在 `navigationDestination(for: UUID.self)` 闭包内通过 `projects.first(where:)` 反查实例。理由：@retroactive Hashable 给 `@Model` 类型 attach extension 在 Swift 6 strict concurrency + SwiftData PersistentModel 协议链下风险点较多（hash 应基于持久 id 而非内存身份，但 PersistentModel 默认 `==` 与 hash 是 actor-isolated），UUID 路径既稳又干净。CompanyView 的 `@Query private var projects` 在反查时仍是 live，pop 也由系统正常处理。
- **linkedEventsCount = 6 而非 5**：plan P3.5 验收文案提示 LinoJ 项目 "linked events 显示 e1/e3/e8/e10/e15"（5 个）。SeedData 中 y1 "Engineering standup" 也 `projectKey == "linoj"`（昨日的 standup），ProjectDetailViewModel 不按「本周」过滤 —— 它返回所有归属此 project 的 Event。因此真实总数 = 6（5 本周 + 1 昨日）。test 用 `>= 5` 的下限断言 + 标题集合包含验证，与设计稿语义一致（"linked events" 不限制时间窗）。iOS stats card 显示 "events" 数字会是 6 而非 plan 文本的 5。
- 涉及 Phase：P3.5。后续无影响。

### [2026-05-27] P3.6 Quick Add 施工偏离记录

- **macOS modal 用系统 `.sheet` 而非自建 overlay**：plan P3.6 描述视觉为「居中 520pt modal + 70% black backdrop」。SwiftUI macOS `.sheet` 是从顶部下滑、附着窗口的 sheet（不居中浮动）；要做到真正居中浮动需自建 NSWindow 或 ZStack overlay，会破坏系统标准 dismiss / focus / 投影行为。施工选了 `.sheet(isPresented: $router.showQuickAdd)` + sheet 内 `.frame(width: 520, height: 480)` 锁尺寸的方案。视觉差异仅「位置 vs 顶部下滑」，遮罩、阴影、esc dismiss 全由系统提供。⌘↵ 由 Create 按钮 `.keyboardShortcut(.return, modifiers: .command)` 接管。
- **TabRouter 新增两个字段**：
  - `public var quickAddDefaultKind: QuickAddViewModel.Kind = .todo` —— 入口（⌘N/⌘⇧T 默认 .todo、⌘⇧E / Calendar `+ New event` 设 .event、⌘⇧P 设 .project、iOS `+` 默认 .todo）在打开 sheet 前设置，Quick Add VM 在 `onAppear` 时拿这个值。
  - `public var quickAddPrefilledProject: Project? = nil` —— 未来从 Project detail `+ Add todo` 入口预填用；P3.6 暂无入口设置它。Router 自身已 `@MainActor`，与 @Model 同线程，无需 Sendable。
  sheet 关闭后两个字段都重置（`onDisappear` 里清回默认值），避免下次打开还带着上次状态。
- **Attendees / Members 选择器为 placeholder**：plan P3.6 明确允许 attendee 选择器留到后续 Phase。`+ Add` / `+ Invite` 按钮当前 print 占位；AvatarStack 仍按 vm.eventAttendees / vm.projectMembers 实时渲染，只是没有任何路径往里面加 Person。这与 plan「关键接口契约」一致 —— VM 字段就位，UI 选择器 stub。
- **submit() 返回类型 `AnyHashable`**：plan 接口契约写法即如此。实现返回 `AnyHashable(model.id)`（UUID 包一层），方便上层调用 `vm.submit()` 后跳转到新对象。
- 涉及 Phase：P3.6。后续 P3.7 Quick action（"New todo"...）也走 router.quickAddDefaultKind 切换；P3.8 设置项 default todo scope 应作用于 Quick Add 初始 `todoScope`，留给 P3.8 接通时改。

### [2026-05-27] P4 施工偏离记录

- **HeadsUp 显示窗口固定 60 分钟，与 NotificationService.leadMinutes 解耦**：plan P4 接口契约里 HeadsUpService 接收 `leadMinutes: Int = 30`，但 README「Heads-up alert logic」明确「show when an event starts within 60 minutes from now」。施工把这两件事拆开 —— HeadsUpService 内部 UI 显示窗口写死 60 min，`leadMinutes` 入参仅保留为 plan 契约（供调用方查询 / 未来扩展），实际不影响显示判定；NotificationService 才是按 `leadMinutes` 调度本地通知。修改 SettingsViewModel.headsUpLeadMinutes 会让 NotificationService 重新 scheduleAll，但不会重启 HeadsUpService（也无需重启）。
- **AppServices 容器封装可选 service**：plan P4 接口未指定如何把 `HeadsUpService` / `YesterdayMissedService` 注入 SwiftUI 子树。施工新增 `AppServices: @Observable @MainActor` 包装类，含 `headsUp: HeadsUpService?` 与 `yesterdayMissed: YesterdayMissedService?` 两个可选字段。RootWindow / RootTabView 在 `.task` 中拿到 modelContext 后填充字段；子 View 用 `@Environment(AppServices.self)`。原因：SwiftUI `.environment(...)` 按类型注入，无法直接传 `Optional<T>` 让接收方用 `@Environment(T.self)` 拿到 nil。
- **MainViewModel / CalendarViewModel init 增加可选 service 参数**：`MainViewModel(context:headsUpService:yesterdayMissedService:)` 与 `CalendarViewModel(context:today:yesterdayMissedService:)`。service 未传时 `yesterdayMissed` 回退到本地 fetch 逻辑（与 P3.2/P3.4 行为一致），保证既有测试 mock 不破。MainView_macOS / MainView_iOS / CalendarView_macOS / CalendarView_iOS 在 `.task` 与 `.onChange(of: services.headsUp == nil)` 中重建 vm，让 service 从 nil 变成实际实例时 vm 自动持有最新引用。
- **NotificationService 标 `@MainActor`**：plan 写「actor 或 final class 都可」。施工选 `@MainActor final class`，因为 `scheduleAll(events: [Event], ...)` 接收的是 SwiftData `@Model` 类型（Event 非 Sendable），调用方都在 MainActor，保持隔离一致避免跨 actor 数据竞争编译错。UNUserNotificationCenter 本身线程安全。
- **MainViewModel.openHeadsUpEvent 保持 noop**：plan P3.2/P4 都提到这个方法，但「Heads-up Open → 跳到 Calendar 那天」涉及 TabRouter 与 CalendarViewModel.selectDay 联动，目前 MainViewModel 不持 router。HeadsUpAlert 的 `onOpen` closure 由调用方（MainView）传入完成跳转更直接，所以 VM 内 noop 保留。MainView 当前也未实现跳转 closure 主体 —— v0.9 该交互留给 P5 或下一版本接通。
- **测试覆盖**：HeadsUpServiceTests（6 个：within 60 min / picks earliest / outside window / already ended / in progress / snooze）+ YesterdayMissedServiceTests（3 个：filter only yesterday / confirm removes / future now empty）。总测试 76 → 85，全部新增稳定通过。**注意**：`ProjectDetailViewModelTests.membersSinceText` 已经 flaky（与 P4 无关，是 SwiftData 关系建立时序问题；已 spawn 单独 task 排查）。P4 自身测试连续 5 次稳定 9/9。
- 涉及 Phase：P4。下游 P5+：本地化时 NotificationService 的「Heads up — / in N min · 」字符串需迁移到 xcstrings。

### [2026-05-27] P6 施工偏离记录

- **ProjectCard.macFull 响应式：用「构造参数 compact」而非组件内 GeometryReader**：plan P6 描述「< 1200pt：Company project cards 内部从 3 列变 2 行 layout」。第一版尝试在 ProjectCard 内部加 GeometryReader 自适应自身宽度，发现 GeometryReader 在 VStack 内会要求父级提供 idealSize，破坏卡片高度自适应（卡片被压成 200pt 固定高）。改方案：给 `ProjectCard.init` 加 `compact: Bool = false` 参数，由 CompanyView 在外层 `GeometryReader { geo in ... }` 中读 NavigationStack 内容区宽度，把 `geo.size.width < 1200` 作为 compact 值透下去。布局正确性 + 高度自适应都保留。其它 variant（macStrip / iosMini / iosFull）忽略该参数，签名向后兼容。
- **Calendar < 1100pt 「sticky 周一列」简化为「时间标签列锁定」**：plan 描述「周一列 sticky」。考虑到 SwiftUI 横向 ScrollView 内做 sticky 第一列需要嵌套 LazyHStack + pinnedViews，复杂度与收益不成比例。施工采用更朴素方案：把 52pt 时间标签列放在 ScrollView 外层 HStack 里（不进入横向滚动区域），整组 7 个 day column 在右侧 ScrollView(.horizontal) 内可滚动。表头同样把时间列占位放在 HStack 外侧。视觉效果：用户横向滚时，时间标签固定可见，今天/周一/任何日期列在窗口里都按需出现。这与 plan 意图「窄窗口下仍可读」一致，"sticky 周一" 的精确语义略调整。
- **Calendar < 900pt 3-day window 算法**：plan 写「today + 2 邻天」。施工取 `[todayIdx-1, todayIdx, todayIdx+1]` 三天，若 today 不在当前 vm.weekDays 内（用户切到非本周）则 fallback 到 weekDays 前 3 项；越界时 clamp 到合法范围。仍保留同一 weekGrid / dayColumn / now 线渲染路径，复用率高。
- **macOS hover cursor pointer 不实现**：plan brief 明确「不要为 NSCursor 切换花太多功夫（README 不硬要求）」+「最简：只做 bg hover」。施工新增 `ljHoverBackground()` modifier（macOS only，fill `Color.lj.chip`），用在 Search palette row / Personal completed row / Main yesterday row。其它 TodoBubble / ProjectCard.macStrip 等已经用 `ljHoverLift()` 表达 hover，不叠加 bg。NSCursor.push/pop 完全不做。
- **LinoJHaptics 抽象**：新增 `Packages/LinoJCore/Sources/LinoJCore/Platform/LinoJHaptics.swift`，对外只暴露 `LinoJHaptics.lightTap()` 静态方法 + `@MainActor`；iOS 走 `UIImpactFeedbackGenerator(style: .light).impactOccurred()`，macOS / 其它平台为空实现。调用点：`PersonalViewModel.toggleDone / toggleUrgency`、`CompanyViewModel.toggleDone`、`MainViewModel.toggleDone / confirmAttended`、`ProjectDetailViewModel.toggleDone / toggleUrgency`、`QuickAddViewModel.submit`（三种 kind 各一次，成功 save 后触发）。注意没在 `delete()` 上加 —— plan 只点了 toggle done / urgency / 创建，删除不算。
- **EmptyState 淡入由组件自身负责**：新增 `ljEmptyStateAppearance()` modifier（@State visible flag，0→1 opacity，0.2s easeInOut），直接挂在 `EmptyState.body` 末尾。调用方无需关心；跨平台一致。
- **TodoBubble 已有 ljHoverLift（P2）保持不变**：plan brief 提到要「确认 ljHoverLift 应用在 macOS Screens 渲染的 TodoBubble」。检查后发现 `TodoBubble` 组件内部就 `.ljHoverLift()`（line 76），所以所有调用方自动继承，不需要在 MainView / PersonalView / CompanyView / ProjectDetailView 里重复挂。HeadsUpAlert 脉冲 + CompletedBox chevron 旋转也是 P2 已实现，本期未改。
- **测试**：新增 `HapticsTests.swift`（2 个：`lightTapNoCrashOnMacOS` / `repeatedLightTapStability`），验证 macOS 测试环境下 no-op 不崩 + 连续多次稳定。总测试 93 → 95。已知 flaky `ProjectDetailViewModelTests.membersSinceText` 不变（plan 明确不修）—— 多次运行有时通过有时不过，P6 自身 0 失败、0 新增不稳定测试。
- 涉及 Phase：P6。下游 P7：Release 构建验证时需手测窗口拖到 1050pt / 850pt 看 Calendar / Main / Company 响应式切换；iOS 真机手测 haptic 触感。NSCursor pointer / 完整 sticky 第一列若未来产品要求精确还原可在 v1.0 重做。

### [2026-05-28] Reviewer 反馈修复（F1 + F2 + I1..I10 + S11 + S12）

针对 reviewer 在 v0.9 P0-P6 完成后给出的 2 个致命 + 10 个重要 + 2 条建议，统一修复。

- **F1：LinoJTime 时间源拆分**。原 `LinoJTime.now()` 在 DEBUG 下返回 `SeedData.todaySimulated()`（冻结 2026-05-27 09:00），导致 HeadsUpService alert 永不更新 / Calendar now 线永不移动 / NotificationService 时间源不一致。修复：把 API 拆为 `now()`（始终真实 `Date.now`）+ `today()`（DEBUG 返回 seed 锚点、Release 返回 real `Date.now`）。Caller 迁移：HeadsUpService.tick/snooze、NotificationService.scheduleAll、CalendarView_macOS now 线、HeadsUpServiceTests 全部用 `now()`；MainViewModel.todayEvents / next7DaysGrouped / yesterdayMissed（fallback）、CalendarViewModel.today、ProjectDetailView todayStart、MainView_iOS upcomingToday、YesterdayMissedServiceTests 全部用 `today()`。`LinoJTime.startOfToday()` 改基于 `today()`。
- **F2：ProjectDetailViewModel.membersSinceText 5/5 稳定**。根因是 SwiftData `Project.members` to-many 关系 fault 行为不稳定 —— 多次 fetch 时 `.count` 偶发返回 0/2/3。修复：在 Project 模型上新增冗余 `memberCount: Int` 字段，`init(members:)` 时一次性写定（v0.9 无项目编辑入口）。VM 用 `project.memberCount` 替代 `project.members.count`；ProjectCard / ProjectDetailView_macOS / SearchViewModel 同步切换。另外 `shortDateFormatter.locale = Locale(identifier: "en_US_POSIX")` + `dateFormat = "MMM d"` 锁英文输出，"Apr 12" 与设计稿对齐，与系统语言无关。
- **I1..I10 + S11/S12**：
  - I1：CompletedBox 头部 `"Completed (X)"` 走 `LJStrings.sectionCompleted(_:)`，xcstrings 加 `Section.completed = "Completed (%d)" / "已完成 (%d)"`。
  - I2：ProjectCard `todosBlock` / `eventsBlock` / iosFull 五处硬编码英文改用 LJStrings.todos / linkedEvents / statEvents + 新增 `projectCardUrgentSuffix(_:)` / `projectCardEventsSuffix(_:)` / `projectCardTodosSuffix(_:)`（xcstrings 已加）。"+N more" 复用既有 `Counts.moreEvents`。
  - I3：HeadsUp Open 按钮真接通 —— MainView_macOS / MainView_iOS 的 `onOpen` closure 直接 `router.current = .calendar`，不经过 VM。MainView_iOS 新增 `@Environment(TabRouter.self)`。
  - I4：iOS Main / Calendar EmptyState CTA `action` 真接通：Main → `router.quickAddDefaultKind = .todo + showQuickAdd = true`；Calendar → `kind = .event`。
  - I5：QuickAddViewModel.init 加 `defaultScope: Scope = .personal` 参数；QuickAddModal_macOS / QuickAddSheet_iOS 各持一个 `@State var settings = SettingsViewModel()`，打开 sheet 时传 `settings.defaultTodoScope`。SettingsView_macOS 加 `rowWithV1Hint`，iOS SettingsSheet 给 `toggleRow` / `pickerRowRawValue` 加 `v1Hint: Bool` 参数。受影响字段：showCompletedInCounts / systemBannerEnabled / yesterdayMissedReminderEnabled / dailySummaryHour / quietHours{Start,End} 全部 hint 为「(coming in v1.0)」；defaultTodoScope 与 headsUpLeadMinutes 是真接通的，不加。
  - I6：iOS CalendarView_iOS 的 ‹/›/Today 按钮加 `.frame(minWidth: 44, minHeight: 44) + .contentShape(Rectangle())`，视觉保留 30pt 圆角方框但触摸区扩到 HIG 44pt。
  - I7：NotificationService.scheduleAll 内 `let now = Date()` 改为 `LinoJTime.now()`，与 HeadsUpService 一致。
  - I8：RootWindow / RootTabView 加 `.onChange(of: allEvents.map(\.start))` 监听 event.start 编辑（v0.9 没编辑入口但 monitor 就位）。
  - I9：HeadsUpService.tick 末尾加一致性兜底 —— 若 currentAlert 引用的 eventID 不在 fetch 结果中（被删了），立即置 nil。
  - I10：TodoBubble 的 `.accessibilityLabel("Completed" / "Open")` 走 `LJStrings.a11yCompletedSuffix` / `a11yOpenSuffix`（xcstrings 已加）。
  - S11：QuickAddModal_macOS / QuickAddSheet_iOS 在 `.onDisappear` 中 `vm = nil`，下次打开 sheet 重建 VM 避免输入污染。
  - S12：LinoJCommands.swift `CommandMenu("View")` → `CommandMenu(Text(LJStrings.menuNavigate))`，xcstrings 加 `Menu.navigate = "Navigate" / "导航"`，避免与系统 View 菜单冲突。
- **YesterdayMissedServiceTests 测试调整**：因 F1 后 `LinoJTime.now()` 默认参数 = real `Date()`，测试改为显式传 `LinoJTime.today()` 让 yesterday-missed seed（2026-05-26）窗口对齐。逻辑等价。
- **验收**：ProjectDetailViewModelTests 5/5 稳定；全量 95 个测试全绿；`swift build -Xswiftc -warnings-as-errors` 0 warning；macOS + iOS 两端 Debug + Release 共 4 个 BUILD SUCCEEDED。
- **未修**：S1..S10 中除 S11/S12 外其它建议项 reviewer 标记为低优 / 已 OK / 文档化范围内，按 brief 跳过。
- 涉及 Phase：跨 P1（Project 模型 +memberCount 字段）/ P2（CompletedBox / ProjectCard / TodoBubble 组件本地化）/ P3.1（LinoJCommands 菜单命名 + iOS RootTabView 监听）/ P3.2（MainView_macOS / MainView_iOS HeadsUp Open + EmptyState CTA）/ P3.4（CalendarView_iOS hit target + EmptyState CTA）/ P3.5（ProjectDetailViewModel）/ P3.6（QuickAddViewModel + sheet vm 清理）/ P3.8（Settings v1 hints）/ P4（HeadsUpService / NotificationService / YesterdayMissedService 时间源 + 一致性兜底）/ P5（xcstrings 新增 6 个 key + .lproj 同步）。

### [2026-05-28] v1.0 规划

- **动机**：v0.9（P0-P7 + Reviewer 修复）全部完成，95 测试全绿、两端 Debug/Release 4 个 BUILD SUCCEEDED。付费 Apple Developer 账号已下发，把 v0.9 文末「v1.0 待办清单」展开为正式可施工 Phase。
- **结构变更**：原「## v1.0 待办清单（不展开为 Phase）」节改造为「## v1.0 Phase 列表」，新增 8 个 Phase（V0..V7，V 前缀避免与 P0-P7 混淆）+「v1.0 技术选型/约束」小节 +「用户需在网页端手动操作的清单」节。v0.9 P0-P7 描述与既有变更日志条目**未改动**。
- **v1.0 范围（敲定决策）**：同一 Apple ID `linocai@hotmail.com` 原地升级，Team `HX73DFL88G` 不变；正式 Bundle ID `com.linocai.linoj.{macos,ios}`；CloudKit 单 container `iCloud.com.linocai.linoj` 两端共用。**做**：CloudKit/iCloud 同步（SwiftData `.automatic`）、Sign in with Apple、CloudKit 订阅式静默推送、macOS 顶栏修复、Edit project、App Store Connect 建记录 + 隐私 manifest。**不做**：Widget、自建 APNs 服务端、EventKit mirror（降级留 v1.1）、BGTask/Spotlight/Shortcuts、强制公证上架。
- **新增 Phase**：V0 付费迁移+capability[共享] / V1 CloudKit 同步[共享] / V2 Push 静默推送[共享] / V3 Sign in with Apple[共享] / V4 macOS 顶栏修复[macOS] / V5 Edit project[共享] / V6 ASC+隐私 manifest+收尾[共享] / V7 P7 遗留（可并入 V6）[共享]。
- **最大技术风险**：V1 把现有 local-only `@Model` 切 CloudKit 的硬约束（标量需默认值、to-many 关系需 `=[]`、禁 `@Attribute(.unique)`、deleteRule 跨端验证、memberCount 冗余字段同步语义、v0.9 旧 store 迁移）——已在 V1 节列 8 条逐项核对清单。
- **README 4 开放问题最终决策**：iCloud toggle 默认 ON（接真，OFF 需重启生效不热切）；Edit project 复用 QuickAddViewModel edit 模式；From-yesterday 保留为已确认行为；Widget 明确不做。
- **依赖**：V0 是 V1/V2/V3 硬前置（依赖网页端 App ID + CloudKit Container 已建）；V4/V5 无付费依赖可并行提前；V6 依赖 V0-V5 + CloudKit Dashboard Production schema 部署。
- **阻塞点（需主会话回问用户）**：App Store Connect 的 **App 显示名** 与 **SKU** 尚未确定，V6 / 网页清单第 3 项需要。

### [2026-05-28] v1.0 决策补充：ASC 信息 + 统一 Bundle ID

- **App Store Connect 信息敲定**：Name = `LinoJ`，SKU = `LINOJ001`，Primary Language = 简体中文，Platforms = iOS + macOS。
- **Bundle ID 由分开改为统一**（覆盖上一节「`com.linocai.linoj.{macos,ios}`」决策）：用户在 ASC 建 App 时发现分开的 Bundle ID 会导致需建两个 App 记录。改为 **iOS / macOS 共用同一 Bundle ID `com.linocai.linoj`**（去后缀），走 Universal Purchase，单个 ASC 记录承载两平台。
  - 影响 V0：两端 pbxproj 的 `PRODUCT_BUNDLE_IDENTIFIER` 都改成 `com.linocai.linoj`（已就地更新 V0 节）。
  - 影响网页清单：developer.apple.com 只需注册 **1 个** App ID `com.linocai.linoj`（原计划 2 个带后缀的作废，可删）。CloudKit container `iCloud.com.linocai.linoj` 不变。
  - 两个独立 Xcode target 用相同 Bundle ID 合法（iOS/macOS 各自平台 build，不冲突）。

### [2026-05-28] V4 — macOS 顶栏 toolbar 修复 完成

- 变更内容：把 `RootWindow.swift` 顶栏从「仅居中 4-tab Picker」重做为对齐 `direction-a.jsx` AWindow chrome 的单行三段布局：左 LinoJ wordmark（13pt/semibold/tracking -0.13）+ 6pt 中性状态 dot；中 4-tab segmented Picker（两侧 `Spacer(minLength:)` 推到居中，`maxWidth 360 + fixedSize`）；右 「Search or jump」chip pill（放大镜 + 文字 + ⌘K mono kbd，宽 200/高 28/radius 7，点击 `router.showSearch = true`）+ 「+ New」ink 按钮（背景 `Color.lj.ink`、文字 `Color.lj.bg`、radius 7、高 28，点击 `quickAddDefaultKind = .todo` + `showQuickAdd = true`）。顶栏高 44、下沿 0.5pt `Color.lj.border` 分隔线、背景 `Color.lj.bg`。
- 新增本地化 key：`Toolbar.searchOrJump`（Search or jump / 搜索或跳转）、`Toolbar.new`（New / 新建）；xcstrings + 双 lproj 经 `xcstringstool compile` 同步；LJStrings 加 `toolbarSearchOrJump` / `toolbarNew`。
- 变更原因：v0.9 macOS 验收偏离设计稿，顶栏缺 wordmark / 状态 dot / Search / New 元素。
- 影响范围：V4（macOS only）。iOS 未改动（按 V4 plan 结论 iOS 顶栏即两枚 floating glass 按钮，无需变更）。
- 偏离说明：① 设计稿 wordmark 左侧的三个彩色圆点是 macOS 系统红绿灯（窗口系统原生提供，不由 App 绘制），设计稿未画语义状态 dot；按 V4 plan 要求在 wordmark 右侧补一个 6pt 中性 dot（`Color.lj.inkDim`），V1 接 CloudSyncMonitor 后变色。② 设计稿是单行 HStack（wordmark+tabs 左对齐、Search+New 右对齐），任务书要求「中部 Picker 居中」，故用两侧 `Spacer` 把 Picker 推到水平居中——与设计稿严格的左聚簇略有取舍，但符合任务书三段式居中要求。③ ink 按钮文字色用 `Color.lj.bg`（与既有 `CalendarView_macOS.newEventButton` 及设计稿 `color: t.bg` 一致），未用任务书括注的 `Color.lj.panel`。
- 验收：`swift test` 95 测试全绿；LinoJ-macOS / LinoJ-iOS 两端 `xcodebuild ... build` 均 BUILD SUCCEEDED，0 Swift warning。

### [2026-05-28] V5 — Edit project 流程 完成

- 变更内容：
  - `QuickAddViewModel` 加 edit 模式：新增 init 参数 `editingProject: Project? = nil`、只读 `editingProjectID: UUID?`、计算属性 `isEditing`。edit 模式下强制 `kind = .project`（无视 `defaultKind`），预填 `projectTitle/projectIntro/projectTag/projectMembers`。`submit()` 的 `.project` 分支：`isEditing` 时按 `editingProjectID` 用 `#Predicate` fetch 既有 project，原地回写 title/intro/tag/members + 重算 `memberCount`（F2 冗余字段同步，V1 约束 7）+ `context.save()`，返回原 id；fetch 不到（极端：edit 期间被删）回退为创建，避免静默丢输入。`canSubmit` 复用既有 project 分支（title 非空）。
  - `TabRouter` 新增 `quickAddEditingProject: Project? = nil`（与 `quickAddPrefilledProject` 同模式：入口设置 + sheet onDisappear 清回 nil）。
  - `QuickAddModal_macOS` / `QuickAddSheet_iOS`：vm 构造传 `editingProject: router.quickAddEditingProject`；edit 模式标题切 `QuickAdd.editProjectTitle`、提交按钮文案切 `QuickAdd.save`、segmented control `.disabled(vm.isEditing)`（不隐藏，锁死在 Project 段）；onDisappear 清 `quickAddEditingProject`。
  - `ProjectDetailView_macOS`：hero 区 "Edit project" outline 按钮 action 从 print 改为 `router.quickAddEditingProject = project; router.showQuickAdd = true`（加 `@Environment(TabRouter.self)`）。
  - `ProjectDetailView_iOS`：顶部 `⋯` floating glass 按钮从 print 改为 `Menu`，含「Edit project」（pencil 图标）item，触发同上 router 信号（加 `@Environment(TabRouter.self)`）。breadcrumb 区的 macOS `⋯` 按钮仍 print（V5 范围只接 "Edit project" 入口，未要求接通 breadcrumb `⋯` 菜单）。
  - 新增本地化 key `QuickAdd.editProjectTitle`（Edit project / 编辑项目）、`QuickAdd.save`（Save / 保存）：xcstrings + 双 lproj（en / zh-Hans）+ LJStrings 三轨同步，LocalizationTests 批量覆盖加 2 项。
  - `QuickAddViewModelTests` 新增 3 项（edit init 预填 / edit submit 原地更新且总数不变且 notes 保留 / edit 改 members 后 memberCount 同步，含增减双向）。
- 变更原因：v0.9 Project Detail 的 "Edit project" 按钮仅 print；V5 接真，复用 QuickAddViewModel edit 模式（README 开放问题 2 决策）。
- 影响范围：V5（共享）。create 路径（editingProject == nil）行为与 v0.9 完全一致，无回归。
- 偏离说明：① **Router 字段名用 `quickAddEditingProject`（plan 契约名）而非任务书的 `editingProject`** —— PROJECT_PLAN.md V5 节「关键接口/类型契约」明确写 `quickAddEditingProject`，以 plan 为准。② **`Project.notes` 字段在 Project form 里不存在** —— v0.9 macOS/iOS 的 Project 表单只有 Title / Description(绑 `projectIntro`) / Tag / Members 四项输入，create 路径硬编码 `notes: ""`。故 edit 模式同样不预填、不回写 notes，保留既有值原封不动（测试 #9 断言 notes 保留）。③ iOS `⋯` 用 `Menu`（比直接触发更符合 plan「⋯ 菜单」描述，复用既有 `LJStrings.editProject` 作菜单项 label）；segmented 用 disable 而非隐藏（保留视觉一致，用户能看到锁在 Project 段）。
- 验收：`swift test` 98 测试全绿（95 + 3 edit）；LinoJ-macOS / LinoJ-iOS 两端 `xcodebuild ... build` 均 BUILD SUCCEEDED，0 Swift compiler warning。

### [2026-05-28] V0 — 付费迁移与 capability 开启 完成

- 变更内容：
  - **统一 Bundle ID**：`LinoJ-macOS.xcodeproj/project.pbxproj`（Debug+Release 两处 `com.example.linoj.macos`）与 `LinoJ-iOS.xcodeproj/project.pbxproj`（Debug+Release 两处 `com.example.linoj.ios`）全部改为完全相同的 `com.linocai.linoj`，走 Universal Purchase。`DEVELOPMENT_TEAM = HX73DFL88G` 未动。
  - **macOS entitlements**（`LinoJ-macOS/LinoJ-macOS/Resources/LinoJ-macOS.entitlements`）：在保留 `com.apple.security.app-sandbox = true` 基础上追加 `icloud-container-identifiers`（`iCloud.com.linocai.linoj`）/ `icloud-services`（CloudKit）/ `ubiquity-kvstore-identifier`（`$(TeamIdentifierPrefix)iCloud.com.linocai.linoj`）/ `aps-environment`（development）/ `applesignin`（Default）/ `com.apple.security.network.client`（true）。
  - **iOS entitlements**（`LinoJ-iOS/LinoJ-iOS/Resources/LinoJ-iOS.entitlements`）：从空 dict 填入与 macOS 相同的 icloud-container-identifiers / icloud-services / ubiquity-kvstore-identifier / aps-environment / applesignin 五组（不含 app-sandbox 与 network.client）。
  - 新增 `Packages/LinoJCore/Sources/LinoJCore/CloudKit/LinoJCloudKit.swift`：`public enum LinoJCloudKit { public static let containerID = "iCloud.com.linocai.linoj" }`（V1 复用）。
  - **未动** `LinoJStore.makeContainer`（仍 `cloudKitDatabase: .none`），CloudKit 实接留 V1。
- 变更原因：开启 V1/V2/V3 所需的三项付费 capability（CloudKit / Push / Sign in with Apple）+ 统一 Bundle ID。
- 影响范围：V0（全栈 / 工程配置）。无业务逻辑改动，无回归。
- 偏离说明：无。严格照 V0 节 entitlements key 清单与统一 Bundle ID 决策执行；未加 App Groups（签名失败原因为设备未注册，非 missing App Group）。
- 验收：
  - `swift test`（LinoJCore）98 测试全绿。
  - iOS Simulator（iPhone 17 Pro）`xcodebuild ... build` **BUILD SUCCEEDED**。
  - macOS `xcodebuild ... -allowProvisioningUpdates build` **BUILD FAILED——签名失败，非编译失败**：失败发生在 `GatherProvisioningInputs`/`CreateBuildDescription` 阶段（早于任何 Swift/clang 编译），错误为 ① `Device "Tedothy" isn't registered in your developer account`（本机未注册到开发者账号）② `No profiles for 'com.linocai.linoj' were found`（headless `xcodebuild` 非交互拉不到新 Bundle ID 的 Mac App Development profile）。需用户在 Xcode 里手动 build 一次让 Xcode 注册本机设备并自动生成/下载含三项 capability 的 profile——非代码 bug。entitlements 与 Bundle ID 配置已 grep 确认正确。

### [2026-05-28] V1 — CloudKit 同步 完成

- 变更内容：
  - **4 个 `@Model` 按 CloudKit 硬约束逐条改造**（`Todo` / `Project` / `Event` / `Person`）：
    - 所有非 optional 标量加默认值：`Todo`（title/urgencyRaw/scopeRaw/done/createdAt）、`Project`（title/intro/notes/tag/memberCount/createdAt）、`Event`（title/start/end/location/attendedConfirmed）、`Person`（name）、四类 `id` 全部 `= UUID()`。`urgencyRaw`/`scopeRaw` 默认值用 `Urgency.normal.rawValue` / `Scope.personal.rawValue`，与 computed wrapper 兜底一致。
    - 所有 to-many 关系加默认 `= []`：`Project.members/todos/events`、`Event.attendees`、`Person.memberOf/attending`。
    - **补齐缺失的 inverse**（V1 最大坑）：v0.9 的 `Project.members ↔ Person` 与 `Event.attendees ↔ Person` 是单向 to-many（Person 侧无 inverse），CloudKit 要求双向。在 `Person` 上新增两条 inverse 关系 `memberOf: [Project]`（`inverse: \Project.members`）+ `attending: [Event]`（`inverse: \Event.attendees`），deleteRule 默认 `.nullify`。
    - `Todo.project` / `Event.project` 已 optional（保留）；其 inverse 在 `Project.todos`/`Project.events` 侧（`.nullify`，保留）。
    - 审计确认**无** `@Attribute(.unique)` / `#Unique` 宏（grep 全模型仅注释提及）。enum 存 raw String 合规。
  - **`LinoJStore.makeContainer` 切 CloudKit**：签名改为 `makeContainer(inMemory: Bool = false, cloudSyncEnabled: Bool = true)`。`inMemory == true` 永远 `cloudKitDatabase: .none`（测试不触网）；`inMemory == false` 时 `cloudSyncEnabled ? .private(LinoJCloudKit.containerID) : .none`。
  - **`CloudSyncMonitor`**（新增 `CloudKit/CloudSyncMonitor.swift`）：`@Observable @MainActor`，`Status { idle/syncing/synced(Date)/error(String) }`，`start()` 订阅 `NSPersistentCloudKitContainer.eventChangedNotification`（CoreData）解析事件 → status；`lastSyncedText: LocalizedStringResource` 映射本地化文案；`cloudSyncEnabled: false` 时静默（idle + "Local only"）。
  - **App 启动注入**：两端 App init 读 `SettingsViewModel.readICloudSyncOn()`（新增静态读取器，与 init 同逻辑、默认 ON）传给 `makeContainer(cloudSyncEnabled:)`。RootWindow / RootTabView 的 `.task` 用同一开关创建 `CloudSyncMonitor` 并 `start()`，存入 `AppServices.cloudSyncMonitor`（AppServices 新增字段）。Settings 两端 `.task` 取出注入到自有 vm（`SettingsViewModel.attachSyncMonitor(_:)`）。
  - **Settings iCloud toggle 接真 + Last-synced pill**：`SettingsViewModel.iCloudSyncOn` 写 UserDefaults（v0.9 已有），运行时切换**不热切容器**（plan 决策：OFF 需重启）。toggle 旁加 mono caption "Restart to apply"（新增本地化 key `Settings.icloudRestartHint`）。`lastSyncedText` 从静态 `String` 改为 `LocalizedStringResource`，由 `CloudSyncMonitor` 实时驱动（"Synced just now" / "Syncing…" / "Sync paused" / "Local only"），移除 v0.9 "· placeholder"。状态点颜色随状态变色（syncing=蓝 / synced=绿 / error=红 / 纯本地=中性）。
  - 新增本地化 key 5 个：`Settings.syncedJustNow` / `Settings.syncing` / `Settings.syncPaused` / `Settings.syncLocalOnly` / `Settings.icloudRestartHint`，xcstrings + `xcstringstool compile` 同步双 lproj + LJStrings 三轨；LocalizationTests 批量覆盖加 5 项。
  - 测试：新增 `CloudKitConfigTests`（5 个：inMemory 可用 / inMemory 覆盖 cloudSyncEnabled / seed 计数 16-3-18-8 不变 / 纯本地分支不抛 / Person inverse 双向可遍历）+ `CloudSyncMonitorTests`（6 个：纯本地 idle / cloud idle 乐观 / 状态流转文案映射 / 纯本地忽略注入状态 / start 幂等 / Settings attach 跟随）。`SettingsPersistenceTests` 改 1 处（lastSyncedText 改 LocalizedStringResource 后解析比对）+ 加 1 个（OFF 回退 Local only）。
- 变更原因：付费账号下发后接通 CloudKit 跨端同步（plan v1.0 V1）。
- 影响范围：V1（共享）。模型改动为兼容变更（加默认值 + 关系转 optional/加 inverse），SwiftData 走 lightweight migration。测试路径仍 `inMemory: true` + `.none` 不触真云。
- 偏离说明：
  - ① **参数名用 `cloudSyncEnabled`（plan V1 契约名）而非任务书的 `cloudKitEnabled`** —— PROJECT_PLAN.md V1 节「关键接口/类型契约」明确写 `makeContainer(inMemory:cloudSyncEnabled:)`，以 plan 为准。
  - ② **`cloudKitDatabase` 用 `.private(LinoJCloudKit.containerID)` 而非 plan 文字的 `.automatic`** —— SwiftData 的 `.automatic` 不接受 container ID 参数，而 V1 要求「指定 `iCloud.com.linocai.linoj`」；`.private(containerID)` 是接受显式容器标识符的 API 形态，符合「指定单一 private container」语义。任务书也明确指向 `.private(LinoJCloudKit.containerID)`。
  - ③ **`CloudSyncMonitor.lastSyncedText` 返回 `LocalizedStringResource` 而非 plan 契约的 `String`** —— 项目本地化规范禁止 UI 出现 raw String 字面量（全局规范第 6 条），同步状态文案必须中英双语；返回 LocalizedStringResource 让 UI 直接 `Text(...)`。plan 契约的 `String` 仅为类型示意。
  - ④ **`CloudSyncMonitor` 无 `init(container:)`，改 `init(cloudSyncEnabled:)`** —— plan 契约写 `init(container: ModelContainer)`，但 SwiftData 不暴露其底层 `NSPersistentCloudKitContainer` 实例，monitor 靠全局 `NotificationCenter` 通知（object: nil）监听即可，无需持有 container；改为接收 `cloudSyncEnabled` 让纯本地模式直接静默，避免无谓订阅。
  - ⑤ **Last-synced 为真实状态（非降级）**：`NSPersistentCloudKitContainer.eventChangedNotification` 确实可用（CoreData framework），monitor 解析 import/export/setup 事件的进行中/结束/错误。但「真实 last-synced 时间戳文案」简化为状态档位文案（"Synced just now" 不带绝对时间），符合 plan 契约 `lastSyncedText` 列举的 4 档；synced 事件的 `endDate` 已捕获在 `.synced(Date)` 里，未来若要展示「N 分钟前」可直接用。
- 验收：
  - `swift test`（LinoJCore）**110 测试全绿**（98 + 12 新增）。`swift build --build-tests -Xswiftc -warnings-as-errors` 0 warning。
  - iOS Simulator（iPhone 17 Pro）`xcodebuild ... build` **BUILD SUCCEEDED**，0 warning。
  - macOS：`-allowProvisioningUpdates build` 仍在签名阶段失败（同 V0：device "Tedothy" 未注册 + 无 `com.linocai.linoj` profile，发生在 `GatherProvisioningInputs`/`CreateBuildDescription`，早于任何 Swift 编译——非代码 bug）。**编译阶段独立验证通过**：`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build` 跳过签名后 macOS target **BUILD SUCCEEDED**，0 warning，证明 macOS 代码（含 SettingsView_macOS / RootWindow / App init 改动）编译干净。

### [2026-05-28] V2 — Push（CloudKit 订阅式静默推送）完成

- 变更内容：
  - **不手搓 CKSubscription（关键认知修正）**：SwiftData 配 `cloudKitDatabase: .private(...)` 后底层 `NSPersistentCloudKitContainer` 已自动创建并管理 `CKDatabaseSubscription`，V2 不再按 V2 节原文「创建 `CKDatabaseSubscription` + `RemoteNotificationCoordinator`」实现——手搓会与 SwiftData 内部订阅冲突/重复。V2 真正只做两件让静默推送能后台唤醒 App 触发同步的事：开后台模式 + 注册远程通知。全局经验记录已有「SwiftData automatic 同步内置订阅」的方向，本 Phase 据此落地。
  - 新增 `Packages/LinoJCore/Sources/LinoJCore/CloudKit/RemoteNotificationRegistrar.swift`：`@MainActor public enum RemoteNotificationRegistrar`，静态 `register()` 用 `#if canImport(UIKit) && os(iOS)` 走 `UIApplication.shared.registerForRemoteNotifications()`、`#elseif canImport(AppKit)` 走 `NSApplication.shared.registerForRemoteNotifications()`。无状态、不抛错（注册结果系统异步处理，不持有 device token）。
  - **注册时机**：两端 `.task`（`RootWindow` macOS / `RootTabView` iOS），仅当 `SettingsViewModel.readICloudSyncOn() == true` 时调 `RemoteNotificationRegistrar.register()`（与 makeContainer / CloudSyncMonitor 同源开关）。纯本地模式不注册（monitor 仍以 `cloudSyncEnabled:false` 创建走静默 idle）。与 V0 的 `NotificationService` 本地通知授权（UNUserNotificationCenter）并行、互不替代——远程注册不弹授权弹窗（静默推送无需授权）。
  - **iOS 开启 Remote notifications 后台模式（V2 例外允许改 pbxproj）**：`INFOPLIST_KEY_UIBackgroundModes` build setting 对数组 key **实测不生效**（GENERATE_INFOPLIST_FILE 不映射，生成的 Info.plist 不含此项）。按 V2 节预案改用**显式 Info.plist 文件**：新增 `LinoJ-iOS/Info.plist`（仅含 `UIBackgroundModes = [remote-notification]`），两端 Debug+Release config 加 `INFOPLIST_FILE = Info.plist` 并保留 `GENERATE_INFOPLIST_FILE = YES`（生成的标准 key 合并叠加到该基底之上，实测 `CFBundleIdentifier` / `UILaunchScreen` 等仍正常生成）。
  - macOS 不改 background modes（运行时即可收推送），aps-environment 由 V0 已加。
  - 测试：新增 `RemoteNotificationRegistrarTests.swift`（1 个：headless 测试进程调 `register()` 不崩——macOS `NSApplication.shared.registerForRemoteNotifications()` 无 APNs 环境为 noop/异步失败，不抛不 crash）。
- 变更原因：让 CloudKit 跨端改动下发的 content-available 静默推送能后台唤醒 App，触发 SwiftData 自动 merge → `@Query` 自动刷新 UI（plan v1.0 V2）。
- 影响范围：V2（共享 + iOS pbxproj/Info.plist）。无业务逻辑改动，无回归（V1 的 110 测试 + V2 新增 1 = 111 全绿）。
- 偏离说明：
  - ① **不实现 V2 节契约的 `RemoteNotificationCoordinator` / `CKDatabaseSubscription`**——SwiftData automatic CloudKit 同步已内置 `CKDatabaseSubscription` 并管理推送，手搓会冲突/重复。改为只做「注册远程通知 + 开后台模式」的最小必要项，payload 由系统 + SwiftData 自动消费，无需 `handleRemoteNotification`。任务书已明确指向这条路线。
  - ② **`UIBackgroundModes` 用显式 Info.plist 文件而非 `INFOPLIST_KEY_UIBackgroundModes` build setting**——后者对数组 key 实测不映射进生成的 Info.plist（已 PlistBuddy 验证缺失）。`Info.plist` 放在 **SRCROOT 根目录**（`LinoJ-iOS/Info.plist`，与 `.xcodeproj` 同级、在 `PBXFileSystemSynchronizedRootGroup` 同步文件夹之外）——若放进同步文件夹内会被自动加入 Copy Bundle Resources 触发 Info.plist duplicate-output 编译错误。未改任何其它 pbxproj 设置（仅两 config 各加一行 `INFOPLIST_FILE`），同步根组结构未动。
- 验收：
  - `swift test`（LinoJCore）**111 测试全绿**（110 + 1 新增）。
  - iOS Simulator（iPhone 17 Pro）`xcodebuild ... build` **BUILD SUCCEEDED**；PlistBuddy 确认生成的 `LinoJ-iOS.app/Info.plist` 含 `UIBackgroundModes = [remote-notification]` 且 CFBundle*/UILaunchScreen 等生成 key 正常合并。无 V2 引入的代码 warning（仅 V0/V1 既有的 AccentColor 资产目录提示 + AppIntents 元数据信息，与 V2 无关）。
  - macOS：`CODE_SIGNING_ALLOWED=NO build` 跳签名 **BUILD SUCCEEDED**，无 V2 引入 warning（macOS 设备签名仍待用户 Xcode 手动 build，同 V0/V1，非代码 bug）。
  - grep 确认全工程**无** `CKDatabaseSubscription()` / `CKModifySubscriptionsOperation` 实例化、无 `RemoteNotificationCoordinator`（仅注释提及），证明依赖 SwiftData 内置订阅。

### [2026-05-28] V3 — Sign in with Apple 完成
- 变更内容：
  - 新增 `Packages/LinoJCore/Sources/LinoJCore/Auth/AppleSignInService.swift`：`@Observable @MainActor public final class AppleSignInService`，State 枚举 `signedOut` / `signedIn(userID:displayName:email:)`，便捷只读 `isSignedIn` / `userID` / `displayName` / `email`。`handleAuthorization(_:)` 从 `ASAuthorizationAppleIDCredential` 取 user/fullName/email；`restoreState()` 启动从持久化恢复；`refreshCredentialState()` 用 `ASAuthorizationAppleIDProvider.getCredentialState` 校验（`.revoked`/`.notFound` 自动登出）；`signOut()` 仅清身份**不动 SwiftData/CloudKit**（plan V3 决策）。首次授权拿到的 name/email 持久化，后续登录 credential 回 nil 时**沿用缓存值不覆盖成空**。
  - 新增 `Packages/LinoJCore/Sources/LinoJCore/Auth/KeychainIdentityStore.swift`：`AppleIDIdentityStore` 协议 + Keychain 实现（generic password，service `com.linocai.linoj.appleid`，`kSecAttrAccessibleAfterFirstUnlock`，失败静默降级）+ `InMemoryIdentityStore` 测试桩。
  - `AppServices` 增 `appleSignIn: AppleSignInService?` 字段；两端 RootWindow/RootTabView 的 `.task` 创建 service → `restoreState()` → `await refreshCredentialState()`，AppServices 长生命周期持有（不随 Settings sheet 重建）。
  - macOS `SettingsView_macOS` / iOS `SettingsSheet_iOS` Account 行接真：未登录显示原生 `SignInWithAppleButton(.signIn)`（scope `[.fullName,.email]`，样式随 colorScheme black/white），已登录显示姓名/email；Sign out 按钮（macOS Account 行内 / iOS 底部红色按钮）从 print 改为 `auth.signOut()`，iOS 仅在已登录时显示。
  - EventKit mirror 两个 toggle（Apple Calendar / Reminders）hint 从隐含 v0.9 占位改为显式 "(coming later)" 标记（plan V3：v1.0 不接 EventKit）；toggle 仍可拨、无 EKEventStore 接入。
  - 本地化新增 4 key（xcstrings + 两 lproj，`xcstringstool compile` 重生）：`Settings.signInWithApple`、`Settings.account.signedOutHint`、`Settings.account.notSignedIn`、`Settings.eventKitLaterHint`，中英双填，Strings.swift 加对应静态成员。
  - `SettingsViewModel.accountEmail` 占位字段保留（不再被 UI 消费，仅 SettingsPersistenceTests 断言其默认值），更新注释说明已被 AppleSignInService 取代。
  - 新增 `Packages/LinoJCore/Tests/LinoJCoreTests/AppleSignInServiceTests.swift`（6 测试）：初始登出、applyCredential 登入+字段+持久化、再登录沿用缓存 name/email、signOut 清状态+持久化、restoreState 恢复、空 store 维持登出。
- 变更原因：付费账号下发后接通 App 级 Sign in with Apple 登录身份展示（plan v1.0 V3）。
- 影响范围：V3（共享）。无业务数据逻辑改动（不碰 SwiftData/CloudKit），无回归。
- 偏离说明：
  - ① **持久化选 Keychain（plan V3 明确「敏感，存 Keychain 不是 UserDefaults」）而非任务书建议的 UserDefaults 简化**——以 plan 为准。已用 `AppleIDIdentityStore` 协议隔离，测试注入 `InMemoryIdentityStore` 不触真 Keychain；headless `swift test` 实测 Keychain generic password 读写成功（status 0）。任务书提到的 UserDefaults 方案作为 v1.1 可选降级未采用。
  - ② **服务类型名用 plan 契约的 `AppleSignInService` + `State` 枚举，而非任务书正文的 `AppleAuthService`**——PROJECT_PLAN.md V3「关键接口/类型契约」明确写 `AppleSignInService` / `handleAuthorization` / `refreshCredentialState` / `signOut`，以 plan 为准。任务书要求的状态机能力（isSignedIn/userID/displayName/email、applyCredential 测试钩子、signOut 清持久化、restoreState）全部满足，仅命名遵 plan。
  - ③ EventKit mirror hint 文案取 plan V3 给的「(coming later)」（plan 给了 "(coming later)" / "(not yet available)" 两个候选，选前者）。
- 验收：
  - `swift test`（LinoJCore）**117 测试全绿**（111 + 6 新增），超过 ≥114 要求。
  - iOS Simulator（iPhone 17 Pro）`xcodebuild ... build` **BUILD SUCCEEDED**，0 warning。
  - macOS `CODE_SIGNING_ALLOWED=NO build` 跳签名 **BUILD SUCCEEDED**，0 代码 warning（仅 AppIntents 元数据信息，与 V3 无关；macOS 设备签名仍待用户 Xcode，同 V0/V1/V2）。
  - 真机交互验收（点 Sign in → 系统弹窗 → 显示姓名/email、重启保持、撤销授权检测 revoked、Sign out 不清库）需用户在真机执行——单测覆盖状态机，UI 接线已就位。

### [2026-05-28] V6 隐私 manifest + 收尾（并入 V7/P7 可做部分）完成

- 变更内容：
  - **隐私清单 PrivacyInfo.xcprivacy（两端各一份）**：新增 `LinoJ-iOS/LinoJ-iOS/PrivacyInfo.xcprivacy` 与 `LinoJ-macOS/LinoJ-macOS/PrivacyInfo.xcprivacy`，放在两个 App target 的 `PBXFileSystemSynchronizedRootGroup` 同步文件夹内，自动入 bundle（无需改 pbxproj）。内容两端一致：`NSPrivacyTracking = false`、`NSPrivacyTrackingDomains = []`、`NSPrivacyCollectedDataTypes = []`、`NSPrivacyAccessedAPITypes` 仅声明一项 `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1`。
    - **数据收集为空的依据**：LinoJ 业务数据存用户**私有** CloudKit DB（`.private`），开发者无访问权，按 Apple 定义不算 collected；无分析、无广告、无第三方 SDK。SIWA 的 user identifier 仅本地 Keychain 持久化（不上送开发者服务器），故 `NSPrivacyCollectedDataTypes` 留空。
    - **required-reason API 仅声明 UserDefaults**：grep 全工程（`Packages/LinoJCore/Sources` + 两端 App）确认——仅 `SettingsViewModel`（`UserDefaults` 注入）用到 UserDefaults required-reason API；**无** file timestamp / disk space / system boot time / system uptime / active keyboard 等其它 required-reason API（grep `systemUptime`/`contentModificationDate`/`creationDate`/`attributesOfFileSystem`/`volumeAvailableCapacity`/`FileAttributeKey`/`resourceValues` 等全 0 命中）。按实声明，未凭空加任何 reason。
  - **LinoJCore README（V7 文档化）**：新增 `Packages/LinoJCore/README.md`（≤80 行），仅讲：打开 `LinoJ.xcworkspace`、`swift test --package-path Packages/LinoJCore`（含 `--enable-code-coverage`）、模块结构一览。明确不与 PROJECT_PLAN.md 重叠（README 末尾指回 plan 为权威）。
  - **测试覆盖率补强（V7/P7）**：新增 15 个测试（117 → 132 全绿），补薄弱处：
    - `SearchViewModelTests` +5：`open(.todo)` 按 scope 路由 Personal/Company、`open(.event)`→Calendar / `open(.project)`→Company、quick actions newEvent/newProject/jumpTo 全分支、`display(for:)` 的 event/project/全 quickAction 文案分支、`totalCount`/`flatItems` 一致。
    - `PersonalCompanyViewModelTests` +6：Personal `toggleUrgency`/`delete`/`normal` 列、Company `normal` 列 / `toggleDone` / 选中无 urgent 的 project filter（Q3）得空 urgent 列。
    - `AppleSignInServiceTests` +2：不同 userID 登录不沿用旧 name/email（合并仅对同 userID 回退）、空 store 首次只回 userID 时 name/email 维持 nil。
    - `CloudSyncMonitorTests` +1：cloud 模式 `start()`/`stop()` 生命周期（订阅/注销 CoreData observer）幂等可重入不崩。
    - `LinoJCoreSmokeTests` +1：`AppServices` 容器 init 全 nil + 注入实例反映（覆盖原 0% 的 init region）。
- 变更原因：补 App Store 要求的隐私清单（V6）+ 收尾 V7/P7 中不依赖真实签名的部分（LinoJCore README 文档化 + 核心 ViewModel/Service 测试覆盖 ≥70%）。
- 影响范围：V6 + V7/P7（共享 + 两端 App 资源）。无业务逻辑改动（仅新增测试 + 资源文件 + 文档），无回归。
- 偏离说明：
  - ① **未实际 archive / Validate App**（V6 节验收含 Archive + Organizer Validate；本 Phase 任务书明确「不实际 archive，需真实签名留用户」）——archive 需真实 Distribution 签名 + 已注册设备 + CloudKit production schema，与 V0 起 pending 的 macOS 设备签名同源，留用户 Xcode 手动执行（见下方「用户后续手动清单」）。
  - ② **未测 NotificationService**（0% line coverage 保持）——`UNUserNotificationCenter.current()` 在 headless `swift test` 进程无 App bundle 上下文，会崩溃/不稳定，写测试属「为凑数写无意义/不稳定测试」，按任务书纪律不写。即便完全排除该文件，ViewModels/+Services/ 仍达 ~89.7%（含它为 85.05%），远超 70%。
  - ③ ASC App 记录关联 / xcstrings 同步（V6 节范围内）——V0-V5 各 Phase 已随做（xcstrings 已在 V3/V5 双轨同步），ASC 建记录为用户网页操作（见 plan「用户需在网页端手动操作的清单」第 3 项），本 Phase 不重复。
- 验收：
  - `swift test`（LinoJCore）**132 测试全绿**（117 + 15 新增）。
  - **覆盖率（`--enable-code-coverage` + `xcrun llvm-cov report`，line coverage）**：ViewModels/ + Services/ 两目录合计 **85.05%**（1104/1298 行）；仅 ViewModels/ **91.71%**；含 Auth/ + CloudKit/ + 不可测的 NotificationService 在内的最宽口径 **78.06%**——均 **超过 ≥70% 目标**。单文件亮点：SearchViewModel 96%、CompanyViewModel 97%、PersonalViewModel 97%、SettingsViewModel 95%、AppServices 100%。
  - iOS Simulator（iPhone 17 Pro）`xcodebuild ... build` **BUILD SUCCEEDED**，0 代码 warning；PrivacyInfo.xcprivacy 确认进 `LinoJ-iOS.app/PrivacyInfo.xcprivacy`。
  - macOS `CODE_SIGNING_ALLOWED=NO build` 跳签名 **BUILD SUCCEEDED**，0 代码 warning；PrivacyInfo.xcprivacy 确认进 `LinoJ-macOS.app/Contents/Resources/PrivacyInfo.xcprivacy`。
  - 两个 `PrivacyInfo.xcprivacy` 文件存在且 `plutil -lint` 均 OK。
- 用户后续手动清单（本 Phase 不可代做，需真实签名 / 网页控制台）：
  - **① Xcode 手动 build macOS 一次**（V0 起 pending）：注册本机设备 + 自动生成含 CloudKit/Push/SIWA 三 capability 的 provisioning profile（headless `xcodebuild` 拉不到，须 Xcode 交互）。
  - **② Xcode Product → Archive（macOS + iOS 各一次）→ Organizer "Validate App"**：验证 profile / capability / 隐私清单无校验错误（V6 节验收，本 Phase 未做）。
  - **③ CloudKit Dashboard：Deploy Schema 从 Development → Production**（`iCloud.com.linocai.linoj`）：Release 构建走 production 环境，未部署则 production 端无 record types、跨端同步失败（plan「用户需在网页端手动操作的清单」第 2 项）。
  - **④ App Store Connect 建/确认 App 记录**：统一 Bundle ID `com.linocai.linoj`、Name=LinoJ、SKU=LINOJ001、主语言简中、iOS+macOS 两平台挂同一记录；如要提审再关联 build（plan 清单第 3 项）。

### [2026-05-28] V1 CloudKit 致命崩溃修复：to-many 关系须 optional（非 `=[]`）
- 变更内容：
  - **修正 V1「CloudKit 对现有 @Model 的硬约束清单」第 2 条的错误描述**：原写「to-many 关系必须有默认 `= []`」是**错的**。真实 CloudKit `.private` 容器（`NSPersistentCloudKitContainer`）加载时校验 schema 报 `CloudKit integration requires that all relationships be optional`，要求**所有关系（含 to-many）类型必须 optional `[X]?`**，非 optional 数组 + `= []` 不满足。已就地把 V1 节第 2 条改为「所有关系（含 to-many）必须 optional `[X]?`，init 默认值给空数组」。
  - **6 个 to-many 关系类型从 `[X] = []` 改为 `[X]?`**（grep 确认）：`Project.members: [Person]?` / `Project.todos: [Todo]?` / `Project.events: [Event]?` / `Event.attendees: [Person]?` / `Person.memberOf: [Project]?` / `Person.attending: [Event]?`。deleteRule / inverse 全部保留不变。to-one（`Todo.project` / `Event.project`）本已 optional，未动。
  - **init 默认值**：`Project.init(members: [Person]? = [])` / `Event.init(attendees: [Person]? = [])` 改 optional 参数，默认 `= []`（构造时存空数组而非 nil，行为更自然；CloudKit 校验的是类型 optional 不是值非空）。`Project.init` 里 `memberCount = (members ?? []).count`。
  - **全访问点加 `?? []` 兜底**：`(rel ?? [])` 统一模式。源码改动文件——`ProjectCard.swift`（members×4 / todos×3 / events×2）、`EventCard.swift`（attendees）、`SearchViewModel.swift`（todos/events count hint）、`QuickAddViewModel.swift`（`projectMembers = editing.members ?? []`，line 151）、`SeedData.swift`（fault 预热 3 处）、`MainView_macOS.swift`（todos×2/events/members）、`ProjectDetailView_macOS.swift`（members/attendees）、`ProjectDetailView_iOS.swift`（members/attendees）。`QuickAddViewModel.submit()` 的 `existing.members = projectMembers` 是 `[Person]→[Person]?` 赋值（合法，不需改）。
  - **SeedData 关系赋值方式**：全程**构造时整体赋值**（`Project(members: [...])` / `Event(attendees: [...])` 经 init 参数），无任何 `.append` 到 optional 数组，天然安全。
  - **memberCount 同步逻辑**：`Project.init` 改 `(members ?? []).count`；`QuickAddViewModel` edit 分支 `existing.memberCount = projectMembers.count`（`projectMembers` 是非 optional 本地 state，不变）。`ProjectDetailViewModel.membersSinceText` 仍读 `project.memberCount`（不读关系），无需改。
  - **测试**：修 `CloudKitConfigTests`（inverse 断言 `?? []`）、`ModelTests`（attendees `?? []`）、`QuickAddViewModelTests`（members `?? []`）；**新增** `CloudKitConfigTests.toManyOptionalRelationshipsReadWrite`——inMemory 建 project + 2 todos + 2 members + 1 event，全 6 关系读出 count 正确 + 空关系兜底（逼近真实读写路径）。该测试注释说明：真实 `.private` 容器 schema 校验需 entitlement + 签名，headless 无法构造，只能用户 Xcode 真机重跑验证。
- 变更原因：V1 之前按错误的约束清单把 to-many 写成 `[X] = []`，真机 macOS `LinoJ_macOSApp.init()` → `makeContainer(cloudSyncEnabled: true)` 加载 `.private` 容器时 schema 校验 fatalError 崩溃。
- 影响范围：V1（共享）。模型关系类型变更（`[X]=[]` → `[X]?`），SwiftData 走 lightweight migration（关系转 optional 是兼容变更）。测试路径仍 inMemory + `.none` 不触真云。
- 验收：`swift test`（LinoJCore）**133 全绿**（132 + 1 新增）；iOS Simulator（iPhone 17 Pro）`xcodebuild build` **BUILD SUCCEEDED** 0 warning；macOS `CODE_SIGNING_ALLOWED=NO build` **BUILD SUCCEEDED** 0 warning。⚠️ headless 无法验真实 CloudKit 容器加载（需签名），用户需在 Xcode 真机重跑确认 `.private` 容器不再崩。

### [2026-05-28] CalendarView_macOS 周视图垂直空白 bug 修复
- 变更内容：重构 `CalendarView_macOS.content(vm:)` 的内层布局，消除星期表头与时间网格之间约 220pt 的两段神秘空白：
  - 给 `GeometryReader` 内层 `VStack(spacing: 0)` 显式加 `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)`，杜绝其在 GeometryReader 满高内被垂直居中。
  - 把纵向 `ScrollView(.vertical)` 改为唯一「贪婪」吃剩余高度的元素：加 `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`，内层 `weekGrid` 加 `.frame(maxWidth: .infinity, alignment: .topLeading)`。多余高度只留在网格底部（9PM 之后），不再摊到表头上下。
  - 同样的 top-align 原则应用到 < 1100pt 横向 scroll 路径的 `scrollableWeekGrid`（外层 VStack + 纵向 ScrollView 双重 top-align greedy frame）。
  - 表头行 padding 从 `.bottom s8` 调为 `.top s6 + .bottom s8`，与 divider 间距收紧（≤8pt）。
  - 顺手修 `timeLabelColumn`：7AM 等小时标签从 `.position(x:, y: i*pxPerHour)`（中心压在 y=0 顶部半截被裁）改为 `.offset(y: i*pxPerHour + 6) + .padding(.leading, s6)`（topLeading 锚点 + 6pt 顶部内边距），首个 7AM 标签完整可见。
- 根因：`GeometryReader` 贪婪占满高度，但内层 `VStack` 无显式高度 frame，SwiftUI 默认将其内容垂直居中；ScrollView 又只按 644pt 内容自适应不吃满高度，导致剩余高度被均分到内容上下 → 两段近似相等的空白。
- 变更原因：用户真机 macOS 截图显示周视图排布散乱、表头与网格间大段空白。
- 影响范围：v0.9 P3.4 `CalendarView_macOS.swift`（仅外层垂直布局重构 + 时间标签定位修正）。ViewModel / 网格内部渲染（eventLayout / nowLineY / dayColumn）/ header / 响应式断点 / now Timer / EmptyState 逻辑均未动。
- 列对齐确认：`weekdayHeaderRow` 与 `weekGrid` 均用同一 `timeColumnWidth`(52pt) 占位 + 同一 `columnWidth` + 同一 `.padding(.horizontal, s28)`，7 列精确对齐。
- 验收：`swift test`（LinoJCore）**133 全绿**（不受影响）；macOS `CODE_SIGNING_ALLOWED=NO build` **BUILD SUCCEEDED**，`CalendarView_macOS.swift` 0 warning（仅余 RootWindow / AccentColor 等既存无关 warning）。⚠️ headless 无法看渲染结果，布局正确性靠显式 top-align frame 在逻辑上保证。

### [2026-05-28] Calendar 对齐设计稿：周模型改 today 起算滚动 7 天 + 事件卡片内容补全
- 变更内容：
  - **周模型从「周一起算日历周」改为「today 起算的滚动未来 7 天」**（`CalendarViewModel.swift`）。`weekStart = startOfDay(today)`（不再回退到周一）；`weekDays = [today, today+1, …, today+6]`，today 落在第一列。`goPrevWeek`/`goNextWeek` 整体平移 ±7 天（API/签名不变），`goToday` reset 回 today 起点。`weekTotal`/`eventsByDay` 基于 `[weekStart, weekStart+7)` 窗口。public API 名字全部保留（weekStart/weekDays/goPrev/goNext/goToday/selectedDay/eventsByDay/weekTotal/todayStart/yesterdayMissed/isViewingTodayWeek），仅改语义。把 `startOfMondayWeek(containing:)` helper 替换为 `startOfWeek(containing:) = startOfDay`（确认仅测试 + vm 自身引用，无别处依赖）。`clampedSelectedDay` 从「映射到同 weekday」改为「保持同列偏移（±7 平移）」。`calendar` 的 `firstWeekday=2` 保留为无害遗留（窗口已不依赖）。
  - **DEBUG seed 落点不变**：today=`LinoJTime.today()`=2026-05-27，16 个事件 dayOffset 0..6 全落在窗口 May 27–Jun 2 → `weekTotal == 16`（旧 Mon-week 模型为 15，因 Sun/Mon2 落到下周）。y1/y2（yesterday=May 26）在窗口外，仍出现在 `yesterdayMissed`（=2）。
  - **CalendarViewModelTests 更新**：`weekStartIsMonday`→`weekStartIsToday`（断言 `weekStart == startOfDay(today)` + `weekDays.first == today`）；`weekTotal` 15→16；`goTodayResetsToTodayWeek` 改用 `startOfWeek`；测试注释整体重写为窗口模型说明。仍 11 个测试全绿。
  - **macOS 表头 TODAY 列标签**（`CalendarView_macOS.weekdayHeaderCell`）：today 列顶部小标签显示本地化 "TODAY"/"今天"（新 key `Calendar.today`），非 today 仍显周缩写；today 圆点 • 保留。iOS today pill 本已用 `LJStrings.today`+uppercase 显示 "TODAY"/"今天"，确认一致，未改动。
  - **计数文案** "X events this week" → "X events · next 7 days"（两端 `countsLine`/header）。新 key `Counts.eventsNext7Days` = "%d events · next 7 days" / "未来 7 天 %d 场事件"。旧 `Counts.eventsThisWeek` 在 Swift 已无引用，保留于 xcstrings/lproj（无害本地化数据，不删以减少 churn）。
  - **EventCard `.macWeekGrid` 内容补全**（仅此 variant，其它三个 variant 未动）：布局改为 标题（13pt semibold ink，showTime 时 lineLimit 2 否则 1）→「时间 · 地点」（11pt inkSoft，location 空时只显时间不带 " · "）→ 头像栈（`AvatarStack(people:, max:3)`，底部 `Spacer` 顶起）。左侧 2px 黑 accent / 白底 / 圆角保留。**高度自适应**：用 `GeometryReader` 读卡片实际高度——标题恒显；时间行 `h≥30` 才显；头像栈 `h≥56` 且有 attendees 才显（对应设计 h>50）；内容顶对齐 + `.clipShape` 裁剪，短事件溢出被裁不外溢。时间格式新增 `clockText`：固定 `Locale("en_US")` 的 `h:mm a`（非整点 "9:30 AM"）/ `h a`（整点 "3 PM"），与设计英文格式一致，不随 App 中文 locale 变。
  - **本地化双轨**：编辑 `Localizable.xcstrings` 加两 key（中英双填，manual extractionState）后跑 `xcrun xcstringstool compile Resources/Localizable.xcstrings -o Resources/` 重生 en/zh-Hans 两 lproj，已 plist 验证值正确。
- 变更原因：用户用真机截图对比设计稿，确认 Calendar 周视图差两点——① 周模型应为 today 起算滚动 7 天（设计 "16 events · next 7 days" + 第一列 TODAY + nav "May 27 — Jun 2"），② 事件卡片缺地点与头像。
- 影响范围：v0.9 P3.4 —— `CalendarViewModel.swift`（共享）、`EventCard.swift`（共享，仅 macWeekGrid）、`CalendarView_macOS.swift`、`CalendarView_iOS.swift`、`Strings.swift` + `Localizable.xcstrings` + 两 lproj（共享本地化）、`CalendarViewModelTests.swift`。
- 偏离说明：① 任务建议 `AvatarStack` "小尺寸"，但 `AvatarStack` 无 size 参数（macOS 固定 22pt），按纪律不改其它组件 API，故沿用既有 22pt + 仅在卡片够高（h≥56）时显示并 `.clipShape` 裁剪，效果上等同设计「仅高卡显头像」。② 旧 `Counts.eventsThisWeek` 未删（任务允许「可删」）。
- 验收：`swift test`（LinoJCore）**133 全绿**（含 `CalendarViewModelTests` 11 个、`weekTotal == 16`、`LocalizationTests` 双语断言）；macOS `CODE_SIGNING_ALLOWED=NO build` **BUILD SUCCEEDED** 0 代码 warning；iOS Simulator（iPhone 17 Pro）`build` **BUILD SUCCEEDED** 0 warning。⚠️ headless 无法看渲染结果，卡片高度降级靠 GeometryReader + clip 在逻辑上保证。

### [2026-05-28] 0.9.1 reviewer 修复 + iOS TestFlight 发版准备
- 变更内容（reviewer 致命/重要/建议项 1-6 + 发版准备 7-9）：
  - **【致命 1】ModelContainer init 失败回退本地，不再 fatalError**（`LinoJ_iOSApp.swift` / `LinoJ_macOSApp.swift`）：新增 `makeContainerWithFallback()`——先按启动期 `cloudSyncEnabled` 试建容器，CloudKit 容器失败（iCloud 未登录 / 网络差 / production schema 未部署 / 迁移异常）时**回退**再试 `makeContainer(cloudSyncEnabled: false)`（纯本地 `.none`）；仅本地也失败才 fatalError（基本不可能）。回退时写 `UserDefaults` 标记 `linoj.cloudFellBackToLocal=true`（成功建 CloudKit 容器时清回 false），供未来 Settings 显示「iCloud 暂不可用」——本次未加 UI（最小实现，任务不强求）。DEBUG seed 逻辑保留：回退后仍 `try? SeedData.seedIfEmpty` 到本地容器。
  - **【重要 2】版本号 bump**：两端 pbxproj（各 Debug+Release）`MARKETING_VERSION` 0.9.0→**0.9.1**、`CURRENT_PROJECT_VERSION` 1→**2**。
  - **【重要 3】macOS 顶栏状态 dot 接 CloudSyncMonitor**（`RootWindow.swift`）：`wordmark()` 的状态 dot 从硬编码 `Color.lj.inkDim` 改为新增计算属性 `syncDotColor`，映射 `services.cloudSyncMonitor?.status`：syncing=blue / synced=#19c332 绿 / error=红 / idle / nil / 本地=`inkDim` 中性。与 `SettingsView_macOS.syncDotColor` 同套逻辑。
  - **【重要 4】Keychain 写入改 SecItemUpdate 优先**（`KeychainIdentityStore.swift setValue`）：从「先无条件 deleteItem 再 SecItemAdd」改为先 `SecItemUpdate`，返回 `errSecItemNotFound` 再 `SecItemAdd`。避免 delete 成功而 add 失败丢身份；写失败时旧值保留。
  - **【建议 5】plist DOCTYPE 笔误**：两端 `PrivacyInfo.xcprivacy` 第 2 行 + iOS 根目录 `Info.plist` 第 2 行 `apple.com/DTDs/PropertyList`（多 s）→ `apple.com/DTD/PropertyList-1.0.dtd`（与 entitlements 一致）。
  - **【建议 6】iOS Settings 通知项过期文案**：`Settings.v1OnlyHint` xcstrings 值 "(coming in v1.0)"/"（v1.0 中接通）" → "(coming later)"/"（后续版本）"（与 EventKit mirror `Settings.eventKitLaterHint` 口径一致）。`xcstringstool compile` 重生两 lproj，plist 验证值正确。Swift 侧 key 引用不变。
  - **【发版 7】App 显示名 = LinoJ**：两端 pbxproj（各 Debug+Release）加 `INFOPLIST_KEY_CFBundleDisplayName = LinoJ`（单值字符串 key，GENERATE_INFOPLIST_FILE 机制下能映射进生成的 Info.plist；已 PlistBuddy 验证 `CFBundleDisplayName == LinoJ`）。修掉主屏图标显示 "LinoJ-iOS"。
  - **【发版 8】Export compliance**：iOS 显式 `Info.plist` 加 `ITSAppUsesNonExemptEncryption = false`（App 只用 HTTPS/CloudKit 标准加密），免 TestFlight 上传弹出口合规问卷。验证生成 plist 含此 key + `UIBackgroundModes` 仍保留（显式 plist + INFOPLIST_KEY 合并叠加正常）。macOS 这轮不发，未加。
  - **【发版 9】清理 print() + 隐藏死 stub 按钮**：全工程 15 处 `print()` 清零（`grep "print(" | grep -v "#if DEBUG" | wc -l` == 0）。① QuickAdd submit 失败的 2 处错误日志改静默（`_ = error`，sheet 保持打开让用户重试）。② **隐藏 Quick Add 的 Attendees「+ Add」/ Members「+ Invite」两个空 stub 按钮**（macOS `QuickAddModal_macOS.swift` + iOS `QuickAddSheet_iOS.swift`）：这两个选择器无真实选择能力，点了没反应；改为整节仅在 `eventAttendees`/`projectMembers` 非空时渲染（当前恒空 = 整节隐藏）。**创建 Event/Project 仍可正常提交**（只是不带 attendees/members）。③ 其它 stub（About 链接 ×5、ProjectDetail ⋯ / add todo / add event ×4）去掉 print，按钮保留（beta 可接受点击静默无反应）。
- 变更原因：reviewer 审完 V0-V6 云代码给出致命+重要项 + 发版准备需求；准备发 0.9.1 + iOS TestFlight（macOS 这轮不发）。
- 影响范围：v1.0 V0-V6 收尾 + 发版 —— `LinoJ_iOSApp.swift`、`LinoJ_macOSApp.swift`、`RootWindow.swift`、`KeychainIdentityStore.swift`（共享）、`QuickAddModal_macOS.swift`、`QuickAddSheet_iOS.swift`、`SettingsView_macOS.swift`、`SettingsSheet_iOS.swift`、`ProjectDetailView_macOS.swift`、`ProjectDetailView_iOS.swift`、两端 `project.pbxproj`、两端 `PrivacyInfo.xcprivacy`、iOS `Info.plist`、`Localizable.xcstrings` + 两 lproj（共享本地化）。
- 偏离说明：
  - **fatalError 回退涉及 V1「OFF 需重启」语义**：V1 原约定运行时切 iCloud 开关不热切容器、下次启动按新值生效。本次回退**不改这条**——回退只在「App init 时按当前开关建 CloudKit 容器失败」的异常路径触发，把本次启动降级为纯本地容器，**不修改用户的 iCloud 开关值**（开关仍 ON）。即：用户开关仍是 ON、本次跑本地、`linoj.cloudFellBackToLocal=true`；待下次启动（iCloud 恢复可用）会重新尝试建 CloudKit 容器并清标记。语义上是「ON 但本次云不可用 → 本地兜底」，与「OFF」是两回事，不破坏 V1 重启生效约定。
  - 建议 6 未新增/不删任何 Swift key，仅改 `Settings.v1OnlyHint` 的本地化值（任务即此要求）。
  - 隐藏 stub 按钮选择「非空才渲染整节」而非新增「无可选」占位文案，避免引入新本地化 key 增加双轨维护成本（任务允许「隐藏」，未要求占位提示）。
  - macOS 签名配置（CODE_SIGN_IDENTITY 等）**未动**（任务明确禁止，macOS 这轮不发）。
- 验收：`swift test`（LinoJCore）**133 全绿**；`swift build -Xswiftc -warnings-as-errors` **0 warning**；iOS Simulator（iPhone 17 Pro）`build` + macOS `CODE_SIGNING_ALLOWED=NO build` 均 **BUILD SUCCEEDED**；`print(` 非 DEBUG 计数 **0**；两端 pbxproj grep 确认 `MARKETING_VERSION = 0.9.1` / `CURRENT_PROJECT_VERSION = 2`；PlistBuddy 验证生成 Info.plist `CFBundleDisplayName=LinoJ`、iOS `ITSAppUsesNonExemptEncryption=false`、`UIBackgroundModes` 含 `remote-notification`、版本 0.9.1/2。

### [2026-05-28] 0.9.1 真机落地 + 用户验收后的布局/交互修复（收尾）

- **iOS 真机验证通过**：付费证书数据线部署到真机，App 正常启动 → 之前 reviewer 担心的「真机 .private CloudKit 容器能否加载」证实通过（headless 验不了，只能真机）。用户实测 **CloudKit 跨设备同步可用**（传输正常）。0.9.1 对个人使用实打实落地（付费 dev profile 1 年有效，到期重连 ⌘R 续）。
- **用户验收发现并修复的 bug（主会话直接改，均已 build 验证）**：
  - macOS 顶栏改 unified chrome：`.windowStyle(.hiddenTitleBar)`，自定义顶栏与红绿灯同排融合；tab 从 `.pickerStyle(.segmented)`（蓝底系统控件）改为对齐 direction-a.jsx 的自定义 chip 按钮（active=chip 底+ink+600）；TrafficLightConfigurator 把红绿灯垂直居中到 44pt 顶栏。
  - 日历布局连环 bug：① 星期表头行 `Color.clear.frame(width:)` 未限高 → 纵向贪婪撑成 ~500pt（"上下均等空白"真因，非 ZStack 居中/ScrollView 未填充——前几次误判）。修：限高 + 行 `.fixedSize(vertical:true)`。② RootWindow 内容分发 ZStack 补 `.topLeading`（防未填满子视图被居中）。③ header 移出 GeometryReader（geo.width > 窗口宽导致「新建事件」按钮溢出被裁）。④ 列宽算法补减 `s28*2` 水平 padding。
  - 日历对齐设计：周模型从「周一到周日」改为「today 起算未来 7 天」（weekStart=startOfDay(today)、TODAY 列标签、计数「16 events · next 7 days」）；EventCard `.macWeekGrid` 改为 标题→「时间·地点」→头像栈，时间格式锁 en_US。
  - iOS 底部 **两条 tab bar 叠加** bug：删自渲 `FloatingTabBar` + 失效的 `.toolbar(.hidden, for: .tabBar)`，改用 iOS 26 原生 Liquid Glass tab bar。
  - macOS **Settings 退不出去** bug：`.sheet` 不响应 ESC 且无关闭按钮 → 加右上「完成」按钮 + `.keyboardShortcut(.cancelAction)`。
- **App Icon**：用户提供 rounded-J 图，iOS 1024 单图（无 alpha）+ macOS 全套 10 尺寸，actool 编译通过。
- **遗留（不阻塞个人使用；走 TestFlight/上架时再做）**：CloudKit schema deploy 到 Production（dev↔prod 数据隔离）；iOS 各屏滚动到底的 ~100pt 多余底部留白（原为让开旧浮动 capsule，现原生 bar 由系统处理安全区，可后续收）；Quick Add 的 Attendees/Members 选择器仍为隐藏 stub（未实现选人）；Settings 多个通知/同步占位开关仍标 "(coming later)"。
- 经验已沉淀至 `~/.claude/CLAUDE.md`「[2026-05-28] SwiftUI 布局/分发踩坑」。

### [2026-05-28] 0.9.1 真机打包 + seed 竞态修复 + 工程清理（本轮收尾，供新会话接手）

**修复**
- **seed × CloudKit 竞态（数据翻倍真因）**：两端 App init 的 DEBUG `seedIfEmpty` 改为**仅在 iCloud sync OFF（纯本地）时执行**。cloud ON 时本地启动瞬间为空、CloudKit 异步同步未完成，无脑 seed 会抢在同步前塞一份 → 与云端重复累积（多端/多次安装叠 2×、3×）。cloud ON（含 init 失败回退本地的异常态）一律不 seed。Release 永不 seed（不变）。
- **macOS 桌面包本地化全变 raw key**：根因是用 `cp -R` 拷 .app 把 `Contents/Resources/`（含 SwiftPM 包 `LinoJCore_LinoJCore.bundle` 的 lproj）拷丢了；`codesign --verify` 仍过、app 仍能启动，极迷惑。**改用 `ditto` 拷 .app**。Release 产物本身一直正确。
- macOS Settings sheet 退不出去（ESC 无效 + 无关闭按钮）→ 加右上「完成」按钮 + `.keyboardShortcut(.cancelAction)`。
- iOS 底部两条 tab bar 叠加（`.toolbar(.hidden, for:.tabBar)` 在 iOS 26 不隐藏原生 bar）→ 删自渲 FloatingTabBar，用原生 Liquid Glass tab bar。

**工程清理**：删 `Packages/LinoJCore/.build`(207MB 缓存)、`.DS_Store`、过期的 `SETUP_XCODE.md`、`xcuserdata`。工程 210M→3.5M。源码/工程/设计稿/测试零改动。源码 0 处 DIAG 残留。**注意：项目尚未 `git init`**（有 .gitignore 但无 .git），新会话若要版本管理需先初始化。

**当前状态（0.9.1）**：133 测试全绿；两端 Debug + macOS Release build 通过；iOS 真机部署跑通、CloudKit 跨设备同步**实测可用**；桌面 `~/Desktop/LinoJ.app`（Apple Development 签名，dev 环境，个人可用约 1 年）。**个人使用已落地**。

### [2026-05-28] v1.0 收口规划：扩充 W 组三个 Phase（W1/W2/W3）

- **动机**：v1.0 公开上线前的三块功能缺口，用户已确认全做。在上半部分生效 plan 的 V7 之后新增「v1.0 收口 Phase 列表（W 组）」，并把「🚀 v1.0 公开上线剩余清单」里的三条缺口指向对应 W Phase。本次仅改 plan，不动任何 App 源码 / 测试。
- **涉及 Phase（新增）**：W1 / W2 / W3，均 [全栈]，无付费能力依赖，互相独立、可任意顺序，但都依赖 v0.9 + V5。
- **W1（Quick Add 选人器）决策**：从既有 Person 多选 + **允许临时新建 Person**（按 name 去重，命中复用既有；不做 Person 管理面板）。落库**只走既有** `Event.attendees` / `Project.members` 关系，**不新增 @Model、不改 schema**。VM 落点选 `QuickAddViewModel` 加 `toggleAttendee/Member`、`isXSelected`、`addPerson(named:existing:target:)` + `PersonTarget` 枚举，复用 V5 的 submit（含 memberCount 重算）。macOS 内联展开选人区、iOS 二级 picker。临时新建 Person「选中即 insert、随 submit save、取消不强制回滚」（权衡写明）。
- **W2（Settings 占位开关）逐项决策**：✅真接通——`showCompletedInCounts`（影响 Main/Personal/Company/ProjectDetail 的 open 计数，VM 加注入式 `includeCompletedInCounts`）、`systemBannerEnabled`（作 scheduleAll 总闸门）、`yesterdayMissedReminderEnabled`（作「From yesterday」box 显示闸门，VM 加 `showYesterdayMissed`）。⏸隐藏整行——`dailySummaryHour` / `quietHours`（重活延后，仅删 UI，VM 字段 + UserDefaults + 测试全留）。⏸保留但禁用——`calendarMirrorOn` / `remindersMirrorOn`（EventKit 路线图项，保留 "(coming later)" + `.disabled(true)`）。三个已接通行去掉 "(coming later)"。**不改 SettingsViewModel**（不破坏 SettingsPersistenceTests）。
- **W3（⋯ 菜单 / Search 定位 / About 链接）逐项决策**：① macOS ⋯ 空 Button → `Menu`（Edit project 复用 V5 + 新增 Delete project 带确认弹窗 + pop；iOS ⋯ 追加 Delete）；删除沿用 `.nullify`（todos/events 变 standalone）。② Search 三类结果**全部精确定位**——project push 到 ProjectDetail、event 切 Calendar 定位到那天、todo 切对应 tab + scrollTo bubble（被 filter 隐藏则先重置 filter）；走 TabRouter 新增 `pending*` 信号 + 各屏 onChange 消费；事件/bubble 高亮列为可选（无承载字段则只滚动）。③ About 链接：✅Feedback（mailto）、✅Privacy（`LinoJLinks.privacyPolicy` 占位 URL，**待用户替换真实隐私政策 URL**）；⏸砍掉 Release notes + Acknowledgements 两行。新增 `LinoJLinks` 常量 + `ProjectDetailViewModel.deleteProject()`。
- **三条贯穿约束已写进 W 组开头**：CloudKit 关系 optional + 不改 schema；memberCount 每次编辑重算；本地化双轨三步（xcstrings → xcstringstool compile → Strings.swift），各 Phase 列了需新增的 key 清单。
- **影响范围（待 builder 施工）**：共享 `QuickAddViewModel` / `MainViewModel` / `PersonalViewModel` / `CompanyViewModel` / `ProjectDetailViewModel` / `CalendarViewModel` / `SearchViewModel` / `TabRouter` / 新增 `LinoJLinks` / `Strings.swift` + `Localizable.xcstrings` + 两 lproj；两端 `QuickAdd*` / `Settings*` / `ProjectDetailView*` / `CompanyView*` / `CalendarView*` / `RootWindow.swift` / `RootTabView.swift`。本次规划阶段**零源码改动**。

### [2026-05-28] W1 施工：Quick Add 选人器接真（Attendees / Members）

- **变更内容**：按 W1 plan 施工。
  - **共享**：`QuickAddViewModel` 新增 `PersonTarget` 枚举 + `toggleAttendee/isAttendeeSelected` + `toggleMember/isMemberSelected` + `addPerson(named:existing:target:)`（trim → 空白返回 nil；按 name trim+小写查重名，命中复用既有、未命中 `Person(name:)`+`context.insert`，立即选中、**不在此 save**，随 submit 落库）。submit() 与 V5 路径不改，memberCount 仍由既有 submit 重算。`Strings.swift` 加 9 个 `LJStrings` 成员；`Localizable.xcstrings` 双填 9 key 并 `xcstringstool compile` 重生两 lproj。新增 `QuickAddPeoplePickerTests`（7 测试：toggle 去重、isSelected、addPerson 复用 vs 新建、空白名 nil、create Project memberCount==members.count、Event attendees 落库）；`LocalizationTests` 加 W1 9 key 的 zh≠en 断言。
  - **macOS**（`QuickAddModal_macOS.swift`）：Attendees/Members 两节去掉「仅非空才渲染」逻辑，改始终渲染（标题 + 入口按钮 + 已选 AvatarStack 或空态提示）；点入口内联展开限高 160pt 可滚动 Person 列表（顶部输入框 + checkmark 行 toggle + 「+ 新建『<name>』」行）。新增 `@Query(sort:\Person.name) allPeople` + 展开态/搜索 State，随 onDisappear 复位。
  - **iOS**（`QuickAddSheet_iOS.swift`）：两节同样始终渲染 + 入口按钮 present 二级 `PeoplePickerSheet_iOS`（NavigationStack + List checkmark 多选 + `.searchable` + 「+ 新建」行 + 右上「完成」回传）；`.sheet(item:)` 叠在 Quick Add sheet 上。新增 `@Query allPeople` + `peoplePickerTarget` State，随 onDisappear 复位。
- **变更原因**：补 0.9.1 隐藏的最大缺口（建 Event 加不了参会人 / 建 Project 加不了成员）。
- **影响范围**：Phase W1。共享 `QuickAddViewModel.swift` / `Strings.swift` / `Localizable.xcstrings` + `en.lproj` + `zh-Hans.lproj` / 新增 `QuickAddPeoplePickerTests.swift` / `LocalizationTests.swift`；macOS `QuickAddModal_macOS.swift`；iOS `QuickAddSheet_iOS.swift`。**未新增 @Model、未改 schema**。
- **偏离说明（按 plan 契约执行）**：
  - 临时新建 Person 用户取消时**不强制回滚**（采纳 plan 默认最小实现，残留无引用 Person 可接受，下一版 People 面板清理）。
  - `addPerson` 选中时用「未选才 append」而非 `toggle`，避免「复用既有且恰已选」被反选——符合「新建/选中」语义（plan 契约也提示了此权衡）。
  - 新增 key 命名/文案全部照 plan「需新增的本地化 key」清单，无偏离。
- **验收**：`swift test --package-path Packages/LinoJCore` **141 测试全绿**（含新增 7 picker + W1 本地化断言）；`swift build -Xswiftc -warnings-as-errors` **0 warning**；macOS `CODE_SIGNING_ALLOWED=NO build` **BUILD SUCCEEDED**（唯一 warning 在 `RootWindow.swift:379 reposition()`，W1 前既有、与本期无关）；iOS Simulator（iPhone 17 Pro）`build` **BUILD SUCCEEDED** 0 代码 warning。⚠️ headless 无法验真实 UI 渲染 / 真实 CloudKit 容器落库——选人交互、临时新建落库、V5 edit 增删、memberCount 跨端同步、重启留存**需用户真机验收**（plan W1「验收标准」全部条目）。

---

### [2026-05-28] W2 施工：Settings 占位开关逐项收口（消费 or 隐藏）
- **变更内容**：按 W2 plan 施工。**不改 `SettingsViewModel`**（字段 / 默认值 / persist / 测试全保留）。
  - **共享（各 VM 加注入式 bool，VM 不读 UserDefaults）**：
    - `MainViewModel` + `includeCompletedInCounts`（true → `openCount` 含 done = `.count`；false 维持仅未完成）+ `showYesterdayMissed`（false → `yesterdayMissed` getter 短路 `[]`，含 service 路径）；新增 `allTodos()` 助手。
    - `PersonalViewModel` / `CompanyViewModel` / `ProjectDetailViewModel` + `includeCompletedInCounts`（分别改 `openCount` / `todosCount` / `openCount` getter）。
    - `CalendarViewModel` + `showYesterdayMissed`（短路 `yesterdayMissed`，含 service 路径）。
    - 测试扩充（+8，141→149）：`MainViewModelTests` 加 openCount 14↔16 差异 + showYesterdayMissed gate（fallback + service）；`PersonalCompanyViewModelTests` 加 Personal/Company 含 done 计数差异；`ProjectDetailViewModelTests` 加 openCount 含 done；`CalendarViewModelTests` 加 showYesterdayMissed gate（fallback + service）。`SettingsPersistenceTests` 无回归。
  - **三项真接通的消费契约**：
    - `showCompletedInCounts` → Main/Personal/Company/ProjectDetail 的 open/todos 计数（urgent / kanban 内容不变）；各屏 View 注入 + `.onChange` 即时刷新。
    - `systemBannerEnabled` → `NotificationService.scheduleAll` 总闸门：两端 `RootWindow`/`RootTabView` 的首次调度 + lead/Event onChange 全部加 `guard systemBannerEnabled`；新增 `.onChange(of: systemBannerEnabled)`（ON→requestAuthorization+scheduleAll，OFF→`await cancelAll()`）。
    - `yesterdayMissedReminderEnabled` → Main/Calendar 「From yesterday」box 显示闸门（靠 VM getter 短路，下游「非空才渲染」逻辑不变）。
  - **四项隐藏 / 禁用**：`dailySummaryHour` / `quietHoursStart/End` 两端 Settings **删 UI 行**（VM 字段/key/测试全留）；`calendarMirrorOn` / `remindersMirrorOn` 保留 + 保留 "(coming later)" + 追加 `.disabled(true)`。
  - **去 "(coming later)"**：`showCompletedInCounts` / `systemBannerEnabled` / `yesterdayMissedReminderEnabled` 三行不再传 v1 hint（headsUpLeadMinutes 早已是普通 row）。两端删去因隐藏行而变死的助手：macOS 删 `rowWithV1Hint` + `formatHour`；iOS 删 `quietHoursRow` + `formatHour`（`toggleRow`/`pickerRowRawValue` 的 `v1Hint` 能力保留作通用 primitive）。`Settings.v1OnlyHint` 本地化 key 保留（iOS row primitive 仍引用）。
- **变更原因**：占位开关只写 UserDefaults 无消费方、UI 标 "(coming later)"，上线像坏功能。能廉价接通的接通，依赖 EventKit / 定时调度的重活继续延后但隐藏 / 禁用。
- **有无新增本地化 key**：**无**（接通是删 hint、隐藏是删 UI；未引入新文案）。
- **偏离 plan**：无。严格按逐项决策表 + 三项消费契约 + 注入式 bool（同 `headsUpLeadMinutes` 模式）执行。补充说明：macOS Calendar 本就未渲染 yesterday box，gate 仍注入到 VM getter（逻辑一致、与 iOS 对称），实际显隐影响落在 Main（两端）+ iOS Calendar。
- **影响范围**：Phase W2。共享 `MainViewModel.swift` / `PersonalViewModel.swift` / `CompanyViewModel.swift` / `ProjectDetailViewModel.swift` / `CalendarViewModel.swift` + 测试 4 文件；macOS `SettingsView_macOS.swift` / `RootWindow.swift` / `MainView_macOS.swift` / `PersonalView_macOS.swift` / `CompanyView_macOS.swift` / `ProjectDetailView_macOS.swift` / `CalendarView_macOS.swift`；iOS `SettingsSheet_iOS.swift` / `RootTabView.swift` / `MainView_iOS.swift` / `PersonalView_iOS.swift` / `CompanyView_iOS.swift` / `ProjectDetailView_iOS.swift` / `CalendarView_iOS.swift`。**未改 `SettingsViewModel`、未新增 @Model、未改 schema、未新增本地化 key**。
- **验收**：`swift test --package-path Packages/LinoJCore` **149 测试全绿**（141 + 8 W2）；`swift build -Xswiftc -warnings-as-errors` **0 warning**；macOS `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build` **BUILD SUCCEEDED** 0 代码 warning；iOS Simulator（iPhone 17 Pro）`build` **BUILD SUCCEEDED** 0 代码 warning。⚠️ headless 无法验真实通知调度 / UI——**需用户真机验收**：① systemBanner OFF 后建未来 Event 不再排本地通知（pending 为空 / 不增）、ON 恢复；② showCompletedInCounts 切换计数即时变大 / 变小（urgent 列 + kanban 内容不变）；③ yesterdayMissed OFF 后 Main / Calendar 「From yesterday」box 消失、ON 恢复；④ dailySummary / quietHours 行已消失、Calendar/Reminders 镜像置灰不可拨。

### [2026-05-28] W3 施工：ProjectDetail ⋯ 菜单 / Search 精确定位 / Settings About 链接 收口
- **变更内容**：按 W3 plan 三块逐项实现。**不新增 @Model、不改 schema、不引入新 navigation 框架**（仅 TabRouter `pending*` + 各屏 onChange 消费）。
  - **共享（先做）**：
    - `TabRouter` 加 4 个精确定位信号 `pendingProjectID` / `pendingEventDate` / `pendingEventID` / `pendingTodoID`（目标 View 监听消费后清回 nil，与既有 `quickAddEditingProject` 同模式）。
    - `LinoJCore.swift` 加 `public enum LinoJLinks`（`feedbackEmail = "feedback@linoj.app"`、`privacyPolicy = "https://linoj.app/privacy"` ⚠️ 占位待用户替换）。
    - `ProjectDetailViewModel` 加 `deleteProject()`（`context.delete(project)` + `try? save()`，沿用既有 `.nullify` deleteRule，两端复用）。
    - `CalendarViewModel` 加 `focus(on:)`（同时移动 7 天窗口 `weekStart` 让任意日期落入窗口 + 设 `selectedDay`，比既有 `selectDay` 多移窗口）。
    - `SearchViewModel.open` 三分支接 `pending*`：todo → 切 personal/company + `pendingTodoID`；event → 反查 start 切 calendar + `pendingEventDate`（startOfDay）+ `pendingEventID`；project → 切 company + `pendingProjectID`。移除三处 `TODO P3+` 注释换成实现说明。
    - 新增 4 个本地化 key（中英双填 + 重生 lproj + `LJStrings` 成员）：`ProjectDetail.delete` / `ProjectDetail.deleteConfirmTitle` / `ProjectDetail.deleteConfirmMessage` / `ProjectDetail.deleteConfirmConfirm`（Cancel 复用既有 `QuickAdd.cancel`，不重复加）。
    - 测试扩充（+2，149→151）：`SearchViewModelTests` 断言 open 三类设置正确的 `router.pending*`；`ProjectDetailViewModelTests` 加 `deleteProject()`（删除后 project 不在 context、其原 todos 仍存在但 `project == nil`）；`LocalizationTests` 加 4 个新 key zh≠en 断言。
  - **macOS（次做，先验收）**：`ProjectDetailView_macOS` 空 ⋯ Button → `Menu`（Edit project 复用 V5 路径 + Delete project，`.confirmationDialog` 确认后 `deleteProject()` + `dismiss()` pop）；`CompanyView_macOS` 监听 `pendingProjectID` append `navigationPath` + 监听 `pendingTodoID`（重置 filter 为 All 后 `ScrollViewReader.scrollTo`，bubble 加 `.id`）；`CalendarView_macOS` 监听 `pendingEventDate` 调 `vm.focus(on:)`；`PersonalView_macOS` 监听 `pendingTodoID` 滚动（加 router env + `.id`）；`SettingsView_macOS` About 区删 Release notes/Acknowledgements 两行、Feedback/Privacy 接 `@Environment(\.openURL)`（AboutLink 加 `destination` URL）。
  - **iOS（末做，后验收）**：`ProjectDetailView_iOS` Menu 加 Delete 项 + `.confirmationDialog` + pop；`CompanyView_iOS` 同 macOS 监听 `pendingProjectID` / `pendingTodoID`（加 router env + urgent/normal bubble `.id` + 预览注入 TabRouter）；`CalendarView_iOS` 监听 `pendingEventDate`；`PersonalView_iOS` 监听 `pendingTodoID`（加 router env + `.id` + 预览注入 TabRouter）；`SettingsSheet_iOS` About 区删两行、Feedback/Privacy 接 `openURL`。
- **变更原因**：三个零散 no-op 占位（macOS ⋯ 空 Button、Search 只切 tab 不定位、About 链接死点）上线像坏功能；逐项实现或合理砍掉。
- **有无新增本地化 key**：新增 4 个 `ProjectDetail.*`（delete 菜单 + 确认对话框标题/正文/确认按钮）；Cancel 复用 `QuickAdd.cancel`。About 砍掉的 Release notes/Acknowledgements 行未删既有 key（留着无害）。
- **偏离 plan（含可选项决策）**：
  - **高亮（可选项）**：**本期不做** bubble/event 选中闪烁高亮。评估后各 VM 均无承载字段（CalendarViewModel 无 `selectedEventID`、TodoBubble/EventCard 无高亮入参），plan 明确「无承载字段则本期不做高亮、只做滚动/切换定位」。`pendingEventID` 信号已埋好但目标 View 仅消费 `pendingEventDate`（仅定位那天），`pendingEventID` 当场清回 nil 不使用——为将来加高亮预留。
  - **Main 屏不消费 `pendingTodoID`**：`SearchViewModel.open(.todo)` 只路由到 `.personal` / `.company`（todo 找不到时 fallback `.main` 但不设 pendingTodoID），**Search 永远不会把 todo 定位到 Main**；且 Main 左列是两个独立内层 ScrollView（单锚点 scroll 不可靠）。故 Main 不接 `pendingTodoID`（接了也永不触发），plan「Personal/Company/Main 屏接」的 Main 项按实际路由语义合理省略。
  - **砍行**：About 区按 plan 砍掉 Release notes + Acknowledgements，只留 Feedback + Privacy 两行（都真能点开）。
  - ⚠️ **`LinoJLinks.privacyPolicy` 是占位 URL `https://linoj.app/privacy`，待用户替换为真实隐私政策 URL**（上架 App Store 必须有真实隐私政策页）。
- **影响范围**：Phase W3。共享 `TabRouter.swift` / `LinoJCore.swift` / `ProjectDetailViewModel.swift` / `CalendarViewModel.swift` / `SearchViewModel.swift` / `Strings.swift` / `Localizable.xcstrings` + 2 lproj + 测试 3 文件（`SearchViewModelTests` / `ProjectDetailViewModelTests` / `LocalizationTests`）；macOS `ProjectDetailView_macOS.swift` / `CompanyView_macOS.swift` / `CalendarView_macOS.swift` / `PersonalView_macOS.swift` / `SettingsView_macOS.swift`；iOS `ProjectDetailView_iOS.swift` / `CompanyView_iOS.swift` / `CalendarView_iOS.swift` / `PersonalView_iOS.swift` / `SettingsSheet_iOS.swift`。
- **验收**：`swift test --package-path Packages/LinoJCore` **151 测试全绿**（149 + 2 W3）；`swift build -Xswiftc -warnings-as-errors` **0 warning**；macOS `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build` **BUILD SUCCEEDED** 0 代码 warning；iOS Simulator（iPhone 17 Pro）`build` **BUILD SUCCEEDED** 0 代码 warning（已知 `RootWindow.swift:379 reposition()` 既有无关 warning，未新增其它）。⚠️ headless 无法验真实导航 / 邮件 / 浏览器——**需用户真机验收**：① Search 选 project → 直接进该 ProjectDetail（非停在列表）；② Search 选 event → 切 Calendar 且定位到该事件那天（selectedDay 正确）；③ Search 选 todo → 切正确 tab 并滚到该 bubble（被 filter 隐藏则 filter 已重置为 All）；④ 两端 ProjectDetail ⋯ → Edit + Delete；Delete → 确认弹窗 → 删除 + pop 回 Company、其 todos/events 变 standalone 仍存在；⑤ Settings About → Feedback 拉起邮件 compose、Privacy 打开浏览器、Release notes/Acknowledgements 两行已移除。

### [2026-05-28] W1-W3 审查（@reviewer）+ 收尾跟进
- **审查结论**：@reviewer 以外部审计员视角对照 plan 逐项核对 W1/W2/W3 —— **无致命、无重要问题**，仅 3 条建议。CloudKit 约束（不新增 @Model / 关系兜底）、memberCount 重算（create + V5 edit 共用 submit 无旁路）、本地化双轨（xcstrings / 两 lproj / Strings.swift 三处一致）、W2 注入式可测 + SettingsViewModel 零改动、W3 pending* 信号 onChange 消费后清 nil 均验证通过。独立复核 `swift test` 151 全绿、`swift build -Xswiftc -warnings-as-errors` 0 warning。结论「可进入发版准备」。
- **跟进①（已做）**：补 `QuickAddPeoplePickerTests.editProjectResyncsMemberCount` —— V5 edit 路径删减 members 后 submit，断言 memberCount 经 submit 重算（3→2，而非沿用旧值），堵 reviewer 指出的「edit 路径 memberCount 仅间接覆盖」缺口。测试数 151 → **152 全绿**。
- **跟进②（已记）已知边界**：Search 定位到一个**已完成（done）的 todo** 时，目标屏只渲染 open bubbles，`.id(todo.id)` 不存在 → `scrollTo` 静默 no-op（plan W3 已将 todo 定位定义为 best-effort，符合验收，此处仅明确记录该边界）。
- **跟进③（待用户）硬阻塞**：`LinoJLinks.privacyPolicy = "https://linoj.app/privacy"` 是占位 URL，**上架前必须替换为真实可访问的隐私政策页**（App Store 审核会因死链被拒）。

### [2026-05-28] 为真机/桌面反馈扩充修复 Phase（W4 / W5 / W6）

- **背景**：用户在真机/桌面（主用 macOS）实测 **旧 0.9.1 build**（W1/W2/W3/V5 尚未部署到他桌面）后反馈一批「不能操作」问题。主控已逐条定点到代码，本次 @planner 把其中「真实缺口」补成新修复 Phase，延续 W 组编号与施工纪律（先 macOS 验收 → 再 iOS）。**本次规划阶段零源码改动，仅编辑 PROJECT_PLAN.md。**
- **新增 Phase（均无付费能力依赖、延续三条 W 组硬约束）：**
  - **W4 — 事件可操作：编辑 / 删除 / 标记已出席 [全栈]**（最重要，macOS 优先）。定点：`EventCard.swift` 四 variant 全纯展示无交互；全工程无事件编辑路径（`QuickAddViewModel` 只有 `editingProjectID`）；`confirmAttended` 已存在但只接在 yesterday-missed box。**方案**：复用 V5「Project 编辑」模式给 `QuickAddViewModel` 加 `editingEvent` 模式（init 预填 + submit `.event` update 分支 + fetch 不到回退创建）；`TabRouter` 加 `quickAddEditingEvent`（与 `quickAddEditingProject` 同模式）；`CalendarViewModel`/`MainViewModel` 加 `deleteEvent` + `unconfirmAttended`（复用既有 `confirmAttended`）；`EventCard` **保持纯展示不改**，由各屏外层套 `onTapGesture`（打开编辑）+ `contextMenu`（macOS 右键 / iOS 长按：Edit / Mark/Unmark attended / Delete）；attendees 编辑回写复用 W1 选人器。
  - **W5 — ProjectDetail「+ 添加事件」/「+ 添加待办」接通 [全栈]**。定点：两按钮空 stub（`ProjectDetailView_macOS.swift:438`/`:325`、`ProjectDetailView_iOS.swift:420`），且「+ 添加事件」**文案误用 `LJStrings.addTodo`**。**方案**：复用既有 `QuickAddViewModel.prefilledProject`（已支持 `.event` 设 eventProject、`.todo` 设 company+todoProject），接通 = 按钮设 `router.quickAddPrefilledProject = project` + `quickAddDefaultKind = .event/.todo` + `showQuickAdd = true`（三字段已存在，VM/Router 不改）；新增 `Project.addEvent` key 修正误用文案。
  - **W6 — 编辑模式隐藏分段控件（小 UX）[前端]**。定点：编辑态分段控件 `.disabled(vm.isEditing)` 灰显（`QuickAddModal_macOS.swift:160`/`QuickAddSheet_iOS.swift:171`）像坏功能。**方案**：编辑态改为 `if !vm.isEditingAny { Picker(...) }` 直接隐藏整条分段控件，只显示「编辑项目/编辑事件」标题；无新增 key。
- **「事件完成」语义最终决策（W4）**：`attendedConfirmed = true` = 「我参加了」。**「标记已出席」操作仅对已结束事件（`end <= now`）出现**（未来/进行中事件不显示，避免无意义勾选）；已确认的过去事件该项翻转为「取消已出席」（可逆）；编辑/删除两操作不分过去未来恒可用（覆盖绝大多数「操作不了」诉求）。最小合理实现，不上「完成 checkbox / 重复事件」等过度设计。
- **标注为「已实现、仅需重新部署到 macOS 桌面验证」（不新规划）：**
  - **问题②「项目删除 / ⋯」→ 已由 W3 实现**（两端 ⋯ 已接 Edit+Delete）。用户旧版看到空 stub 是 0.9.1 占位，重新部署 W3 build 即生效。
  - **问题④的「成员选人器」→ 已由 W1 实现**（编辑项目表单 Members 节内联选人器）。用户旧版无选人器，重新部署 W1 build 即恢复，不重新规划成员；④ 真正剩余只有 W6 的「编辑模式隐藏分段控件」UX 项。
- **范围纪律**：仅规划①③④三块；EventKit / 提醒细化等仍延后，未顺手扩张。**不新增 @Model、不改 schema**（事件 CRUD 全走既有 `Event` 字段）。
- **影响范围（待 builder 施工）**：共享 `QuickAddViewModel` / `CalendarViewModel` / `MainViewModel` / `TabRouter` / `Strings.swift` + `Localizable.xcstrings` + 两 lproj + 测试；macOS `CalendarView_macOS` / `MainView_macOS` / `QuickAddModal_macOS` / `ProjectDetailView_macOS`；iOS `CalendarView_iOS` / `MainView_iOS` / `QuickAddSheet_iOS` / `ProjectDetailView_iOS`。`EventCard.swift` 不改。
- **新增本地化 key**：W4 8 个（`Event.edit/delete/markAttended/unmarkAttended/deleteConfirmTitle/deleteConfirmMessage/deleteConfirmConfirm` + `QuickAdd.editEventTitle`）；W5 1 个（`Project.addEvent`）；W6 0 个。均走双轨三步。
- **涉及 Phase（新增）**：W4 / W5 / W6，均无付费能力依赖，依赖 v0.9 + V5 + W1。W6 建议在 W4 之后做（消费 W4 的 `isEditingAny`）。

---

## 🚀 v1.0 公开上线剩余清单（新会话从这里接）

**必做（TestFlight / 上架前）**
1. **清 CloudKit Development 重复数据**：icloud.developer.apple.com → container `iCloud.com.linocai.linoj` → Development → 删记录或 Reset Development Environment（都是 seed 垃圾，安全）。seed 竞态已修，清完不再产生新重复。
2. **CloudKit schema deploy Development → Production**：TestFlight/Release 跑 production 环境，不部署测试者同步失败。
3. **iOS Archive → 上传 App Store Connect**：Xcode Organizer ▸ Distribute（自动签名用付费 team 分发证书）。版本已是 0.9.1 / build 2（再传需 +build）。
4. **App Store Connect**：App Privacy 问卷（口径与 PrivacyInfo.xcprivacy 一致：私有 CloudKit 数据不算 collected、SIWA name/email 仅本地 Keychain）、TestFlight 测试信息。export compliance 已设 `ITSAppUsesNonExemptEncryption=false`，免问卷。

**未实现的功能缺口（上线前决定做或砍）—— 已于 2026-05-28 展开为 W 组 Phase（用户确认三块全做），详见上方「v1.0 收口 Phase 列表（W 组）」：**
- Quick Add 的 **Attendees / Members 选人器** → **W1**（从现有 Person 多选 + 允许临时新建；落库走既有关系；memberCount 重算）。
- Settings 标 "(coming later)" 的占位开关 → **W2**（showCompletedInCounts / systemBanner / yesterdayMissedReminder 真接通；dailySummary / quietHours 隐藏；Calendar/Reminders 镜像保留并 disable）。
- ProjectDetail ⋯ 菜单 / Search 精确定位 / Settings About 链接 → **W3**（macOS ⋯ 接 Edit+Delete；Search 三类结果精确定位；About 留 Feedback+Privacy、砍 Release notes/Acks）。

**v1.1+ 已明确延后**（见上方「v1.0 待办」节）：EventKit 真镜像、Widget（out of scope）、macOS 公开分发（Developer ID 公证 / MAS，本轮只做了 dev 签名桌面包）、远程推送服务端（当前是 CloudKit 订阅静默推送，无自建 APNs）。

**视觉小尾巴**：iOS 各屏滚到底有 ~100pt 多余留白（原让位旧浮动 capsule，现原生 tab bar 系统处理安全区，可收）。
