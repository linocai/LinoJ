// Project.swift
// Project 只属于 Company scope，是若干 Todo + Event 的容器。
//
// 关键设计点：
//   - members 是 `[Person]`，删除 Person 不级联（让用户在 People 管理面板手动处理，v0.9 没那面板，但语义先稳）；
//   - todos / events 用反向关系，删除 Project 时把对应 Todo.project / Event.project 置 nil（`.nullify`），
//     不删除 Todo / Event 本身 —— 因为 todo 失去 project 后仍是合法的 standalone work todo。
//
// V1（CloudKit）约束：
//   - 所有非 optional 标量必须有默认值（`title/intro/notes/tag/memberCount/createdAt`）。
//   - 所有关系必须 optional —— **包括 to-many**（CloudKit 要求所有 relationship optional，
//     `members/todos/events` 类型为 `[X]?`，构造时给空数组而非 nil）。
//   - `members` 与 `Person.memberOf` 互为 inverse（CloudKit 要求双向）；inverse 声明放在
//     Person 侧（`@Relationship(inverse: \Project.members)`）。
//   - 无 `@Attribute(.unique)`（CloudKit 不支持）。

import Foundation
import SwiftData

@Model
public final class Project {
    /// 持久化主键。CloudKit 不允许 `@Attribute(.unique)`，靠 UUID 自然唯一保证。
    public var id: UUID = UUID()

    /// 项目标题，单行。V1：CloudKit 约束需默认值。
    public var title: String = ""

    /// 1-2 句 intro，卡片副标题位。
    public var intro: String = ""

    /// 长文 notes，保留换行（UI 用 `\n\n` 渲染段落）。
    public var notes: String = ""

    /// 自由文本状态标签（"Shipping June" / "In review" / "Almost done"…）。
    public var tag: String = ""

    /// 项目成员；删除 Person 不级联到 Project，反之亦然。
    /// V1：与 `Person.memberOf` 互为 inverse（inverse 声明在 Person 侧）。CloudKit 要求关系 optional，
    /// 类型为 `[Person]?`，构造时给空数组。
    @Relationship public var members: [Person]?

    /// F2 修复：冗余存的 members 计数，避免 SwiftData to-many fault 引发
    /// `members.count` 偶发返回 0/2/3。写入 members 时同步维护这个值（在 init / 后续
    /// add/remove 操作时更新；V5 的 Edit project 流程每次改 members 都重写 memberCount，
    /// CloudKit 同步它作为普通 Int 字段，last-writer-wins）。V1：CloudKit 约束需默认值。
    public var memberCount: Int = 0

    /// 创建时间，用于 "since Apr 12" 这类副标题。V1：CloudKit 约束需默认值。
    public var createdAt: Date = Date.now

    /// 反向关系：归属本项目的 Todo。删除 Project 时把 Todo.project 置 nil。
    /// V1：CloudKit 要求 to-many 关系 optional，类型为 `[Todo]?`。
    @Relationship(deleteRule: .nullify, inverse: \Todo.project)
    public var todos: [Todo]?

    /// 反向关系：归属本项目的 Event。删除 Project 时把 Event.project 置 nil。
    /// V1：CloudKit 要求 to-many 关系 optional，类型为 `[Event]?`。
    @Relationship(deleteRule: .nullify, inverse: \Event.project)
    public var events: [Event]?

    public init(
        id: UUID = UUID(),
        title: String,
        intro: String,
        notes: String,
        tag: String,
        members: [Person]? = [],
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.intro = intro
        self.notes = notes
        self.tag = tag
        self.members = members
        // F2：同步维护 memberCount —— 此处 init 时的 count 一定准确（数组刚被赋值）。
        self.memberCount = (members ?? []).count
        self.createdAt = createdAt
        // todos / events 由反向关系自动维护，初始化为空数组让 SwiftData 接管。
        self.todos = []
        self.events = []
    }
}
