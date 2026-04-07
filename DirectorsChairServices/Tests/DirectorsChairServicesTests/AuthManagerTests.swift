// DirectorsChairServices/Tests/DirectorsChairServicesTests/AuthManagerTests.swift
//
// Unit tests for the OAuth2 PKCE AuthManager state machine.

import XCTest
@testable import DirectorsChairServices
@testable import DirectorsChairCore

// MARK: - AuthManager Tests

@MainActor
final class AuthManagerTests: XCTestCase {

    // MARK: - Properties

    private var authManager: AuthManager!
    private var testConfig: AuthConfiguration!

    // Use a dedicated UserDefaults suite for tests so we don't pollute real data
    private let testKeychainSuite = "com.directorschair.auth.test"

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()

        testConfig = AuthConfiguration(
            giteaBaseURL: "https://test.example.com",
            clientID: "test-client-id-12345",
            redirectURI: "directorschair://oauth/callback",
            localCallbackPort: 19999
        )

        authManager = AuthManager(configuration: testConfig)

        // Clean up any leftover keychain state from previous test runs
        let keychain = KeychainService.shared
        try await keychain.deleteAll()
    }

    override func tearDown() async throws {
        // Clean up keychain state after tests
        let keychain = KeychainService.shared
        try await keychain.deleteAll()

        authManager = nil
        testConfig = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsLoggedOut() {
        XCTAssertFalse(authManager.isAuthenticated, "Fresh AuthManager should not be authenticated")
        XCTAssertNil(authManager.currentUser, "Fresh AuthManager should have no current user")
        XCTAssertFalse(authManager.isLoading, "Fresh AuthManager should not be loading")
        XCTAssertNil(authManager.errorMessage, "Fresh AuthManager should have no error message")
    }

    func testInitialAuthorizationHeaderIsNil() {
        XCTAssertNil(authManager.authorizationHeader, "Authorization header should be nil when not authenticated")
    }

    func testInitialAccessTokenIsNil() {
        XCTAssertNil(authManager.currentAccessToken, "Access token should be nil when not authenticated")
    }

    // MARK: - Configuration Tests

    func testCustomConfigurationIsStored() {
        XCTAssertEqual(authManager.configuration.giteaBaseURL, "https://test.example.com")
        XCTAssertEqual(authManager.configuration.clientID, "test-client-id-12345")
        XCTAssertEqual(authManager.configuration.redirectURI, "directorschair://oauth/callback")
        XCTAssertEqual(authManager.configuration.localCallbackPort, 19999)
    }

    func testDefaultConfiguration() {
        let defaultConfig = AuthConfiguration.default
        XCTAssertEqual(defaultConfig.giteaBaseURL, "https://git.directorschair.app")
        XCTAssertFalse(defaultConfig.clientID.isEmpty, "Default clientID should not be empty")
        XCTAssertEqual(defaultConfig.redirectURI, "directorschair://oauth/callback")
        XCTAssertEqual(defaultConfig.localCallbackPort, 19274)
    }

    func testAuthManagerUsesDefaultConfiguration() {
        let defaultManager = AuthManager()
        XCTAssertEqual(defaultManager.configuration.giteaBaseURL, AuthConfiguration.default.giteaBaseURL)
        XCTAssertEqual(defaultManager.configuration.clientID, AuthConfiguration.default.clientID)
    }

    // MARK: - Login URL Generation Tests

    func testLoginWithEmptyClientIDThrowsNotConfigured() async {
        let emptyConfig = AuthConfiguration(
            giteaBaseURL: "https://test.example.com",
            clientID: "",
            redirectURI: "directorschair://oauth/callback",
            localCallbackPort: 19999
        )
        let emptyManager = AuthManager(configuration: emptyConfig)

        do {
            try await emptyManager.login()
            XCTFail("Login with empty clientID should throw AuthError.notConfigured")
        } catch let error as AuthError {
            switch error {
            case .notConfigured:
                // Expected
                break
            default:
                XCTFail("Expected AuthError.notConfigured, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - Token Refresh Tests

    func testRefreshTokenIfNeededNoExpiryDoesNothing() async throws {
        // With no token expiry set (fresh manager), this should be a no-op
        try await authManager.refreshTokenIfNeeded()
        XCTAssertFalse(authManager.isAuthenticated, "Should remain unauthenticated")
    }

    func testForceRefreshWithNoRefreshTokenThrows() async {
        // Force refresh when there's no refresh token stored should throw
        do {
            try await authManager.forceRefreshToken()
            XCTFail("Force refresh with no refresh token should throw")
        } catch let error as AuthError {
            switch error {
            case .noRefreshToken:
                // Expected
                break
            default:
                XCTFail("Expected AuthError.noRefreshToken, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - Logout Tests

    func testLogoutClearsState() async {
        // Manually set some state to simulate a logged-in session
        // Since accessToken/refreshToken are private, we verify via public API
        await authManager.logout()

        XCTAssertFalse(authManager.isAuthenticated, "Should not be authenticated after logout")
        XCTAssertNil(authManager.currentUser, "Current user should be nil after logout")
        XCTAssertNil(authManager.authorizationHeader, "Authorization header should be nil after logout")
        XCTAssertNil(authManager.currentAccessToken, "Access token should be nil after logout")
        XCTAssertNil(authManager.errorMessage, "Error message should be nil after logout")
    }

    func testLogoutClearsKeychain() async throws {
        let keychain = KeychainService.shared

        // Pre-populate keychain with test tokens
        try await keychain.save("test-access-token", forKey: .accessToken)
        try await keychain.save("test-refresh-token", forKey: .refreshToken)
        try await keychain.save("1234567890", forKey: .tokenExpiry)

        // Verify they were stored
        let preLogoutToken = try await keychain.load(key: .accessToken)
        XCTAssertNotNil(preLogoutToken, "Access token should exist before logout")

        // Logout
        await authManager.logout()

        // Verify keychain was cleared
        let postLogoutAccess = try await keychain.load(key: .accessToken)
        let postLogoutRefresh = try await keychain.load(key: .refreshToken)
        let postLogoutExpiry = try await keychain.load(key: .tokenExpiry)

        XCTAssertNil(postLogoutAccess, "Access token should be cleared from keychain after logout")
        XCTAssertNil(postLogoutRefresh, "Refresh token should be cleared from keychain after logout")
        XCTAssertNil(postLogoutExpiry, "Token expiry should be cleared from keychain after logout")
    }

    func testLogoutIsIdempotent() async {
        // Multiple logouts should not crash or cause issues
        await authManager.logout()
        await authManager.logout()
        await authManager.logout()

        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.currentUser)
    }

    // MARK: - Offline Mode Tests

    func testOfflineModeAvailable() async {
        // "Continue Offline" mode: the app should work without authentication
        // A fresh AuthManager with no credentials should allow this
        XCTAssertFalse(authManager.isAuthenticated, "Should not be authenticated in offline mode")
        XCTAssertNil(authManager.currentUser, "No user in offline mode")
        // The app checks isAuthenticated — false means offline mode is available
    }

    // MARK: - Session Restoration Tests

    func testRestoreSessionWithNoStoredTokens() async {
        // With a clean keychain, restoreSession should leave us logged out
        await authManager.restoreSession()

        XCTAssertFalse(authManager.isAuthenticated, "Should not be authenticated with no stored tokens")
        XCTAssertFalse(authManager.isLoading, "Should not be loading after restore completes")
    }

    func testRestoreSessionWithInvalidTokenClearsState() async throws {
        // Store an invalid token — the fetchUserInfo call will fail,
        // causing restoreSession to clear everything
        let keychain = KeychainService.shared
        try await keychain.save("invalid-token-that-will-fail", forKey: .accessToken)

        await authManager.restoreSession()

        // After failed restore, everything should be cleared
        XCTAssertFalse(authManager.isAuthenticated, "Should not be authenticated after failed restore")
        XCTAssertFalse(authManager.isLoading, "Should not be loading after restore completes")

        // Keychain should also be cleared
        let storedToken = try await keychain.load(key: .accessToken)
        XCTAssertNil(storedToken, "Invalid token should be cleared from keychain after failed restore")
    }

    // MARK: - Auth State Publisher Tests (Combine)

    func testAuthStatePublisherEmitsChanges() async {
        // AuthManager uses @Published properties which provide Combine publishers
        var stateChanges: [Bool] = []

        // Subscribe to isAuthenticated changes
        let cancellable = authManager.$isAuthenticated
            .sink { isAuth in
                stateChanges.append(isAuth)
            }

        // Initial value should have been received
        XCTAssertFalse(stateChanges.isEmpty, "Should receive initial published value")
        XCTAssertFalse(stateChanges.last ?? true, "Initial state should be false")

        // Trigger a logout (should keep it false)
        await authManager.logout()

        cancellable.cancel()
    }

    func testCurrentUserPublisherEmitsChanges() {
        var userChanges: [AuthenticatedUser?] = []

        let cancellable = authManager.$currentUser
            .sink { user in
                userChanges.append(user)
            }

        // Initial value
        XCTAssertFalse(userChanges.isEmpty, "Should receive initial published value")
        XCTAssertNil(userChanges.last ?? AuthenticatedUser(id: 0, username: "", email: "", fullName: "", avatarURL: "", isAdmin: false),
                     "Initial user should be nil")

        cancellable.cancel()
    }

    // MARK: - Concurrent Access Safety Tests

    func testConcurrentAccessSafety() async {
        // AuthManager is @MainActor, which provides serialization of access.
        // Test that multiple rapid operations don't crash.
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    _ = self.authManager.isAuthenticated
                    _ = self.authManager.currentUser
                    _ = self.authManager.authorizationHeader
                    _ = self.authManager.currentAccessToken
                }
            }

            // Also interleave logouts
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    await self.authManager.logout()
                }
            }
        }

        // If we get here without crashing, concurrency is safe
        XCTAssertFalse(authManager.isAuthenticated)
    }

    func testConcurrentRestoreAndLogout() async {
        // Rapid restore + logout should not corrupt state
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await self.authManager.restoreSession()
            }
            group.addTask { @MainActor in
                await self.authManager.logout()
            }
        }

        // State should be consistent after both complete
        // (either logged out or restored — both are valid)
        XCTAssertFalse(authManager.isLoading, "Should not be stuck in loading state")
    }

    // MARK: - AuthError Tests

    func testAuthErrorDescriptions() {
        let errors: [(AuthError, String)] = [
            (.notConfigured, "not configured"),
            (.pkceGenerationFailed, "PKCE"),
            (.authorizationFailed("test"), "test"),
            (.tokenExchangeFailed("exchange error"), "exchange error"),
            (.tokenRefreshFailed("refresh error"), "refresh error"),
            (.userInfoFailed("user error"), "user error"),
            (.keychainError("keychain problem"), "keychain problem"),
            (.noRefreshToken, "sign out"),
            (.sessionExpired, "expired"),
        ]

        for (error, expectedSubstring) in errors {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(
                description.localizedCaseInsensitiveContains(expectedSubstring),
                "AuthError.\(error) description '\(description)' should contain '\(expectedSubstring)'"
            )
        }
    }

    // MARK: - AuthenticatedUser Tests

    func testAuthenticatedUserCodable() throws {
        let user = AuthenticatedUser(
            id: 42,
            username: "testuser",
            email: "test@example.com",
            fullName: "Test User",
            avatarURL: "https://example.com/avatar.png",
            isAdmin: false
        )

        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(AuthenticatedUser.self, from: data)

        XCTAssertEqual(decoded.id, 42)
        XCTAssertEqual(decoded.username, "testuser")
        XCTAssertEqual(decoded.email, "test@example.com")
        XCTAssertEqual(decoded.fullName, "Test User")
        XCTAssertEqual(decoded.avatarURL, "https://example.com/avatar.png")
        XCTAssertFalse(decoded.isAdmin)
    }

    func testAuthenticatedUserAdminFlag() {
        let adminUser = AuthenticatedUser(
            id: 1,
            username: "admin",
            email: "admin@example.com",
            fullName: "Admin",
            avatarURL: "",
            isAdmin: true
        )
        XCTAssertTrue(adminUser.isAdmin)

        let regularUser = AuthenticatedUser(
            id: 2,
            username: "user",
            email: "user@example.com",
            fullName: "User",
            avatarURL: "",
            isAdmin: false
        )
        XCTAssertFalse(regularUser.isAdmin)
    }

    // MARK: - AuthConfiguration Tests

    func testAuthConfigurationCustomInit() {
        let config = AuthConfiguration(
            giteaBaseURL: "https://custom.server.com",
            clientID: "custom-id",
            redirectURI: "myapp://callback",
            localCallbackPort: 8080
        )

        XCTAssertEqual(config.giteaBaseURL, "https://custom.server.com")
        XCTAssertEqual(config.clientID, "custom-id")
        XCTAssertEqual(config.redirectURI, "myapp://callback")
        XCTAssertEqual(config.localCallbackPort, 8080)
    }

    // MARK: - Handle Callback Tests

    func testHandleCallbackWithNoCodeThrows() async {
        let callbackURL = URL(string: "directorschair://oauth/callback?state=abc123")!

        do {
            try await authManager.handleCallback(url: callbackURL)
            XCTFail("handleCallback with no code should throw")
        } catch let error as AuthError {
            switch error {
            case .authorizationFailed:
                // Expected — no authorization code in callback
                break
            default:
                XCTFail("Expected AuthError.authorizationFailed, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthError, got \(type(of: error)): \(error)")
        }
    }

    func testHandleCallbackWithCodeButNoVerifierThrows() async {
        // Provide a code but since no login() was started, there's no code verifier
        let callbackURL = URL(string: "directorschair://oauth/callback?code=test-code&state=abc123")!

        do {
            try await authManager.handleCallback(url: callbackURL)
            XCTFail("handleCallback without prior login should throw (no code verifier)")
        } catch {
            // Expected — either PKCE or token exchange failure
            // since the code verifier is nil
        }
    }
}
