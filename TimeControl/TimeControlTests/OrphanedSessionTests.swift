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

        // Short sessions are now kept but marked as discardedShort (not removed)
        XCTAssertEqual(vm.todos[0].sessions.count, 1)
        XCTAssertNotNil(vm.todos[0].sessions[0].stoppedAt)
        XCTAssertEqual(vm.todos[0].sessions[0].outcome, .discardedShort)
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

    // MARK: - Cycle 5: lastSeenAt for crash recovery

    func test_sanitize_usesLastSeenAt_asStoppedAt_notNow() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        let startedAt = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        todo.lastStartTime = startedAt
        todo.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        vm.todos = [todo]

        let lastSeen = Date(timeIntervalSinceNow: -1800) // 30 min ago
        vm.lastSeenAt = lastSeen

        vm.sanitizeOrphanedRunningState()

        // stoppedAt should be approximately lastSeenAt, not now (1 hour later)
        let stoppedAt = vm.todos[0].sessions.last?.stoppedAt ?? 0
        let diff = abs(stoppedAt - lastSeen.timeIntervalSince1970)
        XCTAssertLessThanOrEqual(diff, 2, "stoppedAt should be within 2s of lastSeenAt")

        // totalTimeSpent should be ~30 min, not ~60 min
        XCTAssertGreaterThanOrEqual(vm.todos[0].totalTimeSpent, 1700)
        XCTAssertLessThanOrEqual(vm.todos[0].totalTimeSpent, 1900)
    }

    func test_sanitize_fallsBackToNow_whenLastSeenAtAbsent() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        let startedAt = Date(timeIntervalSinceNow: -120)
        todo.lastStartTime = startedAt
        todo.sessions = [TaskSession(startedAt: startedAt.timeIntervalSince1970)]
        vm.todos = [todo]

        vm.lastSeenAt = nil

        vm.sanitizeOrphanedRunningState()

        // Should work exactly like before: use current time as cutoff
        XCTAssertNil(vm.todos[0].lastStartTime)
        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertGreaterThanOrEqual(vm.todos[0].totalTimeSpent, 115)
    }

    func test_lastSeenAt_persisted_onTimerTick() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        todo.lastStartTime = Date()
        todo.sessions = [TaskSession(startedAt: Date().timeIntervalSince1970)]
        vm.todos = [todo]
        vm.runningTaskId = todo.id

        // Force a timer tick by manually calling the tick handler
        vm.handleTimerTick()

        XCTAssertNotNil(vm.lastSeenAt)
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
