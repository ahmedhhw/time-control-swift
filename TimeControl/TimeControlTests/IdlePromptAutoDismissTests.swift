//
//  IdlePromptAutoDismissTests.swift
//  TimeControlTests
//

import XCTest
import Combine
@testable import TimeControl

final class IdlePromptAutoDismissTests: XCTestCase {

    // MARK: - Helpers

    private func makeMonitor(
        config: IdlePromptConfig = IdlePromptConfig(enabled: true, activityThresholdSeconds: 10, cooldownSeconds: 1200)
    ) -> (monitor: IdleActivityMonitor, factory: FakeTimerFactory, advance: (TimeInterval) -> Void) {
        var currentDate = Date(timeIntervalSinceReferenceDate: 0)
        let factory = FakeTimerFactory()
        let suiteID = "AutoDismissTest-\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suiteID)!
        let monitor = IdleActivityMonitor(
            config: config,
            clock: { currentDate },
            timerFactory: factory.makeTimer,
            userDefaults: ud
        )
        let advance: (TimeInterval) -> Void = { seconds in
            currentDate = currentDate.addingTimeInterval(seconds)
        }
        return (monitor, factory, advance)
    }

    private func fireTimer(_ factory: FakeTimerFactory) {
        (factory.lastTimer as? FakeRepeatTimer)?.fire()
    }

    private func waitForMain(timeout: TimeInterval = 0.2) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    // MARK: - Tests

    /// When the monitor transitions to .suppressed (task started), the window manager's
    /// onDismiss callback must be invoked — proving dismiss() was called.
    func testAutoDismiss_whenMonitorBecomesSupressed_viaTaskStart() {
        let (monitor, factory, advance) = makeMonitor()
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Work")]
        monitor.start(viewModel: vm)

        // Bring the prompt up
        monitor.testOnly_recordActivity()
        advance(11)
        fireTimer(factory)
        XCTAssertEqual(monitor.state, .promptShown)

        // Subscribe the window manager to the monitor
        let windowManager = IdlePromptWindowManager.shared
        var dismissCallCount = 0
        windowManager.onDismiss = { dismissCallCount += 1 }
        windowManager.subscribeToMonitor(monitor)

        // Start a task — monitor goes .suppressed
        vm.toggleTimer(vm.todos[0])
        waitForMain()

        XCTAssertEqual(monitor.state, .suppressed)
        XCTAssertGreaterThanOrEqual(dismissCallCount, 1,
            "dismiss() must be called when monitor state becomes .suppressed")
    }

    /// When a task is already running (monitor is .suppressed from the start),
    /// subscribing should NOT immediately trigger a spurious dismiss.
    func testNoDismiss_whenAlreadySuppressedBeforeSubscribing() {
        let (monitor, _, _) = makeMonitor()
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Work")]
        monitor.start(viewModel: vm)

        // Start the task first — state is .suppressed
        vm.toggleTimer(vm.todos[0])
        waitForMain()
        XCTAssertEqual(monitor.state, .suppressed)

        let windowManager = IdlePromptWindowManager.shared
        var dismissCallCount = 0
        windowManager.onDismiss = { dismissCallCount += 1 }
        windowManager.subscribeToMonitor(monitor)

        waitForMain()

        // The initial published value fires synchronously; we only want to dismiss
        // when transitioning TO .suppressed while the prompt is shown.
        // Since the prompt was never shown, dismiss should not be called.
        XCTAssertEqual(dismissCallCount, 0,
            "dismiss() must not fire for the initial .suppressed value when prompt was never shown")
    }

    /// Going from .suppressed back to .idle (task stops) must not call dismiss.
    func testNoDismiss_whenMonitorBecomesIdle() {
        let (monitor, _, _) = makeMonitor()
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Work")]
        monitor.start(viewModel: vm)

        vm.toggleTimer(vm.todos[0])
        waitForMain()

        let windowManager = IdlePromptWindowManager.shared
        var dismissCallCount = 0
        windowManager.onDismiss = { dismissCallCount += 1 }
        windowManager.subscribeToMonitor(monitor)

        // Stop the task — monitor goes .idle
        vm.toggleTimer(vm.todos[0])
        waitForMain()

        XCTAssertEqual(monitor.state, .idle)
        XCTAssertEqual(dismissCallCount, 0,
            "dismiss() must not be called when state becomes .idle")
    }
}
