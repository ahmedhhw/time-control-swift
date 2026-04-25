//
//  KeychainTests.swift
//  TimeControlTests
//

import XCTest
@testable import TimeControl

final class KeychainTests: XCTestCase {

    private let testKey = "test.ado.pat.\(UUID().uuidString)"

    override func tearDown() {
        try? Keychain.delete(testKey)
        super.tearDown()
    }

    func testSaveAndRead() throws {
        try Keychain.save(testKey, value: "my-secret-pat")
        let result = try Keychain.read(testKey)
        XCTAssertEqual(result, "my-secret-pat")
    }

    func testOverwriteExistingValue() throws {
        try Keychain.save(testKey, value: "first")
        try Keychain.save(testKey, value: "second")
        let result = try Keychain.read(testKey)
        XCTAssertEqual(result, "second")
    }

    func testReadMissingKeyThrows() {
        XCTAssertThrowsError(try Keychain.read("nonexistent.\(UUID().uuidString)"))
    }

    func testDeleteRemovesValue() throws {
        try Keychain.save(testKey, value: "to-delete")
        try Keychain.delete(testKey)
        XCTAssertThrowsError(try Keychain.read(testKey))
    }

    func testDeleteMissingKeyDoesNotThrow() {
        XCTAssertNoThrow(try Keychain.delete("nonexistent.\(UUID().uuidString)"))
    }
}
