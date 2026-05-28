// Spacing.swift
// LinoJ 间距常量 —— 来自 README「Design tokens → Spacing」段：8px grid，常用值
// 4 / 6 / 8 / 10 / 12 / 14 / 16 / 18 / 22 / 28 / 32。
//
// 视图层禁止直接写裸数字（如 `.padding(14)`），统一引用 `LJSpacing.s14`，
// 这样后续如果整体 +/-2pt 调整也只改一个文件。

import CoreGraphics

/// LinoJ 间距常量集合。命名规则：`s` + 像素数，方便点字母触发补全。
public enum LJSpacing {
    public static let s4:  CGFloat = 4
    public static let s6:  CGFloat = 6
    public static let s8:  CGFloat = 8
    public static let s10: CGFloat = 10
    public static let s12: CGFloat = 12
    public static let s14: CGFloat = 14
    public static let s16: CGFloat = 16
    public static let s18: CGFloat = 18
    public static let s22: CGFloat = 22
    public static let s28: CGFloat = 28
    public static let s32: CGFloat = 32
}
