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

    // MARK: - fetchCurrentUserProfile

    func testFetchProfileReturnsDisplayNameAndId() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            XCTAssertTrue(request.url?.host == "dev.azure.com", "Should call dev.azure.com, not vssps")
            XCTAssertTrue(request.url?.path.contains("connectiondata") == true)
            let json = """
            {"authenticatedUser":{"providerDisplayName":"Ahmed H","id":"abc-123"}}
            """.data(using: .utf8)!
            return (self.makeResponse(statusCode: 200, url: request.url!), json)
        }

        let profile = try await service.fetchCurrentUserProfile(org: "myorg", pat: "secret")

        XCTAssertEqual(profile.displayName, "Ahmed H")
        XCTAssertEqual(profile.id, "abc-123")
    }

    func testFetchProfileThrowsUnauthorizedOn401() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            return (self.makeResponse(statusCode: 401, url: request.url!), Data())
        }

        do {
            _ = try await service.fetchCurrentUserProfile(org: "myorg", pat: "badpat")
            XCTFail("Expected unauthorized error")
        } catch ADOService.ADOError.unauthorized {
            // correct
        }
    }

    func testFetchProfileThrowsOnNetworkError() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await service.fetchCurrentUserProfile(org: "myorg", pat: "secret")
            XCTFail("Expected network error")
        } catch ADOService.ADOError.urlError {
            // correct
        }
    }

    // MARK: - searchCommentMentions

    private func searchJSON(ids: [Int]) -> Data {
        let results = ids.map { id in
            "{\"fields\":{\"system.id\":\"\(id)\",\"system.title\":\"Item \(id)\",\"system.state\":\"Active\"}}"
        }.joined(separator: ",")
        return "{\"count\":\(ids.count),\"results\":[\(results)]}".data(using: .utf8)!
    }

    func testSearchCommentMentionsReturnsIds() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            XCTAssertTrue(request.url?.host == "almsearch.dev.azure.com")
            XCTAssertEqual(request.httpMethod, "POST")
            if let body = request.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
                XCTAssertTrue(bodyStr.contains("Ahmed H"))
            }
            return (self.makeResponse(statusCode: 200, url: request.url!), self.searchJSON(ids: [42, 99]))
        }

        let ids = try await service.searchCommentMentions(
            org: "myorg", project: "myproj", pat: "secret", displayName: "Ahmed H"
        )

        XCTAssertEqual(ids, [42, 99])
    }

    func testSearchCommentMentionsReturnsEmptyWhenNoResults() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            return (self.makeResponse(statusCode: 200, url: request.url!), self.searchJSON(ids: []))
        }

        let ids = try await service.searchCommentMentions(
            org: "myorg", project: "myproj", pat: "secret", displayName: "Ahmed H"
        )

        XCTAssertTrue(ids.isEmpty)
    }

    func testSearchCommentMentionsThrowsOn401() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            return (self.makeResponse(statusCode: 401, url: request.url!), Data())
        }

        do {
            _ = try await service.searchCommentMentions(
                org: "myorg", project: "myproj", pat: "badpat", displayName: "Ahmed H"
            )
            XCTFail("Expected unauthorized error")
        } catch ADOService.ADOError.unauthorized {
            // correct
        }
    }

    func testSearchCommentMentionsThrowsOnNetworkError() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await service.searchCommentMentions(
                org: "myorg", project: "myproj", pat: "secret", displayName: "Ahmed H"
            )
            XCTFail("Expected network error")
        } catch ADOService.ADOError.urlError {
            // correct
        }
    }

    // MARK: - fetchMentionedWorkItems

    func testFetchMentionedCallsProfileThenSearchThenBatch() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] request in
            callCount += 1
            switch callCount {
            case 1: // Profile API
                XCTAssertTrue(request.url?.host == "dev.azure.com")
                let json = "{\"authenticatedUser\":{\"providerDisplayName\":\"Ahmed H\",\"id\":\"abc-123\"}}".data(using: .utf8)!
                return (self.makeResponse(statusCode: 200, url: request.url!), json)
            case 2: // Search API
                XCTAssertTrue(request.url?.host == "almsearch.dev.azure.com")
                XCTAssertEqual(request.httpMethod, "POST")
                return (self.makeResponse(statusCode: 200, url: request.url!), self.searchJSON(ids: [42]))
            default: // Batch fetch
                XCTAssertTrue(request.url?.absoluteString.contains("workitemsbatch") == true)
                return (self.makeResponse(statusCode: 200, url: request.url!),
                        self.batchJSON(items: [(42, "Review PR", "Active", "<p>Please review</p>")]))
            }
        }

        let items = try await service.fetchMentionedWorkItems(org: "myorg", project: "myproj", pat: "secret")

        XCTAssertEqual(callCount, 3)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, 42)
        XCTAssertEqual(items[0].title, "Review PR")
        XCTAssertEqual(items[0].state, "Active")
    }

    func testFetchMentionedReturnsEmptyWhenSearchFindsNothing() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] request in
            callCount += 1
            if callCount == 1 {
                let json = "{\"authenticatedUser\":{\"providerDisplayName\":\"Ahmed H\",\"id\":\"abc-123\"}}".data(using: .utf8)!
                return (self.makeResponse(statusCode: 200, url: request.url!), json)
            }
            return (self.makeResponse(statusCode: 200, url: request.url!), self.searchJSON(ids: []))
        }

        let items = try await service.fetchMentionedWorkItems(org: "myorg", project: "myproj", pat: "secret")

        XCTAssertEqual(callCount, 2, "No batch call should be made when search returns empty")
        XCTAssertTrue(items.isEmpty)
    }

    func testFetchMentionedThrowsWhenProfileFails() async throws {
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

    func testFetchMentionedThrowsWhenSearchFails() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] request in
            callCount += 1
            if callCount == 1 {
                let json = "{\"authenticatedUser\":{\"providerDisplayName\":\"Ahmed H\",\"id\":\"abc-123\"}}".data(using: .utf8)!
                return (self.makeResponse(statusCode: 200, url: request.url!), json)
            }
            return (self.makeResponse(statusCode: 401, url: request.url!), Data())
        }

        do {
            _ = try await service.fetchMentionedWorkItems(org: "myorg", project: "myproj", pat: "secret")
            XCTFail("Expected unauthorized error")
        } catch ADOService.ADOError.unauthorized {
            // correct
        }
    }

    // MARK: - Batch chunking

    func testFetchAssignedChunksRequestsWhenOver200Ids() async throws {
        // 250 IDs should produce exactly 2 batch calls (200 + 50)
        let ids = Array(1...250)
        var batchCallCount = 0

        MockURLProtocol.requestHandler = { [self] request in
            if request.url?.absoluteString.contains("wiql") == true {
                return (self.makeResponse(statusCode: 200, url: request.url!), self.wiqlJSON(ids: ids))
            } else {
                batchCallCount += 1
                // Return a fixed-size response per call so we can verify items combined
                let chunk = batchCallCount == 1
                    ? Array(1...200).map { id in (id: id, title: "Item \(id)", state: "Active", description: "") }
                    : Array(201...250).map { id in (id: id, title: "Item \(id)", state: "Active", description: "") }
                return (self.makeResponse(statusCode: 200, url: request.url!), self.batchJSON(items: chunk))
            }
        }

        let items = try await service.fetchAssignedWorkItems(org: "myorg", project: "myproj", pat: "secret")

        XCTAssertEqual(batchCallCount, 2, "Should make 2 batch calls for 250 IDs")
        XCTAssertEqual(items.count, 250)
    }

    func testFetchAssignedDoesNotChunkWhenUnder200Ids() async throws {
        let ids = Array(1...150)
        var batchCallCount = 0

        MockURLProtocol.requestHandler = { [self] request in
            if request.url?.absoluteString.contains("wiql") == true {
                return (self.makeResponse(statusCode: 200, url: request.url!), self.wiqlJSON(ids: ids))
            } else {
                batchCallCount += 1
                let items = ids.map { id in (id: id, title: "Item \(id)", state: "Active", description: "") }
                return (self.makeResponse(statusCode: 200, url: request.url!), self.batchJSON(items: items))
            }
        }

        let items = try await service.fetchAssignedWorkItems(org: "myorg", project: "myproj", pat: "secret")

        XCTAssertEqual(batchCallCount, 1, "Should make exactly 1 batch call for 150 IDs")
        XCTAssertEqual(items.count, 150)
    }
}
