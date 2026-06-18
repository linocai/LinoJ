// TabRouter.swift
// 顶层 Tab 路由 + 各类全局 modal/sheet 的开关状态。
//
// 计划 P3.1 验收：⌘1..⌘4 / iOS 底部 capsule 都改写 `current`；⌘K / ⌘N / ⌘,
// 把对应 show* flag 翻 true（实际 sheet 绑定在后续 P3.6 / P3.7 / P3.8 接通；
// 本 Phase 仅状态生效，UI 行为 noop）。
//
// 标 `@MainActor` 因为这个状态会被 SwiftUI View 直接读写，所有访问点都在主线程；
// 也方便 Swift 6 strict concurrency 模式下从 View Commands 等闭包内自由 mutate。
// `@Observable` 让属性自动产生订阅，View 与 Commands 通过 `@Environment` 拿到同一引用。

import Foundation
import Observation

/// LinoJ 顶层 Tab 路由 + 全局 modal/sheet 状态容器。
///
/// 在 App `@main` 处实例化一次，通过 `.environment(router)` 注入给 RootView，
/// 之后 RootView / Commands / Floating buttons 都从环境取同一引用。
@Observable
@MainActor
public final class TabRouter {

    /// 当前激活的 Tab。默认 `.main`。
    /// macOS 顶部 segmented Picker / iOS 底部 capsule 都 bind 到这里。
    public var current: AppTab = .main

    /// Search palette 是否展示。P3.7 接通 sheet/modal；当前 ⌘K 只翻这个 flag。
    public var showSearch: Bool = false

    /// Quick Add 是否展示。P3.6 起：sheet 真接通，⌘N / ⌘⇧T / ⌘⇧E / ⌘⇧P / iOS `+` /
    /// Calendar `+ New event` 都把这个翻 true，同时设 `quickAddDefaultKind` 决定预选项。
    public var showQuickAdd: Bool = false

    /// 打开 Quick Add 时初始 segmented control 选项。
    /// ⌘N / iOS `+` 默认 `.todo`；⌘⇧E / Calendar `+ New event` 设 `.event`；⌘⇧P 设 `.project`。
    /// Quick Add sheet 在 onAppear 时把这个值喂给新 VM 的 `defaultKind`。
    public var quickAddDefaultKind: QuickAddViewModel.Kind = .todo

    /// v1.3 R2/R3：打开 Quick Add 时若非 nil，覆盖 VM 的初始 Todo scope。
    /// Personal 屏「＋新建个人待办」设 `.personal`、Company 屏「＋新建公司事项」设 `.company`，
    /// 让从子页发起的新建待办默认落在当前页的 scope。nil 时回退 Settings 的 `defaultTodoScope`。
    /// sheet onDisappear 清回 nil（与 quickAddDefaultKind 同模式）。
    public var quickAddDefaultScope: Scope? = nil

    /// 打开 Quick Add 时可选的预填 Project。
    /// 用 `Project?` 引用而非 ID —— router 自身已 `@MainActor`，与 @Model 同线程，无需跨 actor。
    /// 当前 P3.6 没有任何入口设置它（Project detail 的 `+ Add todo` 不在范围内），保留接口给未来。
    public var quickAddPrefilledProject: Project? = nil

    /// V5：打开 Quick Add 时若非 nil，sheet 以 **Project edit 模式** 打开（预填该 project 字段，
    /// submit 走 update 而非 insert）。与 quickAddPrefilledProject 同模式：入口（ProjectDetail 的
    /// "Edit project" / iOS `⋯`）打开 sheet 前设置 + `showQuickAdd = true`，sheet onDisappear 清回 nil。
    public var quickAddEditingProject: Project? = nil

    /// W4：打开 Quick Add 时若非 nil，sheet 以 **Event edit 模式** 打开（预填该 event 字段，
    /// submit 走 update 而非 insert）。与 quickAddEditingProject 完全同模式：事件卡点击 / contextMenu
    /// 的 Edit → 设置该字段 + `showQuickAdd = true`，sheet onDisappear 清回 nil。
    /// 与 quickAddEditingProject 互斥（同一时刻只设一个）。
    public var quickAddEditingEvent: Event? = nil

    /// Settings 是否展示。P3.8 接通；当前 ⌘, 只翻这个 flag。
    public var showSettings: Bool = false

    // MARK: - W3 精确定位信号（Search 结果 → 跨视图定位）

    /// W3：Search 选中 project 后写入目标 project.id。CompanyView 监听非 nil 时把它
    /// append 进 NavigationStack path（push ProjectDetail），消费后清回 nil。
    /// 与 `quickAddEditingProject` 同模式：router 设值 → 目标 View 监听消费后清回 nil。
    public var pendingProjectID: UUID? = nil

    /// W3：Search 选中 event 后写入该 event 所在那天的 startOfDay。CalendarView 监听非 nil 时
    /// 把 CalendarViewModel 定位到那天（设 selectedDay / 移动窗口），消费后清回 nil。
    public var pendingEventDate: Date? = nil

    /// W3：Search 选中 event 后写入 event.id，预留给「高亮具体事件卡」。
    /// 当前各 CalendarViewModel 无承载字段，本期不做高亮；目标 View 仅消费 pendingEventDate。
    public var pendingEventID: UUID? = nil

    /// W3：Search 选中 todo 后写入 todo.id。目标屏（Personal/Company/Main）用 ScrollViewReader
    /// 监听非 nil 时滚动到该 bubble（被 filter 隐藏则先重置 filter），消费后清回 nil。
    public var pendingTodoID: UUID? = nil

    public init() {}
}
