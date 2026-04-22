//
//  FloatingWindowVisibilityTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class FloatingWindowVisibilityTests: XCTestCase {

    func testDefaultVisibility_allTrue() {
        let sut = FloatingWindowVisibility()
        XCTAssertTrue(sut.showDescription)
        XCTAssertTrue(sut.showTimers)
        XCTAssertTrue(sut.showSubtasks)
    }

    func testToggleDescription_becomesHidden() {
        var sut = FloatingWindowVisibility()
        sut.showDescription.toggle()
        XCTAssertFalse(sut.showDescription)
    }

    func testToggleDescription_twice_restoresTrue() {
        var sut = FloatingWindowVisibility()
        sut.showDescription.toggle()
        sut.showDescription.toggle()
        XCTAssertTrue(sut.showDescription)
    }

    func testToggleTimers_becomesHidden() {
        var sut = FloatingWindowVisibility()
        sut.showTimers.toggle()
        XCTAssertFalse(sut.showTimers)
    }

    func testToggleTimers_twice_restoresTrue() {
        var sut = FloatingWindowVisibility()
        sut.showTimers.toggle()
        sut.showTimers.toggle()
        XCTAssertTrue(sut.showTimers)
    }

    func testToggleSubtasks_becomesHidden() {
        var sut = FloatingWindowVisibility()
        sut.showSubtasks.toggle()
        XCTAssertFalse(sut.showSubtasks)
    }

    func testToggleSubtasks_twice_restoresTrue() {
        var sut = FloatingWindowVisibility()
        sut.showSubtasks.toggle()
        sut.showSubtasks.toggle()
        XCTAssertTrue(sut.showSubtasks)
    }

    func testAllHidden_canBeRestored() {
        var sut = FloatingWindowVisibility()
        sut.showDescription = false
        sut.showTimers = false
        sut.showSubtasks = false

        sut.showDescription = true
        sut.showTimers = true
        sut.showSubtasks = true

        XCTAssertTrue(sut.showDescription)
        XCTAssertTrue(sut.showTimers)
        XCTAssertTrue(sut.showSubtasks)
    }
}
