//
//  TodayTotalTimeTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class TodayTotalTimeTests: XCTestCase {

    private var todayStart: TimeInterval {
        Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
    }

    private func session(offsetStart: TimeInterval, offsetEnd: TimeInterval) -> TaskSession {
        TaskSession(startedAt: todayStart + offsetStart, stoppedAt: todayStart + offsetEnd)
    }

    private func openSession(offsetStart: TimeInterval) -> TaskSession {
        TaskSession(startedAt: todayStart + offsetStart, stoppedAt: nil)
    }

    // MARK: - Tests

    func testTodayTotalTime_noTasks_isZero() {
        let (vm, _, _) = makeViewModel()
        vm.todos = []
        XCTAssertEqual(vm.todayTotalTime, 0, accuracy: 1)
    }

    func testTodayTotalTime_sessionFullyToday_counted() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        todo.sessions = [session(offsetStart: 3600, offsetEnd: 5400)] // 30 min
        vm.todos = [todo]
        XCTAssertEqual(vm.todayTotalTime, 1800, accuracy: 1)
    }

    func testTodayTotalTime_sessionStartedYesterday_excluded() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        // Started yesterday, ended today — start not in today, excluded
        todo.sessions = [TaskSession(startedAt: todayStart - 3600, stoppedAt: todayStart + 1800)]
        vm.todos = [todo]
        XCTAssertEqual(vm.todayTotalTime, 0, accuracy: 1)
    }

    func testTodayTotalTime_sessionEndedYesterday_excluded() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        // Started and ended yesterday — neither in today
        todo.sessions = [TaskSession(startedAt: todayStart - 7200, stoppedAt: todayStart - 3600)]
        vm.todos = [todo]
        XCTAssertEqual(vm.todayTotalTime, 0, accuracy: 1)
    }

    func testTodayTotalTime_openSession_notCounted() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        todo.sessions = [openSession(offsetStart: -60)] // currently running, no stoppedAt
        vm.todos = [todo]
        XCTAssertEqual(vm.todayTotalTime, 0, accuracy: 1)
    }

    func testTodayTotalTime_subtaskSessionsToday_counted() {
        let (vm, _, _) = makeViewModel()
        var subtask = makeSubtask()
        subtask.sessions = [session(offsetStart: 0, offsetEnd: 900)] // 15 min
        let todo = makeTodo(subtasks: [subtask])
        vm.todos = [todo]
        XCTAssertEqual(vm.todayTotalTime, 900, accuracy: 1)
    }

    func testTodayTotalTime_multipleSessions_summed() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        todo.sessions = [
            session(offsetStart: 0, offsetEnd: 1800),    // 30 min
            session(offsetStart: 3600, offsetEnd: 5400), // 30 min
        ]
        vm.todos = [todo]
        XCTAssertEqual(vm.todayTotalTime, 3600, accuracy: 1)
    }

    func testTodayTotalTime_multipleTasks_summed() {
        let (vm, _, _) = makeViewModel()
        var t1 = makeTodo(text: "A")
        t1.sessions = [session(offsetStart: 0, offsetEnd: 1800)]
        var t2 = makeTodo(text: "B")
        t2.sessions = [session(offsetStart: 3600, offsetEnd: 5400)]
        vm.todos = [t1, t2]
        XCTAssertEqual(vm.todayTotalTime, 3600, accuracy: 1)
    }
}
