//
//  CommandPaletteWindowManager.swift
//  TimeControl
//

import AppKit
import SwiftUI
import KeyboardShortcuts

// MARK: - Standalone wrapper

private struct StandaloneCommandPaletteView: View {
    let actions: [AppAction]
    let onDismiss: () -> Void

    var body: some View {
        CommandPaletteView(actions: actions, onDismiss: onDismiss)
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

final class CommandPaletteWindowManager {
    static let shared = CommandPaletteWindowManager()

    private var panel: NSPanel?
    private var outsideClickMonitor: Any?

    var onDismiss: (() -> Void)?
    var isVisible: Bool { panel?.isVisible ?? false }

    func show(viewModel: TodoViewModel) {
        dismiss()
        let actions = buildActions(viewModel: viewModel)
        let width: CGFloat = 440
        let height: CGFloat = 380
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let origin = CGPoint(
            x: screen.visibleFrame.midX - width / 2,
            y: screen.visibleFrame.midY - height / 2
        )

        let paletteView = StandaloneCommandPaletteView(
            actions: actions,
            onDismiss: { [weak self] in self?.dismiss() }
        )

        let newPanel = NSPanel(
            contentRect: NSRect(origin: origin, size: CGSize(width: width, height: height)),
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
        hostingController.view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        newPanel.contentViewController = hostingController

        panel = newPanel
        newPanel.orderFrontRegardless()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in self?.dismiss() }

        DispatchQueue.main.async {
            newPanel.makeKey()
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

    func buildActions(viewModel: TodoViewModel) -> [AppAction] {
        let mgr = KeyboardShortcutManager.shared
        return [
            AppAction(id: "toggleTimer",      displayName: "Play / Pause Timer",
                      aliases: ["play", "pause", "resume", "start", "stop", "timer"],
                      shortcutName: .toggleTimer,
                      handler: { mgr.performToggleTimerKeepWindow(viewModel: viewModel) }),
            AppAction(id: "taskSwitcher",     displayName: "Switch Task",
                      aliases: ["switch", "change", "task"],
                      shortcutName: .taskSwitcher,
                      handler: { mgr.performShowTaskSwitcher(viewModel: viewModel) }),
            AppAction(id: "setTimer",         displayName: "Set Countdown Timer",
                      aliases: ["countdown", "timer", "set"],
                      shortcutName: .setTimer,
                      handler: { mgr.performShowQuickTimer(viewModel: viewModel) }),
            AppAction(id: "openNotes",        displayName: "Open Notes",
                      aliases: ["notes", "note"],
                      shortcutName: .openNotes,
                      handler: { mgr.performToggleNotes() }),
            AppAction(id: "openNotesViewer",  displayName: "Open Notes Viewer",
                      aliases: ["notes viewer", "viewer"],
                      shortcutName: .openNotesViewer,
                      handler: { mgr.performToggleNotesViewer() }),
            AppAction(id: "completeTask",     displayName: "Complete Task",
                      aliases: ["complete", "done", "finish", "close"],
                      shortcutName: .completeTask,
                      handler: { mgr.performCompleteTask(viewModel: viewModel) }),
            AppAction(id: "collapse",         displayName: "Collapse / Expand Window",
                      aliases: ["collapse", "expand", "minimize"],
                      shortcutName: .toggleFloatingWindowCollapse,
                      handler: { mgr.performToggleFloatingWindowCollapse() }),
            AppAction(id: "openADOComment",   displayName: "Open ADO Comment",
                      aliases: ["ado", "comment"],
                      shortcutName: .openADOComment,
                      handler: { mgr.performOpenADOComment() }),
            AppAction(id: "openSubtaskInput", displayName: "Add Subtask",
                      aliases: ["subtask", "add"],
                      shortcutName: .openSubtaskInput,
                      handler: { mgr.performOpenSubtaskInput() }),
            AppAction(id: "openHistory",      displayName: "Open History",
                      aliases: ["history"],
                      shortcutName: .openHistory,
                      handler: { mgr.performOpenHistory() }),
            AppAction(id: "showMainWindow",   displayName: "Show / Hide Main Window",
                      aliases: ["main", "window", "show", "hide"],
                      shortcutName: .showMainWindow,
                      handler: { mgr.performShowMainWindow() }),
        ]
    }

    @MainActor
    static func formatShortcut(for name: KeyboardShortcuts.Name) -> String? {
        KeyboardShortcuts.getShortcut(for: name)?.description
    }
}

