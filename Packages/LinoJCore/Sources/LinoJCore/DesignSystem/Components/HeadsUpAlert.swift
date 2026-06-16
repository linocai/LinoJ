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
    /// v1.2 P4：进行中标志 + 剩余分钟 + 「+N 更多」角标数。
    private let isOngoing: Bool
    private let remainingMinutes: Int
    private let moreCount: Int
    private let onSnooze: () -> Void
    private let onOpen: () -> Void

    /// 控制脉冲动画的状态。@State 必须在 View 上，且初始为 false，
    /// 在 `.task` / `.onAppear` 中翻转到 true 启动 repeatForever 动画。
    @State private var pulsing = false

    public init(
        event: Event,
        minutesUntil: Int,
        isOngoing: Bool = false,
        remainingMinutes: Int = 0,
        moreCount: Int = 0,
        onSnooze: @escaping () -> Void = {},
        onOpen: @escaping () -> Void = {}
    ) {
        self.event = event
        self.minutesUntil = minutesUntil
        self.isOngoing = isOngoing
        self.remainingMinutes = remainingMinutes
        self.moreCount = moreCount
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
                // v1.2 P4：进行中 → 「now · 还剩 Y 分」；未开始 → 「in X min」。
                Text(timeText)
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
                // v1.2 P4：窗口内还有其它即将开始事件时显示「+N 更多」角标（单条不堆叠）。
                if moreCount > 0 {
                    moreBadge
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

    /// v1.2 P4：时间文案 —— 进行中显示「now · 还剩 Y 分」，未开始显示「in X min」。
    private var timeText: LocalizedStringResource {
        isOngoing
            ? LJStrings.headsUpOngoing(remainingMinutes)
            : LJStrings.headsUpInMinutes(minutesUntil)
    }

    /// v1.2 P4：「+N 更多」角标 —— chip 样式小标签。
    private var moreBadge: some View {
        Text(LJStrings.headsUpMoreCount(moreCount))
            .font(.system(size: 11, weight: .semibold, design: .default))
            .foregroundStyle(Color.lj.blueInk)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule(style: .continuous).fill(Color.lj.blueSoft)
            }
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
