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
    public static let version: String = "1.1"
}

/// W3：Settings About 区的外链常量。集中放在 Core，两端 Settings View 共用。
public enum LinoJLinks {
    /// Feedback 行的收件邮箱（两端 About 行点击 `mailto:` 拉起邮件 compose）。
    public static let feedbackEmail = "feedback@linoj.app"

    /// 隐私政策页 URL（两端 About 行点击 `openURL` 打开浏览器）。
    /// ⚠️ 占位值，待用户替换为真实隐私政策 URL（上架 App Store 必须有真实隐私政策页）。
    public static let privacyPolicy = "https://linoj.app/privacy"
}
