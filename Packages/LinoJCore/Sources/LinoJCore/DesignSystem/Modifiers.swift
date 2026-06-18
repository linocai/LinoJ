// Modifiers.swift
// 共享 View modifier —— bubble / card / completed-box / dashed border / tag pill / hover lift。
//
// 这些是 P2 各原子组件复用的视觉基本块。每个 modifier 内部按平台 #if 切换尺寸细节，
// 但对外接口跨平台一致。

import SwiftUI

// MARK: - 顶部内高光 helper（v1.3 玻璃深度收边复用）

/// 玻璃面板 / 气泡的「顶部内高光」：inset 0 0.5px 0 rgba(255,255,255,0.6~0.9) 的 SwiftUI 近似。
/// 用一条线性渐变 stroke（顶边白高光 → 向下迅速透明）叠在圆角矩形上缘，制造材质受光的浮起感。
/// dark 下高光降弱，避免发灰。
/// public：App target（macOS 顶栏玻璃 pill / 图标按钮）也直接复用，保证收边一致。
public struct LJTopHighlight: View {
    let radius: CGFloat
    @Environment(\.colorScheme) private var scheme

    /// - radius: 顶高光圆角，需与所贴的圆角矩形一致。
    public init(radius: CGFloat) {
        self.radius = radius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(scheme == .dark ? 0.22 : 0.85),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.75
            )
            // 高光主要在上缘：用 mask 让下半截渐隐（线性 stroke 已渐隐，这里再压一层保证只亮顶边）。
            .mask(
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .allowsHitTesting(false)
    }
}

// MARK: - Bubble style (urgent / normal) — v1.3 紫蓝 + 原生材质

/// `ljBubbleStyle(urgent:)` 的内部实现 modifier（v1.3）。
///
/// urgent：urgentSoft 软底 + urgentBorder + 顶高光 + 左 3pt 品牌渐变全高竖条（上下内缩 9pt），圆角 13。
/// normal：`.ultraThinMaterial` 克制半透（密集小气泡不挂重 blur）+ hairline + 顶高光，圆角 13。
private struct LJBubbleModifier: ViewModifier {
    let urgent: Bool
    private let r = LJRadii.card  // 13

    func body(content: Content) -> some View {
        content
            // .dc.html: padding 11px 13px（urgent 左 16px 给竖条让位）
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .padding(.leading, urgent ? 3 : 0)
            .background {
                if urgent {
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .fill(Color.lj.urgentSoft)
                } else {
                    // 密集小气泡：克制半透原生材质（不挂 .regularMaterial 重玻璃，防糊 + 拖性能）。
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(
                        urgent ? Color.lj.urgentBorder : Color.lj.border,
                        lineWidth: 0.5
                    )
            }
            // 顶部内高光（材质浮起感）
            .overlay { LJTopHighlight(radius: r) }
            .overlay(alignment: .leading) {
                if urgent {
                    // 3pt 宽品牌渐变全高竖条，上下各内缩 9pt（.dc.html: top:9 bottom:9）。
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(LJGradients.brandVertical)
                        .frame(width: 3)
                        .padding(.vertical, 9)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }
}

// MARK: - Card style — v1.3 容器级玻璃

/// `ljCardStyle()` 的内部实现（v1.3）。
///
/// 容器级玻璃：`.regularMaterial` + hairline + 顶高光 + 柔投影，圆角 card(13)、14pt padding。
/// 比 `ljGlassPanel()` 圆角小一档，用于内容卡片（右栏「最近灵感」缩略卡等）。
private struct LJCardModifier: ViewModifier {
    private let r = LJRadii.card

    func body(content: Content) -> some View {
        content
            .padding(LJSpacing.s14)
            .background {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
            .overlay { LJTopHighlight(radius: r) }
            .shadow(color: Color.lj.shadowCard, radius: 10, x: 0, y: 6)
    }
}

// MARK: - Glass panel — v1.3 容器级大玻璃面板

/// `ljGlassPanel()` 的内部实现（v1.3）。
///
/// 容器级大玻璃面板（右栏 Next 7 days / 富卡 / 周网格 / 笔记卡 / modal）：
/// `.regularMaterial` + hairline + 顶高光 + 较深柔投影，圆角 panel(18)。padding 由调用方控制。
private struct LJGlassPanelModifier: ViewModifier {
    let radius: CGFloat
    let padded: Bool

    func body(content: Content) -> some View {
        content
            .padding(padded ? LJSpacing.s18 : 0)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
            .overlay { LJTopHighlight(radius: radius) }
            // 右栏柔投影：.dc.html 0 9px 26px rgba(0,0,0,0.07)
            .shadow(color: Color.lj.shadowCard, radius: 13, x: 0, y: 9)
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

    /// 通用卡片样式（v1.3：.regularMaterial + hairline + 顶高光 + 柔投影 + 13pt 圆角 + 14pt padding）。
    func ljCardStyle() -> some View {
        modifier(LJCardModifier())
    }

    /// 容器级大玻璃面板（v1.3：.regularMaterial + hairline + 顶高光 + 深柔投影）。
    /// 用于右栏 Next 7 days / 项目富卡 / 周网格 / 笔记卡 / modal。
    /// - radius: 圆角，默认 panel(18)。
    /// - padded: 是否自带 18pt 内边距（默认 true）；需要自定 padding 时传 false。
    func ljGlassPanel(radius: CGFloat = LJRadii.panel, padded: Bool = true) -> some View {
        modifier(LJGlassPanelModifier(radius: radius, padded: padded))
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
