//
//  QuickTimerWindowTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

@MainActor
final class QuickTimerWindowTests: XCTestCase {

    // MARK: - QuickTimerWindowManager lifecycle

    func test_showManager_setsIsVisible() {
        let manager = QuickTimerWindowManager()
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        XCTAssertTrue(manager.isVisible)
    }

    func test_dismissManager_clearsIsVisible() {
        let manager = QuickTimerWindowManager()
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        manager.dismiss()
        XCTAssertFalse(manager.isVisible)
    }

    func test_showTwice_doesNotStackPanels() {
        let manager = QuickTimerWindowManager()
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        manager.show(viewModel: vm)
        XCTAssertTrue(manager.isVisible)
    }

    func test_dismissWhenNotShown_doesNotCrash() {
        let manager = QuickTimerWindowManager()
        manager.dismiss()
        XCTAssertFalse(manager.isVisible)
    }

    // MARK: - QuickTimerController (testable logic, no NSPanel)

    func test_setTimer_callsSetCountdown() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Write tests")
        vm.todos = [task]
        vm.toggleTimer(task)

        let controller = QuickTimerController(viewModel: vm)
        controller.hours = 0
        controller.minutes = 25
        controller.commit()

        let updated = vm.todos.first(where: { $0.id == task.id })
        XCTAssertEqual(updated?.countdownTime, 25 * 60)
    }

    func test_clearTimer_callsClearCountdown() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Write tests")
        vm.todos = [task]
        vm.toggleTimer(task)
        vm.setCountdown(taskId: task.id, time: 600)

        let controller = QuickTimerController(viewModel: vm)
        controller.clear()

        let updated = vm.todos.first(where: { $0.id == task.id })
        XCTAssertEqual(updated?.countdownTime, 0)
    }

    func test_canSet_falseWhenHoursAndMinutesAreZero() {
        let (vm, _, _) = makeViewModel()
        let controller = QuickTimerController(viewModel: vm)
        controller.hours = 0
        controller.minutes = 0
        XCTAssertFalse(controller.canSet)
    }

    func test_canSet_trueWhenMinutesNonZero() {
        let (vm, _, _) = makeViewModel()
        let controller = QuickTimerController(viewModel: vm)
        controller.hours = 0
        controller.minutes = 5
        XCTAssertTrue(controller.canSet)
    }

    func test_noRunningTask_commitDoesNothing() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Idle task")
        vm.todos = [task]

        let controller = QuickTimerController(viewModel: vm)
        controller.hours = 0
        controller.minutes = 10
        controller.commit()

        let updated = vm.todos.first(where: { $0.id == task.id })
        XCTAssertEqual(updated?.countdownTime, 0)
    }

    func test_showsRunningTaskName() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Fix crash")
        vm.todos = [task]
        vm.toggleTimer(task)

        let controller = QuickTimerController(viewModel: vm)
        XCTAssertEqual(controller.runningTaskName, "Fix crash")
    }

    func test_runningTaskName_nilWhenNoTaskRunning() {
        let (vm, _, _) = makeViewModel()
        let task = makeTodo(text: "Fix crash")
        vm.todos = [task]

        let controller = QuickTimerController(viewModel: vm)
        XCTAssertNil(controller.runningTaskName)
    }

    // MARK: - KeyboardShortcutManager setup

    func test_setupRegistersShortcutHandlersWithoutCrashing() {
        let manager = KeyboardShortcutManager()
        let (vm, _, _) = makeViewModel()
        XCTAssertNoThrow(manager.setup(viewModel: vm))
    }
}
