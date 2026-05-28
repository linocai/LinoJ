// Modifiers.swift
// 共享 View modifier —— bubble / card / completed-box / dashed border / tag pill / hover lift。
//
// 这些是 P2 各原子组件复用的视觉基本块。每个 modifier 内部按平台 #if 切换尺寸细节，
// 但对外接口跨平台一致。

import SwiftUI

// MARK: - Bubble style (urgent / normal)

/// `ljBubbleStyle(urgent:)` 的内部实现 modifier。
///
/// urgent 视觉：背景 blueSoft、边框 blueBorder、左侧 3pt blue accent；
/// normal 视觉：背景 panel、边框 border、无左侧 bar。
private struct LJBubbleModifier: ViewModifier {
    let urgent: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, LJSpacing.s12)
            .padding(.horizontal, LJSpacing.s14)
            // 左侧多留 2pt 让 accent bar 不压标题
            .padding(.leading, urgent ? 2 : 0)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(urgent ? Color.lj.blueSoft : Color.lj.panel)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        urgent ? Color.lj.blueBorder : Color.lj.border,
                        lineWidth: 0.5
                    )
            }
            .overlay(alignment: .leading) {
                if urgent {
                    // 3pt 宽蓝色 accent bar，上下各 8pt 内缩，圆角 1pt
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.lj.blue)
                        .frame(width: 3)
                        .padding(.vertical, 8)
                        .padding(.leading, 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

// MARK: - Card style

/// `ljCardStyle()` 的内部实现。
///
/// 视觉：panel 背景、0.5pt border、12pt 圆角、14pt padding。
private struct LJCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(LJSpacing.s14)
            .background {
                RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous)
                    .fill(Color.lj.panel)
            }
            .overlay {
                RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
    }
}

// MARK: - Completed box style (dashed border)

/// `ljCompletedBoxStyle()` 的内部实现。
///
/// 视觉：dashed border 灰框（borderStrong）、12pt 圆角、14pt padding。
/// 不填背景 —— 让 CompletedBox 在父级背景上呼吸。
private struct LJCompletedBoxModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(LJSpacing.s14)
            .background {
                RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous)
                    .strokeBorder(
                        Color.lj.borderStrong,
                        style: StrokeStyle(lineWidth: 1.0, dash: [4, 4])
                    )
            }
    }
}

// MARK: - Dashed border (generic helper)

/// `ljDashedBorder(...)` 的内部实现。
///
/// 不改背景，只叠加一层 dashed stroke。lineWidth 1.5pt（README "1.5pt 虚线" 验收要求）。
private struct LJDashedBorderModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        color,
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                    )
            }
    }
}

// MARK: - Tag pill

/// `ljTagPill()` 的内部实现。
///
/// 视觉：chip 背景填充 + 横向 8pt + 纵向 3pt padding + pill 圆角；
/// 文字样式由 `ljTagStyle()` 控制（uppercase + kerning + tag font）。
private struct LJTagPillModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .ljTagStyle()
            .padding(.horizontal, LJSpacing.s8)
            .padding(.vertical, 3)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.lj.chip)
            }
    }
}

// MARK: - Hover lift (macOS only)

#if os(macOS)
/// macOS 鼠标 hover 时整体 `translateY(-1pt)`，0.12s ease-out。
/// iOS 不存在 hover，这部分编译时跳过；外层 public modifier 在 iOS 上返回 self。
struct LJHoverLiftModifier: ViewModifier {
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .offset(y: hovered ? -1 : 0)
            .animation(.easeOut(duration: 0.12), value: hovered)
            .onHover { hovered = $0 }
    }
}

// MARK: - Hover background (macOS list row tint)

/// `ljHoverBackground()` 的内部实现 —— P6「macOS list row」hover 视觉规格：
/// 鼠标悬停时背景填 `Color.lj.chip`（约 rgba(10,10,10,0.04)）。
/// 用 RoundedRectangle 兜底圆角 6pt，调用方一般已 padding 过；
/// 不渲染背景时返回透明色，避免影响布局。
struct LJHoverBackgroundModifier: ViewModifier {
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovered ? Color.lj.chip : Color.clear)
            )
            .animation(.easeOut(duration: 0.12), value: hovered)
            .onHover { hovered = $0 }
    }
}
#endif

// MARK: - Empty state appearance (fade-in)

/// `ljEmptyStateAppearance()` 的内部实现 —— P6「Empty state appearance：fade-in 0.2s」。
/// 在 onAppear 翻 visible 标志，初始 opacity 0 → 1，0.2s easeInOut。
private struct LJEmptyStateAppearanceModifier: ViewModifier {
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: visible)
            .onAppear { visible = true }
    }
}

// MARK: - Public API

public extension View {

    /// Todo bubble 视觉。urgent=true 走 blue 系列；urgent=false 走 panel 系列。
    func ljBubbleStyle(urgent: Bool) -> some View {
        modifier(LJBubbleModifier(urgent: urgent))
    }

    /// 通用卡片样式（panel 背景 + 细边 + 12pt 圆角 + 14pt padding）。
    func ljCardStyle() -> some View {
        modifier(LJCardModifier())
    }

    /// CompletedBox 样式（dashed 灰框，无背景填充）。
    func ljCompletedBoxStyle() -> some View {
        modifier(LJCompletedBoxModifier())
    }

    /// 虚线描边帮手。默认色 borderStrong、半径 card；可覆盖。
    func ljDashedBorder(
        color: Color = Color.lj.borderStrong,
        radius: CGFloat = LJRadii.card
    ) -> some View {
        modifier(LJDashedBorderModifier(color: color, radius: radius))
    }

    /// 全大写小 chip pill —— 用于 project tag 等。
    func ljTagPill() -> some View {
        modifier(LJTagPillModifier())
    }

    /// macOS hover 抬起 1pt；iOS 无效果（编译时直接返回 self）。
    @ViewBuilder
    func ljHoverLift() -> some View {
        #if os(macOS)
        modifier(LJHoverLiftModifier())
        #else
        self
        #endif
    }

    /// macOS 列表行 hover 时填 `Color.lj.chip` 背景；iOS 无效果（编译时直接返回 self）。
    /// 用于 Search palette 行、Personal compact completed row 等场景 —— bubble 行
    /// 已经用 `ljHoverLift()` 表达 hover 状态，不要叠加。
    @ViewBuilder
    func ljHoverBackground() -> some View {
        #if os(macOS)
        modifier(LJHoverBackgroundModifier())
        #else
        self
        #endif
    }

    /// 空状态出现时的淡入动画（0.2s easeInOut）—— plan P6「Empty state appearance」。
    /// 跨平台一致；用在 EmptyState 容器外层即可，重复 `.onAppear` 不会触发额外副作用。
    func ljEmptyStateAppearance() -> some View {
        modifier(LJEmptyStateAppearanceModifier())
    }
}
