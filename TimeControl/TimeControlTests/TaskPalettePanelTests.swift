//
//  TaskPalettePanelTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

@MainActor
final class TaskPalettePanelTests: XCTestCase {

    // MARK: - TaskPalettePanelManager

    func test_showPanel_setsIsVisible() {
        let manager = TaskPalettePanelManager()
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        XCTAssertTrue(manager.isVisible)
    }

    func test_dismissPanel_clearsIsVisible() {
        let manager = TaskPalettePanelManager()
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        manager.dismiss()
        XCTAssertFalse(manager.isVisible)
    }

    func test_showTwice_doesNotStackPanels() {
        let manager = TaskPalettePanelManager()
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        manager.show(viewModel: vm)
        XCTAssertTrue(manager.isVisible)
    }

    func test_dismissWhenNotShown_doesNotCrash() {
        let manager = TaskPalettePanelManager()
        manager.dismiss()
        XCTAssertFalse(manager.isVisible)
    }

    // MARK: - Elapsed time formatter helper

    func test_elapsedTimeLabel_zeroSeconds_returnsNil() {
        let label = TaskPaletteElapsedTime.label(totalTimeSpent: 0)
        XCTAssertNil(label)
    }

    func test_elapsedTimeLabel_lessThanOneMinute_returnsNil() {
        let label = TaskPaletteElapsedTime.label(totalTimeSpent: 45)
        XCTAssertNil(label)
    }

    func test_elapsedTimeLabel_exactlyOneMinute_returnsLabel() {
        let label = TaskPaletteElapsedTime.label(totalTimeSpent: 60)
        XCTAssertNotNil(label)
        XCTAssertEqual(label, "1m")
    }

    func test_elapsedTimeLabel_90minutes_returnsHoursAndMinutes() {
        let label = TaskPaletteElapsedTime.label(totalTimeSpent: 90 * 60)
        XCTAssertEqual(label, "1h 30m")
    }

    func test_elapsedTimeLabel_exactlyOneHour_returnsHoursOnly() {
        let label = TaskPaletteElapsedTime.label(totalTimeSpent: 3600)
        XCTAssertEqual(label, "1h")
    }

    func test_elapsedTimeLabel_addsRunningSessionTime() {
        var task = makeTodo(text: "Running task")
        task.totalTimeSpent = 60  // 1m stored
        task.lastStartTime = Date(timeIntervalSinceNow: -60)  // running for 1m more
        let label = TaskPaletteElapsedTime.label(task: task)
        // Should reflect at least 2m total
        XCTAssertNotNil(label)
        let minutes = Int((task.totalTimeSpent + 60) / 60)
        XCTAssertTrue(label!.contains("\(minutes)m") || label!.contains("h"))
    }

    // MARK: - KeyboardShortcutManager setup

    func test_setupRegistersShortcutHandlersWithoutCrashing() {
        let manager = KeyboardShortcutManager()
        let (vm, _, _) = makeViewModel()
        XCTAssertNoThrow(manager.setup(viewModel: vm))
    }
}
