//
//  IdlePromptWindowManager.swift
//  TimeControl
//

import AppKit
import SwiftUI

final class IdlePromptWindowManager {
    static let shared = IdlePromptWindowManager()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<IdlePromptView>?

    private init() {}

    // MARK: - Public API

    func show(viewModel: TodoViewModel) {
        // Don't stack prompts
        guard panel == nil || !(panel?.isVisible ?? false) else { return }

        let screen = screenForPrompt()
        let panelWidth: CGFloat = 360
        let panelHeight: CGFloat = 180
        let padding: CGFloat = 16

        let xPos = screen.visibleFrame.maxX - panelWidth - padding
        let yPos = screen.visibleFrame.maxY - panelHeight - padding

        let newPanel = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.isMovableByWindowBackground = true
        newPanel.hidesOnDeactivate = false

        let monitor = IdleActivityMonitor.shared
        let promptView = IdlePromptView(
            onStartTask: { [weak self] in
                monitor.handleStartTask()
                self?.dismiss()
                IdlePromptWindowManager.focusMainWindowAndNewTaskInput(viewModel: viewModel)
            },
            onDismiss: { [weak self] in
                monitor.handleDismiss()
                self?.dismiss()
            },
            onSnooze: { [weak self] minutes in
                monitor.handleSnooze(minutes: minutes)
                self?.dismiss()
            }
        )

        let hosting = NSHostingView(rootView: promptView)
        hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        newPanel.contentView = hosting

        panel = newPanel
        hostingView = hosting
        newPanel.orderFrontRegardless()
    }

    func dismiss() {
        panel?.close()
        panel = nil
        hostingView = nil
    }

    // MARK: - Private helpers

    private func screenForPrompt() -> NSScreen {
        // Use the screen containing the current mouse position, falling back to main
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private static func focusMainWindowAndNewTaskInput(viewModel: TodoViewModel) {
        NSApp.activate(ignoringOtherApps: true)
        // Find and bring forward the main ContentView window
        if let mainWindow = NSApp.windows.first(where: { $0.contentViewController is NSHostingController<ContentView> })
            ?? NSApp.windows.filter({ !($0 is NSPanel) }).first {
            mainWindow.makeKeyAndOrderFront(nil)
        }
        viewModel.requestFocusNewTaskInput()
    }
}
