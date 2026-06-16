// QuickAddViewModel.swift
// Quick Add modal/sheet 背后的 ViewModel —— plan P3.6 唯一实体。
//
// 设计要点：
//   - 单 VM 同时承载 3 种 Kind（todo / event / project）的表单字段，UI 在 segmented control
//     切 kind 时无需重建 VM，只切显示分支。canSubmit / submit() 内部按 kind 路由。
//   - prefilledProject：调用方（Calendar 的 `+ New event`、Company project detail 的 `+ Add todo`
//     等）可以预填某个 project，作用域：
//       * kind == .todo → 同时把 scope 预设为 .company 并把 todoProject 设为该 project；
//       * kind == .event → 把 eventProject 设为该 project；
//       * kind == .project → 不适用（忽略）。
//   - scope == .personal 时 todoProject 自动置 nil（schema 不强约束，由 VM 在 setter 钩子里清空），
//     UI 上 Project chip row 同时 disable + opacity 0.5。
//   - canSubmit 规则（plan P3.6）：
//       * todo: title.trim 非空；
//       * event: title 非空 && end > start；
//       * project: title 非空。
//   - submit() 在 context 里 insert 新 @Model 实例 → try context.save() → 返回新对象的 id（AnyHashable）。
//     失败时 throws 让上层弹错误提示（macOS 当前直接关闭 sheet，iOS 同；详细错误展示留 v1.0）。
//   - V5 Edit project 模式（editingProject 非 nil）：
//       * init 时强制 kind=.project（edit 只编辑 Project；Todo/Event edit 不在 V5 范围），
//         把既有 project 的 title/intro/tag/members 预填进对应字段，记录 editingProjectID；
//       * UI 通过 isEditing 锁死 segmented control（不允许切 kind）+ 标题/按钮文案切「Edit / Save」；
//       * submit() 走 update 分支：按 editingProjectID 反查该 project，回写 title/intro/tag/members
//         + 重算 memberCount（Reviewer F2 冗余字段，编辑 members 后必须同步，否则 CloudKit 出脏数据），
//         不创建新对象，返回原 project.id；
//       * notes 字段当前 Project 表单没有输入（create 路径硬编码 ""），edit 模式同样不回写 notes，
//         保留既有 notes 原值不动（见变更日志 V5）。
//   - W4 Edit event 模式（editingEvent 非 nil）：与 editingProject 完全对称：
//       * init 时强制 kind=.event（无视 defaultKind），把既有 event 的 title/start/end/location/
//         attendees/project 预填进对应字段（start 同时灌 eventDate 取日期 + eventStart 取时分，
//         end 灌 eventEnd），记录 editingEventID；与 editingProject 互斥（同一时刻只设一个）；
//       * UI 通过 isEditingEvent / isEditingAny 锁/切标题与按钮文案（Edit event / Save）；
//       * submit() 的 .event 分支：按 editingEventID 反查既有 event，原地回写
//         title/start/end/location/attendees(类型 [Person]? 兜底)/project，不创建新对象，返回原 id；
//         fetch 不到（极端：edit 期间被删/跨端同步删除）回退为创建，避免静默丢输入（与 project edit 同构）；
//       * 不动 memberCount（事件编辑不触碰 Project.members）。

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class QuickAddViewModel {

    // MARK: - Nested types

    /// Quick Add 当前正在编辑的实体类型。
    public enum Kind: Hashable, Sendable {
        case todo
        case event
        case project
    }

    // MARK: - Stored

    private let context: ModelContext

    /// 当前 segmented control 选中的 kind。
    public var kind: Kind

    // MARK: Todo fields

    public var todoTitle: String = ""
    public var todoUrgency: Urgency = .normal
    public var todoScope: Scope = .personal {
        didSet {
            // scope=.personal 不允许挂 project（README NON-NEGOTIABLE）；
            // 切回 personal 时主动清空，UI 同时 disable picker。
            if todoScope == .personal {
                todoProject = nil
            }
        }
    }
    public var todoProject: Project? {
        didSet {
            // P1：选了一个非 nil project ⇒ 自动锁 scope=.company（让「personal + project」
            // 这个非法态从根上 unrepresentable）。与 `todoScope=.personal → todoProject=nil`
            // 的 didSet 形成双向闭环。
            //
            // 防 didSet 互触发死循环：仅在「非 nil」时回设 company。切回 personal 时
            // scope didSet 把 todoProject 清成 nil，nil 不命中这里的分支，故不会再反弹回 company。
            if todoProject != nil {
                todoScope = .company
            }
        }
    }

    // MARK: Event fields

    public var eventTitle: String = ""
    /// 仅日期部分（hour/minute 已在 init 时清零，由 UI DatePicker 用 `.date` 显示）。
    public var eventDate: Date
    /// 起始时间（仅 hour/minute 部分，date 部分被 UI 通过 `.hourAndMinute` 控制；
    /// submit 时会把 eventDate + eventStart 的时分组合成最终 Date）。
    public var eventStart: Date
    /// 结束时间（同上规则）。
    public var eventEnd: Date
    public var eventLocation: String = ""
    public var eventAttendees: [Person] = []
    public var eventProject: Project?

    // MARK: Project fields

    public var projectTitle: String = ""
    public var projectIntro: String = ""
    public var projectTag: String = ""
    public var projectMembers: [Person] = []

    // MARK: Edit mode

    /// V5：非 nil 表示正在编辑既有 Project（edit 模式）；nil 表示 create 模式。
    /// 存 ID 而非 Project 引用，submit() 时按 ID 反查 —— 与跨 actor / 持久化语义解耦。
    public private(set) var editingProjectID: UUID?

    /// W4：非 nil 表示正在编辑既有 Event（edit 模式）；nil 表示 create 模式。
    /// 与 editingProjectID 互斥（同一时刻只设一个）。存 ID 而非 Event 引用，submit() 时按 ID 反查。
    public private(set) var editingEventID: UUID?

    /// 是否处于 Project edit 模式。UI 用它锁 segmented control + 切标题/按钮文案。
    /// W4：语义保持不变（= project edit），避免改动 V5 既有判断。
    public var isEditing: Bool { editingProjectID != nil }

    /// W4：是否处于 Event edit 模式。
    public var isEditingEvent: Bool { editingEventID != nil }

    /// W4：是否处于任一 edit 模式（project 或 event）。
    /// UI 用它统一判断「标题/按钮文案切 Edit/Save」+「隐藏/锁分段控件」。
    public var isEditingAny: Bool { isEditing || isEditingEvent }

    // MARK: - Init

    public init(
        context: ModelContext,
        defaultKind: Kind = .todo,
        prefilledProject: Project? = nil,
        defaultScope: Scope = .personal,
        editingProject: Project? = nil,
        editingEvent: Event? = nil
    ) {
        self.context = context
        // edit 模式强制 kind（无视 defaultKind）；否则用 defaultKind。
        // V5：editingProject → .project；W4：editingEvent → .event（二者互斥）。
        if editingProject != nil {
            self.kind = .project
        } else if editingEvent != nil {
            self.kind = .event
        } else {
            self.kind = defaultKind
        }
        // I5: 应用 Settings 中的 defaultTodoScope 默认值。
        // 注意：todoScope 的 didSet 在 `prefilledProject` 后会被覆盖（company + project），
        // 所以这里直接初始化 stored property，didSet 在 init 阶段不会触发。
        self.todoScope = defaultScope

        // Event 的默认时间窗：今天的下一个整点 ~ 整点 + 1h。
        // 这只是 UI 初值；用户在 DatePicker 里随时改。
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: now)
        let nextHour = cal.date(from: comps).flatMap {
            cal.date(byAdding: .hour, value: 1, to: $0)
        } ?? now
        let endHour = cal.date(byAdding: .hour, value: 1, to: nextHour) ?? nextHour

        self.eventDate = nextHour
        self.eventStart = nextHour
        self.eventEnd = endHour

        // 预填 project：todo 同时翻 scope=.company。
        // 注意：edit 模式下 kind 已强制为 .project，prefilledProject 不会命中 .todo/.event 分支。
        if let p = prefilledProject {
            switch self.kind {
            case .todo:
                self.todoScope = .company
                self.todoProject = p
            case .event:
                self.eventProject = p
            case .project:
                break
            }
        }

        // V5：edit 模式 —— 预填既有 Project 字段并记录 editingProjectID。
        // notes 当前表单无输入，故不预填也不回写（保留既有值）。
        if let editing = editingProject {
            self.editingProjectID = editing.id
            self.projectTitle = editing.title
            self.projectIntro = editing.intro
            self.projectTag = editing.tag
            self.projectMembers = editing.members ?? []
        }

        // W4：edit event 模式 —— 预填既有 Event 字段并记录 editingEventID。
        // 时间拆装：start 同时灌 eventDate（取日期）+ eventStart（取时分）；end 灌 eventEnd（取时分）。
        // attendees 为 [Person]?，`?? []` 兜底。
        if let editing = editingEvent {
            self.editingEventID = editing.id
            self.eventTitle = editing.title
            self.eventDate = editing.start
            self.eventStart = editing.start
            self.eventEnd = editing.end
            self.eventLocation = editing.location
            self.eventAttendees = editing.attendees ?? []
            self.eventProject = editing.project
        }
    }

    // MARK: - Validation

    /// 根据当前 kind 决定 Create 按钮是否可用。
    public var canSubmit: Bool {
        switch kind {
        case .todo:
            return !todoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .event:
            let titleOK = !eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            // end 必须严格大于 start。等于也不行（0 时长事件无意义）。
            return titleOK && composedEventEnd > composedEventStart
        case .project:
            return !projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Submit

    /// 创建对应实体并持久化，返回新对象的 id。失败时抛错（context.save 异常）。
    /// P6：成功 save 后触发 light haptic（iOS 真机有效，其它平台 no-op）。
    @discardableResult
    public func submit() throws -> AnyHashable {
        switch kind {
        case .todo:
            let todo = Todo(
                title: todoTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                urgency: todoUrgency,
                scope: todoScope,
                // 再次兜底：personal scope 时绝不挂 project。
                project: todoScope == .personal ? nil : todoProject,
                done: false,
                createdAt: .now
            )
            context.insert(todo)
            try context.save()
            LinoJHaptics.lightTap()
            return AnyHashable(todo.id)

        case .event:
            // W4：edit 模式走 update 分支 —— 反查既有 event，原地回写字段而非 insert 新对象。
            if let editingID = editingEventID {
                let target = editingID
                let descriptor = FetchDescriptor<Event>(
                    predicate: #Predicate { $0.id == target }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    // 极端情况：edit 期间该 event 被删（如跨端同步删除）。
                    // 回退为创建，避免静默丢用户输入（与 project edit 完全同构）。
                    let event = Event(
                        title: eventTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                        start: composedEventStart,
                        end: composedEventEnd,
                        location: eventLocation.trimmingCharacters(in: .whitespacesAndNewlines),
                        attendees: eventAttendees,
                        project: eventProject,
                        attendedConfirmed: false
                    )
                    context.insert(event)
                    try context.save()
                    LinoJHaptics.lightTap()
                    return AnyHashable(event.id)
                }
                existing.title = eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                existing.start = composedEventStart
                existing.end = composedEventEnd
                existing.location = eventLocation.trimmingCharacters(in: .whitespacesAndNewlines)
                // attendees 类型 [Person]?；直接赋当前已选数组（W1 选人器增删的结果）。
                existing.attendees = eventAttendees
                existing.project = eventProject
                // attendedConfirmed 不在编辑表单内，保留既有值不动（与 notes 同策略）。
                try context.save()
                LinoJHaptics.lightTap()
                return AnyHashable(existing.id)
            }

            let event = Event(
                title: eventTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                start: composedEventStart,
                end: composedEventEnd,
                location: eventLocation.trimmingCharacters(in: .whitespacesAndNewlines),
                attendees: eventAttendees,
                project: eventProject,
                attendedConfirmed: false
            )
            context.insert(event)
            try context.save()
            LinoJHaptics.lightTap()
            return AnyHashable(event.id)

        case .project:
            // V5：edit 模式走 update 分支 —— 反查既有 project，回写字段而非 insert 新对象。
            if let editingID = editingProjectID {
                let target = editingID
                let descriptor = FetchDescriptor<Project>(
                    predicate: #Predicate { $0.id == target }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    // 极端情况：edit 期间该 project 被删（如跨端同步删除）。
                    // 回退为创建，避免静默丢用户输入。
                    let project = Project(
                        title: projectTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                        intro: projectIntro,
                        notes: "",
                        tag: projectTag.trimmingCharacters(in: .whitespacesAndNewlines),
                        members: projectMembers,
                        createdAt: .now
                    )
                    context.insert(project)
                    try context.save()
                    LinoJHaptics.lightTap()
                    return AnyHashable(project.id)
                }
                existing.title = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                existing.intro = projectIntro
                existing.tag = projectTag.trimmingCharacters(in: .whitespacesAndNewlines)
                existing.members = projectMembers
                // F2：编辑 members 后必须重算冗余 memberCount，否则 CloudKit 同步脏数据（V1 约束 7）。
                existing.memberCount = projectMembers.count
                // notes 保留既有值不动（表单无 notes 输入）。
                try context.save()
                LinoJHaptics.lightTap()
                return AnyHashable(existing.id)
            }

            let project = Project(
                title: projectTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                intro: projectIntro,
                notes: "",
                tag: projectTag.trimmingCharacters(in: .whitespacesAndNewlines),
                members: projectMembers,
                createdAt: .now
            )
            context.insert(project)
            try context.save()
            LinoJHaptics.lightTap()
            return AnyHashable(project.id)
        }
    }

    // MARK: - People picker (W1)

    /// W1：选人器落点（Attendees / Members）的加入目标。
    public enum PersonTarget: Sendable {
        case attendee
        case member
    }

    // MARK: Attendees (Event)

    /// 切换某 Person 在 eventAttendees 中的选中态。
    /// 已选（按 `Person.id`）则移除，未选则加入；保证不重复（按 id 去重）。
    public func toggleAttendee(_ person: Person) {
        if let idx = eventAttendees.firstIndex(where: { $0.id == person.id }) {
            eventAttendees.remove(at: idx)
        } else {
            eventAttendees.append(person)
        }
    }

    /// 当前 Person 是否已在 eventAttendees 中（按 id）。
    public func isAttendeeSelected(_ person: Person) -> Bool {
        eventAttendees.contains { $0.id == person.id }
    }

    // MARK: Members (Project)

    /// 切换某 Person 在 projectMembers 中的选中态。
    /// 已选（按 `Person.id`）则移除，未选则加入；保证不重复（按 id 去重）。
    public func toggleMember(_ person: Person) {
        if let idx = projectMembers.firstIndex(where: { $0.id == person.id }) {
            projectMembers.remove(at: idx)
        } else {
            projectMembers.append(person)
        }
    }

    /// 当前 Person 是否已在 projectMembers 中（按 id）。
    public func isMemberSelected(_ person: Person) -> Bool {
        projectMembers.contains { $0.id == person.id }
    }

    // MARK: 临时新建 Person

    /// W1：在选人器内临时新建一个 Person 并立即选中。
    ///
    /// 行为（plan 契约）：
    ///   - `name` 内部 trim；trim 后为空白返回 nil（不创建、不选中）。
    ///   - 先在 `existing`（@Query 拉到的全部 Person）里按 trim + 小写查重名；命中则**复用**既有那条
    ///     （不 insert 新对象，避免重名 Person 在 CloudKit 无唯一约束下堆积），直接选中并返回。
    ///   - 未命中则 `Person(name:)` + `context.insert`，立即选中并返回。
    ///   - **不在此处 save**：临时新建的 Person 随 Quick Add 整体 `submit()` 落库；
    ///     若用户取消（dismiss 未 submit），W1 不强制回滚（个人级数据，残留一条无引用 Person 可接受）。
    ///   - 选中即调用对应 `toggleAttendee/toggleMember`（若已选则幂等：若复用的既有 Person 已在选中列表
    ///     里，会被 toggle 移除 —— 但「新建」语义下用户输入的是新名字、不会命中已选项；复用既有同名时
    ///     若恰已选中，则保持选中而非移除）。
    @discardableResult
    public func addPerson(named name: String, existing: [Person], target: PersonTarget) -> Person? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 查重名：trim + case-insensitive。
        let key = trimmed.lowercased()
        let person: Person
        if let match = existing.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key
        }) {
            person = match
        } else {
            let created = Person(name: trimmed)
            context.insert(created)
            person = created
        }

        // 选中：若尚未在目标列表里则加入（不用 toggle，避免「复用既有且恰已选」时被反选）。
        switch target {
        case .attendee:
            if !isAttendeeSelected(person) {
                eventAttendees.append(person)
            }
        case .member:
            if !isMemberSelected(person) {
                projectMembers.append(person)
            }
        }
        return person
    }

    // MARK: - Helpers

    /// 把 eventDate（取 y/m/d）与 eventStart（取 h/m）组合成最终 Date。
    /// 这样 UI 上 DatePicker 可以拆 date / time 两个组件，submit 时统一拼装。
    private var composedEventStart: Date {
        Self.compose(date: eventDate, time: eventStart)
    }
    private var composedEventEnd: Date {
        Self.compose(date: eventDate, time: eventEnd)
    }

    private static func compose(date: Date, time: Date) -> Date {
        let cal = Calendar.current
        let dateComps = cal.dateComponents([.year, .month, .day], from: date)
        let timeComps = cal.dateComponents([.hour, .minute], from: time)
        var combined = DateComponents()
        combined.year = dateComps.year
        combined.month = dateComps.month
        combined.day = dateComps.day
        combined.hour = timeComps.hour
        combined.minute = timeComps.minute
        return cal.date(from: combined) ?? date
    }
}
