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
// U9（v1.1）App Group store 迁移：
//   - widget extension 进程访问不到 App 私有的 Application Support 目录，因此非 inMemory 时把
//     store **物理位置**移到 App Group 共享容器（`appGroupStoreURL()`），App 与 widget 用同一 URL
//     打开同一 store。
//   - 旧版（v1.0）用户数据在旧默认位置（named ModelConfiguration 的默认 url），切到 App Group URL
//     后旧 store 不会自动出现 → `migrateStoreToAppGroupIfNeeded()` 在建容器前把旧 store 整套文件
//     **拷贝**（非移动）到 App Group 容器；旧 store 永不删除，作为回退保险。
//   - **回退路径**：`appGroupStoreURL()` 返回 nil（entitlement 没配好 / containerURL 取不到）时，
//     `makeContainer` 不带 url 参数回退默认位置，保证 App 不因 App Group 配置问题而起不来。
//
// 关键约束：
//   - schema 必须把所有 `@Model` 类型一次性列全；漏列会在第一次 fetch 时 trap。
//   - 所有 `@Model` 已按 plan V1「CloudKit 硬约束清单」改造（标量带默认值、to-many `= []`、
//     关系双向 inverse、无 `@Attribute(.unique)`），否则 `.private` 路径会在运行时 reject 同步。

import Foundation
import SwiftData

public enum LinoJStore {

    // MARK: - U9：store 物理位置常量

    /// SwiftData 命名配置 `ModelConfiguration("LinoJStore", ...)` 实际落盘时的 store 基础文件名。
    ///
    /// 真机/真容器探测结论（v1.1 U9a 施工，2026-05-31）：
    ///   named 配置的默认 url 落在该进程的 Application Support 目录，文件名是 **`LinoJStore.store`**
    ///   （扩展名 `.store`，**不是** `.sqlite`），并带 `LinoJStore.store-wal` / `LinoJStore.store-shm`
    ///   两个 sidecar，以及与 store 同目录的辅助产物：`LinoJStore_ckAssets`（CloudKit 资源目录）和
    ///   `.LinoJStore_SUPPORT`（隐藏支持目录）——后两者的命名都从 store 基础名派生。
    ///
    /// 因此迁移目标也沿用同一基础名 `LinoJStore.store`（而非 plan 占位的 `LinoJStore.sqlite`），
    /// 让整套文件 1:1 同名拷贝、SwiftData 用同一基础名重算出一致的辅助目录名 —— 这是迁移成败关键，
    /// 避免「重命名 store 但辅助目录名对不上、wal 无法回放」的隐患。详见 PROJECT_PLAN.md 变更日志。
    public static let storeBaseName = "LinoJStore.store"

    /// 与 store 基础名一起需要搬运的所有相关文件 / 目录名（sidecar + 辅助目录）。
    /// 迁移时逐个探测实际存在的才拷（不存在的跳过，干净安装时大多只有 `.store` 主文件）。
    private static let storeCompanionNames: [String] = [
        "LinoJStore.store-wal",
        "LinoJStore.store-shm",
        "LinoJStore_ckAssets",     // CloudKit 资源目录（cloud ON 时存在）
        ".LinoJStore_SUPPORT",     // 隐藏支持目录
    ]

    /// 迁移时要探测 / 搬运的全部条目（主 store + companions）。
    private static var storeAllItemNames: [String] {
        [storeBaseName] + storeCompanionNames
    }

    /// U9：App Group store URL（两端 App 与 widget 共用）。
    /// `containerURL` 失败（entitlement 没配好 / 系统取不到）返回 nil → `makeContainer` fallback 默认位置。
    public static func appGroupStoreURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: LinoJAppGroup.id)?
            .appending(path: storeBaseName)
    }

    // MARK: - U9：旧 store 迁移（幂等 + 回退保险）

    /// U9：旧默认位置 store 迁到 App Group 容器（幂等；已迁移或无旧 store 则 no-op）。
    ///
    /// 逻辑：若 App Group 容器 URL 可取 且 容器内**无** store 文件、而旧默认位置**有** store →
    /// 把旧 store 连同所有 sidecar / 辅助目录 `copyItem` 拷到 App Group 容器；旧 store **保留不删**
    /// （回退保险）。已迁移（目标已存在）或无旧 store / 取不到 group URL → no-op。
    /// cloud ON/OFF 都执行（拷贝是无害本地操作）。
    ///
    /// 真实搬运逻辑抽到可注入源/目标目录的 `migrateStore(from:to:)`，本函数只负责喂真实 URL。
    @MainActor
    public static func migrateStoreToAppGroupIfNeeded() {
        guard let groupStoreURL = appGroupStoreURL() else {
            // App Group 容器取不到（entitlement 没配好等）→ 不迁移，makeContainer 会 fallback 默认位置。
            return
        }
        guard let oldStoreURL = legacyDefaultStoreURL() else {
            // 默认位置 URL 都取不到（极罕见）→ 放弃迁移。
            return
        }
        let groupDir = groupStoreURL.deletingLastPathComponent()
        let oldDir = oldStoreURL.deletingLastPathComponent()
        // 同目录（理论上不会发生，App Group 与默认位置不同）→ no-op，避免自拷自。
        guard groupDir.standardizedFileURL != oldDir.standardizedFileURL else { return }
        migrateStore(from: oldDir, to: groupDir)
    }

    /// 旧默认位置的 store URL：复刻 SwiftData 对 named 配置 `ModelConfiguration("LinoJStore", ...)`
    /// 的默认落盘位置 —— 该进程 Application Support 目录下的 `LinoJStore.store`。
    /// 取不到 Application Support 目录返回 nil。
    static func legacyDefaultStoreURL() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return nil
        }
        return appSupport.appending(path: storeBaseName)
    }

    /// U9 迁移核心（可测）：把 `sourceDir` 下的整套 LinoJ store 文件拷到 `targetDir`。
    ///
    /// 纪律：
    ///   - **幂等 / 不覆盖**：目标目录已有主 store（`storeBaseName`）→ 直接 no-op（视为已迁移）。
    ///   - **源无主 store** → no-op（干净安装，没有可迁移的旧数据）。
    ///   - **拷贝非移动**：旧文件保留不删，作为回退保险。
    ///   - 逐个探测：只拷源目录下**实际存在**的条目（主 store + sidecar + 辅助目录），不存在的跳过。
    ///   - 任一文件拷贝抛错都**吞掉不上抛**：迁移是 best-effort，失败也不能让 App 起不来
    ///     （最坏情况退化为「App Group 容器内重建空 store + CloudKit 拉回 / 旧位置数据仍在」）。
    static func migrateStore(from sourceDir: URL, to targetDir: URL) {
        let fm = FileManager.default

        let sourceStore = sourceDir.appending(path: storeBaseName)
        let targetStore = targetDir.appending(path: storeBaseName)

        // 幂等：目标已有主 store → 已迁移过，no-op（绝不覆盖）。
        guard !fm.fileExists(atPath: targetStore.path) else { return }
        // 源无主 store → 无旧数据可迁，no-op。
        guard fm.fileExists(atPath: sourceStore.path) else { return }

        // 确保目标目录存在（App Group 容器目录通常已由系统建好，但保险起见）。
        if !fm.fileExists(atPath: targetDir.path) {
            try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }

        // 逐个探测实际存在的条目再拷（主 store 先拷，再拷 companions）。
        for name in storeAllItemNames {
            let src = sourceDir.appending(path: name)
            let dst = targetDir.appending(path: name)
            guard fm.fileExists(atPath: src.path) else { continue }   // 源不存在 → 跳过
            guard !fm.fileExists(atPath: dst.path) else { continue }  // 目标已存在 → 不覆盖
            try? fm.copyItem(at: src, to: dst)                        // best-effort，失败吞掉
        }
    }

    // MARK: - 容器工厂

    /// 构造 LinoJ 的 SwiftData 容器。
    ///
    /// - Parameters:
    ///   - inMemory: `true` 时仅在内存中存储，重启即失（测试 / preview 用），且强制 `.none` 不连云。
    ///     **此路径完全不碰 App Group URL**（纯内存 + `.none`，测试不受影响）。
    ///   - cloudSyncEnabled: 仅当 `inMemory == false` 时生效。`true` 走 CloudKit private database
    ///     同步；`false` 走纯本地磁盘 store。默认 `true`（plan V1：iCloud sync 默认 ON）。
    /// - Returns: 配置好的 `ModelContainer`，可注入 SwiftUI `.modelContainer(_:)`。
    /// - Throws: SwiftData 初始化失败时抛错（通常是 schema 不一致或磁盘写入受限）。
    ///
    /// U9：非 inMemory 时 `ModelConfiguration` 显式指定 `url = appGroupStoreURL()`（与 widget 共用）；
    /// `appGroupStoreURL()` 返回 nil 时 fallback 回默认位置（不带 url 参数）。
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
            Note.self,   // U1（v1.1）：灵感版块 @Model。加新实体是兼容变更，走 lightweight migration。
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

        let config: ModelConfiguration
        if inMemory {
            // 测试 / preview：纯内存 + .none，不碰 App Group URL（命名配置即可，落盘位置无意义）。
            config = ModelConfiguration(
                "LinoJStore",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: cloudKitDatabase
            )
        } else if let groupURL = appGroupStoreURL() {
            // U9：App 运行 + App Group 可用 → 显式指定 group 容器内的 store URL（与 widget 共用）。
            config = ModelConfiguration(
                schema: schema,
                url: groupURL,
                cloudKitDatabase: cloudKitDatabase
            )
        } else {
            // U9 回退：App Group 取不到（entitlement 没配好 / containerURL nil）→ 回退默认位置
            // （不带 url，沿用 named 配置默认落盘），保证 App 不因 App Group 配置问题而起不来。
            config = ModelConfiguration(
                "LinoJStore",
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: cloudKitDatabase
            )
        }
        return try ModelContainer(for: schema, configurations: [config])
    }
}
