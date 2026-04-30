//
//  PauseBeforeDeleteTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class PauseBeforeDeleteTests: XCTestCase {

    // MARK: - Cycle 3: pause-before-delete

    func test_performDeleteTodo_pausesRunningSubtasks_beforeRemoving() {
        let (vm, _, _) = makeViewModel()
        vm.confirmTaskDeletion = false
        let s1 = makeSubtask(title: "S1")
        let s2 = makeSubtask(title: "S2")
        let taskA = makeTodo(text: "A", subtasks: [s1, s2])
        vm.todos = [taskA]

        // Start A — auto-starts s1
        vm.toggleTimer(vm.todos[0])
        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)

        // Delete task A
        vm.deleteTodo(vm.todos[0])

        XCTAssertNil(vm.runningTaskId)
        XCTAssertTrue(vm.todos.isEmpty)
    }

    func test_performDeleteSubtask_pausesRunningSubtask_beforeRemoving() {
        let (vm, _, _) = makeViewModel()
        vm.confirmSubtaskDeletion = false
        let s1 = makeSubtask(title: "S1")
        vm.todos = [makeTodo(text: "Parent", subtasks: [s1])]

        // Start parent — auto-starts s1
        vm.toggleTimer(vm.todos[0])
        let runningSubId = vm.todos[0].subtasks.first(where: { $0.isRunning })!.id

        // Delete s1 while it's running
        let parentCopy = vm.todos[0]
        let subCopy = vm.todos[0].subtasks.first(where: { $0.id == runningSubId })!
        vm.deleteSubtask(subCopy, from: parentCopy)

        // Subtask should be gone
        XCTAssertTrue(vm.todos[0].subtasks.isEmpty)
        // Parent task should still be running
        XCTAssertTrue(vm.todos[0].isRunning)
        // Parent's running session should still be open (stoppedAt == nil)
        XCTAssertNotNil(vm.todos[0].sessions.last)
        XCTAssertNil(vm.todos[0].sessions.last?.stoppedAt)
    }

    func test_deleteSubtaskFromFloatingWindow_pausesRunningSubtask_beforeRemoving() {
        let (vm, _, _) = makeViewModel()
        let s1 = makeSubtask(title: "S1")
        vm.todos = [makeTodo(text: "Parent", subtasks: [s1])]

        // Start parent — auto-starts s1
        vm.toggleTimer(vm.todos[0])
        let runningSubId = vm.todos[0].subtasks.first(where: { $0.isRunning })!.id
        let parentId = vm.todos[0].id

        // Delete via floating window entrypoint
        vm.deleteSubtaskFromFloatingWindow(runningSubId, from: parentId)

        XCTAssertTrue(vm.todos[0].subtasks.isEmpty)
        // Parent task should still be running
        XCTAssertTrue(vm.todos[0].isRunning)
        // Parent session still open
        XCTAssertNil(vm.todos[0].sessions.last?.stoppedAt)
    }
}
