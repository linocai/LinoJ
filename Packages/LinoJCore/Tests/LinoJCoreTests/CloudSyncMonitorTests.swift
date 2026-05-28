// CloudSyncMonitorTests.swift
// V1：验证 CloudSyncMonitor 的状态机 → 本地化文案映射，以及纯本地模式的静默行为。
//
// 不连真实 CloudKit：测试只构造 monitor + 注入 status（`_setStatusForTesting`），验证
// `status` 与 `lastSyncedText` 的映射。真实 NSPersistentCloudKitContainer 通知链路靠真机验收。

import Foundation
import Testing
@testable import LinoJCore

@Suite("V1 CloudSyncMonitor 状态机与文案")
@MainActor
struct CloudSyncMonitorTests {

    /// 把 LocalizedStringResource 在 en locale 解析为字符串，便于断言。
    /// 与 LocalizationTests.resolve 同模式：复制后改 `locale` 再 `String(localized:)`。
    private func en(_ resource: LocalizedStringResource) -> String {
        var copy = resource
        copy.locale = Locale(identifier: "en")
        return String(localized: copy)
    }

    @Test("纯本地模式：初始 idle，lastSyncedText = 'Local only'，start() 不订阅也不崩")
    func localOnlyModeStaysIdle() {
        let monitor = CloudSyncMonitor(cloudSyncEnabled: false)
        #expect(monitor.status == .idle)
        #expect(en(monitor.lastSyncedText) == "Local only")

        // start() 在纯本地模式直接返回（不订阅通知），status 仍 idle。
        monitor.start()
        #expect(monitor.status == .idle)
        #expect(en(monitor.lastSyncedText) == "Local only")
    }

    @Test("CloudKit 模式初值：idle 时乐观显示 'Synced just now'")
    func cloudModeIdleOptimistic() {
        let monitor = CloudSyncMonitor(cloudSyncEnabled: true)
        #expect(monitor.status == .idle)
        #expect(en(monitor.lastSyncedText) == "Synced just now")
    }

    @Test("状态流转：idle → syncing → synced → error 文案映射正确")
    func statusFlowMapsToText() {
        let monitor = CloudSyncMonitor(cloudSyncEnabled: true)

        monitor._setStatusForTesting(.syncing)
        #expect(monitor.status == .syncing)
        #expect(en(monitor.lastSyncedText) == "Syncing…")

        let now = Date.now
        monitor._setStatusForTesting(.synced(now))
        #expect(monitor.status == .synced(now))
        #expect(en(monitor.lastSyncedText) == "Synced just now")

        monitor._setStatusForTesting(.error("network down"))
        #expect(monitor.status == .error("network down"))
        #expect(en(monitor.lastSyncedText) == "Sync paused")
    }

    @Test("纯本地模式即使被注入非 idle 状态，文案仍固定 'Local only'")
    func localOnlyIgnoresInjectedStatus() {
        let monitor = CloudSyncMonitor(cloudSyncEnabled: false)
        monitor._setStatusForTesting(.syncing)
        // cloudSyncEnabled == false 时 lastSyncedText 短路返回 Local only，不看 status。
        #expect(en(monitor.lastSyncedText) == "Local only")
    }

    @Test("start() 幂等：cloud 模式重复调用不崩、不改变当前 status")
    func startIsIdempotent() {
        let monitor = CloudSyncMonitor(cloudSyncEnabled: true)
        monitor._setStatusForTesting(.synced(Date.now))
        monitor.start()
        monitor.start()
        // start() 只订阅通知，不主动改 status（无通知时维持注入值）。
        if case .synced = monitor.status {} else {
            Issue.record("start() 不应重置已注入的 .synced 状态")
        }
        monitor.stop()
    }

    @Test("cloud 模式 start() 订阅通知、stop() 注销，幂等可重入不崩")
    func cloudModeStartStopLifecycle() {
        let monitor = CloudSyncMonitor(cloudSyncEnabled: true)
        // 首次 start 注册 CoreData 通知 observer。
        monitor.start()
        // 再 start 应先注销旧 observer 再注册（幂等）。
        monitor.start()
        // stop 注销 observer。
        monitor.stop()
        // stop 后再 stop 不应崩（token 已 nil）。
        monitor.stop()
        // 生命周期操作不改变初始 idle 乐观文案。
        #expect(en(monitor.lastSyncedText) == "Synced just now")
    }

    @Test("SettingsViewModel.attachSyncMonitor 后 lastSyncedText 跟随 monitor")
    func settingsAttachReflectsMonitor() {
        let suite = "linoj.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let vm = SettingsViewModel(defaults: defaults)
        let monitor = CloudSyncMonitor(cloudSyncEnabled: true)
        vm.attachSyncMonitor(monitor)

        monitor._setStatusForTesting(.syncing)
        #expect(en(vm.lastSyncedText) == "Syncing…")

        monitor._setStatusForTesting(.error("boom"))
        #expect(en(vm.lastSyncedText) == "Sync paused")
    }
}
