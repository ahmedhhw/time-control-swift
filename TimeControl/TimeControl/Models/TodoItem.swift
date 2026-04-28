//
//  TodoItem.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import Foundation

struct TaskSession: Codable, Equatable {
    var startedAt: TimeInterval
    var stoppedAt: TimeInterval?
    
    init(startedAt: TimeInterval = Date().timeIntervalSince1970, stoppedAt: TimeInterval? = nil) {
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
    }

    var isComplete: Bool { stoppedAt != nil }
}

struct Subtask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var isCompleted: Bool
    var totalTimeSpent: TimeInterval = 0
    var lastStartTime: Date? = nil
    var sessions: [TaskSession] = []
    
    init(id: UUID = UUID(), title: String, description: String = "", isCompleted: Bool = false, totalTimeSpent: TimeInterval = 0, lastStartTime: Date? = nil, sessions: [TaskSession] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.totalTimeSpent = totalTimeSpent
        self.lastStartTime = lastStartTime
        self.sessions = sessions
    }
    
    var isRunning: Bool {
        lastStartTime != nil
    }
    
    var currentTimeSpent: TimeInterval {
        var time = totalTimeSpent
        if let startTime = lastStartTime {
            time += Date().timeIntervalSince(startTime)
        }
        return time
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var isCompleted: Bool = false
    var index: Int
    var totalTimeSpent: TimeInterval = 0
    var lastStartTime: Date? = nil
    var description: String = ""
    var dueDate: Date? = nil
    var isAdhoc: Bool = false
    var fromWho: String = ""
    var estimatedTime: TimeInterval = 0
    var subtasks: [Subtask] = []
    var createdAt: TimeInterval
    var startedAt: TimeInterval? = nil
    var completedAt: TimeInterval? = nil
    var notes: String = ""
    var countdownTime: TimeInterval = 0
    var countdownStartTime: Date? = nil
    var countdownElapsedAtPause: TimeInterval = 0
    var lastPlayedAt: TimeInterval? = nil
    var sessions: [TaskSession] = []
    var reminderDate: Date? = nil
    var adoWorkItemId: String? = nil
    // Runtime-only state — not persisted. Set to true when NotificationScheduler fires for this task.
    var hasActiveNotification: Bool = false

    init(id: UUID = UUID(), text: String, isCompleted: Bool = false, index: Int = 0, totalTimeSpent: TimeInterval = 0, lastStartTime: Date? = nil, description: String = "", dueDate: Date? = nil, isAdhoc: Bool = false, fromWho: String = "", estimatedTime: TimeInterval = 0, subtasks: [Subtask] = [], createdAt: TimeInterval? = nil, startedAt: TimeInterval? = nil, completedAt: TimeInterval? = nil, notes: String = "", countdownTime: TimeInterval = 0, countdownStartTime: Date? = nil, countdownElapsedAtPause: TimeInterval = 0, lastPlayedAt: TimeInterval? = nil, sessions: [TaskSession] = [], reminderDate: Date? = nil, adoWorkItemId: String? = nil) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.index = index
        self.totalTimeSpent = totalTimeSpent
        self.lastStartTime = lastStartTime
        self.description = description
        self.dueDate = dueDate
        self.isAdhoc = isAdhoc
        self.fromWho = fromWho
        self.estimatedTime = estimatedTime
        self.subtasks = subtasks
        self.createdAt = createdAt ?? Date().timeIntervalSince1970
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.countdownTime = countdownTime
        self.countdownStartTime = countdownStartTime
        self.countdownElapsedAtPause = countdownElapsedAtPause
        self.lastPlayedAt = lastPlayedAt
        self.sessions = sessions
        self.reminderDate = reminderDate
        self.adoWorkItemId = adoWorkItemId
    }

    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, text, isCompleted, index, totalTimeSpent, lastStartTime, description
        case dueDate, isAdhoc, fromWho, estimatedTime, subtasks, createdAt, startedAt
        case completedAt, notes, countdownTime, countdownStartTime, countdownElapsedAtPause
        case lastPlayedAt, sessions, reminderDate, hasActiveNotification, adoWorkItemId
    }

    var isRunning: Bool {
        lastStartTime != nil
    }

    var currentTimeSpent: TimeInterval {
        var time = totalTimeSpent
        if let startTime = lastStartTime {
            time += Date().timeIntervalSince(startTime)
        }
        return time
    }
    
    var countdownElapsed: TimeInterval {
        guard countdownTime > 0 else { return 0 }
        
        if isRunning, let startTime = countdownStartTime {
            let currentSessionElapsed = Date().timeIntervalSince(startTime)
            return min(countdownElapsedAtPause + currentSessionElapsed, countdownTime)
        } else {
            return min(countdownElapsedAtPause, countdownTime)
        }
    }
}
