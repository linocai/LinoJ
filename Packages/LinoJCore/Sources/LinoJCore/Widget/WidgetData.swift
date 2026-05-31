// WidgetData.swift
// U9.3（v1.1）：Widget timeline 的数据层。
//
// 设计取舍：
//   - Widget extension 跑在**独立进程**，只读 App Group 共享容器内的 SwiftData store。
//     timeline provider 用 `LinoJStore.makeWidgetContainer()` 打开一个**最小只读配置**容器
//     （`cloudKitDatabase: .none`、不触发 CloudKit mirroring），fetch `Event`/`Todo`，**绝不写**。
//   - timeline 的「数据计算」抽成**纯函数**（输入 `[Event]`/`[Todo]` → 输出 `Sendable` 值类型），
//     与 SwiftData / 进程 / 容器解耦，可在 `swift test` headless 下完整覆盖（真实 group 容器
//     headless 取不到，但搬运/计算逻辑能测）。
//   - 计数语义**复用 Main**：`openCount` = 未完成 todo 数；`urgentCount` = 未完成且 urgent 数
//     （与 `MainViewModel.openCount` / `urgentCount` 一致，见该文件）。
//   - 「今日接下来 N 个事件」语义：今天（同一日历日）内、`start >= now`（还没开始）的事件，
//     按 start 升序取前 N 个。calm 调性：mono 时间 + 标题，蓝色只留给 urgent（这里事件无紧急色，
//     widget 视图侧用中性色渲染事件，蓝色只给 urgent todo 计数）。
//
// 为什么用值类型快照而非直接传 `@Model`：
//   `Event`/`Todo` 是 `@Model` 引用类型、非 `Sendable`，不能跨 actor / 进入 TimelineEntry。
//   provider 在 `@MainActor` 上 fetch 后立即转成 `Sendable` 值快照塞进 entry。

import Foundation
import SwiftData

// MARK: - Sendable 值类型快照

/// Widget 展示用的单个事件快照（从 `Event` 投影出的 `Sendable` 值类型）。
public struct WidgetEventItem: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let location: String
    public let start: Date
    public let end: Date

    public init(id: UUID, title: String, location: String, start: Date, end: Date) {
        self.id = id
        self.title = title
        self.location = location
        self.start = start
        self.end = end
    }
}

/// Widget 展示用的 todo 计数快照（复用 Main 的「open / urgent」语义）。
public struct WidgetTodoCounts: Equatable, Sendable {
    /// 未完成 todo 总数（`done == false`）。
    public let open: Int
    /// 未完成且 urgent 的 todo 数。
    public let urgent: Int

    public init(open: Int, urgent: Int) {
        self.open = open
        self.urgent = urgent
    }

    public static let zero = WidgetTodoCounts(open: 0, urgent: 0)
}

/// 一个 timeline entry 的完整数据载荷（`Sendable` 值类型，可安全塞进 WidgetKit entry）。
public struct WidgetSnapshot: Equatable, Sendable {
    /// 该 entry 代表的时刻（timeline date）。
    public let date: Date
    /// 今日接下来的事件（已按 start 升序、已截到上限）。
    public let upcomingEvents: [WidgetEventItem]
    /// open / urgent todo 计数。
    public let counts: WidgetTodoCounts

    public init(date: Date, upcomingEvents: [WidgetEventItem], counts: WidgetTodoCounts) {
        self.date = date
        self.upcomingEvents = upcomingEvents
        self.counts = counts
    }

    /// 容器打开失败 / 无数据时的兜底（空事件 + 0 计数），保证 widget 不崩。
    public static func placeholder(date: Date = .now) -> WidgetSnapshot {
        WidgetSnapshot(date: date, upcomingEvents: [], counts: .zero)
    }
}

// MARK: - 纯计算函数（可测，与 SwiftData / 进程解耦）

public enum WidgetData {

    /// widget medium 尺寸今日 look-ahead 的事件上限（plan：今天接下来 1-3 个事件）。
    public static let maxUpcomingEvents = 3

    /// 从 `[Event]`（已投影成 `WidgetEventItem` 值类型）取「今日接下来的事件」：
    ///   - 与 `now` 同一日历日；
    ///   - `start >= now`（还没开始 / 正要开始）—— calm look-ahead 只看「接下来」，不回看已过去的；
    ///   - 按 start 升序；
    ///   - 截到 `limit` 个（默认 `maxUpcomingEvents`）。
    ///
    /// 纯函数：调用方先 fetch + 投影，再喂进来；不碰 SwiftData，便于单测。
    public static func upcomingEventsToday(
        from events: [WidgetEventItem],
        now: Date,
        calendar: Calendar = .current,
        limit: Int = maxUpcomingEvents
    ) -> [WidgetEventItem] {
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return []
        }
        return events
            .filter { $0.start >= now && $0.start >= startOfToday && $0.start < startOfTomorrow }
            .sorted { $0.start < $1.start }
            .prefix(limit)
            .map { $0 }
    }

    /// 复用 Main 的计数语义：
    ///   - `open`  = 未完成 todo 数（`done == false`）；
    ///   - `urgent` = 未完成且 `urgency == .urgent` 的数。
    /// 输入 `(done, urgentRaw)` 元组对，避免依赖 `@Model`，便于单测。
    public static func counts(
        fromTodos todos: [(done: Bool, urgency: Urgency)]
    ) -> WidgetTodoCounts {
        let open = todos.filter { !$0.done }
        let urgent = open.filter { $0.urgency == .urgent }.count
        return WidgetTodoCounts(open: open.count, urgent: urgent)
    }

    // MARK: - timeline 刷新时点

    /// 计算下一个 timeline 刷新时点：取「下一个整点」与「下一个事件起点」中**较早**者。
    ///
    /// 用于 widget `.atEnd` reload 之外的精确刷新：让 widget 在事件开始的那一刻（事件从
    /// look-ahead 列表里掉出去）或整点（计数 / 日期翻篇）及时更新。
    /// 没有未来事件时退化为「下一个整点」。
    public static func nextReloadDate(
        after now: Date,
        upcomingEventStarts: [Date],
        calendar: Calendar = .current
    ) -> Date {
        let nextHour = nextHourBoundary(after: now, calendar: calendar)
        // 取严格晚于 now 的最早事件起点。
        let nextEventStart = upcomingEventStarts
            .filter { $0 > now }
            .min()
        if let nextEventStart, nextEventStart < nextHour {
            return nextEventStart
        }
        return nextHour
    }

    /// 严格晚于 `now` 的下一个整点（hh:00:00）。
    public static func nextHourBoundary(after now: Date, calendar: Calendar = .current) -> Date {
        // 截到当前整点，再 +1 小时，保证严格晚于 now（即便 now 恰好是整点也前进一格）。
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        let thisHour = calendar.date(from: comps) ?? now
        return calendar.date(byAdding: .hour, value: 1, to: thisHour) ?? now.addingTimeInterval(3600)
    }

    // MARK: - SwiftData 读取（widget timeline provider 调用）

    /// 从一个**只读** `ModelContext`（来自 `LinoJStore.makeWidgetContainer()`）fetch 并投影出
    /// 一个 `WidgetSnapshot`。**只读**：只 `fetch`，绝不 `insert`/`delete`/`save`。
    ///
    /// 任一 fetch 失败都退化为「该项为空」（事件空 / 计数 0），不抛错——widget 宁可显示空也不崩。
    /// `@MainActor`：ModelContext 非 Sendable，统一在主 actor 上读，读完产出的是 `Sendable` 快照。
    @MainActor
    public static func snapshot(from context: ModelContext, now: Date = .now) -> WidgetSnapshot {
        // 事件：投影成值类型 → 取今日接下来 N 个。
        let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let projected = allEvents.map {
            WidgetEventItem(id: $0.id, title: $0.title, location: $0.location, start: $0.start, end: $0.end)
        }
        let upcoming = upcomingEventsToday(from: projected, now: now)

        // 计数：投影成 (done, urgency) 元组 → 复用 Main 计数语义。
        let allTodos = (try? context.fetch(FetchDescriptor<Todo>())) ?? []
        let todoTuples = allTodos.map { (done: $0.done, urgency: $0.urgency) }
        let counts = self.counts(fromTodos: todoTuples)

        return WidgetSnapshot(date: now, upcomingEvents: upcoming, counts: counts)
    }
}
