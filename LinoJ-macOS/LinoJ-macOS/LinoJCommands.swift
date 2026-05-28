// LinoJCommands.swift
// macOS 全局菜单 + 键盘快捷键。P3.1 把以下接通：
//   - ⌘1..⌘4：切 Tab（router.current = .main / .personal / .company / .calendar）。
//   - ⌘K：打开 Search palette（router.showSearch = true；P3.7 接 sheet）。
//   - ⌘N / ⌘⇧T / ⌘⇧E / ⌘⇧P：打开 Quick Add（router.showQuickAdd = true；P3.6 接 modal、本期不区分 kind）。
//   - ⌘,：打开 Settings（router.showSettings = true；P3.8 接 sheet）。
//
// 注意：SwiftUI Commands 不是 View，不能用 @Environment(TabRouter.self)；
// 但 @Observable final class 是引用类型，直接 `let router: TabRouter` 持有即可，
// 内部 mutate 通过引用反映回 App 持有的同一实例，订阅者（RootWindow）自动刷新。

import SwiftUI
import LinoJCore

struct LinoJCommands: Commands {

    /// App 持有的 router 引用。@Observable 引用类型直接拿，不需要 Binding。
    let router: TabRouter

    var body: some Commands {

        // 替换系统默认 "New" 菜单组。P3.6 起 ⌘⇧T/E/P 真正预设 Quick Add kind。
        // ⌘N 默认 Todo（plan P3.6: "默认 Todo"）。
        CommandGroup(replacing: .newItem) {
            Button("New…") {
                router.quickAddDefaultKind = .todo
                router.showQuickAdd = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("New Todo") {
                router.quickAddDefaultKind = .todo
                router.showQuickAdd = true
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Button("New Event") {
                router.quickAddDefaultKind = .event
                router.showQuickAdd = true
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("New Project") {
                router.quickAddDefaultKind = .project
                router.showQuickAdd = true
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        // S12: 菜单命名从 "View" 改为 "Navigate"，避免与系统 View 菜单合并冲突。
        // 用 LocalizedStringResource 保证中英双语支持。
        CommandMenu(Text(LJStrings.menuNavigate)) {
            Button("Main") {
                router.current = .main
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Personal") {
                router.current = .personal
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Company") {
                router.current = .company
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Calendar") {
                router.current = .calendar
            }
            .keyboardShortcut("4", modifiers: .command)

            Divider()

            Button("Search…") {
                router.showSearch = true
            }
            .keyboardShortcut("k", modifiers: .command)
        }

        // ⌘, 触发 Settings。这里替换系统默认 appSettings 组，避免与默认 Settings scene 重复出现。
        // P3.8 接通真正的 Settings sheet 之前，按下仅翻 flag，行为是 noop（无 sheet 弹出）。
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                router.showSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
