// CalendarViewModelTests.swift
// 验证 CalendarViewModel 在 seed 数据上的行为。
//
// ⚠️ 窗口模型（对齐设计稿）：Calendar 是「today 起算的滚动 7 天窗口」，不再回退到周一。
//   - today = startOfDay(2026-05-27 09:00) = 2026-05-27 00:00
//   - weekStart = today（窗口第一列就是 today）
//   - 7 天窗口 = May 27 .. June 2（today .. today+6）
//   - seed 的 16 个事件（dayOffset 0..6 = Tue/Wed/Thu/Fri/Sat/Sun/Mon2）全部落在窗口内
//     → weekTotal == 16。
//   - y1/y2（yesterday = May 26）落在窗口外，不计入 weekTotal；仍出现在 yesterdayMissed（=2）。

import Foundation
import SwiftData
import Testing
@testable import LinoJCore

@Suite("CalendarViewModel — week math + seed events")
@MainActor
struct CalendarViewModelTests {

    private func makeSeededVM() throws -> (CalendarViewModel, ModelContext) {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)
        let vm = CalendarViewModel(context: context)
        return (vm, context)
    }

    // MARK: - weekStart 计算

    @Test("weekStart = today 的 startOfDay（滚动窗口第一列就是 today：2026-05-27）")
    func weekStartIsToday() throws {
        let (vm, _) = try makeSeededVM()
        let calendar = CalendarViewModel.calendar
        let todayStart = calendar.startOfDay(for: LinoJTime.today())
        #expect(vm.weekStart == todayStart)
        // weekDays 第一项 == weekStart == today。
        #expect(vm.weekDays.first == todayStart)
    }

    // MARK: - eventsByDay 形态

    @Test("eventsByDay 共 7 个 key（含空天）")
    func eventsByDayHasSevenKeys() throws {
        let (vm, _) = try makeSeededVM()
        #expect(vm.eventsByDay.count == 7)
    }

    @Test("today（May 27，窗口第一列）那天有 4 个事件")
    func tueHasFourEvents() throws {
        let (vm, _) = try makeSeededVM()
        let calendar = CalendarViewModel.calendar
        let tueStart: Date = {
            var comps = DateComponents()
            comps.year = 2026
            comps.month = 5
            comps.day = 27
            return calendar.startOfDay(for: calendar.date(from: comps) ?? .now)
        }()
        let tueEvents = vm.eventsByDay[tueStart] ?? []
        #expect(tueEvents.count == 4)
        // 4 场 Tue 事件按 start 排序后顺序应为：Morning standup → 1:1 with Mei → Design review → Dinner with parents。
        let titles = tueEvents.map(\.title)
        #expect(titles == [
            "Morning standup",
            "1:1 with Mei",
            "Design review — sidebar",
            "Dinner with parents",
        ])
    }

    // MARK: - 周导航

    @Test("goNextWeek() 让 weekStart += 7 天")
    func goNextWeekAdvances() throws {
        let (vm, _) = try makeSeededVM()
        let before = vm.weekStart
        vm.goNextWeek()
        let calendar = CalendarViewModel.calendar
        let dayDiff = calendar.dateComponents([.day], from: before, to: vm.weekStart).day
        #expect(dayDiff == 7)
    }

    @Test("goPrevWeek() 让 weekStart -= 7 天")
    func goPrevWeekRetreats() throws {
        let (vm, _) = try makeSeededVM()
        let before = vm.weekStart
        vm.goPrevWeek()
        let calendar = CalendarViewModel.calendar
        let dayDiff = calendar.dateComponents([.day], from: before, to: vm.weekStart).day
        #expect(dayDiff == -7)
    }

    @Test("goToday() reset 到 today 起算窗口")
    func goTodayResetsToTodayWeek() throws {
        let (vm, _) = try makeSeededVM()
        vm.goNextWeek()
        vm.goNextWeek()
        let calendar = CalendarViewModel.calendar
        let todayWeek = CalendarViewModel.startOfWeek(containing: LinoJTime.today())
        vm.goToday()
        #expect(calendar.isDate(vm.weekStart, inSameDayAs: todayWeek))
        // weekStart reset 后 == today 的 startOfDay。
        let todayStart = calendar.startOfDay(for: LinoJTime.today())
        #expect(vm.weekStart == todayStart)
        // selectedDay 也应回到 today 的 startOfDay。
        #expect(calendar.isDate(vm.selectedDay, inSameDayAs: todayStart))
    }

    // MARK: - selectDay + isViewingTodayWeek

    @Test("selectDay 写入 startOfDay")
    func selectDayNormalizesToStartOfDay() throws {
        let (vm, _) = try makeSeededVM()
        let calendar = CalendarViewModel.calendar
        let pickedRaw: Date = {
            var comps = DateComponents()
            comps.year = 2026
            comps.month = 5
            comps.day = 30
            comps.hour = 14
            comps.minute = 12
            return calendar.date(from: comps) ?? .now
        }()
        vm.selectDay(pickedRaw)
        #expect(vm.selectedDay == calendar.startOfDay(for: pickedRaw))
    }

    @Test("初始 isViewingTodayWeek == true；goNextWeek 后 == false")
    func isViewingTodayWeekFlag() throws {
        let (vm, _) = try makeSeededVM()
        #expect(vm.isViewingTodayWeek)
        vm.goNextWeek()
        #expect(vm.isViewingTodayWeek == false)
        vm.goToday()
        #expect(vm.isViewingTodayWeek)
    }

    // MARK: - yesterdayMissed

    @Test("yesterdayMissed 含 2 个未确认昨日事件")
    func yesterdayMissedFromSeed() throws {
        let (vm, _) = try makeSeededVM()
        let missed = vm.yesterdayMissed
        #expect(missed.count == 2)
        let titles = Set(missed.map(\.title))
        #expect(titles == Set(["Engineering standup", "Coffee with Andrew"]))
    }

    @Test("confirmAttended 把对应 event attendedConfirmed 置 true，从 missed 中移除")
    func confirmAttendedDropsFromMissed() throws {
        let (vm, _) = try makeSeededVM()
        guard let first = vm.yesterdayMissed.first else {
            Issue.record("seed should produce at least one missed event")
            return
        }
        vm.confirmAttended(first)
        #expect(first.attendedConfirmed)
        #expect(vm.yesterdayMissed.count == 1)
    }

    // MARK: - W2: showYesterdayMissed gate

    @Test("W2: showYesterdayMissed == false 时 yesterdayMissed 短路为空（fallback 路径）")
    func yesterdayMissedGatedOffFallback() throws {
        let (vm, _) = try makeSeededVM()
        #expect(vm.showYesterdayMissed == true)
        #expect(vm.yesterdayMissed.count == 2)
        vm.showYesterdayMissed = false
        #expect(vm.yesterdayMissed.isEmpty)
        vm.showYesterdayMissed = true
        #expect(vm.yesterdayMissed.count == 2)
    }

    @Test("W2: showYesterdayMissed gate 也短路 service-backed 路径")
    func yesterdayMissedGatedOffWithService() throws {
        let container = try LinoJStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try SeedData.seedIfEmpty(context)
        let service = YesterdayMissedService(context: context)
        let vm = CalendarViewModel(context: context, yesterdayMissedService: service)
        #expect(vm.yesterdayMissed.count == 2)
        vm.showYesterdayMissed = false
        #expect(vm.yesterdayMissed.isEmpty)
    }

    // MARK: - weekTotal

    @Test("weekTotal == 16（窗口 May 27-Jun 2 含全部 16 个 seed 事件；y1/y2 yesterday 在窗口外）")
    func weekTotalAcrossSeed() throws {
        let (vm, _) = try makeSeededVM()
        #expect(vm.weekTotal == 16)
        // 验证各天 count 之和与 weekTotal 一致（reduce 算法自洽）。
        let summed = vm.weekDays.reduce(0) { $0 + (vm.eventsByDay[$1]?.count ?? 0) }
        #expect(summed == vm.weekTotal)
    }
}
