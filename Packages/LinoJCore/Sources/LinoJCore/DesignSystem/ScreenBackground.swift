// ScreenBackground.swift
// v1.3 双端五屏前端重构：屏幕背景层（底色渐变 + 可选 bloom orb）。
//
// 这是「玻璃可见的前提」—— .regularMaterial / .ultraThinMaterial 背后必须有底色 / orb 透上来才显玻璃。
// 各屏根背景用 `someView.ljScreenBackground(.macOS)` 替换原来的 `Color.lj.bg.ignoresSafeArea()`。
//
// 真理源：design_handoff_linoj_frontend/LinoJ 主页.dc.html inline style：
//   macOS 底色 linear-gradient(135°, #F7F8FB→#EEF0F6)；iOS linear-gradient(160°, #F4F3EF→#EBEDF3)。
//   bloom orb（默认 on）三团 radial：
//     macOS：橙 @15%/12% a0.42 (→40%)、蓝 @92%/22% a0.46 (→44%)、紫 @80%/94% a0.40 (→46%)。
//     iOS：  橙 @18%/10% a0.40、蓝 @92%/16% a0.44、紫 @84%/90% a0.40。
//   注意 orb 含橙团但仅作背景柔光，与 urgent 语义无关。

import SwiftUI

/// 屏幕背景布局类型（控制底色渐变角度 + orb 锚点）。
public enum LJScreenLayout: Sendable {
    case macOS
    case iOS
}

/// `ljScreenBackground(_:bloom:)` 的内部实现。
private struct LJScreenBackgroundModifier: ViewModifier {
    let layout: LJScreenLayout
    let bloom: Bool

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    baseGradient
                    if bloom {
                        bloomOrbs
                    }
                }
                .ignoresSafeArea()
            }
    }

    /// 底色线性渐变（macOS 135° / iOS 160°，用 unitPoint 近似角度）。
    private var baseGradient: some View {
        let (top, bottom, start, end): (Color, Color, UnitPoint, UnitPoint) = {
            switch layout {
            case .macOS:
                // 135°：左上 → 右下
                return (Color.lj.bgGradTop, Color.lj.bgGradBottom, .topLeading, .bottomTrailing)
            case .iOS:
                // 160°：近垂直、略偏右下
                return (Color.lj.bgGradTopIOS, Color.lj.bgGradBottomIOS,
                        UnitPoint(x: 0.15, y: 0), UnitPoint(x: 0.85, y: 1))
            }
        }()
        return LinearGradient(colors: [top, bottom], startPoint: start, endPoint: end)
    }

    /// 三团 RadialGradient bloom orb 叠加（橙 / 蓝 / 紫），锚屏角、各约 40~46% 处归零。
    private var bloomOrbs: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // 半径取屏对角线一定比例（近似 CSS radial 的 N% transparent 归零点）。
            let diag = (w * w + h * h).squareRoot()

            let anchors: (warm: UnitPoint, blue: UnitPoint, purple: UnitPoint) = {
                switch layout {
                case .macOS:
                    return (UnitPoint(x: 0.15, y: 0.12),
                            UnitPoint(x: 0.92, y: 0.22),
                            UnitPoint(x: 0.80, y: 0.94))
                case .iOS:
                    return (UnitPoint(x: 0.18, y: 0.10),
                            UnitPoint(x: 0.92, y: 0.16),
                            UnitPoint(x: 0.84, y: 0.90))
                }
            }()

            ZStack {
                orb(color: Color.lj.orbWarm,   anchor: anchors.warm,   w: w, h: h, radius: diag * 0.42)
                orb(color: Color.lj.orbBlue,   anchor: anchors.blue,   w: w, h: h, radius: diag * 0.46)
                orb(color: Color.lj.orbPurple, anchor: anchors.purple, w: w, h: h, radius: diag * 0.48)
            }
        }
    }

    /// 单个 radial orb：从锚点处的实色渐隐到透明，直接叠在底色渐变上（normal blend，近似 CSS radial-gradient）。
    private func orb(color: Color, anchor: UnitPoint, w: CGFloat, h: CGFloat, radius: CGFloat) -> some View {
        RadialGradient(
            gradient: Gradient(colors: [color, color.opacity(0)]),
            center: anchor,
            startRadius: 0,
            endRadius: radius
        )
        .frame(width: w, height: h)
        .allowsHitTesting(false)
    }
}

public extension View {

    /// 屏幕背景层（底色渐变 + 可选 bloom orb）。
    /// 替换各屏原来的 `Color.lj.bg.ignoresSafeArea()`。玻璃材质背后需要它才显半透浮起。
    /// - layout: macOS / iOS（控制渐变角度 + orb 锚点）。
    /// - bloom: 是否启用 bloom orb（默认 true，决策 D-orb）。
    func ljScreenBackground(_ layout: LJScreenLayout, bloom: Bool = true) -> some View {
        modifier(LJScreenBackgroundModifier(layout: layout, bloom: bloom))
    }
}
