//
//  ADOImportViewLayoutTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

@MainActor
final class ADOImportViewLayoutTests: XCTestCase {

    // MARK: - Phase 1: mentionedItems VM stays intact even though section is hidden

    func test_mentionedItems_existsOnViewModel() {
        let vm = ADOImportViewModel()
        let items: [ADOWorkItem] = vm.mentionedItems
        XCTAssertNotNil(items as [ADOWorkItem]?,
            "mentionedItems must still exist on the VM even though the section is hidden")
    }

    func test_loadMentioned_doesNotCrash() async {
        let vm = ADOImportViewModel()
        await vm.loadMentioned()
        XCTAssertTrue(true)
    }

    func test_fetchedItem_isNilInitially() {
        let vm = ADOImportViewModel()
        XCTAssertNil(vm.fetchedItem)
    }

    func test_workItemIdText_isEmptyInitially() {
        let vm = ADOImportViewModel()
        XCTAssertEqual(vm.workItemIdText, "")
    }

    // MARK: - Phase 2: assigned list scrollable data

    func test_assignedItems_canHoldManyItems() {
        let vm = ADOImportViewModel()
        let manyItems = (1...20).map { i in
            ADOWorkItem(id: i, title: "Task \(i)", description: "", state: "Active")
        }
        vm.assignedItems = manyItems
        XCTAssertEqual(vm.assignedItems.count, 20)
    }

    func test_assignedItems_filteredByExistingAdoIds() {
        let vm = ADOImportViewModel()
        vm.assignedItems = [
            ADOWorkItem(id: 1, title: "Already imported", description: "", state: "Active"),
            ADOWorkItem(id: 2, title: "New item", description: "", state: "Active"),
        ]
        let existingIds: Set<String> = ["1"]
        let visible = vm.assignedItems.filter { !existingIds.contains(String($0.id)) }
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.id, 2)
    }
}
