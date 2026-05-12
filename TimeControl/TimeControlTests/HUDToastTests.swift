//
//  HUDToastTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

@MainActor
final class HUDToastTests: XCTestCase {

    // MARK: - Toggle timer action

    func test_toggleTimerStartsTask() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Fix crash")
        vm.todos = [task]

        KeyboardShortcutManager.shared.performToggleTimerKeepWindow(viewModel: vm)

        XCTAssertEqual(vm.runningTaskId, task.id)
    }

    func test_toggleTimerPausesRunningTask() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Fix crash")
        vm.todos = [task]
        vm.toggleTimer(task)  // start it

        KeyboardShortcutManager.shared.performToggleTimerKeepWindow(viewModel: vm)

        // keepWindowOpen: true keeps runningTaskId set; only lastStartTime is cleared
        XCTAssertEqual(vm.runningTaskId, task.id)
        XCTAssertNil(vm.todos.first(where: { $0.id == task.id })?.lastStartTime)
    }

    func test_toggleTimerNoOpWhenNoTasks() {
        let (vm, _, _) = makeViewModel()
        vm.todos = []

        // Should not crash
        KeyboardShortcutManager.shared.performToggleTimerKeepWindow(viewModel: vm)

        XCTAssertNil(vm.runningTaskId)
    }

    func test_toggleTimerResumesLastPlayedWhenNoneRunning() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Fix crash")
        vm.todos = [task]
        vm.toggleTimer(task)      // start
        vm.pauseTask(task.id, keepWindowOpen: false)  // pause — now nothing running but lastPlayedAt is set

        KeyboardShortcutManager.shared.performToggleTimerKeepWindow(viewModel: vm)

        XCTAssertEqual(vm.runningTaskId, task.id)
    }

    // MARK: - HUD message

    func test_hudMessageAfterPause() {
        let hud = HUDToastController()
        let task = makeTodo(text: "Fix crash")

        hud.show(action: .paused, taskName: task.text)

        XCTAssertTrue(hud.currentMessage.contains("Fix crash"))
        XCTAssertTrue(hud.currentMessage.lowercased().contains("paused"))
    }

    func test_hudMessageAfterResume() {
        let hud = HUDToastController()
        let task = makeTodo(text: "Fix crash")

        hud.show(action: .resumed, taskName: task.text)

        XCTAssertTrue(hud.currentMessage.contains("Fix crash"))
        XCTAssertTrue(hud.currentMessage.lowercased().contains("resumed"))
    }

    func test_hudDismissesAfterDelay() {
        let hud = HUDToastController()
        hud.show(action: .paused, taskName: "Some task")

        let expectation = XCTestExpectation(description: "HUD dismisses")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            XCTAssertFalse(hud.isVisible)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4.0)
    }
}
