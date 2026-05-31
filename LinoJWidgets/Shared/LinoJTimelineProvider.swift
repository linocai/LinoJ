// LinoJTimelineProvider.swift
// U9.3（v1.1）：LinoJ widget 的 TimelineProvider。
//
// 职责：在 widget extension 进程内**只读**打开 App Group 共享的 SwiftData store
// （`LinoJStore.makeWidgetContainer()`，`cloudKitDatabase: .none` + `allowsSave: false`），
// fetch Event/Todo，投影成 `WidgetSnapshot`（`Sendable` 值类型），生成 timeline。
//
// 刷新策略（plan U9.3）：`.atEnd` + 每整点 / 下一个事件起点刷新。
//   - 我们生成「现在」一个 entry，policy 设为 `.after(nextReloadDate)`：取「下一个整点」与
//     「下一个事件起点」中较早者，让 widget 在事件开始那刻（事件从 look-ahead 掉出）或整点
//     （计数/日期翻篇）及时刷新；那个时点到了 WidgetKit 会回调 provider 重新出 timeline。
//   - 容器打开失败（widget entitlement 没配好 / containerURL nil）→ 兜底空快照，不崩 widget。

import WidgetKit
import SwiftUI
import SwiftData
import LinoJCore

/// 单个 timeline entry：携带一个 `Sendable` 的 `WidgetSnapshot`。
struct LinoJEntry: TimelineEntry {
    /// WidgetKit 要求的 entry 时刻。
    var date: Date
    /// 该 entry 的全部展示数据（事件 look-ahead + 计数）。
    var snapshot: WidgetSnapshot
}

struct LinoJTimelineProvider: TimelineProvider {

    /// 占位（widget gallery / 首次加载骨架）：空数据，避免读容器。
    func placeholder(in context: Context) -> LinoJEntry {
        LinoJEntry(date: .now, snapshot: .placeholder())
    }

    /// 快照（widget gallery 预览 / 系统抓一帧）：读真实数据；isPreview 时若读不到也给空。
    func getSnapshot(in context: Context, completion: @escaping (LinoJEntry) -> Void) {
        let entry = Self.loadEntry()
        completion(entry)
    }

    /// 生成 timeline：当前一个 entry + `.after(nextReloadDate)` 刷新策略。
    func getTimeline(in context: Context, completion: @escaping (Timeline<LinoJEntry>) -> Void) {
        let entry = Self.loadEntry()
        let starts = entry.snapshot.upcomingEvents.map(\.start)
        let reloadDate = WidgetData.nextReloadDate(after: entry.date, upcomingEventStarts: starts)
        // plan：`.atEnd` 语义 —— 给出到 reloadDate 为止的单 entry timeline，到点后系统回调重出。
        let timeline = Timeline(entries: [entry], policy: .after(reloadDate))
        completion(timeline)
    }

    /// 打开只读容器 + 读快照。任何失败兜底空快照。
    /// `MainActor.assumeIsolated`：`makeWidgetContainer` / `snapshot(from:)` 都是 `@MainActor`；
    /// WidgetKit 的 timeline 回调在主线程上执行，可安全 assumeIsolated。
    private static func loadEntry() -> LinoJEntry {
        let now = Date.now
        return MainActor.assumeIsolated {
            do {
                let container = try LinoJStore.makeWidgetContainer()
                let snapshot = WidgetData.snapshot(from: container.mainContext, now: now)
                return LinoJEntry(date: now, snapshot: snapshot)
            } catch {
                // 容器打开失败（App Group 取不到 / store 缺失等）→ 空快照，不崩。
                return LinoJEntry(date: now, snapshot: .placeholder(date: now))
            }
        }
    }
}
