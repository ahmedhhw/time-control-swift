//
//  ADOServiceTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

final class ADOServiceTests: XCTestCase {

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

    // MARK: - fetchWorkItem

    func testFetchWorkItemReturnsTitle() async throws {
        MockURLProtocol.requestHandler = { _ in
            let json = """
            {"id":42,"fields":{"System.Title":"My ADO Task","System.Description":"<p>Do the thing</p>"}}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: URL(string: "https://dev.azure.com")!,
                                           statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let item = try await service.fetchWorkItem(
            org: "myorg", project: "myproject", id: 42, pat: "secret"
        )
        XCTAssertEqual(item.id, 42)
        XCTAssertEqual(item.title, "My ADO Task")
        XCTAssertEqual(item.description, "<p>Do the thing</p>")
    }

    func testFetchWorkItemBuildsCorrectURL() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let json = """
            {"id":7,"fields":{"System.Title":"T","System.Description":""}}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        _ = try await service.fetchWorkItem(org: "contoso", project: "alpha", id: 7, pat: "p")

        let url = try XCTUnwrap(capturedRequest?.url?.absoluteString)
        XCTAssertTrue(url.contains("dev.azure.com/contoso/alpha"))
        XCTAssertTrue(url.contains("/workitems/7"))
        XCTAssertTrue(url.contains("api-version=7.1"))
    }

    func testFetchWorkItemSendsBasicAuth() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let json = """
            {"id":1,"fields":{"System.Title":"T","System.Description":""}}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        _ = try await service.fetchWorkItem(org: "o", project: "p", id: 1, pat: "mytoken")

        let auth = try XCTUnwrap(capturedRequest?.value(forHTTPHeaderField: "Authorization"))
        let expected = "Basic " + Data(":mytoken".utf8).base64EncodedString()
        XCTAssertEqual(auth, expected)
    }

    func testFetchWorkItemThrowsOn401() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.fetchWorkItem(org: "o", project: "p", id: 1, pat: "bad")
            XCTFail("Expected error")
        } catch ADOService.ADOError.unauthorized {
            // correct
        }
    }

    func testFetchWorkItemThrowsOn404() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.fetchWorkItem(org: "o", project: "p", id: 999, pat: "t")
            XCTFail("Expected error")
        } catch ADOService.ADOError.notFound {
            // correct
        }
    }

    func testFetchWorkItemThrowsOnNetworkError() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await service.fetchWorkItem(org: "o", project: "p", id: 1, pat: "t")
            XCTFail("Expected error")
        } catch ADOService.ADOError.networkUnavailable {
            // correct
        }
    }
}
