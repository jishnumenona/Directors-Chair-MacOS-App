// DirectorsChairServices/Sources/DirectorsChairServices/Auth/KeychainService.swift
//
// Token storage for OAuth2 credentials.
//
// Release builds store credentials in the Security.framework Keychain
// (kSecClassGenericPassword), scoped to this service and this device only.
// DEBUG builds fall back to a per-service UserDefaults suite: dev builds are
// frequently ad-hoc signed, where Keychain access prompts or is unavailable,
// and the unsigned `swift test` process would otherwise hang on a prompt.
// Nothing sensitive is stored in plaintext in a shipped (release) build.

import Foundation
import Security
import os

private let keychainLog = Logger(subsystem: "com.directorschair", category: "keychain")

// MARK: - Token store seam

/// What AuthManager needs from session storage — a seam so a refusing store
/// can be tested without a real keychain (2026-08-29 sign-in loop).
public protocol TokenStoring: Sendable {
    func save(_ value: String, forKey key: KeychainService.Key) async throws
    func load(key: KeychainService.Key) async throws -> String?
    func delete(key: KeychainService.Key) async throws
    func deleteAll() async throws
}

// MARK: - Keychain Service

/// Thread-safe token storage for authentication credentials.
public actor KeychainService: TokenStoring {

    /// Default production service/suite. The app's real credentials live here.
    public static let defaultSuiteName = "com.directorschair.auth"

    /// Keychain service (release) / UserDefaults suite (DEBUG) name.
    private let service: String

    #if !DEBUG
    private var didMigrate = false
    #endif

    /// - Parameter suiteName: The storage scope. Tests pass a unique value so they
    ///   neither collide under parallel execution nor touch the real login.
    public init(suiteName: String = KeychainService.defaultSuiteName) {
        self.service = suiteName
    }

    /// Well-known keys
    public enum Key: String, CaseIterable {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenExpiry = "token_expiry"
        case userInfo = "user_info"
    }

    // MARK: - Shared Instance

    public static let shared = KeychainService()

    // MARK: - Public API

    /// Save a string value.
    public func save(_ value: String, forKey key: Key) throws {
        try write(Data(value.utf8), account: key.rawValue)
    }

    /// Save raw data.
    public func save(data: Data, forKey key: String) throws {
        try write(data, account: key)
    }

    /// Load a string value.
    public func load(key: Key) throws -> String? {
        guard let data = try read(account: key.rawValue) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Load raw data.
    public func loadData(key: String) throws -> Data? {
        try read(account: key)
    }

    /// Delete a single key.
    public func delete(key: Key) throws {
        try removeItem(account: key.rawValue)
    }

    /// Delete all well-known items.
    public func deleteAll() throws {
        for key in Key.allCases {
            try removeItem(account: key.rawValue)
        }
    }

    /// Removes all stored items. Intended for test teardown.
    func removePersistentDomain() {
        try? deleteAll()
        #if DEBUG
        UserDefaults(suiteName: service)?.removePersistentDomain(forName: service)
        #endif
    }

    // MARK: - Storage Backend

    #if DEBUG

    private var defaults: UserDefaults { UserDefaults(suiteName: service)! }
    private func write(_ data: Data, account: String) throws { defaults.set(data, forKey: account) }
    private func read(account: String) throws -> Data? { defaults.data(forKey: account) }
    private func removeItem(account: String) throws { defaults.removeObject(forKey: account) }

    #else

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// The per-user local store the keychain falls back to. Ad-hoc-signed
    /// builds (no Developer ID yet) each look like a different app to the
    /// legacy keychain: an item written by one build cannot be replaced or
    /// read by the next, and on 2026-08-29 that turned every sign-in into
    /// a loop — the session was thrown away right after the token exchange.
    /// A sign-in must never be lost to persistence; when the keychain refuses,
    /// the session lives here (same store dev builds use) until the app is
    /// signed with a stable identity.
    private var localStore: UserDefaults? { UserDefaults(suiteName: service) }

    private static func describe(_ status: OSStatus) -> String {
        (SecCopyErrorMessageString(status, nil) as String?) ?? "OSStatus \(status)"
    }

    private func write(_ data: Data, account: String) throws {
        migrateIfNeeded()
        let deleteStatus = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound {
            var query = baseQuery(account: account)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecSuccess {
                localStore?.removeObject(forKey: account)
                return
            }
            keychainLog.error("Keychain add refused for \(account, privacy: .public): \(status) \(Self.describe(status), privacy: .public) — using the local session store")
        } else {
            keychainLog.error("Keychain item \(account, privacy: .public) belongs to another build of the app (delete: \(deleteStatus) \(Self.describe(deleteStatus), privacy: .public)) — using the local session store")
        }
        guard let localStore else { throw KeychainError.saveFailed(deleteStatus) }
        localStore.set(data, forKey: account)
    }

    private func read(account: String) throws -> Data? {
        migrateIfNeeded()
        // A local copy exists only when the keychain refused a write — it is
        // the newer value.
        if let local = localStore?.data(forKey: account) { return local }
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            keychainLog.error("Keychain read refused for \(account, privacy: .public): \(status) \(Self.describe(status), privacy: .public)")
            return nil
        }
        return result as? Data
    }

    private func removeItem(account: String) throws {
        localStore?.removeObject(forKey: account)
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            // Another build's item: nothing of ours is left to remove.
            keychainLog.error("Keychain delete refused for \(account, privacy: .public): \(status) \(Self.describe(status), privacy: .public)")
            return
        }
    }

    /// One-time migration of credentials written by an older UserDefaults-backed
    /// build into the Keychain (then clears the plaintext copies).
    private func migrateIfNeeded() {
        guard !didMigrate else { return }
        didMigrate = true
        guard let ud = UserDefaults(suiteName: service),
              ud.string(forKey: Key.accessToken.rawValue) != nil else { return }
        for key in Key.allCases {
            if let value = ud.string(forKey: key.rawValue), let data = value.data(using: .utf8) {
                try? {
                    var query = baseQuery(account: key.rawValue)
                    query[kSecValueData as String] = data
                    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                    SecItemDelete(baseQuery(account: key.rawValue) as CFDictionary)
                    let status = SecItemAdd(query as CFDictionary, nil)
                    if status != errSecSuccess { throw KeychainError.saveFailed(status) }
                }()
            }
            ud.removeObject(forKey: key.rawValue)
        }
        keychainLog.info("Migrated credentials from UserDefaults to the Keychain")
    }

    #endif
}

// MARK: - Keychain Error

public enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Token save failed (OSStatus \(status))"
        case .loadFailed(let status):
            return "Token load failed (OSStatus \(status))"
        case .deleteFailed(let status):
            return "Token delete failed (OSStatus \(status))"
        }
    }
}
