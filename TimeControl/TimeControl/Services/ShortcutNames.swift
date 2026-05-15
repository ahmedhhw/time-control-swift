//
//  ShortcutNames.swift
//  TimeControl
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleTimer  = Self("toggleTimer",  default: .init(.i, modifiers: [.command, .shift]))
    static let taskSwitcher = Self("taskSwitcher", default: .init(.l, modifiers: .command))
    static let setTimer     = Self("setTimer",     default: .init(.y, modifiers: [.command, .shift]))
    static let openNotes    = Self("openNotes",    default: .init(.d, modifiers: .command))
    static let completeTask = Self("completeTask", default: .init(.o, modifiers: .command))
    static let toggleFloatingWindowCollapse = Self("toggleFloatingWindowCollapse", default: .init(.c, modifiers: [.command, .shift]))
    static let openNotesViewer = Self("openNotesViewer", default: .init(.d, modifiers: [.command, .shift]))
    static let openADOComment   = Self("openADOComment",   default: .init(.c, modifiers: .option))
    static let openSubtaskInput = Self("openSubtaskInput", default: .init(.s, modifiers: .option))
    static let openHistory      = Self("openHistory",      default: .init(.h, modifiers: .option))
    static let showMainWindow   = Self("showMainWindow",   default: .init(.m, modifiers: .option))
    static let sendADOComment   = Self("sendADOComment",   default: .init(.return, modifiers: .command))
    static let commandPalette   = Self("commandPalette",   default: .init(.l, modifiers: [.command, .shift]))
}
