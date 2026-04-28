//
//  ADOURLBuilderTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class ADOURLBuilderTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "ADOURLBuilderTests"
    private var settings: ADOSettingsStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settings = ADOSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        settings = nil
        super.tearDown()
    }

    // MARK: - buildURL

    func testBuildURL_withNumericId_andConfiguredOrgProject() {
        settings.organization = "myorg"
        settings.project = "myproject"
        let builder = ADOURLBuilder(settings: settings)
        let url = builder.buildURL(id: "12345")
        XCTAssertEqual(url?.absoluteString, "https://dev.azure.com/myorg/myproject/_workitems/edit/12345")
    }

    func testBuildURL_returnsNilWhenOrgEmpty() {
        settings.organization = ""
        settings.project = "myproject"
        let builder = ADOURLBuilder(settings: settings)
        XCTAssertNil(builder.buildURL(id: "12345"))
    }

    func testBuildURL_returnsNilWhenProjectEmpty() {
        settings.organization = "myorg"
        settings.project = ""
        let builder = ADOURLBuilder(settings: settings)
        XCTAssertNil(builder.buildURL(id: "12345"))
    }

    func testBuildURL_returnsNilWhenIdEmpty() {
        settings.organization = "myorg"
        settings.project = "myproject"
        let builder = ADOURLBuilder(settings: settings)
        XCTAssertNil(builder.buildURL(id: ""))
    }

    func testBuildURL_returnsNilWhenIdWhitespace() {
        settings.organization = "myorg"
        settings.project = "myproject"
        let builder = ADOURLBuilder(settings: settings)
        XCTAssertNil(builder.buildURL(id: "   "))
    }

    func testBuildURL_trimsWhitespaceAroundId() {
        settings.organization = "myorg"
        settings.project = "myproject"
        let builder = ADOURLBuilder(settings: settings)
        let url = builder.buildURL(id: "  12345  ")
        XCTAssertEqual(url?.absoluteString, "https://dev.azure.com/myorg/myproject/_workitems/edit/12345")
    }

    func testBuildURL_percentEncodesProjectWithSpaces() {
        settings.organization = "myorg"
        settings.project = "My Project"
        let builder = ADOURLBuilder(settings: settings)
        let url = builder.buildURL(id: "1")
        XCTAssertEqual(url?.absoluteString, "https://dev.azure.com/myorg/My%20Project/_workitems/edit/1")
    }

    // MARK: - extractId

    func testExtractId_fromFullUrl() {
        let id = ADOURLBuilder.extractId(from: "https://dev.azure.com/myorg/myproject/_workitems/edit/12345")
        XCTAssertEqual(id, "12345")
    }

    func testExtractId_fromUrlWithQueryString() {
        let id = ADOURLBuilder.extractId(from: "https://dev.azure.com/myorg/myproject/_workitems/edit/12345?foo=bar")
        XCTAssertEqual(id, "12345")
    }

    func testExtractId_fromUrlWithEncodedProject() {
        let id = ADOURLBuilder.extractId(from: "https://dev.azure.com/myorg/My%20Project/_workitems/edit/987")
        XCTAssertEqual(id, "987")
    }

    func testExtractId_fromBareNumber() {
        XCTAssertEqual(ADOURLBuilder.extractId(from: "12345"), "12345")
    }

    func testExtractId_fromBareNumberWithWhitespace() {
        XCTAssertEqual(ADOURLBuilder.extractId(from: "  12345  "), "12345")
    }

    func testExtractId_returnsNilForGarbage() {
        XCTAssertNil(ADOURLBuilder.extractId(from: "hello world"))
    }

    func testExtractId_returnsNilForEmpty() {
        XCTAssertNil(ADOURLBuilder.extractId(from: ""))
        XCTAssertNil(ADOURLBuilder.extractId(from: "   "))
    }
}
