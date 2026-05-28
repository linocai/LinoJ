// Person.swift
// Person 是 attendee / member 的轻量实体：只保存 id + name。
//
// 设计稿里 avatar 显示首字母（"M" / "A" / "Mom" → "M"），所以加一个
// `initial` 计算属性集中产生，避免 UI 各处重复 `String(name.prefix(1)).uppercased()`。
//
// V1（CloudKit）约束：
//   - 标量 `name` 必须有默认值（`= ""`），CloudKit 字段可缺失，SwiftData 需能用默认值填充。
//   - CloudKit 要求每个关系**双向声明 inverse**，且**所有关系（含 to-many）必须 optional**。
//     v0.9 的 `Project.members` 与 `Event.attendees` 是单向 to-many（Person 侧无 inverse），
//     CloudKit 会拒绝同步。这里补两条 inverse 关系：`memberOf`（被哪些 Project 当成员）+
//     `attending`（参加哪些 Event）。两条都 to-many、类型 `[X]?`（optional），deleteRule
//     默认 `.nullify`（删 Person 不级联删 Project/Event）。

import Foundation
import SwiftData

@Model
public final class Person {
    /// 持久化主键。CloudKit 不允许 `@Attribute(.unique)`，靠 UUID 自然唯一保证。
    public var id: UUID = UUID()

    /// 显示名。可以是单字母代号（"M"）也可以是完整名（"Andrew"），
    /// avatar 一律取首字母大写。V1：CloudKit 约束需默认值。
    public var name: String = ""

    /// 反向关系（V1 CloudKit 要求 inverse）：本 Person 作为成员归属的 Project 列表。
    /// 与 `Project.members` 互为 inverse。删除 Person 时 nullify（不级联删 Project）。
    /// V1：CloudKit 要求 to-many 关系 optional，类型为 `[Project]?`。
    @Relationship(deleteRule: .nullify, inverse: \Project.members)
    public var memberOf: [Project]?

    /// 反向关系（V1 CloudKit 要求 inverse）：本 Person 作为参与人参加的 Event 列表。
    /// 与 `Event.attendees` 互为 inverse。删除 Person 时 nullify（不级联删 Event）。
    /// V1：CloudKit 要求 to-many 关系 optional，类型为 `[Event]?`。
    @Relationship(deleteRule: .nullify, inverse: \Event.attendees)
    public var attending: [Event]?

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    /// Avatar 显示的单字符 initial（大写）。
    public var initial: String {
        String(name.prefix(1)).uppercased()
    }
}
