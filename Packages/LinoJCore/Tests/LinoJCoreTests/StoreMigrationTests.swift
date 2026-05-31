// StoreMigrationTests.swift
// U9（v1.1）验收：`LinoJStore.migrateStore(from:to:)` 的纯文件搬运逻辑。
//
// 为什么只测 `migrateStore(from:to:)` 而不测 `migrateStoreToAppGroupIfNeeded()`：
//   后者依赖真实 App Group 容器（`containerURL(forSecurityApplicationGroupIdentifier:)`），
//   headless `swift test` 进程无 App Group entitlement → 取不到容器、无法构造。把搬运核心抽成
//   可注入源/目标目录的 `migrateStore(from:to:)`，用临时目录桩覆盖三条关键路径；
//   `migrateStoreToAppGroupIfNeeded()` 只是「喂真实 URL」的薄包装，真机验收覆盖。
//
// 三条必测断言（按 builder prompt）：
//  1. 无旧 store 时 migrate no-op（目标目录保持空）。
//  2. 有旧 store（连同 -wal/-shm 及辅助目录）→ 拷到目标目录、文件齐、**旧文件仍在**（回退保险）。
//  3. 目标已存在主 store 时**不覆盖**（幂等）。

import Foundation
import Testing
@testable import LinoJCore

@Suite("U9 — LinoJStore.migrateStore(from:to:) 文件搬运")
struct StoreMigrationTests {

    /// 建一个临时根目录，返回 (source, target) 两个子目录（均已创建）。
    /// caller 负责在 defer 里清理 root。
    private func makeTempDirs() throws -> (root: URL, source: URL, target: URL) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appending(path: "linoj.migration.\(UUID().uuidString)")
        let source = root.appending(path: "source")
        let target = root.appending(path: "target")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        return (root, source, target)
    }

    /// 在 `dir` 里造一套「旧 store」文件：主 store + -wal/-shm sidecar + 一个辅助目录。
    /// 用与生产一致的基础名 `LinoJStore.store`。
    private func writeFakeStore(in dir: URL) throws {
        let fm = FileManager.default
        let base = LinoJStore.storeBaseName // "LinoJStore.store"
        try Data("STORE".utf8).write(to: dir.appending(path: base))
        try Data("WAL".utf8).write(to: dir.appending(path: "\(base)-wal"))
        try Data("SHM".utf8).write(to: dir.appending(path: "\(base)-shm"))
        // 辅助目录（命名从基础名派生，如 CloudKit 资源目录）。
        let ckAssets = dir.appending(path: "LinoJStore_ckAssets")
        try fm.createDirectory(at: ckAssets, withIntermediateDirectories: true)
        try Data("ASSET".utf8).write(to: ckAssets.appending(path: "blob.dat"))
    }

    @Test("无旧 store → no-op（目标保持空）")
    func noLegacyStoreIsNoOp() throws {
        let fm = FileManager.default
        let dirs = try makeTempDirs()
        defer { try? fm.removeItem(at: dirs.root) }

        // source 里什么都没有。
        LinoJStore.migrateStore(from: dirs.source, to: dirs.target)

        let targetContents = try fm.contentsOfDirectory(atPath: dirs.target.path)
        #expect(targetContents.isEmpty, "无旧 store 时目标目录应保持空")
    }

    @Test("有旧 store（含 sidecar + 辅助目录）→ 全套拷到目标、文件齐、旧文件仍在")
    func copiesFullSetAndKeepsLegacy() throws {
        let fm = FileManager.default
        let dirs = try makeTempDirs()
        defer { try? fm.removeItem(at: dirs.root) }

        try writeFakeStore(in: dirs.source)
        LinoJStore.migrateStore(from: dirs.source, to: dirs.target)

        let base = LinoJStore.storeBaseName

        // 目标齐：主 store + 两个 sidecar + 辅助目录（含内部文件）。
        #expect(fm.fileExists(atPath: dirs.target.appending(path: base).path))
        #expect(fm.fileExists(atPath: dirs.target.appending(path: "\(base)-wal").path))
        #expect(fm.fileExists(atPath: dirs.target.appending(path: "\(base)-shm").path))
        var isDir: ObjCBool = false
        let assetsDir = dirs.target.appending(path: "LinoJStore_ckAssets")
        #expect(fm.fileExists(atPath: assetsDir.path, isDirectory: &isDir))
        #expect(isDir.boolValue, "辅助目录应作为目录递归拷贝")
        #expect(fm.fileExists(atPath: assetsDir.appending(path: "blob.dat").path),
                "辅助目录内部文件也应被拷贝")

        // 内容正确（主 store）。
        let copied = try String(contentsOf: dirs.target.appending(path: base), encoding: .utf8)
        #expect(copied == "STORE")

        // 回退保险：旧文件仍在（拷贝非移动）。
        #expect(fm.fileExists(atPath: dirs.source.appending(path: base).path))
        #expect(fm.fileExists(atPath: dirs.source.appending(path: "\(base)-wal").path))
        #expect(fm.fileExists(atPath: dirs.source.appending(path: "\(base)-shm").path))
        #expect(fm.fileExists(atPath: dirs.source.appending(path: "LinoJStore_ckAssets/blob.dat").path))
    }

    @Test("目标已存在主 store → 不覆盖（幂等）")
    func doesNotOverwriteExistingTarget() throws {
        let fm = FileManager.default
        let dirs = try makeTempDirs()
        defer { try? fm.removeItem(at: dirs.root) }

        let base = LinoJStore.storeBaseName

        // source 有「新」内容，target 已有「旧已迁移」内容。
        try writeFakeStore(in: dirs.source)
        try Data("ALREADY_MIGRATED".utf8).write(to: dirs.target.appending(path: base))

        LinoJStore.migrateStore(from: dirs.source, to: dirs.target)

        // 目标主 store 内容不被覆盖。
        let targetStore = try String(contentsOf: dirs.target.appending(path: base), encoding: .utf8)
        #expect(targetStore == "ALREADY_MIGRATED", "目标已有主 store 时应整体 no-op，不覆盖")

        // 既然整体 no-op，sidecar 也不应被带过去。
        #expect(!fm.fileExists(atPath: dirs.target.appending(path: "\(base)-wal").path),
                "幂等：目标已迁移则不再搬 sidecar")
    }

    @Test("源/目标同目录 → no-op（避免自拷自）")
    func sameDirIsHandledGracefully() throws {
        let fm = FileManager.default
        let dirs = try makeTempDirs()
        defer { try? fm.removeItem(at: dirs.root) }

        try writeFakeStore(in: dirs.source)
        // 源 == 目标：目标已有主 store（就是源自己）→ 幂等守卫直接 no-op，不抛错、不破坏文件。
        LinoJStore.migrateStore(from: dirs.source, to: dirs.source)

        #expect(fm.fileExists(atPath: dirs.source.appending(path: LinoJStore.storeBaseName).path))
    }

    @Test("legacyDefaultStoreURL 指向 Application Support 下的 LinoJStore.store")
    func legacyDefaultStoreURLShape() throws {
        let url = try #require(LinoJStore.legacyDefaultStoreURL())
        #expect(url.lastPathComponent == "LinoJStore.store")
        #expect(url.deletingLastPathComponent().lastPathComponent == "Application Support")
    }
}
