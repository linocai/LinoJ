// Note.swift
// U1（v1.1）：灵感版块的核心数据模型 —— 一条富文本笔记，照抄苹果备忘录 MVP。
//
// 设计决策（plan U1，定死）：
//   - 富文本正文不以 String 存储，而是把 `AttributedString` 编码成 `Data`（字段 `bodyData`）落库，
//     读写统一走 `body` computed property（编解码失败兜底空串），上层永不直接碰 `bodyData`。
//   - 标题不单独存字段 —— 由正文首行派生（`displayTitle`），避免「title 与正文首行不一致」的同步冲突；
//     列表与搜索都用 `displayTitle`，空正文回退本地化「新笔记 / New note」。
//   - MVP **无任何关系字段**（不挂 person / project / folder，延后 v1.2+）。
//
// CloudKit 硬约束（plan U1「Note 模型 CloudKit 硬约束清单」，逐条满足 —— 漏一条在真机加载
// `.private` 容器时 fatalError，而 `inMemory + .none` 单测抓不到，必须真机验证容器加载）：
//   1. 非 optional 标量必须有默认值：`id / bodyData / isPinned / createdAt / updatedAt` 全带默认值。✅
//   2. 关系全 optional：MVP 无关系字段，天然满足。
//      ⚠️ 未来若加 `project: Project?` / `people: [Person]?` 必须 optional 且双向 inverse（v1.2+），
//      否则 `.private` 容器 fatalError「CloudKit integration requires that all relationships be optional」。
//   3. 禁 `@Attribute(.unique)`：`id` 靠 UUID 自然唯一（与既有模型一致），不标 unique。✅
//   4. `bodyData: Data` 字段：CloudKit 当 bytes 存储无特殊约束；MVP 富文本不含图片，体积可控。
//   5. `updatedAt` 是「列表按编辑时间倒序」排序键 + CloudKit 冲突 last-writer-wins —— 每次
//      `body` / `isPinned` 变更必须重算 `updatedAt = .now`（写回纪律在 U2 ViewModel 落地）。
//   6. schema 迁移：加新实体是兼容变更，SwiftData 走 lightweight migration（不动既有 4 实体）。
//   7. CloudKit 生产 schema 上线前须把含 Note record type 的 schema 从 Development → Production 重新 deploy（U10）。

import Foundation
import SwiftData

@Model
public final class Note {
    /// 持久化主键。CloudKit 不允许 `@Attribute(.unique)`，靠 UUID 自然唯一保证。
    public var id: UUID = UUID()

    /// 富文本正文，编码成 Data 落库。读写请走 `body` computed property，上层不直接碰。
    /// CloudKit 约束需默认值（空 Data）。
    public var bodyData: Data = Data()

    /// 是否置顶。置顶组恒在列表上方（U2 排序）。CloudKit 约束需默认值。
    public var isPinned: Bool = false

    /// 创建时间。CloudKit 约束需默认值。
    public var createdAt: Date = Date.now

    /// 列表倒序排序键 + CloudKit 冲突 last-writer-wins。每次编辑必须重写（U2 ViewModel 负责）。
    /// CloudKit 约束需默认值。
    public var updatedAt: Date = Date.now

    public init(
        id: UUID = UUID(),
        body: AttributedString = AttributedString(),
        isPinned: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bodyData = Note.encode(body)
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 富文本正文。`bodyData` ⇄ `AttributedString` 编解码，失败兜底空串。
    /// 不直接读写 `bodyData`，所有正文访问走这里。
    public var body: AttributedString {
        get { Note.decode(bodyData) }
        set { bodyData = Note.encode(newValue) }
    }

    /// 列表 / 搜索显示标题：取正文纯文本首个非空行（trim 后），全空则回退本地化「新笔记 / New note」。
    public var displayTitle: String {
        let plain = String(body.characters)
        for line in plain.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return String(localized: LJStrings.noteUntitled)
    }

    // MARK: - AttributedString ⇄ Data 编解码（失败兜底空串）

    /// 把 `AttributedString` 编码成 `Data`；失败回空 `Data`（对应空正文）。
    static func encode(_ value: AttributedString) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    /// 把 `Data` 解码回 `AttributedString`；空 / 损坏数据兜底为空串。
    static func decode(_ data: Data) -> AttributedString {
        guard !data.isEmpty else { return AttributedString() }
        return (try? JSONDecoder().decode(AttributedString.self, from: data)) ?? AttributedString()
    }
}
