//
//  TaskPaletteWindowManagerTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class TaskPaletteWindowManagerTests: XCTestCase {

    private var manager: TaskPaletteWindowManager!

    override func setUp() {
        super.setUp()
        manager = TaskPaletteWindowManager()
    }

    override func tearDown() {
        manager.dismiss()
        manager = nil
        super.tearDown()
    }

    // MARK: - Visibility

    func testShow_makesWindowVisible() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Alpha"), makeTodo(text: "Beta")]

        manager.show(viewModel: vm)

        XCTAssertTrue(manager.isVisible, "Panel should be visible after show()")
    }

    func testDismiss_hidesWindow() {
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        XCTAssertTrue(manager.isVisible)

        manager.dismiss()

        XCTAssertFalse(manager.isVisible, "Panel should not be visible after dismiss()")
    }

    func testShowTwice_doesNotStackPanels() {
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        manager.show(viewModel: vm)

        // Still visible — not crashed or doubled up
        XCTAssertTrue(manager.isVisible)
    }

    // MARK: - onDismiss callback

    func testDismiss_callsOnDismissCallback() {
        let (vm, _, _) = makeViewModel()
        var called = false
        manager.onDismiss = { called = true }

        manager.show(viewModel: vm)
        manager.dismiss()

        XCTAssertTrue(called, "onDismiss callback should be invoked by dismiss()")
    }

    func testOnDismiss_notCalledIfNeverShown() {
        var called = false
        manager.onDismiss = { called = true }

        manager.dismiss()

        XCTAssertFalse(called, "onDismiss must not fire if show() was never called")
    }
}
