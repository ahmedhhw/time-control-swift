//
//  TaskPaletteWindowManager.swift
//  TimeControl
//

import AppKit
import SwiftUI

// MARK: - Standalone wrapper with opaque background

private struct StandaloneTaskPaletteView: View {
    let tasks: [TodoItem]
    let currentTaskId: UUID
    let unreadADOTaskIds: Set<UUID>
    let onSelect: (TodoItem) -> Void
    let onCreate: (String) -> Void
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0

    var body: some View {
        let _ = print("[StandalonePalette] rendering tasks=\(tasks.count) search='\(searchText)'")
        TaskPaletteView(
            tasks: tasks,
            searchText: $searchText,
            selectedIndex: $selectedIndex,
            currentTaskId: currentTaskId,
            showElapsedTime: true,
            unreadADOTaskIds: unreadADOTaskIds,
            onSelect: onSelect,
            onCreate: onCreate,
            onDismiss: onDismiss
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(1)
    }
}

// MARK: - Window manager

final class TaskPaletteWindowManager {
    static let shared = TaskPaletteWindowManager()

    private var panel: NSPanel?
    private var outsideClickMonitor: Any?

    /// Called inside dismiss() — injectable for testing.
    var onDismiss: (() -> Void)?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(viewModel: TodoViewModel) {
        dismiss()
        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 360
        _showPanel(viewModel: viewModel, origin: originNearMouse(width: panelWidth, height: panelHeight),
                   panelWidth: panelWidth, panelHeight: panelHeight)
    }

    func showCentered(viewModel: TodoViewModel) {
        dismiss()
        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 360
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let origin = CGPoint(
            x: screen.visibleFrame.midX - panelWidth / 2,
            y: screen.visibleFrame.midY - panelHeight / 2
        )
        _showPanel(viewModel: viewModel, origin: origin, panelWidth: panelWidth, panelHeight: panelHeight)
    }

    private func _showPanel(viewModel: TodoViewModel, origin: CGPoint, panelWidth: CGFloat, panelHeight: CGFloat) {
        let tasks = TaskPaletteWindowManager.availableTasks(for: viewModel)
        let currentTaskId = viewModel.todos.first(where: { $0.isRunning })?.id ?? UUID()
        print("[TaskPalette] todos=\(viewModel.todos.count) tasks=\(tasks.count)")

        let paletteView = StandaloneTaskPaletteView(
            tasks: tasks,
            currentTaskId: currentTaskId,
            unreadADOTaskIds: viewModel.unreadADOTaskIds,
            onSelect: { [weak self] task in
                viewModel.switchToTask(task)
                self?.dismiss()
            },
            onCreate: { [weak self] text in
                viewModel.filterText = text
                viewModel.addTodo()
                if let created = viewModel.todos.last {
                    viewModel.switchToTask(created)
                }
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let newPanel = NSPanel(
            contentRect: NSRect(origin: origin, size: CGSize(width: panelWidth, height: panelHeight)),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true
        newPanel.hidesOnDeactivate = false
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.becomesKeyOnlyIfNeeded = false

        let hostingController = NSHostingController(rootView: paletteView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        newPanel.contentViewController = hostingController

        panel = newPanel
        newPanel.orderFrontRegardless()
        // Defer makeKey + first responder so SwiftUI finishes layout before focus is set
        DispatchQueue.main.async {
            newPanel.makeKey()
            if let textField = hostingController.view.firstDescendant(ofType: NSTextField.self) {
                newPanel.makeFirstResponder(textField)
            }
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        guard panel != nil else { return }
        panel?.close()
        panel = nil
        onDismiss?()
    }

    // MARK: - Private helpers

    private func originNearMouse(width: CGFloat, height: CGFloat) -> CGPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let padding: CGFloat = 12
        var x = mouse.x - width / 2
        var y = mouse.y - height - padding
        // Clamp within visible frame
        let frame = screen.visibleFrame
        x = max(frame.minX + padding, min(x, frame.maxX - width - padding))
        y = max(frame.minY + padding, min(y, frame.maxY - height - padding))
        return CGPoint(x: x, y: y)
    }

    static func availableTasks(for viewModel: TodoViewModel) -> [TodoItem] {
        let incomplete = viewModel.todos.filter { !$0.isCompleted }
        var sorted: [TodoItem]

        switch viewModel.dropdownSortOption {
        case .recentlyPlayed:
            sorted = incomplete.sorted {
                let t1 = $0.lastPlayedAt ?? $0.startedAt ?? $0.createdAt
                let t2 = $1.lastPlayedAt ?? $1.startedAt ?? $1.createdAt
                return t1 > t2
            }
        case .newest:
            sorted = incomplete.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            sorted = incomplete.sorted { $0.createdAt < $1.createdAt }
        case .estimateSize:
            sorted = incomplete.sorted {
                switch ($0.estimatedTime > 0, $1.estimatedTime > 0) {
                case (true, true): return $0.estimatedTime < $1.estimatedTime
                case (true, false): return true
                case (false, true): return false
                default: return false
                }
            }
        case .dueDate:
            sorted = incomplete.sorted {
                switch ($0.dueDate, $1.dueDate) {
                case let (d1?, d2?): return d1 < d2
                case (_?, nil): return true
                case (nil, _?): return false
                default: return false
                }
            }
        }

        if viewModel.preferADOMode {
            sorted.sort { todo1, todo2 in
                let has1 = todo1.adoWorkItemId != nil
                let has2 = todo2.adoWorkItemId != nil
                if has1 != has2 { return has1 }
                return false
            }
        }

        return sorted
    }
}

private extension NSView {
    func firstDescendant<T: NSView>(ofType type: T.Type) -> T? {
        for sub in subviews {
            if let match = sub as? T { return match }
            if let match = sub.firstDescendant(ofType: type) { return match }
        }
        return nil
    }
}
