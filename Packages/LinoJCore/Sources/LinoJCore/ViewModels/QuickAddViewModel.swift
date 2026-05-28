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
    public var todoProject: Project?

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

    /// 是否处于 Project edit 模式。UI 用它锁 segmented control + 切标题/按钮文案。
    public var isEditing: Bool { editingProjectID != nil }

    // MARK: - Init

    public init(
        context: ModelContext,
        defaultKind: Kind = .todo,
        prefilledProject: Project? = nil,
        defaultScope: Scope = .personal,
        editingProject: Project? = nil
    ) {
        self.context = context
        // V5：edit 模式强制 kind=.project（无视 defaultKind）；否则用 defaultKind。
        self.kind = editingProject == nil ? defaultKind : .project
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
