//
//  LinkParserTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class LinkParserTests: XCTestCase {

    // MARK: - Plain text

    func testPlainTextReturnsSingleTextSegment() {
        let segments = LinkParser.parse("Hello world")
        XCTAssertEqual(segments, [.text("Hello world")])
    }

    func testEmptyStringReturnsEmptySegments() {
        let segments = LinkParser.parse("")
        XCTAssertEqual(segments, [])
    }

    // MARK: - Single URL

    func testHttpsURLReturnsSingleLinkSegment() {
        let segments = LinkParser.parse("https://example.com")
        XCTAssertEqual(segments, [.link(URL(string: "https://example.com")!)])
    }

    func testHttpURLReturnsSingleLinkSegment() {
        let segments = LinkParser.parse("http://example.com/path")
        XCTAssertEqual(segments, [.link(URL(string: "http://example.com/path")!)])
    }

    // MARK: - Mixed text and URLs

    func testTextBeforeLinkProducesTextThenLink() {
        let segments = LinkParser.parse("See https://example.com")
        XCTAssertEqual(segments, [
            .text("See "),
            .link(URL(string: "https://example.com")!)
        ])
    }

    func testTextAfterLinkProducesLinkThenText() {
        let segments = LinkParser.parse("https://example.com is great")
        XCTAssertEqual(segments, [
            .link(URL(string: "https://example.com")!),
            .text(" is great")
        ])
    }

    func testTextSurroundingLinkProducesThreeSegments() {
        let segments = LinkParser.parse("See https://example.com for details")
        XCTAssertEqual(segments, [
            .text("See "),
            .link(URL(string: "https://example.com")!),
            .text(" for details")
        ])
    }

    // MARK: - Multiple URLs

    func testMultipleLinksProduceMultipleLinkSegments() {
        let segments = LinkParser.parse("https://a.com and https://b.com")
        XCTAssertEqual(segments, [
            .link(URL(string: "https://a.com")!),
            .text(" and "),
            .link(URL(string: "https://b.com")!)
        ])
    }

    // MARK: - URLs with query strings and paths

    func testURLWithQueryStringParsesCorrectly() {
        let segments = LinkParser.parse("Go to https://example.com/page?q=1&r=2 now")
        XCTAssertEqual(segments, [
            .text("Go to "),
            .link(URL(string: "https://example.com/page?q=1&r=2")!),
            .text(" now")
        ])
    }
}
