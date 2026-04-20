//
//  SQLiteStorageTests.swift
//  TimeControlTests
//

import XCTest
import GRDB
@testable import TimeControl

final class SQLiteStorageTests: XCTestCase {

    var storage: SQLiteStorage!
    var dbURL: URL!

    override func setUp() {
        super.setUp()
        dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".db")
        storage = try! SQLiteStorage(dbURL: dbURL)
    }

    override func tearDown() {
        storage = nil
        try? FileManager.default.removeItem(at: dbURL)
        super.tearDown()
    }

    // MARK: - Phase 1: Schema

    func testDBFileIsCreatedOnInit() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))
    }

    func testAllFourTablesExist() throws {
        let tables = try storage.dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }
        XCTAssertTrue(tables.contains("tasks"))
        XCTAssertTrue(tables.contains("subtasks"))
        XCTAssertTrue(tables.contains("task_sessions"))
        XCTAssertTrue(tables.contains("subtask_sessions"))
    }

    func testTasksTableHasRequiredColumns() throws {
        let columns = try storage.dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(tasks)")
        }.map { $0["name"] as String }

        let required = ["id", "text", "is_completed", "index", "total_time_spent",
                        "last_start_time", "description", "due_date", "is_adhoc",
                        "from_who", "estimated_time", "created_at", "started_at",
                        "completed_at", "notes", "countdown_time", "countdown_start_time",
                        "countdown_elapsed_at_pause", "last_played_at", "reminder_date",
                        "has_active_notification"]
        for col in required {
            XCTAssertTrue(columns.contains(col), "tasks table missing column: \(col)")
        }
    }

    func testSubtasksTableHasRequiredColumns() throws {
        let columns = try storage.dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(subtasks)")
        }.map { $0["name"] as String }

        let required = ["id", "task_id", "title", "description", "is_completed",
                        "total_time_spent", "last_start_time", "subtask_order"]
        for col in required {
            XCTAssertTrue(columns.contains(col), "subtasks table missing column: \(col)")
        }
    }

    func testTaskSessionsTableHasRequiredColumns() throws {
        let columns = try storage.dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(task_sessions)")
        }.map { $0["name"] as String }

        XCTAssertTrue(columns.contains("id"))
        XCTAssertTrue(columns.contains("task_id"))
        XCTAssertTrue(columns.contains("started_at"))
        XCTAssertTrue(columns.contains("stopped_at"))
    }

    func testSubtaskSessionsTableHasRequiredColumns() throws {
        let columns = try storage.dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(subtask_sessions)")
        }.map { $0["name"] as String }

        XCTAssertTrue(columns.contains("id"))
        XCTAssertTrue(columns.contains("subtask_id"))
        XCTAssertTrue(columns.contains("started_at"))
        XCTAssertTrue(columns.contains("stopped_at"))
    }

    func testSchemaMigrationRunsWithoutErrorOnFreshDB() {
        // If we reach this point, setUp() succeeded, so migration ran cleanly.
        XCTAssertNotNil(storage)
    }

    // MARK: - Phase 2: Save

    func testSavingTaskInsertsOneRowInTasksTable() throws {
        let task = makeTodo(text: "Buy milk")
        try storage.save(task)

        let count = try storage.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tasks")!
        }
        XCTAssertEqual(count, 1)
    }

    func testSavingTaskWithTwoSubtasksInsertsTwoSubtaskRows() throws {
        let task = makeTodo(text: "Parent", subtasks: [makeSubtask(title: "A"), makeSubtask(title: "B")])
        try storage.save(task)

        let count = try storage.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM subtasks")!
        }
        XCTAssertEqual(count, 2)
    }

    func testSubtaskRowsHaveCorrectTaskID() throws {
        let task = makeTodo(text: "Parent", subtasks: [makeSubtask(title: "Child")])
        try storage.save(task)

        let taskId = try storage.dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT task_id FROM subtasks LIMIT 1")!
        }
        XCTAssertEqual(taskId, task.id.uuidString)
    }

    func testSavingTaskWithSessionsInsertsSessionRows() throws {
        var task = makeTodo(text: "Work")
        task.sessions = [TaskSession(startedAt: 1000, stoppedAt: 2000)]
        try storage.save(task)

        let count = try storage.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM task_sessions")!
        }
        XCTAssertEqual(count, 1)
    }

    func testSavingSubtaskWithSessionsInsertsSubtaskSessionRows() throws {
        var subtask = makeSubtask(title: "Sub")
        subtask.sessions = [TaskSession(startedAt: 500, stoppedAt: 1500)]
        let task = makeTodo(text: "Parent", subtasks: [subtask])
        try storage.save(task)

        let count = try storage.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM subtask_sessions")!
        }
        XCTAssertEqual(count, 1)
    }

    func testSavingSameTaskTwiceDoesNotCreateDuplicates() throws {
        let task = makeTodo(text: "No Dupe")
        try storage.save(task)
        try storage.save(task)

        let count = try storage.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tasks")!
        }
        XCTAssertEqual(count, 1)
    }

    // MARK: - Phase 3: Load

    func testLoadReturnsSameTaskThatWasSaved() throws {
        let id = UUID()
        let task = TodoItem(
            id: id,
            text: "Round-trip",
            isCompleted: true,
            index: 3,
            totalTimeSpent: 3600,
            description: "desc",
            dueDate: Date(timeIntervalSince1970: 5_000_000),
            isAdhoc: true,
            fromWho: "Boss",
            estimatedTime: 7200,
            createdAt: 1_000_000,
            startedAt: 1_100_000,
            completedAt: 1_200_000,
            notes: "my notes",
            reminderDate: Date(timeIntervalSince1970: 6_000_000)
        )
        try storage.save(task)
        let loaded = try storage.load()

        XCTAssertEqual(loaded.count, 1)
        let t = loaded[0]
        XCTAssertEqual(t.id, id)
        XCTAssertEqual(t.text, "Round-trip")
        XCTAssertTrue(t.isCompleted)
        XCTAssertEqual(t.index, 3)
        XCTAssertEqual(t.totalTimeSpent, 3600)
        XCTAssertEqual(t.description, "desc")
        XCTAssertEqual(t.dueDate?.timeIntervalSince1970 ?? 0, 5_000_000, accuracy: 0.001)
        XCTAssertTrue(t.isAdhoc)
        XCTAssertEqual(t.fromWho, "Boss")
        XCTAssertEqual(t.estimatedTime, 7200)
        XCTAssertEqual(t.createdAt, 1_000_000)
        XCTAssertEqual(t.startedAt, 1_100_000)
        XCTAssertEqual(t.completedAt, 1_200_000)
        XCTAssertEqual(t.notes, "my notes")
        XCTAssertEqual(t.reminderDate?.timeIntervalSince1970 ?? 0, 6_000_000, accuracy: 0.001)
    }

    func testSubtasksAreLoadedAndAttachedToCorrectParent() throws {
        let s1 = Subtask(id: UUID(), title: "Alpha", description: "d1", isCompleted: false)
        let s2 = Subtask(id: UUID(), title: "Beta", description: "d2", isCompleted: true)
        let task = makeTodo(text: "With Subtasks", subtasks: [s1, s2])
        try storage.save(task)

        let loaded = try storage.load()
        XCTAssertEqual(loaded[0].subtasks.count, 2)
        XCTAssertEqual(loaded[0].subtasks[0].title, "Alpha")
        XCTAssertEqual(loaded[0].subtasks[1].title, "Beta")
        XCTAssertTrue(loaded[0].subtasks[1].isCompleted)
    }

    func testTaskSessionsAreLoadedAndAttachedCorrectly() throws {
        var task = makeTodo(text: "Sessions")
        task.sessions = [
            TaskSession(startedAt: 1000, stoppedAt: 2000),
            TaskSession(startedAt: 3000, stoppedAt: nil)
        ]
        try storage.save(task)

        let loaded = try storage.load()
        XCTAssertEqual(loaded[0].sessions.count, 2)
        XCTAssertEqual(loaded[0].sessions[0].startedAt, 1000)
        XCTAssertEqual(loaded[0].sessions[0].stoppedAt, 2000)
        XCTAssertEqual(loaded[0].sessions[1].startedAt, 3000)
        XCTAssertNil(loaded[0].sessions[1].stoppedAt)
    }

    func testSubtaskSessionsAreLoadedCorrectly() throws {
        var sub = makeSubtask(title: "Timed Sub")
        sub.sessions = [TaskSession(startedAt: 100, stoppedAt: 200)]
        let task = makeTodo(text: "Parent", subtasks: [sub])
        try storage.save(task)

        let loaded = try storage.load()
        XCTAssertEqual(loaded[0].subtasks[0].sessions.count, 1)
        XCTAssertEqual(loaded[0].subtasks[0].sessions[0].startedAt, 100)
    }

    func testTasksAreReturnedSortedByIndex() throws {
        try storage.save(makeTodo(text: "C").withIndex(2))
        try storage.save(makeTodo(text: "A").withIndex(0))
        try storage.save(makeTodo(text: "B").withIndex(1))

        let loaded = try storage.load()
        XCTAssertEqual(loaded.map { $0.text }, ["A", "B", "C"])
    }

    func testLoadFromEmptyDBReturnsEmptyArray() throws {
        let loaded = try storage.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testLastStartTimeRoundTrips() throws {
        let date = Date(timeIntervalSince1970: 7_000_000)
        var task = makeTodo(text: "Running")
        task.lastStartTime = date
        try storage.save(task)

        let loaded = try storage.load()
        XCTAssertNotNil(loaded[0].lastStartTime)
        XCTAssertEqual(loaded[0].lastStartTime!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testUpsertUpdatesExistingTask() throws {
        var task = makeTodo(text: "Original")
        try storage.save(task)
        task.text = "Updated"
        try storage.save(task)

        let loaded = try storage.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].text, "Updated")
    }

    // MARK: - Phase 4: Delete

    func testDeletingTaskRemovesItsRowFromTasksTable() throws {
        let task = makeTodo(text: "Delete me")
        try storage.save(task)
        try storage.delete(task.id)

        let loaded = try storage.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testDeletingTaskCascadesToSubtasks() throws {
        let task = makeTodo(text: "Parent", subtasks: [makeSubtask(title: "Child")])
        try storage.save(task)
        try storage.delete(task.id)

        let count = try storage.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM subtasks")!
        }
        XCTAssertEqual(count, 0)
    }

    func testDeletingTaskCascadesToTaskSessions() throws {
        var task = makeTodo(text: "Sessioned")
        task.sessions = [TaskSession(startedAt: 100, stoppedAt: 200)]
        try storage.save(task)
        try storage.delete(task.id)

        let count = try storage.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM task_sessions")!
        }
        XCTAssertEqual(count, 0)
    }

    func testDeletingTaskCascadesToSubtaskSessions() throws {
        var sub = makeSubtask(title: "Sub")
        sub.sessions = [TaskSession(startedAt: 50, stoppedAt: 150)]
        let task = makeTodo(text: "Parent", subtasks: [sub])
        try storage.save(task)
        try storage.delete(task.id)

        let count = try storage.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM subtask_sessions")!
        }
        XCTAssertEqual(count, 0)
    }

    // MARK: - Phase 5: JSON Migration

    func testMigrationFromValidJSONPopulatesDB() throws {
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_todos.json")
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let tasks = [
            makeTodo(text: "Migrated Task 1").withIndex(0),
            makeTodo(text: "Migrated Task 2").withIndex(1)
        ]
        TodoStorage.save(todos: tasks, notificationRecords: [], to: jsonURL)

        try storage.migrateFromJSONIfNeeded(jsonURL: jsonURL)

        let loaded = try storage.load()
        XCTAssertEqual(loaded.count, 2)
    }

    func testMigrationPreservesSubtasksAndSessions() throws {
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_todos.json")
        defer {
            try? FileManager.default.removeItem(at: jsonURL)
            let bak = jsonURL.deletingPathExtension().appendingPathExtension("json.bak")
            try? FileManager.default.removeItem(at: bak)
        }

        var sub = makeSubtask(title: "Migrated Sub")
        sub.sessions = [TaskSession(startedAt: 100, stoppedAt: 200)]
        var task = makeTodo(text: "Has Sub", subtasks: [sub]).withIndex(0)
        task.sessions = [TaskSession(startedAt: 300, stoppedAt: 400)]
        TodoStorage.save(todos: [task], notificationRecords: [], to: jsonURL)

        try storage.migrateFromJSONIfNeeded(jsonURL: jsonURL)

        let loaded = try storage.load()
        XCTAssertEqual(loaded[0].subtasks.count, 1)
        XCTAssertEqual(loaded[0].sessions.count, 1)
        XCTAssertEqual(loaded[0].subtasks[0].sessions.count, 1)
    }

    func testMigrationRenamesJSONToBak() throws {
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_todos.json")
        let bakURL = URL(fileURLWithPath: jsonURL.path + ".bak")
        defer {
            try? FileManager.default.removeItem(at: jsonURL)
            try? FileManager.default.removeItem(at: bakURL)
        }

        TodoStorage.save(todos: [makeTodo(text: "X").withIndex(0)], notificationRecords: [], to: jsonURL)
        try storage.migrateFromJSONIfNeeded(jsonURL: jsonURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: jsonURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bakURL.path))
    }

    func testMigrationIsNoOpWhenJSONDoesNotExist() throws {
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_todos.json")

        try storage.migrateFromJSONIfNeeded(jsonURL: jsonURL)

        let loaded = try storage.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testMigrationIsNoOpWhenBakAlreadyExists() throws {
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_todos.json")
        let bakURL = URL(fileURLWithPath: jsonURL.path + ".bak")
        defer {
            try? FileManager.default.removeItem(at: bakURL)
        }

        // Pre-populate DB with one task
        try storage.save(makeTodo(text: "Already migrated").withIndex(0))

        // Only bak exists (no json)
        try "{}".write(to: bakURL, atomically: true, encoding: .utf8)
        try storage.migrateFromJSONIfNeeded(jsonURL: jsonURL)

        let loaded = try storage.load()
        XCTAssertEqual(loaded.count, 1)
    }

    func testMigrationOfRunningTaskPreservesLastStartTime() throws {
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_todos.json")
        defer {
            try? FileManager.default.removeItem(at: jsonURL)
            let bak = URL(fileURLWithPath: jsonURL.path + ".bak")
            try? FileManager.default.removeItem(at: bak)
        }

        let startTime = Date(timeIntervalSince1970: 8_000_000)
        var task = makeTodo(text: "Running").withIndex(0)
        task.lastStartTime = startTime
        TodoStorage.save(todos: [task], notificationRecords: [], to: jsonURL)

        try storage.migrateFromJSONIfNeeded(jsonURL: jsonURL)

        let loaded = try storage.load()
        XCTAssertNotNil(loaded[0].lastStartTime)
        XCTAssertEqual(loaded[0].lastStartTime!.timeIntervalSince1970, startTime.timeIntervalSince1970, accuracy: 0.001)
    }
}

// MARK: - Helpers

private extension TodoItem {
    func withIndex(_ i: Int) -> TodoItem {
        var copy = self
        copy.index = i
        return copy
    }
}
