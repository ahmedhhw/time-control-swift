//
//  AppDelegate.swift
//  TimeControl
//

import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var viewModel = TodoViewModel()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        ReminderService.shared.requestPermission()
        ReminderService.shared.rescheduleAll(viewModel.todos)
        setupStatusBarItem()
        scheduleTestNotification()
    }

    private func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Fired 10s after launch"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "TEST_NOTIFICATION", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("AppDelegate: test notification failed: \(error)") }
            else { print("AppDelegate: test notification scheduled, fires in 10s") }
        }
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "TimeControl")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
    }

    @objc private func statusBarButtonClicked() {
        openMainWindow()
    }

    // Show notification banner even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        print("AppDelegate: willPresent notification id=\(notification.request.identifier) title=\(notification.request.content.title)")
        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        print("AppDelegate: didReceive response id=\(response.notification.request.identifier) action=\(response.actionIdentifier)")
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
