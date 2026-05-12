//
//  QuickTimerWindow.swift
//  TimeControl
//

import AppKit
import SwiftUI

// MARK: - Testable controller (no NSPanel dependency)

final class QuickTimerController: ObservableObject {
    @Published var hours: Int = 0
    @Published var minutes: Int = 15

    private let viewModel: TodoViewModel

    var canSet: Bool { hours > 0 || minutes > 0 }

    var runningTaskName: String? {
        guard let id = viewModel.runningTaskId else { return nil }
        return viewModel.todos.first(where: { $0.id == id })?.text
    }

    init(viewModel: TodoViewModel) {
        self.viewModel = viewModel
    }

    func commit() {
        guard let taskId = viewModel.runningTaskId else { return }
        let totalSeconds = TimeInterval(hours * 3600 + minutes * 60)
        viewModel.setCountdown(taskId: taskId, time: totalSeconds)
    }

    func clear() {
        guard let taskId = viewModel.runningTaskId else { return }
        viewModel.clearCountdown(taskId: taskId)
    }
}

// MARK: - Panel manager

final class QuickTimerWindowManager: ObservableObject {
    static let shared = QuickTimerWindowManager()

    @Published private(set) var isVisible: Bool = false

    private var panel: NSPanel?

    func show(viewModel: TodoViewModel) {
        if isVisible { return }

        let controller = QuickTimerController(viewModel: viewModel)
        let view = QuickTimerContent(controller: controller) { [weak self] in
            self?.dismiss()
        }

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 250)

        let newPanel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        if let taskName = controller.runningTaskName {
            newPanel.title = "Set timer — \(taskName)"
        } else {
            newPanel.title = "Set timer — No active task"
        }
        newPanel.isReleasedWhenClosed = false
        newPanel.contentView = hosting
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = false

        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - hosting.frame.width / 2
            let y = screen.visibleFrame.midY - hosting.frame.height / 2
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel = newPanel
        newPanel.orderFrontRegardless()
        newPanel.makeKey()
        isVisible = true
    }

    func dismiss() {
        panel?.close()
        panel = nil
        isVisible = false
    }
}

// MARK: - SwiftUI content

private struct QuickTimerContent: View {
    @ObservedObject var controller: QuickTimerController
    let onDismiss: () -> Void

    var body: some View {
        TimerPickerSheet(
            hours: $controller.hours,
            minutes: $controller.minutes,
            onSet: {
                controller.commit()
                onDismiss()
            },
            onCancel: {
                onDismiss()
            }
        )
    }
}
