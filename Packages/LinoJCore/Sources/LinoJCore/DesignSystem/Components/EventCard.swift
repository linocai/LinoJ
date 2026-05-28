// EventCard.swift
// Event 卡片，四种 variant：macWeekGrid / macRail / iosMini / iosFull。
//
// 共同视觉特征：
//   - 左侧 2pt 黑色 accent bar（urgent 蓝色不适用 —— Event 不分 urgency）；
//   - mono 时间 + 标题；
//   - iOS full 还要 location + AvatarStack。

import SwiftUI

public struct EventCard: View {
    public enum Variant: Hashable {
        case macWeekGrid
        case macRail
        case iosMini
        case iosFull
    }

    private let event: Event
    private let variant: Variant

    public init(event: Event, variant: Variant) {
        self.event = event
        self.variant = variant
    }

    public var body: some View {
        switch variant {
        case .macWeekGrid: macWeekGridBody
        case .macRail:     macRailBody
        case .iosMini:     iosMiniBody
        case .iosFull:     iosFullBody
        }
    }

    // MARK: 时间格式

    /// "09:30" / "14:00" 等。Tabular-nums 在 mono font 里已自带。
    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: event.start)
    }

    private var endText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: event.end)
    }

    /// macWeekGrid 用的 AM/PM 时间（"9:30 AM" / "3 PM"，整点省略 :00）。
    /// 与设计稿一致固定英文格式：用 `en_US` locale，不随 App 中文 locale 变化。
    private var clockText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        let cal = Calendar.current
        let minute = cal.component(.minute, from: event.start)
        // 整点 → "3 PM"；非整点 → "9:30 AM"。
        f.dateFormat = (minute == 0) ? "h a" : "h:mm a"
        return f.string(from: event.start)
    }

    /// "时间 · 地点"；location 为空时只显示时间（不带 " · "）。
    private var clockAndLocationText: String {
        let loc = event.location.trimmingCharacters(in: .whitespaces)
        return loc.isEmpty ? clockText : "\(clockText) · \(loc)"
    }

    // MARK: macOS 周视图小时槽内卡片
    //
    // 对齐设计稿 macWeekGrid（自上而下）：标题（粗体）→「时间 · 地点」（灰色小字）→ 头像栈（底部）。
    // 高度自适应：用 GeometryReader 读卡片实际高度——
    //   - 标题恒显（至少标题可见）；
    //   - 时间行仅在 ≥ 二级高度时显示；
    //   - 头像栈仅在卡片够高（≥ avatarMinHeight，约 ≥1.2h 槽）且有 attendees 时显示（设计 h>50 才显示）。
    // 内容顶对齐 + 整体 .clipped()，短事件溢出部分被裁掉，绝不溢出卡片边界。

    private var macWeekGridBody: some View {
        let attendees = event.attendees ?? []
        return GeometryReader { geo in
            let h = geo.size.height
            // 阈值：时间行约需 ~30pt；头像栈底部约需 ~56pt（设计 h>50）。
            let showTime = h >= 30
            let showAvatars = h >= 56 && !attendees.isEmpty

            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(Color.lj.ink)
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(Color.lj.ink)
                        .lineLimit(showTime ? 2 : 1)
                    if showTime {
                        Text(clockAndLocationText)
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundStyle(Color.lj.inkSoft)
                            .lineLimit(1)
                    }
                    if showAvatars {
                        Spacer(minLength: 2)
                        AvatarStack(people: attendees, max: 3)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.lj.panel)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    // MARK: macOS Main 右栏 day-row 中的事件 row

    private var macRailBody: some View {
        HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s10) {
            Text(timeText)
                .ljMonoStyle()
                .frame(width: 44, alignment: .leading)
            Text(event.title)
                .font(.lj.caption)
                .foregroundStyle(Color.lj.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    // MARK: iOS Main "Upcoming today" 横向 scroll mini card

    private var iosMiniBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(timeText).ljMonoStyle()
            Text(event.title)
                .font(.lj.cardTitle)
                .foregroundStyle(Color.lj.ink)
                .lineLimit(2)
            if !event.location.isEmpty {
                Text(event.location)
                    .font(.lj.caption)
                    .foregroundStyle(Color.lj.inkSoft)
                    .lineLimit(1)
            }
        }
        .frame(width: 200, alignment: .leading)
        .frame(minHeight: 90, alignment: .topLeading)
        .ljCardStyle()
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.lj.ink)
                .frame(width: 2)
                .padding(.vertical, 10)
        }
    }

    // MARK: iOS Calendar 单日 list 大卡

    private var iosFullBody: some View {
        HStack(alignment: .top, spacing: LJSpacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeText).ljMonoStyle()
                Text(endText)
                    .font(.lj.mono)
                    .foregroundStyle(Color.lj.inkMute)
            }
            .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title).ljCardTitleStyle()
                if !event.location.isEmpty {
                    Text(event.location)
                        .font(.lj.caption)
                        .foregroundStyle(Color.lj.inkSoft)
                }
                if !(event.attendees ?? []).isEmpty {
                    AvatarStack(people: event.attendees ?? [], max: 4)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ljCardStyle()
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.lj.ink)
                .frame(width: 2)
                .padding(.vertical, 10)
        }
    }
}

// MARK: - Preview

#if DEBUG
private func sampleEvent() -> Event {
    Event(
        title: "Morning standup",
        start: Date().addingTimeInterval(60 * 30),
        end:   Date().addingTimeInterval(60 * 60),
        location: "Zoom",
        attendees: [Person(name: "Mei"), Person(name: "Andrew"), Person(name: "Kai")]
    )
}

#Preview("macWeekGrid", traits: .sizeThatFitsLayout) {
    EventCard(event: sampleEvent(), variant: .macWeekGrid)
        .frame(width: 130, height: 64)
        .padding(LJSpacing.s16)
        .background(Color.lj.bg)
}

#Preview("macRail", traits: .sizeThatFitsLayout) {
    EventCard(event: sampleEvent(), variant: .macRail)
        .frame(width: 320)
        .padding(LJSpacing.s16)
        .background(Color.lj.bg)
}

#Preview("iosMini", traits: .sizeThatFitsLayout) {
    EventCard(event: sampleEvent(), variant: .iosMini)
        .padding(LJSpacing.s16)
        .background(Color.lj.iosMainBg)
}

#Preview("iosFull", traits: .sizeThatFitsLayout) {
    EventCard(event: sampleEvent(), variant: .iosFull)
        .frame(width: 380)
        .padding(LJSpacing.s16)
        .background(Color.lj.iosMainBg)
}
#endif
