//
//  ADOFetchCommentsTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class ADOFetchCommentsTests: XCTestCase {

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

    // MARK: - Helpers

    private func makeCommentsJSON(comments: [[String: Any]] = []) -> Data {
        let json: [String: Any] = ["comments": comments]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func makeComment(id: Int = 1, text: String = "Hello", author: String = "Alice", date: String = "2025-04-30T10:00:00Z") -> [String: Any] {
        ["id": id, "text": text, "createdBy": ["displayName": author], "createdDate": date]
    }

    private func respond(statusCode: Int, body: Data = Data()) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }
    }

    // MARK: - ADOService.fetchComments — URL and auth

    func testFetchCommentsBuildsCorrectURL() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.makeCommentsJSON())
        }

        _ = try await service.fetchComments(org: "myorg", project: "myproj", id: 42, pat: "tok")

        let url = try XCTUnwrap(capturedRequest?.url?.absoluteString)
        XCTAssertTrue(url.contains("dev.azure.com/myorg/myproj"))
        XCTAssertTrue(url.contains("/workitems/42/comments"))
        XCTAssertTrue(url.contains("api-version=7.1-preview.3"))
    }

    func testFetchCommentsSendsBasicAuth() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.makeCommentsJSON())
        }

        _ = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "mytoken")

        let auth = try XCTUnwrap(capturedRequest?.value(forHTTPHeaderField: "Authorization"))
        let expected = "Basic " + Data(":mytoken".utf8).base64EncodedString()
        XCTAssertEqual(auth, expected)
    }

    func testFetchCommentsUsesGETMethod() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.makeCommentsJSON())
        }

        _ = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "t")

        let method = capturedRequest?.httpMethod ?? "GET"
        XCTAssertEqual(method, "GET")
    }

    // MARK: - ADOService.fetchComments — decoding

    func testFetchCommentsDecodesCommentList() async throws {
        let json = makeCommentsJSON(comments: [
            makeComment(id: 1, text: "First", author: "Alice"),
            makeComment(id: 2, text: "Second", author: "Bob")
        ])
        MockURLProtocol.requestHandler = respond(statusCode: 200, body: json)

        let result = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "t")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].text, "First")
        XCTAssertEqual(result[0].authorDisplayName, "Alice")
        XCTAssertEqual(result[1].text, "Second")
    }

    func testFetchCommentsParsesCreatedDate() async throws {
        let dateString = "2025-04-30T10:00:00Z"
        let json = makeCommentsJSON(comments: [makeComment(date: dateString)])
        MockURLProtocol.requestHandler = respond(statusCode: 200, body: json)

        let result = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "t")

        let formatter = ISO8601DateFormatter()
        let expected = formatter.date(from: dateString)!
        XCTAssertEqual(result.first?.createdDate, expected)
    }

    func testFetchCommentsReturnsEmptyArrayForZeroComments() async throws {
        MockURLProtocol.requestHandler = respond(statusCode: 200, body: makeCommentsJSON())

        let result = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "t")

        XCTAssertEqual(result, [])
    }

    func testFetchCommentsReturnsSortedNewestFirst() async throws {
        let json = makeCommentsJSON(comments: [
            makeComment(id: 1, text: "Older", date: "2025-04-28T10:00:00Z"),
            makeComment(id: 2, text: "Newer", date: "2025-04-30T10:00:00Z")
        ])
        MockURLProtocol.requestHandler = respond(statusCode: 200, body: json)

        let result = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "t")

        XCTAssertEqual(result.first?.text, "Newer")
        XCTAssertEqual(result.last?.text, "Older")
    }

    // MARK: - ADOService.fetchComments — errors

    func testFetchCommentsThrowsUnauthorizedOn401() async throws {
        MockURLProtocol.requestHandler = respond(statusCode: 401)

        do {
            _ = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "bad")
            XCTFail("Expected error")
        } catch ADOService.ADOError.unauthorized {}
    }

    func testFetchCommentsThrowsNotFoundOn404() async throws {
        MockURLProtocol.requestHandler = respond(statusCode: 404)

        do {
            _ = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "t")
            XCTFail("Expected error")
        } catch ADOService.ADOError.notFound {}
    }

    func testFetchCommentsThrowsServerErrorOn500() async throws {
        MockURLProtocol.requestHandler = respond(statusCode: 500)

        do {
            _ = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "t")
            XCTFail("Expected error")
        } catch ADOService.ADOError.serverError(let code) {
            XCTAssertEqual(code, 500)
        }
    }

    func testFetchCommentsThrowsURLErrorOnNetworkFailure() async throws {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "t")
            XCTFail("Expected error")
        } catch ADOService.ADOError.urlError {}
    }

    func testFetchCommentsThrowsInvalidResponseOnBadJSON() async throws {
        MockURLProtocol.requestHandler = respond(statusCode: 200, body: "not json".data(using: .utf8)!)

        do {
            _ = try await service.fetchComments(org: "o", project: "p", id: 1, pat: "t")
            XCTFail("Expected error")
        } catch ADOService.ADOError.invalidResponse {}
    }

    // MARK: - ADOCommentsViewModel

    @MainActor func testInitialStateIsIdle() {
        let vm = ADOCommentsViewModel(workItemId: "1", service: service)
        XCTAssertEqual(vm.state, .idle)
    }

    @MainActor func testFetchSuccessSetsLoadedState() async {
        let json = makeCommentsJSON(comments: [makeComment(id: 1), makeComment(id: 2)])
        MockURLProtocol.requestHandler = respond(statusCode: 200, body: json)

        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set("myorg", forKey: "ado.organization")
        defaults.set("myproj", forKey: "ado.project")
        defaults.set("mytoken", forKey: "ado.pat")
        let settings = ADOSettingsStore(defaults: defaults)
        let vm = ADOCommentsViewModel(workItemId: "42", service: service, settings: settings)

        await vm.fetch()

        if case .loaded(let comments) = vm.state {
            XCTAssertEqual(comments.count, 2)
        } else {
            XCTFail("Expected .loaded, got \(vm.state)")
        }
    }

    @MainActor func testFetchSuccessWithZeroCommentsSetsLoadedEmpty() async {
        MockURLProtocol.requestHandler = respond(statusCode: 200, body: makeCommentsJSON())

        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set("o", forKey: "ado.organization"); defaults.set("p", forKey: "ado.project"); defaults.set("t", forKey: "ado.pat")
        let vm = ADOCommentsViewModel(workItemId: "1", service: service, settings: ADOSettingsStore(defaults: defaults))

        await vm.fetch()

        XCTAssertEqual(vm.state, .loaded([]))
    }

    @MainActor func testFetchOn401SetsErrorState() async {
        MockURLProtocol.requestHandler = respond(statusCode: 401)

        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set("o", forKey: "ado.organization"); defaults.set("p", forKey: "ado.project"); defaults.set("t", forKey: "ado.pat")
        let vm = ADOCommentsViewModel(workItemId: "1", service: service, settings: ADOSettingsStore(defaults: defaults))

        await vm.fetch()

        if case .error = vm.state {} else { XCTFail("Expected .error, got \(vm.state)") }
    }

    @MainActor func testFetchOnNetworkFailureSetsErrorState() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set("o", forKey: "ado.organization"); defaults.set("p", forKey: "ado.project"); defaults.set("t", forKey: "ado.pat")
        let vm = ADOCommentsViewModel(workItemId: "1", service: service, settings: ADOSettingsStore(defaults: defaults))

        await vm.fetch()

        if case .error = vm.state {} else { XCTFail("Expected .error, got \(vm.state)") }
    }

    @MainActor func testRefreshAfterLoadedFetchesAgain() async {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set("o", forKey: "ado.organization"); defaults.set("p", forKey: "ado.project"); defaults.set("t", forKey: "ado.pat")
        let vm = ADOCommentsViewModel(workItemId: "1", service: service, settings: ADOSettingsStore(defaults: defaults))

        MockURLProtocol.requestHandler = respond(statusCode: 200, body: makeCommentsJSON(comments: [makeComment(id: 1)]))
        await vm.fetch()

        MockURLProtocol.requestHandler = respond(statusCode: 200, body: makeCommentsJSON(comments: [makeComment(id: 1), makeComment(id: 2)]))
        await vm.refresh()

        if case .loaded(let comments) = vm.state {
            XCTAssertEqual(comments.count, 2)
        } else {
            XCTFail("Expected .loaded with 2 comments after refresh")
        }
    }

    @MainActor func testFetchWithInvalidWorkItemIdSetsError() async {
        let vm = ADOCommentsViewModel(workItemId: "not-a-number", service: service)

        await vm.fetch()

        if case .error = vm.state {} else { XCTFail("Expected .error for invalid workItemId") }
    }

    // MARK: - ADOComment model

    func testADOCommentEquality() {
        let date = Date()
        let a = ADOComment(id: 1, text: "Hello", authorDisplayName: "Alice", createdDate: date)
        let b = ADOComment(id: 1, text: "Hello", authorDisplayName: "Alice", createdDate: date)
        let c = ADOComment(id: 2, text: "Hello", authorDisplayName: "Alice", createdDate: date)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testRelativeTimeStringIsNotEmpty() {
        let comment = ADOComment(id: 1, text: "Hi", authorDisplayName: "Alice", createdDate: Date().addingTimeInterval(-7200))
        XCTAssertFalse(comment.relativeTimeString.isEmpty)
    }
}
