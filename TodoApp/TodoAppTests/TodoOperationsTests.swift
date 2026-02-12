//
//  TodoOperationsTests.swift
//  TodoAppTests
//
//  Created on 2/11/26.
//

import XCTest
@testable import TodoApp

/// Tests for core todo operations that would be performed in ContentView
final class TodoOperationsTests: XCTestCase {
    
    // MARK: - Add Todo Tests
    
    func testAddTodoToEmptyList() {
        var todos: [TodoItem] = []
        
        let newTodo = TodoItem(text: "First Todo", index: todos.count)
        todos.append(newTodo)
        
        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos.first?.text, "First Todo")
        XCTAssertEqual(todos.first?.index, 0)
    }
    
    func testAddMultipleTodos() {
        var todos: [TodoItem] = []
        
        for i in 0..<5 {
            let todo = TodoItem(text: "Todo \(i)", index: todos.count)
            todos.append(todo)
        }
        
        XCTAssertEqual(todos.count, 5)
        XCTAssertEqual(todos[0].index, 0)
        XCTAssertEqual(todos[4].index, 4)
    }
    
    func testAddTodoMaintainsCorrectIndices() {
        var todos: [TodoItem] = []
        
        let todo1 = TodoItem(text: "Todo 1", index: todos.count)
        todos.append(todo1)
        
        let todo2 = TodoItem(text: "Todo 2", index: todos.count)
        todos.append(todo2)
        
        let todo3 = TodoItem(text: "Todo 3", index: todos.count)
        todos.append(todo3)
        
        XCTAssertEqual(todos[0].index, 0)
        XCTAssertEqual(todos[1].index, 1)
        XCTAssertEqual(todos[2].index, 2)
    }
    
    // MARK: - Toggle Todo Tests
    
    func testToggleTodoCompletion() {
        var todo = TodoItem(text: "Test Todo", isCompleted: false)
        
        todo.isCompleted.toggle()
        XCTAssertTrue(todo.isCompleted)
        
        todo.isCompleted.toggle()
        XCTAssertFalse(todo.isCompleted)
    }
    
    func testToggleTodoInList() {
        var todos = [
            TodoItem(text: "Todo 1", isCompleted: false, index: 0),
            TodoItem(text: "Todo 2", isCompleted: false, index: 1)
        ]
        
        let todoId = todos[0].id
        if let index = todos.firstIndex(where: { $0.id == todoId }) {
            todos[index].isCompleted.toggle()
        }
        
        XCTAssertTrue(todos[0].isCompleted)
        XCTAssertFalse(todos[1].isCompleted)
    }
    
    func testCompletedAtSetWhenToggled() {
        var todo = TodoItem(text: "Test Todo", isCompleted: false)
        
        XCTAssertNil(todo.completedAt)
        
        todo.isCompleted = true
        todo.completedAt = Date().timeIntervalSince1970
        
        XCTAssertNotNil(todo.completedAt)
    }
    
    // MARK: - Delete Todo Tests
    
    func testDeleteTodoFromList() {
        var todos = [
            TodoItem(text: "Todo 1", index: 0),
            TodoItem(text: "Todo 2", index: 1),
            TodoItem(text: "Todo 3", index: 2)
        ]
        
        let todoToDelete = todos[1]
        todos.removeAll { $0.id == todoToDelete.id }
        
        XCTAssertEqual(todos.count, 2)
        XCTAssertEqual(todos[0].text, "Todo 1")
        XCTAssertEqual(todos[1].text, "Todo 3")
    }
    
    func testDeleteAndReindex() {
        var todos = [
            TodoItem(text: "Todo 1", index: 0),
            TodoItem(text: "Todo 2", index: 1),
            TodoItem(text: "Todo 3", index: 2)
        ]
        
        // Delete middle todo
        let todoToDelete = todos[1]
        todos.removeAll { $0.id == todoToDelete.id }
        
        // Reindex
        for (index, _) in todos.enumerated() {
            todos[index].index = index
        }
        
        XCTAssertEqual(todos[0].index, 0)
        XCTAssertEqual(todos[1].index, 1)
    }
    
    func testDeleteLastTodo() {
        var todos = [TodoItem(text: "Only Todo", index: 0)]
        
        let idToRemove = todos[0].id
        todos.removeAll { $0.id == idToRemove }
        
        XCTAssertTrue(todos.isEmpty)
    }
    
    // MARK: - Timer Operations Tests
    
    func testStartTimer() {
        var todo = TodoItem(text: "Test Todo")
        
        XCTAssertNil(todo.lastStartTime)
        XCTAssertNil(todo.startedAt)
        
        todo.lastStartTime = Date()
        todo.startedAt = Date().timeIntervalSince1970
        
        XCTAssertNotNil(todo.lastStartTime)
        XCTAssertNotNil(todo.startedAt)
        XCTAssertTrue(todo.isRunning)
    }
    
    func testStopTimer() {
        var todo = TodoItem(text: "Test Todo")
        
        // Start timer
        let startTime = Date(timeIntervalSinceNow: -100)
        todo.lastStartTime = startTime
        
        // Stop timer and accumulate time
        let elapsed = Date().timeIntervalSince(startTime)
        todo.totalTimeSpent += elapsed
        todo.lastStartTime = nil
        
        XCTAssertFalse(todo.isRunning)
        XCTAssertGreaterThan(todo.totalTimeSpent, 99)
    }
    
    func testOnlyOneTimerRunningAtOnce() {
        var todos = [
            TodoItem(text: "Todo 1", index: 0),
            TodoItem(text: "Todo 2", index: 1),
            TodoItem(text: "Todo 3", index: 2)
        ]
        
        // Start first timer
        todos[0].lastStartTime = Date()
        
        // Start second timer - should stop first one
        for i in 0..<todos.count {
            if todos[i].isRunning {
                if let startTime = todos[i].lastStartTime {
                    todos[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[i].lastStartTime = nil
            }
        }
        todos[1].lastStartTime = Date()
        
        XCTAssertFalse(todos[0].isRunning)
        XCTAssertTrue(todos[1].isRunning)
        XCTAssertFalse(todos[2].isRunning)
    }
    
    func testTimerStopsWhenTodoCompleted() {
        var todo = TodoItem(text: "Test Todo")
        
        // Start timer
        todo.lastStartTime = Date(timeIntervalSinceNow: -50)
        
        // Complete todo
        todo.isCompleted = true
        
        // Stop timer
        if todo.isCompleted && todo.isRunning {
            if let startTime = todo.lastStartTime {
                todo.totalTimeSpent += Date().timeIntervalSince(startTime)
            }
            todo.lastStartTime = nil
        }
        
        XCTAssertFalse(todo.isRunning)
        XCTAssertGreaterThan(todo.totalTimeSpent, 0)
    }
    
    // MARK: - Move Todo Tests
    
    func testMoveTodoInList() {
        var todos = [
            TodoItem(text: "Todo 1", index: 0),
            TodoItem(text: "Todo 2", index: 1),
            TodoItem(text: "Todo 3", index: 2)
        ]
        
        // Move first todo to last position
        let movedTodo = todos.remove(at: 0)
        todos.insert(movedTodo, at: 2)
        
        // Reindex
        for (index, _) in todos.enumerated() {
            todos[index].index = index
        }
        
        XCTAssertEqual(todos[0].text, "Todo 2")
        XCTAssertEqual(todos[1].text, "Todo 3")
        XCTAssertEqual(todos[2].text, "Todo 1")
        XCTAssertEqual(todos[0].index, 0)
        XCTAssertEqual(todos[1].index, 1)
        XCTAssertEqual(todos[2].index, 2)
    }
    
    func testMoveToSamePosition() {
        var todos = [
            TodoItem(text: "Todo 1", index: 0),
            TodoItem(text: "Todo 2", index: 1)
        ]
        
        let sourceIndex = 0
        let destinationIndex = 0
        
        if sourceIndex != destinationIndex {
            let movedTodo = todos.remove(at: sourceIndex)
            todos.insert(movedTodo, at: destinationIndex)
        }
        
        // Should remain unchanged
        XCTAssertEqual(todos[0].text, "Todo 1")
        XCTAssertEqual(todos[1].text, "Todo 2")
    }
    
    // MARK: - Subtask Operations Tests
    
    func testAddSubtask() {
        var todo = TodoItem(text: "Parent Todo", index: 0)
        
        let subtask = Subtask(title: "New Subtask")
        todo.subtasks.append(subtask)
        
        XCTAssertEqual(todo.subtasks.count, 1)
        XCTAssertEqual(todo.subtasks.first?.title, "New Subtask")
    }
    
    func testToggleSubtask() {
        let subtask = Subtask(title: "Test Subtask", isCompleted: false)
        var todo = TodoItem(text: "Parent Todo", index: 0, subtasks: [subtask])
        
        if let index = todo.subtasks.firstIndex(where: { $0.id == subtask.id }) {
            todo.subtasks[index].isCompleted.toggle()
        }
        
        XCTAssertTrue(todo.subtasks[0].isCompleted)
    }
    
    func testDeleteSubtask() {
        let subtask1 = Subtask(title: "Subtask 1")
        let subtask2 = Subtask(title: "Subtask 2")
        var todo = TodoItem(text: "Parent Todo", index: 0, subtasks: [subtask1, subtask2])
        
        todo.subtasks.removeAll { $0.id == subtask1.id }
        
        XCTAssertEqual(todo.subtasks.count, 1)
        XCTAssertEqual(todo.subtasks.first?.title, "Subtask 2")
    }
    
    func testMultipleSubtasksIndependent() {
        let subtask1 = Subtask(title: "Subtask 1", isCompleted: false)
        let subtask2 = Subtask(title: "Subtask 2", isCompleted: false)
        var todo = TodoItem(text: "Parent Todo", index: 0, subtasks: [subtask1, subtask2])
        
        // Toggle first subtask
        todo.subtasks[0].isCompleted = true
        
        XCTAssertTrue(todo.subtasks[0].isCompleted)
        XCTAssertFalse(todo.subtasks[1].isCompleted)
    }
    
    // MARK: - Filtering Tests
    
    func testFilterIncompleteTodos() {
        let todos = [
            TodoItem(text: "Incomplete 1", isCompleted: false, index: 0),
            TodoItem(text: "Complete", isCompleted: true, index: 1),
            TodoItem(text: "Incomplete 2", isCompleted: false, index: 2)
        ]
        
        let incompleteTodos = todos.filter { !$0.isCompleted }
        
        XCTAssertEqual(incompleteTodos.count, 2)
        XCTAssertEqual(incompleteTodos[0].text, "Incomplete 1")
        XCTAssertEqual(incompleteTodos[1].text, "Incomplete 2")
    }
    
    func testFilterCompletedTodos() {
        let todos = [
            TodoItem(text: "Incomplete", isCompleted: false, index: 0),
            TodoItem(text: "Complete 1", isCompleted: true, index: 1),
            TodoItem(text: "Complete 2", isCompleted: true, index: 2)
        ]
        
        let completedTodos = todos.filter { $0.isCompleted }
        
        XCTAssertEqual(completedTodos.count, 2)
        XCTAssertEqual(completedTodos[0].text, "Complete 1")
        XCTAssertEqual(completedTodos[1].text, "Complete 2")
    }
    
    func testFilterRunningTimers() {
        var todos = [
            TodoItem(text: "Running", index: 0),
            TodoItem(text: "Not Running 1", index: 1),
            TodoItem(text: "Not Running 2", index: 2)
        ]
        
        todos[0].lastStartTime = Date()
        
        let runningTodos = todos.filter { $0.isRunning }
        
        XCTAssertEqual(runningTodos.count, 1)
        XCTAssertEqual(runningTodos.first?.text, "Running")
    }
}
