// Colors.swift
// LinoJ 全部颜色 token —— 两套（light / dark）。
//
// 颜色访问统一走 `Color.lj.bg` 这种风格：`Color.lj` 是嵌套枚举 `Color.LJ` 的别名，
// 里面每个 token 都是 `Color(light:dark:)` 的实例，会根据当前 `colorScheme`
// 在 macOS（NSColor）与 iOS（UIColor）上自动切换。
//
// 数值来源：design_handoff_linoj/README.md 中「Design tokens → Colors (light/dark mode)」段。
// 100% 与 README 数值一致；不允许在视图里硬编码任何 hex —— 都走这里。

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Cross-platform helper: dynamic light/dark color + hex literal

public extension Color {
    /// 跨平台的「动态颜色」工厂：iOS 用 UIColor trait callback，
    /// macOS 用 NSColor `init(name:dynamicProvider:)`，
    /// 其它平台（理论上不存在，留给将来 Linux 编译时不爆掉）退化为 light。
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            // bestMatch 在 dark / vibrantDark 任一命中时返回非 nil。
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            return isDark ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }

    /// 从 RGB hex（0xRRGGBB）+ 可选 alpha 构造 sRGB Color。
    /// 不接受字符串解析，避免运行时崩溃路径；所有 token 都用整型字面量。
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >>  8) & 0xff) / 255.0
        let b = Double( hex        & 0xff) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - LinoJ palette

public extension Color {
    /// LinoJ 全部 token 的命名空间。
    ///
    /// 访问方式：`Color.lj.bg` / `Color.lj.blue` 等。
    /// 每个 token 都是动态 Color —— SwiftUI 在渲染时按 `colorScheme` 解析。
    enum LJ {

        // MARK: Surfaces

        /// App 主背景（macOS / iOS 通用）。light = #fafaf9，dark = #0d0d0e。
        public static let bg = Color(
            light: Color(hex: 0xfafaf9),
            dark:  Color(hex: 0x0d0d0e)
        )

        /// 次级表面（行/分区背景，比 bg 稍深）。light = #f3f2ef，dark = #161617。
        public static let bgSoft = Color(
            light: Color(hex: 0xf3f2ef),
            dark:  Color(hex: 0x161617)
        )

        /// 卡片 / list row 背景。light = #ffffff，dark = #181819。
        public static let panel = Color(
            light: Color(hex: 0xffffff),
            dark:  Color(hex: 0x181819)
        )

        /// 主分割线 / 卡片细边。light = rgba(15,15,15,0.07)，dark = rgba(255,255,255,0.07)。
        public static let border = Color(
            light: Color(red: 15/255, green: 15/255, blue: 15/255, opacity: 0.07),
            dark:  Color(red: 1,      green: 1,      blue: 1,      opacity: 0.07)
        )

        /// 强分割线（dashed border / 强调描边）。light = rgba(15,15,15,0.12)，dark = rgba(255,255,255,0.14)。
        public static let borderStrong = Color(
            light: Color(red: 15/255, green: 15/255, blue: 15/255, opacity: 0.12),
            dark:  Color(red: 1,      green: 1,      blue: 1,      opacity: 0.14)
        )

        // MARK: Text

        /// 主文字。light = #0a0a0a，dark = #f6f6f5。
        public static let ink = Color(
            light: Color(hex: 0x0a0a0a),
            dark:  Color(hex: 0xf6f6f5)
        )

        /// 次级文字（meta / 副标题）。light = rgba(10,10,10,0.62)，dark = rgba(246,246,245,0.65)。
        public static let inkSoft = Color(
            light: Color(red: 10/255,  green: 10/255,  blue: 10/255,  opacity: 0.62),
            dark:  Color(red: 246/255, green: 246/255, blue: 245/255, opacity: 0.65)
        )

        /// 弱文字（caption / hint）。light = rgba(10,10,10,0.42)，dark = rgba(246,246,245,0.42)。
        public static let inkMute = Color(
            light: Color(red: 10/255,  green: 10/255,  blue: 10/255,  opacity: 0.42),
            dark:  Color(red: 246/255, green: 246/255, blue: 245/255, opacity: 0.42)
        )

        /// 最弱文字（占位 / 不可用态）。light = rgba(10,10,10,0.22)，dark = rgba(246,246,245,0.22)。
        public static let inkDim = Color(
            light: Color(red: 10/255,  green: 10/255,  blue: 10/255,  opacity: 0.22),
            dark:  Color(red: 246/255, green: 246/255, blue: 245/255, opacity: 0.22)
        )

        /// 小 chip 背景（tag pill / kbd badge / avatar fallback）。
        /// light = rgba(10,10,10,0.05)，dark = rgba(255,255,255,0.06)。
        public static let chip = Color(
            light: Color(red: 10/255, green: 10/255, blue: 10/255, opacity: 0.05),
            dark:  Color(red: 1,      green: 1,      blue: 1,      opacity: 0.06)
        )

        // MARK: Blue accent (urgent / heads-up only)

        /// Urgent / Heads-up 蓝。light = #2563eb，dark = #60a5fa。
        public static let blue = Color(
            light: Color(hex: 0x2563eb),
            dark:  Color(hex: 0x60a5fa)
        )

        /// 蓝色文字色（urgent bubble 标题）。light = #1e40af，dark = #93c5fd。
        public static let blueInk = Color(
            light: Color(hex: 0x1e40af),
            dark:  Color(hex: 0x93c5fd)
        )

        /// 蓝色软填充（urgent bubble 背景）。light = rgba(37,99,235,0.08)，dark = rgba(96,165,250,0.12)。
        public static let blueSoft = Color(
            light: Color(red: 37/255, green: 99/255,  blue: 235/255, opacity: 0.08),
            dark:  Color(red: 96/255, green: 165/255, blue: 250/255, opacity: 0.12)
        )

        /// 更软的蓝填充（heads-up alert 整体底）。light = rgba(37,99,235,0.045)，dark = rgba(96,165,250,0.07)。
        ///
        /// README dark 段未单列该项，按 light 0.045 / 0.08 = 0.5625 比例缩 0.12 得 ~0.07，
        /// 与设计稿 visual 接近。
        public static let blueSofter = Color(
            light: Color(red: 37/255, green: 99/255,  blue: 235/255, opacity: 0.045),
            dark:  Color(red: 96/255, green: 165/255, blue: 250/255, opacity: 0.07)
        )

        /// 蓝色边框（urgent bubble border / heads-up pill border）。
        /// light = rgba(37,99,235,0.22)，dark = rgba(96,165,250,0.32)。
        public static let blueBorder = Color(
            light: Color(red: 37/255, green: 99/255,  blue: 235/255, opacity: 0.22),
            dark:  Color(red: 96/255, green: 165/255, blue: 250/255, opacity: 0.32)
        )

        // MARK: iOS-specific

        /// iOS Main 页背景（比 macOS bg 暖一档，让手机视觉更亲和）。
        /// light = #f4f3ef，dark = #000000（README iOS bg 段）。
        public static let iosMainBg = Color(
            light: Color(hex: 0xf4f3ef),
            dark:  Color(hex: 0x000000)
        )
    }

    /// `Color.lj.bg` 这类访问入口。
    static var lj: LJ.Type { LJ.self }
}
