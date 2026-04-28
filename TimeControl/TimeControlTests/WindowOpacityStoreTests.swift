//
//  WindowOpacityStoreTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class WindowOpacityStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "WindowOpacityStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Defaults

    func testCurrentTaskOpacity_defaultsToOne_whenNothingSaved() {
        let store = WindowOpacityStore(defaults: defaults)
        XCTAssertEqual(store.currentTaskOpacity, 1.0, accuracy: 0.001)
    }

    func testNotesOpacity_defaultsToOne_whenNothingSaved() {
        let store = WindowOpacityStore(defaults: defaults)
        XCTAssertEqual(store.notesOpacity, 1.0, accuracy: 0.001)
    }

    // MARK: - Round trip per window

    func testCurrentTaskOpacity_roundTrip() {
        let store = WindowOpacityStore(defaults: defaults)
        store.currentTaskOpacity = 0.5
        XCTAssertEqual(store.currentTaskOpacity, 0.5, accuracy: 0.001)

        // Same key, fresh instance — must persist via UserDefaults.
        let other = WindowOpacityStore(defaults: defaults)
        XCTAssertEqual(other.currentTaskOpacity, 0.5, accuracy: 0.001)
    }

    func testNotesOpacity_roundTrip() {
        let store = WindowOpacityStore(defaults: defaults)
        store.notesOpacity = 0.42
        let other = WindowOpacityStore(defaults: defaults)
        XCTAssertEqual(other.notesOpacity, 0.42, accuracy: 0.001)
    }

    // MARK: - Independent keys

    func testCurrentTaskAndNotes_useIndependentKeys() {
        let store = WindowOpacityStore(defaults: defaults)
        store.currentTaskOpacity = 0.3
        store.notesOpacity = 0.9
        XCTAssertEqual(store.currentTaskOpacity, 0.3, accuracy: 0.001)
        XCTAssertEqual(store.notesOpacity, 0.9, accuracy: 0.001)
    }

    // MARK: - Clamping

    func testSetBelowMinimum_clampsToMinimum() {
        let store = WindowOpacityStore(defaults: defaults)
        store.currentTaskOpacity = 0.0
        XCTAssertEqual(store.currentTaskOpacity, WindowOpacityStore.minimum, accuracy: 0.001)
    }

    func testSetNegative_clampsToMinimum() {
        let store = WindowOpacityStore(defaults: defaults)
        store.notesOpacity = -1.0
        XCTAssertEqual(store.notesOpacity, WindowOpacityStore.minimum, accuracy: 0.001)
    }

    func testSetAboveMaximum_clampsToOne() {
        let store = WindowOpacityStore(defaults: defaults)
        store.currentTaskOpacity = 1.5
        XCTAssertEqual(store.currentTaskOpacity, 1.0, accuracy: 0.001)
    }

    func testMinimumIsTwoTenths() {
        // The plan stipulates a 0.20 floor so the user can't make a window invisible.
        XCTAssertEqual(WindowOpacityStore.minimum, 0.2, accuracy: 0.001)
    }
}
