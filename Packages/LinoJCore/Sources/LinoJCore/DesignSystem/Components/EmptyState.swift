// EmptyState.swift
// 通用空状态块：小几何 SVG 风 icon + display 标题 + 温和副标 + 可选 CTA。
//
// 设计参考：design_handoff_linoj/empty-states.jsx 中 `EmptyArt` 的 5 个 kind。
// P2 实现其中 4 个 variant：
//   inboxZero  → check 风 icon（虚线圈 + 钩号），标题 "Inbox zero."
//   urgentEmpty → sparkle 风 icon，标题 "Nothing urgent." 副标 "Nice."
//   clearWeek   → calendar 风 icon，标题 "A clear week."
//   noResults(q) → search 风 icon，标题 'No matches for "q"'
//
// SVG 通过 SwiftUI `Path` 重画，保证矢量 + 跟随 colorScheme。

import SwiftUI

public struct EmptyState: View {
    public enum Variant: Hashable {
        case inboxZero
        case urgentEmpty
        case clearWeek
        case noResults(String)
    }

    private let variant: Variant
    private let ctaTitle: LocalizedStringResource?
    private let action: (() -> Void)?

    public init(
        variant: Variant,
        ctaTitle: LocalizedStringResource? = nil,
        action: (() -> Void)? = nil
    ) {
        self.variant = variant
        self.ctaTitle = ctaTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: LJSpacing.s14) {
            icon
                .frame(width: 72, height: 72)

            Text(title)
                .font(.system(size: 19, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.ink)
                .kerning(-0.38)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 13.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if let ctaTitle, let action {
                Button(action: action) {
                    Text(ctaTitle)
                        .font(.system(size: 12.5, weight: .semibold, design: .default))
                        .foregroundStyle(Color.lj.panel)
                        .padding(.horizontal, LJSpacing.s14)
                        .padding(.vertical, 7)
                        .background {
                            RoundedRectangle(cornerRadius: LJRadii.chip, style: .continuous)
                                .fill(Color.lj.ink)
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, LJSpacing.s4)
            }
        }
        .padding(.vertical, LJSpacing.s28)
        .padding(.horizontal, LJSpacing.s22)
        .frame(maxWidth: .infinity)
        // P6：出现时淡入 0.2s（README「Empty state appearance」要求）。
        .ljEmptyStateAppearance()
    }

    // MARK: 文案

    /// P5：title 走 LocalizedStringResource，由 SwiftUI Text 在渲染时解析当前 locale。
    private var title: LocalizedStringResource {
        switch variant {
        case .inboxZero:        return LJStrings.emptyInboxZeroTitle
        case .urgentEmpty:      return LJStrings.emptyUrgentEmptyTitle
        case .clearWeek:        return LJStrings.emptyClearWeekTitle
        case .noResults(let q): return LJStrings.emptyNoResultsTitle(q)
        }
    }

    private var subtitle: LocalizedStringResource {
        switch variant {
        case .inboxZero:    return LJStrings.emptyInboxZeroSubtitle
        case .urgentEmpty:  return LJStrings.emptyUrgentEmptySubtitle
        case .clearWeek:    return LJStrings.emptyClearWeekSubtitle
        case .noResults:    return LJStrings.emptyNoResultsSubtitle
        }
    }

    // MARK: 几何 icon

    @ViewBuilder
    private var icon: some View {
        switch variant {
        case .inboxZero:   inboxZeroIcon
        case .urgentEmpty: urgentEmptyIcon
        case .clearWeek:   clearWeekIcon
        case .noResults:   noResultsIcon
        }
    }

    /// inboxZero: 虚线圈 + 钩号。
    private var inboxZeroIcon: some View {
        ZStack {
            // 虚线圆
            Circle()
                .strokeBorder(
                    Color.lj.inkMute,
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 5])
                )
            // 钩号（半透明 ink）
            Path { p in
                p.move(to: CGPoint(x: 24, y: 36))
                p.addLine(to: CGPoint(x: 33, y: 45))
                p.addLine(to: CGPoint(x: 49, y: 27))
            }
            .stroke(
                Color.lj.ink.opacity(0.45),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
        }
    }

    /// urgentEmpty: 散射 + 中心点（sparkle）。
    private var urgentEmptyIcon: some View {
        ZStack {
            // 8 条短线（上下左右 + 四对角）
            ForEach(0..<8, id: \.self) { i in
                Rectangle()
                    .fill(Color.lj.inkMute)
                    .frame(width: 1.5, height: 9)
                    .offset(y: -24)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            // 中心晕
            Circle().fill(Color.lj.ink).opacity(0.18).frame(width: 14, height: 14)
            Circle().fill(Color.lj.ink).opacity(0.45).frame(width: 7, height: 7)
        }
    }

    /// clearWeek: 日历框（含 7 道横线感觉，简化为 1 道分隔 + 中心点）。
    private var clearWeekIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.lj.inkMute, lineWidth: 1.5)
                .frame(width: 44, height: 40)
                .offset(y: 4)
            // 顶部装订
            Rectangle().fill(Color.lj.inkMute).frame(width: 1.5, height: 10).offset(x: -12, y: -10)
            Rectangle().fill(Color.lj.inkMute).frame(width: 1.5, height: 10).offset(x: 12,  y: -10)
            // 分隔线
            Rectangle().fill(Color.lj.inkMute).frame(width: 44, height: 1).offset(y: -6)
            // 中心点
            Circle().fill(Color.lj.ink).opacity(0.3).frame(width: 6, height: 6).offset(y: 8)
        }
    }

    /// noResults: 放大镜。
    private var noResultsIcon: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.lj.inkMute, lineWidth: 1.8)
                .frame(width: 28, height: 28)
                .offset(x: -4, y: -4)
            // 镜柄
            Path { p in
                p.move(to: CGPoint(x: 44, y: 44))
                p.addLine(to: CGPoint(x: 56, y: 56))
            }
            .stroke(
                Color.lj.inkMute,
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
            )
            // 镜内横线（表示「找不到结果」）
            Rectangle()
                .fill(Color.lj.ink.opacity(0.4))
                .frame(width: 12, height: 1.5)
                .offset(x: -4, y: -4)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("inboxZero", traits: .sizeThatFitsLayout) {
    EmptyState(variant: .inboxZero, ctaTitle: LJStrings.emptyInboxZeroCTA, action: {})
        .frame(width: 480)
        .padding(LJSpacing.s16)
        .background(Color.lj.bg)
}

#Preview("urgentEmpty", traits: .sizeThatFitsLayout) {
    EmptyState(variant: .urgentEmpty)
        .frame(width: 360)
        .ljDashedBorder()
        .padding(LJSpacing.s16)
        .background(Color.lj.bg)
}

#Preview("clearWeek", traits: .sizeThatFitsLayout) {
    EmptyState(variant: .clearWeek, ctaTitle: LJStrings.emptyClearWeekCTA, action: {})
        .frame(width: 600)
        .padding(LJSpacing.s16)
        .background(Color.lj.bg)
}

#Preview("noResults", traits: .sizeThatFitsLayout) {
    EmptyState(variant: .noResults("renovate the moon"))
        .frame(width: 480)
        .padding(LJSpacing.s16)
        .background(Color.lj.bg)
}

#Preview("Dark", traits: .sizeThatFitsLayout) {
    EmptyState(variant: .inboxZero, ctaTitle: LJStrings.emptyInboxZeroCTA, action: {})
        .frame(width: 480)
        .padding(LJSpacing.s16)
        .background(Color.lj.bg)
        .environment(\.colorScheme, .dark)
}
#endif
