//
//  TaskPalettePanel.swift
//  TimeControl
//

import AppKit
import SwiftUI

// MARK: - Elapsed time label helper (testable, no UI dependency)

enum TaskPaletteElapsedTime {
    static func label(totalTimeSpent: TimeInterval, lastStartTime: Date? = nil) -> String? {
        var total = totalTimeSpent
        if let start = lastStartTime {
            total += max(0, Date().timeIntervalSince(start))
        }
        let minutes = Int(total) / 60
        guard minutes > 0 else { return nil }
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    static func label(task: TodoItem) -> String? {
        label(totalTimeSpent: task.totalTimeSpent, lastStartTime: task.lastStartTime)
    }
}

// MARK: - Panel manager (observable state for tests + UI)

final class TaskPalettePanelManager: ObservableObject {
    static let shared = TaskPalettePanelManager()

    @Published private(set) var isVisible: Bool = false

    private var panel: NSPanel?
    private var outsideClickMonitor: Any?

    func show(viewModel: TodoViewModel) {
        if isVisible { return }

        let view = TaskPalettePanelContent(viewModel: viewModel) { [weak self] in
            self?.dismiss()
        }

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 400)

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
        newPanel.hasShadow = true

        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - hosting.frame.width / 2
            let y = screen.visibleFrame.midY + 40
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel = newPanel
        newPanel.orderFrontRegardless()
        newPanel.makeKey()
        isVisible = true

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        panel?.close()
        panel = nil
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        isVisible = false
    }
}

// MARK: - SwiftUI content view for the panel

private struct TaskPalettePanelContent: View {
    @ObservedObject var viewModel: TodoViewModel
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0

    private var tasks: [TodoItem] {
        let incomplete = viewModel.todos.filter { !$0.isCompleted }
        return incomplete.sorted {
            let t1 = $0.lastPlayedAt ?? $0.createdAt
            let t2 = $1.lastPlayedAt ?? $1.createdAt
            return t1 > t2
        }
    }

    private var currentTaskId: UUID {
        viewModel.runningTaskId ?? UUID()
    }

    var body: some View {
        VStack(spacing: 0) {
            TaskPaletteView(
                tasks: tasks,
                searchText: $searchText,
                selectedIndex: $selectedIndex,
                currentTaskId: currentTaskId,
                showElapsedTime: true,
                unreadADOTaskIds: viewModel.unreadADOTaskIds,
                onSelect: { task in
                    viewModel.switchToTask(task)
                    onDismiss()
                },
                onCreate: { title in
                    let newTask = TodoItem(text: title, index: viewModel.todos.count)
                    viewModel.insertTodo(newTask)
                    if let created = viewModel.todos.last {
                        viewModel.switchToTask(created)
                    }
                    onDismiss()
                },
                onDismiss: onDismiss
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(radius: 20)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
