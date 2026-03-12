//
//  ReminderService.swift
//  TimeControl
//

import UserNotifications
import Foundation

final class ReminderService {
    static let shared = ReminderService()

    private init() {
        registerCategories()
    }

    private func registerCategories() {
        let startAction = UNNotificationAction(
            identifier: "START_TASK",
            title: "Start Task",
            options: .foreground
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_30",
            title: "Snooze 30 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [startAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("ReminderService: permission request failed: \(error)")
            } else {
                print("ReminderService: permission granted = \(granted)")
            }
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("ReminderService: authorizationStatus = \(settings.authorizationStatus.rawValue), alertSetting = \(settings.alertSetting.rawValue)")
        }
    }

    func schedule(_ task: TodoItem) {
        // Cancel any existing notification for this task first
        cancel(for: task.id)

        guard let reminderDate = task.reminderDate, reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Start: \(task.text)"
        content.body = "Your reminder to begin this task"
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"

        let interval = reminderDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("ReminderService: schedule failed for \(task.text): \(error)")
            } else {
                let local = DateFormatter.localizedString(from: reminderDate, dateStyle: .short, timeStyle: .short)
                print("ReminderService: scheduled '\(task.text)' at \(local) (local)")
            }
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            print("ReminderService: pending count = \(reqs.count), ids = \(reqs.map { $0.identifier })")
        }
    }

    func cancel(for taskId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [taskId.uuidString]
        )
    }

    func rescheduleAll(_ todos: [TodoItem]) {
        for todo in todos {
            if let reminderDate = todo.reminderDate, reminderDate > Date() {
                schedule(todo)
            }
        }
    }
}
