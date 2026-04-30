//
//  TaskPauseConsistencyTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class TaskPauseConsistencyTests: XCTestCase {

    // MARK: - Cycle 1: createTask(switchToIt:) pauses running subtasks on the previous task

    func test_createTask_switchToIt_pausesRunningSubtaskOnPreviousTask() {
        let (vm, _, _) = makeViewModel()
        let s1 = makeSubtask(title: "S1")
        let taskA = makeTodo(text: "A", subtasks: [s1])
        vm.todos = [taskA]

        // Start task A — auto-starts s1
        vm.toggleTimer(vm.todos[0])
        // Backdate both lastStartTime and session startedAt so > 30s elapsed
        let pastDate = Date(timeIntervalSinceNow: -60)
        vm.todos[0].subtasks[0].lastStartTime = pastDate
        if !vm.todos[0].subtasks[0].sessions.isEmpty {
            vm.todos[0].subtasks[0].sessions[vm.todos[0].subtasks[0].sessions.count - 1].startedAt = pastDate.timeIntervalSince1970
        }

        // Create new task C and switch to it
        vm.createTask(title: "C", switchToIt: true)

        let s1AfterSwitch = vm.todos.first(where: { $0.text == "A" })!.subtasks.first(where: { $0.id == s1.id })!
        XCTAssertNil(s1AfterSwitch.lastStartTime, "s1 should not be running after switching away from A")
        XCTAssertFalse(s1AfterSwitch.isRunning, "s1.isRunning should be false")
        XCTAssertGreaterThan(s1AfterSwitch.totalTimeSpent, 0, "s1 should have accumulated time")
    }

    func test_createTask_switchToIt_pausesRunningSubtaskTimer_setsStoppedAt() {
        let (vm, _, _) = makeViewModel()
        let s1 = makeSubtask(title: "S1")
        let taskA = makeTodo(text: "A", subtasks: [s1])
        vm.todos = [taskA]

        // Start task A — auto-starts s1
        vm.toggleTimer(vm.todos[0])
        // Backdate both lastStartTime AND the session startedAt so stopSubtaskSession sees > 30s
        let pastDate = Date(timeIntervalSinceNow: -60)
        vm.todos[0].subtasks[0].lastStartTime = pastDate
        if !vm.todos[0].subtasks[0].sessions.isEmpty {
            vm.todos[0].subtasks[0].sessions[vm.todos[0].subtasks[0].sessions.count - 1].startedAt = pastDate.timeIntervalSince1970
        }

        vm.createTask(title: "C", switchToIt: true)

        let s1After = vm.todos.first(where: { $0.text == "A" })!.subtasks.first(where: { $0.id == s1.id })!
        XCTAssertNotNil(s1After.sessions.last?.stoppedAt, "The trailing session for s1 should have stoppedAt set")
    }

    // MARK: - Cycle 1 regression guards

    func test_pauseTask_pausesAllRunningSubtasks() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0])

        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)
        vm.pauseTask(vm.todos[0].id, keepWindowOpen: false)

        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
        XCTAssertNil(vm.todos[0].subtasks[0].lastStartTime)
    }

    func test_toggleTimer_pause_pausesAllRunningSubtasks() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0]) // start
        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)

        vm.toggleTimer(vm.todos[0]) // pause
        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
    }

    func test_switchToTask_pausesAllRunningSubtasks() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        let taskA = makeTodo(text: "A", subtasks: [sub])
        let taskB = makeTodo(text: "B")
        vm.todos = [taskA, taskB]

        vm.toggleTimer(vm.todos[0])
        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)

        vm.switchToTask(vm.todos[1])
        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
    }

    func test_completeTaskFromFloatingWindow_pausesAllRunningSubtasks() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0])

        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)
        vm.completeTaskFromFloatingWindow(vm.todos[0].id)

        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
    }

    func test_toggleTodo_complete_pausesAllRunningSubtasks() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0])

        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)
        vm.toggleTodo(vm.todos[0])

        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
    }

    func test_pauseRunningTaskForTermination_pausesAllRunningSubtasks() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0])

        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)

        // Trigger via the termination notification path
        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)

        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
    }

    // MARK: - Cycle 2: toggleSubtaskTimerFromFloatingWindow parent-running guard

    func test_toggleSubtaskTimerFromFloatingWindow_doesNothing_whenParentNotRunning() {
        let (vm, _, _) = makeViewModel()
        let s1 = makeSubtask(title: "S1")
        let taskA = makeTodo(text: "A", subtasks: [s1])
        vm.todos = [taskA]

        // Do NOT start parent
        vm.toggleSubtaskTimerFromFloatingWindow(s1.id, in: taskA.id)

        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
        XCTAssertNil(vm.todos[0].subtasks[0].lastStartTime)
        XCTAssertTrue(vm.todos[0].subtasks[0].sessions.isEmpty)
    }

    func test_toggleSubtaskTimerFromFloatingWindow_pausesRunningSubtask_whenParentRunning() {
        let (vm, _, _) = makeViewModel()
        let s1 = makeSubtask(title: "S1")
        let taskA = makeTodo(text: "A", subtasks: [s1])
        vm.todos = [taskA]

        // Start parent — auto-starts s1
        vm.toggleTimer(vm.todos[0])
        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)

        // Toggle s1 again to pause it via the floating window entrypoint
        vm.toggleSubtaskTimerFromFloatingWindow(vm.todos[0].subtasks[0].id, in: taskA.id)
        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
    }
}
