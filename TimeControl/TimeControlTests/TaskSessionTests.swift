//
//  TaskSessionTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class TaskSessionTests: XCTestCase {

    func testSession_stoppedAt_nil_whenOngoing() {
        let s = TaskSession(startedAt: 1000)
        XCTAssertNil(s.stoppedAt)
    }

    func testSession_duration_whenStopped() {
        let s = TaskSession(startedAt: 1000, stoppedAt: 1060)
        XCTAssertEqual(s.stoppedAt! - s.startedAt, 60)
    }
}
