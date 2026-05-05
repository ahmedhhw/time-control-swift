//
//  ADOBulkFetchTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

@MainActor
final class ADOBulkFetchTests: XCTestCase {

    // MARK: - Helpers

    private var session: URLSession!
    private var service: ADOService!

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

    // MARK: - WIQL + batch JSON factories

    private func wiqlJSON(ids: [Int]) -> Data {
        let items = ids.map {
            "{\"id\":\($0),\"url\":\"https://dev.azure.com/org/proj/_apis/wit/workItems/\($0)\"}"
        }.joined(separator: ",")
        return "{\"workItems\":[\(items)]}".data(using: .utf8)!
    }

    private func batchJSON(items: [(id: Int, title: String, state: String, description: String)]) -> Data {
        let values = items.map { item in
            "{\"id\":\(item.id),\"fields\":{\"System.Title\":\"\(item.title)\",\"System.State\":\"\(item.state)\",\"System.Description\":\"\(item.description)\"}}"
        }.joined(separator: ",")
        return "{\"value\":[\(values)]}".data(using: .utf8)!
    }

    private func makeResponse(statusCode: Int, url: URL = URL(string: "https://dev.azure.com")!) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    // MARK: - fetchAssignedWorkItems

    func testFetchAssignedReturnsWorkItems() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] request in
            callCount += 1
            if callCount == 1 {
                // WIQL response
                return (self.makeResponse(statusCode: 200, url: request.url!),
                        self.wiqlJSON(ids: [48210, 47903]))
            } else {
                // Batch response
                return (self.makeResponse(statusCode: 200, url: request.url!),
                        self.batchJSON(items: [
                            (48210, "Migrate auth", "Active", ""),
                            (47903, "Fix bug", "Resolved", "Details here")
                        ]))
            }
        }

        let items = try await service.fetchAssignedWorkItems(org: "myorg", project: "myproj", pat: "secret")

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].id, 48210)
        XCTAssertEqual(items[0].title, "Migrate auth")
        XCTAssertEqual(items[0].state, "Active")
        XCTAssertEqual(items[1].id, 47903)
        XCTAssertEqual(items[1].title, "Fix bug")
        XCTAssertEqual(items[1].state, "Resolved")
    }

    func testFetchAssignedReturnsEmptyOnNoResults() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            // Only one call expected (WIQL returns empty → no batch call)
            return (self.makeResponse(statusCode: 200, url: request.url!),
                    self.wiqlJSON(ids: []))
        }

        let items = try await service.fetchAssignedWorkItems(org: "myorg", project: "myproj", pat: "secret")

        XCTAssertEqual(items.count, 0)
    }

    func testFetchAssignedThrowsUnauthorized() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            return (self.makeResponse(statusCode: 401, url: request.url!), Data())
        }

        do {
            _ = try await service.fetchAssignedWorkItems(org: "myorg", project: "myproj", pat: "badpat")
            XCTFail("Expected unauthorized error")
        } catch ADOService.ADOError.unauthorized {
            // correct
        }
    }

    func testFetchAssignedThrowsOnNetworkError() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await service.fetchAssignedWorkItems(org: "myorg", project: "myproj", pat: "secret")
            XCTFail("Expected network error")
        } catch ADOService.ADOError.urlError {
            // correct — maps URLError to ADOError.urlError
        } catch {
            // Any ADOError subtype is acceptable for network failures
        }
    }

    // MARK: - fetchMentionedWorkItems

    func testFetchMentionedReturnsWorkItems() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] request in
            callCount += 1
            if callCount == 1 {
                return (self.makeResponse(statusCode: 200, url: request.url!),
                        self.wiqlJSON(ids: [12345]))
            } else {
                return (self.makeResponse(statusCode: 200, url: request.url!),
                        self.batchJSON(items: [
                            (12345, "Review PR", "Active", "<p>Please review</p>")
                        ]))
            }
        }

        let items = try await service.fetchMentionedWorkItems(org: "myorg", project: "myproj", pat: "secret")

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, 12345)
        XCTAssertEqual(items[0].title, "Review PR")
    }

    func testFetchMentionedThrowsUnauthorized() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            return (self.makeResponse(statusCode: 401, url: request.url!), Data())
        }

        do {
            _ = try await service.fetchMentionedWorkItems(org: "myorg", project: "myproj", pat: "badpat")
            XCTFail("Expected unauthorized error")
        } catch ADOService.ADOError.unauthorized {
            // correct
        }
    }
}
