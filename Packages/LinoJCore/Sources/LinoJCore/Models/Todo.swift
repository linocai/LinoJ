// Todo.swift
// Todo 是无时间的待办。NON-NEGOTIABLE：**没有 due date / today / tomorrow / overdue**。
// createdAt 仅用于排序；completedAt（v1.2）仅记录「何时完成」用于 CompletedBox 近 30 天分层 ——
// 两者都不是「钟」（不参与提醒 / 不渲染为日程），墙不动：要绑钟就是 Event。
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

    /// v1.2 P5：完成时刻。`toggleDone` 置 `done=true` 时写 `.now`，置 `false` 时清 `nil`。
    /// 支撑 CompletedBox「近 30 天 recent / 更早 archive」分层（不删任何 completed todo）。
    /// optional（`Date?`）→ CloudKit 合规；加此字段触发轻量 schema 演进（旧 store 升级见真机清单）。
    /// 存量旧 done todo 的 `completedAt == nil` 归 recent（不丢失，见 VM 分层逻辑）。
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        urgency: Urgency,
        scope: Scope,
        project: Project? = nil,
        done: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.urgencyRaw = urgency.rawValue
        self.scopeRaw = scope.rawValue
        self.project = project
        self.done = done
        self.createdAt = createdAt
        self.completedAt = completedAt
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
