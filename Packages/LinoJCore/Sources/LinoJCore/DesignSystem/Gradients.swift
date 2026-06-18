// Gradients.swift
// LinoJ 品牌渐变 —— v1.3 双端五屏前端重构（靛蓝→紫品牌）。
//
// 真理源：design_handoff_linoj_frontend/LinoJ 主页.dc.html inline style：
//   linear-gradient(135deg, #5B8DEF, #8A6DF0) —— 主按钮 / avatar 圆点 / urgent 竖条 / 勾选框。
//   linear-gradient(180deg, #5B8DEF, #8A6DF0) —— urgent 气泡左侧全高竖条。
//
// 两端各取动态 token（light/dark）跟随 colorScheme。dark 提亮一档（与 Colors 紫系派生一致）。

import SwiftUI

/// LinoJ 渐变集合。访问：`LJGradients.brand`。
public enum LJGradients {

    /// 品牌渐变端·亮蓝（#5B8DEF）。dark 提亮 #7BA3F5。
    public static let brandBlue = Color(
        light: Color(hex: 0x5B8DEF),
        dark:  Color(hex: 0x7BA3F5)
    )

    /// 品牌渐变端·紫（#8A6DF0）。dark 提亮 #A98FF5。
    public static let brandPurple = Color(
        light: Color(hex: 0x8A6DF0),
        dark:  Color(hex: 0xA98FF5)
    )

    /// 品牌渐变 135°（主按钮 / avatar 圆点 / 勾选框）：brandBlue → brandPurple。
    public static var brand: LinearGradient {
        LinearGradient(
            colors: [brandBlue, brandPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 品牌渐变 180°（urgent 气泡左侧全高竖条）：上 brandBlue → 下 brandPurple。
    public static var brandVertical: LinearGradient {
        LinearGradient(
            colors: [brandBlue, brandPurple],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
