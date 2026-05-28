// Typography.swift
// LinoJ 字体 ramp —— 完整覆盖 README 中「Design tokens → Typography」表。
//
// 设计稿 letter-spacing 用 em 单位（-0.025em 等）；SwiftUI 的 `.kerning(_:)` 只接受 pt。
// 转换近似公式：`kerning_pt = em × point_size`。例如 26pt 标题 -0.025em ≈ -0.65pt。
// 为了避免每次在视图里重算，本文件直接以 view modifier 形式封装好（`ljDisplayTitleStyle()` 等），
// 它们内部按平台 `#if os(macOS) / os(iOS)` 切换字号 + 字重 + kerning。
//
// 同时为兼容性保留纯 `Font.lj.*` 接口（不带 kerning，因为 Font 本身不承载 kerning），
// 供直接拼 Text 时用。需要严格视觉时优先用 modifier。

import SwiftUI

// MARK: - Font.LJ (pure Font ramp)

public extension Font {
    /// LinoJ 字体 ramp 的命名空间。
    ///
    /// 这些静态方法返回 `Font`，不携带 kerning（SwiftUI Font 不支持 kerning）。
    /// 要拿到完整设计稿效果（含 kerning），用本文件下方 View modifier 系列。
    enum LJ {

        /// 大标题（"To do" / "Personal" / "Calendar"）。macOS 26pt / iOS 34pt，semibold/bold。
        public static var displayTitle: Font {
            #if os(macOS)
            return .system(size: 26, weight: .semibold, design: .default)
            #else
            return .system(size: 34, weight: .bold, design: .default)
            #endif
        }

        /// 区段标题（"Urgent" / "Normal" / "Next 7 days"）。17pt，semibold/bold。
        public static var sectionHeader: Font {
            #if os(macOS)
            return .system(size: 17, weight: .semibold, design: .default)
            #else
            return .system(size: 17, weight: .bold, design: .default)
            #endif
        }

        /// 卡片标题（Project / Event 标题）。macOS 15pt / iOS 15pt 折中值（README 13-17 / 13-16）。
        public static var cardTitle: Font {
            #if os(macOS)
            return .system(size: 15, weight: .semibold, design: .default)
            #else
            return .system(size: 15, weight: .semibold, design: .default)
            #endif
        }

        /// Urgent bubble 标题。macOS 14.5pt / iOS 15.5pt，semibold。
        public static var bubbleUrgent: Font {
            #if os(macOS)
            return .system(size: 14.5, weight: .semibold, design: .default)
            #else
            return .system(size: 15.5, weight: .semibold, design: .default)
            #endif
        }

        /// Normal bubble 标题。macOS 13.5pt / iOS 14.5pt，medium。
        public static var bubbleNormal: Font {
            #if os(macOS)
            return .system(size: 13.5, weight: .medium, design: .default)
            #else
            return .system(size: 14.5, weight: .medium, design: .default)
            #endif
        }

        /// 正文。macOS 13pt / iOS 14pt，medium。
        public static var body: Font {
            #if os(macOS)
            return .system(size: 13, weight: .medium, design: .default)
            #else
            return .system(size: 14, weight: .medium, design: .default)
            #endif
        }

        /// Caption / meta 文字。macOS 11.5pt / iOS 12pt，medium。
        public static var caption: Font {
            #if os(macOS)
            return .system(size: 11.5, weight: .medium, design: .default)
            #else
            return .system(size: 12, weight: .medium, design: .default)
            #endif
        }

        /// 全大写 tag 文字。macOS 10.5pt / iOS 10.5pt，semibold/bold。
        /// 实际渲染时还需要 `.textCase(.uppercase)` 与 kerning（见 `ljTagStyle()` modifier）。
        public static var tag: Font {
            #if os(macOS)
            return .system(size: 10.5, weight: .semibold, design: .default)
            #else
            return .system(size: 10.5, weight: .bold, design: .default)
            #endif
        }

        /// 等宽数字（时间 / 计数 / kbd）。tabular-nums 由 `.monospacedDigit()` 在 modifier 中追加。
        public static var mono: Font {
            #if os(macOS)
            return .system(size: 11.5, weight: .medium, design: .monospaced)
            #else
            return .system(size: 12, weight: .medium, design: .monospaced)
            #endif
        }
    }

    /// `Font.lj.displayTitle` 这类访问入口。
    static var lj: LJ.Type { LJ.self }
}

// MARK: - View modifier ramp (includes kerning)

public extension View {

    /// 大标题样式（含 kerning + 颜色 = `.lj.ink`）。
    /// kerning 公式：26pt × -0.025em ≈ -0.65pt（macOS）；34pt × -0.03em ≈ -1.0pt（iOS）。
    func ljDisplayTitleStyle() -> some View {
        let kern: CGFloat = {
            #if os(macOS)
            return -0.65
            #else
            return -1.0
            #endif
        }()
        return self
            .font(.lj.displayTitle)
            .kerning(kern)
            .foregroundStyle(Color.lj.ink)
    }

    /// 区段标题样式（"Urgent" 等）。kerning ≈ 17 × -0.015em ≈ -0.25pt。
    func ljSectionHeaderStyle() -> some View {
        let kern: CGFloat = {
            #if os(macOS)
            return -0.25
            #else
            return -0.34
            #endif
        }()
        return self
            .font(.lj.sectionHeader)
            .kerning(kern)
            .foregroundStyle(Color.lj.ink)
    }

    /// 卡片标题样式（Project / Event 标题）。kerning ≈ 15 × -0.015em ≈ -0.22pt。
    func ljCardTitleStyle() -> some View {
        self
            .font(.lj.cardTitle)
            .kerning(-0.22)
            .foregroundStyle(Color.lj.ink)
    }

    /// Urgent bubble 标题样式。kerning ≈ 14.5 × -0.005em ≈ -0.07pt。
    func ljBubbleUrgentStyle() -> some View {
        self
            .font(.lj.bubbleUrgent)
            .kerning(-0.07)
            .foregroundStyle(Color.lj.ink)
    }

    /// Normal bubble 标题样式。kerning 同 urgent（-0.005em）。
    func ljBubbleNormalStyle() -> some View {
        self
            .font(.lj.bubbleNormal)
            .kerning(-0.07)
            .foregroundStyle(Color.lj.ink)
    }

    /// 正文样式。kerning ≈ 13 × -0.005em ≈ -0.06pt。
    func ljBodyStyle() -> some View {
        self
            .font(.lj.body)
            .kerning(-0.06)
            .foregroundStyle(Color.lj.ink)
    }

    /// Caption / meta 文字样式。无 kerning。颜色 inkSoft。
    func ljCaptionStyle() -> some View {
        self
            .font(.lj.caption)
            .foregroundStyle(Color.lj.inkSoft)
    }

    /// 全大写 tag pill 文字样式。kerning ≈ 10.5 × +0.07em ≈ +0.74pt（正向 letter-spacing）。
    /// 颜色 inkMute 让 tag 看起来不抢戏。
    func ljTagStyle() -> some View {
        self
            .font(.lj.tag)
            .kerning(0.74)
            .textCase(.uppercase)
            .foregroundStyle(Color.lj.inkMute)
    }

    /// 等宽数字 / 时间样式（tabular-nums + 等宽字形）。kerning ≈ 11.5 × -0.02em ≈ -0.23pt。
    func ljMonoStyle() -> some View {
        self
            .font(.lj.mono.monospacedDigit())
            .kerning(-0.23)
            .foregroundStyle(Color.lj.inkSoft)
    }
}
