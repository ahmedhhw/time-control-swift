//
//  ADOCommentViewModelTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

@MainActor
final class ADOCommentViewModelTests: XCTestCase {

    var session: URLSession!
    var service: ADOService!
    var settings: ADOSettingsStore!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        service = ADOService(session: session)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("myorg", forKey: "ado.organization")
        defaults.set("myproj", forKey: "ado.project")
        defaults.set("mytoken", forKey: "ado.pat")
        settings = ADOSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    private func makeVM(workItemId: String = "42") -> ADOCommentViewModel {
        ADOCommentViewModel(workItemId: workItemId, service: service, settings: settings)
    }

    // MARK: - Initial state

    func testInitialPhaseIsIdle() {
        let vm = makeVM()
        XCTAssertEqual(vm.phase, .idle)
    }

    func testInitialCommentTextIsEmpty() {
        let vm = makeVM()
        XCTAssertEqual(vm.commentText, "")
    }

    // MARK: - open / cancel

    func testOpenSetsPhaseToOpen() {
        let vm = makeVM()
        vm.open()
        XCTAssertEqual(vm.phase, .open)
    }

    func testCancelResetsToIdle() {
        let vm = makeVM()
        vm.open()
        vm.commentText = "draft"
        vm.cancel()
        XCTAssertEqual(vm.phase, .idle)
        XCTAssertEqual(vm.commentText, "")
    }

    // MARK: - send success

    func testSendSuccessTransitionsToSent() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "hello"
        await vm.send()

        XCTAssertEqual(vm.phase, .sent)
    }

    func testSendClearsTextAfterSuccess() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "done"
        await vm.send()
        XCTAssertEqual(vm.commentText, "")
    }

    func testSendDoesNothingWhenTextEmpty() async {
        let vm = makeVM()
        vm.open()
        vm.commentText = "   "
        await vm.send()
        // Should stay open/idle, not move to sending
        XCTAssertNotEqual(vm.phase, .sending)
    }

    // MARK: - send errors → error phase

    func testSendOn401TransitionsToError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "test"
        await vm.send()

        XCTAssertEqual(vm.phase, .error)
    }

    func testSendOnServerErrorTransitionsToError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "test"
        await vm.send()

        XCTAssertEqual(vm.phase, .error)
    }

    // MARK: - network down → queued phase

    func testSendOnNetworkErrorTransitionsToQueued() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "queued comment"
        await vm.send()

        XCTAssertEqual(vm.phase, .queued)
    }

    func testQueuedPreservesCommentText() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "will be queued"
        await vm.send()

        XCTAssertEqual(vm.commentText, "will be queued")
    }

    // MARK: - retry

    func testRetrySuccessTransitionsToSent() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "retry me"
        await vm.send()
        XCTAssertEqual(vm.phase, .queued)

        // Now restore connectivity
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        await vm.retry()
        XCTAssertEqual(vm.phase, .sent)
    }

    func testRetryFailureStaysInError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "fail"
        await vm.send()
        XCTAssertEqual(vm.phase, .error)

        await vm.retry()
        XCTAssertEqual(vm.phase, .error)
    }

    // MARK: - dismiss

    func testDismissSentResetsToIdle() {
        let vm = makeVM()
        vm.phase = .sent
        vm.dismiss()
        XCTAssertEqual(vm.phase, .idle)
    }

    func testDismissQueuedResetsToIdle() {
        let vm = makeVM()
        vm.phase = .queued
        vm.commentText = "queued"
        vm.dismiss()
        XCTAssertEqual(vm.phase, .idle)
        XCTAssertEqual(vm.commentText, "")
    }

    func testDismissErrorResetsToIdle() {
        let vm = makeVM()
        vm.phase = .error
        vm.dismiss()
        XCTAssertEqual(vm.phase, .idle)
    }

    // MARK: - workItemId

    func testVMUsesWorkItemIdFromInit() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let vm = makeVM(workItemId: "99")
        vm.open()
        vm.commentText = "hello"
        await vm.send()

        let url = try XCTUnwrap(capturedURL?.absoluteString)
        XCTAssertTrue(url.contains("/workitems/99/comments"))
    }
}
