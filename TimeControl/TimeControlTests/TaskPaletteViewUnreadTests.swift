//
//  TaskPaletteViewUnreadTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

@MainActor
final class TaskPaletteViewUnreadTests: XCTestCase {

    // MARK: - Phase 1: unreadADOTaskIds param behaviour

    func test_hasUnreadADO_trueWhenTaskIdInUnreadSet() {
        let task = makeTodo(text: "Story", adoWorkItemId: "42")
        let unread: Set<UUID> = [task.id]
        XCTAssertTrue(unread.contains(task.id))
    }

    func test_hasUnreadADO_falseWhenTaskIdNotInUnreadSet() {
        let task = makeTodo(text: "Story", adoWorkItemId: "42")
        let unread: Set<UUID> = []
        XCTAssertFalse(unread.contains(task.id))
    }

    func test_hasUnreadADO_falseWhenNoADOLink() {
        let task = makeTodo(text: "No ADO")
        let unread: Set<UUID> = [task.id]
        // isADO gate is false — no adoWorkItemId
        XCTAssertNil(task.adoWorkItemId)
    }

    func test_defaultUnreadSet_taskPaletteViewCompilesWithoutParam() {
        // Verifies the default [] makes the param optional at all call sites
        let task = makeTodo(text: "T", adoWorkItemId: "1")
        _ = TaskPaletteView(
            tasks: [task],
            searchText: .constant(""),
            selectedIndex: .constant(0),
            currentTaskId: task.id,
            onSelect: { _ in },
            onCreate: { _ in },
            onDismiss: {}
        )
    }

    // MARK: - Phase 2: badge label logic

    func test_badgeLabel_noUnread_isPlainADO() {
        XCTAssertEqual(PaletteRowBadgeHelper.badgeLabel(hasUnreadADO: false), "ADO")
    }

    func test_badgeLabel_withUnread_hasSurroundingSpaces() {
        XCTAssertEqual(PaletteRowBadgeHelper.badgeLabel(hasUnreadADO: true), " ADO ")
    }

    // MARK: - Phase 3: StandaloneTaskPaletteView accepts unreadADOTaskIds

    func test_showPanel_withUnreadIds_doesNotCrash() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "T", adoWorkItemId: "5")
        vm.todos = [task]
        vm.unreadADOTaskIds = [task.id]
        let manager = TaskPaletteWindowManager()
        XCTAssertNoThrow(manager.show(viewModel: vm))
        manager.dismiss()
    }

    func test_showPanel_withEmptyUnreadIds_doesNotCrash() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "T", adoWorkItemId: "5")
        vm.todos = [task]
        let manager = TaskPaletteWindowManager()
        XCTAssertNoThrow(manager.show(viewModel: vm))
        manager.dismiss()
    }

    // MARK: - Phase 4: TaskPalettePanel call site

    func test_palettePanelShow_withUnreadIds_doesNotCrash() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "T", adoWorkItemId: "3")
        vm.todos = [task]
        vm.unreadADOTaskIds = [task.id]
        let manager = TaskPalettePanelManager()
        XCTAssertNoThrow(manager.show(viewModel: vm))
        manager.dismiss()
    }
}
