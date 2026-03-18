//
//  ModelEnumTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class ModelEnumTests: XCTestCase {

    // MARK: - AutoPauseDuration.displayName

    func testAutoPauseDuration_off_displayName() {
        XCTAssertFalse(AutoPauseDuration.off.displayName.isEmpty)
        XCTAssertEqual(AutoPauseDuration.off.displayName, "Off")
    }

    func testAutoPauseDuration_singular_displayName() {
        XCTAssertEqual(AutoPauseDuration.oneMinute.displayName, "1 minute")
    }

    func testAutoPauseDuration_plural_displayName() {
        XCTAssertEqual(AutoPauseDuration.twoMinutes.displayName, "2 minutes")
        XCTAssertEqual(AutoPauseDuration.tenMinutes.displayName, "10 minutes")
    }

    func testAutoPauseDuration_allCases_haveNonEmptyDisplayName() {
        for kase in AutoPauseDuration.allCases {
            XCTAssertFalse(kase.displayName.isEmpty, "displayName was empty for case \(kase)")
        }
    }

    // MARK: - DefaultTimerDuration.displayName

    func testDefaultTimerDuration_off_displayName() {
        XCTAssertEqual(DefaultTimerDuration.off.displayName, "Off")
    }

    func testDefaultTimerDuration_oneHour_displayName() {
        XCTAssertEqual(DefaultTimerDuration.oneHour.displayName, "1 hour")
    }

    func testDefaultTimerDuration_ninetyMinutes_displayName() {
        XCTAssertEqual(DefaultTimerDuration.ninetyMinutes.displayName, "1.5 hours")
    }

    func testDefaultTimerDuration_twoHours_displayName() {
        XCTAssertEqual(DefaultTimerDuration.twoHours.displayName, "2 hours")
    }

    func testDefaultTimerDuration_minuteVariants_displayName() {
        XCTAssertEqual(DefaultTimerDuration.fiveMinutes.displayName, "5 minutes")
        XCTAssertEqual(DefaultTimerDuration.thirtyMinutes.displayName, "30 minutes")
    }

    func testDefaultTimerDuration_allCases_haveNonEmptyDisplayName() {
        for kase in DefaultTimerDuration.allCases {
            XCTAssertFalse(kase.displayName.isEmpty, "displayName was empty for case \(kase)")
        }
    }

    // MARK: - TodoItem.hasActiveNotification

    func testHasActiveNotification_defaultsFalse() {
        let todo = makeTodo()
        XCTAssertFalse(todo.hasActiveNotification)
    }

    func testHasActiveNotification_canBeSetTrue() {
        var todo = makeTodo()
        todo.hasActiveNotification = true
        XCTAssertTrue(todo.hasActiveNotification)
    }

    func testHasActiveNotification_canBeResetToFalse() {
        var todo = makeTodo()
        todo.hasActiveNotification = true
        todo.hasActiveNotification = false
        XCTAssertFalse(todo.hasActiveNotification)
    }

    // MARK: - TodoItem.countdownElapsed

    func testCountdownElapsed_noCountdown_returnsZero() {
        // countdownTime == 0 → always returns 0
        let todo = makeTodo()
        XCTAssertEqual(todo.countdownElapsed, 0)
    }

    func testCountdownElapsed_paused_returnsPausedValue() {
        // Not running (lastStartTime nil), countdownElapsedAtPause set
        var todo = makeTodo()
        todo.countdownTime = 300
        todo.countdownElapsedAtPause = 120
        // isRunning == false because lastStartTime == nil
        XCTAssertEqual(todo.countdownElapsed, 120, accuracy: 0.01)
    }

    func testCountdownElapsed_paused_clampedToCountdownTime() {
        var todo = makeTodo()
        todo.countdownTime = 300
        todo.countdownElapsedAtPause = 400  // exceeds countdownTime
        XCTAssertEqual(todo.countdownElapsed, 300)
    }

    func testCountdownElapsed_running_accumulatesTime() {
        var todo = makeTodo()
        todo.countdownTime = 600
        todo.countdownElapsedAtPause = 100
        todo.lastStartTime = Date(timeIntervalSinceNow: -30)  // makes isRunning == true
        todo.countdownStartTime = Date(timeIntervalSinceNow: -30)

        // elapsed should be ~130 (100 paused + ~30 live)
        XCTAssertGreaterThan(todo.countdownElapsed, 129)
        XCTAssertLessThan(todo.countdownElapsed, 131)
    }

    func testCountdownElapsed_running_clampedToCountdownTime() {
        var todo = makeTodo()
        todo.countdownTime = 50
        todo.countdownElapsedAtPause = 40
        todo.lastStartTime = Date(timeIntervalSinceNow: -20)  // isRunning == true
        todo.countdownStartTime = Date(timeIntervalSinceNow: -20)

        // Would be ~60 but capped at countdownTime (50)
        XCTAssertEqual(todo.countdownElapsed, 50)
    }
}
