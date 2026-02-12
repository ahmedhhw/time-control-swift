//
//  TodoItemTests.swift
//  TimeControlTests
//
//  Created on 2/11/26.
//

import XCTest
@testable import TimeControl

final class TodoItemTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testTodoItemInitialization() {
        let todo = TodoItem(text: "Test Todo")
        
        XCTAssertFalse(todo.isCompleted, "New todo should not be completed")
        XCTAssertEqual(todo.text, "Test Todo")
        XCTAssertEqual(todo.totalTimeSpent, 0)
        XCTAssertNil(todo.lastStartTime)
        XCTAssertEqual(todo.description, "")
        XCTAssertNil(todo.dueDate)
        XCTAssertFalse(todo.isAdhoc)
        XCTAssertEqual(todo.fromWho, "")
        XCTAssertEqual(todo.estimatedTime, 0)
        XCTAssertTrue(todo.subtasks.isEmpty)
        XCTAssertNil(todo.startedAt)
        XCTAssertNil(todo.completedAt)
        XCTAssertEqual(todo.notes, "")
    }
    
    func testTodoItemInitializationWithAllParameters() {
        let dueDate = Date()
        let subtasks = [Subtask(title: "Subtask 1")]
        let createdAt = Date().timeIntervalSince1970
        
        let todo = TodoItem(
            text: "Complete Todo",
            isCompleted: true,
            index: 1,
            totalTimeSpent: 3600,
            description: "Detailed description",
            dueDate: dueDate,
            isAdhoc: true,
            fromWho: "Manager",
            estimatedTime: 7200,
            subtasks: subtasks,
            createdAt: createdAt,
            notes: "Some notes"
        )
        
        XCTAssertTrue(todo.isCompleted)
        XCTAssertEqual(todo.text, "Complete Todo")
        XCTAssertEqual(todo.index, 1)
        XCTAssertEqual(todo.totalTimeSpent, 3600)
        XCTAssertEqual(todo.description, "Detailed description")
        XCTAssertEqual(todo.dueDate, dueDate)
        XCTAssertTrue(todo.isAdhoc)
        XCTAssertEqual(todo.fromWho, "Manager")
        XCTAssertEqual(todo.estimatedTime, 7200)
        XCTAssertEqual(todo.subtasks.count, 1)
        XCTAssertEqual(todo.createdAt, createdAt)
        XCTAssertEqual(todo.notes, "Some notes")
    }
    
    // MARK: - Timer Functionality Tests
    
    func testIsRunningWhenTimerNotStarted() {
        let todo = TodoItem(text: "Test Todo")
        XCTAssertFalse(todo.isRunning, "Todo should not be running when timer is not started")
    }
    
    func testIsRunningWhenTimerStarted() {
        var todo = TodoItem(text: "Test Todo")
        todo.lastStartTime = Date()
        XCTAssertTrue(todo.isRunning, "Todo should be running when lastStartTime is set")
    }
    
    func testCurrentTimeSpentWithoutTimer() {
        var todo = TodoItem(text: "Test Todo")
        todo.totalTimeSpent = 3600
        
        XCTAssertEqual(todo.currentTimeSpent, 3600, accuracy: 0.1)
    }
    
    func testCurrentTimeSpentWithRunningTimer() {
        var todo = TodoItem(text: "Test Todo")
        todo.totalTimeSpent = 3600
        todo.lastStartTime = Date(timeIntervalSinceNow: -100) // Started 100 seconds ago
        
        // Current time should be total time + time since start
        let expectedTime: TimeInterval = 3700
        XCTAssertEqual(todo.currentTimeSpent, expectedTime, accuracy: 1.0)
    }
    
    func testTimerAccumulatesTime() {
        var todo = TodoItem(text: "Test Todo")
        
        // First session: 100 seconds
        todo.totalTimeSpent = 100
        
        // Second session: started 50 seconds ago
        todo.lastStartTime = Date(timeIntervalSinceNow: -50)
        
        let expectedTime: TimeInterval = 150
        XCTAssertEqual(todo.currentTimeSpent, expectedTime, accuracy: 1.0)
    }
    
    // MARK: - Timestamp Tests
    
    func testCreatedAtDefaultsToNow() {
        let beforeCreation = Date().timeIntervalSince1970
        let todo = TodoItem(text: "Test Todo")
        let afterCreation = Date().timeIntervalSince1970
        
        XCTAssertGreaterThanOrEqual(todo.createdAt, beforeCreation)
        XCTAssertLessThanOrEqual(todo.createdAt, afterCreation)
    }
    
    func testCreatedAtCanBeSet() {
        let customTime = Date(timeIntervalSince1970: 1000000).timeIntervalSince1970
        let todo = TodoItem(text: "Test Todo", createdAt: customTime)
        
        XCTAssertEqual(todo.createdAt, customTime)
    }
    
    func testStartedAtInitiallyNil() {
        let todo = TodoItem(text: "Test Todo")
        XCTAssertNil(todo.startedAt)
    }
    
    func testCompletedAtInitiallyNil() {
        let todo = TodoItem(text: "Test Todo")
        XCTAssertNil(todo.completedAt)
    }
    
    // MARK: - Subtask Tests
    
    func testAddingSubtasks() {
        var todo = TodoItem(text: "Test Todo")
        let subtask1 = Subtask(title: "Subtask 1")
        let subtask2 = Subtask(title: "Subtask 2")
        
        todo.subtasks = [subtask1, subtask2]
        
        XCTAssertEqual(todo.subtasks.count, 2)
        XCTAssertEqual(todo.subtasks[0].title, "Subtask 1")
        XCTAssertEqual(todo.subtasks[1].title, "Subtask 2")
    }
    
    func testSubtasksAreIndependent() {
        let subtask1 = Subtask(title: "Subtask 1", isCompleted: true)
        let subtask2 = Subtask(title: "Subtask 2", isCompleted: false)
        
        let todo = TodoItem(text: "Test Todo", subtasks: [subtask1, subtask2])
        
        XCTAssertTrue(todo.subtasks[0].isCompleted)
        XCTAssertFalse(todo.subtasks[1].isCompleted)
    }
    
    // MARK: - Estimated Time Tests
    
    func testEstimatedTimeInSeconds() {
        let todo = TodoItem(text: "Test Todo", estimatedTime: 3600)
        XCTAssertEqual(todo.estimatedTime, 3600) // 1 hour
    }
    
    func testEstimatedTimeDefaultsToZero() {
        let todo = TodoItem(text: "Test Todo")
        XCTAssertEqual(todo.estimatedTime, 0)
    }
    
    // MARK: - Due Date Tests
    
    func testDueDateCanBeSet() {
        let dueDate = Date(timeIntervalSinceNow: 86400) // 24 hours from now
        let todo = TodoItem(text: "Test Todo", dueDate: dueDate)
        
        XCTAssertEqual(todo.dueDate, dueDate)
    }
    
    func testDueDateDefaultsToNil() {
        let todo = TodoItem(text: "Test Todo")
        XCTAssertNil(todo.dueDate)
    }
    
    // MARK: - Adhoc Task Tests
    
    func testAdhocFlagDefaultsToFalse() {
        let todo = TodoItem(text: "Test Todo")
        XCTAssertFalse(todo.isAdhoc)
    }
    
    func testAdhocFlagCanBeSet() {
        let todo = TodoItem(text: "Test Todo", isAdhoc: true)
        XCTAssertTrue(todo.isAdhoc)
    }
    
    // MARK: - From Who Tests
    
    func testFromWhoDefaultsToEmpty() {
        let todo = TodoItem(text: "Test Todo")
        XCTAssertEqual(todo.fromWho, "")
    }
    
    func testFromWhoCanBeSet() {
        let todo = TodoItem(text: "Test Todo", fromWho: "Manager")
        XCTAssertEqual(todo.fromWho, "Manager")
    }
    
    // MARK: - Notes Tests
    
    func testNotesDefaultsToEmpty() {
        let todo = TodoItem(text: "Test Todo")
        XCTAssertEqual(todo.notes, "")
    }
    
    func testNotesCanBeSet() {
        let todo = TodoItem(text: "Test Todo", notes: "Important notes")
        XCTAssertEqual(todo.notes, "Important notes")
    }
    
    // MARK: - Equatable Tests
    
    func testTodoItemEquality() {
        let id = UUID()
        let todo1 = TodoItem(id: id, text: "Test Todo")
        let todo2 = TodoItem(id: id, text: "Test Todo")
        
        XCTAssertEqual(todo1, todo2)
    }
    
    func testTodoItemInequality() {
        let todo1 = TodoItem(text: "Test Todo 1")
        let todo2 = TodoItem(text: "Test Todo 2")
        
        XCTAssertNotEqual(todo1, todo2)
    }
}
