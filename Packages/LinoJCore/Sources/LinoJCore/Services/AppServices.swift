// AppServices.swift
// 一个轻量的 @Observable 容器，把 P4 引入的几个 service 实例（HeadsUpService /
// YesterdayMissedService）打包成单个 environment 注入对象。
//
// 为什么需要这个：
//   - SwiftUI `.environment(...)` 是按类型注入；同一个 modifier 只能注入一个 @Observable 类型实例。
//   - 我们想从 RootWindow / RootTabView 在 modelContext 拿到后才初始化 services，
//     但 environment 类型不能是 Optional<T>（接收方 @Environment(T.self) 拿不到 nil）。
//   - 用一个 wrapper 持有可选 service：wrapper 自身永远存在，子 View 通过 wrapper 取出 service。
//     wrapper 内部字段变化时，因为它是 @Observable，子 View 会自动收到刷新。
//
// 子 View 用法：
//   @Environment(AppServices.self) private var services
//   ...
//   if let svc = services.headsUp { ... }
//
// 注意：AppServices 不持有 SettingsViewModel —— Settings 自己 own VM 实例（每次 sheet 打开
// 重新创建即可），与 service 的「全局 live」语义不同。

import Foundation
import Observation

@Observable
@MainActor
public final class AppServices {

    /// HeadsUp service。RootView 在 `.task` 中初始化并 start()。
    public var headsUp: HeadsUpService?

    /// Yesterday missed service。同上时机初始化。
    public var yesterdayMissed: YesterdayMissedService?

    /// V1：CloudKit 同步状态 monitor。App 启动时按 `cloudSyncEnabled` 创建并 `start()`，
    /// Settings 取出注入到自己的 SettingsViewModel 驱动 Last-synced pill。纯本地 / 测试时 nil。
    public var cloudSyncMonitor: CloudSyncMonitor?

    /// V3：Sign in with Apple 登录态服务。App 启动 `.task` 创建并 `restoreState()` +
    /// `refreshCredentialState()`，Settings Account 行据此显示 Sign in 按钮 / 已登录身份。
    /// AppServices 长生命周期持有它（不随 Settings sheet 开关重建），保证登录态全程稳定。
    public var appleSignIn: AppleSignInService?

    public init() {
        self.headsUp = nil
        self.yesterdayMissed = nil
        self.cloudSyncMonitor = nil
        self.appleSignIn = nil
    }
}
