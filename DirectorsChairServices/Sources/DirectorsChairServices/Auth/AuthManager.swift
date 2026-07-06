// DirectorsChairServices/Sources/DirectorsChairServices/Auth/AuthManager.swift
//
// OAuth2 PKCE Authentication Manager for DirectorsChair

import Foundation
import AuthenticationServices
import CryptoKit
import os
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Auth Configuration

/// Configuration for Gitea OAuth2 authentication.
public struct AuthConfiguration {
    public let giteaBaseURL: String
    public let clientID: String
    public let redirectURI: String
    public let localCallbackPort: Int

    public static let `default` = AuthConfiguration(
        giteaBaseURL: ServiceEnvironment.giteaBaseURLString,
        clientID: "c2091ed1-1094-4089-81ed-90a59ed4d307",
        redirectURI: "directorschair://oauth/callback",
        localCallbackPort: 19274
    )

    public init(giteaBaseURL: String, clientID: String, redirectURI: String, localCallbackPort: Int) {
        self.giteaBaseURL = giteaBaseURL
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.localCallbackPort = localCallbackPort
    }
}

// MARK: - Authenticated User

/// Represents the logged-in user.
public struct AuthenticatedUser: Codable, Sendable {
    public let id: Int
    public let username: String
    public let email: String
    public let fullName: String
    public let avatarURL: String
    public let isAdmin: Bool

    public init(id: Int, username: String, email: String, fullName: String, avatarURL: String, isAdmin: Bool) {
        self.id = id
        self.username = username
        self.email = email
        self.fullName = fullName
        self.avatarURL = avatarURL
        self.isAdmin = isAdmin
    }
}

// MARK: - Auth Error

public enum AuthError: LocalizedError {
    case notConfigured
    case pkceGenerationFailed
    case authorizationFailed(String)
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case userInfoFailed(String)
    case keychainError(String)
    case noRefreshToken
    case sessionExpired

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Authentication is not configured. Set NATIVE_OAUTH2_CLIENT_ID."
        case .pkceGenerationFailed: return "Failed to generate PKCE challenge."
        case .authorizationFailed(let msg): return "Authorization failed: \(msg)"
        case .tokenExchangeFailed(let msg): return "Token exchange failed: \(msg)"
        case .tokenRefreshFailed(let msg): return "Token refresh failed: \(msg)"
        case .userInfoFailed(let msg): return "Failed to fetch user info: \(msg)"
        case .keychainError(let msg): return "Keychain error: \(msg)"
        case .noRefreshToken: return "Your session could not be renewed. Please sign out and sign back in from the account menu."
        case .sessionExpired: return "Your session has expired. Please sign out and sign back in from the account menu."
        }
    }
}

// MARK: - Token Response

private struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int?
    let refresh_token: String?
    let scope: String?
}

// MARK: - Auth Debug Logger

private let authLogger = Logger(subsystem: "com.directorschair", category: "auth")

/// Auth-flow logging via os.Logger at .debug level. Never writes to a file:
/// OAuth callback URLs contain authorization codes and must not be persisted to
/// a world-readable /tmp log. .debug messages are not persisted in release.
private func authLog(_ message: String) {
    authLogger.debug("\(message, privacy: .public)")
}

// MARK: - Auth Manager

/// Manages OAuth2 PKCE authentication with Gitea.
///
/// Handles login, token refresh, logout, and Keychain persistence.
/// Inject as `@EnvironmentObject` from the app entry point.
@MainActor
public class AuthManager: ObservableObject {

    // MARK: - Published State

    @Published public var isAuthenticated = false
    @Published public var currentUser: AuthenticatedUser?
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    // MARK: - Configuration

    public var configuration: AuthConfiguration

    // MARK: - Private State

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?
    private var codeVerifier: String?
    /// Expected OAuth `state` for the in-flight login, checked on callback to
    /// prevent CSRF. Set when login() starts, cleared once consumed.
    private var oauthState: String?
    /// The single in-flight token refresh, so concurrent 401s share one refresh
    /// instead of each POSTing (which would invalidate the rotated token).
    private var inFlightRefresh: Task<Void, Error>?

    private let keychain: KeychainService
    private let session = URLSession.shared
    private var authSession: ASWebAuthenticationSession?
    #if canImport(AppKit)
    private let contextProvider = AuthPresentationContext()
    #endif

    // MARK: - Initialization

    /// - Parameter keychain: Credential store. Defaults to the shared production
    ///   store; tests inject an isolated instance so they never touch the real login.
    public init(configuration: AuthConfiguration = .default, keychain: KeychainService = .shared) {
        self.configuration = configuration
        self.keychain = keychain
        authLog("[Auth] AuthManager initialized, clientID: \(configuration.clientID.prefix(8))...")
    }

    // MARK: - Public API

    /// The current Bearer token for API requests, or nil if not authenticated.
    public var authorizationHeader: String? {
        guard let token = accessToken, isAuthenticated else { return nil }
        return "Bearer \(token)"
    }

    /// The raw access token for services that need it directly.
    public var currentAccessToken: String? {
        accessToken
    }

    /// Attempt to restore session from Keychain on app launch.
    public func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let storedToken = try await keychain.load(key: .accessToken) else {
                return
            }

            accessToken = storedToken
            refreshToken = try await keychain.load(key: .refreshToken)

            if let expiryString = try await keychain.load(key: .tokenExpiry),
               let expiryInterval = Double(expiryString) {
                tokenExpiry = Date(timeIntervalSince1970: expiryInterval)
            }

            // Load cached user info
            if let userJSON = try await keychain.load(key: .userInfo),
               let data = userJSON.data(using: .utf8) {
                currentUser = try JSONDecoder().decode(AuthenticatedUser.self, from: data)
            }

            // Check if token needs refresh
            if let expiry = tokenExpiry, Date() >= expiry {
                try await refreshAccessToken()
            } else {
                // Validate token by fetching user info
                try await fetchUserInfo()
            }

            isAuthenticated = true

        } catch {
            // Being offline is not a reason to log the user out. If the failure
            // is a connectivity error and we already loaded a cached token, keep
            // the restored session (offline mode); only a genuine auth failure
            // clears it and wipes the tokens.
            if Self.isNetworkError(error), accessToken != nil {
                isAuthenticated = true
                authLog("[Auth] restoreSession: offline — keeping cached session")
            } else {
                await clearSession()
            }
        }
    }

    /// True for connectivity errors (device offline, host unreachable, timeout),
    /// as opposed to authentication/authorization failures.
    private static func isNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .timedOut, .cannotConnectToHost,
             .cannotFindHost, .networkConnectionLost, .dataNotAllowed,
             .internationalRoamingOff, .callIsActive:
            return true
        default:
            return false
        }
    }

    /// Start OAuth2 PKCE login flow.
    ///
    /// Opens the system browser (via ASWebAuthenticationSession) to the Gitea
    /// authorize endpoint. On callback, exchanges the authorization code for tokens.
    public func login() async throws {
        guard !configuration.clientID.isEmpty else {
            throw AuthError.notConfigured
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        authLog("[Auth] Starting OAuth2 PKCE login flow")

        // 1. Generate PKCE code verifier + challenge
        let verifier = generateCodeVerifier()
        guard let challenge = generateCodeChallenge(from: verifier) else {
            throw AuthError.pkceGenerationFailed
        }
        self.codeVerifier = verifier
        authLog("[Auth] PKCE verifier generated")

        // 2. Build authorization URL
        let state = UUID().uuidString
        self.oauthState = state
        guard var components = URLComponents(string: "\(configuration.giteaBaseURL)/login/oauth/authorize") else {
            throw AuthError.notConfigured
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: "read:user write:user read:repository write:repository"),
        ]

        guard let authURL = components.url else {
            throw AuthError.authorizationFailed("Failed to build authorization URL")
        }
        authLog("[Auth] Auth URL: \(authURL)")

        // 3. Present ASWebAuthenticationSession — store as property to prevent deallocation
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "directorschair"
            ) { [weak self] callbackURL, error in
                self?.authSession = nil // Release after completion
                if let error = error {
                    authLog("[Auth] ASWebAuthSession error: \(error.localizedDescription)")
                    continuation.resume(throwing: AuthError.authorizationFailed(error.localizedDescription))
                } else if let callbackURL = callbackURL {
                    authLog("[Auth] ASWebAuthSession callback received")  // URL contains the auth code — not logged
                    continuation.resume(returning: callbackURL)
                } else {
                    authLog("[Auth] ASWebAuthSession: no callback URL")
                    continuation.resume(throwing: AuthError.authorizationFailed("No callback URL received"))
                }
            }
            self.authSession?.prefersEphemeralWebBrowserSession = true
            #if canImport(AppKit)
            self.authSession?.presentationContextProvider = self.contextProvider
            #endif
            self.authSession?.start()
            authLog("[Auth] ASWebAuthenticationSession started")
        }

        authLog("[Auth] Callback URL received")  // URL contains the auth code — not logged

        // 4. Extract authorization code from callback
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.authorizationFailed("No authorization code in callback URL")
        }
        authLog("[Auth] Authorization code extracted")

        // Verify state matches
        let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
        guard returnedState == state else {
            throw AuthError.authorizationFailed("State mismatch — possible CSRF attack")
        }
        authLog("[Auth] State verified")

        // 5. Exchange code for tokens
        authLog("[Auth] Exchanging code for tokens...")
        try await exchangeCodeForTokens(code: code)
        authLog("[Auth] Token exchange successful")

        // 6. Fetch user info
        authLog("[Auth] Fetching user info...")
        try await fetchUserInfo()
        authLog("[Auth] User info fetched: \(currentUser?.username ?? "unknown")")

        isAuthenticated = true
        authLog("[Auth] Login complete — authenticated!")
    }

    /// Handle an OAuth callback URL (from URL scheme or local server).
    public func handleCallback(url: URL) async throws {
        authLog("[Auth] handleCallback called")  // URL contains the auth code — not logged

        // If login() flow is already handling this via ASWebAuthenticationSession, skip
        if authSession != nil {
            authLog("[Auth] handleCallback skipped — ASWebAuthenticationSession is active")
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.authorizationFailed("No authorization code in callback")
        }

        // CSRF protection: only accept a callback whose state matches the one we
        // issued when login() started. A callback with no pending login, or a
        // mismatched state, is rejected (same check login()'s own flow performs).
        let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
        guard let expectedState = oauthState, returnedState == expectedState else {
            oauthState = nil
            throw AuthError.authorizationFailed("State mismatch — possible CSRF attack")
        }
        oauthState = nil

        authLog("[Auth] handleCallback: exchanging code for tokens...")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        try await exchangeCodeForTokens(code: code)
        try await fetchUserInfo()
        isAuthenticated = true
        authLog("[Auth] handleCallback: login complete!")
    }

    /// Refresh the access token using the stored refresh token.
    public func refreshTokenIfNeeded() async throws {
        guard let expiry = tokenExpiry else { return }

        // Refresh 60 seconds before actual expiry
        if Date().addingTimeInterval(60) >= expiry {
            try await refreshAccessToken()
        }
    }

    /// Force-refresh the access token regardless of expiry.
    /// Used when the server rejects the current token with 401.
    public func forceRefreshToken() async throws {
        authLog("[Auth] Force token refresh requested")
        try await refreshAccessToken()
    }

    /// Log out: clear tokens, Keychain, and state.
    public func logout() async {
        await clearSession()
    }

    // MARK: - Token Exchange

    /// Build an endpoint URL from the configured base + path, throwing rather
    /// than force-unwrapping if the configured base URL is malformed (WS3.5).
    private func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: "\(configuration.giteaBaseURL)\(path)") else {
            throw AuthError.notConfigured
        }
        return url
    }

    private func exchangeCodeForTokens(code: String) async throws {
        guard let verifier = codeVerifier else {
            authLog("[Auth] exchangeCodeForTokens: NO code verifier!")
            throw AuthError.pkceGenerationFailed
        }

        let tokenURL = try endpoint("/login/oauth/access_token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": configuration.clientID,
            "code": code,
            "redirect_uri": configuration.redirectURI,
            "code_verifier": verifier,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        authLog("[Auth] Token exchange POST to: \(tokenURL)")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.tokenExchangeFailed("Not an HTTP response")
        }

        authLog("[Auth] Token exchange response: HTTP \(httpResponse.statusCode)")
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "unknown"
            authLog("[Auth] Token exchange FAILED: \(responseBody)")
            throw AuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(responseBody)")
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        authLog("[Auth] Token received, scope: \(tokenResponse.scope ?? "none")")
        try await storeTokens(tokenResponse)
        self.codeVerifier = nil
    }

    private func refreshAccessToken() async throws {
        // Coalesce concurrent refreshes: if two requests hit 401 at once, they
        // must share one refresh, not both POST (Gitea rotates the refresh token
        // so the second would fail and drop a still-valid session).
        if let existing = inFlightRefresh {
            try await existing.value
            return
        }
        let task = Task { try await performTokenRefresh() }
        inFlightRefresh = task
        defer { inFlightRefresh = nil }
        try await task.value
    }

    private func performTokenRefresh() async throws {
        guard let refresh = refreshToken else {
            throw AuthError.noRefreshToken
        }

        let tokenURL = try endpoint("/login/oauth/access_token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": configuration.clientID,
            "refresh_token": refresh,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            // No HTTP response (transient) — keep the session, allow a retry.
            throw AuthError.sessionExpired
        }

        if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
            // The refresh token itself is rejected (invalid_grant) — the session
            // is genuinely dead. This is the only case that logs the user out.
            await clearSession()
            throw AuthError.sessionExpired
        }

        guard httpResponse.statusCode == 200 else {
            // Server-side or transient failure (5xx, rate limit, etc.). Do NOT
            // clear the session — a temporary hiccup must not log the user out
            // and tear down their open project. Let the caller retry later.
            throw AuthError.sessionExpired
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        try await storeTokens(tokenResponse)
    }

    // MARK: - User Info

    private func fetchUserInfo() async throws {
        guard let token = accessToken else {
            throw AuthError.userInfoFailed("No access token")
        }

        let url = try endpoint("/api/v1/user")
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.userInfoFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.userInfoFailed("Invalid JSON")
        }

        let user = AuthenticatedUser(
            id: json["id"] as? Int ?? 0,
            username: json["login"] as? String ?? "",
            email: json["email"] as? String ?? "",
            fullName: json["full_name"] as? String ?? "",
            avatarURL: json["avatar_url"] as? String ?? "",
            isAdmin: json["is_admin"] as? Bool ?? false
        )

        currentUser = user

        // Cache user info in Keychain
        if let userJSON = try? JSONEncoder().encode(user),
           let userString = String(data: userJSON, encoding: .utf8) {
            try await keychain.save(userString, forKey: .userInfo)
        }
    }

    // MARK: - Token Storage

    private func storeTokens(_ response: TokenResponse) async throws {
        accessToken = response.access_token
        refreshToken = response.refresh_token

        if let expiresIn = response.expires_in {
            tokenExpiry = Date().addingTimeInterval(Double(expiresIn))
        }

        do {
            try await keychain.save(response.access_token, forKey: .accessToken)

            if let refresh = response.refresh_token {
                try await keychain.save(refresh, forKey: .refreshToken)
            }

            if let expiry = tokenExpiry {
                try await keychain.save(String(expiry.timeIntervalSince1970), forKey: .tokenExpiry)
            }
        } catch {
            throw AuthError.keychainError(error.localizedDescription)
        }
    }

    private func clearSession() async {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        currentUser = nil
        isAuthenticated = false
        codeVerifier = nil
        errorMessage = nil

        try? await keychain.deleteAll()
    }

    // MARK: - PKCE Helpers

    /// Generate a random code verifier (43-128 URL-safe characters).
    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Generate S256 code challenge from verifier.
    private func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .utf8) else { return nil }
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Presentation Context Provider

#if canImport(AppKit)
/// Provides the anchor window for ASWebAuthenticationSession on macOS.
class AuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        return window
    }
}
#endif
