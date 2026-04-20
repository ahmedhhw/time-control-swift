//
//  SQLiteStorage.swift
//  TimeControl
//

import Foundation
import GRDB

class SQLiteStorage {
    let dbQueue: DatabaseQueue

    init(dbURL: URL? = nil) throws {
        let url: URL
        if let provided = dbURL {
            url = provided
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dir = docs.appendingPathComponent("TimeControl", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("timecontrol.db")
        }

        dbQueue = try DatabaseQueue(path: url.path)
        try migrate()
    }

    // MARK: - Save

    func save(_ task: TodoItem) throws {
        try dbQueue.write { db in
            try upsertTask(task, db: db)
        }
    }

    // MARK: - Load

    func load() throws -> [TodoItem] {
        try dbQueue.read { db in
            let taskRows = try Row.fetchAll(db, sql: "SELECT * FROM tasks ORDER BY \"index\" ASC")
            return try taskRows.map { row in
                try buildTask(from: row, db: db)
            }
        }
    }

    // MARK: - Delete

    func delete(_ taskId: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM tasks WHERE id = ?", arguments: [taskId.uuidString])
        }
    }

    // MARK: - JSON Migration

    func migrateFromJSONIfNeeded(jsonURL: URL = TodoStorage.storageURL) throws {
        let bakURL = URL(fileURLWithPath: jsonURL.path + ".bak")

        // Already migrated (bak exists) or nothing to migrate
        guard FileManager.default.fileExists(atPath: jsonURL.path),
              !FileManager.default.fileExists(atPath: bakURL.path) else {
            return
        }

        let (tasks, _) = TodoStorage.load(from: jsonURL)
        try dbQueue.write { db in
            for task in tasks {
                try upsertTask(task, db: db)
            }
        }

        try FileManager.default.moveItem(at: jsonURL, to: bakURL)
    }

    // MARK: - Private helpers

    private func upsertTask(_ task: TodoItem, db: Database) throws {
        try db.execute(sql: """
            INSERT INTO tasks (
                id, text, is_completed, "index", total_time_spent, last_start_time,
                description, due_date, is_adhoc, from_who, estimated_time,
                created_at, started_at, completed_at, notes,
                countdown_time, countdown_start_time, countdown_elapsed_at_pause,
                last_played_at, reminder_date, has_active_notification
            ) VALUES (
                ?, ?, ?, ?, ?, ?,
                ?, ?, ?, ?, ?,
                ?, ?, ?, ?,
                ?, ?, ?,
                ?, ?, ?
            )
            ON CONFLICT(id) DO UPDATE SET
                text = excluded.text,
                is_completed = excluded.is_completed,
                "index" = excluded."index",
                total_time_spent = excluded.total_time_spent,
                last_start_time = excluded.last_start_time,
                description = excluded.description,
                due_date = excluded.due_date,
                is_adhoc = excluded.is_adhoc,
                from_who = excluded.from_who,
                estimated_time = excluded.estimated_time,
                created_at = excluded.created_at,
                started_at = excluded.started_at,
                completed_at = excluded.completed_at,
                notes = excluded.notes,
                countdown_time = excluded.countdown_time,
                countdown_start_time = excluded.countdown_start_time,
                countdown_elapsed_at_pause = excluded.countdown_elapsed_at_pause,
                last_played_at = excluded.last_played_at,
                reminder_date = excluded.reminder_date,
                has_active_notification = excluded.has_active_notification
            """,
            arguments: [
                task.id.uuidString,
                task.text,
                task.isCompleted ? 1 : 0,
                task.index,
                task.totalTimeSpent,
                task.lastStartTime?.timeIntervalSince1970,
                task.description,
                task.dueDate?.timeIntervalSince1970,
                task.isAdhoc ? 1 : 0,
                task.fromWho,
                task.estimatedTime,
                task.createdAt,
                task.startedAt,
                task.completedAt,
                task.notes,
                task.countdownTime,
                task.countdownStartTime?.timeIntervalSince1970,
                task.countdownElapsedAtPause,
                task.lastPlayedAt,
                task.reminderDate?.timeIntervalSince1970,
                task.hasActiveNotification ? 1 : 0
            ]
        )

        // Replace subtasks: delete existing, re-insert in order
        try db.execute(sql: "DELETE FROM subtasks WHERE task_id = ?", arguments: [task.id.uuidString])
        for (order, subtask) in task.subtasks.enumerated() {
            try db.execute(sql: """
                INSERT INTO subtasks (id, task_id, title, description, is_completed, total_time_spent, last_start_time, subtask_order)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    subtask.id.uuidString,
                    task.id.uuidString,
                    subtask.title,
                    subtask.description,
                    subtask.isCompleted ? 1 : 0,
                    subtask.totalTimeSpent,
                    subtask.lastStartTime?.timeIntervalSince1970,
                    order
                ]
            )
            try db.execute(sql: "DELETE FROM subtask_sessions WHERE subtask_id = ?", arguments: [subtask.id.uuidString])
            for session in subtask.sessions {
                try db.execute(sql: """
                    INSERT INTO subtask_sessions (subtask_id, started_at, stopped_at) VALUES (?, ?, ?)
                    """,
                    arguments: [subtask.id.uuidString, session.startedAt, session.stoppedAt]
                )
            }
        }

        // Replace task sessions
        try db.execute(sql: "DELETE FROM task_sessions WHERE task_id = ?", arguments: [task.id.uuidString])
        for session in task.sessions {
            try db.execute(sql: """
                INSERT INTO task_sessions (task_id, started_at, stopped_at) VALUES (?, ?, ?)
                """,
                arguments: [task.id.uuidString, session.startedAt, session.stoppedAt]
            )
        }
    }

    private func buildTask(from row: Row, db: Database) throws -> TodoItem {
        let idString: String = row["id"]
        let id = UUID(uuidString: idString)!

        let lastStartTimeInterval: Double? = row["last_start_time"]
        let dueDateInterval: Double? = row["due_date"]
        let countdownStartInterval: Double? = row["countdown_start_time"]
        let reminderInterval: Double? = row["reminder_date"]

        let subtaskRows = try Row.fetchAll(db,
            sql: "SELECT * FROM subtasks WHERE task_id = ? ORDER BY subtask_order ASC",
            arguments: [idString])
        let subtasks = try subtaskRows.map { sRow in
            try buildSubtask(from: sRow, db: db)
        }

        let sessionRows = try Row.fetchAll(db,
            sql: "SELECT * FROM task_sessions WHERE task_id = ?",
            arguments: [idString])
        let sessions = sessionRows.map { sRow -> TaskSession in
            let started: Double = sRow["started_at"]
            let stopped: Double? = sRow["stopped_at"]
            return TaskSession(startedAt: started, stoppedAt: stopped)
        }

        var task = TodoItem(
            id: id,
            text: row["text"],
            isCompleted: (row["is_completed"] as Int) != 0,
            index: row["index"],
            totalTimeSpent: row["total_time_spent"],
            lastStartTime: lastStartTimeInterval.map { Date(timeIntervalSince1970: $0) },
            description: row["description"],
            dueDate: dueDateInterval.map { Date(timeIntervalSince1970: $0) },
            isAdhoc: (row["is_adhoc"] as Int) != 0,
            fromWho: row["from_who"],
            estimatedTime: row["estimated_time"],
            subtasks: subtasks,
            createdAt: row["created_at"],
            startedAt: row["started_at"],
            completedAt: row["completed_at"],
            notes: row["notes"],
            countdownTime: row["countdown_time"],
            countdownStartTime: countdownStartInterval.map { Date(timeIntervalSince1970: $0) },
            countdownElapsedAtPause: row["countdown_elapsed_at_pause"],
            lastPlayedAt: row["last_played_at"],
            sessions: sessions,
            reminderDate: reminderInterval.map { Date(timeIntervalSince1970: $0) }
        )
        task.hasActiveNotification = (row["has_active_notification"] as Int) != 0
        return task
    }

    private func buildSubtask(from row: Row, db: Database) throws -> Subtask {
        let subtaskIdString: String = row["id"]
        let lastStartInterval: Double? = row["last_start_time"]

        let sessionRows = try Row.fetchAll(db,
            sql: "SELECT * FROM subtask_sessions WHERE subtask_id = ?",
            arguments: [subtaskIdString])
        let sessions = sessionRows.map { sRow -> TaskSession in
            let started: Double = sRow["started_at"]
            let stopped: Double? = sRow["stopped_at"]
            return TaskSession(startedAt: started, stoppedAt: stopped)
        }

        return Subtask(
            id: UUID(uuidString: subtaskIdString)!,
            title: row["title"],
            description: row["description"],
            isCompleted: (row["is_completed"] as Int) != 0,
            totalTimeSpent: row["total_time_spent"],
            lastStartTime: lastStartInterval.map { Date(timeIntervalSince1970: $0) },
            sessions: sessions
        )
    }

    // MARK: - Migration

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS tasks (
                    id TEXT PRIMARY KEY NOT NULL,
                    text TEXT NOT NULL,
                    is_completed INTEGER NOT NULL DEFAULT 0,
                    "index" INTEGER NOT NULL DEFAULT 0,
                    total_time_spent REAL NOT NULL DEFAULT 0,
                    last_start_time REAL,
                    description TEXT NOT NULL DEFAULT '',
                    due_date REAL,
                    is_adhoc INTEGER NOT NULL DEFAULT 0,
                    from_who TEXT NOT NULL DEFAULT '',
                    estimated_time REAL NOT NULL DEFAULT 0,
                    created_at REAL NOT NULL,
                    started_at REAL,
                    completed_at REAL,
                    notes TEXT NOT NULL DEFAULT '',
                    countdown_time REAL NOT NULL DEFAULT 0,
                    countdown_start_time REAL,
                    countdown_elapsed_at_pause REAL NOT NULL DEFAULT 0,
                    last_played_at REAL,
                    reminder_date REAL,
                    has_active_notification INTEGER NOT NULL DEFAULT 0
                )
                """)

            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS subtasks (
                    id TEXT PRIMARY KEY NOT NULL,
                    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
                    title TEXT NOT NULL,
                    description TEXT NOT NULL DEFAULT '',
                    is_completed INTEGER NOT NULL DEFAULT 0,
                    total_time_spent REAL NOT NULL DEFAULT 0,
                    last_start_time REAL,
                    subtask_order INTEGER NOT NULL DEFAULT 0
                )
                """)

            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS task_sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
                    started_at REAL NOT NULL,
                    stopped_at REAL
                )
                """)

            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS subtask_sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    subtask_id TEXT NOT NULL REFERENCES subtasks(id) ON DELETE CASCADE,
                    started_at REAL NOT NULL,
                    stopped_at REAL
                )
                """)

            // Enable cascading deletes via foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        try migrator.migrate(dbQueue)

        // Ensure foreign keys are on for every connection
        try dbQueue.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
    }
}
