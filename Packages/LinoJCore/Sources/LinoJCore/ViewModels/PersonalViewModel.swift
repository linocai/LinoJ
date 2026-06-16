// PersonalViewModel.swift
// Personal 视图的 ViewModel —— 仅过滤 scope == .personal 的 Todo。
//
// 数据流模式照搬 MainViewModel：`@Observable @MainActor`、init 拿 ModelContext、
// computed property 用 fetch + 过滤；refresh(tick:) 触发重新求值。
//
// 输出三类：
//   - urgent：scope == .personal && !done && urgency == .urgent
//   - normal：scope == .personal && !done && urgency == .normal
//   - completed：scope == .personal && done
// 计数：
//   - openCount = urgent.count + normal.count
//   - doneCount = completed.count

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class PersonalViewModel {

    // MARK: Stored

    private let context: ModelContext

    /// Refresh tick —— 任意写入都让 Observation 把所有 computed property 标记为脏。
    private var tick: Int = 0

    /// W2：Settings 的 `showCompletedInCounts` 注入值。为 true 时 `openCount` 改为
    /// 「全部 personal todo（含 done）」计数；false 维持「仅未完成」。注入式（VM 不读 UserDefaults）。
    public var includeCompletedInCounts: Bool = false

    /// v1.2 P5：「近 30 天」分层的「现在」锚点。默认 `LinoJTime.now()`（生产 = 真实现在）；
    /// 测试注入固定时刻让 recent/archive 边界确定性。
    private let now: Date

    // MARK: Init

    public init(context: ModelContext, now: Date = LinoJTime.now()) {
        self.context = context
        self.now = now
    }

    // MARK: Refresh

    /// View 层在 `@Query` 数据变化时调用，让 computed property 在下一帧重新 fetch。
    public func refresh() {
        tick &+= 1
    }

    // MARK: - Derived

    /// 全部 personal scope 的 todo（fetch 一次，三个分支共用）。
    private func personalTodos() -> [Todo] {
        // SwiftData `#Predicate` 暂不支持自动比较 raw enum；改为读所有 Todo 后 in-memory 过滤。
        // 数据量 v0.9 ≤ 100 条，没性能问题。
        let all = (try? context.fetch(FetchDescriptor<Todo>())) ?? []
        return all.filter { $0.scope == .personal }
    }

    /// open + urgent，按 createdAt 升序。
    public var urgent: [Todo] {
        _ = tick
        return personalTodos()
            .filter { !$0.done && $0.urgency == .urgent }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// open + normal，按 createdAt 升序。
    public var normal: [Todo] {
        _ = tick
        return personalTodos()
            .filter { !$0.done && $0.urgency == .normal }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 已完成的 personal todos，按 createdAt 升序。
    public var completed: [Todo] {
        _ = tick
        return personalTodos()
            .filter { $0.done }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// v1.2 P5：近 30 天完成（或 `completedAt == nil` 的存量旧 done 数据）的 personal todos。
    /// CompletedBox 默认展开显示这一段。按 createdAt 升序。
    public var completedRecent: [Todo] {
        _ = tick
        return completed.filter { Self.isRecent($0, now: now) }
    }

    /// v1.2 P5：超过 30 天完成的 personal todos（CompletedBox 二级 archive，点开才显示）。按 createdAt 升序。
    public var completedArchive: [Todo] {
        _ = tick
        return completed.filter { !Self.isRecent($0, now: now) }
    }

    /// v1.2 P5：「近 30 天」判定（纯函数）。`completedAt == nil`（存量旧 done 数据）归 recent，不丢失。
    static func isRecent(_ todo: Todo, now: Date) -> Bool {
        guard let completedAt = todo.completedAt else { return true }
        return completedAt >= now.addingTimeInterval(-30 * 24 * 60 * 60)
    }

    /// open todos 数量（urgent + normal）。
    /// W2：`includeCompletedInCounts == true` 时改为「全部 personal todo（含 done）」计数。
    public var openCount: Int {
        _ = tick
        if includeCompletedInCounts {
            return personalTodos().count
        }
        return personalTodos().filter { !$0.done }.count
    }

    /// 已完成数量。
    public var doneCount: Int {
        _ = tick
        return personalTodos().filter { $0.done }.count
    }

    // MARK: - Mutations

    /// 切换 todo 的 done 状态并持久化。
    /// P6：iOS 真机触发 light haptic（macOS / 模拟器 no-op）。
    public func toggleDone(_ todo: Todo) {
        todo.done.toggle()
        // v1.2 P5：维护 completedAt —— 置完成时写 now（注入锚点），取消完成时清 nil。
        todo.completedAt = todo.done ? now : nil
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }

    /// 切换 todo 的 urgency（urgent ↔ normal）并持久化。
    /// P6：iOS 真机触发 light haptic。
    public func toggleUrgency(_ todo: Todo) {
        todo.urgency = (todo.urgency == .urgent) ? .normal : .urgent
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }

    /// 删除 todo。失败时静默吞掉（UI 会自动重新 fetch）。
    public func delete(_ todo: Todo) {
        context.delete(todo)
        try? context.save()
        refresh()
    }
}
