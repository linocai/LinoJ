// LinoJ_macOSApp.swift
// macOS App 入口。P3.2 起承载：
//   - 一个 `WindowGroup` 装 `RootWindow`（顶栏 Picker + Tab 路由分发的真实视图）；
//   - `TabRouter` 通过 `.environment` 注入；
//   - `ModelContainer` 通过 `.modelContainer` 注入，给 SwiftData `@Query` / `@Environment(\.modelContext)` 提供根；
//   - DEBUG 构建在 init 末尾调一次 `SeedData.seedIfEmpty`，让首启动有 design fixture 数据；
//   - 全局菜单 / 键盘快捷键（⌘1..⌘4 切 tab、⌘N、⌘⇧T/E/P、⌘K、⌘,）由 `LinoJCommands` 提供。
//
// 后续 Phase 会追加 Settings scene（P3.8）。

import SwiftUI
import SwiftData
import LinoJCore

@main
struct LinoJ_macOSApp: App {

    /// 全局唯一的 TabRouter，App 生命周期持有。
    /// 用 `@State` 因为 `@Observable` 类型不需要 `@StateObject`/`@ObservedObject`；
    /// `@State` 在 Swift 6 + iOS/macOS 26 SDK 中负责保持引用 + 触发依赖刷新。
    @State private var router = TabRouter()

    /// SwiftData 根容器。init 时构造一次。
    /// 0.9.1 修订：CloudKit 容器构建失败时**回退**到纯本地 `.none` 容器，让 App 仍能启动
    /// （真机若 iCloud 未登录 / 网络差 / production schema 未部署 / 迁移异常都会触发）。
    /// 只有连本地容器都建不出来才 fatalError（基本不可能）。
    let container: ModelContainer

    init() {
        // makeContainer 是 @MainActor —— init 在 @main entrypoint 等价主线程，可以直接 assumeIsolated。
        let container = MainActor.assumeIsolated {
            // U9（v1.1）：建容器前先做一次幂等的 App Group store 迁移（把旧默认位置的 v1.0 数据
            // 拷到 App Group 共享容器，旧 store 保留不删作回退）。失败 / 已迁移 / 无旧 store 均 no-op，
            // 不抛错，绝不阻断 App 启动。
            LinoJStore.migrateStoreToAppGroupIfNeeded()
            return Self.makeContainerWithFallback()
        }
        self.container = container
        #if DEBUG
        // ⚠️ 只在「纯本地模式（iCloud sync OFF）」才 seed。Release 永远不 seed（启动 Inbox zero）。
        // CloudKit ON 时：本地 store 启动瞬间为空，CloudKit 初次同步是异步、稍后才拉下云端数据；
        // 若此刻无脑 seedIfEmpty，会抢在同步前先塞一份 → 与云端既有数据重复累积（多端/多次安装叠 2×、3×…）。
        // 所以 cloud ON（含回退本地的异常态）一律不 seed；仅 cloud OFF 纯本地 DEBUG 才 seed 演示数据（无竞态）。
        if !SettingsViewModel.readICloudSyncOn() {
            MainActor.assumeIsolated {
                try? SeedData.seedIfEmpty(container.mainContext)
            }
        }
        #endif
    }

    /// 先按启动期 iCloud sync 开关试建容器；失败回退纯本地 `.none`。
    /// V1：运行时切 toggle 不热切容器（SwiftData 限制），下次启动按新值生效。
    @MainActor
    private static func makeContainerWithFallback() -> ModelContainer {
        let cloudSyncEnabled = SettingsViewModel.readICloudSyncOn()
        do {
            let container = try LinoJStore.makeContainer(cloudSyncEnabled: cloudSyncEnabled)
            // 上次回退过、本次又成功（如重新登录 iCloud）：清掉回退标记。
            UserDefaults.standard.set(false, forKey: "linoj.cloudFellBackToLocal")
            return container
        } catch {
            // CloudKit 容器构建失败：回退纯本地容器，记一个标记供 Settings 显示。
            if cloudSyncEnabled {
                UserDefaults.standard.set(true, forKey: "linoj.cloudFellBackToLocal")
            }
            do {
                return try LinoJStore.makeContainer(cloudSyncEnabled: false)
            } catch {
                // 连纯本地容器都建不出来 —— 无可恢复路径。
                fatalError("Local ModelContainer init failed: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootWindow()
                .environment(router)
                .frame(minWidth: 1200, minHeight: 720)
        }
        .modelContainer(container)
        // V4 修订：隐藏系统标题栏，让自定义顶栏与红绿灯融合在同一行（unified chrome，
        // 对齐 direction-a.jsx）。RootWindow 的 toolbar 左侧留出红绿灯宽度的内边距。
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            // 把 router 直接传进 Commands。Commands 不是 View，不能用 @Environment；
            // 但 @Observable 引用类型可以直接持有，内部 mutate 会同步刷新订阅者。
            LinoJCommands(router: router)
        }
    }
}
