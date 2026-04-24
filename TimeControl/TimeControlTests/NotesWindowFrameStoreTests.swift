//
//  NotesWindowFrameStoreTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class NotesWindowFrameStoreTests: XCTestCase {

    private var store: NotesWindowFrameStore!
    private let key = "notesWindowFrame_test"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
        store = NotesWindowFrameStore(userDefaultsKey: key)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    // MARK: - Initial state

    func testLoad_whenNothingSaved_returnsNil() {
        XCTAssertNil(store.load())
    }

    // MARK: - Save / load round-trip

    func testSaveAndLoad_persistsOriginAndSize() {
        let frame = NSRect(x: 120, y: 240, width: 600, height: 450)
        store.save(frame)
        let loaded = store.load()
        XCTAssertEqual(Double(loaded?.origin.x ?? -1), 120, accuracy: 0.5)
        XCTAssertEqual(Double(loaded?.origin.y ?? -1), 240, accuracy: 0.5)
        XCTAssertEqual(Double(loaded?.size.width ?? -1), 600, accuracy: 0.5)
        XCTAssertEqual(Double(loaded?.size.height ?? -1), 450, accuracy: 0.5)
    }

    func testSave_overwritesPreviousFrame() {
        store.save(NSRect(x: 10, y: 10, width: 300, height: 200))
        store.save(NSRect(x: 50, y: 75, width: 700, height: 500))
        let loaded = store.load()!
        XCTAssertEqual(Double(loaded.origin.x), 50, accuracy: 0.5)
        XCTAssertEqual(Double(loaded.origin.y), 75, accuracy: 0.5)
        XCTAssertEqual(Double(loaded.size.width), 700, accuracy: 0.5)
        XCTAssertEqual(Double(loaded.size.height), 500, accuracy: 0.5)
    }

    // MARK: - Clear

    func testClear_makesLoadReturnNil() {
        store.save(NSRect(x: 100, y: 100, width: 400, height: 300))
        XCTAssertNotNil(store.load())
        store.clear()
        XCTAssertNil(store.load())
    }

    // MARK: - Minimum size clamping

    func testLoad_clampsWidthToMinimum() {
        store.save(NSRect(x: 0, y: 0, width: 10, height: 400))
        let loaded = store.load()!
        XCTAssertGreaterThanOrEqual(loaded.size.width, NotesWindowFrameStore.minSize.width)
    }

    func testLoad_clampsHeightToMinimum() {
        store.save(NSRect(x: 0, y: 0, width: 500, height: 5))
        let loaded = store.load()!
        XCTAssertGreaterThanOrEqual(loaded.size.height, NotesWindowFrameStore.minSize.height)
    }

    func testLoad_doesNotClampLegalSize() {
        store.save(NSRect(x: 0, y: 0, width: 500, height: 400))
        let loaded = store.load()!
        XCTAssertEqual(Double(loaded.size.width), 500, accuracy: 0.5)
        XCTAssertEqual(Double(loaded.size.height), 400, accuracy: 0.5)
    }
}
