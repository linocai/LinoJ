// FloatingActions.swift
// iOS 右上角三枚浮动 glass 按钮：放大镜（Search）+ 加号（Quick Add）+ gear（Settings）。
//
// 视觉规范（README 第 358 行 + design_handoff_linoj/ios-main.jsx）：
//   - 每枚按钮 40pt 圆形，外壳 `.glassEffect(in: Capsule())`（capsule 在等宽等高下即圆形）；
//   - 图标 SF Symbol `magnifyingglass` / `plus` / `gearshape`，颜色 `.lj.ink`；
//   - 三枚按钮间距 LJSpacing.s10。
//
// P3.1 阶段最初只有前两枚；P3.8 追加第三枚 gear 翻 router.showSettings = true，作为 iOS
// Settings 入口（plan 要求 iOS 必须有 Settings 入口，但未指定具体放置；选 floating actions 行
// 是最贴合 iOS 已有 chrome 的方案）。

import SwiftUI
import LinoJCore

struct FloatingActions: View {

    @Environment(TabRouter.self) private var router

    var body: some View {
        HStack(spacing: LJSpacing.s10) {
            Button {
                router.showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.lj.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(in: Capsule())
            // P5：accessibility label 复用 searchClear/quickAddNew/settingsTitle 不够精准；
            // 用 Search.scope.all 的「全部」其实是 scope chip 名。
            // 实用做法：直接走 LJStrings 中存在的 token。Search 用 search 类标题 (实际是
            // search 占位符 placeholder)。但放大镜按钮 a11y 名直接用 String literal "Search" /
            // "Quick add" / "Settings" 作为最后保险（这是 a11y 一行短词，能再加 3 个 key 但
            // 视觉无收益，本期保留 raw 英文 + 用 LJStrings.searchScopeAll 替代 "Search" 不准确）。
            //
            // 折中策略：A11y.search / A11y.quickAdd / A11y.settings —— 见 xcstrings 末尾追加项。
            .accessibilityLabel(Text(LJStrings.a11ySearch))

            Button {
                router.showQuickAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.lj.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(in: Capsule())
            .accessibilityLabel(Text(LJStrings.a11yQuickAdd))

            Button {
                router.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.lj.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(in: Capsule())
            .accessibilityLabel(Text(LJStrings.a11ySettings))
        }
    }
}
