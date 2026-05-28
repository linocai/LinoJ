// TodoBubble.swift
// Todo 列表中的单个 bubble。
//
// 视觉规格（README + direction-a.jsx）：
//   urgent：blueSoft 底 + 3pt blue 左 accent + ink 标题 600 14.5pt
//   normal：panel 底 + 细 border + ink 标题 500 13.5pt
// 设计稿的 checkbox 暂留到 P3 实施时增强；P2 给出可点击容器（onToggleDone）即可。

import SwiftUI

/// Todo 列表 bubble。点击触发 `onToggleDone`（P2 仅挂 gesture，行为留 ViewModel 接）。
public struct TodoBubble: View {
    private let todo: Todo
    private let onToggleDone: () -> Void

    public init(todo: Todo, onToggleDone: @escaping () -> Void = {}) {
        self.todo = todo
        self.onToggleDone = onToggleDone
    }

    public var body: some View {
        let urgent = todo.urgency == .urgent
        return HStack(alignment: .top, spacing: LJSpacing.s10) {
            // 简化的 checkbox 占位：实心方框（done） / 空方框（未 done）。
            // P3 阶段再做完整 SF Symbol checkbox。
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(
                        urgent ? Color.lj.blue : Color.lj.inkMute,
                        lineWidth: 1.2
                    )
                    .frame(width: urgent ? 17 : 15, height: urgent ? 17 : 15)

                if todo.done {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(urgent ? Color.lj.blue : Color.lj.ink)
                        .frame(width: urgent ? 11 : 9, height: urgent ? 11 : 9)
                }
            }
            .padding(.top, 1)
            // I10: 本地化 accessibility label。
            .accessibilityLabel(todo.done ? Text(LJStrings.a11yCompletedSuffix) : Text(LJStrings.a11yOpenSuffix))

            // 标题 + 可选 project chip
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

                if let project = todo.project {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.lj.inkMute)
                            .frame(width: 4, height: 4)
                        Text(project.title)
                            .font(.lj.caption)
                            .foregroundStyle(Color.lj.inkSoft)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.lj.chip)
                    }
                }
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
