// Enums.swift
// 跨模块共用的枚举：urgency（todo 紧急级别）、scope（个人 / 工作）、AppTab（顶层 Tab）。
//
// 三个枚举都标 Codable + CaseIterable + Sendable，保证：
//   - Codable：方便未来 JSON 导入 / 导出 / iCloud 编解码（v0.9 暂不接，但接口先稳住）；
//   - CaseIterable：UI 上的 picker / chip row 直接遍历 `allCases`；
//   - Sendable：在 Swift 6 strict concurrency 下可跨 actor 自由传递。

import Foundation

/// Todo 的紧急级别。
///
/// README NON-NEGOTIABLE：只有两级 —— `urgent`（蓝色 bubble、左侧 accent）与 `normal`（白色 bubble）。
/// 不允许加 "later" / "someday" 等额外级别。
public enum Urgency: String, Codable, CaseIterable, Sendable {
    case urgent
    case normal
}

/// Todo 所属语境。
///
/// `personal` 进入 Personal tab；`company` 进入 Company tab。
/// Project 只能挂在 `company` scope 的 todo 上（schema 不强约束，由 ViewModel 在 P3.6 校验）。
public enum Scope: String, Codable, CaseIterable, Sendable {
    case personal
    case company
}

/// 顶层 Tab 的标识。
///
/// raw 值用 lowercase 单词，便于：
///   - Settings 中的 `defaultTab` 持久化为字符串；
///   - 调试日志 / 深链接（v1.0 用）；
///   - SwiftUI Picker tag 直接绑 `AppTab`。
///
/// U0（v1.1）新增第 5 个 case `inspiration`（灵感）。CaseIterable 自动纳入 `allCases`；
/// 所有遍历 `allCases` 的点（Settings defaultTab picker / Search jump-to）天然覆盖；
/// 所有穷举 `switch self`（如 `localizedDisplayName` / SearchViewModel.display）已为新 case 补分支。
public enum AppTab: String, Codable, CaseIterable, Sendable {
    case main
    case personal
    case company
    case calendar
    case inspiration   // U0 新增；raw "inspiration"
}
