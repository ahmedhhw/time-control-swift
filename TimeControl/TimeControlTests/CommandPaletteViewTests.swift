//
//  CommandPaletteViewTests.swift
//  TimeControlTests
//

import XCTest
import SwiftUI
@testable import TimeControl

final class CommandPaletteViewTests: XCTestCase {

    private func makeActions() -> [AppAction] {
        [
            AppAction(id: "testA", displayName: "Test Action A", aliases: ["alpha"], shortcutName: nil, handler: {}),
            AppAction(id: "testB", displayName: "Test Action B", aliases: ["beta"],  shortcutName: nil, handler: {}),
        ]
    }

    func testCommandPaletteView_instantiatesWithoutCrashing() {
        let view = CommandPaletteView(actions: makeActions(), onDismiss: {})
        XCTAssertNoThrow(_ = view.body)
    }

    func testCommandPaletteView_emptyActions_instantiatesWithoutCrashing() {
        let view = CommandPaletteView(actions: [], onDismiss: {})
        XCTAssertNoThrow(_ = view.body)
    }

    func testCommandPaletteView_singleAction_instantiatesWithoutCrashing() {
        let actions = [AppAction(id: "x", displayName: "Only Action", aliases: [], shortcutName: nil, handler: {})]
        let view = CommandPaletteView(actions: actions, onDismiss: {})
        XCTAssertNoThrow(_ = view.body)
    }
}
