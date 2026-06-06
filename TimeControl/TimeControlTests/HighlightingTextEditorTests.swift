//
//  HighlightingTextEditorTests.swift
//  TimeControlTests
//

import XCTest
import AppKit
@testable import TimeControl

final class HighlightingTextEditorTests: XCTestCase {

    private func makeTextView(text: String) -> NSTextView {
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        tv.string = text
        return tv
    }

    // MARK: - Renders text

    func testTextView_rendersBodyText() {
        let tv = makeTextView(text: "Hello world")
        XCTAssertEqual(tv.string, "Hello world")
    }

    func testTextView_rendersMultilineText() {
        let body = "Line one\nLine two\nLine three"
        let tv = makeTextView(text: body)
        XCTAssertEqual(tv.string, body)
    }

    // MARK: - Editable

    func testTextView_isEditable() {
        let tv = makeTextView(text: "")
        XCTAssertTrue(tv.isEditable)
    }

    // MARK: - No highlights when query is empty

    func testApplyHighlights_emptyQuery_noHighlightsApplied() {
        let tv = makeTextView(text: "Meeting scheduled for Thursday.")
        HighlightingTextEditor.applyHighlights(to: tv, query: "")
        let attrs = tv.textStorage?.attributes(at: 0, effectiveRange: nil)
        XCTAssertNil(attrs?[.backgroundColor])
    }

    func testApplyHighlights_blankQuery_noHighlightsApplied() {
        let tv = makeTextView(text: "Meeting scheduled for Thursday.")
        HighlightingTextEditor.applyHighlights(to: tv, query: "   ")
        let attrs = tv.textStorage?.attributes(at: 0, effectiveRange: nil)
        XCTAssertNil(attrs?[.backgroundColor])
    }

    // MARK: - Highlights applied

    func testApplyHighlights_singleMatch_highlightsCorrectRange() {
        let body = "Meeting scheduled for Thursday."
        let tv = makeTextView(text: body)
        HighlightingTextEditor.applyHighlights(to: tv, query: "scheduled")

        let matchStart = (body as NSString).range(of: "scheduled").location
        let attrs = tv.textStorage?.attributes(at: matchStart, effectiveRange: nil)
        XCTAssertNotNil(attrs?[.backgroundColor], "Match range should have a background color")
    }

    func testApplyHighlights_multipleMatches_allHighlighted() {
        let body = "Meeting on Monday. Meeting on Friday."
        let tv = makeTextView(text: body)
        HighlightingTextEditor.applyHighlights(to: tv, query: "Meeting")

        let ns = body as NSString
        let first = ns.range(of: "Meeting").location
        let second = ns.range(of: "Meeting", options: [], range: NSRange(location: first + 1, length: ns.length - first - 1)).location

        let attrs1 = tv.textStorage?.attributes(at: first, effectiveRange: nil)
        let attrs2 = tv.textStorage?.attributes(at: second, effectiveRange: nil)
        XCTAssertNotNil(attrs1?[.backgroundColor])
        XCTAssertNotNil(attrs2?[.backgroundColor])
    }

    func testApplyHighlights_caseInsensitive() {
        let body = "meeting on Monday."
        let tv = makeTextView(text: body)
        HighlightingTextEditor.applyHighlights(to: tv, query: "MEETING")

        let matchStart = (body as NSString).range(of: "meeting").location
        let attrs = tv.textStorage?.attributes(at: matchStart, effectiveRange: nil)
        XCTAssertNotNil(attrs?[.backgroundColor])
    }

    // MARK: - Highlights cleared when query changes to empty

    func testApplyHighlights_clearingQuery_removesHighlights() {
        let body = "Meeting scheduled for Thursday."
        let tv = makeTextView(text: body)
        HighlightingTextEditor.applyHighlights(to: tv, query: "scheduled")
        HighlightingTextEditor.applyHighlights(to: tv, query: "")

        let matchStart = (body as NSString).range(of: "scheduled").location
        let attrs = tv.textStorage?.attributes(at: matchStart, effectiveRange: nil)
        XCTAssertNil(attrs?[.backgroundColor])
    }

    // MARK: - Text not matching query has no highlight

    func testApplyHighlights_nonMatchingText_noHighlight() {
        let body = "Meeting scheduled for Thursday."
        let tv = makeTextView(text: body)
        HighlightingTextEditor.applyHighlights(to: tv, query: "Friday")

        let attrs = tv.textStorage?.attributes(at: 0, effectiveRange: nil)
        XCTAssertNil(attrs?[.backgroundColor])
    }
}
