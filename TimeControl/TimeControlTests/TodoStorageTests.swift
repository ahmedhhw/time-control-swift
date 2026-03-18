//
//  TodoStorageTests.swift
//  TimeControlTests
//
//  Created on 2/11/26.
//

import XCTest
@testable import TimeControl

final class TodoStorageTests: XCTestCase {

    var testStorageURL: URL!

    override func setUp() {
        super.setUp()
        // Use a temporary test file
        let tempDir = FileManager.default.temporaryDirectory
        testStorageURL = tempDir.appendingPathComponent("test_todos_\(UUID().uuidString).json")
    }

    override func tearDown() {
        // Clean up test file
        if FileManager.default.fileExists(atPath: testStorageURL.path) {
            try? FileManager.default.removeItem(at: testStorageURL)
        }
        super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveEmptyTodos() {
        let todos: [TodoItem] = []

        // This test verifies the method doesn't crash with empty array
        TodoStorage.save(todos: todos, notificationRecords: [], to: testStorageURL)

        // No assertion needed, just verify it doesn't crash
    }

    func testSaveSingleTodo() {
        let todo = TodoItem(text: "Test Todo", index: 0)

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)

        // Verify file was created by loading it back
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos
        XCTAssertEqual(loadedTodos.count, 1)
        XCTAssertEqual(loadedTodos.first?.text, "Test Todo")
    }

    func testSaveMultipleTodos() {
        let todos = [
            TodoItem(text: "Todo 1", index: 0),
            TodoItem(text: "Todo 2", index: 1),
            TodoItem(text: "Todo 3", index: 2)
        ]

        TodoStorage.save(todos: todos, notificationRecords: [], to: testStorageURL)

        let loadedTodos = TodoStorage.load(from: testStorageURL).todos
        XCTAssertEqual(loadedTodos.count, 3)
    }

    func testSaveTodoWithAllProperties() {
        let dueDate = Date(timeIntervalSince1970: 1000000)
        let subtasks = [
            Subtask(title: "Subtask 1", description: "Desc 1", isCompleted: false),
            Subtask(title: "Subtask 2", description: "Desc 2", isCompleted: true)
        ]

        let todo = TodoItem(
            text: "Complete Todo",
            isCompleted: false,
            index: 0,
            totalTimeSpent: 3600,
            lastStartTime: Date(timeIntervalSince1970: 2000000),
            description: "Detailed description",
            dueDate: dueDate,
            isAdhoc: true,
            fromWho: "Manager",
            estimatedTime: 7200,
            subtasks: subtasks,
            createdAt: 500000,
            startedAt: 600000,
            notes: "Some notes"
        )

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)

        let loadedTodos = TodoStorage.load(from: testStorageURL).todos
        XCTAssertEqual(loadedTodos.count, 1)

        let loadedTodo = loadedTodos.first!
        XCTAssertEqual(loadedTodo.text, "Complete Todo")
        XCTAssertEqual(loadedTodo.isCompleted, false)
        XCTAssertEqual(loadedTodo.totalTimeSpent, 3600)
        XCTAssertEqual(loadedTodo.description, "Detailed description")
        XCTAssertNotNil(loadedTodo.dueDate)
        XCTAssertTrue(loadedTodo.isAdhoc)
        XCTAssertEqual(loadedTodo.fromWho, "Manager")
        XCTAssertEqual(loadedTodo.estimatedTime, 7200)
        XCTAssertEqual(loadedTodo.subtasks.count, 2)
        XCTAssertEqual(loadedTodo.createdAt, 500000)
        XCTAssertEqual(loadedTodo.startedAt, 600000)
        XCTAssertEqual(loadedTodo.notes, "Some notes")
    }

    // MARK: - Load Tests

    func testLoadWhenFileDoesNotExist() {
        // testStorageURL is always a fresh temp path that has never been written to
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        // Should return empty array when file doesn't exist
        XCTAssertTrue(loadedTodos.isEmpty)
    }

    func testLoadPreservesOrder() {
        let todos = [
            TodoItem(text: "Todo 1", index: 0),
            TodoItem(text: "Todo 2", index: 1),
            TodoItem(text: "Todo 3", index: 2)
        ]

        TodoStorage.save(todos: todos, notificationRecords: [], to: testStorageURL)
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        XCTAssertEqual(loadedTodos.count, 3)
        XCTAssertEqual(loadedTodos[0].text, "Todo 1")
        XCTAssertEqual(loadedTodos[1].text, "Todo 2")
        XCTAssertEqual(loadedTodos[2].text, "Todo 3")
    }

    func testLoadPreservesOrderEvenIfSavedOutOfOrder() {
        let todos = [
            TodoItem(text: "Todo C", index: 2),
            TodoItem(text: "Todo A", index: 0),
            TodoItem(text: "Todo B", index: 1)
        ]

        TodoStorage.save(todos: todos, notificationRecords: [], to: testStorageURL)
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        // Should be sorted by index
        XCTAssertEqual(loadedTodos[0].text, "Todo A")
        XCTAssertEqual(loadedTodos[1].text, "Todo B")
        XCTAssertEqual(loadedTodos[2].text, "Todo C")
    }

    // MARK: - Subtask Persistence Tests

    func testSaveAndLoadSubtasks() {
        let subtask1 = Subtask(title: "Subtask 1", description: "Description 1", isCompleted: false)
        let subtask2 = Subtask(title: "Subtask 2", description: "Description 2", isCompleted: true)

        let todo = TodoItem(text: "Parent Todo", index: 0, subtasks: [subtask1, subtask2])

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        XCTAssertEqual(loadedTodos.first?.subtasks.count, 2)
        XCTAssertEqual(loadedTodos.first?.subtasks[0].title, "Subtask 1")
        XCTAssertEqual(loadedTodos.first?.subtasks[0].description, "Description 1")
        XCTAssertFalse(loadedTodos.first?.subtasks[0].isCompleted ?? true)
        XCTAssertEqual(loadedTodos.first?.subtasks[1].title, "Subtask 2")
        XCTAssertTrue(loadedTodos.first?.subtasks[1].isCompleted ?? false)
    }

    func testSubtaskIdPersistence() {
        let subtaskId = UUID()
        let subtask = Subtask(id: subtaskId, title: "Test Subtask")
        let todo = TodoItem(text: "Parent Todo", index: 0, subtasks: [subtask])

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        XCTAssertEqual(loadedTodos.first?.subtasks.first?.id, subtaskId)
    }

    // MARK: - Timestamp Persistence Tests

    func testCreatedAtPersistence() {
        let createdAt: TimeInterval = 1000000
        let todo = TodoItem(text: "Test", index: 0, createdAt: createdAt)

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        XCTAssertEqual(loadedTodos.first?.createdAt, createdAt)
    }

    func testStartedAtPersistence() {
        let startedAt: TimeInterval = 2000000
        var todo = TodoItem(text: "Test", index: 0)
        todo.startedAt = startedAt

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        XCTAssertEqual(loadedTodos.first?.startedAt, startedAt)
    }

    func testCompletedAtPersistence() {
        let completedAt: TimeInterval = 3000000
        var todo = TodoItem(text: "Test", index: 0)
        todo.completedAt = completedAt

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        XCTAssertEqual(loadedTodos.first?.completedAt, completedAt)
    }

    func testNilTimestampsPersistence() {
        let todo = TodoItem(text: "Test", index: 0)

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        XCTAssertNil(loadedTodos.first?.startedAt)
        XCTAssertNil(loadedTodos.first?.completedAt)
    }

    // MARK: - Date Persistence Tests

    func testDueDatePersistence() {
        let dueDate = Date(timeIntervalSince1970: 5000000)
        let todo = TodoItem(text: "Test", index: 0, dueDate: dueDate)

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        XCTAssertNotNil(loadedTodos.first?.dueDate)
        if let loadedDueDate = loadedTodos.first?.dueDate {
            XCTAssertEqual(loadedDueDate.timeIntervalSince1970, dueDate.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("Due date should not be nil")
        }
    }

    func testLastStartTimePersistence() {
        let lastStartTime = Date(timeIntervalSince1970: 6000000)
        var todo = TodoItem(text: "Test", index: 0)
        todo.lastStartTime = lastStartTime

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loadedTodos = TodoStorage.load(from: testStorageURL).todos

        XCTAssertNotNil(loadedTodos.first?.lastStartTime)
        if let loadedLastStartTime = loadedTodos.first?.lastStartTime {
            XCTAssertEqual(loadedLastStartTime.timeIntervalSince1970, lastStartTime.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("Last start time should not be nil")
        }
    }

    // MARK: - Save/Load Cycle Tests

    func testMultipleSaveLoadCycles() {
        // First cycle
        let todos1 = [TodoItem(text: "Todo 1", index: 0)]
        TodoStorage.save(todos: todos1, notificationRecords: [], to: testStorageURL)
        let loaded1 = TodoStorage.load(from: testStorageURL).todos
        XCTAssertEqual(loaded1.count, 1)

        // Second cycle - overwrite
        let todos2 = [
            TodoItem(text: "Todo A", index: 0),
            TodoItem(text: "Todo B", index: 1)
        ]
        TodoStorage.save(todos: todos2, notificationRecords: [], to: testStorageURL)
        let loaded2 = TodoStorage.load(from: testStorageURL).todos
        XCTAssertEqual(loaded2.count, 2)
        XCTAssertEqual(loaded2[0].text, "Todo A")
    }

    func testOverwritingExistingData() {
        let original = [TodoItem(text: "Original", index: 0)]
        TodoStorage.save(todos: original, notificationRecords: [], to: testStorageURL)

        let updated = [TodoItem(text: "Updated", index: 0)]
        TodoStorage.save(todos: updated, notificationRecords: [], to: testStorageURL)

        let loaded = TodoStorage.load(from: testStorageURL).todos
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.text, "Updated")
    }

    // MARK: - Phase 4: Missing Field Round-Trip Tests

    func testReminderDate_roundTrip() {
        let reminderDate = Date(timeIntervalSince1970: 9_000_000)
        var todo = TodoItem(text: "Reminder Task", index: 0)
        todo.reminderDate = reminderDate

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loaded = TodoStorage.load(from: testStorageURL).todos

        XCTAssertNotNil(loaded.first?.reminderDate)
        if let loadedDate = loaded.first?.reminderDate {
            XCTAssertEqual(loadedDate.timeIntervalSince1970, reminderDate.timeIntervalSince1970, accuracy: 0.001)
        }
    }

    func testHasActiveNotification_true_roundTrip() {
        var todo = TodoItem(text: "Notif Task", index: 0)
        todo.hasActiveNotification = true

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loaded = TodoStorage.load(from: testStorageURL).todos

        XCTAssertTrue(loaded.first?.hasActiveNotification ?? false)
    }

    func testHasActiveNotification_false_roundTrip() {
        var todo = TodoItem(text: "Notif Task", index: 0)
        todo.hasActiveNotification = false

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loaded = TodoStorage.load(from: testStorageURL).todos

        XCTAssertFalse(loaded.first?.hasActiveNotification ?? true)
    }

    // These four fields are not currently written by TodoStorage.save().
    // These tests document that behaviour so any future storage change that
    // starts persisting them is immediately visible.

    func testCountdownTime_notPersistedByStorage() {
        var todo = TodoItem(text: "Countdown Task", index: 0)
        todo.countdownTime = 3_600

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loaded = TodoStorage.load(from: testStorageURL).todos

        XCTAssertEqual(loaded.first?.countdownTime, 0, "countdownTime is not currently saved by TodoStorage")
    }

    func testCountdownStartTime_notPersistedByStorage() {
        var todo = TodoItem(text: "Countdown Task", index: 0)
        todo.countdownStartTime = Date(timeIntervalSince1970: 1_000_000)

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loaded = TodoStorage.load(from: testStorageURL).todos

        XCTAssertNil(loaded.first?.countdownStartTime, "countdownStartTime is not currently saved by TodoStorage")
    }

    func testCountdownElapsedAtPause_notPersistedByStorage() {
        var todo = TodoItem(text: "Countdown Task", index: 0)
        todo.countdownElapsedAtPause = 1_800

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loaded = TodoStorage.load(from: testStorageURL).todos

        XCTAssertEqual(loaded.first?.countdownElapsedAtPause, 0, "countdownElapsedAtPause is not currently saved by TodoStorage")
    }

    func testLastPlayedAt_notPersistedByStorage() {
        var todo = TodoItem(text: "Task", index: 0)
        todo.lastPlayedAt = 5_000_000

        TodoStorage.save(todos: [todo], notificationRecords: [], to: testStorageURL)
        let loaded = TodoStorage.load(from: testStorageURL).todos

        XCTAssertNil(loaded.first?.lastPlayedAt, "lastPlayedAt is not currently saved by TodoStorage")
    }

    func testLoad_missingOptionalFields_usesDefaults() {
        let minimalJSON = """
        {
            "tasks": {
                "00000000-0000-0000-0000-000000000001": {
                    "title": "Minimal Task",
                    "index": 0,
                    "isCompleted": false
                }
            },
            "notificationRecords": []
        }
        """
        try! minimalJSON.write(to: testStorageURL, atomically: true, encoding: .utf8)

        let loaded = TodoStorage.load(from: testStorageURL).todos

        XCTAssertEqual(loaded.count, 1)
        let task = loaded.first!
        XCTAssertEqual(task.text, "Minimal Task")
        XCTAssertEqual(task.totalTimeSpent, 0)
        XCTAssertEqual(task.description, "")
        XCTAssertFalse(task.isAdhoc)
        XCTAssertEqual(task.fromWho, "")
        XCTAssertEqual(task.estimatedTime, 0)
        XCTAssertEqual(task.notes, "")
        XCTAssertNil(task.dueDate)
        XCTAssertNil(task.lastStartTime)
        XCTAssertNil(task.startedAt)
        XCTAssertNil(task.completedAt)
        XCTAssertFalse(task.hasActiveNotification)
        XCTAssertNil(task.reminderDate)
    }

    func testLoad_oldNotificationRecordsArePruned() {
        let taskId = UUID()
        let oldDate = Date().addingTimeInterval(-31 * 24 * 60 * 60)
        let recentDate = Date().addingTimeInterval(-1 * 24 * 60 * 60)

        let oldRecord = NotificationRecord(taskId: taskId, taskTitle: "Old", firedAt: oldDate)
        let recentRecord = NotificationRecord(taskId: taskId, taskTitle: "Recent", firedAt: recentDate)

        TodoStorage.save(todos: [], notificationRecords: [oldRecord, recentRecord], to: testStorageURL)
        let result = TodoStorage.load(from: testStorageURL)

        XCTAssertEqual(result.notificationRecords.count, 1)
        XCTAssertEqual(result.notificationRecords.first?.taskTitle, "Recent")
    }

    func testLoad_corruptedJSON_returnsEmptyState() {
        try! "this is not valid json {{{]]}".write(to: testStorageURL, atomically: true, encoding: .utf8)

        let result = TodoStorage.load(from: testStorageURL)

        XCTAssertTrue(result.todos.isEmpty)
        XCTAssertTrue(result.notificationRecords.isEmpty)
    }
}
