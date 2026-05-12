//
//  ShortcutNames.swift
//  TimeControl
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleTimer  = Self("toggleTimer",  default: .init(.o, modifiers: .command))
    static let taskSwitcher = Self("taskSwitcher", default: .init(.l, modifiers: .command))
    static let setTimer     = Self("setTimer",     default: .init(.t, modifiers: [.command, .shift]))
    static let openNotes    = Self("openNotes",    default: .init(.n, modifiers: .command))
}
