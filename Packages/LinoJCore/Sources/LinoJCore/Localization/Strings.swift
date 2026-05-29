// Strings.swift
// P5：把 Localizable.xcstrings 中的 key 映射成 LocalizedStringResource 静态成员。
//
// 用法：
//   Text(LJStrings.todoTitle)            // 自动从 LinoJCore 包资源解析当前 locale
//   String(localized: LJStrings.todoTitle)
//   Text("\(open) ").  -> 数字仍走 Swift 字面量；本地化字串走 LJStrings.*
//
// Bundle.module 由 SwiftPM 在 Package.swift target 段声明 resources 后自动生成；
// 所有 LocalizedStringResource 显式带 `bundle: .atURL(Bundle.module.bundleURL)`，
// 否则在 App target 调用方上下文会误用 main bundle，找不到字符串。
//
// 设计：所有静态成员都放在 `LJStrings` 枚举里（无 case），调用方写 `LJStrings.urgent` 即可。
// 不直接 extend LocalizedStringResource —— 避免把 100+ 项灌进系统类型空间，命名也更清楚。

import Foundation

/// LinoJ 全局本地化 string 入口。所有 key 与 Resources/Localizable.xcstrings 一一对应。
public enum LJStrings {

    // 在内部封装 Bundle 解析：所有 helper 都走这一处，避免每个属性都重复指 bundle。
    // 不能 @inlinable —— SwiftPM 自动生成的 `Bundle.module` 是 internal，
    // @inlinable 函数无法引用 internal 符号；保留为普通 static func 即可。
    static func r(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }

    // MARK: - Tabs

    public static let tabMain: LocalizedStringResource = r("Tab.main")
    public static let tabPersonal: LocalizedStringResource = r("Tab.personal")
    public static let tabCompany: LocalizedStringResource = r("Tab.company")
    public static let tabCalendar: LocalizedStringResource = r("Tab.calendar")

    // MARK: - Toolbar (macOS 顶栏)

    /// macOS 顶栏右侧「Search or jump」按钮文案（V4）。
    public static let toolbarSearchOrJump: LocalizedStringResource = r("Toolbar.searchOrJump")
    /// macOS 顶栏右侧「New」按钮文案（V4）。按钮实际显示 "+ New" / "+ 新建"，"+" 由布局拼接。
    public static let toolbarNew: LocalizedStringResource = r("Toolbar.new")

    // MARK: - Main / Section titles

    public static let mainTitle: LocalizedStringResource = r("Main.title")
    public static let urgent: LocalizedStringResource = r("Section.urgent")
    public static let normal: LocalizedStringResource = r("Section.normal")
    public static let projects: LocalizedStringResource = r("Section.projects")
    public static let next7Days: LocalizedStringResource = r("Section.next7Days")
    public static let fromYesterday: LocalizedStringResource = r("Section.fromYesterday")
    public static let todos: LocalizedStringResource = r("Section.todos")
    public static let linkedEvents: LocalizedStringResource = r("Section.linkedEvents")
    public static let notes: LocalizedStringResource = r("Section.notes")
    public static let upcomingToday: LocalizedStringResource = r("Section.upcomingToday")

    /// `Completed (%d)` —— CompletedBox 折叠头部。
    public static func sectionCompleted(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "Section.completed",
            defaultValue: "Completed (\(count))",
            bundle: .atURL(Bundle.module.bundleURL)
        )
    }

    /// `%d urgent` —— ProjectCard / Main project strip 的 urgent 后缀。
    public static func projectCardUrgentSuffix(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "ProjectCard.urgentSuffix",
            defaultValue: "\(count) urgent",
            bundle: .atURL(Bundle.module.bundleURL)
        )
    }

    /// `%d events · next 7 days` —— Calendar 顶栏滚动 7 天窗口事件计数副标。
    public static func countsEventsNext7Days(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "Counts.eventsNext7Days",
            defaultValue: "\(count) events · next 7 days",
            bundle: .atURL(Bundle.module.bundleURL)
        )
    }

    /// `%d events` —— ProjectCard 数字+事件标签。
    public static func projectCardEventsSuffix(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "ProjectCard.eventsSuffix",
            defaultValue: "\(count) events",
            bundle: .atURL(Bundle.module.bundleURL)
        )
    }

    /// `%d todos` —— ProjectCard 数字+待办标签。
    public static func projectCardTodosSuffix(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "ProjectCard.todosSuffix",
            defaultValue: "\(count) todos",
            bundle: .atURL(Bundle.module.bundleURL)
        )
    }

    // MARK: - Settings v1 hint

    /// Settings 中暂未接通的字段后缀提示「(coming in v1.0)」。
    public static let settingsV1OnlyHint: LocalizedStringResource = r("Settings.v1OnlyHint")

    // MARK: - macOS Menu

    /// macOS 菜单：Navigate（原 "View"，避免与系统 View 菜单合并）。
    public static let menuNavigate: LocalizedStringResource = r("Menu.navigate")

    // MARK: - Day labels

    public static let today: LocalizedStringResource = r("Day.today")
    public static let tomorrow: LocalizedStringResource = r("Day.tomorrow")
    public static let todayUpper: LocalizedStringResource = r("Day.todayUpper")

    // MARK: - Stat / count words

    public static let statOpen: LocalizedStringResource = r("Stat.open")
    public static let statUrgent: LocalizedStringResource = r("Stat.urgent")
    public static let statDone: LocalizedStringResource = r("Stat.done")
    public static let statEvents: LocalizedStringResource = r("Stat.events")
    public static let statOpenTodos: LocalizedStringResource = r("Stat.openTodos")
    public static let statLinkedEvents: LocalizedStringResource = r("Stat.linkedEvents")
    public static let statCreated: LocalizedStringResource = r("Stat.created")

    // MARK: - Empty states

    public static let emptyInboxZeroTitle: LocalizedStringResource = r("Empty.inboxZero.title")
    public static let emptyInboxZeroSubtitle: LocalizedStringResource = r("Empty.inboxZero.subtitle")
    public static let emptyInboxZeroCTA: LocalizedStringResource = r("Empty.inboxZero.cta")
    public static let emptyUrgentEmptyTitle: LocalizedStringResource = r("Empty.urgentEmpty.title")
    public static let emptyUrgentEmptySubtitle: LocalizedStringResource = r("Empty.urgentEmpty.subtitle")
    public static let emptyClearWeekTitle: LocalizedStringResource = r("Empty.clearWeek.title")
    public static let emptyClearWeekSubtitle: LocalizedStringResource = r("Empty.clearWeek.subtitle")
    public static let emptyClearWeekCTA: LocalizedStringResource = r("Empty.clearWeek.cta")
    public static let emptyNoResultsSubtitle: LocalizedStringResource = r("Empty.noResults.subtitle")

    /// `No matches for "%@"` —— 占位 query string。
    public static func emptyNoResultsTitle(_ query: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "Empty.noResults.title",
            defaultValue: "No matches for \"\(query)\"",
            bundle: .atURL(Bundle.module.bundleURL)
        )
    }

    public static let nothingHere: LocalizedStringResource = r("Empty.nothingHere")
    public static let nothingInNormal: LocalizedStringResource = r("Empty.nothingInNormal")
    public static let nothingUrgentNice: LocalizedStringResource = r("Empty.nothingUrgentNice")
    public static let nothingOnBooks: LocalizedStringResource = r("Empty.nothingOnBooks")
    public static let nothingOnBooksDot: LocalizedStringResource = r("Empty.nothingOnBooksDot")
    public static let nothingFinishedYet: LocalizedStringResource = r("Empty.nothingFinishedYet")
    public static let completedUntilCrossOff: LocalizedStringResource = r("Empty.completedUntilCrossOff")

    // MARK: - HeadsUp

    public static let headsUp: LocalizedStringResource = r("HeadsUp.title")
    public static let headsUpSnooze: LocalizedStringResource = r("HeadsUp.snooze")
    public static let headsUpOpen: LocalizedStringResource = r("HeadsUp.open")

    /// `in %d min` —— 与 minutesUntil 数值拼接。
    public static func headsUpInMinutes(_ minutes: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "HeadsUp.inMinutes",
            defaultValue: "in \(minutes) min",
            bundle: .atURL(Bundle.module.bundleURL)
        )
    }

    // MARK: - Calendar specific

    /// 周视图表头 today 列的全大写小标签 "TODAY" / "今天"（取代周缩写 MON/TUE…）。
    public static let calendarTodayUpper: LocalizedStringResource = r("Calendar.today")
    public static let tapToConfirm: LocalizedStringResource = r("Calendar.tapToConfirm")
    public static let previousWeek: LocalizedStringResource = r("Calendar.previousWeek")
    public static let nextWeek: LocalizedStringResource = r("Calendar.nextWeek")
    public static let jumpToday: LocalizedStringResource = r("Calendar.jumpToday")
    public static let newEvent: LocalizedStringResource = r("Calendar.newEvent")
    public static let newEventAcc: LocalizedStringResource = r("Calendar.newEventAcc")

    // MARK: - Project

    public static let allBuckets: LocalizedStringResource = r("Project.allBuckets")
    public static let editProject: LocalizedStringResource = r("Project.editProject")
    public static let addTodo: LocalizedStringResource = r("Project.addTodo")
    public static let addEvent: LocalizedStringResource = r("Project.addEvent")
    public static let backToCompany: LocalizedStringResource = r("Project.backToCompany")
    public static let projectMore: LocalizedStringResource = r("Project.more")
    public static let projectNotFound: LocalizedStringResource = r("Project.notFound")

    // MARK: - ProjectDetail delete (W3)

    /// ⋯ 菜单「Delete project」项文案。
    public static let projectDetailDelete: LocalizedStringResource = r("ProjectDetail.delete")
    /// 删除确认对话框标题。
    public static let projectDetailDeleteConfirmTitle: LocalizedStringResource = r("ProjectDetail.deleteConfirmTitle")
    /// 删除确认对话框正文（说明 todos/events 变 standalone + 不可撤销）。
    public static let projectDetailDeleteConfirmMessage: LocalizedStringResource = r("ProjectDetail.deleteConfirmMessage")
    /// 删除确认对话框的破坏性确认按钮文案（"Delete"）。
    public static let projectDetailDeleteConfirmConfirm: LocalizedStringResource = r("ProjectDetail.deleteConfirmConfirm")

    // MARK: - Event actions (W4)

    /// 事件卡 contextMenu / 编辑入口「Edit event」文案。
    public static let eventEdit: LocalizedStringResource = r("Event.edit")
    /// 事件卡 contextMenu「Delete event」文案。
    public static let eventDelete: LocalizedStringResource = r("Event.delete")
    /// 事件卡 contextMenu「Mark attended」（仅已结束事件出现）。
    public static let eventMarkAttended: LocalizedStringResource = r("Event.markAttended")
    /// 事件卡 contextMenu「Unmark attended」（已结束且已确认事件，翻转回未出席）。
    public static let eventUnmarkAttended: LocalizedStringResource = r("Event.unmarkAttended")
    /// 删除事件确认对话框标题。
    public static let eventDeleteConfirmTitle: LocalizedStringResource = r("Event.deleteConfirmTitle")
    /// 删除事件确认对话框正文。
    public static let eventDeleteConfirmMessage: LocalizedStringResource = r("Event.deleteConfirmMessage")
    /// 删除事件确认对话框的破坏性确认按钮文案（"Delete"）。
    public static let eventDeleteConfirmConfirm: LocalizedStringResource = r("Event.deleteConfirmConfirm")

    // MARK: - Filters

    public static let filterAllWork: LocalizedStringResource = r("Filter.allWork")
    public static let filterStandalone: LocalizedStringResource = r("Filter.standalone")

    // MARK: - Done suffix

    public static let doneSuffix: LocalizedStringResource = r("Done.suffix")

    // MARK: - QuickAdd

    public static let quickAddNew: LocalizedStringResource = r("QuickAdd.new")
    /// V5：edit 模式下 sheet 标题（取代 "New"）。
    public static let quickAddEditProjectTitle: LocalizedStringResource = r("QuickAdd.editProjectTitle")
    /// W4：event edit 模式下 sheet 标题（取代 "New"）。
    public static let quickAddEditEventTitle: LocalizedStringResource = r("QuickAdd.editEventTitle")
    /// V5：edit 模式下提交按钮文案（"Save" / "保存"，取代 "Create"）。
    public static let quickAddSave: LocalizedStringResource = r("QuickAdd.save")
    public static let quickAddCancel: LocalizedStringResource = r("QuickAdd.cancel")
    public static let quickAddCancelHint: LocalizedStringResource = r("QuickAdd.cancelHint")
    public static let quickAddCreate: LocalizedStringResource = r("QuickAdd.create")
    public static let quickAddCreateHint: LocalizedStringResource = r("QuickAdd.createHint")
    public static let quickAddCreateTodo: LocalizedStringResource = r("QuickAdd.createTodo")
    public static let quickAddCreateEvent: LocalizedStringResource = r("QuickAdd.createEvent")
    public static let quickAddCreateProject: LocalizedStringResource = r("QuickAdd.createProject")
    public static let quickAddKindTodo: LocalizedStringResource = r("QuickAdd.kind.todo")
    public static let quickAddKindEvent: LocalizedStringResource = r("QuickAdd.kind.event")
    public static let quickAddKindProject: LocalizedStringResource = r("QuickAdd.kind.project")
    public static let quickAddTodoPlaceholder: LocalizedStringResource = r("QuickAdd.todo.placeholder")
    public static let quickAddEventPlaceholder: LocalizedStringResource = r("QuickAdd.event.placeholder")
    public static let quickAddProjectPlaceholder: LocalizedStringResource = r("QuickAdd.project.placeholder")
    public static let quickAddLocationPlaceholder: LocalizedStringResource = r("QuickAdd.location.placeholder")
    public static let quickAddTagPlaceholder: LocalizedStringResource = r("QuickAdd.tag.placeholder")
    public static let quickAddLabelUrgency: LocalizedStringResource = r("QuickAdd.label.urgency")
    public static let quickAddLabelScope: LocalizedStringResource = r("QuickAdd.label.scope")
    public static let quickAddLabelProject: LocalizedStringResource = r("QuickAdd.label.project")
    public static let quickAddLabelLinkProject: LocalizedStringResource = r("QuickAdd.label.linkProject")
    public static let quickAddLabelLocation: LocalizedStringResource = r("QuickAdd.label.location")
    public static let quickAddLabelAttendees: LocalizedStringResource = r("QuickAdd.label.attendees")
    public static let quickAddLabelDescription: LocalizedStringResource = r("QuickAdd.label.description")
    public static let quickAddLabelTag: LocalizedStringResource = r("QuickAdd.label.tag")
    public static let quickAddLabelMembers: LocalizedStringResource = r("QuickAdd.label.members")
    public static let quickAddOptional: LocalizedStringResource = r("QuickAdd.optional")
    public static let quickAddTagHint: LocalizedStringResource = r("QuickAdd.tag.hint")
    public static let quickAddTagHintShort: LocalizedStringResource = r("QuickAdd.tag.hintShort")
    public static let quickAddChipNone: LocalizedStringResource = r("QuickAdd.chip.none")
    public static let quickAddChipAdd: LocalizedStringResource = r("QuickAdd.chip.add")
    public static let quickAddChipInvite: LocalizedStringResource = r("QuickAdd.chip.invite")
    public static let quickAddEventDate: LocalizedStringResource = r("QuickAdd.event.date")
    public static let quickAddEventStart: LocalizedStringResource = r("QuickAdd.event.start")
    public static let quickAddEventEnd: LocalizedStringResource = r("QuickAdd.event.end")
    public static let quickAddEventDateRow: LocalizedStringResource = r("QuickAdd.event.dateRow")
    public static let quickAddEventStartsRow: LocalizedStringResource = r("QuickAdd.event.startsRow")
    public static let quickAddEventEndsRow: LocalizedStringResource = r("QuickAdd.event.endsRow")

    // MARK: - Quick Add people picker (W1)

    /// Attendees 节空态入口按钮文案（实际显示 "+ Add attendee"，"+" 含在文案内）。
    public static let quickAddAttendeesAdd: LocalizedStringResource = r("QuickAdd.attendeesAdd")
    /// Members 节空态入口按钮文案（实际显示 "+ Add member"）。
    public static let quickAddMembersAdd: LocalizedStringResource = r("QuickAdd.membersAdd")
    /// Attendees 节空态占位提示文案。
    public static let quickAddAttendeesEmpty: LocalizedStringResource = r("QuickAdd.attendeesEmpty")
    /// Members 节空态占位提示文案。
    public static let quickAddMembersEmpty: LocalizedStringResource = r("QuickAdd.membersEmpty")
    /// 选人器标题（iOS 二级 picker 导航标题 / macOS 内联区标题）。
    public static let quickAddPeoplePickerTitle: LocalizedStringResource = r("QuickAdd.peoplePickerTitle")
    /// 选人器顶部搜索/输入框 placeholder。
    public static let quickAddPeopleSearchPlaceholder: LocalizedStringResource = r("QuickAdd.peopleSearchPlaceholder")
    /// 「新建人员」行的基础文案（实际行显示 "Create『<name>』"，name 由布局拼接，不进 key）。
    public static let quickAddPeopleCreateNew: LocalizedStringResource = r("QuickAdd.peopleCreateNew")
    /// 选人器右上「完成」回传按钮文案。
    public static let quickAddPeopleDone: LocalizedStringResource = r("QuickAdd.peopleDone")
    /// 选人器搜索无匹配时的占位文案。
    public static let quickAddPeopleNoResults: LocalizedStringResource = r("QuickAdd.peopleNoResults")

    // MARK: - Urgency / Scope picker labels (proper-case for chip / Picker tag)

    public static let urgencyUrgent: LocalizedStringResource = r("Urgency.urgent")
    public static let urgencyNormal: LocalizedStringResource = r("Urgency.normal")
    public static let scopePersonal: LocalizedStringResource = r("Scope.personal")
    public static let scopeCompany: LocalizedStringResource = r("Scope.company")

    // MARK: - Search

    public static let searchPlaceholder: LocalizedStringResource = r("Search.placeholder")
    public static let searchClear: LocalizedStringResource = r("Search.clear")
    public static let searchScopeAll: LocalizedStringResource = r("Search.scope.all")
    public static let searchScopeTodos: LocalizedStringResource = r("Search.scope.todos")
    public static let searchScopeEvents: LocalizedStringResource = r("Search.scope.events")
    public static let searchScopeProjects: LocalizedStringResource = r("Search.scope.projects")
    public static let searchNavigate: LocalizedStringResource = r("Search.navigate")
    public static let searchOpenHint: LocalizedStringResource = r("Search.open")
    public static let searchVerbOpen: LocalizedStringResource = r("Search.verb.open")
    public static let searchVerbRun: LocalizedStringResource = r("Search.verb.run")

    /// 顶部「No matches for "q"」短 variant (palette 顶端无结果时显示 inline)。
    public static func searchNoMatchesShort(_ query: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "Search.noMatchesShort",
            defaultValue: "No matches for \"\(query)\"",
            bundle: .atURL(Bundle.module.bundleURL)
        )
    }

    // MARK: - Settings

    public static let settingsTitle: LocalizedStringResource = r("Settings.title")
    public static let settingsSectionGeneral: LocalizedStringResource = r("Settings.section.general")
    public static let settingsSectionNotifications: LocalizedStringResource = r("Settings.section.notifications")
    public static let settingsSectionSync: LocalizedStringResource = r("Settings.section.sync")
    public static let settingsSectionShortcuts: LocalizedStringResource = r("Settings.section.shortcuts")
    public static let settingsSectionAbout: LocalizedStringResource = r("Settings.section.about")
    public static let settingsSectionAccount: LocalizedStringResource = r("Settings.section.account")
    public static let settingsSectionSyncOtherApps: LocalizedStringResource = r("Settings.section.syncOtherApps")

    public static let settingsGeneralHint: LocalizedStringResource = r("Settings.general.hint")
    public static let settingsAppearance: LocalizedStringResource = r("Settings.appearance")
    public static let settingsAppearanceHint: LocalizedStringResource = r("Settings.appearance.hint")
    public static let settingsAppearanceHintIOS: LocalizedStringResource = r("Settings.appearance.hintIOS")
    public static let settingsAppearanceValue: LocalizedStringResource = r("Settings.appearance.value")
    public static let settingsAppearanceLocked: LocalizedStringResource = r("Settings.appearance.locked")
    public static let settingsDefaultTab: LocalizedStringResource = r("Settings.defaultTab")
    public static let settingsDefaultTabHint: LocalizedStringResource = r("Settings.defaultTab.hint")
    public static let settingsDefaultScope: LocalizedStringResource = r("Settings.defaultScope")
    public static let settingsDefaultScopeHint: LocalizedStringResource = r("Settings.defaultScope.hint")
    public static let settingsShowCompleted: LocalizedStringResource = r("Settings.showCompleted")
    public static let settingsShowCompletedHint: LocalizedStringResource = r("Settings.showCompleted.hint")
    public static let settingsStartWeek: LocalizedStringResource = r("Settings.startWeek")
    public static let settingsStartWeekHint: LocalizedStringResource = r("Settings.startWeek.hint")

    public static let weekdaySunday: LocalizedStringResource = r("Weekday.sunday")
    public static let weekdayMonday: LocalizedStringResource = r("Weekday.monday")

    public static let settingsNotificationsHint: LocalizedStringResource = r("Settings.notifications.hint")
    public static let settingsHeadsUp: LocalizedStringResource = r("Settings.headsUp")
    public static let settingsHeadsUpHint: LocalizedStringResource = r("Settings.headsUp.hint")
    public static let settingsHeadsUpShort: LocalizedStringResource = r("Settings.headsUpShort")
    public static let settingsSystemBanner: LocalizedStringResource = r("Settings.systemBanner")
    public static let settingsSystemBannerHint: LocalizedStringResource = r("Settings.systemBanner.hint")
    public static let settingsSystemBannerShort: LocalizedStringResource = r("Settings.systemBannerShort")
    public static let settingsYesterdayMissed: LocalizedStringResource = r("Settings.yesterdayMissed")
    public static let settingsYesterdayMissedHint: LocalizedStringResource = r("Settings.yesterdayMissed.hint")
    public static let settingsDailySummary: LocalizedStringResource = r("Settings.dailySummary")
    public static let settingsDailySummaryHint: LocalizedStringResource = r("Settings.dailySummary.hint")
    public static let settingsQuietHours: LocalizedStringResource = r("Settings.quietHours")
    public static let settingsQuietHoursHint: LocalizedStringResource = r("Settings.quietHours.hint")

    public static let settingsSyncHint: LocalizedStringResource = r("Settings.sync.hint")
    public static let settingsICloudSync: LocalizedStringResource = r("Settings.iCloudSync")
    public static let settingsICloudSyncHint: LocalizedStringResource = r("Settings.iCloudSync.hint")
    public static let settingsICloudSyncHintShort: LocalizedStringResource = r("Settings.iCloudSync.hintShort")
    public static let settingsAccount: LocalizedStringResource = r("Settings.account")
    public static let settingsAppleAccount: LocalizedStringResource = r("Settings.appleAccount")
    public static let settingsSignOut: LocalizedStringResource = r("Settings.signOut")

    // V3：Sign in with Apple —— Account 行未登录 / 已登录展示文案。
    /// Account 行未登录时的文字（macOS 备用 / iOS 行内）以及无障碍标签。
    public static let settingsSignInWithApple: LocalizedStringResource = r("Settings.signInWithApple")
    /// Account 行未登录时的次级提示。
    public static let settingsAccountSignedOutHint: LocalizedStringResource = r("Settings.account.signedOutHint")
    /// 已登录但 Apple 未回传姓名 / email 时的兜底展示。
    public static let settingsAccountNotSignedIn: LocalizedStringResource = r("Settings.account.notSignedIn")
    /// V3：EventKit mirror 占位 hint「(coming later)」—— v1.0 不接 EventKit（plan V3 决策）。
    public static let settingsEventKitLaterHint: LocalizedStringResource = r("Settings.eventKitLaterHint")

    public static let settingsAppleCalendar: LocalizedStringResource = r("Settings.appleCalendar")
    public static let settingsAppleCalendarHint: LocalizedStringResource = r("Settings.appleCalendar.hint")
    public static let settingsAppleCalendarShort: LocalizedStringResource = r("Settings.appleCalendarShort")
    public static let settingsAppleCalendarShortHint: LocalizedStringResource = r("Settings.appleCalendarShort.hint")
    public static let settingsAppleReminders: LocalizedStringResource = r("Settings.appleReminders")
    public static let settingsAppleRemindersHint: LocalizedStringResource = r("Settings.appleReminders.hint")
    public static let settingsAppleRemindersShort: LocalizedStringResource = r("Settings.appleRemindersShort")
    public static let settingsAppleRemindersShortHint: LocalizedStringResource = r("Settings.appleRemindersShort.hint")

    public static let settingsLastSyncedPlaceholder: LocalizedStringResource = r("Settings.lastSyncedPlaceholder")

    // V1：CloudKit 同步状态文案 + iCloud toggle「重启生效」提示。
    /// 同步成功 / 乐观初值。
    public static let settingsSyncedJustNow: LocalizedStringResource = r("Settings.syncedJustNow")
    /// 同步进行中。
    public static let settingsSyncing: LocalizedStringResource = r("Settings.syncing")
    /// 同步出错 / 暂停。
    public static let settingsSyncPaused: LocalizedStringResource = r("Settings.syncPaused")
    /// iCloud OFF / 纯本地模式状态。
    public static let settingsSyncLocalOnly: LocalizedStringResource = r("Settings.syncLocalOnly")
    /// iCloud toggle 旁的「重启后生效」mono caption（OFF 不热切，需重启）。
    public static let settingsICloudRestartHint: LocalizedStringResource = r("Settings.icloudRestartHint")

    public static let settingsShortcutsHint: LocalizedStringResource = r("Settings.shortcuts.hint")
    public static let settingsShortcutsNavigation: LocalizedStringResource = r("Settings.shortcuts.navigation")
    public static let settingsShortcutsCreate: LocalizedStringResource = r("Settings.shortcuts.create")
    public static let settingsShortcutsOnTodo: LocalizedStringResource = r("Settings.shortcuts.onTodo")

    public static let shortcutOpenSearch: LocalizedStringResource = r("Shortcut.openSearch")
    public static let shortcutOpenSettings: LocalizedStringResource = r("Shortcut.openSettings")
    public static let shortcutNewDefault: LocalizedStringResource = r("Shortcut.newDefault")
    public static let shortcutNewTodo: LocalizedStringResource = r("Shortcut.newTodo")
    public static let shortcutNewEvent: LocalizedStringResource = r("Shortcut.newEvent")
    public static let shortcutNewProject: LocalizedStringResource = r("Shortcut.newProject")
    public static let shortcutToggleDone: LocalizedStringResource = r("Shortcut.toggleDone")
    public static let shortcutToggleUrgent: LocalizedStringResource = r("Shortcut.toggleUrgent")
    public static let shortcutDelete: LocalizedStringResource = r("Shortcut.delete")

    public static let aboutAppName: LocalizedStringResource = r("About.appName")
    public static let aboutTagline: LocalizedStringResource = r("About.tagline")
    public static let aboutReleaseNotes: LocalizedStringResource = r("About.releaseNotes")
    public static let aboutReleaseNotesHint: LocalizedStringResource = r("About.releaseNotes.hint")
    public static let aboutFeedback: LocalizedStringResource = r("About.feedback")
    public static let aboutPrivacy: LocalizedStringResource = r("About.privacy")
    public static let aboutPrivacyHint: LocalizedStringResource = r("About.privacy.hint")
    public static let aboutAcknowledgements: LocalizedStringResource = r("About.acknowledgements")
    public static let aboutAcknowledgementsHint: LocalizedStringResource = r("About.acknowledgements.hint")
    public static let aboutVersion: LocalizedStringResource = r("About.version")

    public static let commonDone: LocalizedStringResource = r("Common.done")

    // MARK: - Accessibility

    public static let a11ySearch: LocalizedStringResource = r("A11y.search")
    public static let a11yQuickAdd: LocalizedStringResource = r("A11y.quickAdd")
    public static let a11ySettings: LocalizedStringResource = r("A11y.settings")
    public static let a11yCompletedSuffix: LocalizedStringResource = r("Accessibility.completedSuffix")
    public static let a11yOpenSuffix: LocalizedStringResource = r("Accessibility.openSuffix")
}

// MARK: - Bundle.module helper

/// 测试代码用来直接拿包 bundle 引用，避免重新引入 SwiftPM 自动暴露的 `Bundle.module`
/// 在测试 target 中不可见的问题（测试 target 不绑 resources，但能 import LinoJCore）。
public enum LinoJCoreBundle {
    public static let bundle: Bundle = .module
}

// MARK: - AppTab 本地化 display name

public extension AppTab {
    /// SwiftUI Picker / Tab label / 占位文案统一使用的本地化标签。
    var localizedDisplayName: LocalizedStringResource {
        switch self {
        case .main:     return LJStrings.tabMain
        case .personal: return LJStrings.tabPersonal
        case .company:  return LJStrings.tabCompany
        case .calendar: return LJStrings.tabCalendar
        }
    }
}
