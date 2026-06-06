//
//  CommandPaletteWindowManagerTests.swift
//  TimeControlTests
//

import XCTest
import KeyboardShortcuts
@testable import TimeControl

final class CommandPaletteWindowManagerTests: XCTestCase {

    private var manager: CommandPaletteWindowManager!

    override func setUp() {
        super.setUp()
        manager = CommandPaletteWindowManager()
    }

    override func tearDown() {
        manager.dismiss()
        manager = nil
        super.tearDown()
    }

    // MARK: - Visibility

    func testShow_makesWindowVisible() {
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        XCTAssertTrue(manager.isVisible)
    }

    func testDismiss_hidesWindow() {
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        manager.dismiss()
        XCTAssertFalse(manager.isVisible)
    }

    func testShowTwice_doesNotStackPanels() {
        let (vm, _, _) = makeViewModel()
        manager.show(viewModel: vm)
        manager.show(viewModel: vm)
        XCTAssertTrue(manager.isVisible)
    }

    // MARK: - onDismiss callback

    func testDismiss_callsOnDismissCallback() {
        let (vm, _, _) = makeViewModel()
        var called = false
        manager.onDismiss = { called = true }
        manager.show(viewModel: vm)
        manager.dismiss()
        XCTAssertTrue(called)
    }

    func testOnDismiss_notCalledIfNeverShown() {
        var called = false
        manager.onDismiss = { called = true }
        manager.dismiss()
        XCTAssertFalse(called)
    }

    // MARK: - buildActions

    func testBuildActions_returns11Actions() {
        let (vm, _, _) = makeViewModel()
        XCTAssertEqual(manager.buildActions(viewModel: vm).count, 11)
    }

    func testBuildActions_allHaveUniqueIds() {
        let (vm, _, _) = makeViewModel()
        let actions = manager.buildActions(viewModel: vm)
        let ids = actions.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testBuildActions_allHaveNonEmptyDisplayNames() {
        let (vm, _, _) = makeViewModel()
        XCTAssertTrue(manager.buildActions(viewModel: vm).allSatisfy { !$0.displayName.isEmpty })
    }

    func testBuildActions_allHaveShortcutName() {
        let (vm, _, _) = makeViewModel()
        XCTAssertTrue(manager.buildActions(viewModel: vm).allSatisfy { $0.shortcutName != nil })
    }

    func testBuildActions_containsOpenNotesAction() {
        let (vm, _, _) = makeViewModel()
        XCTAssertTrue(manager.buildActions(viewModel: vm).contains(where: { $0.id == "openNotes" }))
    }

    func testBuildActions_openNotes_hasNotesAlias() {
        let (vm, _, _) = makeViewModel()
        let action = manager.buildActions(viewModel: vm).first(where: { $0.id == "openNotes" })!
        XCTAssertTrue(action.aliases.contains("notes"))
    }

    func testBuildActions_completeTask_hasDoneAlias() {
        let (vm, _, _) = makeViewModel()
        let action = manager.buildActions(viewModel: vm).first(where: { $0.id == "completeTask" })!
        XCTAssertTrue(action.aliases.contains("done"))
    }

    // MARK: - formatShortcut

    @MainActor
    func testFormatShortcut_returnsNonNilForAllDefaultShortcuts() {
        let names: [KeyboardShortcuts.Name] = [
            .toggleTimer, .taskSwitcher, .setTimer, .openNotes, .openNotesViewer,
            .completeTask, .toggleFloatingWindowCollapse, .openADOComment,
            .openSubtaskInput, .openHistory, .showMainWindow
        ]
        for name in names {
            KeyboardShortcuts.reset(name)
            XCTAssertNotNil(
                CommandPaletteWindowManager.formatShortcut(for: name),
                "Expected non-nil for \(name)"
            )
        }
    }

    @MainActor
    func testFormatShortcut_toggleTimer_containsCommandSymbol() {
        KeyboardShortcuts.reset(.toggleTimer)
        let result = CommandPaletteWindowManager.formatShortcut(for: .toggleTimer)
        XCTAssertTrue(result?.contains("⌘") ?? false)
    }

    @MainActor
    func testFormatShortcut_setTimer_containsShiftSymbol() {
        KeyboardShortcuts.reset(.setTimer)
        let result = CommandPaletteWindowManager.formatShortcut(for: .setTimer)
        XCTAssertTrue(result?.contains("⇧") ?? false)
    }

    @MainActor
    func testFormatShortcut_openHistory_containsShiftSymbol() {
        KeyboardShortcuts.reset(.openHistory)
        let result = CommandPaletteWindowManager.formatShortcut(for: .openHistory)
        XCTAssertTrue(result?.contains("⇧") ?? false)
    }

    @MainActor
    func testFormatShortcut_clearedShortcut_returnsNil() {
        KeyboardShortcuts.setShortcut(nil, for: .commandPalette)
        XCTAssertNil(CommandPaletteWindowManager.formatShortcut(for: .commandPalette))
    }
}
