//
//  TodoStorage.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import Foundation

class TodoStorage {
    private static let storageURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("todos.json")
    }()

    static func save(todos: [TodoItem], notificationRecords: [NotificationRecord]) {
        var tasksDict: [String: [String: Any]] = [:]

        for todo in todos {
            var taskData: [String: Any] = [
                "title": todo.text,
                "index": todo.index,
                "isCompleted": todo.isCompleted,
                "totalTimeSpent": todo.totalTimeSpent,
                "description": todo.description,
                "isAdhoc": todo.isAdhoc,
                "fromWho": todo.fromWho,
                "estimatedTime": todo.estimatedTime,
                "createdAt": todo.createdAt,
                "notes": todo.notes
            ]

            if let lastStartTime = todo.lastStartTime {
                taskData["lastStartTime"] = lastStartTime.timeIntervalSince1970
            }

            if let dueDate = todo.dueDate {
                taskData["dueDate"] = dueDate.timeIntervalSince1970
            }

            if let startedAt = todo.startedAt {
                taskData["startedAt"] = startedAt
            }

            if let completedAt = todo.completedAt {
                taskData["completedAt"] = completedAt
            }

            if todo.reminderDate != nil || todo.hasActiveNotification {
                if let reminderDate = todo.reminderDate {
                    taskData["reminderDate"] = reminderDate.timeIntervalSince1970
                }
                if todo.hasActiveNotification {
                    taskData["hasActiveNotification"] = true
                }
            }

            let sessionsArray: [[String: Any]] = todo.sessions.map { session in
                var s: [String: Any] = ["startedAt": session.startedAt]
                if let stopped = session.stoppedAt { s["stoppedAt"] = stopped }
                return s
            }
            taskData["sessions"] = sessionsArray

            var subtasksArray: [[String: Any]] = []
            for subtask in todo.subtasks {
                let subtaskSessions: [[String: Any]] = subtask.sessions.map { session in
                    var s: [String: Any] = ["startedAt": session.startedAt]
                    if let stopped = session.stoppedAt { s["stoppedAt"] = stopped }
                    return s
                }
                subtasksArray.append([
                    "id": subtask.id.uuidString,
                    "title": subtask.title,
                    "description": subtask.description,
                    "isCompleted": subtask.isCompleted,
                    "totalTimeSpent": subtask.totalTimeSpent,
                    "sessions": subtaskSessions
                ])
            }
            taskData["subtasks"] = subtasksArray

            tasksDict[todo.id.uuidString] = taskData
        }

        var recordsArray: [[String: Any]] = []
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(notificationRecords),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            recordsArray = decoded
        }

        let jsonData: [String: Any] = ["tasks": tasksDict, "notificationRecords": recordsArray]

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
            try data.write(to: storageURL)
        } catch {
            print("Error saving todos: \(error.localizedDescription)")
        }
    }

    static func load() -> (todos: [TodoItem], notificationRecords: [NotificationRecord]) {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return ([], [])
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Load notification records
            var notificationRecords: [NotificationRecord] = []
            if let recordsRaw = json?["notificationRecords"],
               let recordsData = try? JSONSerialization.data(withJSONObject: recordsRaw) {
                let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
                notificationRecords = (try? JSONDecoder().decode([NotificationRecord].self, from: recordsData))?
                    .filter { $0.firedAt > cutoff }
                    .sorted { $0.firedAt > $1.firedAt } ?? []
            }

            guard let tasksDict = json?["tasks"] as? [String: [String: Any]] else {
                return ([], notificationRecords)
            }

            var todos: [TodoItem] = []
            for (idString, taskData) in tasksDict {
                guard let id = UUID(uuidString: idString),
                      let title = taskData["title"] as? String,
                      let index = taskData["index"] as? Int else {
                    continue
                }

                let isCompleted = taskData["isCompleted"] as? Bool ?? false
                let totalTimeSpent = taskData["totalTimeSpent"] as? TimeInterval ?? 0
                let description = taskData["description"] as? String ?? ""
                let isAdhoc = taskData["isAdhoc"] as? Bool ?? false
                let fromWho = taskData["fromWho"] as? String ?? ""
                let estimatedTime = taskData["estimatedTime"] as? TimeInterval ?? 0
                let createdAt = taskData["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                let startedAt = taskData["startedAt"] as? TimeInterval
                let completedAt = taskData["completedAt"] as? TimeInterval
                let notes = taskData["notes"] as? String ?? ""

                var lastStartTime: Date? = nil
                if let timestamp = taskData["lastStartTime"] as? TimeInterval {
                    lastStartTime = Date(timeIntervalSince1970: timestamp)
                }

                var dueDate: Date? = nil
                if let timestamp = taskData["dueDate"] as? TimeInterval {
                    dueDate = Date(timeIntervalSince1970: timestamp)
                }

                var reminderDate: Date? = nil
                if let timestamp = taskData["reminderDate"] as? TimeInterval {
                    reminderDate = Date(timeIntervalSince1970: timestamp)
                }

                let hasActiveNotification = taskData["hasActiveNotification"] as? Bool ?? false

                let taskSessions: [TaskSession] = (taskData["sessions"] as? [[String: Any]] ?? []).compactMap { s in
                    guard let start = s["startedAt"] as? TimeInterval else { return nil }
                    return TaskSession(startedAt: start, stoppedAt: s["stoppedAt"] as? TimeInterval)
                }

                var subtasks: [Subtask] = []
                if let subtasksArray = taskData["subtasks"] as? [[String: Any]] {
                    for subtaskData in subtasksArray {
                        guard let subtaskIdString = subtaskData["id"] as? String,
                              let subtaskId = UUID(uuidString: subtaskIdString),
                              let subtaskTitle = subtaskData["title"] as? String else {
                            continue
                        }
                        let subtaskDescription = subtaskData["description"] as? String ?? ""
                        let subtaskIsCompleted = subtaskData["isCompleted"] as? Bool ?? false
                        let subtaskTotalTimeSpent = subtaskData["totalTimeSpent"] as? TimeInterval ?? 0
                        let subtaskSessions: [TaskSession] = (subtaskData["sessions"] as? [[String: Any]] ?? []).compactMap { s in
                            guard let start = s["startedAt"] as? TimeInterval else { return nil }
                            return TaskSession(startedAt: start, stoppedAt: s["stoppedAt"] as? TimeInterval)
                        }
                        subtasks.append(Subtask(id: subtaskId, title: subtaskTitle, description: subtaskDescription, isCompleted: subtaskIsCompleted, totalTimeSpent: subtaskTotalTimeSpent, sessions: subtaskSessions))
                    }
                }

                var todo = TodoItem(id: id, text: title, isCompleted: isCompleted, index: index, totalTimeSpent: totalTimeSpent, lastStartTime: lastStartTime, description: description, dueDate: dueDate, isAdhoc: isAdhoc, fromWho: fromWho, estimatedTime: estimatedTime, subtasks: subtasks, createdAt: createdAt, startedAt: startedAt, completedAt: completedAt, notes: notes, sessions: taskSessions, reminderDate: reminderDate)
                todo.hasActiveNotification = hasActiveNotification
                todos.append(todo)
            }

            return (todos.sorted { $0.index < $1.index }, notificationRecords)
        } catch {
            print("Error loading todos: \(error.localizedDescription)")
            return ([], [])
        }
    }
}
