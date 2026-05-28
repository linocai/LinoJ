// Event.swift
// Event 必带时间 + 地点 + 人。NON-NEGOTIABLE：没有 todo 字段。
//
// `attendedConfirmed` 用于 README 中的「From yesterday」box —— 昨日已结束但用户未确认参加的
// event 会出现在 Main 与 Calendar 的 dashed-border 小框中等待 checkoff。
//
// V1（CloudKit）约束：
//   - 所有非 optional 标量必须有默认值（`title/start/end/location/attendedConfirmed`）。
//   - to-many `attendees` 必须 optional（CloudKit 要求所有关系 optional，类型 `[Person]?`），
//     且与 `Person.attending` 互为 inverse（inverse 声明在 Person 侧）。
//   - to-one `project: Project?` 已 optional；其 inverse 在 `Project.events` 侧声明。
//   - 无 `@Attribute(.unique)`（CloudKit 不支持）。

import Foundation
import SwiftData

@Model
public final class Event {
    /// 持久化主键。CloudKit 不允许 `@Attribute(.unique)`，靠 UUID 自然唯一保证。
    public var id: UUID = UUID()

    /// 事件标题。V1：CloudKit 约束需默认值。
    public var title: String = ""

    /// 起始时间（绝对时间，含时区信息）。V1：CloudKit 约束需默认值。
    public var start: Date = Date.now

    /// 结束时间。需保证 `end >= start`，但 schema 不强约束（由 ViewModel 校验）。
    public var end: Date = Date.now

    /// 地点字符串。可以是 "Zoom"、"Conf Rm A"、"Tartine Manufactory" 等任意自由文本。
    public var location: String = ""

    /// 参与人。删除 Person 不影响 Event 存在。
    /// V1：与 `Person.attending` 互为 inverse（inverse 声明在 Person 侧）。CloudKit 要求关系 optional，
    /// 类型为 `[Person]?`，构造时给空数组。
    @Relationship public var attendees: [Person]?

    /// 关联项目（可选）。删除 Project 时由 Project.events 反向关系 nullify。
    @Relationship public var project: Project?

    /// 是否已被用户确认 "我参加了"。
    /// 默认 `false`；用户在 Main / Calendar 的 yesterday-missed box 中勾选后置为 true。
    /// V1：CloudKit 约束需默认值。
    public var attendedConfirmed: Bool = false

    public init(
        id: UUID = UUID(),
        title: String,
        start: Date,
        end: Date,
        location: String,
        attendees: [Person]? = [],
        project: Project? = nil,
        attendedConfirmed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.attendees = attendees
        self.project = project
        self.attendedConfirmed = attendedConfirmed
    }
}
