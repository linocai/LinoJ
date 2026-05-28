// ModelContainer+LinoJ.swift
// `LinoJStore` 是 SwiftData ModelContainer 的工厂入口。两端 App 启动时调用 `makeContainer(...)`
// 注入 SwiftUI 环境，测试用 `makeContainer(inMemory: true)` 拿一个临时容器。
//
// V1（CloudKit）行为变更：
//   - `inMemory == true`（测试 / preview）：永远 `cloudKitDatabase: .none`，本地内存，**绝不连云**
//     （否则测试会尝试连真实 CloudKit 容器导致挂起 / 失败）。
//   - `inMemory == false`（App 运行）：由 `cloudSyncEnabled` 决定：
//       * `true`  → `cloudKitDatabase: .private(LinoJCloudKit.containerID)`，SwiftData 自动建
//         `NSPersistentCloudKitContainer`，跨端同步到 `iCloud.com.linocai.linoj` private database。
//       * `false` → `cloudKitDatabase: .none`，纯本地磁盘 store，不连云。
//   - 运行时切换 iCloud toggle **不热切容器**（SwiftData 不支持运行时改 `cloudKitDatabase`）。
//     toggle 持久化到 UserDefaults，下次 App 启动时 `makeContainer` 读取决定 `.private` / `.none`，
//     当次会话不重建容器（plan V1 决策：OFF 需重启生效）。
//
// 关键约束：
//   - schema 必须把所有 `@Model` 类型一次性列全；漏列会在第一次 fetch 时 trap。
//   - 所有 `@Model` 已按 plan V1「CloudKit 硬约束清单」改造（标量带默认值、to-many `= []`、
//     关系双向 inverse、无 `@Attribute(.unique)`），否则 `.private` 路径会在运行时 reject 同步。

import Foundation
import SwiftData

public enum LinoJStore {
    /// 构造 LinoJ 的 SwiftData 容器。
    ///
    /// - Parameters:
    ///   - inMemory: `true` 时仅在内存中存储，重启即失（测试 / preview 用），且强制 `.none` 不连云。
    ///   - cloudSyncEnabled: 仅当 `inMemory == false` 时生效。`true` 走 CloudKit private database
    ///     同步；`false` 走纯本地磁盘 store。默认 `true`（plan V1：iCloud sync 默认 ON）。
    /// - Returns: 配置好的 `ModelContainer`，可注入 SwiftUI `.modelContainer(_:)`。
    /// - Throws: SwiftData 初始化失败时抛错（通常是 schema 不一致或磁盘写入受限）。
    ///
    /// `@MainActor` 限定是为了配合 Swift 6 strict concurrency：
    /// `ModelContainer` 本身 Sendable，但首次创建涉及主线程 SwiftUI 环境读取。
    @MainActor
    public static func makeContainer(
        inMemory: Bool = false,
        cloudSyncEnabled: Bool = true
    ) throws -> ModelContainer {
        let schema = Schema([
            Person.self,
            Project.self,
            Todo.self,
            Event.self,
        ])

        // 解析 cloudKitDatabase：
        //   inMemory 永远 .none（测试不连真实 CloudKit）；
        //   非 inMemory 时由 cloudSyncEnabled 决定 .private(container) / .none。
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase
        if inMemory {
            cloudKitDatabase = .none
        } else {
            cloudKitDatabase = cloudSyncEnabled
                ? .private(LinoJCloudKit.containerID)
                : .none
        }

        let config = ModelConfiguration(
            "LinoJStore",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKitDatabase
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
