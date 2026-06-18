// SecondaryButton.swift
// v1.3 新功能件：次级按钮（＋新建项目 等）。
//
// 用于公司项目区标题行右侧「＋新建项目」。区别于主按钮（品牌渐变实心）：白底半透 + 紫 hairline + 紫字/icon。
//
// 真理源：design_handoff_linoj_frontend/LinoJ 主页.dc.html inline style：
//   白底 rgba(255,255,255,0.62~0.65)（→ 用 .ultraThinMaterial 近似半透白）+ 0.5px rgba(123,123,240,0.28~0.3) border
//   + 顶高光 + #6E63E6(accent) 字/icon；圆角 9(mac)/11(iOS)。

import SwiftUI

/// 次级按钮（白底 + 紫 hairline + 紫字）。默认带前置「＋」SF Symbol。
public struct LJSecondaryButton: View {
    private let title: LocalizedStringResource
    private let systemImage: String
    private let action: () -> Void

    public init(
        _ title: LocalizedStringResource,
        systemImage: String = "plus",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    private var radius: CGFloat {
        #if os(macOS)
        return 9
        #else
        return 11
        #endif
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: LJSpacing.s6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .default))
            }
            .foregroundStyle(Color.lj.accent)
            .padding(.horizontal, LJSpacing.s12)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.lj.accent.opacity(0.30), lineWidth: 0.5)
            }
            .overlay { LJTopHighlight(radius: radius) }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Secondary button", traits: .sizeThatFitsLayout) {
    LJSecondaryButton(LJStrings.tabCompany) {}
        .padding(LJSpacing.s16)
        .background(Color.lj.bg)
}
#endif
