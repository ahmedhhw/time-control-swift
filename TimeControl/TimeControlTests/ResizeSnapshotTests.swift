//
//  ResizeSnapshotTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class ResizeSnapshotTests: XCTestCase {

    // MARK: - Helpers

    private func height(_ snap: ResizeSnapshot) -> CGFloat {
        calculateDynamicHeight(snapshot: snap)
    }

    // MARK: - Cycle 1.0 — Scaffolding

    func test_collapsed_returnsFiftyPoints() {
        let snap = ResizeSnapshot.fixture(isCollapsed: true)
        XCTAssertEqual(height(snap), 50)
    }

    // MARK: - Cycle 1.1 — Minimum clamp (380)

    func test_emptySnapshot_clampsToMinimum380() {
        XCTAssertEqual(height(.fixture()), 380)
    }

    // MARK: - Cycle 1.2 — Maximum clamp (900)

    func test_giantSubtaskHeight_clampsTo900() {
        let snap = ResizeSnapshot.fixture(subtaskContentHeight: 5000)
        XCTAssertEqual(height(snap), 900)
    }

    // MARK: - Cycle 1.3 — Subtask content height addend capped at 400

    func test_subtaskHeight_cappedAt400_inAddend() {
        let big = ResizeSnapshot.fixture(subtaskContentHeight: 1000)
        let cap = ResizeSnapshot.fixture(subtaskContentHeight: 400)
        XCTAssertEqual(height(big), height(cap))
    }

    // MARK: - Cycle 1.4 — Subtask fallback when subtaskContentHeight == 0

    func test_zeroSubtaskHeight_usesEightyPointFallback() {
        let zero = ResizeSnapshot.fixture(subtaskContentHeight: 0)
        let eighty = ResizeSnapshot.fixture(subtaskContentHeight: 80)
        XCTAssertEqual(height(zero), height(eighty))
    }

    // MARK: - Cycle 1.5 — Countdown timer sections

    func test_countdownZero_addsNothing() {
        let off = ResizeSnapshot.fixture(countdownTime: 0, showTimerBar: true)
        let base = ResizeSnapshot.fixture()
        XCTAssertEqual(height(off), height(base))
    }

    func test_countdownActive_barCollapsed_addsThirty() {
        let collapsed = ResizeSnapshot.fixture(countdownTime: 60, showTimerBar: false)
        let base = ResizeSnapshot.fixture()
        XCTAssertEqual(height(collapsed) - height(base), 30)
    }

    func test_countdownActive_barExpanded_addsNinety() {
        let expanded = ResizeSnapshot.fixture(countdownTime: 60, showTimerBar: true)
        let base = ResizeSnapshot.fixture()
        XCTAssertEqual(height(expanded) - height(base), 90)
    }

    // MARK: - Cycle 1.6 — Timer completed message addend (120)

    func test_timerCompletedMessage_adds120() {
        let on = ResizeSnapshot.fixture(showTimerCompletedMessage: true)
        let off = ResizeSnapshot.fixture(showTimerCompletedMessage: false)
        XCTAssertEqual(height(on) - height(off), 120)
    }

    // MARK: - Cycle 1.7 — Estimate bar (collapsed 30, expanded 100)

    func test_estimateZero_addsNothing() {
        let off = ResizeSnapshot.fixture(estimatedTime: 0, showEstimateBar: true)
        let base = ResizeSnapshot.fixture()
        XCTAssertEqual(height(off), height(base))
    }

    func test_estimateActive_barCollapsed_addsThirty() {
        let collapsed = ResizeSnapshot.fixture(estimatedTime: 3600, showEstimateBar: false)
        let base = ResizeSnapshot.fixture()
        XCTAssertEqual(height(collapsed) - height(base), 30)
    }

    func test_estimateActive_barExpanded_addsOneHundred() {
        let expanded = ResizeSnapshot.fixture(estimatedTime: 3600, showEstimateBar: true)
        let base = ResizeSnapshot.fixture()
        XCTAssertEqual(height(expanded) - height(base), 100)
    }

    // MARK: - Cycle 1.8 — Due date bar (collapsed 30, expanded 100)

    func test_dueDateNil_addsNothing() {
        let off = ResizeSnapshot.fixture(dueDate: nil, showDueDateBar: true)
        let base = ResizeSnapshot.fixture()
        XCTAssertEqual(height(off), height(base))
    }

    func test_dueDateSet_barCollapsed_addsThirty() {
        let collapsed = ResizeSnapshot.fixture(dueDate: Date(), showDueDateBar: false)
        let base = ResizeSnapshot.fixture()
        XCTAssertEqual(height(collapsed) - height(base), 30)
    }

    func test_dueDateSet_barExpanded_addsOneHundred() {
        let expanded = ResizeSnapshot.fixture(dueDate: Date(), showDueDateBar: true)
        let base = ResizeSnapshot.fixture()
        XCTAssertEqual(height(expanded) - height(base), 100)
    }

    // MARK: - Cycle 1.9 — Description height scales with lines, capped at 148

    func test_emptyDescription_lessThanOneLine() {
        let empty = ResizeSnapshot.fixture(descriptionText: "")
        let oneLine = ResizeSnapshot.fixture(descriptionText: "x")
        XCTAssertLessThan(height(empty), height(oneLine))
    }

    func test_veryLongDescription_cappedAt148() {
        let huge = ResizeSnapshot.fixture(
            descriptionText: String(repeating: "a", count: 10_000),
            windowWidth: 350
        )
        let alsoHuge = ResizeSnapshot.fixture(
            descriptionText: String(repeating: "a", count: 10_000),
            windowWidth: 100
        )
        XCTAssertEqual(height(huge), height(alsoHuge))
    }

    // MARK: - Phase 2 Cycle 2.1 — Equatable contract

    func test_identicalSnapshots_areEqual() {
        XCTAssertEqual(ResizeSnapshot.fixture(), ResizeSnapshot.fixture())
    }

    func test_differingSubtaskHeight_areNotEqual() {
        XCTAssertNotEqual(
            ResizeSnapshot.fixture(subtaskContentHeight: 100),
            ResizeSnapshot.fixture(subtaskContentHeight: 101)
        )
    }

    func test_differingCollapsed_areNotEqual() {
        XCTAssertNotEqual(
            ResizeSnapshot.fixture(isCollapsed: true),
            ResizeSnapshot.fixture(isCollapsed: false)
        )
    }
}
