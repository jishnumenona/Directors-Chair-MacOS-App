// DirectorsChairServices/Tests/DirectorsChairServicesTests/AuthManagerHandoffTests.swift
//
// Network-path tests for the desktop → web SSO handoff ("Open Web Dashboard"):
// AuthManager.createWebHandoffTicket() against a URLProtocol stub (no live
// server), plus the pure redeem-URL builder. Wire contract: auth-service
// POST /login/handoff/create → {ticket, expires_in}; the browser redeems at
// platform GET /api/v1/session/handoff?ticket=…

import XCTest
@testable import DirectorsChairServices

// MARK: - URLProtocol stub

/// Private stub (not the GiteaClient tests' MockURLProtocol) so a parallel
/// test run can't clobber another class's handler.
final class HandoffURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = HandoffURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

// MARK: - Response helpers (file scope: the stub handler runs off the main
// actor, so these must not be isolated to the @MainActor test class)

private func json(_ object: Any, status: Int, for request: URLRequest) throws -> (HTTPURLResponse, Data) {
    let data = try JSONSerialization.data(withJSONObject: object)
    let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    return (response, data)
}

private func userJSON() -> [String: Any] {
    ["id": 7, "login": "tester", "email": "t@example.com",
     "full_name": "Tester", "avatar_url": "", "is_admin": false]
}

// MARK: - Tests

@MainActor
final class AuthManagerHandoffTests: XCTestCase {

    private var authManager: AuthManager!
    private var testKeychain: KeychainService!

    override func setUp() async throws {
        try await super.setUp()
        let config = AuthConfiguration(
            giteaBaseURL: "https://auth.test.example.com",
            clientID: "test-client-id-12345",
            redirectURI: "directorschair://oauth/callback",
            localCallbackPort: 19999
        )
        testKeychain = KeychainService(suiteName: "com.directorschair.handoff.tests.\(UUID().uuidString)")
        authManager = AuthManager(configuration: config, keychain: testKeychain,
                                  protocolClasses: [HandoffURLProtocol.self])
    }

    override func tearDown() async throws {
        HandoffURLProtocol.handler = nil
        await testKeychain.removePersistentDomain()
        testKeychain = nil
        authManager = nil
        try await super.tearDown()
    }

    /// Seed the keychain with a valid (non-expiring-soon) session and restore
    /// it, so createWebHandoffTicket() runs against an authenticated manager.
    private func restoreAuthenticatedSession(accessToken: String, refreshToken: String? = nil) async throws {
        try await testKeychain.save(accessToken, forKey: .accessToken)
        if let refreshToken {
            try await testKeychain.save(refreshToken, forKey: .refreshToken)
        }
        let expiry = Date().addingTimeInterval(3600).timeIntervalSince1970
        try await testKeychain.save(String(expiry), forKey: .tokenExpiry)

        HandoffURLProtocol.handler = { request in
            try json(userJSON(), status: 200, for: request)   // /api/v1/user validation
        }
        await authManager.restoreSession()
        XCTAssertTrue(authManager.isAuthenticated, "Precondition: restored session must be authenticated")
    }

    // MARK: - Redeem-URL builder

    func testWebHandoffURLBuildsPlatformRedeemURL() {
        let url = AuthManager.webHandoffURL(ticket: "abc123")
        XCTAssertEqual(url.absoluteString,
                       "https://directorschair.app/api/v1/session/handoff?ticket=abc123",
                       "Redeem URL must target the platform BFF with the ticket as a query item")
    }

    func testWebHandoffURLPercentEncodesTicket() {
        let url = AuthManager.webHandoffURL(ticket: "a+b/c=")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "ticket" })?.value, "a+b/c=",
                       "Ticket must round-trip through query encoding unchanged")
    }

    // MARK: - createWebHandoffTicket

    func testCreateHandoffTicketUnauthenticatedThrows() async {
        do {
            _ = try await authManager.createWebHandoffTicket()
            XCTFail("A signed-out manager must not mint a handoff ticket")
        } catch let error as AuthError {
            guard case .sessionExpired = error else {
                return XCTFail("Expected .sessionExpired, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthError, got \(type(of: error)): \(error)")
        }
    }

    func testCreateHandoffTicketPostsBearerTokenAndReturnsTicket() async throws {
        try await restoreAuthenticatedSession(accessToken: "cached-token")

        var captured: URLRequest?
        HandoffURLProtocol.handler = { request in
            switch request.url!.path {
            case "/login/handoff/create":
                captured = request
                return try json(["ticket": "tkt-1", "expires_in": 120], status: 200, for: request)
            default:
                return try json(userJSON(), status: 200, for: request)
            }
        }

        let ticket = try await authManager.createWebHandoffTicket()

        XCTAssertEqual(ticket, "tkt-1")
        XCTAssertEqual(captured?.httpMethod, "POST", "Ticket minting is a POST")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer cached-token",
                       "Create must be authenticated with the user's own access token")
    }

    func testCreateHandoffTicket401RefreshesAndRetries() async throws {
        try await restoreAuthenticatedSession(accessToken: "stale-token", refreshToken: "refresh-1")

        var handoffTokensSeen: [String] = []
        HandoffURLProtocol.handler = { request in
            switch request.url!.path {
            case "/login/handoff/create":
                let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
                handoffTokensSeen.append(auth)
                if auth == "Bearer fresh-token" {
                    return try json(["ticket": "tkt-2", "expires_in": 120], status: 200, for: request)
                }
                return try json(["message": "invalid or expired token"], status: 401, for: request)
            case "/login/oauth/access_token":
                return try json(["access_token": "fresh-token", "token_type": "bearer",
                                 "expires_in": 900, "refresh_token": "refresh-2"],
                                status: 200, for: request)
            default:
                return try json(userJSON(), status: 200, for: request)
            }
        }

        let ticket = try await authManager.createWebHandoffTicket()

        XCTAssertEqual(ticket, "tkt-2")
        XCTAssertEqual(handoffTokensSeen, ["Bearer stale-token", "Bearer fresh-token"],
                       "A 401 must trigger exactly one forced refresh and one retry")
    }

    func testCreateHandoffTicketServerErrorThrowsHandoffFailed() async throws {
        try await restoreAuthenticatedSession(accessToken: "cached-token")

        HandoffURLProtocol.handler = { request in
            switch request.url!.path {
            case "/login/handoff/create":
                return try json(["message": "unavailable"], status: 503, for: request)
            default:
                return try json(userJSON(), status: 200, for: request)
            }
        }

        do {
            _ = try await authManager.createWebHandoffTicket()
            XCTFail("A 5xx must surface as handoffFailed, not a silent fallback")
        } catch let error as AuthError {
            guard case .handoffFailed(let msg) = error else {
                return XCTFail("Expected .handoffFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("503"), "Failure message should carry the HTTP status: \(msg)")
        } catch {
            XCTFail("Expected AuthError, got \(type(of: error)): \(error)")
        }
    }
}
