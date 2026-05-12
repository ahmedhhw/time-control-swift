//
//  HUDToastView.swift
//  TimeControl
//

import SwiftUI
import AppKit

// MARK: - Model

enum HUDAction {
    case paused, resumed
}

// MARK: - Controller (testable, no NSPanel dependency)

final class HUDToastController {
    private(set) var currentMessage: String = ""
    private(set) var isVisible: Bool = false
    private var dismissWorkItem: DispatchWorkItem?

    func show(action: HUDAction, taskName: String) {
        switch action {
        case .paused:
            currentMessage = "⏸  \"\(taskName)\" paused"
        case .resumed:
            currentMessage = "▶  \"\(taskName)\" resumed"
        }
        isVisible = true

        dismissWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.isVisible = false
        }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }
}

// MARK: - SwiftUI view

struct HUDToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - NSPanel wrapper

final class HUDToastPanel {
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    func show(message: String) {
        dismiss()

        let hosting = NSHostingView(rootView: HUDToastView(message: message))
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: 44)

        let newPanel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.contentView = hosting
        newPanel.isMovable = false

        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - hosting.frame.width - 20
            let y = screen.visibleFrame.minY + 20
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        newPanel.orderFrontRegardless()
        panel = newPanel

        let item = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }

    func dismiss() {
        dismissWorkItem?.cancel()
        panel?.orderOut(nil)
        panel = nil
    }
}
