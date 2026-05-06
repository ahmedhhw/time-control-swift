//
//  TaskPaletteFilterTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class TaskPaletteFilterTests: XCTestCase {

    // MARK: - filteredTasks

    func test_emptySearch_returnsAllTasks() {
        let tasks = [makeTodo(text: "Alpha"), makeTodo(text: "Beta"), makeTodo(text: "Gamma")]
        let result = TaskPaletteFilter.filter(tasks: tasks, searchText: "")
        XCTAssertEqual(result.map(\.text), ["Alpha", "Beta", "Gamma"])
    }

    func test_matchingSearch_returnsOnlyMatches() {
        let tasks = [makeTodo(text: "Sugar lemonade"), makeTodo(text: "Some other story"), makeTodo(text: "Fix crash")]
        let result = TaskPaletteFilter.filter(tasks: tasks, searchText: "sugar")
        XCTAssertEqual(result.map(\.text), ["Sugar lemonade"])
    }

    func test_caseInsensitive_matchesUpperAndLower() {
        let tasks = [makeTodo(text: "URGENT task"), makeTodo(text: "normal task")]
        let result = TaskPaletteFilter.filter(tasks: tasks, searchText: "urgent")
        XCTAssertEqual(result.map(\.text), ["URGENT task"])
    }

    func test_partialMatch_returnsContainingItems() {
        let tasks = [makeTodo(text: "Fix crash on launch"), makeTodo(text: "Go to the park")]
        let result = TaskPaletteFilter.filter(tasks: tasks, searchText: "crash")
        XCTAssertEqual(result.map(\.text), ["Fix crash on launch"])
    }

    func test_noMatch_returnsEmpty() {
        let tasks = [makeTodo(text: "Alpha"), makeTodo(text: "Beta")]
        let result = TaskPaletteFilter.filter(tasks: tasks, searchText: "xyz")
        XCTAssertTrue(result.isEmpty)
    }

    func test_multipleMatches_returnsAll() {
        let tasks = [makeTodo(text: "Task one"), makeTodo(text: "Task two"), makeTodo(text: "Other")]
        let result = TaskPaletteFilter.filter(tasks: tasks, searchText: "task")
        XCTAssertEqual(result.count, 2)
    }

    func test_preservesOrder() {
        let tasks = [makeTodo(text: "Zebra task"), makeTodo(text: "Apple task"), makeTodo(text: "Mango task")]
        let result = TaskPaletteFilter.filter(tasks: tasks, searchText: "task")
        XCTAssertEqual(result.map(\.text), ["Zebra task", "Apple task", "Mango task"])
    }

    // MARK: - showCreateRow

    func test_showCreateRow_falseWhenSearchEmpty() {
        let tasks = [makeTodo(text: "Alpha")]
        XCTAssertFalse(TaskPaletteFilter.showCreateRow(tasks: tasks, searchText: ""))
    }

    func test_showCreateRow_trueWhenNoExactMatch() {
        let tasks = [makeTodo(text: "Alpha"), makeTodo(text: "Beta")]
        XCTAssertTrue(TaskPaletteFilter.showCreateRow(tasks: tasks, searchText: "gamma"))
    }

    func test_showCreateRow_falseWhenExactMatch() {
        let tasks = [makeTodo(text: "Alpha"), makeTodo(text: "Beta")]
        XCTAssertFalse(TaskPaletteFilter.showCreateRow(tasks: tasks, searchText: "Alpha"))
    }

    func test_showCreateRow_caseInsensitiveExactMatch() {
        let tasks = [makeTodo(text: "Alpha")]
        XCTAssertFalse(TaskPaletteFilter.showCreateRow(tasks: tasks, searchText: "alpha"))
    }

    // MARK: - selectedTask (commitSelection logic)

    func test_selectedTask_returnsTaskAtIndex() {
        let tasks = [makeTodo(text: "First"), makeTodo(text: "Second"), makeTodo(text: "Third")]
        let filtered = TaskPaletteFilter.filter(tasks: tasks, searchText: "")
        XCTAssertEqual(filtered[1].text, "Second")
    }

    func test_selectedTask_afterFilter_indexIntoFilteredNotOriginal() {
        let tasks = [makeTodo(text: "Alpha"), makeTodo(text: "Beta"), makeTodo(text: "Another alpha")]
        let filtered = TaskPaletteFilter.filter(tasks: tasks, searchText: "alpha")
        // selectedIndex 0 should be "Alpha", not "Beta" (index 1 in original)
        XCTAssertEqual(filtered[0].text, "Alpha")
        XCTAssertEqual(filtered[1].text, "Another alpha")
        XCTAssertEqual(filtered.count, 2)
    }
}
