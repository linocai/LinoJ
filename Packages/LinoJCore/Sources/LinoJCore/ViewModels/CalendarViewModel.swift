// CalendarViewModel.swift
// Calendar 视图的 ViewModel —— 把 SwiftData 中所有 Event 按「未来 7 天」整理给 macOS 周视图
// 与 iOS 单日 list 使用。
//
// 周起点策略（对齐设计稿）：固定为「today 起算的滚动 7 天窗口」——`weekStart = startOfDay(today)`，
// 展示 today / today+1 / … / today+6。**不再回退到周一**（设计稿 Calendar 是 rolling next 7 days，
// 第一列 TODAY，nav 范围 "May 27 — Jun 2" = today..today+6）。goPrev/Next 整体平移 7 天，goToday
// 把窗口 reset 回 today 起点。
//
// 数据流照搬 MainViewModel 模式：
//   - `@Observable @MainActor` final class；
//   - init 拿 ModelContext + 可选的 `today`（默认 LinoJTime.today()：DEBUG = 2026-05-27 09:00；Release = 真实今天）；
//   - `tick` 用于驱动所有 computed property 在 View `.onChange` 时重新 fetch；
//   - 状态变更（goNext / goPrev / goToday / selectDay / confirmAttended）写入 stored prop
//     或 mutate Event，然后 refresh()。
//
// yesterday-missed 已在 P4 抽到 `YesterdayMissedService.computeMissed(now:)`。
// 这里通过可选注入：service 给了就委托；没给就 fallback 本地 fetch（保证既有测试不变）。

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class CalendarViewModel {

    // MARK: Stored

    /// SwiftData 上下文。View 通过 `@Environment(\.modelContext)` 拿到后注入。
    private let context: ModelContext

    /// 该 vm 视角下的「今天」时刻。DEBUG 默认 = LinoJTime.today()（2026-05-27 09:00），
    /// Release 默认 = `.now`。测试时可注入特定 Date。
    private let today: Date

    /// YesterdayMissedService 实例（可选）。P4 起由 App 注入；不传时 fallback 到本地 fetch。
    private let yesterdayMissedService: YesterdayMissedService?

    /// 当前展示的「7 天窗口」起点（默认 = today 的 00:00）。`goPrevWeek`/`goNextWeek`/`goToday` 改写它。
    public var weekStart: Date

    /// iOS 单日 list 当前选中的日期（startOfDay）。`selectDay(_)` 改写。
    /// 默认 = today 所在的 startOfDay（落在 `weekStart..<weekStart+7d` 之内）。
    public var selectedDay: Date

    /// Refresh tick —— 任意写入都让 Observation 把 computed property 标记为脏，下一次
    /// SwiftUI re-render 重新走 fetch。
    private var tick: Int = 0

    /// W2：Settings 的 `yesterdayMissedReminderEnabled` 注入值（View 灌入）。
    /// 为 false 时 `yesterdayMissed` getter 短路返回 `[]`，「From yesterday」box 不渲染。
    public var showYesterdayMissed: Bool = true

    // MARK: Init

    /// - Parameters:
    ///   - context: SwiftData 上下文。
    ///   - today: 可注入的「今天」时刻；测试用。默认值通过 `LinoJTime.today()` 计算
    ///            （DEBUG → 2026-05-27 09:00；Release → `.now`）。
    public init(
        context: ModelContext,
        today: Date = LinoJTime.today(),
        yesterdayMissedService: YesterdayMissedService? = nil
    ) {
        self.context = context
        self.today = today
        self.yesterdayMissedService = yesterdayMissedService
        // 窗口起点 = today 的 startOfDay（滚动「未来 7 天」，today 落在第一列）。
        self.weekStart = Self.startOfWeek(containing: today)
        self.selectedDay = Self.calendar.startOfDay(for: today)
    }

    // MARK: Refresh hook

    /// View 层在 `@Query` 数据变化时调用，让所有 computed property 在下一帧重新 fetch。
    public func refresh() {
        tick &+= 1
    }

    // MARK: - Derived

    /// 窗口 7 天的 startOfDay 数组（today, today+1, …, today+6；切窗口后整体平移）。
    public var weekDays: [Date] {
        _ = tick
        return (0..<7).compactMap {
            Self.calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    /// 本周每天 → 事件列表的 dictionary。**始终 7 个 key**（即使某天为空，也保留 `[]`），
    /// 与 plan 验收契约一致。
    public var eventsByDay: [Date: [Event]] {
        _ = tick
        let events = allEvents()
        var result: [Date: [Event]] = [:]
        for dayStart in weekDays {
            guard let nextDayStart = Self.calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                result[dayStart] = []
                continue
            }
            let dayEvents = events
                .filter { $0.start >= dayStart && $0.start < nextDayStart }
                .sorted { $0.start < $1.start }
            result[dayStart] = dayEvents
        }
        return result
    }

    /// 窗口内事件总数（macOS 顶栏「X events · next 7 days」副标用）。
    public var weekTotal: Int {
        _ = tick
        return eventsByDay.values.reduce(0) { $0 + $1.count }
    }

    /// 昨日已结束 + 未确认参加的事件，按 start 升序。
    /// 仅当 weekStart 包含 today 时 UI 才显示「From yesterday」box，但本属性本身始终可读。
    /// P4 起优先委托 YesterdayMissedService；service 未注入时 fallback 到本地计算。
    public var yesterdayMissed: [Event] {
        _ = tick
        // W2：Settings 关掉「yesterday missed」提醒时短路返回空（box 自然不渲染）。
        guard showYesterdayMissed else { return [] }
        if let service = yesterdayMissedService {
            return service.computeMissed(now: today)
        }
        let startOfToday = Self.calendar.startOfDay(for: today)
        guard let startOfYesterday = Self.calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return []
        }
        return allEvents()
            .filter {
                $0.end < startOfToday
                && $0.end >= startOfYesterday
                && $0.attendedConfirmed == false
            }
            .sorted { $0.start < $1.start }
    }

    /// 当前 weekStart 是否 = today 起算窗口（决定 iOS 是否渲染 yesterday-missed box）。
    public var isViewingTodayWeek: Bool {
        let todayWeekStart = Self.startOfWeek(containing: today)
        return Self.calendar.isDate(weekStart, inSameDayAs: todayWeekStart)
    }

    /// 「今天」的 startOfDay。macOS today-column 高亮 / iOS Today pill / now 线判定都用它。
    public var todayStart: Date {
        Self.calendar.startOfDay(for: today)
    }

    /// 「现在」的精确时刻（用于 now 线的小数小时位置）。
    public var now: Date { today }

    // MARK: - Mutations

    /// 上一周。
    public func goPrevWeek() {
        guard let prev = Self.calendar.date(byAdding: .day, value: -7, to: weekStart) else { return }
        weekStart = prev
        // 切周时不改 selectedDay 的「日期数字」语义，但需要让它落在新周内：取新周的同一星期几。
        selectedDay = clampedSelectedDay(in: prev)
        refresh()
    }

    /// 下一周。
    public func goNextWeek() {
        guard let next = Self.calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }
        weekStart = next
        selectedDay = clampedSelectedDay(in: next)
        refresh()
    }

    /// reset 到 today 起算的 7 天窗口，selectedDay 重置为 today。
    public func goToday() {
        weekStart = Self.startOfWeek(containing: today)
        selectedDay = Self.calendar.startOfDay(for: today)
        refresh()
    }

    /// iOS 7-day strip 点击某天。传入的 Date 会被 normalized 到 startOfDay。
    public func selectDay(_ day: Date) {
        selectedDay = Self.calendar.startOfDay(for: day)
        // 不改 weekStart —— UI 调用方应保证选中的 day 落在当前周内。
        refresh()
    }

    /// W3：Search 选中某个 event 后定位到它所在那天。与 `selectDay` 不同——
    /// 这里**同时移动 7 天窗口**让目标天落入窗口（`weekStart = startOfWeek(containing: day)`），
    /// 使任意日期（含未来/过去周）都能被定位、而不只是当前窗口内。selectedDay 设到目标天。
    public func focus(on day: Date) {
        let dayStart = Self.calendar.startOfDay(for: day)
        weekStart = Self.startOfWeek(containing: dayStart)
        selectedDay = dayStart
        refresh()
    }

    /// 把 yesterday-missed box 中的某条事件标记为「已参加」。
    /// W4：复用为事件卡的「标记已出席」。
    public func confirmAttended(_ event: Event) {
        event.attendedConfirmed = true
        try? context.save()
        refresh()
    }

    /// W4：「取消已出席」—— 把 `attendedConfirmed` 翻回 false（可逆），与 confirmAttended 对称。
    public func unconfirmAttended(_ event: Event) {
        event.attendedConfirmed = false
        try? context.save()
        refresh()
    }

    /// W4：删除事件。`context.delete` + save + refresh（与 confirmAttended 同 VM、同 save+refresh 模式）。
    public func deleteEvent(_ event: Event) {
        context.delete(event)
        try? context.save()
        refresh()
    }

    /// U7：拖拽改期写回。平移保持时长则传 newStart/newEnd（两者一起平移）；
    /// 下边缘拉伸只改 newEnd（newStart 传原 start）。写回 Event 的 start/end 后 save + refresh
    /// （与 confirmAttended/deleteEvent 同 VM、同 save+refresh 模式）。refresh 后 overlapLayout
    /// 自动重算，事件进入/离开重叠簇的列分配随之更新（U5 协同，无需特殊处理）。
    public func moveEvent(_ event: Event, newStart: Date, newEnd: Date) {
        event.start = newStart
        event.end = newEnd
        try? context.save()
        refresh()
    }

    // MARK: - U5 重叠列分配（共享纯函数）

    /// U5：该天事件的重叠列分配。返回 `eventID → (column 0-based, 同簇总列数)`。
    /// 不重叠的事件 `columnCount == 1, column == 0`。取 `eventsByDay[dayStart]`（已按 start 升序）
    /// 包一层调用纯函数核心；找不到该天返回空 map。
    public func overlapLayout(forDay dayStart: Date) -> [UUID: (column: Int, columnCount: Int)] {
        Self.computeOverlapLayout(events: eventsByDay[dayStart] ?? [])
    }

    /// U5：重叠列分配纯函数核心。**不读 `tick`、不 mutate、不依赖 SwiftData**——单测直接调。
    ///
    /// 算法：
    ///   1. 传递性重叠归簇：A、B 重叠定义为 `A.start < B.end && B.start < A.end`（区间相交，
    ///      端点相接不算）。把传递相连的重叠事件归为一个「簇」（cluster）。
    ///   2. 簇内贪心分配列：簇内事件按 start 排序，对每个事件分配「最左可用列」
    ///      （该列上一个事件已结束 `prevEnd <= cur.start` 即可复用该列）。
    ///   3. `columnCount` = 该簇用到的最大列数；**簇内所有事件 columnCount 一致**（同簇等分列宽）。
    public static func computeOverlapLayout(events: [Event]) -> [UUID: (column: Int, columnCount: Int)] {
        guard !events.isEmpty else { return [:] }

        // 按 start 升序排序（同 start 则按 end 升序，保证确定性）。
        let sorted = events.sorted {
            $0.start != $1.start ? $0.start < $1.start : $0.end < $1.end
        }

        var result: [UUID: (column: Int, columnCount: Int)] = [:]

        // 传递性归簇：顺序扫描，维护当前簇 + 当前簇内所有事件的最大 end。
        // 下一个事件的 start < 簇内最大 end → 与簇传递重叠（区间相交且端点不相接），并入；
        // 否则封闭当前簇、开新簇。
        var clusterStart = 0
        var clusterMaxEnd = sorted[0].end
        var i = 1
        while i <= sorted.count {
            let extendsCluster = i < sorted.count && sorted[i].start < clusterMaxEnd
            if extendsCluster {
                clusterMaxEnd = max(clusterMaxEnd, sorted[i].end)
                i += 1
            } else {
                // 封闭 [clusterStart, i) 这一簇，分配列。
                assignColumns(for: Array(sorted[clusterStart..<i]), into: &result)
                clusterStart = i
                if i < sorted.count { clusterMaxEnd = sorted[i].end }
                i += 1
            }
        }

        return result
    }

    /// 对单个簇（已按 start 升序）贪心分配「最左可用列」，并回写统一的 columnCount。
    private static func assignColumns(
        for cluster: [Event],
        into result: inout [UUID: (column: Int, columnCount: Int)]
    ) {
        // 每列记录该列「上一个事件的 end」；列复用条件 prevEnd <= cur.start。
        var columnEnds: [Date] = []
        var assigned: [(id: UUID, column: Int)] = []

        for event in cluster {
            // 找最左一个 end <= event.start 的列；找不到则新开一列。
            var placedColumn: Int? = nil
            for (col, end) in columnEnds.enumerated() where end <= event.start {
                placedColumn = col
                break
            }
            let column: Int
            if let col = placedColumn {
                columnEnds[col] = event.end
                column = col
            } else {
                columnEnds.append(event.end)
                column = columnEnds.count - 1
            }
            assigned.append((id: event.id, column: column))
        }

        let columnCount = columnEnds.count
        for entry in assigned {
            result[entry.id] = (column: entry.column, columnCount: columnCount)
        }
    }

    // MARK: - Internal helpers

    /// 拉全部 Event。failure 静默退回空数组。
    private func allEvents() -> [Event] {
        (try? context.fetch(FetchDescriptor<Event>())) ?? []
    }

    /// 切窗口时把 selectedDay 平移到新窗口内的同一「列偏移」。
    /// 例如旧 selectedDay 在窗口第 3 天，切下一周后映射到新窗口的第 3 天（平移 ±7）。
    /// 落不到（窗口跳变等极端情况）就退回新窗口起点。
    private func clampedSelectedDay(in newWeekStart: Date) -> Date {
        let cal = Self.calendar
        let oldOffset = cal.dateComponents([.day], from: weekStart, to: selectedDay).day ?? 0
        let clamped = min(max(oldOffset, 0), 6)
        return cal.date(byAdding: .day, value: clamped, to: newWeekStart) ?? newWeekStart
    }

    // MARK: - Static helpers (today 起算的滚动窗口)

    /// 本地化日历拷贝。Locale 跟系统走（确保 startOfDay 时区正确）。
    /// 注：窗口已改为 today 起算的滚动 7 天，不再依赖 `firstWeekday`；但保留 `firstWeekday = 2`
    /// 以维持 weekday 组件读取的一致性（不影响窗口计算，仅遗留无害设置）。
    public static let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday（窗口不依赖此值，保留以求一致）
        return cal
    }()

    /// 给定任意一个时刻，返回它的「滚动 7 天窗口」起点 —— 即该日的 startOfDay。
    /// （设计稿 Calendar 是 rolling next 7 days，窗口第一列就是 today；不回退到周一。）
    public static func startOfWeek(containing date: Date) -> Date {
        Self.calendar.startOfDay(for: date)
    }
}
