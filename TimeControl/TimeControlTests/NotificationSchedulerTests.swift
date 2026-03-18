//
//  NotificationSchedulerTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class NotificationSchedulerTests: XCTestCase {

    func testSnap_zerosSeconds() {
        let scheduler = NotificationScheduler.shared
        let date = Date()
        let snapped = scheduler.snap(date)
        XCTAssertEqual(Calendar.current.component(.second, from: snapped), 0)
    }

    func testSchedule_addsToPending() {
        let scheduler = NotificationScheduler.shared
        var task = makeTodo()
        task.reminderDate = Date().addingTimeInterval(3600)
        scheduler.schedule(task)
        XCTAssertNotNil(scheduler.pending[task.id])
        scheduler.cancel(for: task.id) // cleanup
    }

    func testCancel_removesFromPending() {
        let scheduler = NotificationScheduler.shared
        var task = makeTodo()
        task.reminderDate = Date().addingTimeInterval(3600)
        scheduler.schedule(task)
        scheduler.cancel(for: task.id)
        XCTAssertNil(scheduler.pending[task.id])
    }

    func testSchedule_pastDate_doesNotAddToPending() {
        let scheduler = NotificationScheduler.shared
        var task = makeTodo()
        task.reminderDate = Date().addingTimeInterval(-3600)
        scheduler.schedule(task)
        XCTAssertNil(scheduler.pending[task.id])
    }
}
