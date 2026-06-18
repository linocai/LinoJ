// TodoBubble.swift
// Todo 列表中的单个 bubble。
//
// 视觉规格（v1.3 design_handoff_linoj_frontend/LinoJ 主页.dc.html）：
//   urgent：urgentSoft 软底 + 品牌渐变全高左竖条 + 顶高光，标题 600 14px，圆角 13；
//   normal：.ultraThinMaterial 克制半透 + hairline + 顶高光，标题 500 13.5px，圆角 13。
//   checkbox 18px / 圆角 6 / 边框 1.5px；done = 品牌渐变实心 + 白勾。
//   showSource=true（仅主页）时标题下显示来源标签胶囊（个人灰 / 公司紫）+ 可选项目名胶囊。
//   showSource=false（Personal / Company 页）时仅显示项目名胶囊（若有），不显示来源标签。

import SwiftUI

/// Todo 列表 bubble。点击触发 `onToggleDone`。
/// - showSource: 是否显示来源标签胶囊（仅主页 Main 传 true；同 scope 页冗余，传 false）。
public struct TodoBubble: View {
    private let todo: Todo
    private let showSource: Bool
    private let onToggleDone: () -> Void

    public init(
        todo: Todo,
        showSource: Bool = false,
        onToggleDone: @escaping () -> Void = {}
    ) {
        self.todo = todo
        self.showSource = showSource
        self.onToggleDone = onToggleDone
    }

    public var body: some View {
        let urgent = todo.urgency == .urgent
        return HStack(alignment: .top, spacing: 11) {
            // checkbox：18px 圆角 6 边框 1.5px；done = 品牌渐变实心 + 白勾。
            checkbox(urgent: urgent)
                .padding(.top, 1)
                // I10: 本地化 accessibility label。
                .accessibilityLabel(todo.done ? Text(LJStrings.a11yCompletedSuffix) : Text(LJStrings.a11yOpenSuffix))

            // 标题 + 来源标签 / project chip
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if urgent {
                        Text(todo.title).ljBubbleUrgentStyle()
                    } else {
                        Text(todo.title).ljBubbleNormalStyle()
                    }
                }
                .strikethrough(todo.done, color: Color.lj.inkMute)
                .lineLimit(3)

                labelsRow(urgent: urgent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(todo.done ? 0.45 : 1)
        .ljBubbleStyle(urgent: urgent)
        .ljHoverLift()
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleDone()
        }
    }

    // MARK: - checkbox

    @ViewBuilder
    private func checkbox(urgent: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    todo.done ? Color.clear : (urgent ? Color.lj.accent.opacity(0.6) : Color.lj.inkMute),
                    lineWidth: 1.5
                )
                .frame(width: 18, height: 18)

            if todo.done {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LJGradients.brand)
                    .frame(width: 18, height: 18)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - 标签行（来源标签 + 项目名）

    @ViewBuilder
    private func labelsRow(urgent: Bool) -> some View {
        let projectName = todo.project?.title
        if showSource {
            // 主页：来源标签（+ 右侧并排项目名）。
            LJSourceLabel(scope: todo.scope, projectName: projectName, urgent: urgent)
        } else if let projectName, !projectName.isEmpty {
            // 同 scope 页：只显示项目名胶囊（紫点 urgent / 灰点 normal）。
            HStack(spacing: 5) {
                Circle()
                    .fill(urgent ? Color.lj.purpleDot : Color.lj.inkMute)
                    .frame(width: 5, height: 5)
                Text(projectName)
                    .font(.system(size: 10.5, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                    .lineLimit(1)
            }
            .padding(.horizontal, LJSpacing.s8)
            .padding(.vertical, 2)
            .background {
                RoundedRectangle(cornerRadius: LJRadii.sourceLabel, style: .continuous)
                    .fill(Color.lj.chip)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light", traits: .sizeThatFitsLayout) {
    VStack(spacing: LJSpacing.s10) {
        TodoBubble(todo: Todo(
            title: "Reply to Mom about Saturday",
            urgency: .urgent,
            scope: .personal
        ))
        TodoBubble(todo: Todo(
            title: "Buy groceries — eggs, milk, sourdough",
            urgency: .normal,
            scope: .personal
        ))
        TodoBubble(todo: Todo(
            title: "Schedule dentist",
            urgency: .normal,
            scope: .personal,
            done: true
        ))
    }
    .padding(LJSpacing.s16)
    .frame(width: 360)
    .background(Color.lj.bg)
}

#Preview("Dark", traits: .sizeThatFitsLayout) {
    VStack(spacing: LJSpacing.s10) {
        TodoBubble(todo: Todo(
            title: "Finalize macOS sidebar spec",
            urgency: .urgent,
            scope: .company
        ))
        TodoBubble(todo: Todo(
            title: "Write release notes draft",
            urgency: .normal,
            scope: .company
        ))
    }
    .padding(LJSpacing.s16)
    .frame(width: 360)
    .background(Color.lj.bg)
    .environment(\.colorScheme, .dark)
}
#endif
