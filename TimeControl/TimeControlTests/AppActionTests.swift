//
//  AppActionTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class AppActionTests: XCTestCase {

    private func makeAction(name: String, aliases: [String] = []) -> AppAction {
        AppAction(id: name, displayName: name, aliases: aliases, shortcutName: nil, handler: {})
    }

    // MARK: - AppAction.matches

    func test_matches_emptyQuery_returnsTrue() {
        let action = makeAction(name: "Open Notes")
        XCTAssertTrue(action.matches(""))
    }

    func test_matches_displayNameContainsQuery_returnsTrue() {
        let action = makeAction(name: "Open Notes")
        XCTAssertTrue(action.matches("notes"))
    }

    func test_matches_displayNameDoesNotContainQuery_returnsFalse() {
        let action = makeAction(name: "Open Notes")
        XCTAssertFalse(action.matches("timer"))
    }

    func test_matches_aliasContainsQuery_returnsTrue() {
        let action = makeAction(name: "Complete Task", aliases: ["done", "finish"])
        XCTAssertTrue(action.matches("done"))
    }

    func test_matches_caseInsensitive_displayName() {
        let action = makeAction(name: "Play / Pause Timer")
        XCTAssertTrue(action.matches("PLAY"))
    }

    func test_matches_caseInsensitive_alias() {
        let action = makeAction(name: "Complete Task", aliases: ["DONE"])
        XCTAssertTrue(action.matches("done"))
    }

    func test_matches_partialAlias_returnsTrue() {
        let action = makeAction(name: "Open History", aliases: ["history"])
        XCTAssertTrue(action.matches("hist"))
    }

    // MARK: - CommandPaletteFilter.filter

    func test_filter_emptySearch_returnsAll() {
        let actions = [makeAction(name: "A"), makeAction(name: "B"), makeAction(name: "C")]
        XCTAssertEqual(CommandPaletteFilter.filter(actions: actions, searchText: "").count, 3)
    }

    func test_filter_matchingSearch_returnsOnlyMatches() {
        let actions = [
            makeAction(name: "Open Notes"),
            makeAction(name: "Set Timer"),
            makeAction(name: "Open History")
        ]
        let result = CommandPaletteFilter.filter(actions: actions, searchText: "open")
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.displayName.lowercased().contains("open") })
    }

    func test_filter_noMatch_returnsEmpty() {
        let actions = [makeAction(name: "Open Notes"), makeAction(name: "Set Timer")]
        XCTAssertTrue(CommandPaletteFilter.filter(actions: actions, searchText: "xyz").isEmpty)
    }

    func test_filter_preservesOrder() {
        let actions = [makeAction(name: "Zebra"), makeAction(name: "Apple"), makeAction(name: "Mango")]
        let result = CommandPaletteFilter.filter(actions: actions, searchText: "")
        XCTAssertEqual(result.map(\.displayName), ["Zebra", "Apple", "Mango"])
    }

    func test_filter_byAlias_returnsMatch() {
        let actions = [
            makeAction(name: "Complete Task", aliases: ["done"]),
            makeAction(name: "Open Notes")
        ]
        let result = CommandPaletteFilter.filter(actions: actions, searchText: "done")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].displayName, "Complete Task")
    }

    func test_filter_caseInsensitive() {
        let actions = [makeAction(name: "Open Notes"), makeAction(name: "Set Timer")]
        let result = CommandPaletteFilter.filter(actions: actions, searchText: "NOTES")
        XCTAssertEqual(result.count, 1)
    }
}
