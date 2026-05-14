//
//  KeyboardShortcutManager.swift
//  TimeControl
//

import AppKit
import KeyboardShortcuts

final class KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()

    private let hud = HUDToastPanel()

    func setup(viewModel: TodoViewModel) {
        KeyboardShortcuts.onKeyDown(for: .toggleTimer) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self?.performToggleTimerKeepWindow(viewModel: viewModel) }
        }
        KeyboardShortcuts.onKeyDown(for: .taskSwitcher) { [weak self] in
            DispatchQueue.main.async { self?.performShowTaskSwitcher(viewModel: viewModel) }
        }
        KeyboardShortcuts.onKeyDown(for: .setTimer) { [weak self] in
            DispatchQueue.main.async { self?.performShowQuickTimer(viewModel: viewModel) }
        }
        KeyboardShortcuts.onKeyDown(for: .openNotes) { [weak self] in
            DispatchQueue.main.async { self?.performToggleNotes() }
        }
        KeyboardShortcuts.onKeyDown(for: .completeTask) { [weak self] in
            DispatchQueue.main.async { self?.performCompleteTask(viewModel: viewModel) }
        }
        KeyboardShortcuts.onKeyDown(for: .toggleFloatingWindowCollapse) { [weak self] in
            DispatchQueue.main.async { self?.performToggleFloatingWindowCollapse() }
        }
        KeyboardShortcuts.onKeyDown(for: .openNotesViewer) { [weak self] in
            DispatchQueue.main.async { self?.performToggleNotesViewer() }
        }
        KeyboardShortcuts.onKeyDown(for: .openADOComment) { [weak self] in
            DispatchQueue.main.async { self?.performOpenADOComment() }
        }
        KeyboardShortcuts.onKeyDown(for: .openSubtaskInput) { [weak self] in
            DispatchQueue.main.async { self?.performOpenSubtaskInput() }
        }
        KeyboardShortcuts.onKeyDown(for: .openHistory) { [weak self] in
            DispatchQueue.main.async { self?.performOpenHistory() }
        }
        KeyboardShortcuts.onKeyDown(for: .showMainWindow) { [weak self] in
            DispatchQueue.main.async { self?.performShowMainWindow() }
        }
    }

    func performToggleTimerKeepWindow(viewModel: TodoViewModel) {
        // Mirror the in-view pause/resume buttons: detect actual running state from
        // lastStartTime so pause keeps `runningTaskId` set and the next press resumes.
        if let runningId = viewModel.runningTaskId,
           let task = viewModel.todos.first(where: { $0.id == runningId }) {
            if task.lastStartTime != nil {
                viewModel.pauseTask(runningId, keepWindowOpen: true)
            } else {
                viewModel.resumeTask(runningId)
            }
        } else if let task = viewModel.todos
            .filter({ !$0.isCompleted })
            .sorted(by: { ($0.lastPlayedAt ?? 0) > ($1.lastPlayedAt ?? 0) })
            .first {
            viewModel.toggleTimer(task)
        }
    }

    func performShowTaskSwitcher(viewModel: TodoViewModel) {
        TaskPaletteWindowManager.shared.showCentered(viewModel: viewModel)
    }

    func performShowQuickTimer(viewModel: TodoViewModel) {
        QuickTimerWindowManager.shared.show(viewModel: viewModel)
    }

    func performToggleNotes() {
        let mgr = FloatingWindowManager.shared
        if let notes = mgr.notesWindowRef, notes.isVisible {
            notes.close()
        } else {
            mgr.onOpenNotes?()
        }
    }

    func performCompleteTask(viewModel: TodoViewModel) {
        guard FloatingWindowManager.shared.isWindowOpen,
              let task = FloatingWindowManager.shared.currentTask else {
            return
        }

        viewModel.completeTaskFromFloatingWindow(task.id)

        if let updatedTask = viewModel.todos.first(where: { $0.id == task.id }) {
            FloatingWindowManager.shared.updateTask(updatedTask)
        }
    }

    func performToggleNotesViewer() {
        let mgr = FloatingWindowManager.shared
        if let viewer = mgr.notesViewerWindowRef, viewer.isVisible {
            if viewer.isKeyWindow {
                viewer.close()
            } else {
                mgr.onOpenNotesViewer?()
            }
        } else {
            mgr.onOpenNotesViewer?()
        }
    }

    func performToggleFloatingWindowCollapse() {
        let mgr = FloatingWindowManager.shared
        guard mgr.isWindowOpen else { return }
        mgr.onToggleCollapse?()
    }

    func performOpenADOComment() {
        let mgr = FloatingWindowManager.shared
        guard mgr.isWindowOpen else { return }
        guard let task = mgr.currentTask,
              let adoId = task.adoWorkItemId, !adoId.isEmpty else {
            hud.show(message: "No ADO link on this task")
            return
        }
        mgr.activateFloatingWindow()
        mgr.onOpenADOAndFocusComment?()
    }

    func performOpenSubtaskInput() {
        let mgr = FloatingWindowManager.shared
        guard mgr.isWindowOpen else { return }
        mgr.activateFloatingWindow()
        mgr.onOpenSubtasksAndFocusInput?()
    }

    func performOpenHistory() {
        let mgr = FloatingWindowManager.shared
        if let win = mgr.historyWindowRef, win.isVisible {
            if win.isKeyWindow {
                win.close()
            } else {
                NotificationCenter.default.post(name: .openHistoryWindow, object: nil)
            }
        } else {
            NotificationCenter.default.post(name: .openHistoryWindow, object: nil)
        }
    }

    func performShowMainWindow() {
        guard let mainWindow = NSApp.windows.first(where: { !($0 is NSPanel) && $0.isVisible }) else { return }
        if mainWindow.isKeyWindow {
            mainWindow.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }
}
