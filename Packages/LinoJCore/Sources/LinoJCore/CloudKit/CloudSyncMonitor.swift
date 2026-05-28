// CloudSyncMonitor.swift
// V1：监听 SwiftData 底层 `NSPersistentCloudKitContainer` 的同步事件，把状态暴露给 Settings
// 的 Last-synced status pill。
//
// 实现说明：
//   SwiftData 不直接暴露 CloudKit 同步事件，但其底层用 `NSPersistentCloudKitContainer`，后者会
//   广播 `NSPersistentCloudKitContainer.eventChangedNotification`（CoreData framework）。我们订阅
//   该通知，从 userInfo 取出 `NSPersistentCloudKitContainer.Event` 解析 import/export/setup 三类
//   事件的开始 / 结束 / 错误，映射为 `Status`：
//     - 事件 `endDate == nil`（进行中） → `.syncing`
//     - 事件结束且 `error == nil`        → `.synced(endDate)`
//     - 事件结束且 `error != nil`        → `.error(描述)`
//   `lastSyncedText` 据此产出本地化文案，驱动 Settings pill。
//
//   注意：该通知仅当容器真正以 CloudKit (`.private`) 模式启动时才会发出。inMemory / `.none`（纯本地
//   或 iCloud OFF）模式下永远不会触发，`status` 维持初始 `.idle`，`lastSyncedText` 显示
//   "Local only · 仅本地"。`init(cloudSyncEnabled:)` 让 Settings 在 iCloud OFF 时直接拿到
//   一个静态的 "本地" 文案，不必等通知。
//
// 跨平台 / 并发：`@MainActor @Observable`，通知回调在 `start()` 里用 main queue 接收，状态变更
// 始终在主线程，配合 SwiftUI 订阅刷新。

import Foundation
import Observation

#if canImport(CoreData)
import CoreData
#endif

@Observable
@MainActor
public final class CloudSyncMonitor {

    /// 同步状态机（plan V1 契约）。
    public enum Status: Equatable, Sendable {
        /// 未发生同步事件（刚启动 / 纯本地模式）。
        case idle
        /// CloudKit import / export 正在进行。
        case syncing
        /// 上一次同步成功，附完成时间。
        case synced(Date)
        /// 同步出错，附错误描述。
        case error(String)
    }

    /// 当前同步状态，驱动 Settings Last-synced pill。
    public private(set) var status: Status = .idle

    /// 该 monitor 对应的容器是否以 CloudKit 模式启动。
    /// `false`（iCloud OFF / 纯本地）时 `lastSyncedText` 固定 "Local only"，不监听任何通知。
    private let cloudSyncEnabled: Bool

    #if canImport(CoreData)
    /// 持有通知 observer token，便于注销。
    private var observerToken: (any NSObjectProtocol)?
    #endif

    /// - Parameter cloudSyncEnabled: 容器是否以 CloudKit `.private` 模式启动。App 启动时把
    ///   `makeContainer` 用的同一个 `cloudSyncEnabled` 传进来。`false` 时 monitor 静默（纯本地）。
    public init(cloudSyncEnabled: Bool) {
        self.cloudSyncEnabled = cloudSyncEnabled
    }

    /// 开始监听 `NSPersistentCloudKitContainer.eventChangedNotification`。
    /// 幂等：重复调用先注销旧 observer。纯本地模式（`cloudSyncEnabled == false`）直接返回，不订阅。
    public func start() {
        guard cloudSyncEnabled else {
            status = .idle
            return
        }

        #if canImport(CoreData)
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }

        observerToken = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // 在 nonisolated 上下文先把 Notification 解析成 Sendable 的 `Status`（不跨 actor 传
            // 非 Sendable 的 Notification / Event），再投递到 main queue 上 MainActor 更新状态。
            guard let newStatus = Self.parseStatus(from: note) else { return }
            MainActor.assumeIsolated {
                self?.status = newStatus
            }
        }
        #endif
    }

    /// 测试用（`internal`，仅 `@testable import` 可见）：直接注入状态以验证 `lastSyncedText`
    /// 映射。生产代码只通过通知回调改 status（`private(set)`），这里给单测一个可控注入口。
    func _setStatusForTesting(_ newStatus: Status) {
        status = newStatus
    }

    /// 停止监听并注销 observer。
    public func stop() {
        #if canImport(CoreData)
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
        #endif
    }

    #if canImport(CoreData)
    /// 解析单条 CloudKit 事件通知为 Sendable 的 `Status`。
    /// `nonisolated static`：在通知投递线程（main queue）上同步解析，产出值类型 `Status`，
    /// 不把非 Sendable 的 `Notification` / `Event` 带过 actor 边界。
    nonisolated private static func parseStatus(from note: Notification) -> Status? {
        guard
            let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
        else { return nil }

        if event.endDate == nil {
            // 事件进行中。
            return .syncing
        } else if let error = event.error {
            return .error(error.localizedDescription)
        } else {
            return .synced(event.endDate ?? Date.now)
        }
    }
    #endif

    /// 本地化的 Last-synced 文案（plan V1 契约）。
    /// - `.idle`           → cloud 模式 "Synced just now"（乐观初值，避免一启动就空白）/ 本地模式 "Local only"
    /// - `.syncing`        → "Syncing…"
    /// - `.synced`         → "Synced just now"
    /// - `.error`          → "Sync paused"
    public var lastSyncedText: LocalizedStringResource {
        guard cloudSyncEnabled else {
            return LJStrings.settingsSyncLocalOnly
        }
        switch status {
        case .idle:
            return LJStrings.settingsSyncedJustNow
        case .syncing:
            return LJStrings.settingsSyncing
        case .synced:
            return LJStrings.settingsSyncedJustNow
        case .error:
            return LJStrings.settingsSyncPaused
        }
    }

    // 不实现 deinit 注销：observer 闭包用 `[weak self]`，monitor 释放后回调内 `self?` 为 nil
    // 不再 mutate，无强引用环；token observer 在 monitor 与其拥有者（App / SettingsViewModel）
    // 生命周期一致（App 全程持有），实践中不需要在 deinit 里 nonisolated 地碰 MainActor 属性。
    // 需要主动停止时调用 `stop()`（MainActor 上下文）。
}
