// SettingsViewModel.swift
// Settings 屏幕背后的 ViewModel —— plan P3.8 唯一实体。
//
// 设计要点：
//   - 单 VM 同时承载 General / Notifications / Sync 三大段所有字段（plus About 显示用的常量）。
//   - 所有字段持久化到 `UserDefaults`，key prefix 统一为 `"linoj.settings."`。
//   - 每个 setter（用 didSet）在变更后自动调 `persist()`，无需调用方手动同步。
//   - init 时从 UserDefaults 读已存值；缺失字段 fallback 到 plan 指定的默认值。
//   - 测试隔离：init 接受 `defaults: UserDefaults = .standard` 参数，
//     测试可以传入 `UserDefaults(suiteName: "linoj.test.<uuid>")` 避免污染开发机持久存储。
//
// Sync 段是 v0.9 UI 占位（plan §4 + 免费证书约束）：
//   - iCloudSyncOn 默认 ON，但底层不接 CloudKit；
//   - accountEmail / lastSyncedText 是只读占位字符串，无 setter；
//   - calendarMirrorOn / remindersMirrorOn 默认 OFF，写入 UserDefaults 但无任何运行时副作用。

import Foundation
import Observation

/// 一周第一天的选项，用于 Calendar 周视图起点。
public enum Weekday: String, Codable, CaseIterable, Sendable {
    case sunday
    case monday
}

@Observable
@MainActor
public final class SettingsViewModel {

    // MARK: - UserDefaults 键名

    /// 所有 settings key 统一前缀，避免与未来其它子模块的 UserDefaults 命名冲突。
    private enum Key {
        static let prefix = "linoj.settings."

        // General
        static let defaultTab               = prefix + "defaultTab"
        static let defaultTodoScope         = prefix + "defaultTodoScope"
        static let showCompletedInCounts    = prefix + "showCompletedInCounts"
        static let startWeekOn              = prefix + "startWeekOn"

        // Notifications
        static let headsUpLeadMinutes       = prefix + "headsUpLeadMinutes"
        static let systemBannerEnabled      = prefix + "systemBannerEnabled"
        static let yesterdayMissedReminder  = prefix + "yesterdayMissedReminderEnabled"
        static let dailySummaryHour         = prefix + "dailySummaryHour"
        static let quietHoursStart          = prefix + "quietHoursStart"
        static let quietHoursEnd            = prefix + "quietHoursEnd"

        // Sync (UI placeholder)
        static let iCloudSyncOn             = prefix + "iCloudSyncOn"
        static let calendarMirrorOn         = prefix + "calendarMirrorOn"
        static let remindersMirrorOn        = prefix + "remindersMirrorOn"
    }

    // MARK: - 默认值（plan P3.8）

    /// plan「关键接口契约」中 SettingsViewModel 的默认值。
    /// 抽到内部常量便于 init 与重置逻辑共用。
    private enum Defaults {
        static let defaultTab: AppTab = .main
        static let defaultTodoScope: Scope = .company
        static let showCompletedInCounts: Bool = false
        static let startWeekOn: Weekday = .monday
        static let headsUpLeadMinutes: Int = 30
        static let systemBannerEnabled: Bool = true
        static let yesterdayMissedReminderEnabled: Bool = true
        static let dailySummaryHour: Int = 8       // 8 AM
        static let quietHoursStart: Int = 22       // 10 PM
        static let quietHoursEnd: Int = 7          // 7 AM
        static let iCloudSyncOn: Bool = true       // ON by design（plan §技术选型 8）
        static let calendarMirrorOn: Bool = false
        static let remindersMirrorOn: Bool = false
    }

    // MARK: - 后端存储

    /// 注入式 UserDefaults，方便测试用 suite 隔离。生产代码传 `.standard`。
    private let defaults: UserDefaults

    /// init 期间防止 didSet 触发 persist 写回（造成无谓的写覆盖）。
    private var isLoading: Bool = true

    // MARK: - General

    public var defaultTab: AppTab {
        didSet { persistIfReady() }
    }

    public var defaultTodoScope: Scope {
        didSet { persistIfReady() }
    }

    public var showCompletedInCounts: Bool {
        didSet { persistIfReady() }
    }

    public var startWeekOn: Weekday {
        didSet { persistIfReady() }
    }

    // MARK: - Notifications

    /// 取值约束在 5 / 10 / 15 / 30（plan Stepper 步进值）。VM 不强约束，由 UI Stepper 保证。
    public var headsUpLeadMinutes: Int {
        didSet { persistIfReady() }
    }

    public var systemBannerEnabled: Bool {
        didSet { persistIfReady() }
    }

    public var yesterdayMissedReminderEnabled: Bool {
        didSet { persistIfReady() }
    }

    /// 0..23 小时（24 制）。DatePicker 的 hour 取自 `Calendar.current.component(.hour, from:)`。
    public var dailySummaryHour: Int {
        didSet { persistIfReady() }
    }

    public var quietHoursStart: Int {
        didSet { persistIfReady() }
    }

    public var quietHoursEnd: Int {
        didSet { persistIfReady() }
    }

    // MARK: - Sync (UI placeholder only)

    public var iCloudSyncOn: Bool {
        didSet { persistIfReady() }
    }

    /// 占位 email；v0.9 没有真正的账号系统。
    /// V3 起 Account 行改由 `AppleSignInService.state` 驱动真实身份；此字段不再被 Settings UI 消费，
    /// 保留作向后兼容常量（SettingsPersistenceTests 仍断言其默认值）。
    public let accountEmail: String = "you@example.com"

    public var calendarMirrorOn: Bool {
        didSet { persistIfReady() }
    }

    public var remindersMirrorOn: Bool {
        didSet { persistIfReady() }
    }

    /// V1：CloudKit 同步状态 monitor。由 App 启动时注入（`attachSyncMonitor(_:)`），
    /// 未注入时为 nil（测试 / preview / 容器纯本地构造）。`lastSyncedText` 据此动态产出。
    public private(set) var syncMonitor: CloudSyncMonitor?

    /// V1：Last-synced 文案。接 `syncMonitor` 实时驱动（"Synced just now" / "Syncing…" /
    /// "Sync paused" / "Local only"）；monitor 未注入时回退为根据 `iCloudSyncOn` 的静态状态
    /// （ON → "Synced just now"、OFF → "Local only"），移除 v0.9 的 "· placeholder" 后缀。
    public var lastSyncedText: LocalizedStringResource {
        if let syncMonitor {
            return syncMonitor.lastSyncedText
        }
        return iCloudSyncOn ? LJStrings.settingsSyncedJustNow : LJStrings.settingsSyncLocalOnly
    }

    // MARK: - Init

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // 从 UserDefaults 读取已存值；缺失或解析失败时回 Defaults。

        // AppTab.rawValue 是 String。
        if let raw = defaults.string(forKey: Key.defaultTab),
           let tab = AppTab(rawValue: raw) {
            self.defaultTab = tab
        } else {
            self.defaultTab = Defaults.defaultTab
        }

        if let raw = defaults.string(forKey: Key.defaultTodoScope),
           let scope = Scope(rawValue: raw) {
            self.defaultTodoScope = scope
        } else {
            self.defaultTodoScope = Defaults.defaultTodoScope
        }

        // bool(forKey:) 在缺失时返回 false，会与 Defaults 冲突；
        // 用 object(forKey:) 检测「键是否存在」来区分「未设置」与「显式 false」。
        if defaults.object(forKey: Key.showCompletedInCounts) != nil {
            self.showCompletedInCounts = defaults.bool(forKey: Key.showCompletedInCounts)
        } else {
            self.showCompletedInCounts = Defaults.showCompletedInCounts
        }

        if let raw = defaults.string(forKey: Key.startWeekOn),
           let wd = Weekday(rawValue: raw) {
            self.startWeekOn = wd
        } else {
            self.startWeekOn = Defaults.startWeekOn
        }

        if defaults.object(forKey: Key.headsUpLeadMinutes) != nil {
            self.headsUpLeadMinutes = defaults.integer(forKey: Key.headsUpLeadMinutes)
        } else {
            self.headsUpLeadMinutes = Defaults.headsUpLeadMinutes
        }

        if defaults.object(forKey: Key.systemBannerEnabled) != nil {
            self.systemBannerEnabled = defaults.bool(forKey: Key.systemBannerEnabled)
        } else {
            self.systemBannerEnabled = Defaults.systemBannerEnabled
        }

        if defaults.object(forKey: Key.yesterdayMissedReminder) != nil {
            self.yesterdayMissedReminderEnabled = defaults.bool(forKey: Key.yesterdayMissedReminder)
        } else {
            self.yesterdayMissedReminderEnabled = Defaults.yesterdayMissedReminderEnabled
        }

        if defaults.object(forKey: Key.dailySummaryHour) != nil {
            self.dailySummaryHour = defaults.integer(forKey: Key.dailySummaryHour)
        } else {
            self.dailySummaryHour = Defaults.dailySummaryHour
        }

        if defaults.object(forKey: Key.quietHoursStart) != nil {
            self.quietHoursStart = defaults.integer(forKey: Key.quietHoursStart)
        } else {
            self.quietHoursStart = Defaults.quietHoursStart
        }

        if defaults.object(forKey: Key.quietHoursEnd) != nil {
            self.quietHoursEnd = defaults.integer(forKey: Key.quietHoursEnd)
        } else {
            self.quietHoursEnd = Defaults.quietHoursEnd
        }

        if defaults.object(forKey: Key.iCloudSyncOn) != nil {
            self.iCloudSyncOn = defaults.bool(forKey: Key.iCloudSyncOn)
        } else {
            self.iCloudSyncOn = Defaults.iCloudSyncOn
        }

        if defaults.object(forKey: Key.calendarMirrorOn) != nil {
            self.calendarMirrorOn = defaults.bool(forKey: Key.calendarMirrorOn)
        } else {
            self.calendarMirrorOn = Defaults.calendarMirrorOn
        }

        if defaults.object(forKey: Key.remindersMirrorOn) != nil {
            self.remindersMirrorOn = defaults.bool(forKey: Key.remindersMirrorOn)
        } else {
            self.remindersMirrorOn = Defaults.remindersMirrorOn
        }

        // init 完成，后续 setter 的 didSet 才会触发 persist。
        self.isLoading = false
    }

    // MARK: - V1 启动期读取 iCloud sync 开关

    /// V1：在 App 启动早期（构造 ModelContainer 前、SettingsViewModel 实例化前）读取 iCloud sync
    /// 开关，决定 `makeContainer(cloudSyncEnabled:)` 与 `CloudSyncMonitor(cloudSyncEnabled:)` 传值。
    /// 与 init 中读 `Key.iCloudSyncOn` 的逻辑一致：键缺失（首次启动）回退到默认 ON。
    /// 静态方法让 App init 不必先建整个 VM 即可拿到这一个值。
    public static func readICloudSyncOn(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: Key.iCloudSyncOn) != nil {
            return defaults.bool(forKey: Key.iCloudSyncOn)
        }
        return Defaults.iCloudSyncOn
    }

    // MARK: - V1 Sync monitor 注入

    /// V1：把 App 启动时创建的 `CloudSyncMonitor` 注入本 VM，驱动 `lastSyncedText` 实时刷新。
    /// App 在拿到 ModelContainer 后调用一次；测试 / preview 不注入（`lastSyncedText` 走静态回退）。
    public func attachSyncMonitor(_ monitor: CloudSyncMonitor) {
        self.syncMonitor = monitor
    }

    // MARK: - Persistence

    /// 把所有字段写回 UserDefaults。每次 setter 后通过 `persistIfReady()` 调用一次（全量写，
    /// 一次性写完虽然有微小冗余但保证语义最简：任何一项变更后磁盘上必然是当前 VM 的完整快照）。
    public func persist() {
        defaults.set(defaultTab.rawValue, forKey: Key.defaultTab)
        defaults.set(defaultTodoScope.rawValue, forKey: Key.defaultTodoScope)
        defaults.set(showCompletedInCounts, forKey: Key.showCompletedInCounts)
        defaults.set(startWeekOn.rawValue, forKey: Key.startWeekOn)

        defaults.set(headsUpLeadMinutes, forKey: Key.headsUpLeadMinutes)
        defaults.set(systemBannerEnabled, forKey: Key.systemBannerEnabled)
        defaults.set(yesterdayMissedReminderEnabled, forKey: Key.yesterdayMissedReminder)
        defaults.set(dailySummaryHour, forKey: Key.dailySummaryHour)
        defaults.set(quietHoursStart, forKey: Key.quietHoursStart)
        defaults.set(quietHoursEnd, forKey: Key.quietHoursEnd)

        defaults.set(iCloudSyncOn, forKey: Key.iCloudSyncOn)
        defaults.set(calendarMirrorOn, forKey: Key.calendarMirrorOn)
        defaults.set(remindersMirrorOn, forKey: Key.remindersMirrorOn)
    }

    /// init 期间 didSet 触发的 persist 调用被 isLoading 抑制，
    /// 避免每次给字段赋初值都把已有的合法值原样回写一次（虽然写回幂等，但额外的 UserDefaults
    /// 写入会触发 KVO 与 plist 落盘 I/O）。
    private func persistIfReady() {
        guard !isLoading else { return }
        persist()
    }
}
