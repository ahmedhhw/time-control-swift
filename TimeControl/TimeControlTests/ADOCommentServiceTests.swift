//
//  ADOCommentServiceTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class ADOCommentServiceTests: XCTestCase {

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

    // MARK: - postComment success

    func testPostCommentSendsCorrectURL() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        try await service.postComment(org: "contoso", project: "backend", id: 42, comment: "hello", pat: "tok")

        let url = try XCTUnwrap(capturedRequest?.url?.absoluteString)
        XCTAssertTrue(url.contains("dev.azure.com/contoso/backend"))
        XCTAssertTrue(url.contains("/workitems/42/comments"))
    }

    func testPostCommentSendsPATAuth() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        try await service.postComment(org: "o", project: "p", id: 1, comment: "x", pat: "mytoken")

        let auth = try XCTUnwrap(capturedRequest?.value(forHTTPHeaderField: "Authorization"))
        let expected = "Basic " + Data(":mytoken".utf8).base64EncodedString()
        XCTAssertEqual(auth, expected)
    }

    func testPostCommentSendsJSONBody() async throws {
        var capturedBody: Data?
        MockURLProtocol.requestHandler = { request in
            // URLProtocol moves httpBody into httpBodyStream for POST requests
            if let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                let bufferSize = 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read > 0 { data.append(buffer, count: read) }
                }
                buffer.deallocate()
                stream.close()
                capturedBody = data
            } else {
                capturedBody = request.httpBody
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        try await service.postComment(org: "o", project: "p", id: 1, comment: "Test comment", pat: "t")

        let body = try XCTUnwrap(capturedBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: String]
        XCTAssertEqual(json?["text"], "Test comment")
    }

    func testPostCommentSendsContentTypeHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        try await service.postComment(org: "o", project: "p", id: 1, comment: "x", pat: "t")

        let contentType = capturedRequest?.value(forHTTPHeaderField: "Content-Type")
        XCTAssertEqual(contentType, "application/json")
    }

    func testPostCommentSendsPostMethod() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        try await service.postComment(org: "o", project: "p", id: 1, comment: "x", pat: "t")

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
    }

    // MARK: - postComment errors

    func testPostCommentThrowsOn401() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            try await service.postComment(org: "o", project: "p", id: 1, comment: "x", pat: "bad")
            XCTFail("Expected error")
        } catch ADOService.ADOError.unauthorized {
            // correct
        }
    }

    func testPostCommentThrowsServerErrorOnOtherCodes() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            try await service.postComment(org: "o", project: "p", id: 1, comment: "x", pat: "t")
            XCTFail("Expected error")
        } catch ADOService.ADOError.serverError(let code) {
            XCTAssertEqual(code, 500)
        }
    }

    func testPostCommentThrowsURLErrorOnNetworkFailure() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            try await service.postComment(org: "o", project: "p", id: 1, comment: "x", pat: "t")
            XCTFail("Expected error")
        } catch ADOService.ADOError.urlError {
            // correct
        }
    }
}
