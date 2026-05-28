// Todo.swift
// Todo 是无时间的待办。NON-NEGOTIABLE：不存任何时间字段（除 createdAt 用于排序）。
//
// 关于 urgency / scope：
//   SwiftData 对 `@Model` 的 enum 属性支持取决于版本；为了稳妥地跨 light/dark schema 与
//   未来 CloudKit 编解码，我们把枚举原始值存为 `String`（`urgencyRaw` / `scopeRaw`），
//   再用 computed property 暴露强类型枚举给上层。get 用 `init(rawValue:) ?? .normal` 兜底，
//   永不抛错；set 直接写 raw。

import Foundation
import SwiftData

// V1（CloudKit）约束：
//   - 所有非 optional 标量必须有默认值（`title/urgencyRaw/scopeRaw/done/createdAt`）。
//   - to-one `project: Project?` 已 optional；其 inverse 在 `Project.todos` 侧声明。
//   - enum 存 raw String 已合规，CloudKit 视作 String 字段。无 `@Attribute(.unique)`。
@Model
public final class Todo {
    /// 持久化主键。CloudKit 不允许 `@Attribute(.unique)`，靠 UUID 自然唯一保证。
    public var id: UUID = UUID()

    /// Todo 标题，单行。V1：CloudKit 约束需默认值。
    public var title: String = ""

    /// `Urgency` 的原始字符串值。读写请走 `urgency` 计算属性。V1：默认 normal 的 raw。
    public var urgencyRaw: String = Urgency.normal.rawValue

    /// `Scope` 的原始字符串值。读写请走 `scope` 计算属性。V1：默认 personal 的 raw。
    public var scopeRaw: String = Scope.personal.rawValue

    /// 所属项目；`nil` 表示 standalone（或 personal scope）。
    @Relationship public var project: Project?

    /// 是否完成。完成后进入 CompletedBox。V1：CloudKit 约束需默认值。
    public var done: Bool = false

    /// 创建时间，用于按时间排序（虽然 UI 默认按 urgent → normal 分列，但同列内仍按创建时间）。
    /// V1：CloudKit 约束需默认值。
    public var createdAt: Date = Date.now

    public init(
        id: UUID = UUID(),
        title: String,
        urgency: Urgency,
        scope: Scope,
        project: Project? = nil,
        done: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.urgencyRaw = urgency.rawValue
        self.scopeRaw = scope.rawValue
        self.project = project
        self.done = done
        self.createdAt = createdAt
    }

    /// 强类型 urgency。读取时若 raw 损坏，兜底为 `.normal`。
    public var urgency: Urgency {
        get { Urgency(rawValue: urgencyRaw) ?? .normal }
        set { urgencyRaw = newValue.rawValue }
    }

    /// 强类型 scope。读取时若 raw 损坏，兜底为 `.personal`。
    public var scope: Scope {
        get { Scope(rawValue: scopeRaw) ?? .personal }
        set { scopeRaw = newValue.rawValue }
    }
}
