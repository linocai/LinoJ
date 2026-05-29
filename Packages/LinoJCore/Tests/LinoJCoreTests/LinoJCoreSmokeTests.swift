// LinoJCoreSmokeTests.swift
// 最小 smoke test：证明 test target 链接成功 + 版本号符合预期。
//
// 使用 Swift Testing（@Test macro，Swift 6 / Xcode 16+ 默认随附）。

import Testing
@testable import LinoJCore

@Suite("LinoJCore smoke")
struct LinoJCoreSmokeTests {
    @Test("version is the v1.0 release identifier")
    func versionMatchesBaseline() {
        #expect(LinoJCore.version == "1.0")
    }

    @Test("AppServices starts with all services nil and accepts injected instances")
    @MainActor
    func appServicesContainer() {
        let services = AppServices()
        #expect(services.headsUp == nil)
        #expect(services.yesterdayMissed == nil)
        #expect(services.cloudSyncMonitor == nil)
        #expect(services.appleSignIn == nil)

        // 注入后 wrapper 字段反映实例（驱动子 View 刷新的路径）。
        let monitor = CloudSyncMonitor(cloudSyncEnabled: false)
        let auth = AppleSignInService(store: InMemoryIdentityStore())
        services.cloudSyncMonitor = monitor
        services.appleSignIn = auth
        #expect(services.cloudSyncMonitor != nil)
        #expect(services.appleSignIn != nil)
    }
}
