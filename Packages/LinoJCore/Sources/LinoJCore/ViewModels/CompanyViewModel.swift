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

    // MARK: Init

    public init(context: ModelContext) {
        self.context = context
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

    /// 统计区显示的 todos count —— 全部 company 的 open todos，不被 chip filter 影响。
    /// 这与设计稿一致（"X todos · Y projects" 是站在 Company 整体维度）。
    public var todosCount: Int {
        _ = tick
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
        try? context.save()
        LinoJHaptics.lightTap()
        refresh()
    }
}
