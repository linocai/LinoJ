// RemoteNotificationRegistrarTests.swift
// V2：验证 RemoteNotificationRegistrar.register() 可被调用且不崩。
//
// 说明：register() 在 swift test 进程（headless，无完整 App lifecycle）里调用 macOS 的
// `NSApplication.shared.registerForRemoteNotifications()`——该调用在无 APNs 环境下是 noop /
// 静默失败（系统异步回调 didFailToRegister），不会抛错、不会 crash，符合「注册结果由系统
// 异步处理」的设计。测试目标只是确认 ① 类型/入口存在；② 在测试上下文调用安全不崩。
//
// 真实「收到静默推送 → SwiftData 自动同步 → @Query 刷新」闭环靠两端真机（同一 iCloud）验收，
// 单元测试不连真 CloudKit / APNs。

import Foundation
import Testing
@testable import LinoJCore

@Suite("V2 RemoteNotificationRegistrar")
@MainActor
struct RemoteNotificationRegistrarTests {

    @Test("register() 在测试上下文调用不崩")
    func registerDoesNotCrash() {
        // headless 测试进程里调用：macOS 走 NSApplication.shared.registerForRemoteNotifications()，
        // 无 APNs 环境下为 noop / 异步失败回调，不抛错也不 crash。
        // 单独跑该调用即视为通过——能编过 + 不崩说明跨平台守卫与 @MainActor 隔离正确。
        RemoteNotificationRegistrar.register()

        // 显式 #expect 让 Suite 计入一条断言：调用返回后流程仍然存活。
        #expect(Bool(true))
    }
}
