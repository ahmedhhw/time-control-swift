//
//  AppDelegate.swift
//  TimeControl
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel = TodoViewModel()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire the scheduler and overlay to the view model
        NotificationScheduler.shared.viewModel = viewModel
        NotificationWindowManager.shared.viewModel = viewModel

        // Rebuild pending reminders from persisted todos (skips past ones, fires recent missed ones)
        NotificationScheduler.shared.rescheduleAll(viewModel.todos)

        // Restore bell state for any notifications that fired before the last quit
        viewModel.restoreActiveNotifications()

        setupStatusBarItem()
        setupPopover()
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "TimeControl")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 340)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: NotificationHistoryView(viewModel: viewModel, onOpenApp: { [weak self] in
                self?.popover?.close()
                self?.openMainWindow()
            })
        )
        self.popover = popover
    }

    @objc private func statusBarButtonClicked() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.close()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows.first(where: { $0.isVisible })?.makeKeyAndOrderFront(nil)
    }
}
