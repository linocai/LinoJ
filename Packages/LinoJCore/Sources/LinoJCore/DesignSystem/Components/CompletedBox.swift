// CompletedBox.swift
// 「已完成」可折叠 dashed-border 容器，用于 Personal / Company / Project detail 的底部。
//
// 视觉规格（README + direction-a-detail.jsx）：
//   - dashed 灰框（`ljCompletedBoxStyle` modifier）；
//   - 顶部 row "Completed (X)" + 右侧 chevron 默认朝右；
//   - 展开后 chevron 旋转 90°（朝下），0.18s ease；
//   - 折叠后只显示 header；展开后下方插入调用方提供的 content。

import SwiftUI

public struct CompletedBox<Content: View>: View {
    private let count: Int
    private let content: () -> Content
    @State private var expanded = false

    public init(count: Int, @ViewBuilder content: @escaping () -> Content) {
        self.count = count
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header（可点击切换 expanded）
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: LJSpacing.s10) {
                    // 本地化 "Completed (X)" / "已完成 (X)"。占位符 %d 由 LJStrings 工厂注入。
                    Text(LJStrings.sectionCompleted(count))
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(Color.lj.inkSoft)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.lj.inkMute)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 内容（折叠时隐藏）
            if expanded {
                VStack(alignment: .leading, spacing: LJSpacing.s8) {
                    content()
                }
                .padding(.top, LJSpacing.s10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .ljCompletedBoxStyle()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light collapsed", traits: .sizeThatFitsLayout) {
    CompletedBox(count: 2) {
        Text("schedule dentist · done").font(.lj.caption)
            .foregroundStyle(Color.lj.inkMute)
        Text("clean inbox · done").font(.lj.caption)
            .foregroundStyle(Color.lj.inkMute)
    }
    .frame(width: 480)
    .padding(LJSpacing.s16)
    .background(Color.lj.bg)
}

#Preview("Dark", traits: .sizeThatFitsLayout) {
    CompletedBox(count: 0) {
        Text("(empty)").font(.lj.caption)
    }
    .frame(width: 480)
    .padding(LJSpacing.s16)
    .background(Color.lj.bg)
    .environment(\.colorScheme, .dark)
}
#endif
