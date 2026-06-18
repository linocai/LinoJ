// FloatingActions.swift
// iOS 右上角两枚浮动 glass 圆钮：放大镜（Search）+ gear（Settings）。
//
// 视觉规范（design_handoff_linoj_frontend/LinoJ 主页.dc.html（iOS 主页）floating top-right actions）：
//   - 原型只有两枚（search + settings）42pt 圆形玻璃钮，间距 10；图标 `magnifyingglass`/`gearshape`，色 `.lj.ink`。
//   - 外壳 `.glassEffect(in: Capsule())`（iOS 26 原生 Liquid Glass，capsule 在等宽等高下即圆形）。
//
// v1.3 R7（对原型重建）：**移除旧的第三枚「＋」QuickAdd 钮**——原型 iOS 右上仅 search+settings，
// 且 Main 为只读聚合视图（与 macOS R1「Main 只读、移除全局＋新建」一致）。创建入口不丢失：
// Personal/Company/Calendar/Inspiration 各屏头部都有自家品牌渐变「＋新建…」主按钮。

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
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(in: Capsule())
            .accessibilityLabel(Text(LJStrings.a11ySearch))

            Button {
                router.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.lj.ink)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(in: Capsule())
            .accessibilityLabel(Text(LJStrings.a11ySettings))
        }
    }
}
