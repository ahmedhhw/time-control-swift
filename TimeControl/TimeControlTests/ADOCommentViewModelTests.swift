//
//  ADOCommentViewModelTests.swift
//  TimeControlTests
//

import AppKit
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

    // MARK: - URL → hyperlink serialisation

    func testSendConvertsBareLinkToAnchor() async throws {
        var capturedCommentText: String?
        MockURLProtocol.requestHandler = { request in
            capturedCommentText = Self.readCommentText(from: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "See https://example.com for details"
        await vm.send()

        let text = try XCTUnwrap(capturedCommentText)
        XCTAssertTrue(text.contains("<a href=\"https://example.com\">https://example.com</a>"), "Expected URL wrapped in anchor tag, got: \(text)")
    }

    func testSendConvertsHttpLinkToAnchor() async throws {
        var capturedCommentText: String?
        MockURLProtocol.requestHandler = { request in
            capturedCommentText = Self.readCommentText(from: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "Visit http://example.com/path?q=1"
        await vm.send()

        let text = try XCTUnwrap(capturedCommentText)
        XCTAssertTrue(text.contains("<a href=\"http://example.com/path?q=1\">http://example.com/path?q=1</a>"), "Expected URL wrapped in anchor tag, got: \(text)")
    }

    func testSendPreservesTextAroundLink() async throws {
        var capturedCommentText: String?
        MockURLProtocol.requestHandler = { request in
            capturedCommentText = Self.readCommentText(from: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "See https://example.com for details"
        await vm.send()

        let text = try XCTUnwrap(capturedCommentText)
        XCTAssertTrue(text.contains("See"), "Expected surrounding text preserved, got: \(text)")
        XCTAssertTrue(text.contains("for details"), "Expected surrounding text preserved, got: \(text)")
    }

    func testSendDoesNotWrapPlainText() async throws {
        var capturedCommentText: String?
        MockURLProtocol.requestHandler = { request in
            capturedCommentText = Self.readCommentText(from: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "plain text no links"
        await vm.send()

        let text = try XCTUnwrap(capturedCommentText)
        XCTAssertFalse(text.contains("<a href"), "Expected no anchor tags for plain text, got: \(text)")
    }

    private static func readCommentText(from request: URLRequest) -> String? {
        let data: Data?
        if let stream = request.httpBodyStream {
            stream.open()
            var collected = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 1024)
                if read > 0 { collected.append(buffer, count: read) }
            }
            buffer.deallocate()
            stream.close()
            data = collected
        } else {
            data = request.httpBody
        }
        guard let data,
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
        return dict["text"]
    }

    // MARK: - Newline → <br> serialisation

    func testSendConvertsNewlineToBreakTag() async throws {
        var capturedCommentText: String?
        MockURLProtocol.requestHandler = { request in
            capturedCommentText = Self.readCommentText(from: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "line one\nline two"
        await vm.send()

        let text = try XCTUnwrap(capturedCommentText)
        XCTAssertTrue(text.contains("<br>"), "Expected \\n converted to <br>, got: \(text)")
        XCTAssertFalse(text.contains("\n"), "Expected no raw newlines in serialised output, got: \(text)")
    }

    func testSendConvertsMultipleNewlinesToBreakTags() async throws {
        var capturedCommentText: String?
        MockURLProtocol.requestHandler = { request in
            capturedCommentText = Self.readCommentText(from: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "a\nb\nc"
        await vm.send()

        let text = try XCTUnwrap(capturedCommentText)
        XCTAssertEqual(text.components(separatedBy: "<br>").count, 3, "Expected 2 <br> tags for 2 newlines, got: \(text)")
    }

    func testSendPreservesTextAroundNewlines() async throws {
        var capturedCommentText: String?
        MockURLProtocol.requestHandler = { request in
            capturedCommentText = Self.readCommentText(from: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "hello\nworld"
        await vm.send()

        let text = try XCTUnwrap(capturedCommentText)
        XCTAssertTrue(text.contains("hello"), "Expected 'hello' preserved, got: \(text)")
        XCTAssertTrue(text.contains("world"), "Expected 'world' preserved, got: \(text)")
    }

    // MARK: - Pasted images

    func testPasteImageAppendsToList() {
        let vm = makeVM()
        vm.pasteImage(Data([0x89, 0x50, 0x4E, 0x47]), filename: "pasted-image-1.png")
        XCTAssertEqual(vm.pastedImages.count, 1)
        XCTAssertEqual(vm.pastedImages[0].filename, "pasted-image-1.png")
        XCTAssertEqual(vm.pastedImages[0].uploadState, .pending)
    }

    func testRemoveImageDeletesEntry() {
        let vm = makeVM()
        vm.pasteImage(Data([0x01]), filename: "a.png")
        vm.pasteImage(Data([0x02]), filename: "b.png")
        XCTAssertEqual(vm.pastedImages.count, 2)

        let idToRemove = vm.pastedImages[0].id
        vm.removeImage(id: idToRemove)
        XCTAssertEqual(vm.pastedImages.count, 1)
        XCTAssertEqual(vm.pastedImages[0].filename, "b.png")
    }

    func testCancelClearsPastedImages() {
        let vm = makeVM()
        vm.open()
        vm.pasteImage(Data([0x01]), filename: "a.png")
        XCTAssertEqual(vm.pastedImages.count, 1)
        vm.cancel()
        XCTAssertTrue(vm.pastedImages.isEmpty)
    }

    func testSendUploadsImagesBeforePosting() async throws {
        var requestURLs: [String] = []
        MockURLProtocol.requestHandler = { request in
            requestURLs.append(request.url?.absoluteString ?? "")
            if request.url?.absoluteString.contains("attachments") == true {
                let json = #"{"url":"https://dev.azure.com/myorg/myproj/_apis/wit/attachments/abc"}"#.data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, json)
            } else {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, "{}".data(using: .utf8)!)
            }
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "see attached"
        vm.pasteImage(Data([0x89, 0x50, 0x4E, 0x47]), filename: "pasted-image-1.png")
        await vm.send()

        // Upload request must come before the postComment request
        let attachmentIndex = requestURLs.firstIndex(where: { $0.contains("attachments") })
        let commentsIndex = requestURLs.firstIndex(where: { $0.contains("/comments") })
        let ai = try XCTUnwrap(attachmentIndex, "Expected attachment upload request")
        let ci = try XCTUnwrap(commentsIndex, "Expected post comment request")
        XCTAssertLessThan(ai, ci, "Upload must happen before postComment")
    }

    func testSendAppendsImgTagsToComment() async throws {
        let attachmentURL = "https://dev.azure.com/myorg/myproj/_apis/wit/attachments/img1"
        var capturedCommentText: String?
        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString.contains("attachments") == true {
                let json = "{\"url\":\"\(attachmentURL)\"}".data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, json)
            } else {
                capturedCommentText = Self.readCommentText(from: request)
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, "{}".data(using: .utf8)!)
            }
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "look here"
        vm.pasteImage(Data([0x89, 0x50, 0x4E, 0x47]), filename: "pasted-image-1.png")
        await vm.send()

        let text = try XCTUnwrap(capturedCommentText)
        XCTAssertTrue(
            text.contains("<img src=\"\(attachmentURL)\""),
            "Expected img tag with upload URL, got: \(text)"
        )
    }

    func testSendSerialisesInlineImageBetweenTextSegments() async throws {
        let attachmentURL = "https://dev.azure.com/myorg/myproj/_apis/wit/attachments/mid"
        var capturedCommentText: String?
        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString.contains("attachments") == true {
                let json = "{\"url\":\"\(attachmentURL)\"}".data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, json)
            } else {
                capturedCommentText = Self.readCommentText(from: request)
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, "{}".data(using: .utf8)!)
            }
        }

        let vm = makeVM()
        vm.open()
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let id = vm.pasteImage(png, filename: "pasted-image-1.png")
        let before = NSAttributedString(string: "before ", attributes: ADOCommentViewModel.defaultTypingAttributes)
        let attach = NSAttributedString(attachment: InlineImageAttachment(imageData: png, pastedImageId: id))
        let after = NSAttributedString(string: " after", attributes: ADOCommentViewModel.defaultTypingAttributes)
        let body = NSMutableAttributedString(attributedString: before)
        body.append(attach)
        body.append(after)
        vm.commentBody = body

        await vm.send()

        let text = try XCTUnwrap(capturedCommentText)
        let beforeRange = text.range(of: "before")
        let imgRange = text.range(of: "<img ")
        let afterRange = text.range(of: " after")
        XCTAssertNotNil(beforeRange)
        XCTAssertNotNil(imgRange)
        XCTAssertNotNil(afterRange)
        XCTAssertLessThan(beforeRange!.upperBound, imgRange!.lowerBound)
        XCTAssertLessThan(imgRange!.upperBound, afterRange!.lowerBound)
    }

    func testSendClearsPastedImagesOnSuccess() async {
        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString.contains("attachments") == true {
                let json = #"{"url":"https://dev.azure.com/myorg/myproj/_apis/wit/attachments/abc"}"#.data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, json)
            } else {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, "{}".data(using: .utf8)!)
            }
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "with image"
        vm.pasteImage(Data([0x01]), filename: "pasted-image-1.png")
        await vm.send()

        XCTAssertTrue(vm.pastedImages.isEmpty, "Expected pastedImages cleared after successful send")
    }

    func testSendUploadsAndPostsImageOnlyComment() async throws {
        let attachmentURL = "https://dev.azure.com/myorg/myproj/_apis/wit/attachments/only"
        var capturedCommentText: String?
        var sawAttachmentUpload = false
        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString.contains("attachments") == true {
                sawAttachmentUpload = true
                let json = "{\"url\":\"\(attachmentURL)\"}".data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, json)
            } else {
                capturedCommentText = Self.readCommentText(from: request)
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, "{}".data(using: .utf8)!)
            }
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = ""
        vm.pasteImage(Data([0x89, 0x50, 0x4E, 0x47]), filename: "pasted-image-1.png")
        await vm.send()

        XCTAssertTrue(sawAttachmentUpload, "Expected image to be uploaded even with empty text")
        let text = try XCTUnwrap(capturedCommentText, "Expected postComment to be called for image-only send")
        XCTAssertTrue(text.contains("<img src=\"\(attachmentURL)\""), "Expected img tag in posted comment, got: \(text)")
        XCTAssertEqual(vm.phase, .sent)
    }

    func testSendMarksImageFailedOnUploadError() async {
        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString.contains("attachments") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            } else {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, "{}".data(using: .utf8)!)
            }
        }

        let vm = makeVM()
        vm.open()
        vm.commentText = "with broken image"
        vm.pasteImage(Data([0x01]), filename: "pasted-image-1.png")
        await vm.send()

        XCTAssertEqual(vm.pastedImages.count, 1, "Expected failed image to remain in list")
        XCTAssertEqual(vm.pastedImages[0].uploadState, .failed)
    }
}
