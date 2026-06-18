// PrimaryButton.swift
// v1.3 R2–R5 件：子页主按钮「＋新建…」（品牌渐变实心）。
//
// 用于个人 / 公司 / 日历 / 灵感 各屏头部的主操作按钮。区别于 LJSecondaryButton（白底紫 hairline）：
// 品牌渐变实心 + brandGlow 投影 + 白字白 icon。
//
// 真理源：design_handoff_linoj_frontend/LinoJ 主页.dc.html inline style：
//   padding:9px 16px；border-radius:11(mac)/12(iOS)；background:linear-gradient(135°,#5B8DEF,#8A6DF0)；
//   box-shadow:0 6px 16px rgba(123,109,240,0.35~0.4)；color:#fff；icon stroke #fff 2.5；font 13(mac)/13.5(iOS) 600。

import SwiftUI

/// 子页主按钮（品牌渐变 + brandGlow 投影 + 白字白 icon）。默认带前置「＋」SF Symbol。
public struct LJPrimaryButton: View {
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
        return 11
        #else
        return 12
        #endif
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .default))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, LJSpacing.s16)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LJGradients.brand)
            }
            .shadow(color: Color.lj.brandGlow, radius: 8, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Primary button", traits: .sizeThatFitsLayout) {
    LJPrimaryButton(LJStrings.newPersonalTodo) {}
        .padding(LJSpacing.s16)
        .background(Color.lj.bg)
}
#endif
