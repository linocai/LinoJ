// ModelTests.swift
// 验证四个 @Model 类型的 CRUD 与关系完整性。
//
// 所有测试方法都标 @MainActor —— SwiftData ModelContext 在 Swift 6 strict concurrency 下
// 是 main-actor-isolated；LinoJStore.makeContainer 同样限制在 MainActor。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("Model CRUD & relationships")
@MainActor
struct ModelTests {

    /// 创建容器辅助。每个 test 拿独立的 in-memory 容器，互不污染。
    private func makeContext() throws -> ModelContext {
        let container = try LinoJStore.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    @Test("Person CRUD")
    func personCRUD() throws {
        let context = try makeContext()
        let alice = Person(name: "Alice")
        context.insert(alice)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Person>())
        try #require(fetched.count == 1)
        #expect(fetched[0].name == "Alice")
        #expect(fetched[0].initial == "A")

        context.delete(fetched[0])
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Person>()) == 0)
    }

    @Test("Project deletion nullifies todos.project")
    func projectDeletionNullifiesTodos() throws {
        let context = try makeContext()

        let project = Project(
            title: "Throwaway",
            intro: "intro",
            notes: "notes",
            tag: "tag",
            members: [],
            createdAt: .now
        )
        let todoA = Todo(title: "A", urgency: .normal, scope: .company, project: project)
        let todoB = Todo(title: "B", urgency: .normal, scope: .company, project: nil)
        context.insert(project)
        context.insert(todoA)
        context.insert(todoB)
        try context.save()

        #expect(todoA.project != nil)
        #expect(todoB.project == nil)

        context.delete(project)
        try context.save()

        // 重新 fetch 一遍，避免读到旧的内存引用。
        let todos = try context.fetch(FetchDescriptor<Todo>())
        try #require(todos.count == 2)
        for todo in todos {
            #expect(todo.project == nil, "delete project 后所有 todo.project 应被 nullify")
        }
        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 0)
    }

    @Test("Todo urgency / scope round-trip")
    func todoEnumRoundTrip() throws {
        let context = try makeContext()
        let todo = Todo(title: "Demo", urgency: .urgent, scope: .company)
        context.insert(todo)
        try context.save()

        let id = todo.id
        var fetchDescriptor = FetchDescriptor<Todo>(predicate: #Predicate { $0.id == id })
        fetchDescriptor.fetchLimit = 1
        let fetched = try #require(try context.fetch(fetchDescriptor).first)
        #expect(fetched.urgency == .urgent)
        #expect(fetched.scope == .company)

        fetched.urgency = .normal
        fetched.scope = .personal
        try context.save()

        let again = try #require(try context.fetch(fetchDescriptor).first)
        #expect(again.urgency == .normal)
        #expect(again.scope == .personal)
        #expect(again.urgencyRaw == "normal")
        #expect(again.scopeRaw == "personal")
    }

    @Test("Event attendees relationship")
    func eventAttendees() throws {
        let context = try makeContext()
        let p1 = Person(name: "M")
        let p2 = Person(name: "A")
        let p3 = Person(name: "J")
        context.insert(p1)
        context.insert(p2)
        context.insert(p3)

        let event = Event(
            title: "Morning standup",
            start: .now,
            end: .now.addingTimeInterval(1800),
            location: "Zoom",
            attendees: [p1, p2, p3]
        )
        context.insert(event)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Event>()).first)
        // V1：attendees 改 optional（[Person]?），统一 `?? []` 兜底。
        #expect((fetched.attendees ?? []).count == 3)
        let names = Set((fetched.attendees ?? []).map(\.name))
        #expect(names == Set(["M", "A", "J"]))
    }
}
