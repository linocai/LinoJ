// SettingsPersistenceTests.swift
// Plan P3.8 验收：set 值 → 重建实例 → 读到相同值。
//
// 测试隔离：每个测试用独立的 `UserDefaults(suiteName: "linoj.test.<uuid>")`，
// teardown 移除 persistent domain，避免污染开发机或测试间互相干扰。
//
// 三条必测断言（按 builder prompt）：
//  1. set headsUpLeadMinutes=15 → 重建 vm → 仍为 15。
//  2. set defaultTab=.calendar → 重建 vm → 仍为 .calendar。
//  3. iCloudSyncOn 默认值 == true（plan §技术选型 8 + plan P3.8 验收）。
//
// 额外 sanity：
//  4. 多字段联合（scope + bool + enum）一次往返。
//  5. 新建 vm（空 defaults）所有默认值与 plan 一致。

import Foundation
import Testing
@testable import LinoJCore

@Suite("SettingsViewModel — persistence & defaults")
@MainActor
struct SettingsPersistenceTests {

    /// 每个测试用独立 suite，避免互相污染 + 不动开发机 `.standard`。
    /// teardown 由 `defer` 在每个 test 顶部安排。
    private static func makeIsolatedDefaults() -> (UserDefaults, suiteName: String) {
        let suite = "linoj.test.\(UUID().uuidString)"
        // UserDefaults(suiteName:) 在合法名下不会返回 nil；强解。
        let d = UserDefaults(suiteName: suite)!
        return (d, suite)
    }

    private static func tearDown(suiteName: String) {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    // MARK: - 1. headsUpLeadMinutes round-trip

    @Test("set headsUpLeadMinutes=15 then rebuild reads 15")
    func headsUpLeadMinutesRoundTrip() {
        let (defaults, suite) = Self.makeIsolatedDefaults()
        defer { Self.tearDown(suiteName: suite) }

        let vm1 = SettingsViewModel(defaults: defaults)
        vm1.headsUpLeadMinutes = 15

        // 重建一个新 VM，共享同一 defaults —— 模拟「App 重启」。
        let vm2 = SettingsViewModel(defaults: defaults)
        #expect(vm2.headsUpLeadMinutes == 15)
    }

    // MARK: - 2. defaultTab round-trip

    @Test("set defaultTab=.calendar then rebuild reads .calendar")
    func defaultTabRoundTrip() {
        let (defaults, suite) = Self.makeIsolatedDefaults()
        defer { Self.tearDown(suiteName: suite) }

        let vm1 = SettingsViewModel(defaults: defaults)
        vm1.defaultTab = .calendar

        let vm2 = SettingsViewModel(defaults: defaults)
        #expect(vm2.defaultTab == .calendar)
    }

    // MARK: - 3. iCloudSyncOn default == true

    @Test("iCloudSyncOn defaults to true on a fresh defaults store")
    func iCloudSyncOnDefaultsTrue() {
        let (defaults, suite) = Self.makeIsolatedDefaults()
        defer { Self.tearDown(suiteName: suite) }

        let vm = SettingsViewModel(defaults: defaults)
        #expect(vm.iCloudSyncOn == true)
    }

    // MARK: - 4. 多字段联合 round-trip

    @Test("multiple fields persist together (scope + bool + enum + int)")
    func multiFieldRoundTrip() {
        let (defaults, suite) = Self.makeIsolatedDefaults()
        defer { Self.tearDown(suiteName: suite) }

        let vm1 = SettingsViewModel(defaults: defaults)
        vm1.defaultTodoScope = .personal
        vm1.showCompletedInCounts = true
        vm1.startWeekOn = .sunday
        vm1.dailySummaryHour = 6
        vm1.calendarMirrorOn = true

        let vm2 = SettingsViewModel(defaults: defaults)
        #expect(vm2.defaultTodoScope == .personal)
        #expect(vm2.showCompletedInCounts == true)
        #expect(vm2.startWeekOn == .sunday)
        #expect(vm2.dailySummaryHour == 6)
        #expect(vm2.calendarMirrorOn == true)
    }

    // MARK: - 5. 全部默认值（plan P3.8 关键接口契约）

    @Test("fresh defaults yields plan-specified default values")
    func planDefaultsOnFreshStore() {
        let (defaults, suite) = Self.makeIsolatedDefaults()
        defer { Self.tearDown(suiteName: suite) }

        let vm = SettingsViewModel(defaults: defaults)

        #expect(vm.defaultTab == .main)
        #expect(vm.defaultTodoScope == .company)
        #expect(vm.showCompletedInCounts == false)
        #expect(vm.startWeekOn == .monday)
        #expect(vm.headsUpLeadMinutes == 30)
        #expect(vm.systemBannerEnabled == true)
        #expect(vm.yesterdayMissedReminderEnabled == true)
        #expect(vm.dailySummaryHour == 8)
        #expect(vm.quietHoursStart == 22)
        #expect(vm.quietHoursEnd == 7)
        #expect(vm.iCloudSyncOn == true)
        #expect(vm.calendarMirrorOn == false)
        #expect(vm.remindersMirrorOn == false)
        #expect(vm.accountEmail == "you@example.com")
        // V1：lastSyncedText 改为 LocalizedStringResource，无 monitor 注入时按 iCloudSyncOn
        // 静态回退（ON → "Synced just now"）。解析为英文比对（locale 中立断言）。
        #expect(Self.resolveEn(vm.lastSyncedText) == "Synced just now")
    }

    @Test("lastSyncedText falls back to Local only when iCloud sync off and no monitor")
    func lastSyncedTextLocalOnlyFallback() {
        let (defaults, suite) = Self.makeIsolatedDefaults()
        defer { Self.tearDown(suiteName: suite) }

        let vm = SettingsViewModel(defaults: defaults)
        vm.iCloudSyncOn = false
        #expect(Self.resolveEn(vm.lastSyncedText) == "Local only")
        #expect(vm.syncMonitor == nil)
    }

    /// 把 LocalizedStringResource 在 en locale 下解析成字符串（复制后改 locale 再 String(localized:)）。
    private static func resolveEn(_ resource: LocalizedStringResource) -> String {
        var copy = resource
        copy.locale = Locale(identifier: "en")
        return String(localized: copy)
    }
}
