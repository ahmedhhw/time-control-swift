//
//  AppDelegate.swift
//  TimeControl
//

import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var viewModel = TodoViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        ReminderService.shared.rescheduleAll(viewModel.todos)
    }

    // Show notification banner even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let taskIdStr = response.notification.request.identifier
        guard let taskId = UUID(uuidString: taskIdStr) else { return }

        await MainActor.run {
            switch response.actionIdentifier {
            case "START_TASK":
                openMainWindow()
                viewModel.switchToTask(byId: taskId)
            case "SNOOZE_30":
                viewModel.setReminder(Date().addingTimeInterval(30 * 60), for: taskId)
            default: // banner tap
                openMainWindow()
            }
        }
    }

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows.first(where: { $0.isVisible })?.makeKeyAndOrderFront(nil)
    }
}
