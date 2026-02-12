//
//  SubtaskTests.swift
//  TodoAppTests
//
//  Created on 2/11/26.
//

import XCTest
@testable import TodoApp

final class SubtaskTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testSubtaskInitialization() {
        let subtask = Subtask(title: "Test Subtask")
        
        XCTAssertEqual(subtask.title, "Test Subtask")
        XCTAssertEqual(subtask.description, "")
        XCTAssertFalse(subtask.isCompleted)
    }
    
    func testSubtaskInitializationWithAllParameters() {
        let id = UUID()
        let subtask = Subtask(
            id: id,
            title: "Complete Subtask",
            description: "Detailed description",
            isCompleted: true
        )
        
        XCTAssertEqual(subtask.id, id)
        XCTAssertEqual(subtask.title, "Complete Subtask")
        XCTAssertEqual(subtask.description, "Detailed description")
        XCTAssertTrue(subtask.isCompleted)
    }
    
    // MARK: - Default Values Tests
    
    func testSubtaskDefaultDescription() {
        let subtask = Subtask(title: "Test")
        XCTAssertEqual(subtask.description, "")
    }
    
    func testSubtaskDefaultIsCompleted() {
        let subtask = Subtask(title: "Test")
        XCTAssertFalse(subtask.isCompleted)
    }
    
    // MARK: - Modification Tests
    
    func testSubtaskCompletion() {
        var subtask = Subtask(title: "Test")
        XCTAssertFalse(subtask.isCompleted)
        
        subtask.isCompleted = true
        XCTAssertTrue(subtask.isCompleted)
    }
    
    func testSubtaskTitleModification() {
        var subtask = Subtask(title: "Original Title")
        XCTAssertEqual(subtask.title, "Original Title")
        
        subtask.title = "Modified Title"
        XCTAssertEqual(subtask.title, "Modified Title")
    }
    
    func testSubtaskDescriptionModification() {
        var subtask = Subtask(title: "Test", description: "Original")
        XCTAssertEqual(subtask.description, "Original")
        
        subtask.description = "Modified"
        XCTAssertEqual(subtask.description, "Modified")
    }
    
    // MARK: - Equatable Tests
    
    func testSubtaskEquality() {
        let id = UUID()
        let subtask1 = Subtask(id: id, title: "Test")
        let subtask2 = Subtask(id: id, title: "Test")
        
        XCTAssertEqual(subtask1, subtask2)
    }
    
    func testSubtaskInequality() {
        let subtask1 = Subtask(title: "Test 1")
        let subtask2 = Subtask(title: "Test 2")
        
        XCTAssertNotEqual(subtask1, subtask2)
    }
    
    func testSubtaskEqualityWithDifferentContent() {
        let id = UUID()
        let subtask1 = Subtask(id: id, title: "Test", isCompleted: false)
        let subtask2 = Subtask(id: id, title: "Different", isCompleted: true)
        
        // Should be equal if IDs match
        XCTAssertEqual(subtask1, subtask2)
    }
    
    // MARK: - Identifiable Tests
    
    func testSubtaskHasUniqueId() {
        let subtask1 = Subtask(title: "Test 1")
        let subtask2 = Subtask(title: "Test 2")
        
        XCTAssertNotEqual(subtask1.id, subtask2.id)
    }
    
    func testSubtaskIdPersistence() {
        let id = UUID()
        let subtask = Subtask(id: id, title: "Test")
        
        XCTAssertEqual(subtask.id, id)
    }
}
