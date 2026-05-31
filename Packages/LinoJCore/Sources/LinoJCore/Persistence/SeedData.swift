// SeedData.swift
// DEBUG 启动时把 `design_handoff_linoj/data.js` 的内容写入 SwiftData，
// 让两端 App 一打开就能看到设计稿一样的填充态。
//
// 整个文件被 `#if DEBUG` 包起来 —— Release 编译时 SeedData 类型不存在，
// App 启动会得到一个干净的 Inbox zero。
//
// 设计稿的「今天」固定为 2026-05-27 Tuesday 09:00 local time，所有 event 的绝对时间
// 都以这一天为锚点 + weekDays 数组中的天数偏移 + start/end 小数小时换算。

#if DEBUG
import Foundation
import SwiftData

public enum SeedData {

    // MARK: - Public entry

    /// 检查容器是否已经包含 Todo；若已有任何 Todo 则跳过，避免重复 seed。
    ///
    /// 用 Todo 作为「是否 seed 过」的标记，因为只要 seed 过这条线，Todo 必然 ≥ 1。
    /// 调用方应在 App 启动早期、`ModelContainer` 创建后立刻调用一次。
    @MainActor
    public static func seedIfEmpty(_ context: ModelContext) throws {
        let descriptor = FetchDescriptor<Todo>()
        let existingCount = try context.fetchCount(descriptor)
        guard existingCount == 0 else { return }
        try seedAll(context)
    }

    /// 设计稿固定的「今天」。
    ///
    /// 2026-05-27（Tuesday）09:00 local time，与 PROJECT_PLAN.md 的 currentDate 一致。
    /// HeadsUpService 测试与 Yesterday-missed 测试都依赖这个锚点。
    public static func todaySimulated() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 27
        components.hour = 9
        components.minute = 0
        components.second = 0
        // 用当前日历 + 当前时区，让本地展示一致；UTC 偏移不会影响 weekday 计算结果。
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Helpers (internal so SeedDataTests can poke at them)

    /// 把 9.5 这种「小数小时」转成具体某一天的 Date。
    ///
    /// - Parameters:
    ///   - day: 任意时刻（取其年月日，时分秒丢弃）。
    ///   - decimal: 0..<24 的小数小时，`9.5` → 09:30，`14` → 14:00，`23.99` → 23:59（向下取整后乘 60 取整）。
    /// - Returns: 同一日历日的对应 `Date`。
    public static func hoursDecimalToDate(day: Date, decimal: Double) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let totalMinutes = Int((decimal * 60.0).rounded(.down))
        let hour = totalMinutes / 60
        let minute = totalMinutes % 60
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: dayStart) ?? dayStart
    }

    // MARK: - Seed implementation

    @MainActor
    private static func seedAll(_ context: ModelContext) throws {
        let today = startOfDay(todaySimulated())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today

        // 1) People —— 收集 data.js 里所有 attendees / members 提到的 token 去重创建。
        // data.js 里 token 包括 single-letter initials（L/M/A/J/K）与 full names（Mom/Dad/Andrew）。
        // 我们用 token 原文作为 Person.name，UI 取首字母作为 avatar initial。
        // ⚠️ 与 plan "≥ 10" 不符：data.js 仅含 8 个独立 token —— 详见变更日志 / 汇报。
        let peopleTokens = ["L", "M", "A", "J", "K", "Mom", "Dad", "Andrew"]
        var peopleByToken: [String: Person] = [:]
        for token in peopleTokens {
            let person = Person(name: token)
            context.insert(person)
            peopleByToken[token] = person
        }

        // 2) Projects —— 按 data.js 字面构造 3 个项目。
        // members 列表通过 token 查 peopleByToken。
        // createdAt 是设计稿里的 "Apr 12" / "May 3" / "May 15"，年份取 2026。
        let projectLinoJ = Project(
            title: "LinoJ for macOS v1",
            intro: "Native Swift planner. Three intertwined surfaces — personal, work, and time — pulled into one calm workspace.",
            notes: "Shipping target end of June. Sidebar spec is the last blocker. Andy is owning visual, Mei is owning the data model. Linus signs off Friday.\n\nOpen questions: do we ship dark mode at v1? How do widgets fit?",
            tag: "Shipping June",
            members: ["L", "M", "A"].compactMap { peopleByToken[$0] },
            createdAt: makeDate(year: 2026, month: 4, day: 12)
        )
        let projectOnboarding = Project(
            title: "Onboarding redesign",
            intro: "Cut the first-run flow from 7 screens to 3. Lean on empty states that teach instead of explain.",
            notes: "Concept locked. Mei drafting copy v2 — due before Fri crit.",
            tag: "In review",
            members: ["M", "J"].compactMap { peopleByToken[$0] },
            createdAt: makeDate(year: 2026, month: 5, day: 3)
        )
        let projectQ3 = Project(
            title: "Q3 planning",
            intro: "Align the team on three bets for the quarter. Draft → review → commit.",
            notes: "Drafts are in. Final commit review on Wed.",
            tag: "Almost done",
            members: ["L", "M", "A", "J", "K"].compactMap { peopleByToken[$0] },
            createdAt: makeDate(year: 2026, month: 5, day: 15)
        )
        context.insert(projectLinoJ)
        context.insert(projectOnboarding)
        context.insert(projectQ3)
        let projectByKey: [String: Project] = [
            "linoj": projectLinoJ,
            "onboarding": projectOnboarding,
            "q3": projectQ3,
        ]

        // 3) Personal todos —— 7 项。scope 全部 .personal，project 全部 nil。
        let personalTodos: [(String, Urgency, Bool)] = [
            ("Read《人类简史》Ch. 3", .normal, false),
            ("Renew gym membership", .normal, false),
            ("Pick up dry cleaning", .normal, false),
            ("Buy birthday gift for L", .normal, false),
            ("Reply to mom", .urgent, false),
            ("Move savings into HYSA", .urgent, false),
            ("Schedule dentist", .normal, true),
        ]
        for (title, urgency, done) in personalTodos {
            let todo = Todo(
                title: title,
                urgency: urgency,
                scope: .personal,
                project: nil,
                done: done
            )
            context.insert(todo)
        }

        // 4) Work todos —— 9 项。scope 全部 .company，project 用 data.js 的 key 查询。
        let workTodos: [(title: String, urgency: Urgency, done: Bool, projectKey: String?)] = [
            ("Submit Q1 expense report", .urgent, false, nil),
            ("Review legal redlines", .normal, false, nil),
            ("Approve design system PR", .normal, false, nil),
            ("Finalize macOS sidebar spec", .urgent, false, "linoj"),
            ("Review onboarding copy v2", .urgent, false, "onboarding"),
            ("Sync with @Mei on launch deck", .normal, false, "q3"),
            ("Polish empty states", .normal, false, "linoj"),
            ("Audit color tokens", .normal, false, "linoj"),
            ("Draft Q3 OKR doc", .normal, true, "q3"),
        ]
        for spec in workTodos {
            let todo = Todo(
                title: spec.title,
                urgency: spec.urgency,
                scope: .company,
                project: spec.projectKey.flatMap { projectByKey[$0] },
                done: spec.done
            )
            context.insert(todo)
        }

        // 5) Events —— 16 项。day key 通过 dayOffset 表查出绝对天，
        // start / end 通过 hoursDecimalToDate 转 Date。
        // dayOffset 表对应 data.js weekDays：[Tue=0, Wed=1, Thu=2, Fri=3, Sat=4, Sun=5, Mon2=6]。
        let dayOffsetByKey: [String: Int] = [
            "Tue": 0, "Wed": 1, "Thu": 2, "Fri": 3,
            "Sat": 4, "Sun": 5, "Mon2": 6,
        ]
        struct EventSpec {
            let title: String
            let day: String
            let start: Double
            let end: Double
            let location: String
            let who: [String]
            let projectKey: String?
        }
        let events: [EventSpec] = [
            EventSpec(title: "Morning standup", day: "Tue", start: 9.5, end: 10, location: "Zoom",
                     who: ["M", "A", "J"], projectKey: "linoj"),
            EventSpec(title: "1:1 with Mei", day: "Tue", start: 11, end: 11.5, location: "Blue Bottle, Hayes",
                     who: ["M"], projectKey: nil),
            EventSpec(title: "Design review — sidebar", day: "Tue", start: 14, end: 15, location: "Conf Rm A",
                     who: ["M", "A"], projectKey: "linoj"),
            EventSpec(title: "Dinner with parents", day: "Tue", start: 19, end: 20.5, location: "Home",
                     who: ["Mom", "Dad"], projectKey: nil),
            EventSpec(title: "Onboarding crit", day: "Wed", start: 10, end: 11, location: "Conf Rm C",
                     who: ["M", "J"], projectKey: "onboarding"),
            EventSpec(title: "Q3 commit review", day: "Wed", start: 15, end: 16.5, location: "Conf Rm A",
                     who: ["L", "M", "A", "J"], projectKey: "q3"),
            EventSpec(title: "Yoga", day: "Wed", start: 18.5, end: 19.5, location: "Mission Studio",
                     who: [], projectKey: nil),
            EventSpec(title: "Eng sync", day: "Thu", start: 9, end: 10, location: "Zoom",
                     who: ["M", "K"], projectKey: "linoj"),
            EventSpec(title: "Lunch w/ Andrew", day: "Thu", start: 12, end: 13, location: "Tartine",
                     who: ["Andrew"], projectKey: nil),
            EventSpec(title: "Shipping retro", day: "Fri", start: 14, end: 15, location: "Conf Rm B",
                     who: ["M", "A", "J", "K"], projectKey: "linoj"),
            EventSpec(title: "Therapy", day: "Fri", start: 17, end: 18, location: "Mission St",
                     who: [], projectKey: nil),
            EventSpec(title: "Brunch with K", day: "Sat", start: 11, end: 13, location: "Tartine Manufactory",
                     who: ["K"], projectKey: nil),
            EventSpec(title: "Long run", day: "Sat", start: 7.5, end: 9, location: "Crissy Field",
                     who: [], projectKey: nil),
            EventSpec(title: "Call with parents", day: "Sun", start: 10, end: 11, location: "FaceTime",
                     who: ["Mom", "Dad"], projectKey: nil),
            EventSpec(title: "LinoJ kickoff v2", day: "Mon2", start: 10, end: 11.5, location: "Conf Rm A",
                     who: ["L", "M", "A", "J"], projectKey: "linoj"),
            EventSpec(title: "Dentist", day: "Mon2", start: 15.5, end: 16.5, location: "Pacific Dental",
                     who: [], projectKey: nil),
        ]
        for spec in events {
            let offset = dayOffsetByKey[spec.day] ?? 0
            let dayDate = Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
            let startDate = hoursDecimalToDate(day: dayDate, decimal: spec.start)
            let endDate = hoursDecimalToDate(day: dayDate, decimal: spec.end)
            let event = Event(
                title: spec.title,
                start: startDate,
                end: endDate,
                location: spec.location,
                attendees: spec.who.compactMap { peopleByToken[$0] },
                project: spec.projectKey.flatMap { projectByKey[$0] },
                attendedConfirmed: false
            )
            context.insert(event)
        }

        // 6) Yesterday events —— y1 / y2，绝对时间落在 yesterday，attendedConfirmed = false。
        let yesterdaySpecs: [EventSpec] = [
            EventSpec(title: "Engineering standup", day: "Y", start: 9.5, end: 10, location: "Zoom",
                     who: ["M", "A"], projectKey: "linoj"),
            EventSpec(title: "Coffee with Andrew", day: "Y", start: 15, end: 16, location: "Sightglass",
                     who: ["Andrew"], projectKey: nil),
        ]
        for spec in yesterdaySpecs {
            let startDate = hoursDecimalToDate(day: yesterday, decimal: spec.start)
            let endDate = hoursDecimalToDate(day: yesterday, decimal: spec.end)
            let event = Event(
                title: spec.title,
                start: startDate,
                end: endDate,
                location: spec.location,
                attendees: spec.who.compactMap { peopleByToken[$0] },
                project: spec.projectKey.flatMap { projectByKey[$0] },
                attendedConfirmed: false
            )
            context.insert(event)
        }

        // 7) Notes —— U1（v1.1）灵感版块示例。仅纯本地 seed 路径（与上方 seed 同处，
        //    cloud ON 不 seed，遵 CLAUDE.md seed 竞态约束）。2 条示例，1 条置顶。
        //    正文用纯文本 AttributedString；首行作 displayTitle。
        let seedNotes: [(body: String, isPinned: Bool)] = [
            ("Sidebar spec ideas\nThree columns, collapsible. Pin the calendar to the right rail.", true),
            ("Weekend reading\n《人类简史》Ch. 3 — note the cognitive revolution argument.", false),
        ]
        for spec in seedNotes {
            let note = Note(body: AttributedString(spec.body), isPinned: spec.isPinned)
            context.insert(note)
        }

        // 一次性持久化全部 insert。失败抛错让 App 启动早期就 surface 出来。
        try context.save()

        // F2 修复：SwiftData 关系数组（to-many）在 fetch 时是 fault 状态，第一次 .count
        // 读取可能返回 0（fault 未实体化）。在 seed 完 save 后主动触发一次 members fault
        // 实体化，整个 container 之后对该 project 的 members 读取都稳定。
        // 不需要保留任何引用 —— 调用 `.count` / 访问 `.first` 即可触发 SwiftData 内部把
        // 关系数组完整加载到内存。
        for project in [projectLinoJ, projectOnboarding, projectQ3] {
            _ = (project.members ?? []).count
            _ = (project.todos ?? []).count
            _ = (project.events ?? []).count
        }
    }

    // MARK: - Tiny utilities

    /// 取当地日历下的「这一天 00:00」。
    private static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// 用 y/m/d 构造一个本地日历的 Date（时分秒 = 0）。
    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }
}
#endif
