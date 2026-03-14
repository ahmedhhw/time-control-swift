//
//  AppDelegate.swift
//  TimeControl
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel = TodoViewModel()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire the scheduler and overlay to the view model
        NotificationScheduler.shared.viewModel = viewModel
        NotificationWindowManager.shared.viewModel = viewModel

        // Rebuild pending reminders from persisted todos (skips past ones, fires recent missed ones)
        NotificationScheduler.shared.rescheduleAll(viewModel.todos)

        setupStatusBarItem()
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

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows.first(where: { $0.isVisible })?.makeKeyAndOrderFront(nil)
    }
}
