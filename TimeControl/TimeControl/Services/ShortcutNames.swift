//
//  ShortcutNames.swift
//  TimeControl
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleTimer  = Self("toggleTimer",  default: .init(.i, modifiers: .command))
    static let taskSwitcher = Self("taskSwitcher", default: .init(.l, modifiers: .command))
    static let setTimer     = Self("setTimer",     default: .init(.t, modifiers: [.command, .shift]))
    static let openNotes    = Self("openNotes",    default: .init(.d, modifiers: .command))
    static let completeTask = Self("completeTask", default: .init(.o, modifiers: .command))
    static let toggleFloatingWindowCollapse = Self("toggleFloatingWindowCollapse", default: .init(.e, modifiers: [.command, .shift]))
    static let openNotesViewer = Self("openNotesViewer", default: .init(.d, modifiers: [.command, .shift]))
    static let openADOComment   = Self("openADOComment",   default: .init(.w, modifiers: .option))
    static let openSubtaskInput = Self("openSubtaskInput", default: .init(.r, modifiers: .option))
    static let openHistory      = Self("openHistory",      default: .init(.h, modifiers: .option))
    static let showMainWindow   = Self("showMainWindow",   default: .init(.b, modifiers: .option))
}
