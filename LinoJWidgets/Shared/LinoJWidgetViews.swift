// LinoJWidgetViews.swift
// U9.3（v1.1）：LinoJ widget 的 SwiftUI 展示视图（各 widget family 一个布局）。
//
// 视觉（calm 调性，复用 LinoJCore 的 Color.lj.* / Typography）：
//   - systemSmall：下一个事件（mono 时间 + 标题）；无事件则退化显示 open 计数。
//   - systemMedium：今日接下来 1-3 个事件 look-ahead（mono 时间 + 标题）+ 底部 open 计数。
//   - accessoryRectangular（锁屏）：下一个事件（时间 + 标题，单/双行）。
//   - accessoryInline（锁屏）：open 计数一行。
//
// 强调色纪律（v1.3 起紫蓝、无橙）：`Color.lj.blue`（= accent #6E63E6，R0 已换为紫蓝）只给 urgent ——
// 这里只在「urgent > 0」时给 urgent 计数着紫蓝强调色，事件本身用中性 ink 色（事件无紧急概念）。
// Widget 不吃 .glassEffect()，保持扁平呈现，仅配色跟随 token 换值（决策 D-Widget）。

import WidgetKit
import SwiftUI
import LinoJCore

// MARK: - 时间格式（mono、calm）

private extension Date {
    /// 简洁本地化时间（如 `9:30` / `09:30` 视 locale），给 mono 字体展示。
    var ljShortTime: String {
        formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - 计数纯文本（accessory 单行用，避免 Text 拼接）

private extension WidgetTodoCounts {
    /// 「X open · Y urgent」单行字符串（锁屏 accessory 用，无法按段着色，整段一个 Text）。
    /// 本地化词用 `String(localized:)` 即时解析。
    var inlineText: String {
        let openWord = String(localized: LJStrings.statOpen)
        if urgent > 0 {
            let urgentWord = String(localized: LJStrings.statUrgent)
            return "\(open) \(openWord) · \(urgent) \(urgentWord)"
        }
        return "\(open) \(openWord)"
    }

    /// 只 open 的单行字符串（accessoryRectangular 无事件兜底用）。
    var openText: String {
        "\(open) \(String(localized: LJStrings.statOpen))"
    }
}

// MARK: - 计数行（X open · Y urgent）

/// 「X open · Y urgent」计数文本。urgent > 0 时 urgent 数着紫蓝强调色（仅 urgent 给强调色）。
///
/// iOS 26 弃用了 `Text + Text` 拼接，故每段用独立 `Text` 摆进 HStack（保留按段着色：
/// 数字 / 「open」中性，urgent 段着紫蓝强调）。本地化词用 `String(localized:)` 渲染。
struct LinoJCountsLabel: View {
    let counts: WidgetTodoCounts
    /// 紧凑模式（small / accessory）字号略小。
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Text("\(counts.open)")
                .monospacedDigit()
                .foregroundStyle(Color.lj.ink)
            Text(LJStrings.statOpen)
                .foregroundStyle(Color.lj.inkSoft)
            if counts.urgent > 0 {
                Text("·")
                    .foregroundStyle(Color.lj.inkMute)
                Text("\(counts.urgent)")
                    .monospacedDigit()
                    .foregroundStyle(Color.lj.blue)
                Text(LJStrings.statUrgent)
                    .foregroundStyle(Color.lj.blue)
            }
        }
        .font(compact ? .lj.caption : .lj.body)
        .lineLimit(1)
    }
}

// MARK: - 单事件行（mono 时间 + 标题）

struct LinoJEventRow: View {
    let event: WidgetEventItem
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(event.start.ljShortTime)
                .font(.lj.mono.monospacedDigit())
                .foregroundStyle(Color.lj.inkSoft)
                .layoutPriority(1)
            Text(event.title)
                .font(.lj.body)
                .foregroundStyle(Color.lj.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - systemSmall

struct LinoJSmallView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = snapshot.upcomingEvents.first {
                // 有事件：显示下一个事件（时间在上、标题在下，calm 竖排）。
                Text(LJStrings.upcomingToday)
                    .font(.lj.caption)
                    .foregroundStyle(Color.lj.inkMute)
                    .lineLimit(1)
                Text(next.start.ljShortTime)
                    .font(.lj.mono.monospacedDigit())
                    .foregroundStyle(Color.lj.inkSoft)
                Text(next.title)
                    .font(.lj.cardTitle)
                    .foregroundStyle(Color.lj.ink)
                    .lineLimit(3)
                Spacer(minLength: 0)
                LinoJCountsLabel(counts: snapshot.counts, compact: true)
            } else {
                // 无事件：退化为计数 + 「今日无事」。
                Text(LJStrings.nothingOnBooks)
                    .font(.lj.caption)
                    .foregroundStyle(Color.lj.inkMute)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text("\(snapshot.counts.open)")
                    .font(.system(size: 40, weight: .semibold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(Color.lj.ink)
                LinoJCountsLabel(counts: snapshot.counts, compact: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - systemMedium

struct LinoJMediumView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LJStrings.upcomingToday)
                .font(.lj.caption)
                .foregroundStyle(Color.lj.inkMute)
                .lineLimit(1)

            if snapshot.upcomingEvents.isEmpty {
                Spacer(minLength: 0)
                Text(LJStrings.nothingOnBooks)
                    .font(.lj.body)
                    .foregroundStyle(Color.lj.inkSoft)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(snapshot.upcomingEvents) { event in
                        LinoJEventRow(event: event)
                    }
                }
                Spacer(minLength: 0)
            }

            Divider().overlay(Color.lj.border)
            LinoJCountsLabel(counts: snapshot.counts)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 锁屏 accessory（仅 iOS —— macOS 无锁屏 widget family）

#if os(iOS)
/// accessoryRectangular（锁屏）：下一个事件（时间 + 标题）；无事件兜底 open 计数。
struct LinoJAccessoryRectangularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let next = snapshot.upcomingEvents.first {
                Text(next.start.ljShortTime)
                    .font(.system(.caption, design: .monospaced))
                    .widgetAccentable()
                Text(next.title)
                    .font(.headline)
                    .lineLimit(2)
            } else {
                Text(LJStrings.nothingOnBooks)
                    .font(.headline)
                    .lineLimit(1)
                Text(snapshot.counts.openText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// accessoryInline（锁屏单行）：open / urgent 计数。
struct LinoJAccessoryInlineView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        // accessoryInline 是单行系统样式，整段一个 Text（无法分段着色）。
        Text(snapshot.counts.inlineText)
    }
}
#endif

// MARK: - family 分发

struct LinoJWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LinoJEntry

    var body: some View {
        let snapshot = entry.snapshot
        switch family {
        case .systemSmall:
            LinoJSmallView(snapshot: snapshot)
        case .systemMedium:
            LinoJMediumView(snapshot: snapshot)
        #if os(iOS)
        case .accessoryRectangular:
            LinoJAccessoryRectangularView(snapshot: snapshot)
        case .accessoryInline:
            LinoJAccessoryInlineView(snapshot: snapshot)
        #endif
        default:
            // 其它未声明 family（systemLarge / macOS 上不支持的锁屏 family 等）退化为 medium，保证不空白。
            LinoJMediumView(snapshot: snapshot)
        }
    }
}
