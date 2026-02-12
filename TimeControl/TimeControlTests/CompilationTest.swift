//
//  CompilationTest.swift
//  TimeControlTests
//
//  Simple compilation verification test
//

import XCTest
@testable import TimeControl

/// This is a minimal test to verify the test target compiles correctly
final class CompilationTest: XCTestCase {
    
    func testTodoItemCanBeCreated() {
        let todo = TodoItem(text: "Test")
        XCTAssertEqual(todo.text, "Test")
    }
    
    func testSubtaskCanBeCreated() {
        let subtask = Subtask(title: "Test")
        XCTAssertEqual(subtask.title, "Test")
    }
    
    func testStorageExists() {
        // Just verify the class exists
        let todos: [TodoItem] = []
        TodoStorage.save(todos: todos)
        XCTAssertTrue(true, "Storage methods are accessible")
    }
}
