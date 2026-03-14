//
//  AppDelegate.swift
//  TimeControl
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel = TodoViewModel()
    private var statusItem: NSStatusItem?
    private var historyPanel: NSPanel?
    private var outsideClickMonitor: Any?

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
        if let panel = historyPanel, panel.isVisible {
            closeHistoryPanel()
        } else {
            showHistoryPanel()
        }
    }

    private func showHistoryPanel() {
        guard let button = statusItem?.button,
              let buttonWindow = button.window else { return }

        let panelWidth: CGFloat = 300
        let panelHeight: CGFloat = 340

        let buttonFrameOnScreen = buttonWindow.convertToScreen(button.frame)
        let xPos = buttonFrameOnScreen.midX - panelWidth / 2
        let yPos = buttonFrameOnScreen.minY - panelHeight

        let panel = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentViewController = NSHostingController(
            rootView: NotificationHistoryView(viewModel: viewModel, onOpenApp: { [weak self] in
                self?.closeHistoryPanel()
                self?.openMainWindow()
            })
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        historyPanel = panel
        panel.orderFrontRegardless()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeHistoryPanel()
        }
    }

    private func closeHistoryPanel() {
        historyPanel?.close()
        historyPanel = nil
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows.first(where: { $0.isVisible })?.makeKeyAndOrderFront(nil)
    }
}
