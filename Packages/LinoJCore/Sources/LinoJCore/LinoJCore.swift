// LinoJCore.swift
// LinoJCore — 共享的 models / persistence / view models / design tokens 入口。
//
// P0 阶段只暴露版本号，便于两端 App ContentView 验证链接成功；
// 后续 Phase 会在 Models/、Persistence/、DesignSystem/ 等子目录追加内容。

import Foundation

/// LinoJCore 的命名空间。统一以 `enum`（无 case）作为命名空间载体，
/// 避免外部实例化，也方便后续以 `LinoJCore.something` 形式扩展。
public enum LinoJCore {
    /// 当前 LinoJCore 库版本。
    ///
    /// 与 App 显示的 "LinoJ <version>" 一致；升级时同步更新。
    public static let version: String = "0.9.0"
}
