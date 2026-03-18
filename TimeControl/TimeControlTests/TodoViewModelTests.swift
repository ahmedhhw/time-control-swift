//
//  TodoViewModelTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class TodoViewModelTests: XCTestCase {

    // MARK: - Task lifecycle

    func testAddTodo_appendsToTodos() {
        let (vm, _) = makeViewModel()
        vm.newTodoText = "Write report"
        vm.addTodo()
        XCTAssertEqual(vm.todos.count, 1)
        XCTAssertEqual(vm.todos[0].text, "Write report")
        XCTAssertTrue(vm.newTodoText.isEmpty)
    }

    func testAddTodo_emptyText_doesNotAdd() {
        let (vm, _) = makeViewModel()
        vm.newTodoText = "   "
        vm.addTodo()
        XCTAssertTrue(vm.todos.isEmpty)
    }

    func testToggleTodo_completesTask_andStopsTimer() {
        let (vm, _) = makeViewModel()
        vm.newTodoText = "Task"
        vm.addTodo()
        vm.toggleTimer(vm.todos[0])
        vm.toggleTodo(vm.todos[0])
        XCTAssertTrue(vm.todos[0].isCompleted)
        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertNotNil(vm.todos[0].completedAt)
    }

    func testDeleteTodo_removesFromList() {
        let (vm, _) = makeViewModel()
        vm.confirmTaskDeletion = false
        vm.todos = [makeTodo(text: "Task")]
        let todo = vm.todos[0]
        vm.deleteTodo(todo)
        XCTAssertTrue(vm.todos.isEmpty)
    }

    // MARK: - Timer — single task enforcement

    func testToggleTimer_onlyOneTaskRunsAtATime() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]

        vm.toggleTimer(vm.todos[0])
        XCTAssertTrue(vm.todos[0].isRunning)
        XCTAssertFalse(vm.todos[1].isRunning)

        vm.toggleTimer(vm.todos[1])
        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertTrue(vm.todos[1].isRunning)
    }

    func testToggleTimer_pause_stopsTimer() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]
        vm.toggleTimer(vm.todos[0])
        vm.toggleTimer(vm.todos[0]) // pause
        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertNil(vm.runningTaskId)
    }

    func testToggleTimer_setsStartedAt_onFirstStart() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]
        XCTAssertNil(vm.todos[0].startedAt)
        vm.toggleTimer(vm.todos[0])
        XCTAssertNotNil(vm.todos[0].startedAt)
    }

    func testToggleTimer_doesNotOverwriteStartedAt_onResume() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]
        vm.toggleTimer(vm.todos[0])
        let firstStart = vm.todos[0].startedAt
        vm.toggleTimer(vm.todos[0]) // pause
        vm.toggleTimer(vm.todos[0]) // resume
        XCTAssertEqual(vm.todos[0].startedAt, firstStart)
    }

    // MARK: - Subtask auto-start

    func testToggleSubtask_completing_autoStartsNextIncomplete() {
        let (vm, _) = makeViewModel()
        let sub1 = makeSubtask(title: "First")
        let sub2 = makeSubtask(title: "Second")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2])]

        vm.toggleTimer(vm.todos[0])
        // auto-start moves the first incomplete subtask (sub1) to the top and starts it
        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.toggleSubtask(runningSub, in: vm.todos[0])

        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == sub2.id })!.isRunning)
    }

    func testToggleSubtask_completing_pausesItsTimer() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.toggleTimer(vm.todos[0])
        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        XCTAssertTrue(runningSub.isRunning)

        vm.toggleSubtask(runningSub, in: vm.todos[0])
        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == sub.id })!.isRunning)
    }

    func testToggleSubtaskTimer_requiresParentRunning() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        // parent NOT started
        vm.toggleSubtaskTimer(sub, in: vm.todos[0])
        XCTAssertFalse(vm.todos[0].subtasks[0].isRunning)
    }

    func testToggleSubtaskTimer_onlyOneSubtaskRunsAtATime() {
        let (vm, _) = makeViewModel()
        let sub1 = makeSubtask(title: "A")
        let sub2 = makeSubtask(title: "B")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2])]

        vm.toggleTimer(vm.todos[0])         // sub1 auto-starts
        vm.toggleSubtaskTimer(sub2, in: vm.todos[0])  // stops sub1, starts sub2

        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == sub1.id })!.isRunning)
        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == sub2.id })!.isRunning)
    }

    // MARK: - Subtask ordering

    func testCompletedSubtasks_movedToTopOfCompletedBlock() {
        let (vm, _) = makeViewModel()
        let subA = makeSubtask(title: "A")
        let subB = makeSubtask(title: "B")
        let subC = makeSubtask(title: "C")
        vm.todos = [makeTodo(text: "Parent", subtasks: [subA, subB, subC])]

        vm.toggleTimer(vm.todos[0]) // auto-starts first incomplete
        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.toggleSubtask(runningSub, in: vm.todos[0])

        // Completed subtask should be at index 0 (before all incomplete ones)
        XCTAssertTrue(vm.todos[0].subtasks[0].isCompleted)
        XCTAssertFalse(vm.todos[0].subtasks[1].isCompleted)
        XCTAssertFalse(vm.todos[0].subtasks[2].isCompleted)
    }

    func testStartedSubtasks_movedToTopOfIncompleteList() {
        let (vm, _) = makeViewModel()
        let subA = makeSubtask(title: "A")
        let subB = makeSubtask(title: "B")
        let subC = makeSubtask(title: "C")
        vm.todos = [makeTodo(text: "Parent", subtasks: [subA, subB, subC])]

        vm.toggleTimer(vm.todos[0])                         // auto-starts subA (already at top)
        vm.toggleSubtaskTimer(subC, in: vm.todos[0])        // stops subA, starts subC → moves subC to top

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "C") // subC is now first
        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)
    }

    // MARK: - switchToTask

    func testSwitchToTask_stopsCurrentTask() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
        vm.toggleTimer(vm.todos[0])
        vm.switchToTask(vm.todos[1])
        XCTAssertFalse(vm.todos[0].isRunning)
    }

    func testSwitchToTask_autoPlays_whenSettingEnabled() {
        let (vm, _) = makeViewModel()
        vm.autoPlayAfterSwitching = true
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
        vm.toggleTimer(vm.todos[0])
        vm.switchToTask(vm.todos[1])
        XCTAssertTrue(vm.todos[1].isRunning)
    }

    func testSwitchToTask_doesNotAutoPlay_whenSettingDisabled() {
        let (vm, _) = makeViewModel()
        vm.autoPlayAfterSwitching = false
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
        vm.toggleTimer(vm.todos[0])
        vm.switchToTask(vm.todos[1])
        XCTAssertFalse(vm.todos[1].isRunning)
    }

    // MARK: - Persistence round-trip

    func testSaveTodos_persistsAndLoadsCorrectly() {
        let (vm, url) = makeViewModel()
        vm.newTodoText = "Persisted task"
        vm.addTodo() // addTodo calls saveTodos internally

        let vm2 = TodoViewModel(storageURL: url)
        XCTAssertEqual(vm2.todos.count, 1)
        XCTAssertEqual(vm2.todos[0].text, "Persisted task")
    }

    // MARK: - Field updates

    func testUpdateTaskFields_updatesTitleAndNotes() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Old")]
        let id = vm.todos[0].id
        vm.updateTaskFields(id: id, text: "New", description: nil, notes: "my note",
                            dueDate: nil, isAdhoc: nil, fromWho: nil, estimatedTime: nil)
        XCTAssertEqual(vm.todos[0].text, "New")
        XCTAssertEqual(vm.todos[0].notes, "my note")
    }

    // MARK: - Countdown

    func testSetCountdown_storesCountdownTime() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let id = vm.todos[0].id
        vm.setCountdown(taskId: id, time: 300)
        XCTAssertEqual(vm.todos[0].countdownTime, 300)
        XCTAssertNotNil(vm.todos[0].countdownStartTime)
    }

    func testClearCountdown_removesCountdownTime() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        let id = vm.todos[0].id
        vm.setCountdown(taskId: id, time: 300)
        vm.clearCountdown(taskId: id)
        XCTAssertEqual(vm.todos[0].countdownTime, 0)
        XCTAssertNil(vm.todos[0].countdownStartTime)
    }

    // MARK: - Reordering

    func testMoveTodo_updatesIndexOrder() {
        let (vm, _) = makeViewModel()
        vm.todos = [
            TodoItem(text: "A", index: 0),
            TodoItem(text: "B", index: 1),
            TodoItem(text: "C", index: 2)
        ]
        vm.moveTodo(from: 0, to: 2)
        XCTAssertEqual(vm.todos[0].text, "B")
        XCTAssertEqual(vm.todos[1].text, "C")
        XCTAssertEqual(vm.todos[2].text, "A")
        XCTAssertEqual(vm.todos[0].index, 0)
        XCTAssertEqual(vm.todos[1].index, 1)
        XCTAssertEqual(vm.todos[2].index, 2)
    }
}
