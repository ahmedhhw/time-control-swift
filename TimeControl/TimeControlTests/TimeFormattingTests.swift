//
//  TimeFormattingTests.swift
//  TimeControlTests
//
//  Created on 2/11/26.
//

import XCTest
@testable import TimeControl

final class TimeFormattingTests: XCTestCase {
    
    // MARK: - Time Calculation Edge Cases
    
    func testZeroTimeSpent() {
        let todo = TodoItem(text: "Test", totalTimeSpent: 0)
        XCTAssertEqual(todo.currentTimeSpent, 0)
    }
    
    func testExactlyOneSecond() {
        var todo = TodoItem(text: "Test")
        todo.totalTimeSpent = 1
        XCTAssertEqual(todo.currentTimeSpent, 1, accuracy: 0.01)
    }
    
    func testExactlyOneMinute() {
        var todo = TodoItem(text: "Test")
        todo.totalTimeSpent = 60
        XCTAssertEqual(todo.currentTimeSpent, 60, accuracy: 0.01)
    }
    
    func testExactlyOneHour() {
        var todo = TodoItem(text: "Test")
        todo.totalTimeSpent = 3600
        XCTAssertEqual(todo.currentTimeSpent, 3600, accuracy: 0.01)
    }
    
    func testMultipleHours() {
        var todo = TodoItem(text: "Test")
        todo.totalTimeSpent = 7200 // 2 hours
        XCTAssertEqual(todo.currentTimeSpent, 7200, accuracy: 0.01)
    }
    
    func testComplexTime() {
        var todo = TodoItem(text: "Test")
        // 2 hours, 34 minutes, 56 seconds = 9296 seconds
        todo.totalTimeSpent = 9296
        XCTAssertEqual(todo.currentTimeSpent, 9296, accuracy: 0.01)
    }
    
    func testVeryLargeTimeSpent() {
        var todo = TodoItem(text: "Test")
        // 100 hours
        todo.totalTimeSpent = 360000
        XCTAssertEqual(todo.currentTimeSpent, 360000, accuracy: 0.01)
    }
    
    // MARK: - Running Timer Edge Cases
    
    func testTimerStartedJustNow() {
        var todo = TodoItem(text: "Test")
        todo.lastStartTime = Date()
        
        // Should be very close to 0 but not exactly 0
        XCTAssertLessThan(todo.currentTimeSpent, 1.0)
        XCTAssertGreaterThanOrEqual(todo.currentTimeSpent, 0.0)
    }
    
    func testTimerWithPreviousTime() {
        var todo = TodoItem(text: "Test")
        todo.totalTimeSpent = 1000
        todo.lastStartTime = Date(timeIntervalSinceNow: -50)
        
        let currentTime = todo.currentTimeSpent
        XCTAssertGreaterThan(currentTime, 1049)
        XCTAssertLessThan(currentTime, 1051)
    }
    
    func testTimerStartedInPast() {
        var todo = TodoItem(text: "Test")
        // Started 1 hour ago
        todo.lastStartTime = Date(timeIntervalSinceNow: -3600)
        
        let currentTime = todo.currentTimeSpent
        XCTAssertGreaterThan(currentTime, 3599)
        XCTAssertLessThan(currentTime, 3601)
    }
    
    // MARK: - Estimated Time Comparisons
    
    func testTimeRemainingPositive() {
        var todo = TodoItem(text: "Test")
        todo.estimatedTime = 3600 // 1 hour
        todo.totalTimeSpent = 1800 // 30 minutes
        
        let remaining = todo.estimatedTime - todo.currentTimeSpent
        XCTAssertEqual(remaining, 1800, accuracy: 0.01)
    }
    
    func testTimeRemainingNegative() {
        var todo = TodoItem(text: "Test")
        todo.estimatedTime = 3600 // 1 hour
        todo.totalTimeSpent = 5400 // 1.5 hours
        
        let remaining = todo.estimatedTime - todo.currentTimeSpent
        XCTAssertEqual(remaining, -1800, accuracy: 0.01)
    }
    
    func testTimeRemainingExact() {
        var todo = TodoItem(text: "Test")
        todo.estimatedTime = 3600
        todo.totalTimeSpent = 3600
        
        let remaining = todo.estimatedTime - todo.currentTimeSpent
        XCTAssertEqual(remaining, 0, accuracy: 0.01)
    }
    
    func testOverEstimateBySmallAmount() {
        var todo = TodoItem(text: "Test")
        todo.estimatedTime = 3600
        todo.totalTimeSpent = 3601
        
        let overBy = todo.currentTimeSpent - todo.estimatedTime
        XCTAssertEqual(overBy, 1, accuracy: 0.01)
    }
    
    // MARK: - Progress Calculation
    
    func testProgressZeroPercent() {
        var todo = TodoItem(text: "Test")
        todo.estimatedTime = 3600
        todo.totalTimeSpent = 0
        
        let progress = todo.currentTimeSpent / todo.estimatedTime
        XCTAssertEqual(progress, 0.0, accuracy: 0.01)
    }
    
    func testProgressFiftyPercent() {
        var todo = TodoItem(text: "Test")
        todo.estimatedTime = 3600
        todo.totalTimeSpent = 1800
        
        let progress = todo.currentTimeSpent / todo.estimatedTime
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }
    
    func testProgressOneHundredPercent() {
        var todo = TodoItem(text: "Test")
        todo.estimatedTime = 3600
        todo.totalTimeSpent = 3600
        
        let progress = todo.currentTimeSpent / todo.estimatedTime
        XCTAssertEqual(progress, 1.0, accuracy: 0.01)
    }
    
    func testProgressOverOneHundredPercent() {
        var todo = TodoItem(text: "Test")
        todo.estimatedTime = 3600
        todo.totalTimeSpent = 7200
        
        let progress = todo.currentTimeSpent / todo.estimatedTime
        XCTAssertEqual(progress, 2.0, accuracy: 0.01)
    }
    
    func testProgressClampedToOne() {
        var todo = TodoItem(text: "Test")
        todo.estimatedTime = 3600
        todo.totalTimeSpent = 7200
        
        let progress = min(todo.currentTimeSpent / todo.estimatedTime, 1.0)
        XCTAssertEqual(progress, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Date and Timestamp Edge Cases
    
    func testCreatedAtEpochTime() {
        let epochTime: TimeInterval = 0
        let todo = TodoItem(text: "Test", createdAt: epochTime)
        XCTAssertEqual(todo.createdAt, 0)
    }
    
    func testCreatedAtFutureTime() {
        let futureTime = Date(timeIntervalSinceNow: 86400).timeIntervalSince1970
        let todo = TodoItem(text: "Test", createdAt: futureTime)
        XCTAssertEqual(todo.createdAt, futureTime)
    }
    
    func testDueDateInPast() {
        let pastDate = Date(timeIntervalSinceNow: -86400)
        let todo = TodoItem(text: "Test", dueDate: pastDate)
        
        XCTAssertNotNil(todo.dueDate)
        XCTAssertLessThan(todo.dueDate!.timeIntervalSinceNow, 0)
    }
    
    func testDueDateInFuture() {
        let futureDate = Date(timeIntervalSinceNow: 86400)
        let todo = TodoItem(text: "Test", dueDate: futureDate)
        
        XCTAssertNotNil(todo.dueDate)
        XCTAssertGreaterThan(todo.dueDate!.timeIntervalSinceNow, 0)
    }
    
    // MARK: - Timer State Transitions
    
    func testMultipleStartStopCycles() {
        var todo = TodoItem(text: "Test")
        
        // First cycle
        todo.lastStartTime = Date(timeIntervalSinceNow: -10)
        var elapsed1 = Date().timeIntervalSince(todo.lastStartTime!)
        todo.totalTimeSpent += elapsed1
        todo.lastStartTime = nil
        
        let timeAfterFirstCycle = todo.totalTimeSpent
        XCTAssertGreaterThan(timeAfterFirstCycle, 9)
        XCTAssertLessThan(timeAfterFirstCycle, 11)
        
        // Second cycle
        todo.lastStartTime = Date(timeIntervalSinceNow: -5)
        var elapsed2 = Date().timeIntervalSince(todo.lastStartTime!)
        todo.totalTimeSpent += elapsed2
        todo.lastStartTime = nil
        
        let timeAfterSecondCycle = todo.totalTimeSpent
        XCTAssertGreaterThan(timeAfterSecondCycle, 14)
        XCTAssertLessThan(timeAfterSecondCycle, 16)
    }
    
    func testTimerAccuracyOverTime() {
        var todo = TodoItem(text: "Test")
        
        let startDate = Date(timeIntervalSinceNow: -123.456)
        todo.lastStartTime = startDate
        
        let expected: TimeInterval = 123.456
        let actual = todo.currentTimeSpent
        
        XCTAssertEqual(actual, expected, accuracy: 0.1)
    }
    
    // MARK: - Boundary Conditions
    
    func testMinimumTimeInterval() {
        var todo = TodoItem(text: "Test")
        todo.totalTimeSpent = 0.001 // 1 millisecond
        
        XCTAssertGreaterThan(todo.currentTimeSpent, 0)
    }
    
    func testNegativeTimeSpentShouldNotOccur() {
        // This test documents that negative time should not occur
        // in normal usage, but the model doesn't prevent it
        var todo = TodoItem(text: "Test")
        todo.totalTimeSpent = -100
        
        // The model allows negative values, but UI/logic should prevent this
        XCTAssertLessThan(todo.totalTimeSpent, 0)
    }
    
    // MARK: - Concurrent Timer Scenarios
    
    func testOnlyOneTaskShouldHaveRunningTimer() {
        var todos = [
            TodoItem(text: "Task 1", index: 0),
            TodoItem(text: "Task 2", index: 1),
            TodoItem(text: "Task 3", index: 2)
        ]
        
        // Start timer on first task
        todos[0].lastStartTime = Date()
        
        // Count running tasks
        let runningCount = todos.filter { $0.isRunning }.count
        XCTAssertEqual(runningCount, 1)
    }
    
    func testStoppingAllTimers() {
        var todos = [
            TodoItem(text: "Task 1", index: 0),
            TodoItem(text: "Task 2", index: 1)
        ]
        
        // Start a timer
        todos[0].lastStartTime = Date()
        
        // Stop all timers
        for i in 0..<todos.count {
            if todos[i].isRunning {
                if let startTime = todos[i].lastStartTime {
                    todos[i].totalTimeSpent += Date().timeIntervalSince(startTime)
                }
                todos[i].lastStartTime = nil
            }
        }
        
        let runningCount = todos.filter { $0.isRunning }.count
        XCTAssertEqual(runningCount, 0)
    }
    
    // MARK: - Performance Edge Cases
    
    func testLargeNumberOfSubtasks() {
        var subtasks: [Subtask] = []
        for i in 0..<1000 {
            subtasks.append(Subtask(title: "Subtask \(i)"))
        }
        
        let todo = TodoItem(text: "Test", index: 0, subtasks: subtasks)
        XCTAssertEqual(todo.subtasks.count, 1000)
    }
    
    func testCompletedSubtasksCount() {
        let subtasks = [
            Subtask(title: "S1", isCompleted: true),
            Subtask(title: "S2", isCompleted: false),
            Subtask(title: "S3", isCompleted: true),
            Subtask(title: "S4", isCompleted: true),
            Subtask(title: "S5", isCompleted: false)
        ]
        
        let todo = TodoItem(text: "Test", index: 0, subtasks: subtasks)
        let completedCount = todo.subtasks.filter { $0.isCompleted }.count
        
        XCTAssertEqual(completedCount, 3)
    }
    
    func testSubtaskCompletionPercentage() {
        let subtasks = [
            Subtask(title: "S1", isCompleted: true),
            Subtask(title: "S2", isCompleted: true),
            Subtask(title: "S3", isCompleted: false),
            Subtask(title: "S4", isCompleted: false)
        ]
        
        let todo = TodoItem(text: "Test", index: 0, subtasks: subtasks)
        let completedCount = todo.subtasks.filter { $0.isCompleted }.count
        let percentage = Double(completedCount) / Double(todo.subtasks.count)
        
        XCTAssertEqual(percentage, 0.5, accuracy: 0.01)
    }
}
