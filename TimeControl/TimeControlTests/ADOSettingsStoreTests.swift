//
//  ADOSettingsStoreTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class ADOSettingsStoreTests: XCTestCase {

    var store: ADOSettingsStore!

    override func setUp() {
        super.setUp()
        // Isolated UserDefaults suite per test run
        let suite = UUID().uuidString
        store = ADOSettingsStore(defaults: UserDefaults(suiteName: suite)!)
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    func testDefaultsAreEmpty() {
        XCTAssertEqual(store.organization, "")
        XCTAssertEqual(store.project, "")
    }

    func testSaveAndLoadOrganization() {
        store.organization = "contoso"
        XCTAssertEqual(store.organization, "contoso")
    }

    func testSaveAndLoadProject() {
        store.project = "my-project"
        XCTAssertEqual(store.project, "my-project")
    }

    func testValuesPersistedAcrossInstances() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let store1 = ADOSettingsStore(defaults: defaults)
        store1.organization = "acme"
        store1.project = "rocket"

        let store2 = ADOSettingsStore(defaults: defaults)
        XCTAssertEqual(store2.organization, "acme")
        XCTAssertEqual(store2.project, "rocket")
    }
}
