// LinoJ_iOSApp.swift
// iOS App 入口。P3.2 起承载：
//   - 一个 `WindowGroup` 装 `RootTabView`（自定义浮动 glass capsule tab bar + 真实 tab 内容）；
//   - `TabRouter` 通过 `.environment` 注入；
//   - `ModelContainer` 通过 `.modelContainer` 注入；
//   - DEBUG 构建在 init 末尾调一次 `SeedData.seedIfEmpty`；
//   - 右上两枚 floating glass 按钮（Search / +）由 `FloatingActions` 叠在 RootTabView 上层。

import SwiftUI
import SwiftData
import LinoJCore

@main
struct LinoJ_iOSApp: App {

    /// 全局唯一的 TabRouter，App 生命周期持有。
    @State private var router = TabRouter()

    /// SwiftData 根容器。init 时构造一次。
    /// 0.9.1 修订：CloudKit 容器构建失败时**回退**到纯本地 `.none` 容器，让 App 仍能启动
    /// （真机若 iCloud 未登录 / 网络差 / production schema 未部署 / 迁移异常都会触发）。
    /// 只有连本地容器都建不出来才 fatalError（基本不可能）。
    let container: ModelContainer

    init() {
        let container = MainActor.assumeIsolated {
            // U9（v1.1）：建容器前先做一次幂等的 App Group store 迁移（把旧默认位置的 v1.0 数据
            // 拷到 App Group 共享容器，旧 store 保留不删作回退）。失败 / 已迁移 / 无旧 store 均 no-op，
            // 不抛错，绝不阻断 App 启动。
            LinoJStore.migrateStoreToAppGroupIfNeeded()
            return Self.makeContainerWithFallback()
        }
        self.container = container
        #if DEBUG
        // ⚠️ 只在「纯本地模式（iCloud sync OFF）」才 seed。
        // CloudKit ON 时：本地 store 在启动瞬间是空的，CloudKit 的初次同步是异步、稍后才把云端
        // 数据拉下来；若此刻无脑 seedIfEmpty，会抢在同步前先塞一份 → 与云端既有数据重复累积
        // （多端 / 多次安装会叠成 2×、3×…）。所以 cloud ON（含回退本地的异常态）一律不 seed：
        // 新用户空状态、老用户等云同步。仅 cloud OFF 的纯本地 DEBUG 才 seed 演示数据（无竞态）。
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
            UserDefaults.standard.set(false, forKey: "linoj.cloudFellBackToLocal")
            return container
        } catch {
            if cloudSyncEnabled {
                UserDefaults.standard.set(true, forKey: "linoj.cloudFellBackToLocal")
            }
            do {
                return try LinoJStore.makeContainer(cloudSyncEnabled: false)
            } catch {
                fatalError("Local ModelContainer init failed: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(router)
        }
        .modelContainer(container)
    }
}
