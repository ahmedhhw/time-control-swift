//
//  ImprovementsTests.swift
//  TimeControlTests
//
//  Tests for the 5 improvements in improvements.md
//

import XCTest
@testable import TimeControl

// MARK: - Issue 5: Completed task timer guard

final class CompletedTaskTimerGuardTests: XCTestCase {

    func testToggleTimer_onCompletedTask_isNoop() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo(text: "Done", isCompleted: true)
        vm.todos = [todo]

        vm.toggleTimer(vm.todos[0])

        XCTAssertFalse(vm.todos[0].isRunning, "Completed task must not start running")
        XCTAssertNil(vm.runningTaskId, "runningTaskId must stay nil when completed task is toggled")
    }

    func testToggleTimer_onCompletedTask_doesNotAccumulateTime() {
        let (vm, _, _) = makeViewModel()
        var todo = makeTodo(text: "Done", isCompleted: true)
        todo.totalTimeSpent = 100
        vm.todos = [todo]

        vm.toggleTimer(vm.todos[0])

        XCTAssertEqual(vm.todos[0].totalTimeSpent, 100, accuracy: 0.01, "Time must not change when toggling a completed task")
    }

    func testToggleTimer_onIncompleteTask_starts() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Active")]

        vm.toggleTimer(vm.todos[0])

        XCTAssertTrue(vm.todos[0].isRunning)
        XCTAssertEqual(vm.runningTaskId, vm.todos[0].id)
    }

    func testToggleTimer_completingRunningTask_doesNotRestart() {
        // Simulate: task running, then completed, then timer toggled again — must be no-op
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        XCTAssertTrue(vm.todos[0].isRunning)

        // Complete the task while it's running (ViewModel pauses it internally)
        vm.toggleTodo(vm.todos[0])
        XCTAssertTrue(vm.todos[0].isCompleted)
        XCTAssertFalse(vm.todos[0].isRunning)

        // Attempt to toggle timer again — should be a no-op
        let timeBefore = vm.todos[0].totalTimeSpent
        vm.toggleTimer(vm.todos[0])
        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertEqual(vm.todos[0].totalTimeSpent, timeBefore, accuracy: 0.01)
    }
}

// MARK: - Issue 2 & 3: Sleep/wake keeps floating window addressable

final class SleepWakeWindowTests: XCTestCase {

    func testWillSleep_taskTimerStopped() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        XCTAssertTrue(vm.todos[0].isRunning)

        postSleep()

        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertNil(vm.todos[0].lastStartTime)
    }

    func testWillSleep_runningTaskIdPreservedForWindowResumption() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        let taskId = vm.todos[0].id

        postSleep()

        XCTAssertEqual(vm.runningTaskId, taskId,
                       "runningTaskId must be preserved so the floating window can present Resume after wake")
    }

    func testWillSleep_sleepPausedTaskIdSet() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        let taskId = vm.todos[0].id

        postSleep()

        XCTAssertEqual(vm.sleepPausedTaskId, taskId)
    }

    // MARK: - Helpers

    private func postSleep() {
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}
