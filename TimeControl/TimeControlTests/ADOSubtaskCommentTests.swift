//
//  ADOSubtaskCommentTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

// Tests for Phase 8: when a subtask is completed on an ADO-linked task,
// the user should be prompted to push a completion comment to ADO.

final class ADOSubtaskCommentTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    // MARK: - SubtaskCommentPromptStore

    func testAlwaysDefaultsToFalse() {
        let store = SubtaskCommentPromptStore(defaults: makeDefaults())
        let taskId = UUID()
        XCTAssertFalse(store.alwaysPost(for: taskId))
    }

    func testSetAlwaysPostPersists() {
        let store = SubtaskCommentPromptStore(defaults: makeDefaults())
        let taskId = UUID()
        store.setAlwaysPost(true, for: taskId)
        XCTAssertTrue(store.alwaysPost(for: taskId))
    }

    func testSetAlwaysPostFalseClears() {
        let defaults = makeDefaults()
        let store = SubtaskCommentPromptStore(defaults: defaults)
        let taskId = UUID()
        store.setAlwaysPost(true, for: taskId)
        store.setAlwaysPost(false, for: taskId)
        XCTAssertFalse(store.alwaysPost(for: taskId))
    }

    func testAlwaysPostIsPerTask() {
        let store = SubtaskCommentPromptStore(defaults: makeDefaults())
        let taskA = UUID()
        let taskB = UUID()
        store.setAlwaysPost(true, for: taskA)
        XCTAssertTrue(store.alwaysPost(for: taskA))
        XCTAssertFalse(store.alwaysPost(for: taskB))
    }

    // MARK: - SubtaskCompletionCommentBody

    func testCommentBodyFormatIncludesSubtaskTitle() {
        let body = SubtaskCompletionCommentBody.text(for: "Wire up retry button")
        XCTAssertTrue(body.contains("Wire up retry button"))
    }

    func testCommentBodyFormatIncludesCheckmark() {
        let body = SubtaskCompletionCommentBody.text(for: "Any subtask")
        XCTAssertTrue(body.contains("✓") || body.contains("completed") || body.contains("Completed"))
    }
}
