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

    // MARK: - HistoryView session filtering

    func testHistoryView_excludesOpenSession_onToday() {
        let now = Date()
        let openSession = TaskSession(startedAt: now.timeIntervalSince1970 - 300)  // started 5 min ago, no end
        var todo = makeTodoWithSessions([openSession])
        let view = HistoryView(todos: [todo])
        XCTAssertTrue(view.visibleSessions(for: now).isEmpty, "Open sessions must not appear in history view")
    }

    func testHistoryView_includesCompletedSession_onToday() {
        let now = Date()
        let completedSession = TaskSession(startedAt: now.timeIntervalSince1970 - 300, stoppedAt: now.timeIntervalSince1970 - 60)
        let todo = makeTodoWithSessions([completedSession])
        let view = HistoryView(todos: [todo])
        XCTAssertEqual(view.visibleSessions(for: now).count, 1)
    }

    func testHistoryView_excludesOpenSession_onPastDay() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let start = Calendar.current.startOfDay(for: yesterday).timeIntervalSince1970 + 3600  // 1 AM yesterday
        let openSession = TaskSession(startedAt: start)  // no stoppedAt
        let todo = makeTodoWithSessions([openSession])
        let view = HistoryView(todos: [todo])
        XCTAssertTrue(view.visibleSessions(for: yesterday).isEmpty, "Open sessions on past days must not appear")
    }

    func testHistoryView_includesCompletedSession_onPastDay() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let start = Calendar.current.startOfDay(for: yesterday).timeIntervalSince1970 + 3600
        let completedSession = TaskSession(startedAt: start, stoppedAt: start + 1800)
        let todo = makeTodoWithSessions([completedSession])
        let view = HistoryView(todos: [todo])
        XCTAssertEqual(view.visibleSessions(for: yesterday).count, 1)
    }

    // MARK: - Helper

    private func makeTodoWithSessions(_ sessions: [TaskSession]) -> TodoItem {
        var todo = TodoItem(text: "Test Task")
        todo.sessions = sessions
        return todo
    }
}
