//
//  SessionDiscardTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class SessionDiscardTests: XCTestCase {

    // MARK: - Cycle 4: 30 s discard made explicit in the data model

    func test_stopSession_underThirtySeconds_marksSessionAsDiscarded_notRemoved() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo(text: "Task")
        // Start 10 s ago — will be < 30 s threshold
        let startedAt = Date(timeIntervalSinceNow: -10)
        todo.lastStartTime = startedAt
        todo.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        vm.todos = [todo]

        // Pause via toggleTimer (calls stopSession)
        vm.toggleTimer(vm.todos[0])

        // Session should still be present
        XCTAssertEqual(vm.todos[0].sessions.count, 1, "Short session should be kept, not removed")
        // Session should have stoppedAt
        XCTAssertNotNil(vm.todos[0].sessions[0].stoppedAt, "Short session should have stoppedAt set")
        // Session outcome should be discardedShort
        XCTAssertEqual(vm.todos[0].sessions[0].outcome, .discardedShort, "Short session should be marked as discardedShort")
    }

    func test_stopSession_overThirtySeconds_marksSessionAsCompleted() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo(text: "Task")
        let startedAt = Date(timeIntervalSinceNow: -60)
        todo.lastStartTime = startedAt
        todo.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        vm.todos = [todo]

        vm.toggleTimer(vm.todos[0])

        XCTAssertNotNil(vm.todos[0].sessions.last?.stoppedAt)
        XCTAssertEqual(vm.todos[0].sessions[0].outcome, .completed)
    }

    func test_totalTimeSpent_unchanged_byDiscardOutcome_short() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo(text: "Task")
        let startedAt = Date(timeIntervalSinceNow: -10)
        todo.lastStartTime = startedAt
        todo.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        vm.todos = [todo]

        vm.toggleTimer(vm.todos[0])

        // Even discarded sessions should accumulate totalTimeSpent
        XCTAssertGreaterThan(vm.todos[0].totalTimeSpent, 0)
    }

    func test_totalTimeSpent_unchanged_byDiscardOutcome_long() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo(text: "Task")
        let startedAt = Date(timeIntervalSinceNow: -60)
        todo.lastStartTime = startedAt
        todo.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        vm.todos = [todo]

        vm.toggleTimer(vm.todos[0])

        XCTAssertGreaterThanOrEqual(vm.todos[0].totalTimeSpent, 60)
    }
}
