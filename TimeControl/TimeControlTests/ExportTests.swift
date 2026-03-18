//
//  ExportTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class ExportTests: XCTestCase {

    // MARK: - generateExportTextForTask

    func testExportTask_containsTitle() {
        let (vm, _) = makeViewModel()
        let todo = makeTodo(text: "Write documentation")
        let output = vm.generateExportTextForTask(todo)
        XCTAssertTrue(output.contains("Write documentation"))
    }

    func testExportTask_incompleteStatus() {
        let (vm, _) = makeViewModel()
        let todo = makeTodo(text: "Task", isCompleted: false)
        let output = vm.generateExportTextForTask(todo)
        XCTAssertTrue(output.contains("Incomplete"))
    }

    func testExportTask_completedStatus() {
        let (vm, _) = makeViewModel()
        var todo = makeTodo(text: "Task")
        todo.isCompleted = true
        let output = vm.generateExportTextForTask(todo)
        XCTAssertTrue(output.contains("Completed"))
    }

    func testExportTask_containsSubtaskTitles() {
        let (vm, _) = makeViewModel()
        let sub1 = makeSubtask(title: "Research")
        let sub2 = makeSubtask(title: "Write draft", isCompleted: true)
        let todo = makeTodo(text: "Project", subtasks: [sub1, sub2])
        let output = vm.generateExportTextForTask(todo)
        XCTAssertTrue(output.contains("Research"))
        XCTAssertTrue(output.contains("Write draft"))
    }

    func testExportTask_subtaskCompletionMarkers() {
        let (vm, _) = makeViewModel()
        let incomplete = makeSubtask(title: "Pending", isCompleted: false)
        let complete = makeSubtask(title: "Done", isCompleted: true)
        let todo = makeTodo(text: "Task", subtasks: [incomplete, complete])
        let output = vm.generateExportTextForTask(todo)
        XCTAssertTrue(output.contains("○ Pending"))
        XCTAssertTrue(output.contains("✓ Done"))
    }

    func testExportTask_containsNotes() {
        let (vm, _) = makeViewModel()
        var todo = makeTodo(text: "Task")
        todo.notes = "Remember to follow up with Alice"
        let output = vm.generateExportTextForTask(todo)
        XCTAssertTrue(output.contains("Remember to follow up with Alice"))
    }

    func testExportTask_containsDescription() {
        let (vm, _) = makeViewModel()
        var todo = makeTodo(text: "Task")
        todo.description = "Detailed description here"
        let output = vm.generateExportTextForTask(todo)
        XCTAssertTrue(output.contains("Detailed description here"))
    }

    func testExportTask_containsFromWho() {
        let (vm, _) = makeViewModel()
        var todo = makeTodo(text: "Task")
        todo.fromWho = "Manager Bob"
        let output = vm.generateExportTextForTask(todo)
        XCTAssertTrue(output.contains("Manager Bob"))
    }

    func testExportTask_noSubtasks_doesNotCrash() {
        let (vm, _) = makeViewModel()
        let todo = makeTodo(text: "Solo task")
        let output = vm.generateExportTextForTask(todo)
        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(output.contains("Solo task"))
    }

    func testExportTask_withEstimatedTime_showsProgress() {
        let (vm, _) = makeViewModel()
        let todo = makeTodo(text: "Task", estimatedTime: 3600)
        let output = vm.generateExportTextForTask(todo)
        XCTAssertTrue(output.contains("Estimated"))
        XCTAssertTrue(output.contains("Progress"))
    }

    func testExportTask_noOptionalFields_omitsEmptySections() {
        let (vm, _) = makeViewModel()
        let todo = makeTodo(text: "Bare task")
        let output = vm.generateExportTextForTask(todo)
        XCTAssertFalse(output.contains("From:"))
        XCTAssertFalse(output.contains("Notes:"))
        XCTAssertFalse(output.contains("Description:"))
        XCTAssertFalse(output.contains("Subtasks"))
    }

    // MARK: - generateExportTextForAllTasks

    func testExportAllTasks_containsHeader() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A")]
        let output = vm.generateExportTextForAllTasks()
        XCTAssertTrue(output.contains("TASKS EXPORT"))
    }

    func testExportAllTasks_containsSummarySection() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "A"), makeTodo(text: "B")]
        let output = vm.generateExportTextForAllTasks()
        XCTAssertTrue(output.contains("Total tasks: 2"))
        XCTAssertTrue(output.contains("Incomplete: 2"))
    }

    func testExportAllTasks_containsAllTitles() {
        let (vm, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Alpha"), makeTodo(text: "Beta"), makeTodo(text: "Gamma")]
        let output = vm.generateExportTextForAllTasks()
        XCTAssertTrue(output.contains("Alpha"))
        XCTAssertTrue(output.contains("Beta"))
        XCTAssertTrue(output.contains("Gamma"))
    }

    func testExportAllTasks_separatesIncompleteAndCompleted() {
        let (vm, _) = makeViewModel()
        var completed = makeTodo(text: "Done Task")
        completed.isCompleted = true
        let incomplete = makeTodo(text: "Pending Task")
        vm.todos = [incomplete, completed]
        let output = vm.generateExportTextForAllTasks()
        XCTAssertTrue(output.contains("INCOMPLETE TASKS"))
        XCTAssertTrue(output.contains("COMPLETED TASKS"))
        XCTAssertTrue(output.contains("Completed: 1"))
        XCTAssertTrue(output.contains("Incomplete: 1"))
    }

    func testExportAllTasks_emptyList_returnsHeaderOnly() {
        let (vm, _) = makeViewModel()
        vm.todos = []
        let output = vm.generateExportTextForAllTasks()
        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(output.contains("TASKS EXPORT"))
        XCTAssertTrue(output.contains("Total tasks: 0"))
        XCTAssertFalse(output.contains("INCOMPLETE TASKS"))
        XCTAssertFalse(output.contains("COMPLETED TASKS"))
    }

    func testExportAllTasks_allCompleted_noIncompleteSection() {
        let (vm, _) = makeViewModel()
        var t = makeTodo(text: "Finished")
        t.isCompleted = true
        vm.todos = [t]
        let output = vm.generateExportTextForAllTasks()
        XCTAssertTrue(output.contains("COMPLETED TASKS"))
        XCTAssertFalse(output.contains("INCOMPLETE TASKS"))
    }
}
