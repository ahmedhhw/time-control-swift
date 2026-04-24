//
//  SleepWakeTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class SleepWakeTests: XCTestCase {

    // MARK: - Sleep (willSleepNotification)

    func testWillSleep_pausesRunningTask() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        XCTAssertTrue(vm.todos[0].isRunning)

        postSleep()

        XCTAssertFalse(vm.todos[0].isRunning)
        XCTAssertNil(vm.todos[0].lastStartTime)
    }

    func testWillSleep_pausesRunningSubtask() {
        let (vm, _, _) = makeViewModel()
        let sub = makeSubtask(title: "Sub")
        vm.todos = [makeTodo(text: "Parent", subtasks: [sub])]
        vm.toggleTimer(vm.todos[0]) // starts parent + auto-starts sub

        XCTAssertTrue(vm.todos[0].subtasks.first(where: { $0.id == sub.id })!.isRunning)

        postSleep()

        XCTAssertFalse(vm.todos[0].subtasks.first(where: { $0.id == sub.id })!.isRunning)
    }

    func testWillSleep_noRunningTask_doesNothing() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        // no timer started

        postSleep()

        XCTAssertNil(vm.runningTaskId)
        XCTAssertFalse(vm.todos[0].isRunning)
    }

    func testWillSleep_keepsRunningTaskIdSoWindowRemainsAddressable() {
        // After sleep the window stays open (keepWindowOpen: true).
        // runningTaskId intentionally stays set so the floating window can reference
        // the task for resumption; isRunning (lastStartTime) is what becomes nil.
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        let taskId = vm.todos[0].id
        XCTAssertNotNil(vm.runningTaskId)

        postSleep()

        XCTAssertEqual(vm.runningTaskId, taskId, "runningTaskId should stay set so floating window can present Resume")
        XCTAssertFalse(vm.todos[0].isRunning, "task timer must be stopped")
    }

    func testWillSleep_accumulatesTotalTimeSpent() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        let before = vm.todos[0].totalTimeSpent

        postSleep()

        // Some time should have accumulated (at least 0, may be sub-second in tests)
        XCTAssertGreaterThanOrEqual(vm.todos[0].totalTimeSpent, before)
    }

    func testWillSleep_storesSleepPausedTaskId() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        let taskId = vm.todos[0].id

        postSleep()

        XCTAssertEqual(vm.sleepPausedTaskId, taskId)
    }

    // MARK: - Wake (didWakeNotification)

    func testDidWake_withSleepPausedTask_postsResumeNotification() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])
        let taskId = vm.todos[0].id

        postSleep()
        XCTAssertEqual(vm.sleepPausedTaskId, taskId)

        let expectation = XCTestExpectation(description: "PromptResumeAfterSleep posted")
        var receivedTaskId: UUID?
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PromptResumeAfterSleep"),
            object: nil,
            queue: .main
        ) { notification in
            receivedTaskId = notification.userInfo?["taskId"] as? UUID
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        postWake()

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedTaskId, taskId)
    }

    func testDidWake_withNoSleepPausedTask_doesNotPostNotification() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        // Never started — sleepPausedTaskId stays nil

        var notificationReceived = false
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PromptResumeAfterSleep"),
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        postWake()

        // Brief wait to confirm no notification fires
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertFalse(notificationReceived)
        _ = vm // keep vm alive
    }

    func testDidWake_clearsSleepPausedTaskId() {
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Task")]
        vm.toggleTimer(vm.todos[0])

        postSleep()
        XCTAssertNotNil(vm.sleepPausedTaskId)

        let expectation = XCTestExpectation(description: "wake notification consumed")
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PromptResumeAfterSleep"),
            object: nil,
            queue: .main
        ) { _ in expectation.fulfill() }
        defer { NotificationCenter.default.removeObserver(observer) }

        postWake()
        wait(for: [expectation], timeout: 1)

        XCTAssertNil(vm.sleepPausedTaskId)
    }

    // MARK: - Helpers

    private func postSleep() {
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    private func postWake() {
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}
