//
//  ADOServiceAttachmentTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class ADOServiceAttachmentTests: XCTestCase {

    var session: URLSession!
    var service: ADOService!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        service = ADOService(session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - uploadAttachment

    func testUploadAttachmentSendsOctetStreamContentType() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let json = #"{"url":"https://dev.azure.com/org/proj/_apis/wit/attachments/abc"}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        _ = try await service.uploadAttachment(
            org: "myorg", project: "myproj",
            filename: "image.png", data: Data([0x89, 0x50, 0x4E, 0x47]),
            pat: "mytoken"
        )

        let contentType = try XCTUnwrap(capturedRequest?.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(contentType, "application/octet-stream")
    }

    func testUploadAttachmentSendsCorrectURL() async throws {
        var capturedURL: String?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url?.absoluteString
            let json = #"{"url":"https://dev.azure.com/org/proj/_apis/wit/attachments/abc"}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        _ = try await service.uploadAttachment(
            org: "contoso", project: "alpha",
            filename: "pasted-image-1.png", data: Data([0]),
            pat: "tok"
        )

        let url = try XCTUnwrap(capturedURL)
        XCTAssertTrue(url.contains("dev.azure.com/contoso/alpha"), "Expected org/project in URL, got: \(url)")
        XCTAssertTrue(url.contains("/wit/attachments"), "Expected /wit/attachments in URL, got: \(url)")
        XCTAssertTrue(url.contains("fileName=pasted-image-1.png"), "Expected fileName query param, got: \(url)")
    }

    func testUploadAttachmentReturnsURL() async throws {
        let expectedURLString = "https://dev.azure.com/myorg/myproj/_apis/wit/attachments/xyz-123"
        MockURLProtocol.requestHandler = { request in
            let json = "{\"url\":\"\(expectedURLString)\"}".data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let result = try await service.uploadAttachment(
            org: "myorg", project: "myproj",
            filename: "screenshot.png", data: Data([0x01]),
            pat: "token"
        )

        XCTAssertEqual(result.absoluteString, expectedURLString)
    }

    func testUploadAttachmentThrowsOnUnauthorized() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.uploadAttachment(
                org: "o", project: "p", filename: "img.png", data: Data([0]), pat: "bad"
            )
            XCTFail("Expected unauthorized error")
        } catch ADOService.ADOError.unauthorized {
            // correct
        }
    }

    func testUploadAttachmentThrowsOnServerError() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.uploadAttachment(
                org: "o", project: "p", filename: "img.png", data: Data([0]), pat: "tok"
            )
            XCTFail("Expected serverError")
        } catch ADOService.ADOError.serverError(let code) {
            XCTAssertEqual(code, 500)
        }
    }
}
