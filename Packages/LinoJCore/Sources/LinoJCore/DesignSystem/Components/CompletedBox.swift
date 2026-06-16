// CompletedBox.swift
// 「已完成」可折叠 dashed-border 容器，用于 Personal / Company / Project detail 的底部。
//
// 视觉规格（README + direction-a-detail.jsx）：
//   - dashed 灰框（`ljCompletedBoxStyle` modifier）；
//   - 顶部 row "Completed (X)" + 右侧 chevron 默认朝右；
//   - 展开后 chevron 旋转 90°（朝下），0.18s ease；
//   - 折叠后只显示 header；展开后下方插入调用方提供的 content。
//
// v1.2 P5：二级 archive 折叠。`content` 显示「近 30 天」recent；当 `archiveCount > 0` 时，
// 在 recent 下方再嵌一行「+N earlier」二级 disclosure，点开才显示 `archiveContent`（更早的完成项）。
// 不删任何 completed todo —— 只是把超过 30 天的折进更深一层。
//
// 兼容旧调用：保留只有 `count` + `content` 的初始化器（archiveCount 默认 0 → 不渲染二级层）。

import SwiftUI

public struct CompletedBox<Content: View, ArchiveContent: View>: View {
    private let count: Int
    private let archiveCount: Int
    private let content: () -> Content
    private let archiveContent: () -> ArchiveContent
    @State private var expanded = false
    /// v1.2 P5：二级 archive 的展开态（独立于一级 expanded）。
    @State private var archiveExpanded = false

    /// v1.2 P5：完整初始化器 —— recent（`content`）+ archive（`archiveContent`）两段。
    /// - Parameters:
    ///   - count: 顶部 header 显示的总完成数（recent + archive）。
    ///   - archiveCount: 超过 30 天的 archive 条数；> 0 时渲染二级「+N earlier」折叠行。
    public init(
        count: Int,
        archiveCount: Int,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder archiveContent: @escaping () -> ArchiveContent
    ) {
        self.count = count
        self.archiveCount = archiveCount
        self.content = content
        self.archiveContent = archiveContent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 一级 Header（可点击切换 expanded）
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
                    // recent（近 30 天）。
                    content()

                    // v1.2 P5：二级 archive 折叠行 —— 仅当有更早的完成项时渲染。
                    if archiveCount > 0 {
                        archiveDisclosure
                    }
                }
                .padding(.top, LJSpacing.s10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .ljCompletedBoxStyle()
    }

    /// v1.2 P5：二级「+N earlier」disclosure —— 点开显示 archiveContent。
    @ViewBuilder
    private var archiveDisclosure: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                archiveExpanded.toggle()
            }
        } label: {
            HStack(spacing: LJSpacing.s8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.lj.inkMute)
                    .rotationEffect(.degrees(archiveExpanded ? 90 : 0))
                Text(LJStrings.completedEarlier(archiveCount))
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkMute)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if archiveExpanded {
            VStack(alignment: .leading, spacing: LJSpacing.s8) {
                archiveContent()
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - 兼容旧调用（仅 recent，无 archive 二级层）

public extension CompletedBox where ArchiveContent == EmptyView {
    /// 旧式初始化器 —— 只传 `count` + `content`，不渲染二级 archive 层（archiveCount = 0）。
    /// 既有调用点（ProjectDetail 等暂未拆 archive 的地方）继续可用。
    init(count: Int, @ViewBuilder content: @escaping () -> Content) {
        self.init(count: count, archiveCount: 0, content: content, archiveContent: { EmptyView() })
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

#Preview("With archive", traits: .sizeThatFitsLayout) {
    CompletedBox(
        count: 5,
        archiveCount: 3,
        content: {
            Text("recent one · done").font(.lj.caption).foregroundStyle(Color.lj.inkMute)
            Text("recent two · done").font(.lj.caption).foregroundStyle(Color.lj.inkMute)
        },
        archiveContent: {
            Text("old one · done").font(.lj.caption).foregroundStyle(Color.lj.inkMute)
        }
    )
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
