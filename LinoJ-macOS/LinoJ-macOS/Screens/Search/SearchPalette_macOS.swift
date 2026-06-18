// SearchPalette_macOS.swift
// macOS Search / Command palette —— plan P3.7 范围。
//
// 入口：⌘K → router.showSearch = true。RootWindow 用 `.sheet` 绑定。
//
// 视觉决策：
//   - 设计稿 ASearchPalette 描述「居中浮动 modal 620pt + 70% black backdrop」。
//     与 QuickAdd 一致，我们用系统 `.sheet` + 内部 `.frame(width: 640, height: 540)` —— 系统 sheet
//     从顶部滑下、附窗口；这是 plan P3.6 偏离日志已接受的方案，应用于 P3.7 一致。
//   - 按 macos-overlays.jsx ASearchPalette 组装：
//       header（search field + scope chips + esc kbd hint）
//       results（grouped scroll，第一项 subtle 高亮）
//       footer（kbd hints + perf reading）
//
// 键盘：
//   - ↑↓：用 `.onKeyPress` 移动 highlightedIndex（跨 group 在 flatItems 上跑）。
//   - ↵：用 `.onKeyPress(.return)` 调 vm.open(flatItems[highlightedIndex])。
//   - esc：系统 sheet 自带 dismiss + Cancel 按钮（隐含）。
//
// VM 路由：vm 在 init 时直接持有 router，open() 会切 router.current + 翻 showSearch flag；
// View 只负责呈现与按键拦截。

import SwiftUI
import SwiftData
import LinoJCore

struct SearchPalette_macOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(TabRouter.self) private var router

    @State private var vm: SearchViewModel?

    /// 当前高亮的扁平 index。↑↓ 改写、↵ 触发对应 ResultItem 的 open。
    @State private var highlightedIndex: Int = 0

    /// 顶部 TextField 自动 focus。
    @FocusState private var queryFieldFocused: Bool

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                Color.lj.panel
                    .frame(width: 640, height: 540)
            }
        }
        .onAppear {
            if vm == nil {
                vm = SearchViewModel(context: modelContext, router: router)
            }
            // 下个 runloop 抢 focus（sheet 起来后 TextField 才进入响应链）。
            DispatchQueue.main.async {
                queryFieldFocused = true
            }
        }
    }

    @ViewBuilder
    private func content(vm: SearchViewModel) -> some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            header(vm: vm)
            Divider().overlay(Color.lj.border)
            results(vm: vm)
            Divider().overlay(Color.lj.border)
            footer(vm: vm)
        }
        .frame(width: 640, height: 540)
        // v1.3 R6：玻璃卡（与 QuickAdd/Settings 一致；原型未单列 Search，套 R0 玻璃件对齐风格）。
        .background(.regularMaterial)
        .overlay { LJTopHighlight(radius: LJRadii.modalMac) }
        // ↑↓↵ 键盘行为。.onKeyPress 修饰必须作用在能拿到 key event 的 View 上，
        // 这里挂在最外层 VStack 即可。
        .onKeyPress(.downArrow) {
            moveHighlight(by: +1, in: vm)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveHighlight(by: -1, in: vm)
            return .handled
        }
        .onKeyPress(.return) {
            openHighlighted(in: vm)
            return .handled
        }
    }

    // MARK: Header

    @ViewBuilder
    private func header(vm: SearchViewModel) -> some View {
        @Bindable var vm = vm

        HStack(spacing: LJSpacing.s12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.lj.inkSoft)

            TextField(text: $vm.query) {
                Text(LJStrings.searchPlaceholder)
            }
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.lj.ink)
                .focused($queryFieldFocused)
                .onChange(of: vm.query) {
                    // 用户每次输入都 reset 高亮到第一项；
                    // 不在 onChange 里调 performSearch，让 vm.didSet 走 debounce。
                    highlightedIndex = 0
                }
                .onSubmit {
                    openHighlighted(in: vm)
                }

            // × clear button（仅 query 非空时显示）
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    vm.performSearch()
                    highlightedIndex = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lj.inkDim)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LJStrings.searchClear))
            }

            // Scope chips
            HStack(spacing: 4) {
                scopeChip(label: LJStrings.searchScopeAll, scope: .all, vm: vm)
                scopeChip(label: LJStrings.searchScopeTodos, scope: .todos, vm: vm)
                scopeChip(label: LJStrings.searchScopeEvents, scope: .events, vm: vm)
                scopeChip(label: LJStrings.searchScopeProjects, scope: .projects, vm: vm)
            }

            Button {
                dismiss()
            } label: {
                kbd("esc")
            }
            .buttonStyle(.plain)
            .help(Text(LJStrings.quickAddCancel))
            .accessibilityLabel(Text(LJStrings.quickAddCancel))
        }
        .padding(.horizontal, LJSpacing.s18)
        .padding(.vertical, LJSpacing.s14)
    }

    @ViewBuilder
    private func scopeChip(label: LocalizedStringResource, scope: SearchViewModel.Scope, vm: SearchViewModel) -> some View {
        @Bindable var vm = vm
        let active = vm.scope == scope
        Button {
            vm.scope = scope
            highlightedIndex = 0
        } label: {
            Text(label)
                .font(.system(size: 11, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Color.lj.ink : Color.lj.inkMute)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(active ? Color.lj.chip : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Results

    @ViewBuilder
    private func results(vm: SearchViewModel) -> some View {
        if vm.grouped.isEmpty {
            // 无结果（query 非空但 0 命中）—— P5：用 EmptyState(.noResults) 替代单行字符串，
            // 与 iOS 视觉一致，且 query 字符串以本地化格式插入。
            VStack {
                Spacer()
                EmptyState(variant: .noResults(vm.query))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(vm.grouped.enumerated()), id: \.offset) { (gi, group) in
                        // group header
                        Text(group.group.uppercased())
                            .font(.system(size: 10.5, weight: .bold))
                            .kerning(0.84)
                            .foregroundStyle(Color.lj.inkMute)
                            .padding(.horizontal, LJSpacing.s16)
                            .padding(.top, gi == 0 ? 6 : 10)
                            .padding(.bottom, 4)

                        ForEach(Array(group.items.enumerated()), id: \.offset) { (_, item) in
                            row(item: item, vm: vm)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func row(item: SearchViewModel.ResultItem, vm: SearchViewModel) -> some View {
        let info = vm.display(for: item)
        let flat = vm.flatItems
        let flatIdx = flat.firstIndex(of: item) ?? -1
        let isHighlighted = flatIdx == highlightedIndex

        Button {
            vm.open(item)
        } label: {
            HStack(spacing: LJSpacing.s12) {
                // type icon chip
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.lj.chip)
                        .frame(width: 26, height: 26)
                    Image(systemName: info.iconSystemName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.lj.inkSoft)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if info.urgent {
                            Circle()
                                .fill(Color.lj.blue)
                                .frame(width: 6, height: 6)
                        }
                        Text(info.title)
                            .font(.system(
                                size: 13.5,
                                weight: (info.urgent || isHighlighted) ? .semibold : .medium
                            ))
                            .foregroundStyle(info.urgent ? Color.lj.blueInk : Color.lj.ink)
                            .lineLimit(1)
                    }
                    if let hint = info.hint {
                        Text(hint)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.lj.inkMute)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if isHighlighted {
                    kbd("↵")
                } else {
                    Text(verbose(for: item))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.lj.inkDim)
                }
            }
            .padding(.horizontal, LJSpacing.s16)
            .padding(.vertical, 8)
            .background(
                isHighlighted ? Color.lj.chip.opacity(0.7) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // P6：macOS list row hover —— 鼠标悬停时填 chip 背景。和 isHighlighted 兼容
        // （键盘选中色优先，hover 仅在未高亮行上可见，因为 hover 色与高亮色都是 chip 系）。
        .ljHoverBackground()
    }

    private func verbose(for item: SearchViewModel.ResultItem) -> LocalizedStringResource {
        switch item {
        case .quickAction: return LJStrings.searchVerbRun
        default: return LJStrings.searchVerbOpen
        }
    }

    // MARK: Footer

    @ViewBuilder
    private func footer(vm: SearchViewModel) -> some View {
        HStack(spacing: LJSpacing.s14) {
            HStack(spacing: 4) {
                kbd("↑↓")
                Text(LJStrings.searchNavigate)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
            }
            HStack(spacing: 4) {
                kbd("↵")
                Text(LJStrings.searchOpenHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
            }

            Spacer(minLength: 0)

            // perf reading：单复数走 Counts.resultIn / Counts.results；mono 字号保留
            Text(
                vm.totalCount == 1
                    ? String(localized: "Counts.resultIn",
                             defaultValue: "1 result in \(vm.elapsedMs) ms",
                             bundle: LinoJCoreBundle.bundle)
                    : String(localized: "Counts.resultsIn",
                             defaultValue: "\(vm.totalCount) results in \(vm.elapsedMs) ms",
                             bundle: LinoJCoreBundle.bundle)
            )
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.lj.inkMute)
        }
        .padding(.horizontal, LJSpacing.s16)
        .padding(.vertical, LJSpacing.s10)
        .background(Color.lj.bgSoft)
    }

    // MARK: - Keyboard helpers

    private func moveHighlight(by delta: Int, in vm: SearchViewModel) {
        let count = vm.flatItems.count
        guard count > 0 else { return }
        let next = (highlightedIndex + delta + count) % count
        highlightedIndex = next
    }

    private func openHighlighted(in vm: SearchViewModel) {
        let flat = vm.flatItems
        guard flat.indices.contains(highlightedIndex) else {
            // 高亮越界（结果清空），退而打开第一项。
            vm.openFirst()
            return
        }
        vm.open(flat[highlightedIndex])
    }

    /// 单个 kbd 标签视觉（与 QuickAdd 中保持一致）。
    @ViewBuilder
    private func kbd(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.lj.inkSoft)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.lj.chip)
            )
    }
}
