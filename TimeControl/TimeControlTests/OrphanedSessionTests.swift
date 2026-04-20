//
//  OrphanedSessionTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class OrphanedSessionTests: XCTestCase {

    // MARK: - Task orphan cleanup

    func test_orphanedTask_isNotRunningAfterSanitize() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        let startedAt = Date(timeIntervalSinceNow: -120)
        todo.lastStartTime = startedAt
        todo.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        vm.todos = [todo]

        vm.sanitizeOrphanedRunningState()

        XCTAssertNil(vm.todos[0].lastStartTime)
        XCTAssertFalse(vm.todos[0].isRunning)
    }

    func test_orphanedTask_elapsedTimeAccumulated() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        todo.totalTimeSpent = 60
        let startedAt = Date(timeIntervalSinceNow: -120)
        todo.lastStartTime = startedAt
        todo.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        vm.todos = [todo]

        vm.sanitizeOrphanedRunningState()

        XCTAssertGreaterThanOrEqual(vm.todos[0].totalTimeSpent, 180)
    }

    func test_orphanedSession_getsStoppedAt_whenLongEnough() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        let startedAt = Date(timeIntervalSinceNow: -60)
        todo.lastStartTime = startedAt
        todo.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        vm.todos = [todo]

        vm.sanitizeOrphanedRunningState()

        XCTAssertNotNil(vm.todos[0].sessions.last?.stoppedAt)
    }

    func test_orphanedSession_discarded_whenTooShort() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        let startedAt = Date(timeIntervalSinceNow: -10)
        todo.lastStartTime = startedAt
        todo.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        vm.todos = [todo]

        vm.sanitizeOrphanedRunningState()

        XCTAssertTrue(vm.todos[0].sessions.isEmpty)
    }

    // MARK: - Subtask orphan cleanup

    func test_orphanedSubtask_isCleanedUp() {
        let (vm, _, _) = makeViewModel()
        var subtask = makeSubtask()
        let startedAt = Date(timeIntervalSinceNow: -120)
        subtask.lastStartTime = startedAt
        subtask.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        let todo = makeTodo(subtasks: [subtask])
        vm.todos = [todo]

        vm.sanitizeOrphanedRunningState()

        XCTAssertNil(vm.todos[0].subtasks[0].lastStartTime)
        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
    }

    func test_orphanedSubtask_elapsedTimeAccumulated() {
        let (vm, _, _) = makeViewModel()
        var subtask = makeSubtask()
        subtask.totalTimeSpent = 30
        let startedAt = Date(timeIntervalSinceNow: -90)
        subtask.lastStartTime = startedAt
        subtask.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        let todo = makeTodo(subtasks: [subtask])
        vm.todos = [todo]

        vm.sanitizeOrphanedRunningState()

        XCTAssertGreaterThanOrEqual(vm.todos[0].subtasks[0].totalTimeSpent, 120)
    }

    // MARK: - Non-orphaned state is untouched

    func test_nonRunningTask_isUntouched() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        todo.totalTimeSpent = 300
        todo.sessions = [TaskSession(startedAt: 1000, stoppedAt: 1300)]
        vm.todos = [todo]

        vm.sanitizeOrphanedRunningState()

        XCTAssertEqual(vm.todos[0].totalTimeSpent, 300)
        XCTAssertEqual(vm.todos[0].sessions.count, 1)
        XCTAssertNotNil(vm.todos[0].sessions[0].stoppedAt)
    }
}
