// SearchViewModelTests.swift
// Plan P3.7 验收测试。
//
// 四条 + 1 sanity 覆盖 plan 的「关键接口契约」与「验收标准」：
//  1. 空 query 时 grouped 含 Quick actions group（至少 1 个 newTodo）。
//  2. query "side" 时 Todos group 含 w4（"Finalize macOS sidebar spec"）。
//  3. scope=.events 后 Todos group 消失。
//  4. elapsedMs >= 0（performSearch 后计时字段已写入）。
//  5. sanity: openFirst() 不崩 + scope chip 切换会改变 grouped。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("SearchViewModel — query / scope / open")
@MainActor
struct SearchViewModelTests {

    /// 用 inMemory container + seed 一遍真实 fixture，让 search 有 16 条 todo / 18 条 event / 3 个 project。
    /// 不污染开发机持久存储。
    private func makeSeededContextAndRouter() throws -> (ModelContext, TabRouter) {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        #if DEBUG
        try SeedData.seedIfEmpty(context)
        #endif
        let router = TabRouter()
        return (context, router)
    }

    // MARK: 1. 空 query 显示 Quick actions

    @Test("empty query: grouped contains Quick actions group with newTodo")
    func emptyQueryShowsQuickActions() throws {
        let (context, router) = try makeSeededContextAndRouter()
        let vm = SearchViewModel(context: context, router: router)

        // 初始 query == ""，grouped 应已被 init 中 performSearch 填好。
        #expect(vm.grouped.isEmpty == false)

        // 找 Quick actions group。
        let quickGroup = vm.grouped.first { $0.group == "Quick actions" }
        #expect(quickGroup != nil)

        // 含 newTodo quick action（plan 验收：至少 1 个）。
        let hasNewTodo = quickGroup?.items.contains { item in
            if case .quickAction(.newTodo) = item { return true }
            return false
        }
        #expect(hasNewTodo == true)
    }

    // MARK: 2. query "side" 命中 w4 sidebar todo

    @Test(#"query "side": Todos group contains w4 "Finalize macOS sidebar spec""#)
    func querySideMatchesSidebarTodo() throws {
        let (context, router) = try makeSeededContextAndRouter()
        let vm = SearchViewModel(context: context, router: router)

        // 直接同步触发：把 query 设上后立即手动调 performSearch，
        // 避免 debounce 100ms 在测试里等异步。
        vm.query = "side"
        vm.performSearch()

        // Todos group 应出现。
        let todosGroup = vm.grouped.first { $0.group == "Todos" }
        #expect(todosGroup != nil)

        // 该 group 应含一条 todo，display.title 含 "sidebar"。
        let titles: [String] = (todosGroup?.items ?? []).compactMap { item in
            if case .todo = item {
                return vm.display(for: item).title
            }
            return nil
        }
        #expect(titles.contains { $0.lowercased().contains("sidebar") })
    }

    // MARK: 3. scope=.events 后 Todos group 消失

    @Test("scope=.events filters out Todos group")
    func eventsScopeHidesTodos() throws {
        let (context, router) = try makeSeededContextAndRouter()
        let vm = SearchViewModel(context: context, router: router)

        vm.query = "side"
        vm.performSearch()

        // .all 下应能看到 Todos。
        #expect(vm.grouped.contains { $0.group == "Todos" })

        // 切到 .events —— setter 自动 performSearch。
        vm.scope = .events

        // Todos group 应消失。
        #expect(vm.grouped.contains { $0.group == "Todos" } == false)
    }

    // MARK: 4. elapsedMs >= 0

    @Test("elapsedMs is non-negative after performSearch")
    func elapsedMsIsRecorded() throws {
        let (context, router) = try makeSeededContextAndRouter()
        let vm = SearchViewModel(context: context, router: router)

        vm.query = "review"
        vm.performSearch()

        // performSearch 必然把 elapsedMs 设到非负值。
        #expect(vm.elapsedMs >= 0)
    }

    // MARK: 5. openFirst() sanity + scope chip 切换响应

    @Test("openFirst() does not crash and triggers router changes")
    func openFirstWorks() throws {
        let (context, router) = try makeSeededContextAndRouter()
        let vm = SearchViewModel(context: context, router: router)

        // 空 query 下 first item 是 Quick action newTodo —— openFirst 会翻 showQuickAdd flag。
        #expect(router.showQuickAdd == false)
        vm.openFirst()
        #expect(router.showQuickAdd == true)
        #expect(router.quickAddDefaultKind == .todo)

        // 重置后试 query=review 第一条结果（应为 todo）。
        router.showQuickAdd = false
        router.showSearch = true
        vm.query = "review"
        vm.performSearch()

        if let first = vm.flatItems.first {
            // 不管命中是 todo / event / project / quickAction，openFirst 都应同步切走 router.showSearch。
            vm.open(first)
            // .quickAction(.newXxx) 会把 showSearch 翻 false；其它 case 也会。
            #expect(router.showSearch == false)
        }
    }

    // MARK: 6. open(.todo) 按 scope 路由到 Personal / Company

    @Test("open(.todo) routes to Personal/Company by todo scope")
    func openTodoRoutesByScope() throws {
        let (context, router) = try makeSeededContextAndRouter()
        let vm = SearchViewModel(context: context, router: router)

        // 命中一个 personal todo（"Reply to mom" 是 urgent personal）。
        vm.query = "mom"
        vm.performSearch()
        guard let personalItem = vm.flatItems.first(where: { if case .todo = $0 { return true }; return false }) else {
            Issue.record("expected a todo result for query 'mom'")
            return
        }
        router.showSearch = true
        vm.open(personalItem)
        #expect(router.current == .personal)
        #expect(router.showSearch == false)

        // 命中一个 company todo（"sidebar" 属 company scope）→ 切 Company。
        vm.query = "sidebar"
        vm.performSearch()
        guard let companyItem = vm.flatItems.first(where: { if case .todo = $0 { return true }; return false }) else {
            Issue.record("expected a todo result for query 'sidebar'")
            return
        }
        router.showSearch = true
        vm.open(companyItem)
        #expect(router.current == .company)
        #expect(router.showSearch == false)
    }

    // MARK: 7. open(.event) → Calendar，open(.project) → Company

    @Test("open(.event) switches to Calendar tab; open(.project) to Company")
    func openEventAndProjectRouting() throws {
        let (context, router) = try makeSeededContextAndRouter()
        let vm = SearchViewModel(context: context, router: router)

        // Event：seed 有标题含 "standup" 的早会。
        vm.query = "standup"
        vm.scope = .events
        vm.performSearch()
        guard let eventItem = vm.flatItems.first(where: { if case .event = $0 { return true }; return false }) else {
            Issue.record("expected an event result for query 'standup'")
            return
        }
        router.showSearch = true
        vm.open(eventItem)
        #expect(router.current == .calendar)
        #expect(router.showSearch == false)

        // Project：seed 有 "LinoJ for macOS v1"。
        vm.query = "LinoJ"
        vm.scope = .projects
        vm.performSearch()
        guard let projectItem = vm.flatItems.first(where: { if case .project = $0 { return true }; return false }) else {
            Issue.record("expected a project result for query 'LinoJ'")
            return
        }
        router.showSearch = true
        vm.open(projectItem)
        #expect(router.current == .company)
        #expect(router.showSearch == false)
    }

    // MARK: 8. Quick actions: newEvent / newProject / jumpTo 全分支

    @Test("handle quick actions: newEvent / newProject / jumpTo set router correctly")
    func quickActionsCoverAllBranches() throws {
        let (context, router) = try makeSeededContextAndRouter()
        let vm = SearchViewModel(context: context, router: router)

        // newEvent
        router.showSearch = true
        vm.open(.quickAction(.newEvent))
        #expect(router.showQuickAdd == true)
        #expect(router.quickAddDefaultKind == .event)
        #expect(router.showSearch == false)

        // newProject
        router.showQuickAdd = false
        router.showSearch = true
        vm.open(.quickAction(.newProject))
        #expect(router.showQuickAdd == true)
        #expect(router.quickAddDefaultKind == .project)
        #expect(router.showSearch == false)

        // jumpTo each tab
        for tab in AppTab.allCases {
            router.showSearch = true
            vm.open(.quickAction(.jumpTo(tab)))
            #expect(router.current == tab)
            #expect(router.showSearch == false)
        }
    }

    // MARK: 9. display(for:) 覆盖 event / project / 全部 quickAction 文案分支

    @Test("display(for:) produces info for events, projects and every quick action")
    func displayInfoForAllVariants() throws {
        let (context, router) = try makeSeededContextAndRouter()
        let vm = SearchViewModel(context: context, router: router)

        // Event display：图标 calendar、hint 非空（含时间）。
        vm.query = "standup"
        vm.scope = .events
        vm.performSearch()
        if let ev = vm.flatItems.first(where: { if case .event = $0 { return true }; return false }) {
            let info = vm.display(for: ev)
            #expect(info.iconSystemName == "calendar")
            #expect(info.title.isEmpty == false)
            #expect(info.hint?.isEmpty == false)
        } else {
            Issue.record("expected an event result")
        }

        // Project display：图标 folder、hint 含 "todos"。
        vm.query = "LinoJ"
        vm.scope = .projects
        vm.performSearch()
        if let pj = vm.flatItems.first(where: { if case .project = $0 { return true }; return false }) {
            let info = vm.display(for: pj)
            #expect(info.iconSystemName == "folder")
            #expect(info.hint?.contains("todos") == true)
        } else {
            Issue.record("expected a project result")
        }

        // 每种 quick action 都有 display 文案 + shortcut hint。
        let newTodo = vm.display(for: .quickAction(.newTodo))
        #expect(newTodo.hint == "⌘N")
        let newEvent = vm.display(for: .quickAction(.newEvent))
        #expect(newEvent.iconSystemName == "calendar")
        let newProject = vm.display(for: .quickAction(.newProject))
        #expect(newProject.iconSystemName == "folder")
        for tab in AppTab.allCases {
            let info = vm.display(for: .quickAction(.jumpTo(tab)))
            #expect(info.title.contains("Jump to"))
            #expect(info.hint?.isEmpty == false)
        }
    }

    // MARK: 10. totalCount / flatItems 一致

    @Test("totalCount equals flatItems count across groups")
    func totalCountMatchesFlatItems() throws {
        let (context, router) = try makeSeededContextAndRouter()
        let vm = SearchViewModel(context: context, router: router)

        // 空 query → Quick actions + Jump to 两组。
        #expect(vm.totalCount == vm.flatItems.count)
        #expect(vm.totalCount > 0)

        // 多类型命中（"review" 命中 todos / events）。
        vm.query = "review"
        vm.performSearch()
        #expect(vm.totalCount == vm.flatItems.count)
    }
}
