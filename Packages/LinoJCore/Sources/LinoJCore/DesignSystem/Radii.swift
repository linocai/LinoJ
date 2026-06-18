// Radii.swift
// LinoJ 圆角常量 —— 来自 README「Design tokens → Radii」段。
//
// 用法：`RoundedRectangle(cornerRadius: LJRadii.card)`，或 `.cornerRadius(LJRadii.pill)`。

import CoreGraphics

/// LinoJ 圆角常量集合。
/// v1.3：来源标签胶囊 6、bubble 13、容器玻璃面板 16~18（按 .dc.html inline style）。
public enum LJRadii {
    /// 小 chip / tag 的圆角（README: 6-8 macOS, 8-12 iOS；折中 8）。
    public static let chip: CGFloat = 8

    /// 来源标签 / 项目名胶囊圆角（.dc.html: 6px）。
    public static let sourceLabel: CGFloat = 6

    /// 卡片 / bubble 圆角（v1.3 .dc.html: todo bubble 13px）。
    public static let card: CGFloat = 13

    /// 容器级玻璃面板圆角（右栏 Next7 / 富卡 / 周网格 / 笔记卡；.dc.html 16~18）。
    public static let panel: CGFloat = 18

    /// macOS modal 圆角（v1.3 .dc.html: 18）。
    public static let modalMac: CGFloat = 18

    /// iOS bottom sheet 圆角（v1.3 .dc.html: 顶部 24~30）。
    public static let modalIOS: CGFloat = 28

    /// 完整 pill 形（圆角 = 高度 / 2）。
    public static let pill: CGFloat = 999
}
