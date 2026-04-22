//
//  NewTaskStickyModeTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class NewTaskStickyModeTests: XCTestCase {

    private var store: NewTaskStickyStore!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use an isolated UserDefaults suite so tests don't pollute the real store
        let suiteName = "test.stickyMode.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = NewTaskStickyStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.description)
        defaults = nil
        store = nil
        super.tearDown()
    }

    // MARK: - save / load

    func testSave_persistsAllFields() {
        store.save(
            hasDueDate: true,
            dueDate: Date(timeIntervalSince1970: 1_000_000),
            estimateHours: 2,
            estimateMinutes: 30,
            switchToTask: true,
            copyNotes: false
        )

        XCTAssertTrue(defaults.bool(forKey: "newTaskStickyHasDueDate"))
        XCTAssertEqual(defaults.double(forKey: "newTaskStickyDueDate"), 1_000_000, accuracy: 0.001)
        XCTAssertEqual(defaults.integer(forKey: "newTaskStickyEstimateHours"), 2)
        XCTAssertEqual(defaults.integer(forKey: "newTaskStickyEstimateMinutes"), 30)
        XCTAssertTrue(defaults.bool(forKey: "newTaskStickySwitchToTask"))
        XCTAssertFalse(defaults.bool(forKey: "newTaskStickyCopyNotes"))
    }

    func testLoad_returnsPersistedValues() {
        defaults.set(true, forKey: "newTaskStickyHasDueDate")
        defaults.set(Double(9_999_999), forKey: "newTaskStickyDueDate")
        defaults.set(3, forKey: "newTaskStickyEstimateHours")
        defaults.set(45, forKey: "newTaskStickyEstimateMinutes")
        defaults.set(false, forKey: "newTaskStickySwitchToTask")
        defaults.set(true, forKey: "newTaskStickyCopyNotes")

        let loaded = store.load()

        XCTAssertTrue(loaded.hasDueDate)
        XCTAssertEqual(loaded.dueDate.timeIntervalSince1970, 9_999_999, accuracy: 0.001)
        XCTAssertEqual(loaded.estimateHours, 3)
        XCTAssertEqual(loaded.estimateMinutes, 45)
        XCTAssertFalse(loaded.switchToTask)
        XCTAssertTrue(loaded.copyNotes)
    }

    func testLoad_returnsDefaults_whenNothingPersisted() {
        let loaded = store.load()

        XCTAssertFalse(loaded.hasDueDate)
        XCTAssertEqual(loaded.estimateHours, 0)
        XCTAssertEqual(loaded.estimateMinutes, 0)
        XCTAssertFalse(loaded.switchToTask)
        XCTAssertFalse(loaded.copyNotes)
    }

    // MARK: - clear

    func testClear_removesAllPersistedValues() {
        store.save(
            hasDueDate: true,
            dueDate: Date(timeIntervalSince1970: 1_000_000),
            estimateHours: 1,
            estimateMinutes: 15,
            switchToTask: true,
            copyNotes: true
        )

        store.clear()

        XCTAssertFalse(defaults.bool(forKey: "newTaskStickyHasDueDate"))
        XCTAssertEqual(defaults.double(forKey: "newTaskStickyDueDate"), 0)
        XCTAssertEqual(defaults.integer(forKey: "newTaskStickyEstimateHours"), 0)
        XCTAssertEqual(defaults.integer(forKey: "newTaskStickyEstimateMinutes"), 0)
        XCTAssertFalse(defaults.bool(forKey: "newTaskStickySwitchToTask"))
        XCTAssertFalse(defaults.bool(forKey: "newTaskStickyCopyNotes"))
    }

    // MARK: - applyOrReset (the core conditional logic)

    func testApplyOrReset_stickyOff_returnsDefaults() {
        // Pre-populate with non-default values
        store.save(
            hasDueDate: true,
            dueDate: Date(timeIntervalSince1970: 1_000_000),
            estimateHours: 5,
            estimateMinutes: 20,
            switchToTask: true,
            copyNotes: true
        )

        let result = store.applyOrReset(stickyEnabled: false)

        XCTAssertFalse(result.hasDueDate)
        XCTAssertEqual(result.estimateHours, 0)
        XCTAssertEqual(result.estimateMinutes, 0)
        XCTAssertFalse(result.switchToTask)
        XCTAssertFalse(result.copyNotes)
    }

    func testApplyOrReset_stickyOn_returnsPersistedValues() {
        store.save(
            hasDueDate: true,
            dueDate: Date(timeIntervalSince1970: 5_000_000),
            estimateHours: 1,
            estimateMinutes: 30,
            switchToTask: true,
            copyNotes: false
        )

        let result = store.applyOrReset(stickyEnabled: true)

        XCTAssertTrue(result.hasDueDate)
        XCTAssertEqual(result.dueDate.timeIntervalSince1970, 5_000_000, accuracy: 0.001)
        XCTAssertEqual(result.estimateHours, 1)
        XCTAssertEqual(result.estimateMinutes, 30)
        XCTAssertTrue(result.switchToTask)
        XCTAssertFalse(result.copyNotes)
    }

    func testApplyOrReset_stickyOn_noPersistedValues_returnsDefaults() {
        let result = store.applyOrReset(stickyEnabled: true)

        XCTAssertFalse(result.hasDueDate)
        XCTAssertEqual(result.estimateHours, 0)
        XCTAssertEqual(result.estimateMinutes, 0)
        XCTAssertFalse(result.switchToTask)
        XCTAssertFalse(result.copyNotes)
    }

    // MARK: - title is never persisted

    func testSave_doesNotPersistTitle() {
        // There should be no title key at all — callers always reset title to ""
        store.save(
            hasDueDate: false,
            dueDate: Date(),
            estimateHours: 0,
            estimateMinutes: 0,
            switchToTask: false,
            copyNotes: false
        )

        XCTAssertNil(defaults.object(forKey: "newTaskStickyTitle"),
                     "Title must never be persisted by NewTaskStickyStore")
    }
}
