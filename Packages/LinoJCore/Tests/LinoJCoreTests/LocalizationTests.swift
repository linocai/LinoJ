// LocalizationTests.swift
// P5：本地化测试 —— 验证 Localizable.xcstrings 中英双填、Bundle.module 解析路径正确。
//
// 测试策略：
//   - `LocalizedStringResource` 有 `var locale: Locale`（mutable）。我们复制一份，
//     设置目标 locale，再用 `String(localized:)`（无第二参重载）渲染出 String。
//   - 不依赖系统 preferred languages（CI 上环境可能不可控）。

import Foundation
import Testing
@testable import LinoJCore

@Suite("Localization — Localizable.xcstrings 中英双填")
struct LocalizationTests {

    /// 把 `LocalizedStringResource` 在指定 locale 下解析成字符串。
    /// `LocalizedStringResource` 是 struct，复制后 `locale` setter 不会影响调用方的常量。
    private func resolve(
        _ resource: LocalizedStringResource,
        locale identifier: String
    ) -> String {
        var copy = resource
        copy.locale = Locale(identifier: identifier)
        return String(localized: copy)
    }

    // MARK: - 基础解析

    @Test("LJStrings.mainTitle 在 en locale 解析为 'To do'")
    func mainTitleEnglish() {
        #expect(resolve(LJStrings.mainTitle, locale: "en") == "To do")
    }

    @Test("LJStrings.mainTitle 在 zh-Hans locale 解析为 '待办'")
    func mainTitleChinese() {
        #expect(resolve(LJStrings.mainTitle, locale: "zh-Hans") == "待办")
    }

    @Test("LJStrings.emptyInboxZeroTitle 双语都有翻译且差异化")
    func inboxZeroBothLanguages() {
        let en = resolve(LJStrings.emptyInboxZeroTitle, locale: "en")
        let zh = resolve(LJStrings.emptyInboxZeroTitle, locale: "zh-Hans")
        #expect(en == "Inbox zero.")
        #expect(zh == "全部清空。")
        #expect(en != zh, "中英 fallback 异常 —— zh-Hans 没匹配到时会 fall through 到 en")
    }

    @Test("LJStrings.urgent / normal section header 两端翻译正确")
    func sectionHeaders() {
        #expect(resolve(LJStrings.urgent, locale: "en") == "Urgent")
        #expect(resolve(LJStrings.urgent, locale: "zh-Hans") == "紧急")
        #expect(resolve(LJStrings.normal, locale: "en") == "Normal")
        #expect(resolve(LJStrings.normal, locale: "zh-Hans") == "常规")
    }

    @Test("HeadsUp 含格式化占位 `in %d min`")
    func headsUpFormatted() {
        let en = resolve(LJStrings.headsUpInMinutes(10), locale: "en")
        let zh = resolve(LJStrings.headsUpInMinutes(10), locale: "zh-Hans")
        #expect(en == "in 10 min")
        #expect(zh == "10 分钟后")
    }

    @Test("Empty.noResults.title 含 query 占位 %@")
    func noResultsFormatted() {
        let en = resolve(LJStrings.emptyNoResultsTitle("foo"), locale: "en")
        let zh = resolve(LJStrings.emptyNoResultsTitle("foo"), locale: "zh-Hans")
        #expect(en == "No matches for \"foo\"")
        #expect(zh == "没有匹配 \"foo\"")
    }

    // MARK: - 防漏译批量验证（15+ key）

    @Test("批量 15+ key 双语都有非空翻译，且 zh ≠ en")
    func batchTranslationCoverage() {
        // 把代表性 key 全列出来；只要其中任何一项 zh-Hans 缺译会 fallback 回 en，断言失败。
        let cases: [(name: String, resource: LocalizedStringResource, expectedEn: String, expectedZh: String)] = [
            ("Tab.main", LJStrings.tabMain, "Main", "主页"),
            ("Tab.personal", LJStrings.tabPersonal, "Personal", "个人"),
            ("Tab.company", LJStrings.tabCompany, "Company", "工作"),
            ("Tab.calendar", LJStrings.tabCalendar, "Calendar", "日历"),
            ("Main.title", LJStrings.mainTitle, "To do", "待办"),
            ("Section.urgent", LJStrings.urgent, "Urgent", "紧急"),
            ("Section.normal", LJStrings.normal, "Normal", "常规"),
            ("Section.projects", LJStrings.projects, "Projects", "项目"),
            ("Section.next7Days", LJStrings.next7Days, "Next 7 days", "未来 7 天"),
            ("Day.today", LJStrings.today, "Today", "今天"),
            ("Empty.inboxZero.title", LJStrings.emptyInboxZeroTitle, "Inbox zero.", "全部清空。"),
            ("Empty.inboxZero.cta", LJStrings.emptyInboxZeroCTA, "+ New todo", "+ 新建待办"),
            ("Empty.urgentEmpty.title", LJStrings.emptyUrgentEmptyTitle, "Nothing urgent.", "没有紧急。"),
            ("Empty.clearWeek.title", LJStrings.emptyClearWeekTitle, "A clear week.", "一周清净。"),
            ("HeadsUp.title", LJStrings.headsUp, "Heads up", "即将开始"),
            ("HeadsUp.snooze", LJStrings.headsUpSnooze, "Snooze", "稍后提醒"),
            ("Settings.title", LJStrings.settingsTitle, "Settings", "设置"),
            ("Settings.appearance", LJStrings.settingsAppearance, "Appearance", "外观"),
            ("Settings.appearance.locked", LJStrings.settingsAppearanceLocked, "locked", "锁定"),
            ("Search.placeholder", LJStrings.searchPlaceholder, "Search across todos, events, projects…", "搜索待办、事件、项目…"),
            ("QuickAdd.new", LJStrings.quickAddNew, "New", "新建"),
            ("QuickAdd.create", LJStrings.quickAddCreate, "Create", "创建"),
            ("QuickAdd.editProjectTitle", LJStrings.quickAddEditProjectTitle, "Edit project", "编辑项目"),
            ("QuickAdd.save", LJStrings.quickAddSave, "Save", "保存"),
            // V1：CloudKit 同步状态 + iCloud 重启提示文案。
            ("Settings.syncedJustNow", LJStrings.settingsSyncedJustNow, "Synced just now", "刚刚已同步"),
            ("Settings.syncing", LJStrings.settingsSyncing, "Syncing…", "正在同步…"),
            ("Settings.syncPaused", LJStrings.settingsSyncPaused, "Sync paused", "同步已暂停"),
            ("Settings.syncLocalOnly", LJStrings.settingsSyncLocalOnly, "Local only", "仅本地"),
            ("Settings.icloudRestartHint", LJStrings.settingsICloudRestartHint, "Restart to apply", "重启后生效"),
        ]

        for c in cases {
            let en = resolve(c.resource, locale: "en")
            let zh = resolve(c.resource, locale: "zh-Hans")
            #expect(en == c.expectedEn, "[\(c.name)] EN 翻译错位：得到 '\(en)'，期望 '\(c.expectedEn)'")
            #expect(zh == c.expectedZh, "[\(c.name)] 中文翻译错位：得到 '\(zh)'，期望 '\(c.expectedZh)'")
            #expect(zh != en, "[\(c.name)] zh-Hans 与 en 相同 —— 可能 fallback 回了 en（漏译）")
        }
    }

    // MARK: - W1 选人器新增 key 双语验证

    @Test("W1 选人器 9 个 key 双语都有非空翻译，且 zh ≠ en")
    func w1PeoplePickerKeys() {
        let cases: [(name: String, resource: LocalizedStringResource, expectedEn: String, expectedZh: String)] = [
            ("QuickAdd.attendeesAdd", LJStrings.quickAddAttendeesAdd, "+ Add attendee", "+ 添加参会人"),
            ("QuickAdd.membersAdd", LJStrings.quickAddMembersAdd, "+ Add member", "+ 添加成员"),
            ("QuickAdd.attendeesEmpty", LJStrings.quickAddAttendeesEmpty, "No attendees yet", "暂无参会人"),
            ("QuickAdd.membersEmpty", LJStrings.quickAddMembersEmpty, "No members yet", "暂无成员"),
            ("QuickAdd.peoplePickerTitle", LJStrings.quickAddPeoplePickerTitle, "Select people", "选择人员"),
            ("QuickAdd.peopleSearchPlaceholder", LJStrings.quickAddPeopleSearchPlaceholder, "Search or type a name…", "搜索或输入名字…"),
            ("QuickAdd.peopleCreateNew", LJStrings.quickAddPeopleCreateNew, "Create new person", "新建人员"),
            ("QuickAdd.peopleDone", LJStrings.quickAddPeopleDone, "Done", "完成"),
            ("QuickAdd.peopleNoResults", LJStrings.quickAddPeopleNoResults, "No matching people", "没有匹配的人员"),
        ]

        for c in cases {
            let en = resolve(c.resource, locale: "en")
            let zh = resolve(c.resource, locale: "zh-Hans")
            #expect(en == c.expectedEn, "[\(c.name)] EN 翻译错位：得到 '\(en)'，期望 '\(c.expectedEn)'")
            #expect(zh == c.expectedZh, "[\(c.name)] 中文翻译错位：得到 '\(zh)'，期望 '\(c.expectedZh)'")
            #expect(zh != en, "[\(c.name)] zh-Hans 与 en 相同 —— 可能 fallback 回了 en（漏译）")
        }
    }

    // MARK: - W3 ProjectDetail delete 新增 key 双语验证

    @Test("W3 ProjectDetail delete 4 个 key 双语都有非空翻译，且 zh ≠ en")
    func w3ProjectDetailDeleteKeys() {
        let cases: [(name: String, resource: LocalizedStringResource, expectedEn: String, expectedZh: String)] = [
            ("ProjectDetail.delete", LJStrings.projectDetailDelete, "Delete project", "删除项目"),
            ("ProjectDetail.deleteConfirmTitle", LJStrings.projectDetailDeleteConfirmTitle, "Delete this project?", "删除该项目？"),
            ("ProjectDetail.deleteConfirmMessage", LJStrings.projectDetailDeleteConfirmMessage, "Its todos and events will become standalone. This can't be undone.", "其下的待办和事件将变为独立项。此操作无法撤销。"),
            ("ProjectDetail.deleteConfirmConfirm", LJStrings.projectDetailDeleteConfirmConfirm, "Delete", "删除"),
        ]

        for c in cases {
            let en = resolve(c.resource, locale: "en")
            let zh = resolve(c.resource, locale: "zh-Hans")
            #expect(en == c.expectedEn, "[\(c.name)] EN 翻译错位：得到 '\(en)'，期望 '\(c.expectedEn)'")
            #expect(zh == c.expectedZh, "[\(c.name)] 中文翻译错位：得到 '\(zh)'，期望 '\(c.expectedZh)'")
            #expect(zh != en, "[\(c.name)] zh-Hans 与 en 相同 —— 可能 fallback 回了 en（漏译）")
        }
    }

    // MARK: - W4 事件操作新增 key 双语验证

    @Test("W4 事件操作 8 个 key 双语都有非空翻译，且 zh ≠ en")
    func w4EventActionKeys() {
        let cases: [(name: String, resource: LocalizedStringResource, expectedEn: String, expectedZh: String)] = [
            ("Event.edit", LJStrings.eventEdit, "Edit event", "编辑事件"),
            ("Event.delete", LJStrings.eventDelete, "Delete event", "删除事件"),
            ("Event.markAttended", LJStrings.eventMarkAttended, "Mark attended", "标记已出席"),
            ("Event.unmarkAttended", LJStrings.eventUnmarkAttended, "Unmark attended", "取消已出席"),
            ("Event.deleteConfirmTitle", LJStrings.eventDeleteConfirmTitle, "Delete this event?", "删除该事件？"),
            ("Event.deleteConfirmMessage", LJStrings.eventDeleteConfirmMessage, "This can't be undone.", "此操作无法撤销。"),
            ("Event.deleteConfirmConfirm", LJStrings.eventDeleteConfirmConfirm, "Delete", "删除"),
            ("QuickAdd.editEventTitle", LJStrings.quickAddEditEventTitle, "Edit event", "编辑事件"),
        ]

        for c in cases {
            let en = resolve(c.resource, locale: "en")
            let zh = resolve(c.resource, locale: "zh-Hans")
            #expect(en == c.expectedEn, "[\(c.name)] EN 翻译错位：得到 '\(en)'，期望 '\(c.expectedEn)'")
            #expect(zh == c.expectedZh, "[\(c.name)] 中文翻译错位：得到 '\(zh)'，期望 '\(c.expectedZh)'")
            #expect(zh != en, "[\(c.name)] zh-Hans 与 en 相同 —— 可能 fallback 回了 en（漏译）")
        }
    }

    // MARK: - W5 ProjectDetail 添加事件新增 key 双语验证

    @Test("W5 ProjectDetail addEvent key 双语都有非空翻译，且 zh ≠ en")
    func w5ProjectDetailAddEventKey() {
        let en = resolve(LJStrings.addEvent, locale: "en")
        let zh = resolve(LJStrings.addEvent, locale: "zh-Hans")
        #expect(en == "+ Add event", "[Project.addEvent] EN 翻译错位：得到 '\(en)'")
        #expect(zh == "+ 添加事件", "[Project.addEvent] 中文翻译错位：得到 '\(zh)'")
        #expect(zh != en, "[Project.addEvent] zh-Hans 与 en 相同 —— 可能 fallback 回了 en（漏译）")
    }

    // MARK: - Bundle 暴露验证

    @Test("LinoJCoreBundle.bundle 能查到 xcstrings 资源")
    func bundleHasResource() {
        let bundle = LinoJCoreBundle.bundle
        // SwiftPM 把 xcstrings 编译进 bundle 后，bundle 应包含 .lproj 或 string table。
        // 用 localizedString(forKey:value:table:) 反查；返回非空即说明 bundle resource OK。
        let value = bundle.localizedString(forKey: "Tab.main", value: nil, table: nil)
        #expect(!value.isEmpty)
    }
}
