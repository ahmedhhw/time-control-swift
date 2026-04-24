//
//  HistoryWeeklyTotalsTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class HistoryWeeklyTotalsTests: XCTestCase {

    // MARK: - Helpers

    private var cal: Calendar { Calendar.current }

    /// Builds the 42-day calendar grid for the month containing `date`, matching
    /// the same logic used by HistoryView.calendarDays.
    private func calendarDays(for month: Date) -> [Date] {
        guard let monthInterval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - 1 + 7) % 7
        guard let start = cal.date(byAdding: .day, value: -leadingBlanks, to: monthInterval.start) else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func startOfMonth(for date: Date) -> Date {
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    private func session(on date: Date, hours: Double) -> TaskSession {
        let start = cal.startOfDay(for: date).timeIntervalSince1970 + 3600
        return TaskSession(startedAt: start, stoppedAt: start + hours * 3600)
    }

    // MARK: - Tests

    func testNoSessions_allZero() {
        let month = startOfMonth(for: Date())
        let days = calendarDays(for: month)
        let todo = makeTodo()
        let totals = HistoryWeeklyTotals.compute(for: days, displayedMonth: month, todos: [todo])
        XCTAssertEqual(totals.count, 6)
        XCTAssertTrue(totals.allSatisfy { $0 == 0 })
    }

    func testSession_countedInCorrectWeek() {
        let month = startOfMonth(for: Date())
        let days = calendarDays(for: month)

        // Find the first in-month day and put a session there
        guard let firstInMonth = days.first(where: { cal.isDate($0, equalTo: month, toGranularity: .month) }) else {
            return XCTFail("No in-month day found")
        }
        let weekIndex = days.firstIndex(of: firstInMonth)! / 7

        var todo = makeTodo()
        todo.sessions = [session(on: firstInMonth, hours: 2)]
        let totals = HistoryWeeklyTotals.compute(for: days, displayedMonth: month, todos: [todo])

        XCTAssertEqual(totals[weekIndex], 2 * 3600, accuracy: 1)
        for (i, total) in totals.enumerated() where i != weekIndex {
            XCTAssertEqual(total, 0, "Week \(i) should be 0")
        }
    }

    func testAdjacentMonthDays_excluded() {
        let month = startOfMonth(for: Date())
        let days = calendarDays(for: month)

        // First day of the grid is potentially an adjacent-month day
        guard let adjDay = days.first, !cal.isDate(adjDay, equalTo: month, toGranularity: .month) else {
            // No adjacent day in first row; skip
            return
        }
        var todo = makeTodo()
        todo.sessions = [session(on: adjDay, hours: 5)]
        let totals = HistoryWeeklyTotals.compute(for: days, displayedMonth: month, todos: [todo])
        XCTAssertTrue(totals.allSatisfy { $0 == 0 }, "Adjacent-month session must not appear in weekly totals")
    }

    func testMultipleSessions_sameDaySummed() {
        let month = startOfMonth(for: Date())
        let days = calendarDays(for: month)
        guard let day = days.first(where: { cal.isDate($0, equalTo: month, toGranularity: .month) }) else { return }
        let weekIndex = days.firstIndex(of: day)! / 7

        let dayStart = cal.startOfDay(for: day).timeIntervalSince1970
        let s1 = TaskSession(startedAt: dayStart + 3600, stoppedAt: dayStart + 7200)   // 1 h
        let s2 = TaskSession(startedAt: dayStart + 10800, stoppedAt: dayStart + 14400) // 1 h
        var todo = makeTodo()
        todo.sessions = [s1, s2]
        let totals = HistoryWeeklyTotals.compute(for: days, displayedMonth: month, todos: [todo])
        XCTAssertEqual(totals[weekIndex], 2 * 3600, accuracy: 1)
    }

    func testSubtaskSessions_counted() {
        let month = startOfMonth(for: Date())
        let days = calendarDays(for: month)
        guard let day = days.first(where: { cal.isDate($0, equalTo: month, toGranularity: .month) }) else { return }
        let weekIndex = days.firstIndex(of: day)! / 7

        let dayStart = cal.startOfDay(for: day).timeIntervalSince1970
        var sub = makeSubtask()
        sub.sessions = [TaskSession(startedAt: dayStart + 3600, stoppedAt: dayStart + 5400)] // 30 min
        var todo = makeTodo(subtasks: [sub])
        todo.sessions = []
        let totals = HistoryWeeklyTotals.compute(for: days, displayedMonth: month, todos: [todo])
        XCTAssertEqual(totals[weekIndex], 1800, accuracy: 1)
    }

    func testIncompleteSession_excluded() {
        let month = startOfMonth(for: Date())
        let days = calendarDays(for: month)
        guard let day = days.first(where: { cal.isDate($0, equalTo: month, toGranularity: .month) }) else { return }

        // Session with no stoppedAt — still running
        let dayStart = cal.startOfDay(for: day).timeIntervalSince1970
        var todo = makeTodo()
        todo.sessions = [TaskSession(startedAt: dayStart + 3600, stoppedAt: nil)]
        let totals = HistoryWeeklyTotals.compute(for: days, displayedMonth: month, todos: [todo])
        XCTAssertTrue(totals.allSatisfy { $0 == 0 }, "Running session should not contribute to weekly total")
    }

    // MARK: - Format tests

    func testFormat_zero_returnsEmpty() {
        XCTAssertEqual(HistoryWeeklyTotals.format(0), "")
    }

    func testFormat_minutesOnly() {
        XCTAssertEqual(HistoryWeeklyTotals.format(30 * 60), "30m")
    }

    func testFormat_hoursOnly() {
        XCTAssertEqual(HistoryWeeklyTotals.format(2 * 3600), "2h")
    }

    func testFormat_hoursAndMinutes() {
        XCTAssertEqual(HistoryWeeklyTotals.format(2 * 3600 + 30 * 60), "2h 30m")
    }
}
