//
//  NotificationScheduler.swift
//  TimeControl
//

import Foundation

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    // task id → snapped fire time (seconds zeroed out)
    private var pending: [UUID: Date] = [:]
    private var pollTimer: Timer?

    // Injected by AppDelegate after view model is set up
    weak var viewModel: TodoViewModel?

    private init() {
        startPolling()
    }

    // MARK: - Public API

    func schedule(_ task: TodoItem) {
        guard let reminderDate = task.reminderDate else { return }
        let snapped = snap(reminderDate)
        // Only schedule if the snapped time is in the future (or same minute as now)
        guard snapped >= snapNow() else { return }
        pending[task.id] = snapped
        print("NotificationScheduler: scheduled '\(task.text)' at \(snapped)")
    }

    func schedule(_ task: TodoItem, at date: Date) {
        let snapped = snap(date)
        guard snapped >= snapNow() else { return }
        pending[task.id] = snapped
        print("NotificationScheduler: rescheduled '\(task.text)' at \(snapped)")
    }

    func cancel(for taskId: UUID) {
        if pending.removeValue(forKey: taskId) != nil {
            print("NotificationScheduler: cancelled \(taskId)")
        }
    }

    func rescheduleAll(_ todos: [TodoItem]) {
        pending = [:]
        let now = snapNow()
        for todo in todos {
            guard let reminderDate = todo.reminderDate else { continue }
            let snapped = snap(reminderDate)

            // Fire immediately if missed by less than 5 minutes
            let missedWindow: TimeInterval = 5 * 60
            if snapped < now && now.timeIntervalSince(snapped) <= missedWindow {
                fire(taskId: todo.id, taskTitle: todo.text)
            } else if snapped >= now {
                pending[todo.id] = snapped
            }
        }
        print("NotificationScheduler: rescheduleAll — \(pending.count) pending")
    }

    // MARK: - Private

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.tick()
        }
        pollTimer?.tolerance = 5
    }

    private func tick() {
        let currentMinute = snapNow()
        var toFire: [(UUID, String)] = []

        for (taskId, fireTime) in pending {
            if fireTime == currentMinute {
                let title = viewModel?.todos.first(where: { $0.id == taskId })?.text ?? "Task"
                toFire.append((taskId, title))
            }
        }

        for (taskId, title) in toFire {
            pending.removeValue(forKey: taskId)
            fire(taskId: taskId, taskTitle: title)
        }
    }

    private func fire(taskId: UUID, taskTitle: String) {
        let record = NotificationRecord(taskId: taskId, taskTitle: taskTitle)
        NotificationStore.shared.append(record)

        DispatchQueue.main.async { [weak self] in
            self?.viewModel?.setActiveNotification(true, for: taskId)
        }

        let payload = NotificationPayload(
            taskId: taskId,
            title: "Start: \(taskTitle)",
            body: "Your reminder to begin this task"
        )
        DispatchQueue.main.async {
            NotificationWindowManager.shared.show(payload)
        }

        print("NotificationScheduler: fired reminder for '\(taskTitle)'")
    }

    // MARK: - Helpers

    private func snap(_ date: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        comps.second = 0
        return Calendar.current.date(from: comps) ?? date
    }

    private func snapNow() -> Date {
        snap(Date())
    }
}
