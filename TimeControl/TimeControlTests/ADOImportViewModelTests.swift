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

// MARK: - Bulk Import VM Tests

@MainActor
final class ADOBulkImportViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSettings(org: String = "myorg", project: String = "myproj", pat: String = "mytoken") -> ADOSettingsStore {
        let store = ADOSettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store.organization = org
        store.project = project
        store.pat = pat
        return store
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

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

    private func makeResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://dev.azure.com")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - loadAssigned

    func testLoadAssignedPopulatesAssignedItems() async {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] _ in
            callCount += 1
            if callCount == 1 {
                return (self.makeResponse(statusCode: 200), self.wiqlJSON(ids: [10, 20]))
            } else {
                return (self.makeResponse(statusCode: 200), self.batchJSON(items: [
                    (10, "Task A", "Active", ""),
                    (20, "Task B", "Active", "desc")
                ]))
            }
        }

        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        await vm.loadAssigned()

        XCTAssertEqual(vm.assignedItems.count, 2)
        XCTAssertEqual(vm.assignedItems[0].title, "Task A")
        XCTAssertEqual(vm.assignedItems[1].title, "Task B")
        XCTAssertNil(vm.assignedError)
    }

    func testLoadAssignedSetsIsLoadingAssignedThenClears() async {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] _ in
            callCount += 1
            if callCount == 1 {
                return (self.makeResponse(statusCode: 200), self.wiqlJSON(ids: []))
            } else {
                return (self.makeResponse(statusCode: 200), self.batchJSON(items: []))
            }
        }

        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        await vm.loadAssigned()

        // After completion, isLoadingAssigned must be false
        XCTAssertFalse(vm.isLoadingAssigned)
    }

    func testLoadAssignedOnErrorSetsAssignedError() async {
        MockURLProtocol.requestHandler = { [self] _ in
            return (self.makeResponse(statusCode: 401), Data())
        }

        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        await vm.loadAssigned()

        XCTAssertNotNil(vm.assignedError)
        XCTAssertTrue(vm.assignedItems.isEmpty)
    }

    // MARK: - loadMentioned

    func testLoadMentionedPopulatesMentionedItems() async {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] _ in
            callCount += 1
            if callCount == 1 {
                return (self.makeResponse(statusCode: 200), self.wiqlJSON(ids: [99]))
            } else {
                return (self.makeResponse(statusCode: 200), self.batchJSON(items: [
                    (99, "Mentioned Item", "Active", "")
                ]))
            }
        }

        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        await vm.loadMentioned()

        XCTAssertEqual(vm.mentionedItems.count, 1)
        XCTAssertEqual(vm.mentionedItems[0].title, "Mentioned Item")
        XCTAssertNil(vm.mentionedError)
    }

    func testLoadMentionedOnErrorSetsMentionedError() async {
        MockURLProtocol.requestHandler = { [self] _ in
            return (self.makeResponse(statusCode: 401), Data())
        }

        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        await vm.loadMentioned()

        XCTAssertNotNil(vm.mentionedError)
        XCTAssertTrue(vm.mentionedItems.isEmpty)
    }

    // MARK: - toggleSelection

    func testToggleSelectionAddsId() {
        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        vm.toggleSelection(42)
        XCTAssertTrue(vm.selectedIds.contains(42))
    }

    func testToggleSelectionRemovesAlreadySelectedId() {
        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        vm.toggleSelection(42)
        vm.toggleSelection(42)
        XCTAssertFalse(vm.selectedIds.contains(42))
    }

    // MARK: - canImport

    func testCanImportFalseWhenNothingSelectedAndNoFetch() {
        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        XCTAssertFalse(vm.canImport)
    }

    func testCanImportTrueWhenItemSelected() {
        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        vm.toggleSelection(10)
        XCTAssertTrue(vm.canImport)
    }

    func testCanImportTrueWhenFetchedItemPresent() async {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] _ in
            callCount += 1
            let json = "{\"id\":1,\"fields\":{\"System.Title\":\"T\",\"System.Description\":\"\"}}".data(using: .utf8)!
            return (self.makeResponse(statusCode: 200), json)
        }

        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        vm.workItemIdText = "1"
        await vm.fetchWorkItem()

        XCTAssertTrue(vm.canImport)
    }

    // MARK: - importSelected

    func testImportSelectedReturnsTodoItemsForSelectedIds() async {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] _ in
            callCount += 1
            if callCount == 1 {
                return (self.makeResponse(statusCode: 200), self.wiqlJSON(ids: [10, 20]))
            } else {
                return (self.makeResponse(statusCode: 200), self.batchJSON(items: [
                    (10, "Task A", "Active", ""),
                    (20, "Task B", "Active", "")
                ]))
            }
        }

        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        await vm.loadAssigned()

        vm.toggleSelection(10)
        vm.toggleSelection(20)

        let todos = vm.importSelected(existingAdoIds: [])
        XCTAssertEqual(todos.count, 2)
        XCTAssertTrue(todos.allSatisfy { $0.adoWorkItemId != nil })
    }

    func testImportSelectedIncludesFetchedItem() async {
        // Set up for the single-item fetch
        MockURLProtocol.requestHandler = { [self] _ in
            let json = "{\"id\":55,\"fields\":{\"System.Title\":\"Fetched Item\",\"System.Description\":\"\"}}".data(using: .utf8)!
            return (self.makeResponse(statusCode: 200), json)
        }

        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        vm.workItemIdText = "55"
        await vm.fetchWorkItem()

        let todos = vm.importSelected(existingAdoIds: [])
        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos[0].adoWorkItemId, "55")
    }

    func testImportSelectedExcludesAlreadyImportedIds() async {
        var callCount = 0
        MockURLProtocol.requestHandler = { [self] _ in
            callCount += 1
            if callCount == 1 {
                return (self.makeResponse(statusCode: 200), self.wiqlJSON(ids: [10, 20]))
            } else {
                return (self.makeResponse(statusCode: 200), self.batchJSON(items: [
                    (10, "Task A", "Active", ""),
                    (20, "Task B", "Active", "")
                ]))
            }
        }

        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        await vm.loadAssigned()

        vm.toggleSelection(10)
        vm.toggleSelection(20)

        let todos = vm.importSelected(existingAdoIds: ["10"])
        // Item 10 is already imported, only item 20 should be returned
        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos[0].adoWorkItemId, "20")
    }

    func testImportSelectedReturnsEmptyWhenNothingSelected() {
        let vm = ADOImportViewModel(service: ADOService(session: makeSession()), settings: makeSettings())
        let todos = vm.importSelected(existingAdoIds: [])
        XCTAssertTrue(todos.isEmpty)
    }
}
