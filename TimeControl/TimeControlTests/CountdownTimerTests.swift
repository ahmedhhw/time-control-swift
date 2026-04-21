//
//  CountdownTimerTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class CountdownTimerTests: XCTestCase {

    func test_clearCountdown_zeroesAllFields() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        todo.countdownTime = 900
        todo.countdownElapsedAtPause = 300
        todo.countdownStartTime = Date()
        vm.todos = [todo]

        vm.clearCountdown(taskId: todo.id)

        XCTAssertEqual(vm.todos[0].countdownTime, 0)
        XCTAssertEqual(vm.todos[0].countdownElapsedAtPause, 0)
        XCTAssertNil(vm.todos[0].countdownStartTime)
    }

    func test_countdownElapsed_cappedAtCountdownTime() {
        var todo = makeTodo()
        todo.countdownTime = 60
        todo.countdownElapsedAtPause = 70  // over the limit, task not running
        XCTAssertEqual(todo.countdownElapsed, 60)
    }

    func test_countdownElapsed_isZero_afterClear() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        todo.countdownTime = 900
        todo.countdownElapsedAtPause = 450
        vm.todos = [todo]

        vm.clearCountdown(taskId: todo.id)

        XCTAssertEqual(vm.todos[0].countdownElapsed, 0)
    }

    func test_todayTotalTime_doesNotCrash_withOpenSession() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo()
        todo.sessions = [TaskSession(startedAt: Date().timeIntervalSince1970)]  // no stoppedAt
        vm.todos = [todo]

        XCTAssertGreaterThanOrEqual(vm.todayTotalTime, 0)
    }
}
