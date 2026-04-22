//
//  TaskSessionTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class TaskSessionTests: XCTestCase {

    func testSession_stoppedAt_nil_whenOngoing() {
        let s = TaskSession(startedAt: 1000)
        XCTAssertNil(s.stoppedAt)
    }

    func testSession_duration_whenStopped() {
        let s = TaskSession(startedAt: 1000, stoppedAt: 1060)
        XCTAssertEqual(s.stoppedAt! - s.startedAt, 60)
    }

    // MARK: - isComplete

    func testSession_isComplete_whenBothTimesSet() {
        let s = TaskSession(startedAt: 1000, stoppedAt: 2000)
        XCTAssertTrue(s.isComplete)
    }

    func testSession_isComplete_false_whenNoStoppedAt() {
        let s = TaskSession(startedAt: 1000)
        XCTAssertFalse(s.isComplete)
    }

    // MARK: - HistorySessionProcessor filtering

    func testHistory_excludesOpenSession_onToday() {
        let now = Date()
        let openSession = TaskSession(startedAt: now.timeIntervalSince1970 - 600)  // no stoppedAt
        let todo = makeTodoWithSessions([openSession])
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: now)
        XCTAssertTrue(entries.isEmpty, "Open sessions must not appear in history")
    }

    func testHistory_includesLongCompletedSession_onToday() {
        let now = Date()
        // 10-minute completed session (>= 5 min threshold)
        let completedSession = TaskSession(startedAt: now.timeIntervalSince1970 - 600, stoppedAt: now.timeIntervalSince1970 - 60)
        let todo = makeTodoWithSessions([completedSession])
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: now)
        XCTAssertEqual(entries.count, 1)
    }

    func testHistory_excludesOpenSession_onPastDay() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let start = Calendar.current.startOfDay(for: yesterday).timeIntervalSince1970 + 3600
        let openSession = TaskSession(startedAt: start)  // no stoppedAt
        let todo = makeTodoWithSessions([openSession])
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: yesterday)
        XCTAssertTrue(entries.isEmpty, "Open sessions on past days must not appear")
    }

    func testHistory_includesLongCompletedSession_onPastDay() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let start = Calendar.current.startOfDay(for: yesterday).timeIntervalSince1970 + 3600
        // 30-minute session
        let completedSession = TaskSession(startedAt: start, stoppedAt: start + 1800)
        let todo = makeTodoWithSessions([completedSession])
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: yesterday)
        XCTAssertEqual(entries.count, 1)
    }

    // MARK: - Helper

    private func makeTodoWithSessions(_ sessions: [TaskSession]) -> TodoItem {
        var todo = TodoItem(text: "Test Task")
        todo.sessions = sessions
        return todo
    }
}
