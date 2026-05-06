//
//  NotificationWindowManager.swift
//  TimeControl
//

import AppKit
import SwiftUI

final class NotificationWindowManager {
    static let shared = NotificationWindowManager()

    private var panel: NSPanel?
    private var hostingController: NSHostingController<NotificationOverlayView>?
    private var queue: [NotificationPayload] = []
    private var dismissTimer: Timer?
    private var isHovering: Bool = false

    weak var viewModel: TodoViewModel?

    private init() {}

    // MARK: - Public API

    func show(_ payload: NotificationPayload) {
        queue.append(payload)
        if panel == nil || !(panel?.isVisible ?? false) {
            showNext()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        panel?.close()
        panel = nil
        hostingController = nil
        isHovering = false

        if !queue.isEmpty {
            queue.removeFirst()
            showNext()
        } else {
            queue = []
        }
    }

    func setHovering(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            // Cancel auto-dismiss while user is hovering
            dismissTimer?.invalidate()
            dismissTimer = nil
        } else {
            // Restart auto-dismiss countdown
            scheduleAutoDismiss()
        }
    }

    // MARK: - Private

    private func showNext() {
        guard let payload = queue.first else { return }

        guard let screen = NSScreen.main else { return }

        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 120
        let padding: CGFloat = 16

        let xPos = screen.visibleFrame.maxX - panelWidth - padding
        let yPos = screen.visibleFrame.minY + padding

        let newPanel = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.isMovableByWindowBackground = true
        newPanel.hidesOnDeactivate = false

        let overlayView = NotificationOverlayView(payload: payload, windowManager: self)
        let hostingController = NSHostingController(rootView: overlayView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        newPanel.contentViewController = hostingController

        self.panel = newPanel
        self.hostingController = hostingController

        newPanel.orderFrontRegardless()
        scheduleAutoDismiss()
    }

    private func scheduleAutoDismiss() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            guard let self, !self.isHovering else { return }
            self.dismiss()
        }
    }
}
