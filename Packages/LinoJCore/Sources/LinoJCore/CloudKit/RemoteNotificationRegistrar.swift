// RemoteNotificationRegistrar.swift
// V2：CloudKit 订阅式静默推送的「注册远程通知」一步。
//
// 关键认知（见 PROJECT_PLAN.md V2 节 + 全局经验记录）：
//   SwiftData 配 `cloudKitDatabase: .private(...)` 后，底层 NSPersistentCloudKitContainer
//   已**自动创建并管理 CKDatabaseSubscription**。所以 V2 **不手搓 CKSubscription**——
//   那会与 SwiftData 内部订阅冲突/重复。V2 真正要做的，只是让静默推送能在后台唤醒 App
//   触发同步拉取，这需要两件事：
//     ① 工程开 Remote notifications 后台模式（iOS pbxproj 的 UIBackgroundModes）；
//     ② App 启动且 iCloud sync 开启时**注册远程通知**（本文件）。
//   注册成功后，CloudKit 在另一设备改动时下发 content-available 静默推送，系统唤醒 App，
//   SwiftData 自动 merge 变更到 ModelContext，`@Query` 自动刷新 UI——无需手动处理 payload。
//
// 与本地通知的关系：
//   V0 的 NotificationService 走 UNUserNotificationCenter 申请**本地通知**授权（Heads-up 横幅）。
//   远程通知注册（registerForRemoteNotifications）是**另一回事**：静默推送不弹横幅、不需要
//   额外授权弹窗。两者都要做、互不替代。
//
// 跨平台：
//   - iOS：`UIApplication.shared.registerForRemoteNotifications()`。
//   - macOS：`NSApplication.shared.registerForRemoteNotifications()`。
//   两个 API 都必须在主线程调用，故整个 enum 标 `@MainActor`。

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 注册远程通知的跨平台抽象。无状态，纯静态入口。
///
/// 调用时机：App 启动且 iCloud sync 开启时（RootWindow / RootTabView 的 `.task`）。
/// 注册本身不弹授权弹窗（静默推送无需用户授权）；若系统返回 device token / 失败，
/// 由系统 + SwiftData 内部处理，本 App 不持有 token。
@MainActor
public enum RemoteNotificationRegistrar {

    /// 向系统注册远程通知，使本设备能接收 CloudKit 下发的 content-available 静默推送。
    ///
    /// 幂等：系统对重复 register 调用是无害的（系统去重 / 刷新 token）。
    /// 不抛错；底层注册结果（成功 token / 失败）由系统异步回调，CloudKit + SwiftData
    /// 自行消费，业务层无需处理。
    public static func register() {
        #if canImport(UIKit) && os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #elseif canImport(AppKit)
        NSApplication.shared.registerForRemoteNotifications()
        #endif
    }
}
