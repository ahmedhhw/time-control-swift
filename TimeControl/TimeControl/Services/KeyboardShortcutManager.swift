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
            DispatchQueue.main.async { self?.performToggleTimer(viewModel: viewModel) }
        }
        KeyboardShortcuts.onKeyDown(for: .taskSwitcher) {
            DispatchQueue.main.async {
                TaskPalettePanelManager.shared.show(viewModel: viewModel)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .setTimer) {
            DispatchQueue.main.async {
                QuickTimerWindowManager.shared.show(viewModel: viewModel)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .openNotes) {
            DispatchQueue.main.async {
                FloatingWindowManager.shared.onOpenNotes?()
            }
        }
    }

    func performToggleTimer(viewModel: TodoViewModel) {
        if let runningId = viewModel.runningTaskId,
           let task = viewModel.todos.first(where: { $0.id == runningId }) {
            viewModel.pauseTask(runningId, keepWindowOpen: false)
            hud.show(message: "⏸  \"\(task.text)\" paused")
        } else if let task = viewModel.todos
            .filter({ !$0.isCompleted })
            .sorted(by: { ($0.lastPlayedAt ?? 0) > ($1.lastPlayedAt ?? 0) })
            .first {
            viewModel.toggleTimer(task)
            hud.show(message: "▶  \"\(task.text)\" resumed")
        }
    }
}
