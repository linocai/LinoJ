// SearchSheet_iOS.swift
// iOS Search screen —— plan P3.7 范围。
//
// 入口：右上 floating glass `magnifyingglass` 按钮 → router.showSearch = true。
// RootTabView 用 `.sheet(isPresented:)` 绑这个视图，detents `.large`，全屏感。
//
// 视觉决策（design_handoff_linoj_frontend/LinoJ 主页.dc.html（iOS Search））：
//   - 顶部一行：左侧 search field（含 magnifier icon + × clear）+ 右侧 Cancel link。
//   - 第二行：Scope chips 横向 scroll。
//   - 主体：每个 group 一张白色 card（rounded 12pt + border），内含 rows，row 之间细分割线。
//   - 行尾 chevron.right 提示 push。
//
// 行为：
//   - VM 持有 router 引用；open() 切 tab + 关闭 sheet（router.showSearch = false）。
//   - 不实现 ↑↓↵ 硬键盘行为（plan 没要求 iOS）。

import SwiftUI
import SwiftData
import LinoJCore

struct SearchSheet_iOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(TabRouter.self) private var router

    @State private var vm: SearchViewModel?
    @FocusState private var queryFieldFocused: Bool

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                Color.lj.bg.ignoresSafeArea()
            }
        }
        .onAppear {
            if vm == nil {
                vm = SearchViewModel(context: modelContext, router: router)
            }
            DispatchQueue.main.async {
                queryFieldFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    @ViewBuilder
    private func content(vm: SearchViewModel) -> some View {
        @Bindable var vm = vm

        ZStack {
            Color.lj.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar(vm: vm)
                scopeChips(vm: vm)
                resultsScroll(vm: vm)
            }
        }
    }

    // MARK: Top bar

    @ViewBuilder
    private func topBar(vm: SearchViewModel) -> some View {
        @Bindable var vm = vm

        HStack(spacing: LJSpacing.s10) {
            HStack(spacing: LJSpacing.s10) {
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
                    .submitLabel(.search)
                    .onSubmit {
                        vm.openFirst()
                    }

                if !vm.query.isEmpty {
                    Button {
                        vm.query = ""
                        vm.performSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.lj.inkDim)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LJStrings.searchClear))
                }
            }
            .padding(.horizontal, LJSpacing.s14)
            .padding(.vertical, LJSpacing.s10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.lj.chip)
            )

            Button {
                router.showSearch = false
                dismiss()
            } label: {
                Text(LJStrings.quickAddCancel)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.lj.ink)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, LJSpacing.s16)
        .padding(.top, LJSpacing.s14)
        .padding(.bottom, LJSpacing.s10)
    }

    // MARK: Scope chips

    @ViewBuilder
    private func scopeChips(vm: SearchViewModel) -> some View {
        @Bindable var vm = vm

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(label: LJStrings.searchScopeAll, scope: .all, vm: vm)
                chip(label: LJStrings.searchScopeTodos, scope: .todos, vm: vm)
                chip(label: LJStrings.searchScopeEvents, scope: .events, vm: vm)
                chip(label: LJStrings.searchScopeProjects, scope: .projects, vm: vm)
            }
            .padding(.horizontal, LJSpacing.s16)
        }
        .padding(.bottom, LJSpacing.s12)
    }

    @ViewBuilder
    private func chip(label: LocalizedStringResource, scope: SearchViewModel.Scope, vm: SearchViewModel) -> some View {
        @Bindable var vm = vm
        let active = vm.scope == scope
        Button {
            vm.scope = scope
        } label: {
            Text(label)
                .font(.system(size: 12.5, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Color.lj.ink : Color.lj.inkSoft)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(active ? Color.lj.chip : Color.clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            active ? Color.lj.borderStrong : Color.lj.border,
                            lineWidth: 0.5
                        )
                )
                .whiteSpaceNoWrap()
        }
        .buttonStyle(.plain)
    }

    // MARK: Results

    @ViewBuilder
    private func resultsScroll(vm: SearchViewModel) -> some View {
        if vm.grouped.isEmpty {
            // P5：query 非空但无命中 → 用 EmptyState(.noResults) 替代单行字符串，
            // chrome（search field + scope chips）保持可见。
            VStack {
                Spacer()
                EmptyState(variant: .noResults(vm.query))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(vm.grouped.enumerated()), id: \.offset) { (_, group) in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.group.uppercased())
                                .font(.system(size: 10.5, weight: .bold))
                                .kerning(0.84)
                                .foregroundStyle(Color.lj.inkMute)
                                .padding(.horizontal, 4)

                            // Card 包住该组的全部 rows（v1.3 R7：玻璃材质 + hairline + 顶高光）。
                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.offset) { (idx, item) in
                                    row(item: item, isLast: idx == group.items.count - 1, vm: vm)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.regularMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
                            )
                            .overlay { LJTopHighlight(radius: 14) }
                        }
                    }
                }
                .padding(.horizontal, LJSpacing.s16)
                .padding(.bottom, 30)
            }
        }
    }

    @ViewBuilder
    private func row(item: SearchViewModel.ResultItem, isLast: Bool, vm: SearchViewModel) -> some View {
        let info = vm.display(for: item)

        Button {
            vm.open(item)
            dismiss()
        } label: {
            HStack(spacing: LJSpacing.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.lj.chip)
                        .frame(width: 28, height: 28)
                    Image(systemName: info.iconSystemName)
                        .font(.system(size: 13, weight: .medium))
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
                            .font(.system(size: 14, weight: info.urgent ? .semibold : .medium))
                            .foregroundStyle(info.urgent ? Color.lj.blueInk : Color.lj.ink)
                            .lineLimit(1)
                    }
                    if let hint = info.hint {
                        Text(hint)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.lj.inkMute)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.lj.inkDim)
            }
            .padding(.horizontal, LJSpacing.s14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.lj.border)
                    .frame(height: 0.5)
                    .padding(.leading, LJSpacing.s14 + 28 + LJSpacing.s12)
            }
        }
    }
}

/// 小 helper：保证 chip 文字不换行。SwiftUI 没有内建 modifier 名 `whiteSpaceNoWrap`，
/// 用 fixedSize + lineLimit 1 等价。抽出来避免 chip 函数体太长。
private extension View {
    func whiteSpaceNoWrap() -> some View {
        self.lineLimit(1).fixedSize(horizontal: true, vertical: false)
    }
}
