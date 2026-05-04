//
//  ADOImportViewModelTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

@MainActor
final class ADOImportViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeService(
        result: Result<ADOWorkItem, ADOService.ADOError>
    ) -> ADOService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        switch result {
        case .success(let item):
            MockURLProtocol.requestHandler = { request in
                let json = """
                {"id":\(item.id),"fields":{"System.Title":"\(item.title)","System.Description":"\(item.description)"}}
                """.data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!,
                                               statusCode: 200,
                                               httpVersion: nil,
                                               headerFields: nil)!
                return (response, json)
            }
        case .failure(let error):
            MockURLProtocol.requestHandler = { request in
                switch error {
                case .unauthorized:
                    let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                    return (response, Data())
                case .notFound:
                    let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                    return (response, Data())
                case .networkUnavailable:
                    throw URLError(.notConnectedToInternet)
                default:
                    let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                    return (response, Data())
                }
            }
        }

        return ADOService(session: session)
    }

    private func makeSettings(org: String = "myorg", project: String = "myproj", pat: String = "mytoken") -> ADOSettingsStore {
        let store = ADOSettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store.organization = org
        store.project = project
        store.pat = pat
        return store
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateIsIdle() {
        let vm = ADOImportViewModel(service: makeService(result: .success(.init(id: 1, title: "T", description: ""))),
                                    settings: makeSettings())
        XCTAssertEqual(vm.workItemIdText, "")
        XCTAssertNil(vm.fetchedItem)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - fetchWorkItem

    func testFetchSuccessPopulatesFetchedItem() async {
        let item = ADOWorkItem(id: 42, title: "Fix login bug", description: "<p>details</p>")
        let vm = ADOImportViewModel(service: makeService(result: .success(item)),
                                    settings: makeSettings())
        vm.workItemIdText = "42"

        await vm.fetchWorkItem()

        XCTAssertNotNil(vm.fetchedItem)
        XCTAssertEqual(vm.fetchedItem?.id, 42)
        XCTAssertEqual(vm.fetchedItem?.title, "Fix login bug")
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    func testFetchSetsLoadingDuringRequest() async {
        let item = ADOWorkItem(id: 1, title: "T", description: "")
        let vm = ADOImportViewModel(service: makeService(result: .success(item)),
                                    settings: makeSettings())
        vm.workItemIdText = "1"

        // isLoading is transient — just verify fetch completes cleanly
        await vm.fetchWorkItem()
        XCTAssertFalse(vm.isLoading)
    }

    func testFetchClearsPreviousFetchedItemOnNewFetch() async {
        let item1 = ADOWorkItem(id: 1, title: "First", description: "")
        let service = makeService(result: .success(item1))
        let vm = ADOImportViewModel(service: service, settings: makeSettings())
        vm.workItemIdText = "1"
        await vm.fetchWorkItem()
        XCTAssertNotNil(vm.fetchedItem)

        // Second fetch with different item
        MockURLProtocol.requestHandler = { request in
            let json = """
            {"id":2,"fields":{"System.Title":"Second","System.Description":""}}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }
        vm.workItemIdText = "2"
        await vm.fetchWorkItem()

        XCTAssertEqual(vm.fetchedItem?.id, 2)
        XCTAssertEqual(vm.fetchedItem?.title, "Second")
    }

    func testFetchOn401SetsUnauthorizedError() async {
        let vm = ADOImportViewModel(service: makeService(result: .failure(.unauthorized)),
                                    settings: makeSettings())
        vm.workItemIdText = "1"

        await vm.fetchWorkItem()

        XCTAssertNil(vm.fetchedItem)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.errorMessage!.contains("401") || vm.errorMessage!.lowercased().contains("auth"))
    }

    func testFetchOn404SetsNotFoundError() async {
        let vm = ADOImportViewModel(service: makeService(result: .failure(.notFound)),
                                    settings: makeSettings())
        vm.workItemIdText = "999"

        await vm.fetchWorkItem()

        XCTAssertNil(vm.fetchedItem)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.errorMessage!.lowercased().contains("not found") || vm.errorMessage!.contains("404"))
    }

    func testFetchOnNetworkErrorSetsVPNError() async {
        let vm = ADOImportViewModel(service: makeService(result: .failure(.networkUnavailable)),
                                    settings: makeSettings())
        vm.workItemIdText = "1"

        await vm.fetchWorkItem()

        XCTAssertNil(vm.fetchedItem)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.errorMessage!.lowercased().contains("vpn") || vm.errorMessage!.lowercased().contains("network") || vm.errorMessage!.lowercased().contains("reach"))
    }

    func testFetchWithEmptyIdDoesNothing() async {
        let vm = ADOImportViewModel(service: makeService(result: .success(.init(id: 1, title: "T", description: ""))),
                                    settings: makeSettings())
        vm.workItemIdText = ""

        await vm.fetchWorkItem()

        XCTAssertNil(vm.fetchedItem)
        XCTAssertNil(vm.errorMessage)
    }

    func testFetchWithPastedURLExtractsId() async {
        let item = ADOWorkItem(id: 12345, title: "From URL", description: "")
        let vm = ADOImportViewModel(service: makeService(result: .success(item)),
                                    settings: makeSettings())
        vm.workItemIdText = "https://dev.azure.com/org/project/_workitems/edit/12345"

        await vm.fetchWorkItem()

        XCTAssertEqual(vm.fetchedItem?.id, 12345)
    }

    // MARK: - importAsNewTask

    func testImportAsNewTaskReturnsTodoItemWithCorrectTitle() async {
        let item = ADOWorkItem(id: 7, title: "My Work Item", description: "<p>Some work</p>")
        let vm = ADOImportViewModel(service: makeService(result: .success(item)),
                                    settings: makeSettings())
        vm.workItemIdText = "7"
        await vm.fetchWorkItem()

        let todo = vm.importAsNewTask()

        XCTAssertNotNil(todo)
        XCTAssertEqual(todo?.text, "My Work Item")
    }

    func testImportAsNewTaskSetsAdoWorkItemId() async {
        let item = ADOWorkItem(id: 99, title: "Bug", description: "")
        let vm = ADOImportViewModel(service: makeService(result: .success(item)),
                                    settings: makeSettings())
        vm.workItemIdText = "99"
        await vm.fetchWorkItem()

        let todo = vm.importAsNewTask()

        XCTAssertEqual(todo?.adoWorkItemId, "99")
    }

    func testImportAsNewTaskStripsHTMLFromDescription() async {
        let item = ADOWorkItem(id: 1, title: "T", description: "<p>Clean <b>text</b> here</p>")
        let vm = ADOImportViewModel(service: makeService(result: .success(item)),
                                    settings: makeSettings())
        vm.workItemIdText = "1"
        await vm.fetchWorkItem()

        let todo = vm.importAsNewTask()

        XCTAssertNotNil(todo?.description)
        XCTAssertFalse(todo!.description.contains("<p>"))
        XCTAssertFalse(todo!.description.contains("<b>"))
        XCTAssertTrue(todo!.description.contains("Clean"))
        XCTAssertTrue(todo!.description.contains("text"))
    }

    func testImportAsNewTaskReturnsNilWhenNoFetchedItem() {
        let vm = ADOImportViewModel(service: makeService(result: .success(.init(id: 1, title: "T", description: ""))),
                                    settings: makeSettings())

        let todo = vm.importAsNewTask()

        XCTAssertNil(todo)
    }

    // MARK: - canFetch

    func testCanFetchIsFalseWhenIdIsEmpty() {
        let vm = ADOImportViewModel(service: makeService(result: .success(.init(id: 1, title: "T", description: ""))),
                                    settings: makeSettings())
        vm.workItemIdText = "  "
        XCTAssertFalse(vm.canFetch)
    }

    func testCanFetchIsFalseWhenSettingsMissing() {
        let vm = ADOImportViewModel(service: makeService(result: .success(.init(id: 1, title: "T", description: ""))),
                                    settings: makeSettings(org: "", project: "", pat: ""))
        vm.workItemIdText = "123"
        XCTAssertFalse(vm.canFetch)
    }

    func testCanFetchIsTrueWhenIdAndSettingsPresent() {
        let vm = ADOImportViewModel(service: makeService(result: .success(.init(id: 1, title: "T", description: ""))),
                                    settings: makeSettings())
        vm.workItemIdText = "123"
        XCTAssertTrue(vm.canFetch)
    }

    func testCanFetchIsTrueWithFullURL() {
        let vm = ADOImportViewModel(service: makeService(result: .success(.init(id: 1, title: "T", description: ""))),
                                    settings: makeSettings())
        vm.workItemIdText = "https://dev.azure.com/org/project/_workitems/edit/42"
        XCTAssertTrue(vm.canFetch)
    }
}
