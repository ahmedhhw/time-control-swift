//
//  NotificationOverlayView.swift
//  TimeControl
//

import SwiftUI
import AppKit

struct NotificationOverlayView: View {
    let payload: NotificationPayload
    let windowManager: NotificationWindowManager

    @State private var slideOffset: CGFloat = 60
    @State private var opacity: Double = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(payload.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(payload.body)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button(action: startTask) {
                        Text("Start Task")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(action: snooze) {
                        Text("Snooze 30m")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
        }
        .frame(width: 340, height: 100)
        .offset(x: slideOffset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                slideOffset = 0
                opacity = 1
            }
        }
        .onHover { hovering in
            windowManager.setHovering(hovering)
        }
    }

    // MARK: - Actions

    private func startTask() {
        // Open main window and switch to the task
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows
            .first(where: { $0.isVisible && !($0 is NSPanel) })?
            .makeKeyAndOrderFront(nil)

        windowManager.viewModel?.switchToTask(byId: payload.taskId)

        // Open the floating task window if it isn't already open
        if let viewModel = windowManager.viewModel,
           let task = viewModel.todos.first(where: { $0.id == payload.taskId }),
           !FloatingWindowManager.shared.isWindowOpen {
            FloatingWindowManager.shared.showFloatingWindow(for: task, viewModel: viewModel)
        }

        // Dismiss overlay — bell stays lit until user explicitly clicks it
        windowManager.dismiss()
    }

    private func snooze() {
        let snoozedDate = Date().addingTimeInterval(30 * 60)
        if let task = windowManager.viewModel?.todos.first(where: { $0.id == payload.taskId }) {
            NotificationScheduler.shared.schedule(task, at: snoozedDate)
        }
        // Dismiss overlay; bell stays lit (re-queued but current notification not acknowledged)
        windowManager.dismiss()
    }
}
