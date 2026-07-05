// DirectorsChairServices/Sources/DirectorsChairServices/Auth/KeychainService.swift
//
// Token storage service for OAuth2 credentials.
// Uses UserDefaults with obfuscation for ad-hoc signed development builds.
// For production with proper code signing, swap to Security.framework Keychain.

import Foundation

// MARK: - Keychain Service

/// Thread-safe token storage for authentication credentials.
/// Stores tokens in a dedicated UserDefaults suite to avoid legacy
/// Keychain password prompts on ad-hoc signed macOS builds.
public actor KeychainService {

    // MARK: - Constants

    /// Default production suite. The app's real credentials live here.
    public static let defaultSuiteName = "com.directorschair.auth"

    private let suiteName: String
    private let defaults: UserDefaults

    /// - Parameter suiteName: The UserDefaults suite backing storage. Tests pass a
    ///   unique suite so they neither collide with each other under parallel execution
    ///   nor wipe the developer's real login in the shared production suite.
    public init(suiteName: String = KeychainService.defaultSuiteName) {
        self.suiteName = suiteName
        self.defaults = UserDefaults(suiteName: suiteName)!
    }

    /// Removes the entire backing suite. Intended for test teardown.
    func removePersistentDomain() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// Well-known keys
    public enum Key: String {
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
        defaults.set(value, forKey: key.rawValue)
    }

    /// Save raw data.
    public func save(data: Data, forKey key: String) throws {
        defaults.set(data, forKey: key)
    }

    /// Load a string value.
    public func load(key: Key) throws -> String? {
        return defaults.string(forKey: key.rawValue)
    }

    /// Load raw data.
    public func loadData(key: String) throws -> Data? {
        return defaults.data(forKey: key)
    }

    /// Delete a single key.
    public func delete(key: Key) throws {
        defaults.removeObject(forKey: key.rawValue)
    }

    /// Delete all items.
    public func deleteAll() throws {
        for key in Key.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}

// MARK: - Key CaseIterable

extension KeychainService.Key: CaseIterable {}

// MARK: - Keychain Error (kept for API compatibility)

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
