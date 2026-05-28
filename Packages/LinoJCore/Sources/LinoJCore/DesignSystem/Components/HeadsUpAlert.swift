// HeadsUpAlert.swift
// Main 顶部的「Heads up」即将开始事件提醒。
//
// 视觉规格（README）：
//   - 整体 full-width pill；底色 blueSoft；边框 blueBorder；圆角 LJRadii.card；
//   - 左侧脉冲蓝点（opacity 0.4 ↔ 0.9 + scale 0.7 ↔ 1.0，2s ease-in-out 无限循环）；
//   - 文案 "Heads up · in X min · 标题 · 地点"；
//   - 右侧两个按钮：Snooze（plain）+ Open（ink fill pill）。

import SwiftUI

public struct HeadsUpAlert: View {
    private let event: Event
    private let minutesUntil: Int
    private let onSnooze: () -> Void
    private let onOpen: () -> Void

    /// 控制脉冲动画的状态。@State 必须在 View 上，且初始为 false，
    /// 在 `.task` / `.onAppear` 中翻转到 true 启动 repeatForever 动画。
    @State private var pulsing = false

    public init(
        event: Event,
        minutesUntil: Int,
        onSnooze: @escaping () -> Void = {},
        onOpen: @escaping () -> Void = {}
    ) {
        self.event = event
        self.minutesUntil = minutesUntil
        self.onSnooze = onSnooze
        self.onOpen = onOpen
    }

    public var body: some View {
        HStack(alignment: .center, spacing: LJSpacing.s12) {
            // 脉冲蓝点
            Circle()
                .fill(Color.lj.blue)
                .frame(width: 10, height: 10)
                .scaleEffect(pulsing ? 1.0 : 0.7)
                .opacity(pulsing ? 0.9 : 0.4)
                .animation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: pulsing
                )

            // 文案
            HStack(spacing: 6) {
                Text(LJStrings.headsUp)
                    .font(.system(size: 12.5, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.blueInk)
                dot
                Text(LJStrings.headsUpInMinutes(minutesUntil))
                    .ljMonoStyle()
                    .foregroundStyle(Color.lj.blueInk)
                dot
                Text(event.title)
                    .font(.system(size: 12.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.ink)
                    .lineLimit(1)
                if !event.location.isEmpty {
                    dot
                    Text(event.location)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(Color.lj.inkSoft)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 按钮
            Button(action: onSnooze) {
                Text(LJStrings.headsUpSnooze)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                    .padding(.horizontal, LJSpacing.s10)
                    .padding(.vertical, 5)
                    .background {
                        RoundedRectangle(cornerRadius: LJRadii.chip, style: .continuous)
                            .fill(Color.lj.chip)
                    }
            }
            .buttonStyle(.plain)

            Button(action: onOpen) {
                Text(LJStrings.headsUpOpen)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(Color.lj.panel)
                    .padding(.horizontal, LJSpacing.s12)
                    .padding(.vertical, 5)
                    .background {
                        Capsule(style: .continuous).fill(Color.lj.ink)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, LJSpacing.s14)
        .padding(.vertical, LJSpacing.s10)
        .background {
            RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous)
                .fill(Color.lj.blueSofter)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous)
                .strokeBorder(Color.lj.blueBorder, lineWidth: 0.5)
        }
        .onAppear { pulsing = true }
    }

    /// 文案分隔小点。
    private var dot: some View {
        Text("·").foregroundStyle(Color.lj.inkDim)
    }
}

// MARK: - Preview

#if DEBUG
private func sampleHeadsUpEvent() -> Event {
    Event(
        title: "Morning standup",
        start: Date().addingTimeInterval(60 * 10),
        end:   Date().addingTimeInterval(60 * 40),
        location: "Zoom",
        attendees: [Person(name: "Mei"), Person(name: "Andrew")]
    )
}

#Preview("Light", traits: .sizeThatFitsLayout) {
    HeadsUpAlert(event: sampleHeadsUpEvent(), minutesUntil: 10)
        .padding(LJSpacing.s16)
        .frame(width: 760)
        .background(Color.lj.bg)
}

#Preview("Dark", traits: .sizeThatFitsLayout) {
    HeadsUpAlert(event: sampleHeadsUpEvent(), minutesUntil: 22)
        .padding(LJSpacing.s16)
        .frame(width: 760)
        .background(Color.lj.bg)
        .environment(\.colorScheme, .dark)
}
#endif
