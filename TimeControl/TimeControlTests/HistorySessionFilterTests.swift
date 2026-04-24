//
//  HistorySessionFilterTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class HistorySessionFilterTests: XCTestCase {

    // MARK: - Helpers

    private let day: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 22
        return Calendar.current.date(from: comps)!
    }()

    private func dayStart(_ d: Date) -> TimeInterval {
        Calendar.current.startOfDay(for: d).timeIntervalSince1970
    }

    // Build a completed session anchored to `day`
    private func session(startOffset: TimeInterval, duration: TimeInterval) -> TaskSession {
        let start = dayStart(day) + startOffset
        return TaskSession(startedAt: start, stoppedAt: start + duration)
    }

    private func makeTodoWithSession(startOffset: TimeInterval, duration: TimeInterval) -> TodoItem {
        var todo = makeTodo()
        todo.sessions = [session(startOffset: startOffset, duration: duration)]
        return todo
    }

    // MARK: - Filter short sessions (< 5 min = 300s)

    func test_filterShortSessions_excludes4MinSession() {
        let todo = makeTodoWithSession(startOffset: 3600, duration: 239) // 3:59
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day)
        XCTAssertTrue(entries.isEmpty)
    }

    func test_filterShortSessions_includes5MinSession() {
        let todo = makeTodoWithSession(startOffset: 3600, duration: 300) // exactly 5:00
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day)
        XCTAssertEqual(entries.count, 1)
    }

    func test_filterShortSessions_includes10MinSession() {
        let todo = makeTodoWithSession(startOffset: 3600, duration: 600)
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day)
        XCTAssertEqual(entries.count, 1)
    }

    func test_filterShortSessions_mixedReturnsOnlyLong() {
        var todo = makeTodo()
        todo.sessions = [
            session(startOffset: 3600, duration: 239), // short — excluded
            session(startOffset: 7200, duration: 600), // long — included
        ]
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].duration, 600, accuracy: 1)
    }

    func test_filterShortSessions_excludesOpenSession() {
        var todo = makeTodo()
        // Open session (no stoppedAt) — should never appear
        todo.sessions = [TaskSession(startedAt: dayStart(day) + 3600)]
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day)
        XCTAssertTrue(entries.isEmpty)
    }

    func test_filterShortSessions_subtaskSessions() {
        var subtask = makeSubtask()
        subtask.sessions = [session(startOffset: 3600, duration: 239)] // short
        let todo = makeTodo(subtasks: [subtask])
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Merge adjacent sessions (< 2 min gap = 120s)

    func test_mergeSessions_sameTask90sGap_mergedIntoOne() {
        let id = UUID()
        let e1 = SessionEntry(taskId: id, subtaskId: nil, label: "T", startedAt: 0, stoppedAt: 300)
        let e2 = SessionEntry(taskId: id, subtaskId: nil, label: "T", startedAt: 390, stoppedAt: 700)
        // gap = 390 - 300 = 90s < 120s → merge
        let merged = HistorySessionProcessor.mergeSessions([e1, e2])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].startedAt, 0, accuracy: 1)
        XCTAssertEqual(merged[0].stoppedAt, 700, accuracy: 1)
    }

    func test_mergeSessions_sameTask121sGap_notMerged() {
        let id = UUID()
        let e1 = SessionEntry(taskId: id, subtaskId: nil, label: "T", startedAt: 0, stoppedAt: 300)
        let e2 = SessionEntry(taskId: id, subtaskId: nil, label: "T", startedAt: 421, stoppedAt: 800)
        // gap = 421 - 300 = 121s > 120s → keep separate
        let merged = HistorySessionProcessor.mergeSessions([e1, e2])
        XCTAssertEqual(merged.count, 2)
    }

    func test_mergeSessions_differentTasks90sGap_notMerged() {
        let e1 = SessionEntry(taskId: UUID(), subtaskId: nil, label: "A", startedAt: 0, stoppedAt: 300)
        let e2 = SessionEntry(taskId: UUID(), subtaskId: nil, label: "B", startedAt: 390, stoppedAt: 700)
        let merged = HistorySessionProcessor.mergeSessions([e1, e2])
        XCTAssertEqual(merged.count, 2)
    }

    func test_mergeSessions_sameSubtask90sGap_merged() {
        let taskId = UUID()
        let subId = UUID()
        let e1 = SessionEntry(taskId: taskId, subtaskId: subId, label: "S", startedAt: 0, stoppedAt: 300)
        let e2 = SessionEntry(taskId: taskId, subtaskId: subId, label: "S", startedAt: 390, stoppedAt: 700)
        let merged = HistorySessionProcessor.mergeSessions([e1, e2])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].duration, 700, accuracy: 1)
    }

    func test_mergeSessions_differentSubtasksSameTask_notMerged() {
        let taskId = UUID()
        let e1 = SessionEntry(taskId: taskId, subtaskId: UUID(), label: "S1", startedAt: 0, stoppedAt: 300)
        let e2 = SessionEntry(taskId: taskId, subtaskId: UUID(), label: "S2", startedAt: 390, stoppedAt: 700)
        let merged = HistorySessionProcessor.mergeSessions([e1, e2])
        XCTAssertEqual(merged.count, 2)
    }

    func test_mergeSessions_threeConsecutiveClose_mergedIntoOne() {
        let id = UUID()
        let e1 = SessionEntry(taskId: id, subtaskId: nil, label: "T", startedAt: 0,    stoppedAt: 300)
        let e2 = SessionEntry(taskId: id, subtaskId: nil, label: "T", startedAt: 390,  stoppedAt: 700)
        let e3 = SessionEntry(taskId: id, subtaskId: nil, label: "T", startedAt: 780,  stoppedAt: 1100)
        let merged = HistorySessionProcessor.mergeSessions([e1, e2, e3])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].startedAt, 0, accuracy: 1)
        XCTAssertEqual(merged[0].stoppedAt, 1100, accuracy: 1)
    }

    func test_mergeThenFilter_mergedResultShort_excluded() {
        // Two 100s sessions, 90s apart → merged span = 290s (< 300s) → filtered out
        var todo = makeTodo()
        todo.sessions = [
            session(startOffset: 3600, duration: 100),
            session(startOffset: 3790, duration: 100), // gap = 90s
        ]
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day)
        XCTAssertTrue(entries.isEmpty)
    }

    func test_mergeThenFilter_mergedResultLong_included() {
        // Two 200s sessions, 90s apart → merged span = 490s (> 300s) → included
        var todo = makeTodo()
        todo.sessions = [
            session(startOffset: 3600, duration: 200),
            session(startOffset: 3890, duration: 200), // gap = 90s
        ]
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day)
        XCTAssertEqual(entries.count, 1)
    }

    // MARK: - Total duration

    func test_totalDuration_sumsMergedFilteredEntries() {
        let id = UUID()
        let e1 = SessionEntry(taskId: id, subtaskId: nil, label: "T", startedAt: 0, stoppedAt: 600)
        let e2 = SessionEntry(taskId: UUID(), subtaskId: nil, label: "B", startedAt: 1000, stoppedAt: 1900)
        let total = HistorySessionProcessor.totalDuration(of: [e1, e2])
        XCTAssertEqual(total, 1500, accuracy: 1)
    }

    func test_totalDuration_emptyEntries_returnsZero() {
        XCTAssertEqual(HistorySessionProcessor.totalDuration(of: []), 0)
    }

    func test_totalDuration_excludesShortViaFilteredSessions() {
        let todo = makeTodoWithSession(startOffset: 3600, duration: 239) // < 5 min
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day)
        XCTAssertEqual(HistorySessionProcessor.totalDuration(of: entries), 0)
    }

    // MARK: - Group A: Custom minDuration parameter

    func test_customMinDuration_zero_includesShortSessions() {
        let todo = makeTodoWithSession(startOffset: 3600, duration: 239) // 3:59 — normally filtered
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day, minDuration: 0)
        XCTAssertEqual(entries.count, 1)
    }

    func test_customMinDuration_600_excludes5MinSession() {
        let todo = makeTodoWithSession(startOffset: 3600, duration: 300) // exactly 5 min
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day, minDuration: 600)
        XCTAssertTrue(entries.isEmpty)
    }

    func test_customMinDuration_60_includes1MinSession() {
        let todo = makeTodoWithSession(startOffset: 3600, duration: 60)
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day, minDuration: 60)
        XCTAssertEqual(entries.count, 1)
    }

    func test_customMinDuration_60_excludes50sSession() {
        let todo = makeTodoWithSession(startOffset: 3600, duration: 50)
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day, minDuration: 60)
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Group B: Custom maxGap parameter

    func test_customMaxGap_zero_doesNotMergeSessions() {
        // 90s gap — would normally merge with default 120s threshold
        var todo = makeTodo()
        todo.sessions = [
            session(startOffset: 3600, duration: 300),
            session(startOffset: 3990, duration: 300), // gap = 90s
        ]
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day, minDuration: 0, maxGap: 0)
        XCTAssertEqual(entries.count, 2)
    }

    func test_customMaxGap_300_merges4MinGapSessions() {
        // 240s (4 min) gap — merges with maxGap=300
        var todo = makeTodo()
        todo.sessions = [
            session(startOffset: 3600, duration: 300),
            session(startOffset: 4140, duration: 300), // gap = 240s
        ]
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day, minDuration: 0, maxGap: 300)
        XCTAssertEqual(entries.count, 1)
    }

    func test_customMaxGap_30_doesNotMerge60sGap() {
        var todo = makeTodo()
        todo.sessions = [
            session(startOffset: 3600, duration: 300),
            session(startOffset: 3960, duration: 300), // gap = 60s > 30s
        ]
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day, minDuration: 0, maxGap: 30)
        XCTAssertEqual(entries.count, 2)
    }

    // MARK: - Group C: Both params together

    func test_customBoth_largeGapNoFilter_mergesAndIncludes() {
        // maxGap=600 merges sessions 5 min apart; minDuration=0 keeps all results
        var todo = makeTodo()
        todo.sessions = [
            session(startOffset: 3600, duration: 60),
            session(startOffset: 3960, duration: 60), // gap = 300s < 600s → merges
        ]
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day, minDuration: 0, maxGap: 600)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].startedAt, dayStart(day) + 3600, accuracy: 1)
        XCTAssertEqual(entries[0].stoppedAt, dayStart(day) + 4020, accuracy: 1)
    }

    func test_customBoth_noMergeNoFilter_returnsRawSessions() {
        // maxGap=0, minDuration=0 → raw sessions returned without merge or filter
        var todo = makeTodo()
        todo.sessions = [
            session(startOffset: 3600, duration: 30),  // very short
            session(startOffset: 3690, duration: 30),  // 60s gap — won't merge with maxGap=0
        ]
        let entries = HistorySessionProcessor.filteredSessions(from: [todo], for: day, minDuration: 0, maxGap: 0)
        XCTAssertEqual(entries.count, 2)
    }
}
