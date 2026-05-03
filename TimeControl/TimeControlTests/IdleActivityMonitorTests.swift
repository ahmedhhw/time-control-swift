//
//  IdleActivityMonitorTests.swift
//  TimeControlTests
//

import XCTest
import Combine
@testable import TimeControl

// MARK: - Fake timer helpers (test-only)

/// A controllable fake timer. Tests drive it by calling `fire()` manually.
final class FakeRepeatTimer: RepeatTimer {
    let block: () -> Void
    private(set) var isCancelled = false

    init(block: @escaping () -> Void) {
        self.block = block
    }

    func fire() {
        guard !isCancelled else { return }
        block()
    }

    func cancel() {
        isCancelled = true
    }
}

/// Captures the last timer created so tests can drive it.
final class FakeTimerFactory {
    private(set) var lastTimer: FakeRepeatTimer?

    func makeTimer(interval: TimeInterval, block: @escaping () -> Void) -> any RepeatTimer {
        let t = FakeRepeatTimer(block: block)
        lastTimer = t
        return t
    }
}

// MARK: - Tests

final class IdleActivityMonitorTests: XCTestCase {

    // Builds a monitor with controllable clock + timer and isolated UserDefaults.
    private func makeMonitorAndDate(
        config: IdlePromptConfig = IdlePromptConfig(enabled: true, activityThresholdSeconds: 10, cooldownSeconds: 1200)
    ) -> (monitor: IdleActivityMonitor, factory: FakeTimerFactory, advance: (TimeInterval) -> Void) {
        var currentDate = Date(timeIntervalSinceReferenceDate: 0)
        let factory = FakeTimerFactory()
        // Use an ephemeral UserDefaults suite so tests never share snooze state.
        let suiteID = "IdleTest-\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suiteID)!
        let monitor = IdleActivityMonitor(
            config: config,
            clock: { currentDate },
            timerFactory: factory.makeTimer,
            userDefaults: ud
        )
        // `advance` mutates currentDate; since the clock closure captures it by reference
        // the monitor's clock automatically returns the new value on next call.
        let advance: (TimeInterval) -> Void = { seconds in
            currentDate = currentDate.addingTimeInterval(seconds)
        }
        return (monitor, factory, advance)
    }

    // MARK: - 1. No prompt when a task is running

    func testNoPrompt_whenTaskIsRunning() {
        let (monitor, factory, advance) = makeMonitorAndDate()
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Active Task")]
        monitor.start(viewModel: vm)

        vm.toggleTimer(vm.todos[0])
        waitForMainQueue(timeout: 0.2)

        monitor.testOnly_recordActivity()

        for _ in 0..<5 { factory.lastTimer.map { ($0 as! FakeRepeatTimer).fire() } }

        XCTAssertNotEqual(monitor.state, .promptShown,
            "Prompt must not appear while a task is running")
        XCTAssertEqual(monitor.state, .suppressed,
            "State should be suppressed when a task is running")
    }

    // MARK: - 2. Prompt triggers after activity threshold when no task running

    func testPromptShown_afterActivityThreshold_withNoRunningTask() {
        let (monitor, factory, advance) = makeMonitorAndDate()
        var promptShown = false
        monitor.onShowPrompt = { promptShown = true }

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        monitor.testOnly_recordActivity()  // t=0
        advance(11)                         // t=11 — past 10s threshold
        fireTimer(factory)

        XCTAssertTrue(promptShown, "Prompt should be shown after activity threshold with no running task")
        XCTAssertEqual(monitor.state, .promptShown)
    }

    func testNoPrompt_beforeActivityThreshold() {
        let (monitor, factory, advance) = makeMonitorAndDate()
        var promptShown = false
        monitor.onShowPrompt = { promptShown = true }

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        monitor.testOnly_recordActivity()  // t=0
        advance(5)                          // t=5 — before 10s threshold
        fireTimer(factory)

        XCTAssertFalse(promptShown, "Prompt should not show before activity threshold")
        XCTAssertNotEqual(monitor.state, .promptShown)
    }

    func testNoPrompt_whenDisabled() {
        let config = IdlePromptConfig(enabled: false, activityThresholdSeconds: 10, cooldownSeconds: 1200)
        let (monitor, factory, advance) = makeMonitorAndDate(config: config)
        var promptShown = false
        monitor.onShowPrompt = { promptShown = true }

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        monitor.testOnly_recordActivity()
        advance(20)
        fireTimer(factory)

        XCTAssertFalse(promptShown, "Prompt must not show when feature is disabled")
    }

    // MARK: - 3. No prompt during cooldown

    func testNoPrompt_duringCooldown() {
        let (monitor, factory, advance) = makeMonitorAndDate()
        var promptCount = 0
        monitor.onShowPrompt = { promptCount += 1 }

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        // First prompt at t=11
        monitor.testOnly_recordActivity()
        advance(11)
        fireTimer(factory)
        XCTAssertEqual(promptCount, 1)

        // Dismiss → enters cooldown
        monitor.handleDismiss()
        XCTAssertEqual(monitor.state, .cooldown)

        // Activity at t=50, poll at t=61 — still in 1200s cooldown
        advance(50)
        monitor.testOnly_recordActivity()
        advance(11)
        fireTimer(factory)

        XCTAssertEqual(promptCount, 1, "No second prompt should appear during cooldown")
    }

    func testPromptCanAppear_afterCooldownExpires() {
        let config = IdlePromptConfig(enabled: true, activityThresholdSeconds: 10, cooldownSeconds: 60)
        let (monitor, factory, advance) = makeMonitorAndDate(config: config)
        var promptCount = 0
        monitor.onShowPrompt = { promptCount += 1 }

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        // First prompt
        monitor.testOnly_recordActivity()
        advance(11)
        fireTimer(factory)
        XCTAssertEqual(promptCount, 1)
        monitor.handleDismiss()

        // Advance past the 60s cooldown, then generate activity and poll
        advance(60)           // now at t=71 — cooldown expired
        fireTimer(factory)    // poll: expires cooldown → state=idle

        advance(1)            // t=72
        monitor.testOnly_recordActivity()
        advance(11)           // t=83
        fireTimer(factory)

        XCTAssertEqual(promptCount, 2, "Prompt should appear again after cooldown expires")
    }

    // MARK: - 4. State transitions: idle → active → promptShown → cooldown → idle

    func testStateTransition_idle_to_active() {
        let (monitor, _, _) = makeMonitorAndDate()
        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        XCTAssertEqual(monitor.state, .idle, "Initial state should be idle")

        monitor.testOnly_recordActivity()
        XCTAssertEqual(monitor.state, .active, "State should become active after recording activity")
    }

    func testStateTransition_active_to_promptShown() {
        let (monitor, factory, advance) = makeMonitorAndDate()
        var promptShown = false
        monitor.onShowPrompt = { promptShown = true }

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        monitor.testOnly_recordActivity()
        XCTAssertEqual(monitor.state, .active)

        advance(11)
        fireTimer(factory)

        XCTAssertEqual(monitor.state, .promptShown)
        XCTAssertTrue(promptShown)
    }

    func testStateTransition_promptShown_to_cooldown_onDismiss() {
        let (monitor, factory, advance) = makeMonitorAndDate()
        monitor.onShowPrompt = {}

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        monitor.testOnly_recordActivity()
        advance(11)
        fireTimer(factory)
        XCTAssertEqual(monitor.state, .promptShown)

        monitor.handleDismiss()
        XCTAssertEqual(monitor.state, .cooldown)
    }

    func testStateTransition_cooldown_to_idle_afterExpiry() {
        let config = IdlePromptConfig(enabled: true, activityThresholdSeconds: 10, cooldownSeconds: 60)
        let (monitor, factory, advance) = makeMonitorAndDate(config: config)
        monitor.onShowPrompt = {}

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        monitor.testOnly_recordActivity()
        advance(11)
        fireTimer(factory)
        monitor.handleDismiss()
        XCTAssertEqual(monitor.state, .cooldown)

        // Advance past 60s cooldown and fire poll
        advance(70)
        fireTimer(factory)

        XCTAssertEqual(monitor.state, .idle,
            "State should return to idle after cooldown expires with no recent activity")
    }

    // MARK: - 5. State goes to suppressed when task starts

    func testState_becomesSuppressed_whenTaskStarts() {
        let (monitor, _, _) = makeMonitorAndDate()
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Work")]
        monitor.start(viewModel: vm)

        XCTAssertEqual(monitor.state, .idle)

        vm.toggleTimer(vm.todos[0])
        waitForMainQueue(timeout: 0.2)

        XCTAssertEqual(monitor.state, .suppressed,
            "State must become suppressed when a task starts running")
    }

    func testState_suppressed_preventsCooldownOrPrompt() {
        let (monitor, factory, advance) = makeMonitorAndDate()
        var promptShown = false
        monitor.onShowPrompt = { promptShown = true }

        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Work")]
        monitor.start(viewModel: vm)
        vm.toggleTimer(vm.todos[0])
        waitForMainQueue(timeout: 0.2)

        monitor.testOnly_recordActivity()
        advance(30)
        fireTimer(factory)

        XCTAssertFalse(promptShown)
        XCTAssertEqual(monitor.state, .suppressed)
    }

    // MARK: - 6. State returns to idle when task stops

    func testState_returnsToIdle_whenTaskStops() {
        let (monitor, _, _) = makeMonitorAndDate()
        let (vm, _, _) = makeViewModel()
        vm.todos = [makeTodo(text: "Work")]
        monitor.start(viewModel: vm)

        vm.toggleTimer(vm.todos[0])
        waitForMainQueue(timeout: 0.2)
        XCTAssertEqual(monitor.state, .suppressed)

        vm.toggleTimer(vm.todos[0]) // pause/stop
        waitForMainQueue(timeout: 0.2)

        XCTAssertEqual(monitor.state, .idle,
            "State must return to idle when the running task stops")
    }

    // MARK: - 7. Max prompts per day

    func testMaxThreePromptsPerDay() {
        // Use a short cooldown so we can cycle quickly
        let config = IdlePromptConfig(enabled: true, activityThresholdSeconds: 10, cooldownSeconds: 1)
        let (monitor, factory, advance) = makeMonitorAndDate(config: config)
        var promptCount = 0
        monitor.onShowPrompt = { promptCount += 1 }

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        // Attempt to trigger 5 prompts — only 3 should fire
        for _ in 0..<5 {
            monitor.testOnly_recordActivity()
            advance(11)
            fireTimer(factory)

            if monitor.state == .promptShown {
                monitor.handleDismiss()
            }
            // Expire cooldown (cooldownSeconds=1)
            advance(2)
            fireTimer(factory) // transitions cooldown→idle
        }

        XCTAssertEqual(promptCount, 3, "At most 3 prompts should show per day")
    }

    // MARK: - 8. Snooze

    func testSnooze_suppressesPromptForDuration() {
        let (monitor, factory, advance) = makeMonitorAndDate()
        var promptCount = 0
        monitor.onShowPrompt = { promptCount += 1 }

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        // First prompt at t=11
        monitor.testOnly_recordActivity()
        advance(11)
        fireTimer(factory)
        XCTAssertEqual(promptCount, 1)

        // Snooze for 30 minutes
        monitor.handleSnooze(minutes: 30)
        XCTAssertEqual(monitor.state, .snoozed)

        // Activity 5 min later — still snoozed (t=16)
        advance(5 * 60)
        monitor.testOnly_recordActivity()
        advance(11)
        fireTimer(factory)
        XCTAssertEqual(promptCount, 1, "Prompt should not appear while snoozed")

        // After 30-min snooze expires.
        // We're at t=362 (11 + 300 + 11). snoozeUntil = 11 + 1800 = 1811.
        // Advance past 1811 to expire it.
        advance(1500)           // t = 362 + 1500 = 1862 — snooze expired
        fireTimer(factory)      // poll: now >= snoozeUntil → state = .idle

        XCTAssertEqual(monitor.state, .idle, "State should be idle after snooze expires")

        monitor.testOnly_recordActivity()
        advance(11)
        fireTimer(factory)
        XCTAssertEqual(promptCount, 2, "Prompt should appear after snooze period ends")
    }

    // MARK: - 9. handleStartTask sets state to suppressed

    func testHandleStartTask_setsSuppressed() {
        let (monitor, factory, advance) = makeMonitorAndDate()
        monitor.onShowPrompt = {}

        let (vm, _, _) = makeViewModel()
        monitor.start(viewModel: vm)

        monitor.testOnly_recordActivity()
        advance(11)
        fireTimer(factory)
        XCTAssertEqual(monitor.state, .promptShown)

        monitor.handleStartTask()
        XCTAssertEqual(monitor.state, .suppressed,
            "Clicking Start a Task should move to suppressed state")
    }

    // MARK: - Helpers

    private func fireTimer(_ factory: FakeTimerFactory) {
        (factory.lastTimer as? FakeRepeatTimer)?.fire()
    }

    /// Pumps the main RunLoop until the given timeout, allowing async Combine
    /// subscriptions (`.receive(on: DispatchQueue.main)`) to fire.
    private func waitForMainQueue(timeout: TimeInterval = 0.2) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }
}
