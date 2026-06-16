// CompanyViewModel.swift
// Company 视图的 ViewModel —— 过滤 scope == .company 的 Todo + 提供 Project 列表 + scope filter。
//
// 数据流照搬 MainViewModel / PersonalViewModel。
//
// ScopeFilter 的 `project` case 持有 `Project.ID`（即 UUID），而非 `Project` 引用 ——
// `@Model` 类型不 Sendable，把它装进 enum 会破坏 ScopeFilter 的 Hashable 派生 / Sendable 推导。
// View 层在显示 chip label 时用 id 反查 vm.projects。

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
public final class CompanyViewModel {

    /// Company 标签页内顶部 chip 行的过滤模式。
    public enum ScopeFilter: Hashable, Sendable {
        /// 全部 work todos。
        case allWork
        /// 没有归属 project 的 work todos（即「standalone」）。
        case standalone
        /// 归属指定 project 的 work todos。`Project.ID` 即 UUID，避免持有 `@Model` 引用。
        case project(UUID)
    }

    // MARK: Stored

    private let context: ModelContext

    /// Refresh tick —— 任意写入都让 Observation 把所有 computed property 标记为脏。
    private var tick: Int = 0

    /// 当前 chip 过滤模式。默认 `.allWork`。
    public var filter: ScopeFilter = .allWork

    /// W2：Settings 的 `showCompletedInCounts` 注入值。为 true 时 `todosCount` 改为
    /// 「全部 company todo（含 done）」计数；false 维持「仅未完成」。注入式（VM 不读 UserDefaults）。
    public var includeCompletedInCounts: Bool = false

    /// v1.2 P5：「近 30 天」分层的「现在」锚点。默认 `LinoJTime.now()`；测试注入固定时刻。
    private let now: Date

    // MARK: Init

    public init(context: ModelContext, now: Date = LinoJTime.now()) {
        self.context = context
        self.now = now
    }

    // MARK: Refresh

    public func refresh() {
        tick &+= 1
    }

    // MARK: - Derived

    /// 全部 company scope 的 todo（fetch 一次，分支共用）。
    private func workTodos() -> [Todo] {
        let all = (try? context.fetch(FetchDescriptor<Todo>())) ?? []
        return all.filter { $0.scope == .company }
    }

    /// 应用 `filter` 后的 work todos。
    private func filteredWorkTodos() -> [Todo] {
        let all = workTodos()
        switch filter {
        case .allWork:
            return all
        case .standalone:
            return all.filter { $0.project == nil }
        case .project(let projectID):
            return all.filter { $0.project?.id == projectID }
        }
    }

    /// 过滤后 + open + urgent。
    public var urgent: [Todo] {
        _ = tick
        return filteredWorkTodos()
            .filter { !$0.done && $0.urgency == .urgent }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 过滤后 + open + normal。
    public var normal: [Todo] {
        _ = tick
        return filteredWorkTodos()
            .filter { !$0.done && $0.urgency == .normal }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// v1.2 P5：过滤后 + done，按 createdAt 升序（CompletedBox 数据源）。
    public var completed: [Todo] {
        _ = tick
        return filteredWorkTodos()
            .filter { $0.done }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// v1.2 P5：近 30 天完成（或 `completedAt == nil` 存量旧 done）的 company todos。
    public var completedRecent: [Todo] {
        _ = tick
        return completed.filter { PersonalViewModel.isRecent($0, now: now) }
    }

    /// v1.2 P5：超过 30 天完成的 company todos（archive，二级折叠）。
    public var completedArchive: [Todo] {
        _ = tick
        return completed.filter { !PersonalViewModel.isRecent($0, now: now) }
    }

    /// 统计区显示的 todos count —— 全部 company 的 open todos，不被 chip filter 影响。
    /// 这与设计稿一致（"X todos · Y projects" 是站在 Company 整体维度）。
    /// W2：`includeCompletedInCounts == true` 时改为「全部 company todo（含 done）」计数。
    public var todosCount: Int {
        _ = tick
        if includeCompletedInCounts {
            return workTodos().count
        }
        return workTodos().filter { !$0.done }.count
    }

    /// Projects 数量（与 chip filter 无关）。
    public var projectsCount: Int {
        _ = tick
        return projects.count
    }

    /// 全部 project，按 createdAt 升序。
    public var projects: [Project] {
        _ = tick
        return (try? context.fetch(FetchDescriptor<Project>()))?
            .sorted { $0.createdAt < $1.createdAt } ?? []
    }

    // MARK: - Mutations

    /// 切换 chip 过滤模式。
    public func setFilter(_ filter: ScopeFilter) {
        self.filter = filter
        refresh()
    }

    /// 切换 todo 的 done 状态并持久化。
    /// P6：iOS 真机触发 light haptic。
    public func toggleDone(_ todo: Todo) {
        todo.done.toggle()
        // v1.2 P5：维护 completedAt —— 置完成时写 now（注入锚点），取消完成时清 nil。
        todo.completedAt = todo.done ? now : nil
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }
}
