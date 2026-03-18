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

    // MARK: - Phase 5: schedule(_:at:) overload

    func testScheduleAt_futureDate_addsToPending() {
        let scheduler = NotificationScheduler.shared
        let task = makeTodo()
        scheduler.schedule(task, at: Date().addingTimeInterval(7200))
        XCTAssertNotNil(scheduler.pending[task.id])
        scheduler.cancel(for: task.id)
    }

    func testScheduleAt_pastDate_doesNotAddToPending() {
        let scheduler = NotificationScheduler.shared
        let task = makeTodo()
        scheduler.schedule(task, at: Date().addingTimeInterval(-7200))
        XCTAssertNil(scheduler.pending[task.id])
    }

    func testScheduleAt_snapsToMinute() {
        let scheduler = NotificationScheduler.shared
        let task = makeTodo()
        // A date with 45 seconds — should snap to the same minute with 0 seconds
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        comps.minute = (comps.minute ?? 0) + 60 // 1 hour ahead so it's definitely future
        comps.second = 45
        let dateWithSeconds = Calendar.current.date(from: comps)!
        scheduler.schedule(task, at: dateWithSeconds)
        if let stored = scheduler.pending[task.id] {
            XCTAssertEqual(Calendar.current.component(.second, from: stored), 0)
        }
        scheduler.cancel(for: task.id)
    }

    // MARK: - Phase 5: rescheduleAll

    func testRescheduleAll_clearsPreviousPending() {
        let scheduler = NotificationScheduler.shared
        var task = makeTodo()
        task.reminderDate = Date().addingTimeInterval(3600)
        scheduler.schedule(task)
        XCTAssertNotNil(scheduler.pending[task.id])

        scheduler.rescheduleAll([])

        XCTAssertNil(scheduler.pending[task.id])
    }

    func testRescheduleAll_addsFutureReminders() {
        let scheduler = NotificationScheduler.shared
        scheduler.rescheduleAll([])

        var task1 = makeTodo(text: "Task 1")
        var task2 = makeTodo(text: "Task 2")
        task1.reminderDate = Date().addingTimeInterval(3600)
        task2.reminderDate = Date().addingTimeInterval(7200)

        scheduler.rescheduleAll([task1, task2])
        XCTAssertNotNil(scheduler.pending[task1.id])
        XCTAssertNotNil(scheduler.pending[task2.id])

        scheduler.rescheduleAll([])
    }

    func testRescheduleAll_missedByLessThan5Minutes_fires() {
        let scheduler = NotificationScheduler.shared
        NotificationStore.shared.setInitialRecords([])

        var task = makeTodo(text: "Missed Task")
        task.reminderDate = Date().addingTimeInterval(-2 * 60) // 2 min ago — within window

        let countBefore = NotificationStore.shared.records.count
        scheduler.rescheduleAll([task])

        XCTAssertEqual(NotificationStore.shared.records.count, countBefore + 1)
        XCTAssertNil(scheduler.pending[task.id])

        NotificationStore.shared.setInitialRecords([])
    }

    func testRescheduleAll_missedByMoreThan5Minutes_doesNotFire() {
        let scheduler = NotificationScheduler.shared
        NotificationStore.shared.setInitialRecords([])

        var task = makeTodo(text: "Old Task")
        task.reminderDate = Date().addingTimeInterval(-10 * 60) // 10 min ago — outside window

        let countBefore = NotificationStore.shared.records.count
        scheduler.rescheduleAll([task])

        XCTAssertEqual(NotificationStore.shared.records.count, countBefore)
        XCTAssertNil(scheduler.pending[task.id])

        NotificationStore.shared.setInitialRecords([])
    }

    func testRescheduleAll_twoTasksSameMinute_bothScheduled() {
        let scheduler = NotificationScheduler.shared

        var task1 = makeTodo(text: "A")
        var task2 = makeTodo(text: "B")
        // Build a future time with seconds=0 so adding 30s is guaranteed to stay in the same minute
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        comps.minute = (comps.minute ?? 0) + 30
        comps.second = 0
        let minuteStart = Calendar.current.date(from: comps)!
        task1.reminderDate = minuteStart
        task2.reminderDate = minuteStart.addingTimeInterval(30) // same minute, different seconds

        scheduler.rescheduleAll([task1, task2])

        XCTAssertNotNil(scheduler.pending[task1.id])
        XCTAssertNotNil(scheduler.pending[task2.id])
        XCTAssertEqual(scheduler.pending[task1.id], scheduler.pending[task2.id],
                       "Both reminders in the same minute should snap to the same time")

        scheduler.rescheduleAll([])
    }

    func testRescheduleAll_taskWithNoReminderDate_notAdded() {
        let scheduler = NotificationScheduler.shared
        let task = makeTodo(text: "No Reminder") // reminderDate is nil

        scheduler.rescheduleAll([task])

        XCTAssertNil(scheduler.pending[task.id])
    }
}
