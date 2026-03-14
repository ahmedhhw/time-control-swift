//
//  NotificationModels.swift
//  TimeControl
//

import Foundation

// Passed from NotificationScheduler → NotificationWindowManager when a reminder fires
struct NotificationPayload {
    let taskId: UUID
    let title: String
    let body: String
}

// Persisted entry in notification history
struct NotificationRecord: Codable, Identifiable {
    let id: UUID
    let taskId: UUID
    let taskTitle: String
    let firedAt: Date
    var isDismissed: Bool

    init(id: UUID = UUID(), taskId: UUID, taskTitle: String, firedAt: Date = Date(), isDismissed: Bool = false) {
        self.id = id
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.firedAt = firedAt
        self.isDismissed = isDismissed
    }
}
