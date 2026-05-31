// LinoJWidgetBundle.swift
// U9.3（v1.1）：LinoJ widget extension 的 `@main` 入口（两端共享同一份源码）。
//
// 一个 `Widget` 声明，支持 family：
//   systemSmall / systemMedium（主屏 / 桌面）+ accessoryRectangular / accessoryInline（锁屏）。
// 数据来自 `LinoJTimelineProvider`（只读 App Group 共享 SwiftData store）。

import WidgetKit
import SwiftUI
import LinoJCore

@main
struct LinoJWidgetBundle: WidgetBundle {
    var body: some Widget {
        LinoJWidget()
    }
}

struct LinoJWidget: Widget {
    let kind = "LinoJWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LinoJTimelineProvider()) { entry in
            LinoJWidgetEntryView(entry: entry)
                // iOS 17+/macOS 14+：widget 需用 containerBackground 声明背景，
                // 用 LinoJ 的 calm 背景色（bg），随系统深浅自动切换。
                .containerBackground(Color.lj.bg, for: .widget)
        }
        .configurationDisplayName(Text(LJStrings.widgetDisplayName))
        .description(Text(LJStrings.widgetDescription))
        .supportedFamilies(Self.supportedFamilies)
        // calm：禁用系统给中大尺寸 widget 的内容裕度自适应缩放，保持版式稳定。
        .contentMarginsDisabled()
    }

    /// 支持的 family：两端都有 system small/medium；锁屏 accessory 仅 iOS（macOS 不支持）。
    private static var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        return [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline]
        #else
        return [.systemSmall, .systemMedium]
        #endif
    }
}
