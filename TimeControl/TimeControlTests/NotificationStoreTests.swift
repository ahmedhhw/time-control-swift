//
//  NotificationStoreTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class NotificationStoreTests: XCTestCase {

    let store = NotificationStore.shared

    override func setUp() {
        super.setUp()
        store.setInitialRecords([])
        store.onNeedsSave = nil
    }

    override func tearDown() {
        store.setInitialRecords([])
        store.onNeedsSave = nil
        super.tearDown()
    }

    // MARK: - setInitialRecords

    func testSetInitialRecords_populatesRecords() {
        let r1 = NotificationRecord(taskId: UUID(), taskTitle: "A")
        let r2 = NotificationRecord(taskId: UUID(), taskTitle: "B")
        store.setInitialRecords([r1, r2])
        XCTAssertEqual(store.records.count, 2)
    }

    func testSetInitialRecords_replacesExistingRecords() {
        store.setInitialRecords([NotificationRecord(taskId: UUID(), taskTitle: "Old")])
        let fresh = NotificationRecord(taskId: UUID(), taskTitle: "New")
        store.setInitialRecords([fresh])
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.taskTitle, "New")
    }

    func testSetInitialRecords_emptyArray_clearsRecords() {
        store.setInitialRecords([NotificationRecord(taskId: UUID(), taskTitle: "T")])
        store.setInitialRecords([])
        XCTAssertTrue(store.records.isEmpty)
    }

    // MARK: - append

    func testAppend_incrementsCount() {
        store.append(NotificationRecord(taskId: UUID(), taskTitle: "T"))
        XCTAssertEqual(store.records.count, 1)
    }

    func testAppend_insertsAtFront() {
        let first = NotificationRecord(taskId: UUID(), taskTitle: "First")
        let second = NotificationRecord(taskId: UUID(), taskTitle: "Second")
        store.append(first)
        store.append(second)
        XCTAssertEqual(store.records.first?.taskTitle, "Second")
    }

    func testAppend_contentMatches() {
        let taskId = UUID()
        let record = NotificationRecord(taskId: taskId, taskTitle: "My Task")
        store.append(record)
        XCTAssertEqual(store.records.first?.taskId, taskId)
        XCTAssertEqual(store.records.first?.taskTitle, "My Task")
        XCTAssertFalse(store.records.first?.isDismissed ?? true)
    }

    func testAppend_firesOnNeedsSave() {
        var saveCount = 0
        store.onNeedsSave = { saveCount += 1 }
        store.append(NotificationRecord(taskId: UUID(), taskTitle: "T"))
        XCTAssertEqual(saveCount, 1)
    }

    // MARK: - dismiss

    func testDismiss_marksMatchingRecordsDismissed() {
        let taskId = UUID()
        store.setInitialRecords([NotificationRecord(taskId: taskId, taskTitle: "Task")])
        store.dismiss(taskId: taskId)
        XCTAssertTrue(store.records.first?.isDismissed ?? false)
    }

    func testDismiss_doesNotAffectOtherTasks() {
        let idA = UUID()
        let idB = UUID()
        store.setInitialRecords([
            NotificationRecord(taskId: idA, taskTitle: "A"),
            NotificationRecord(taskId: idB, taskTitle: "B")
        ])
        store.dismiss(taskId: idA)
        let recordB = store.records.first { $0.taskId == idB }
        XCTAssertFalse(recordB?.isDismissed ?? true)
    }

    func testDismiss_dismissesAllRecordsForTask() {
        let taskId = UUID()
        store.setInitialRecords([
            NotificationRecord(taskId: taskId, taskTitle: "T"),
            NotificationRecord(taskId: taskId, taskTitle: "T again")
        ])
        store.dismiss(taskId: taskId)
        XCTAssertTrue(store.records.allSatisfy { $0.isDismissed })
    }

    func testDismiss_idempotent() {
        let taskId = UUID()
        store.setInitialRecords([NotificationRecord(taskId: taskId, taskTitle: "T")])
        store.dismiss(taskId: taskId)
        store.dismiss(taskId: taskId)
        XCTAssertTrue(store.records.first?.isDismissed ?? false)
        XCTAssertEqual(store.records.count, 1)
    }

    func testDismiss_unknownId_doesNotCrash() {
        store.setInitialRecords([NotificationRecord(taskId: UUID(), taskTitle: "T")])
        store.dismiss(taskId: UUID()) // unknown — should not crash or modify
        XCTAssertEqual(store.records.count, 1)
        XCTAssertFalse(store.records.first?.isDismissed ?? true)
    }

    func testDismiss_firesOnNeedsSave_whenChanged() {
        let taskId = UUID()
        store.setInitialRecords([NotificationRecord(taskId: taskId, taskTitle: "T")])
        var saveCount = 0
        store.onNeedsSave = { saveCount += 1 }
        store.dismiss(taskId: taskId)
        XCTAssertEqual(saveCount, 1)
    }

    func testDismiss_doesNotFireOnNeedsSave_whenAlreadyDismissed() {
        let taskId = UUID()
        store.setInitialRecords([
            NotificationRecord(taskId: taskId, taskTitle: "T", isDismissed: true)
        ])
        var saveCount = 0
        store.onNeedsSave = { saveCount += 1 }
        store.dismiss(taskId: taskId)
        XCTAssertEqual(saveCount, 0)
    }

    // MARK: - UserDefaults persistence

    private func makeSuite() -> UserDefaults {
        let suite = UUID().uuidString
        return UserDefaults(suiteName: suite)!
    }

    func testLoadFromUserDefaults_returnsEmptyWhenNothingSaved() {
        let defaults = makeSuite()
        let result = NotificationStore.loadFromUserDefaults(defaults: defaults)
        XCTAssertTrue(result.isEmpty)
    }

    func testSaveAndLoad_roundTripsRecords() {
        let defaults = makeSuite()
        let r = NotificationRecord(taskId: UUID(), taskTitle: "Round trip")
        store.setInitialRecords([r])
        store.saveToUserDefaults(defaults: defaults)

        let loaded = NotificationStore.loadFromUserDefaults(defaults: defaults)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.taskTitle, "Round trip")
    }

    func testSaveToUserDefaults_excludesRecordsOlderThan30Days() {
        let defaults = makeSuite()
        let old = NotificationRecord(
            taskId: UUID(), taskTitle: "Old",
            firedAt: Date().addingTimeInterval(-31 * 24 * 60 * 60)
        )
        let recent = NotificationRecord(taskId: UUID(), taskTitle: "Recent")
        store.setInitialRecords([old, recent])
        store.saveToUserDefaults(defaults: defaults)

        let loaded = NotificationStore.loadFromUserDefaults(defaults: defaults)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.taskTitle, "Recent")
    }

    func testLoadFromUserDefaults_excludesRecordsOlderThan30Days() {
        let defaults = makeSuite()
        // Save a mix — one stale record sneaks past by pre-writing raw JSON
        let records = [
            NotificationRecord(taskId: UUID(), taskTitle: "Recent"),
            NotificationRecord(
                taskId: UUID(), taskTitle: "Stale",
                firedAt: Date().addingTimeInterval(-31 * 24 * 60 * 60)
            )
        ]
        let data = try! JSONEncoder().encode(records)
        defaults.set(data, forKey: "notificationRecords")

        let loaded = NotificationStore.loadFromUserDefaults(defaults: defaults)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.taskTitle, "Recent")
    }

    func testLoadFromUserDefaults_returnsRecordsSortedNewestFirst() {
        let defaults = makeSuite()
        let older = NotificationRecord(
            taskId: UUID(), taskTitle: "Older",
            firedAt: Date().addingTimeInterval(-100)
        )
        let newer = NotificationRecord(taskId: UUID(), taskTitle: "Newer", firedAt: Date())
        store.setInitialRecords([older, newer])
        store.saveToUserDefaults(defaults: defaults)

        let loaded = NotificationStore.loadFromUserDefaults(defaults: defaults)
        XCTAssertEqual(loaded.first?.taskTitle, "Newer")
        XCTAssertEqual(loaded.last?.taskTitle, "Older")
    }

    func testSaveToUserDefaults_preservesDismissedState() {
        let defaults = makeSuite()
        let taskId = UUID()
        store.setInitialRecords([NotificationRecord(taskId: taskId, taskTitle: "T", isDismissed: true)])
        store.saveToUserDefaults(defaults: defaults)

        let loaded = NotificationStore.loadFromUserDefaults(defaults: defaults)
        XCTAssertTrue(loaded.first?.isDismissed ?? false)
    }
}
