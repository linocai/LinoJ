// Colors.swift
// LinoJ 全部颜色 token —— 两套（light / dark）。
//
// 颜色访问统一走 `Color.lj.bg` 这种风格：`Color.lj` 是嵌套枚举 `Color.LJ` 的别名，
// 里面每个 token 都是 `Color(light:dark:)` 的实例，会根据当前 `colorScheme`
// 在 macOS（NSColor）与 iOS（UIColor）上自动切换。
//
// 数值来源：design_handoff_linoj_frontend/README.md「Design Tokens → Colors」段
// + design_handoff_linoj_frontend/LinoJ 主页.dc.html 的 inline style（v1.3 起靛蓝→紫品牌）。
// 不允许在视图里硬编码任何 hex —— 都走这里。

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

        // MARK: 紫蓝强调 (v1.3：品牌强调 / urgent / heads-up；无橙)
        //
        // v1.3 双端五屏前端重构：urgent + heads-up + 主强调全部紫蓝系（靛蓝→紫品牌，无橙）。
        // 旧 `blue*` 命名保留（全仓引用自动跟随换值），但语义已是「紫蓝强调」。
        // 数值来源：design_handoff_linoj_frontend/LinoJ 主页.dc.html inline style。
        //   强调色 #6E63E6 / 深一档 #5B5BD6 / 紫点 #8A6DF0；
        //   urgent 软底 rgba(123,123,240,0.09) / border 0.20；heads-up 底 rgba(123,123,240,0.10) / border 0.24。
        // dark：紫系提亮一档（light-only 稿派生默认，真机校）。

        /// 紫蓝强调（计数 / 紧急数字 / 图标 / urgent 点）。light = #6E63E6，dark = #9D93F2（提亮）。
        /// = `accent`（保留 `blue` 旧名，全仓引用即此值）。
        public static let blue = Color(
            light: Color(hex: 0x6E63E6),
            dark:  Color(hex: 0x9D93F2)
        )

        /// 紫蓝强调·深一档文字色（urgent / heads-up 标题）。light = #5B5BD6，dark = #B7AFF7。
        /// = `accentDeep`（保留 `blueInk` 旧名）。
        public static let blueInk = Color(
            light: Color(hex: 0x5B5BD6),
            dark:  Color(hex: 0xB7AFF7)
        )

        /// urgent 气泡软底填充。light = rgba(123,123,240,0.09)，dark 提到 0.16。
        /// = `urgentSoft`（保留 `blueSoft` 旧名）。
        public static let blueSoft = Color(
            light: Color(red: 123/255, green: 123/255, blue: 240/255, opacity: 0.09),
            dark:  Color(red: 157/255, green: 147/255, blue: 242/255, opacity: 0.16)
        )

        /// heads-up alert 整体底（比 urgent 略浓一点点）。light = rgba(123,123,240,0.10)，dark 0.14。
        public static let blueSofter = Color(
            light: Color(red: 123/255, green: 123/255, blue: 240/255, opacity: 0.10),
            dark:  Color(red: 157/255, green: 147/255, blue: 242/255, opacity: 0.14)
        )

        /// urgent border（urgent bubble 0.20 / heads-up pill 0.24，折中走 urgent 值，heads-up 单列 `headsUpBorder`）。
        /// = `urgentBorder`（保留 `blueBorder` 旧名）。light = rgba(123,123,240,0.20)，dark 0.34。
        public static let blueBorder = Color(
            light: Color(red: 123/255, green: 123/255, blue: 240/255, opacity: 0.20),
            dark:  Color(red: 157/255, green: 147/255, blue: 242/255, opacity: 0.34)
        )

        // MARK: 紫系语义别名 + v1.3 新 token

        /// 品牌强调色（= `blue`，语义别名，新代码优先用 `accent`）。#6E63E6。
        public static let accent = blue

        /// 品牌强调·深一档（= `blueInk`，语义别名）。#5B5BD6。
        public static let accentDeep = blueInk

        /// 紫点（项目 / 公司来源标签点 / project 名胶囊 urgent 点）。light = #8A6DF0，dark = #A98FF5。
        public static let purpleDot = Color(
            light: Color(hex: 0x8A6DF0),
            dark:  Color(hex: 0xA98FF5)
        )

        /// urgent 气泡软底（= `blueSoft` 语义别名）。
        public static let urgentSoft = blueSoft

        /// urgent 气泡 border（= `blueBorder` 语义别名）。
        public static let urgentBorder = blueBorder

        /// heads-up 横幅 border。light = rgba(123,123,240,0.24)，dark 0.38。
        public static let headsUpBorder = Color(
            light: Color(red: 123/255, green: 123/255, blue: 240/255, opacity: 0.24),
            dark:  Color(red: 157/255, green: 147/255, blue: 242/255, opacity: 0.38)
        )

        // MARK: scope 来源标签（新功能，仅主页待办）

        /// 来源标签·公司 底。light = rgba(123,123,240,0.12)，dark 0.20。（个人复用 chip）
        public static let scopeCompanyBg = Color(
            light: Color(red: 123/255, green: 123/255, blue: 240/255, opacity: 0.12),
            dark:  Color(red: 157/255, green: 147/255, blue: 242/255, opacity: 0.20)
        )

        /// 来源标签·公司 字（= `accent` #6E63E6）。
        public static let scopeCompanyFg = accent

        /// 来源标签·公司 点（= `purpleDot` #8A6DF0）。
        public static let scopeCompanyDot = purpleDot

        // MARK: 顶栏分段导航 pill 选中底（v1.3 R1 macOS 顶栏）

        /// macOS 顶栏分段 pill 选中项底色（.dc.html navMain.rowBg: rgba(110,110,230,0.13)）。
        /// 比 scopeCompanyBg 略浓、偏深紫蓝，专用于顶栏选中态。dark 派生提一档。
        public static let navSelected = Color(
            light: Color(red: 110/255, green: 110/255, blue: 230/255, opacity: 0.13),
            dark:  Color(red: 157/255, green: 147/255, blue: 242/255, opacity: 0.22)
        )

        // MARK: iOS-specific

        /// iOS Main 页背景（比 macOS bg 暖一档，让手机视觉更亲和）。
        /// light = #f4f3ef，dark = #000000（README iOS bg 段）。
        public static let iosMainBg = Color(
            light: Color(hex: 0xf4f3ef),
            dark:  Color(hex: 0x000000)
        )

        // MARK: 背景底色渐变端色 (v1.3 ljScreenBackground)
        //
        // .dc.html：macOS linear-gradient(135°, #F7F8FB→#EEF0F6)；iOS linear-gradient(160°, #F4F3EF→#EBEDF3)。
        // dark 派生：深底两端（让玻璃材质在暗色下仍有层次）。

        /// macOS 底色渐变起点。light = #F7F8FB，dark = #111114。
        public static let bgGradTop = Color(
            light: Color(hex: 0xF7F8FB),
            dark:  Color(hex: 0x111114)
        )
        /// macOS 底色渐变终点。light = #EEF0F6，dark = #0B0B0D。
        public static let bgGradBottom = Color(
            light: Color(hex: 0xEEF0F6),
            dark:  Color(hex: 0x0B0B0D)
        )
        /// iOS 底色渐变起点（暖一档）。light = #F4F3EF，dark = #101012。
        public static let bgGradTopIOS = Color(
            light: Color(hex: 0xF4F3EF),
            dark:  Color(hex: 0x101012)
        )
        /// iOS 底色渐变终点。light = #EBEDF3，dark = #060608。
        public static let bgGradBottomIOS = Color(
            light: Color(hex: 0xEBEDF3),
            dark:  Color(hex: 0x060608)
        )

        // MARK: bloom orb (v1.3 背景柔光；仅装饰，与 urgent 语义无关)
        //
        // .dc.html macOS：橙 rgba(255,176,120,0.42) / 蓝 rgba(120,170,255,0.46) / 紫 rgba(190,150,255,0.40)。
        // dark：降一档不透明度（避免暗色下过亮）。锚点 / 半径由 ljScreenBackground 控制。

        /// bloom orb·暖橙团（装饰柔光）。light a=0.42，dark a=0.22。
        public static let orbWarm = Color(
            light: Color(red: 255/255, green: 176/255, blue: 120/255, opacity: 0.42),
            dark:  Color(red: 255/255, green: 176/255, blue: 120/255, opacity: 0.22)
        )
        /// bloom orb·蓝团。light a=0.46，dark a=0.26。
        public static let orbBlue = Color(
            light: Color(red: 120/255, green: 170/255, blue: 255/255, opacity: 0.46),
            dark:  Color(red: 120/255, green: 170/255, blue: 255/255, opacity: 0.26)
        )
        /// bloom orb·紫团。light a=0.40，dark a=0.24。
        public static let orbPurple = Color(
            light: Color(red: 190/255, green: 150/255, blue: 255/255, opacity: 0.40),
            dark:  Color(red: 190/255, green: 150/255, blue: 255/255, opacity: 0.24)
        )

        // MARK: 灵感笔记 masonry 多色调浅底 (v1.3 R5)
        //
        // .dc.html toneStyle：a=橙 rgba(255,176,120,0.13)/bar 橙渐变、b=紫 rgba(123,123,240,0.11)/bar 品牌渐变、
        // c=蓝 rgba(120,170,255,0.11)/bar 蓝渐变。tone 由 note.id 哈希派生（无 schema 改动）。
        // dark 派生：底略提一档不透明度，bar 用对应渐变端。

        /// 笔记卡·暖橙调浅底。light a=0.13，dark a=0.16。
        public static let noteToneWarm = Color(
            light: Color(red: 255/255, green: 176/255, blue: 120/255, opacity: 0.13),
            dark:  Color(red: 255/255, green: 176/255, blue: 120/255, opacity: 0.16)
        )
        /// 笔记卡·紫调浅底。light a=0.11，dark a=0.18。
        public static let noteTonePurple = Color(
            light: Color(red: 123/255, green: 123/255, blue: 240/255, opacity: 0.11),
            dark:  Color(red: 157/255, green: 147/255, blue: 242/255, opacity: 0.18)
        )
        /// 笔记卡·蓝调浅底。light a=0.11，dark a=0.18。
        public static let noteToneBlue = Color(
            light: Color(red: 120/255, green: 170/255, blue: 255/255, opacity: 0.11),
            dark:  Color(red: 120/255, green: 170/255, blue: 255/255, opacity: 0.18)
        )

        /// 笔记卡左色条·暖橙端色（bar 渐变上端 #FFB078）。dark 提亮。
        public static let noteBarWarm = Color(
            light: Color(hex: 0xFFB078),
            dark:  Color(hex: 0xFFC093)
        )
        /// 笔记卡左色条·暖橙端色（bar 渐变下端 #F39B6B）。
        public static let noteBarWarmDeep = Color(
            light: Color(hex: 0xF39B6B),
            dark:  Color(hex: 0xF5AE84)
        )
        /// 笔记卡左色条·蓝端色（bar 渐变上端 #78AAFF）。
        public static let noteBarBlue = Color(
            light: Color(hex: 0x78AAFF),
            dark:  Color(hex: 0x93BCFF)
        )

        // MARK: 阴影 (v1.3 深度层次)

        /// 卡片柔投影色。light = black 0.06，dark = black 0.45（暗色需更深才看得见层次）。
        public static let shadowCard = Color(
            light: Color(red: 0, green: 0, blue: 0, opacity: 0.06),
            dark:  Color(red: 0, green: 0, blue: 0, opacity: 0.45)
        )

        /// 品牌按钮发光投影色（rgba(123,109,240,0.35)）。dark 略降。
        public static let brandGlow = Color(
            light: Color(red: 123/255, green: 109/255, blue: 240/255, opacity: 0.35),
            dark:  Color(red: 123/255, green: 109/255, blue: 240/255, opacity: 0.30)
        )
    }

    /// `Color.lj.bg` 这类访问入口。
    static var lj: LJ.Type { LJ.self }
}
