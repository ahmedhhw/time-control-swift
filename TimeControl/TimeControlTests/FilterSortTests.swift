//
//  FilterSortTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class FilterSortTests: XCTestCase {

    var vm: TodoViewModel!

    override func setUp() {
        super.setUp()
        let (freshVm, _, _) = makeViewModel()
        vm = freshVm
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    // MARK: - Filter text

    func testFilterText_matchesTitle() {
        let items = [makeTodo(text: "Write report"), makeTodo(text: "Buy groceries")]
        vm.filterText = "write"
        let result = vm.filterTodos(items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Write report")
    }

    func testFilterText_matchesSubtaskTitle() {
        let sub = makeSubtask(title: "Design mockup")
        let items = [makeTodo(text: "Sprint tasks", subtasks: [sub]), makeTodo(text: "Other")]
        vm.filterText = "design"
        let result = vm.filterTodos(items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Sprint tasks")
    }

    func testFilterText_matchesFromWho() {
        let withFromWho = TodoItem(text: "Review PR", fromWho: "Alice")
        let items = [withFromWho, makeTodo(text: "Other")]
        vm.filterText = "alice"
        let result = vm.filterTodos(items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Review PR")
    }

    func testFilterText_emptyQuery_returnsAll() {
        let items = [makeTodo(text: "A"), makeTodo(text: "B"), makeTodo(text: "C")]
        vm.filterText = ""
        let result = vm.filterTodos(items)
        XCTAssertEqual(result.count, 3)
    }

    func testFilterText_whitespaceOnly_returnsAll() {
        let items = [makeTodo(text: "A"), makeTodo(text: "B")]
        vm.filterText = "   "
        let result = vm.filterTodos(items)
        XCTAssertEqual(result.count, 2)
    }

    func testFilterText_caseInsensitive() {
        let items = [makeTodo(text: "URGENT task"), makeTodo(text: "normal")]
        vm.filterText = "urgent"
        let result = vm.filterTodos(items)
        XCTAssertEqual(result.count, 1)
    }

    func testFilterText_noMatch_returnsEmpty() {
        let items = [makeTodo(text: "Buy milk"), makeTodo(text: "Send email")]
        vm.filterText = "xyz"
        let result = vm.filterTodos(items)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Sort options

    func testSortOption_recentlyPlayed_orderedByLastPlayedAt() {
        vm.isAdvancedMode = true
        vm.sortOption = .recentlyPlayedNewest
        var older = makeTodo(text: "Older")
        var newer = makeTodo(text: "Newer")
        older.lastPlayedAt = Date().timeIntervalSince1970 - 100
        newer.lastPlayedAt = Date().timeIntervalSince1970
        let result = vm.sortTodos([older, newer])
        XCTAssertEqual(result[0].text, "Newer")
        XCTAssertEqual(result[1].text, "Older")
    }

    func testSortOption_recentlyPlayed_unplayedAfterPlayed() {
        vm.isAdvancedMode = true
        vm.sortOption = .recentlyPlayedNewest
        let unplayed = makeTodo(text: "Unplayed")
        var played = makeTodo(text: "Played")
        played.lastPlayedAt = Date().timeIntervalSince1970
        let result = vm.sortTodos([unplayed, played])
        XCTAssertEqual(result[0].text, "Played")
        XCTAssertEqual(result[1].text, "Unplayed")
    }

    func testSortOption_dueDate_nearestFirst() {
        vm.isAdvancedMode = true
        vm.sortOption = .dueDateNearest
        var farther = makeTodo(text: "Farther")
        var nearer = makeTodo(text: "Nearer")
        farther.dueDate = Date().addingTimeInterval(7200)
        nearer.dueDate = Date().addingTimeInterval(3600)
        let result = vm.sortTodos([farther, nearer])
        XCTAssertEqual(result[0].text, "Nearer")
        XCTAssertEqual(result[1].text, "Farther")
    }

    func testSortOption_dueDate_tasksWithDueDateBeforeTasksWithout() {
        vm.isAdvancedMode = true
        vm.sortOption = .dueDateNearest
        let noDueDate = makeTodo(text: "No due date")
        var withDueDate = makeTodo(text: "Has due date")
        withDueDate.dueDate = Date().addingTimeInterval(3600)
        let result = vm.sortTodos([noDueDate, withDueDate])
        XCTAssertEqual(result[0].text, "Has due date")
        XCTAssertEqual(result[1].text, "No due date")
    }

    func testSortOption_creationDate_newestFirst() {
        vm.isAdvancedMode = true
        vm.sortOption = .creationDateNewest
        let older = TodoItem(text: "Old", createdAt: 1_000_000)
        let newer = TodoItem(text: "New", createdAt: 2_000_000)
        let result = vm.sortTodos([older, newer])
        XCTAssertEqual(result[0].text, "New")
        XCTAssertEqual(result[1].text, "Old")
    }

    func testSortOption_creationDate_oldestFirst() {
        vm.isAdvancedMode = true
        vm.sortOption = .creationDateOldest
        let older = TodoItem(text: "Old", createdAt: 1_000_000)
        let newer = TodoItem(text: "New", createdAt: 2_000_000)
        let result = vm.sortTodos([older, newer])
        XCTAssertEqual(result[0].text, "Old")
        XCTAssertEqual(result[1].text, "New")
    }

    func testSortOption_notAdvancedMode_sortsByIndex() {
        vm.isAdvancedMode = false
        let first = TodoItem(text: "First", index: 0, createdAt: 2_000_000)
        let second = TodoItem(text: "Second", index: 1, createdAt: 1_000_000)
        // second was created earlier but has a higher index
        let result = vm.sortTodos([second, first])
        XCTAssertEqual(result[0].text, "First")
        XCTAssertEqual(result[1].text, "Second")
    }

    // MARK: - Incomplete / Completed computed properties

    func testIncompleteTodos_excludesCompleted() {
        vm.todos = [makeTodo(text: "Done", isCompleted: true), makeTodo(text: "Pending")]
        XCTAssertEqual(vm.incompleteTodos.count, 1)
        XCTAssertEqual(vm.incompleteTodos[0].text, "Pending")
    }

    func testCompletedTodos_excludesIncomplete() {
        vm.todos = [makeTodo(text: "Done", isCompleted: true), makeTodo(text: "Pending")]
        XCTAssertEqual(vm.completedTodos.count, 1)
        XCTAssertEqual(vm.completedTodos[0].text, "Done")
    }

    func testIncompleteTodos_emptyWhenAllComplete() {
        vm.todos = [makeTodo(isCompleted: true), makeTodo(isCompleted: true)]
        XCTAssertTrue(vm.incompleteTodos.isEmpty)
    }

    func testCompletedTodos_emptyWhenNoneComplete() {
        vm.todos = [makeTodo(), makeTodo()]
        XCTAssertTrue(vm.completedTodos.isEmpty)
    }

    func testIncompleteTodos_respectsFilterText() {
        vm.todos = [makeTodo(text: "Write docs"), makeTodo(text: "Buy milk")]
        vm.filterText = "write"
        XCTAssertEqual(vm.incompleteTodos.count, 1)
        XCTAssertEqual(vm.incompleteTodos[0].text, "Write docs")
    }
}
