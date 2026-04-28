//
//  SubtitleTextStrokeTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class SubtitleTextStrokeTests: XCTestCase {

    // MARK: - At full opacity, no halo (text is its own thing, the bg is solid)

    func testStrokeWidth_isZero_atFullOpacity() {
        XCTAssertEqual(SubtitleTextStroke.width(forWindowOpacity: 1.0), 0.0, accuracy: 0.001)
    }

    func testStrokeOpacity_isZero_atFullOpacity() {
        XCTAssertEqual(SubtitleTextStroke.haloOpacity(forWindowOpacity: 1.0), 0.0, accuracy: 0.001)
    }

    // MARK: - At minimum window opacity, the halo is at its strongest

    func testStrokeWidth_isMaximum_atMinimumOpacity() {
        let w = SubtitleTextStroke.width(forWindowOpacity: WindowOpacityStore.minimum)
        XCTAssertEqual(w, SubtitleTextStroke.maxWidth, accuracy: 0.001)
    }

    func testStrokeOpacity_isOne_atMinimumOpacity() {
        let a = SubtitleTextStroke.haloOpacity(forWindowOpacity: WindowOpacityStore.minimum)
        XCTAssertEqual(a, 1.0, accuracy: 0.001)
    }

    // MARK: - Halo turns on as soon as opacity drops below 1.0

    func testStrokeWidth_isPositive_belowFullOpacity() {
        XCTAssertGreaterThan(SubtitleTextStroke.width(forWindowOpacity: 0.9), 0)
        XCTAssertGreaterThan(SubtitleTextStroke.width(forWindowOpacity: 0.5), 0)
    }

    func testStrokeWidth_isMonotonicallyDecreasingWithOpacity() {
        let w1 = SubtitleTextStroke.width(forWindowOpacity: 0.3)
        let w2 = SubtitleTextStroke.width(forWindowOpacity: 0.6)
        let w3 = SubtitleTextStroke.width(forWindowOpacity: 0.9)
        XCTAssertGreaterThan(w1, w2)
        XCTAssertGreaterThan(w2, w3)
    }

    // MARK: - Out-of-range inputs are clamped (defensive)

    func testStrokeWidth_clampsAboveOne() {
        XCTAssertEqual(SubtitleTextStroke.width(forWindowOpacity: 1.5), 0.0, accuracy: 0.001)
    }

    func testStrokeWidth_clampsBelowMinimum() {
        // Anything below the store minimum should behave like the minimum.
        let w = SubtitleTextStroke.width(forWindowOpacity: 0.0)
        XCTAssertEqual(w, SubtitleTextStroke.maxWidth, accuracy: 0.001)
    }

    // MARK: - Sanity on the constants

    func testMaxWidth_isReasonableForUI() {
        // A several-point stroke is plenty for legibility without looking gross.
        XCTAssertGreaterThan(SubtitleTextStroke.maxWidth, 0.5)
        XCTAssertLessThanOrEqual(SubtitleTextStroke.maxWidth, 5.0)
    }
}
