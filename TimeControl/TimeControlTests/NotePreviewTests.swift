//
//  NotePreviewTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class NotePreviewTests: XCTestCase {

    // MARK: - Empty / blank body

    func testMatchPreview_emptyBody_returnsEmpty() {
        XCTAssertEqual(NotePreview.matchPreview(body: "", query: ""), "")
    }

    func testMatchPreview_whitespaceBody_returnsEmpty() {
        XCTAssertEqual(NotePreview.matchPreview(body: "   \n  ", query: ""), "")
    }

    // MARK: - No query: returns first non-empty line

    func testMatchPreview_noQuery_returnsFirstLine() {
        let body = "First line\nSecond line"
        XCTAssertEqual(NotePreview.matchPreview(body: body, query: ""), "First line")
    }

    func testMatchPreview_blankQuery_returnsFirstLine() {
        let body = "First line\nSecond line"
        XCTAssertEqual(NotePreview.matchPreview(body: body, query: "   "), "First line")
    }

    func testMatchPreview_noQuery_skipsLeadingBlankLines() {
        let body = "\n\nFirst non-empty\nSecond line"
        XCTAssertEqual(NotePreview.matchPreview(body: body, query: ""), "First non-empty")
    }

    // MARK: - Query: returns matching line

    func testMatchPreview_queryMatchesSecondLine_returnsSecondLine() {
        let body = "Unrelated first line\nMeeting on Thursday"
        XCTAssertEqual(NotePreview.matchPreview(body: body, query: "meeting"), "Meeting on Thursday")
    }

    func testMatchPreview_queryMatchesCaseInsensitive() {
        let body = "Follow up with JAKE about the contract"
        XCTAssertEqual(NotePreview.matchPreview(body: body, query: "jake"), "Follow up with JAKE about the contract")
    }

    func testMatchPreview_queryNoMatch_fallsBackToFirstLine() {
        let body = "First line\nSecond line"
        XCTAssertEqual(NotePreview.matchPreview(body: body, query: "nomatch"), "First line")
    }

    // MARK: - Truncation for long lines

    func testMatchPreview_shortMatchingLine_notTruncated() {
        let body = "Short line with query"
        XCTAssertEqual(NotePreview.matchPreview(body: body, query: "query"), "Short line with query")
    }

    func testMatchPreview_longMatchingLine_truncatedWithEllipsis() {
        // line is > 60 chars and match is in the middle
        let body = "The quick brown fox jumped over the lazy dog and then the retrospective began here at the end"
        let result = NotePreview.matchPreview(body: body, query: "retrospective")
        XCTAssertTrue(result.contains("retrospective"), "Result must contain the match")
        XCTAssertTrue(result.hasPrefix("…") || result.count <= 60, "Long line must be truncated")
    }

    func testMatchPreview_longMatchingLine_resultIsReasonableLength() {
        let body = String(repeating: "x", count: 30) + "TARGET" + String(repeating: "y", count: 30)
        let result = NotePreview.matchPreview(body: body, query: "TARGET")
        XCTAssertTrue(result.contains("TARGET"))
        XCTAssertLessThanOrEqual(result.count, 75)
    }
}
