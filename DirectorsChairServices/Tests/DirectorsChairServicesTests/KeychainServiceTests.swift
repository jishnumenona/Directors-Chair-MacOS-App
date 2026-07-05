// DirectorsChairServices/Tests/DirectorsChairServicesTests/KeychainServiceTests.swift
//
// Unit tests for KeychainService (UserDefaults-backed token storage).

import XCTest
@testable import DirectorsChairServices
@testable import DirectorsChairCore

// MARK: - KeychainService Tests

final class KeychainServiceTests: XCTestCase {

    // MARK: - Properties

    /// Each test gets its own KeychainService backed by a unique UserDefaults suite,
    /// so tests are isolated under parallel execution and never touch the shared
    /// production suite (which holds the developer's real login).
    private var keychain: KeychainService!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        keychain = KeychainService(suiteName: "com.directorschair.auth.tests.\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        await keychain.removePersistentDomain()
        keychain = nil
        try await super.tearDown()
    }

    // MARK: - Save and Load String Tests

    func testSaveAndLoadString() async throws {
        let testValue = "my-secret-access-token-abc123"

        try await keychain.save(testValue, forKey: .accessToken)
        let loaded = try await keychain.load(key: .accessToken)

        XCTAssertEqual(loaded, testValue, "Loaded value should match saved value")
    }

    func testSaveAndLoadStringForAllKeys() async throws {
        // Test each well-known key
        let testValues: [(KeychainService.Key, String)] = [
            (.accessToken, "access-token-value"),
            (.refreshToken, "refresh-token-value"),
            (.tokenExpiry, "1711612800.0"),
            (.userInfo, "{\"id\":1,\"username\":\"test\"}"),
        ]

        for (key, value) in testValues {
            try await keychain.save(value, forKey: key)
        }

        for (key, expectedValue) in testValues {
            let loaded = try await keychain.load(key: key)
            XCTAssertEqual(loaded, expectedValue, "Value for key \(key.rawValue) should match")
        }
    }

    // MARK: - Save and Load Data Tests

    func testSaveAndLoadData() async throws {
        let testData = "binary-data-content".data(using: .utf8)!
        let key = "test.data.key"

        try await keychain.save(data: testData, forKey: key)
        let loaded = try await keychain.loadData(key: key)

        XCTAssertEqual(loaded, testData, "Loaded data should match saved data")
    }

    func testSaveAndLoadLargeData() async throws {
        // Create a moderately large Data payload (simulating a JSON user info blob)
        let largeString = String(repeating: "A", count: 10_000)
        let largeData = largeString.data(using: .utf8)!
        let key = "test.large.data"

        try await keychain.save(data: largeData, forKey: key)
        let loaded = try await keychain.loadData(key: key)

        XCTAssertEqual(loaded, largeData, "Large data should round-trip correctly")
        XCTAssertEqual(loaded?.count, 10_000, "Loaded data size should match")
    }

    // MARK: - Delete Tests

    func testDeleteRemovesEntry() async throws {
        try await keychain.save("token-to-delete", forKey: .accessToken)

        // Verify it exists
        let preDelete = try await keychain.load(key: .accessToken)
        XCTAssertNotNil(preDelete, "Token should exist before delete")

        // Delete it
        try await keychain.delete(key: .accessToken)

        // Verify it's gone
        let postDelete = try await keychain.load(key: .accessToken)
        XCTAssertNil(postDelete, "Token should be nil after delete")
    }

    func testDeleteAllRemovesAllEntries() async throws {
        // Save values for all keys
        try await keychain.save("access", forKey: .accessToken)
        try await keychain.save("refresh", forKey: .refreshToken)
        try await keychain.save("12345", forKey: .tokenExpiry)
        try await keychain.save("{}", forKey: .userInfo)

        // Delete all
        try await keychain.deleteAll()

        // Verify all are nil
        let access = try await keychain.load(key: .accessToken)
        let refresh = try await keychain.load(key: .refreshToken)
        let expiry = try await keychain.load(key: .tokenExpiry)
        let userInfo = try await keychain.load(key: .userInfo)

        XCTAssertNil(access, "Access token should be nil after deleteAll")
        XCTAssertNil(refresh, "Refresh token should be nil after deleteAll")
        XCTAssertNil(expiry, "Token expiry should be nil after deleteAll")
        XCTAssertNil(userInfo, "User info should be nil after deleteAll")
    }

    func testDeleteNonexistentKeyDoesNotThrow() async throws {
        // Deleting a key that doesn't exist should not throw
        try await keychain.delete(key: .accessToken)
        // No assertion needed — test passes if no exception is thrown
    }

    // MARK: - Overwrite Tests

    func testOverwriteExistingEntry() async throws {
        try await keychain.save("first-value", forKey: .accessToken)

        let firstLoad = try await keychain.load(key: .accessToken)
        XCTAssertEqual(firstLoad, "first-value")

        // Overwrite with a new value
        try await keychain.save("second-value", forKey: .accessToken)

        let secondLoad = try await keychain.load(key: .accessToken)
        XCTAssertEqual(secondLoad, "second-value", "Overwritten value should be the latest")
    }

    func testOverwriteMultipleTimes() async throws {
        for i in 0..<10 {
            try await keychain.save("value-\(i)", forKey: .refreshToken)
        }

        let finalValue = try await keychain.load(key: .refreshToken)
        XCTAssertEqual(finalValue, "value-9", "Last written value should persist")
    }

    // MARK: - Load Nonexistent Tests

    func testLoadNonexistentReturnsNil() async throws {
        let result = try await keychain.load(key: .accessToken)
        XCTAssertNil(result, "Loading a key that was never saved should return nil")
    }

    func testLoadDataNonexistentReturnsNil() async throws {
        let result = try await keychain.loadData(key: "nonexistent.data.key")
        XCTAssertNil(result, "Loading data for a key that was never saved should return nil")
    }

    // MARK: - Key Independence Tests

    func testDifferentKeysIndependent() async throws {
        try await keychain.save("access-value", forKey: .accessToken)
        try await keychain.save("refresh-value", forKey: .refreshToken)

        // Verify they are independent
        let access = try await keychain.load(key: .accessToken)
        let refresh = try await keychain.load(key: .refreshToken)

        XCTAssertEqual(access, "access-value")
        XCTAssertEqual(refresh, "refresh-value")
        XCTAssertNotEqual(access, refresh, "Different keys should hold different values")
    }

    func testDeleteOneKeyDoesNotAffectOthers() async throws {
        try await keychain.save("access-value", forKey: .accessToken)
        try await keychain.save("refresh-value", forKey: .refreshToken)

        // Delete only access token
        try await keychain.delete(key: .accessToken)

        let access = try await keychain.load(key: .accessToken)
        let refresh = try await keychain.load(key: .refreshToken)

        XCTAssertNil(access, "Deleted key should be nil")
        XCTAssertEqual(refresh, "refresh-value", "Other keys should be unaffected")
    }

    // MARK: - Edge Case Tests

    func testSaveEmptyString() async throws {
        try await keychain.save("", forKey: .accessToken)
        let loaded = try await keychain.load(key: .accessToken)

        // UserDefaults stores empty strings as empty strings (not nil)
        XCTAssertEqual(loaded, "", "Empty string should round-trip correctly")
    }

    func testSaveEmptyData() async throws {
        let emptyData = Data()
        let key = "test.empty.data"

        try await keychain.save(data: emptyData, forKey: key)
        let loaded = try await keychain.loadData(key: key)

        XCTAssertEqual(loaded, emptyData, "Empty data should round-trip correctly")
        XCTAssertEqual(loaded?.count, 0)
    }

    func testSpecialCharactersInValue() async throws {
        let specialValue = "tok3n/with+special=chars&more%20stuff!@#$^*()"
        try await keychain.save(specialValue, forKey: .accessToken)

        let loaded = try await keychain.load(key: .accessToken)
        XCTAssertEqual(loaded, specialValue, "Special characters in value should round-trip correctly")
    }

    func testUnicodeInValue() async throws {
        let unicodeValue = "token-\u{1F3AC}-\u{1F4F7}-directors-\u{2705}"
        try await keychain.save(unicodeValue, forKey: .accessToken)

        let loaded = try await keychain.load(key: .accessToken)
        XCTAssertEqual(loaded, unicodeValue, "Unicode characters should round-trip correctly")
    }

    func testVeryLongString() async throws {
        let longValue = String(repeating: "x", count: 50_000)
        try await keychain.save(longValue, forKey: .accessToken)

        let loaded = try await keychain.load(key: .accessToken)
        XCTAssertEqual(loaded, longValue, "Long strings should round-trip correctly")
        XCTAssertEqual(loaded?.count, 50_000)
    }

    func testJSONEncodedUserInfo() async throws {
        // Simulate storing encoded AuthenticatedUser JSON
        let user = AuthenticatedUser(
            id: 42,
            username: "director_jane",
            email: "jane@example.com",
            fullName: "Jane Director",
            avatarURL: "https://example.com/avatars/jane.png",
            isAdmin: false
        )

        let encoded = try JSONEncoder().encode(user)
        let jsonString = String(data: encoded, encoding: .utf8)!

        try await keychain.save(jsonString, forKey: .userInfo)

        let loaded = try await keychain.load(key: .userInfo)
        XCTAssertNotNil(loaded)

        let decoded = try JSONDecoder().decode(
            AuthenticatedUser.self,
            from: loaded!.data(using: .utf8)!
        )
        XCTAssertEqual(decoded.id, 42)
        XCTAssertEqual(decoded.username, "director_jane")
        XCTAssertEqual(decoded.email, "jane@example.com")
    }

    // MARK: - Key CaseIterable Tests

    func testKeyCaseIterableCoversAllKeys() {
        let allKeys = KeychainService.Key.allCases
        XCTAssertEqual(allKeys.count, 4, "Should have 4 well-known keys")
        XCTAssertTrue(allKeys.contains(.accessToken))
        XCTAssertTrue(allKeys.contains(.refreshToken))
        XCTAssertTrue(allKeys.contains(.tokenExpiry))
        XCTAssertTrue(allKeys.contains(.userInfo))
    }

    func testKeyRawValues() {
        XCTAssertEqual(KeychainService.Key.accessToken.rawValue, "access_token")
        XCTAssertEqual(KeychainService.Key.refreshToken.rawValue, "refresh_token")
        XCTAssertEqual(KeychainService.Key.tokenExpiry.rawValue, "token_expiry")
        XCTAssertEqual(KeychainService.Key.userInfo.rawValue, "user_info")
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentSavesAndLoads() async throws {
        // KeychainService is an actor, so concurrent access should be safe
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Multiple concurrent saves
            for i in 0..<20 {
                group.addTask {
                    try await self.keychain.save("value-\(i)", forKey: .accessToken)
                }
            }
            try await group.waitForAll()
        }

        // After all concurrent saves, the value should be one of the written values
        let finalValue = try await keychain.load(key: .accessToken)
        XCTAssertNotNil(finalValue, "Should have a value after concurrent saves")
        XCTAssertTrue(finalValue!.hasPrefix("value-"), "Value should be one of the written values")
    }

    func testConcurrentDeleteAndLoad() async throws {
        try await keychain.save("initial-value", forKey: .accessToken)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await self.keychain.delete(key: .accessToken)
            }
            group.addTask {
                _ = try? await self.keychain.load(key: .accessToken)
            }
        }

        // Should not crash — state is either deleted or not
    }

    // MARK: - KeychainError Tests

    func testKeychainErrorDescriptions() {
        let saveError = KeychainError.saveFailed(-25299)
        XCTAssertTrue(
            saveError.errorDescription!.contains("-25299"),
            "Save error should contain OSStatus code"
        )

        let loadError = KeychainError.loadFailed(-25300)
        XCTAssertTrue(
            loadError.errorDescription!.contains("-25300"),
            "Load error should contain OSStatus code"
        )

        let deleteError = KeychainError.deleteFailed(-25301)
        XCTAssertTrue(
            deleteError.errorDescription!.contains("-25301"),
            "Delete error should contain OSStatus code"
        )
    }

    func testKeychainErrorIsLocalizedError() {
        let error: any LocalizedError = KeychainError.saveFailed(0)
        XCTAssertNotNil(error.errorDescription, "KeychainError should provide an error description")
    }
}
