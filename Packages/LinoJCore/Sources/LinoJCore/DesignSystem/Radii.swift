// Radii.swift
// LinoJ 圆角常量 —— 来自 README「Design tokens → Radii」段。
//
// 用法：`RoundedRectangle(cornerRadius: LJRadii.card)`，或 `.cornerRadius(LJRadii.pill)`。

import CoreGraphics

/// LinoJ 圆角常量集合。
public enum LJRadii {
    /// 小 chip / tag 的圆角（README: 6-8 macOS, 8-12 iOS；折中 8）。
    public static let chip: CGFloat = 8

    /// 卡片 / bubble 圆角（README: 11-14；常规卡用 12）。
    public static let card: CGFloat = 12

    /// macOS modal 圆角。
    public static let modalMac: CGFloat = 14

    /// iOS bottom sheet 圆角。
    public static let modalIOS: CGFloat = 24

    /// 完整 pill 形（圆角 = 高度 / 2）。
    public static let pill: CGFloat = 999
}
