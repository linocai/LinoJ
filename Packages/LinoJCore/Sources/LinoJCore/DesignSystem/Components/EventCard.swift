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
    // v1.3 R4（对原型重建）：白底 + 0.5px hairline + **左 2.5px 色条** + 0 1px 3px 投影 + 圆角 8。
    //   色条颜色：挂了 project 的事件用紫 #8A6DF0（purpleDot），否则灰 rgba(60,60,67,0.35)（inkMute）。
    //   自上而下：mono 时间小字（原型 9.5px）→ 标题（11.5px/600）；高卡片再叠头像栈。
    // 内容顶对齐 + 整体 .clipped()，短事件溢出部分被裁掉，绝不溢出卡片边界。

    /// R4：左色条颜色 —— 挂 project 的事件用紫点色，否则中性灰（原型 ev.accent 逻辑）。
    private var weekGridAccent: Color {
        event.project != nil ? Color.lj.purpleDot : Color.lj.inkMute
    }

    private var macWeekGridBody: some View {
        let attendees = event.attendees ?? []
        return GeometryReader { geo in
            let h = geo.size.height
            // 阈值：时间行约需 ~26pt；头像栈底部约需 ~56pt（设计 h>50）。
            let showTime = h >= 26
            let showAvatars = h >= 56 && !attendees.isEmpty

            HStack(alignment: .top, spacing: 0) {
                // 左 2.5px 色条（原型 border-left:2.5px solid ev.accent）。
                Rectangle()
                    .fill(weekGridAccent)
                    .frame(width: 2.5)
                VStack(alignment: .leading, spacing: 1) {
                    if showTime {
                        Text(timeText)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.lj.inkSoft)
                            .lineLimit(1)
                    }
                    Text(event.title)
                        .font(.system(size: 11.5, weight: .semibold, design: .default))
                        .kerning(-0.12)
                        .foregroundStyle(Color.lj.ink)
                        .lineLimit(showTime ? 2 : 1)
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.lj.panel)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: Color.lj.shadowCard, radius: 2, x: 0, y: 1)
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

    /// iOS 卡片左色条 —— 挂 project 用紫（purpleDot），否则中性灰（inkMute）。对原型 ev.accent。
    private var iosAccent: Color {
        event.project != nil ? Color.lj.purpleDot : Color.lj.inkMute
    }

    // MARK: iOS Main "Upcoming today" 横向 scroll mini card
    //
    // v1.3 R7（对原型重建）：玻璃卡（.regularMaterial + hairline + 顶高光 + 柔投影），mono 时间紫（accent），
    // 标题 15px/600，地点灰，底部头像栈（原型无左色条）。

    private var iosMiniBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(timeText)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Color.lj.accent)
            Text(event.title)
                .font(.system(size: 15, weight: .semibold, design: .default))
                .kerning(-0.225)
                .foregroundStyle(Color.lj.ink)
                .lineLimit(2)
            if !event.location.isEmpty {
                Text(event.location)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
                    .lineLimit(1)
            }
            if !(event.attendees ?? []).isEmpty {
                Spacer(minLength: 2)
                AvatarStack(people: event.attendees ?? [], max: 3)
            }
        }
        .frame(width: 200, alignment: .leading)
        .frame(minHeight: 90, alignment: .topLeading)
        .ljGlassPanel(radius: 16, padded: true)
    }

    // MARK: iOS Calendar 单日 list 大卡
    //
    // v1.3 R7（对原型重建）：玻璃卡 + 左 3px 色条（紫/灰）+ mono 时间区间紫（accent）+ 标题 16px/600 + 地点灰。

    private var iosFullBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(timeText) — \(endText)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Color.lj.accent)
            Text(event.title)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .kerning(-0.24)
                .foregroundStyle(Color.lj.ink)
            if !event.location.isEmpty {
                Text(event.location)
                    .font(.system(size: 12.5, weight: .regular, design: .default))
                    .foregroundStyle(Color.lj.inkSoft)
            }
            if !(event.attendees ?? []).isEmpty {
                AvatarStack(people: event.attendees ?? [], max: 4)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, LJSpacing.s18)
        .padding(.trailing, LJSpacing.s16)
        .padding(.vertical, 15)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.lj.border, lineWidth: 0.5)
        }
        .overlay { LJTopHighlight(radius: 16) }
        // 左 3px 全高色条（紫/灰），上下内缩 14pt（原型 top14 bottom14）。
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(iosAccent)
                .frame(width: 3)
                .padding(.vertical, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.lj.shadowCard, radius: 10, x: 0, y: 6)
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
