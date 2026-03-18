//
//  FloatingWindowOperationsTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class FloatingWindowOperationsTests: XCTestCase {

    // MARK: - toggleSubtaskFromFloatingWindow

    func testToggleSubtaskFromFloatingWindow_completesSubtask() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.toggleSubtaskFromFloatingWindow(sub.id, in: vm.todos[0].id)

        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == sub.id })!.isCompleted)
    }

    func testToggleSubtaskFromFloatingWindow_uncompletes_alreadyCompletedSubtask() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Done", isCompleted: true)
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.toggleSubtaskFromFloatingWindow(sub.id, in: vm.todos[0].id)

        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == sub.id })!.isCompleted)
    }

    func testToggleSubtaskFromFloatingWindow_completing_pausesRunningSubtask() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0]) // starts parent + auto-starts sub

        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.toggleSubtaskFromFloatingWindow(runningSub.id, in: vm.todos[0].id)

        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == runningSub.id })!.isRunning)
        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == runningSub.id })!.isCompleted)
    }

    func testToggleSubtaskFromFloatingWindow_completing_autoStartsNextIncomplete() {
        let (vm, _) = makeViewModel()
        let sub1 = makeSubtask(title: "First")
        let sub2 = makeSubtask(title: "Second")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2])]
        vm.toggleTimer(vm.todos[0])

        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.toggleSubtaskFromFloatingWindow(runningSub.id, in: vm.todos[0].id)

        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == sub2.id })!.isRunning)
    }

    func testToggleSubtaskFromFloatingWindow_completedSubtask_movedBeforeIncomplete() {
        let (vm, _) = makeViewModel()
        let sub1 = makeSubtask(title: "A")
        let sub2 = makeSubtask(title: "B")
        let sub3 = makeSubtask(title: "C")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2, sub3])]
        vm.toggleTimer(vm.todos[0])

        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.toggleSubtaskFromFloatingWindow(runningSub.id, in: vm.todos[0].id)

        XCTAssertTrue(vm.todos[0].subtasks[0].isCompleted)
        XCTAssertFalse(vm.todos[0].subtasks[1].isCompleted)
        XCTAssertFalse(vm.todos[0].subtasks[2].isCompleted)
    }

    func testToggleSubtaskFromFloatingWindow_unknownSubtaskId_doesNotCrash() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Parent")]

        // Should return early — no crash, no state change
        vm.toggleSubtaskFromFloatingWindow(UUID(), in: vm.todos[0].id)

        XCTAssertTrue(vm.todos[0].subtasks.isEmpty)
    }

    // MARK: - addSubtaskFromFloatingWindow

    func testAddSubtaskFromFloatingWindow_appendsSubtask() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Parent")]

        vm.addSubtaskFromFloatingWindow(to: vm.todos[0].id, title: "New Sub")

        XCTAssertEqual(vm.todos[0].subtasks.count, 1)
        XCTAssertEqual(vm.todos[0].subtasks[0].title, "New Sub")
    }

    func testAddSubtaskFromFloatingWindow_titleMatches() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Parent")]

        vm.addSubtaskFromFloatingWindow(to: vm.todos[0].id, title: "Exact Title")

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "Exact Title")
    }

    func testAddSubtaskFromFloatingWindow_multipleSubtasks_eachAppended() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Parent")]
        let id = vm.todos[0].id

        vm.addSubtaskFromFloatingWindow(to: id, title: "First")
        vm.addSubtaskFromFloatingWindow(to: id, title: "Second")

        XCTAssertEqual(vm.todos[0].subtasks.count, 2)
        XCTAssertEqual(vm.todos[0].subtasks[0].title, "First")
        XCTAssertEqual(vm.todos[0].subtasks[1].title, "Second")
    }

    func testAddSubtaskFromFloatingWindow_whenParentRunning_andNoIncompleteSubtasks_autoStartsNewSub() {
        let (vm, _) = makeViewModel()
        let completedSub = makeSubtask(title: "Done", isCompleted: true)
        vm.todos = [makeTodo(text: "Parent", subtasks: [completedSub])]
        vm.toggleTimer(vm.todos[0])

        vm.addSubtaskFromFloatingWindow(to: vm.todos[0].id, title: "Fresh Sub")

        let freshSub = vm.todos[0].subtasks.first(where: { $0.title == "Fresh Sub" })!
        XCTAssertTrue(freshSub.isRunning)
    }

    func testAddSubtaskFromFloatingWindow_whenParentRunning_withExistingIncomplete_doesNotAutoStartNewSub() {
        let (vm, _) = makeViewModel()
        let existingSub = makeSubtask(title: "Existing")
        vm.todos = [makeTodo(text: "Parent", subtasks: [existingSub])]
        vm.toggleTimer(vm.todos[0]) // auto-starts existingSub

        vm.addSubtaskFromFloatingWindow(to: vm.todos[0].id, title: "Second Sub")

        let secondSub = vm.todos[0].subtasks.first(where: { $0.title == "Second Sub" })!
        XCTAssertFalse(secondSub.isRunning)
    }

    func testAddSubtaskFromFloatingWindow_unknownTaskId_doesNotCrash() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Parent")]

        vm.addSubtaskFromFloatingWindow(to: UUID(), title: "Orphan")

        // The orphan should not appear anywhere
        XCTAssertTrue(vm.todos[0].subtasks.isEmpty)
    }

    // MARK: - deleteSubtaskFromFloatingWindow

    func testDeleteSubtaskFromFloatingWindow_removesSubtask() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Remove Me")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.deleteSubtaskFromFloatingWindow(sub.id, from: vm.todos[0].id)

        XCTAssertTrue(vm.todos[0].subtasks.isEmpty)
    }

    func testDeleteSubtaskFromFloatingWindow_onlyRemovesTargetSubtask() {
        let (vm, _) = makeViewModel()
        let sub1 = makeSubtask(title: "Keep")
        let sub2 = makeSubtask(title: "Delete Me")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2])]

        vm.deleteSubtaskFromFloatingWindow(sub2.id, from: vm.todos[0].id)

        XCTAssertEqual(vm.todos[0].subtasks.count, 1)
        XCTAssertEqual(vm.todos[0].subtasks[0].title, "Keep")
    }

    func testDeleteSubtaskFromFloatingWindow_runningSubtask_removedWithoutDanglingState() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Running Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0]) // auto-starts sub

        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.deleteSubtaskFromFloatingWindow(runningSub.id, from: vm.todos[0].id)

        XCTAssertTrue(vm.todos[0].subtasks.isEmpty)
        // Parent task should still be running
        XCTAssertTrue(vm.todos[0].isRunning)
    }

    func testDeleteSubtaskFromFloatingWindow_unknownSubtaskId_doesNotAlterList() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Keep")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.deleteSubtaskFromFloatingWindow(UUID(), from: vm.todos[0].id)

        XCTAssertEqual(vm.todos[0].subtasks.count, 1)
    }

    // MARK: - toggleSubtaskTimerFromFloatingWindow

    func testToggleSubtaskTimerFromFloatingWindow_startsSubtask_whenNotRunning() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0]) // start parent

        // Pause the auto-started subtask first so we can test starting explicitly
        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.toggleSubtaskTimerFromFloatingWindow(runningSub.id, in: vm.todos[0].id) // pause it
        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == runningSub.id })!.isRunning)

        vm.toggleSubtaskTimerFromFloatingWindow(runningSub.id, in: vm.todos[0].id) // start again
        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == runningSub.id })!.isRunning)
    }

    func testToggleSubtaskTimerFromFloatingWindow_pausesSubtask_whenRunning() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0])

        let runningSub = vm.todos[0].subtasks.first(where: { $0.isRunning })!
        vm.toggleSubtaskTimerFromFloatingWindow(runningSub.id, in: vm.todos[0].id)

        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == runningSub.id })!.isRunning)
    }

    func testToggleSubtaskTimerFromFloatingWindow_onlyOneSubtaskRunsAtATime() {
        let (vm, _) = makeViewModel()
        let sub1 = makeSubtask(title: "A")
        let sub2 = makeSubtask(title: "B")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2])]
        vm.toggleTimer(vm.todos[0]) // sub1 auto-starts

        vm.toggleSubtaskTimerFromFloatingWindow(sub2.id, in: vm.todos[0].id)

        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == sub1.id })!.isRunning)
        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == sub2.id })!.isRunning)
    }

    func testToggleSubtaskTimerFromFloatingWindow_startedSubtask_movedToTopOfIncompleteList() {
        let (vm, _) = makeViewModel()
        let sub1 = makeSubtask(title: "A")
        let sub2 = makeSubtask(title: "B")
        let sub3 = makeSubtask(title: "C")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub1, sub2, sub3])]
        vm.toggleTimer(vm.todos[0]) // sub1 auto-starts

        vm.toggleSubtaskTimerFromFloatingWindow(sub3.id, in: vm.todos[0].id)

        // sub3 should now be first (moved to top of incomplete list)
        XCTAssertEqual(vm.todos[0].subtasks[0].id, sub3.id)
        XCTAssertTrue(vm.todos[0].subtasks[0].isRunning)
    }

    // MARK: - renameSubtaskFromFloatingWindow

    func testRenameSubtaskFromFloatingWindow_happyPath() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Old")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.renameSubtaskFromFloatingWindow(sub.id, in: vm.todos[0].id, newTitle: "New")

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "New")
    }

    func testRenameSubtaskFromFloatingWindow_whitespaceTrimmed() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Original")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.renameSubtaskFromFloatingWindow(sub.id, in: vm.todos[0].id, newTitle: "  Padded  ")

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "Padded")
    }

    func testRenameSubtaskFromFloatingWindow_whitespaceOnly_doesNotRename() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Keep This")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.renameSubtaskFromFloatingWindow(sub.id, in: vm.todos[0].id, newTitle: "   ")

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "Keep This")
    }

    func testRenameSubtaskFromFloatingWindow_emptyString_doesNotRename() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Stays")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.renameSubtaskFromFloatingWindow(sub.id, in: vm.todos[0].id, newTitle: "")

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "Stays")
    }

    func testRenameSubtaskFromFloatingWindow_unknownSubtaskId_doesNotAlterOtherSubtasks() {
        let (vm, _) = makeViewModel()
        let sub = makeSubtask(title: "Untouched")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]

        vm.renameSubtaskFromFloatingWindow(UUID(), in: vm.todos[0].id, newTitle: "Should Not Apply")

        XCTAssertEqual(vm.todos[0].subtasks[0].title, "Untouched")
    }
}
