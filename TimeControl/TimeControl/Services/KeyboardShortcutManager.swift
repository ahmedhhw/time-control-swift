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
        KeyboardShortcuts.onKeyDown(for: .taskSwitcher) {
            DispatchQueue.main.async {
                TaskPaletteWindowManager.shared.show(viewModel: viewModel)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .setTimer) {
            DispatchQueue.main.async {
                QuickTimerWindowManager.shared.show(viewModel: viewModel)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .openNotes) {
            DispatchQueue.main.async {
                let mgr = FloatingWindowManager.shared
                if let notes = mgr.notesWindowRef, notes.isVisible {
                    notes.close()
                } else {
                    mgr.onOpenNotes?()
                }
            }
        }
    }

    func performToggleTimerKeepWindow(viewModel: TodoViewModel) {
        // Mirror the in-view pause/resume buttons: detect actual running state from
        // lastStartTime so pause keeps `runningTaskId` set and the next press resumes.
        if let runningId = viewModel.runningTaskId,
           let task = viewModel.todos.first(where: { $0.id == runningId }) {
            if task.lastStartTime != nil {
                viewModel.pauseTask(runningId, keepWindowOpen: true)
                DispatchQueue.main.async { self.hud.show(message: "⏸  \"\(task.text)\" paused") }
            } else {
                viewModel.resumeTask(runningId)
                DispatchQueue.main.async { self.hud.show(message: "▶  \"\(task.text)\" resumed") }
            }
        } else if let task = viewModel.todos
            .filter({ !$0.isCompleted })
            .sorted(by: { ($0.lastPlayedAt ?? 0) > ($1.lastPlayedAt ?? 0) })
            .first {
            viewModel.toggleTimer(task)
            DispatchQueue.main.async { self.hud.show(message: "▶  \"\(task.text)\" resumed") }
        }
    }
}
