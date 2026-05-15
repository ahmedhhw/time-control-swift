//
//  AppAction.swift
//  TimeControl
//

import KeyboardShortcuts

struct AppAction: Identifiable {
    let id: String
    let displayName: String
    let aliases: [String]
    let shortcutName: KeyboardShortcuts.Name?
    let handler: () -> Void

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        if displayName.lowercased().contains(q) { return true }
        return aliases.contains { $0.lowercased().contains(q) }
    }
}

enum CommandPaletteFilter {
    static func filter(actions: [AppAction], searchText: String) -> [AppAction] {
        guard !searchText.isEmpty else { return actions }
        return actions.filter { $0.matches(searchText) }
    }
}
