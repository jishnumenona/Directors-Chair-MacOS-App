// GiteaClientNetworkTests.swift
//
// WS4.7 — network-path tests that exercise GiteaClient against a URLProtocol
// stub (no live server). These verify the WS4.2 pagination fix and auth-error
// mapping that previously had zero coverage.

import XCTest
@testable import DirectorsChairServices
@testable import DirectorsChairCore

// MARK: - URLProtocol stub

final class MockURLProtocol: URLProtocol {
    /// Set per test. Receives the request, returns (response, body).
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
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

// MARK: - Tests

final class GiteaClientNetworkTests: XCTestCase {

    private func makeClient() -> GiteaClient {
        GiteaClient(baseURL: URL(string: "https://gitea.test")!,
                    token: "t", protocolClasses: [MockURLProtocol.self])
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func json(_ object: Any, status: Int, for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let data = try JSONSerialization.data(withJSONObject: object)
        let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, data)
    }

    private func treePage(count: Int, truncated: Bool) -> [String: Any] {
        let entries = (0..<count).map { ["path": "f\($0)", "type": "blob", "mode": "100644", "sha": "sha\($0)"] }
        return ["tree": entries, "truncated": truncated]
    }

    // WS4.2: getTree must page past Gitea's truncation, not stop at page 1.
    func testGetTreePaginatesUntilNotTruncated() async throws {
        MockURLProtocol.handler = { [self] request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "page" })?.value
            switch page {
            case "1": return try json(treePage(count: 1000, truncated: true), status: 200, for: request)
            case "2": return try json(treePage(count: 500, truncated: false), status: 200, for: request)
            default:  return try json(treePage(count: 0, truncated: false), status: 200, for: request)
            }
        }

        let entries = try await makeClient().getTree(owner: "u", repo: "r")
        XCTAssertEqual(entries.count, 1500, "All pages must be fetched, not just the first")
    }

    func testGetTreeSinglePageStops() async throws {
        MockURLProtocol.handler = { [self] request in
            try json(treePage(count: 3, truncated: false), status: 200, for: request)
        }
        let entries = try await makeClient().getTree(owner: "u", repo: "r")
        XCTAssertEqual(entries.count, 3)
    }

    // A 401 must surface as an authentication error, not a generic failure.
    func testUnauthorizedMapsToAuthenticationFailed() async {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        do {
            _ = try await makeClient().listRepositories()
            XCTFail("A 401 should throw")
        } catch let error as RemoteRepositoryError {
            guard case .authenticationFailed = error else {
                return XCTFail("Expected .authenticationFailed, got \(error)")
            }
        } catch {
            XCTFail("Expected RemoteRepositoryError, got \(type(of: error))")
        }
    }
}

// MARK: - CloudSyncManager failure reporting (WS4.1)

@MainActor
final class CloudSyncManagerNetworkTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    // WS4.1: a push where uploads fail must report .error and throw — never
    // report success (the "safely in the cloud" illusion).
    func testPushReportsErrorWhenUploadsFail() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dc-sync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(#"{"name":"P","schema_version":1}"#.utf8)
            .write(to: dir.appendingPathComponent("project.json"))

        MockURLProtocol.handler = { request in
            let url = request.url!
            func resp(_ status: Int, _ obj: Any) throws -> (HTTPURLResponse, Data) {
                (HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                 headerFields: ["Content-Type": "application/json"])!,
                 try JSONSerialization.data(withJSONObject: obj))
            }
            let path = url.path
            if path.contains("/git/trees/") { return try resp(200, ["tree": [], "truncated": false]) }
            if path.contains("/contents/")  { return try resp(500, ["message": "upload boom"]) } // uploads fail
            if path.contains("/repos/")     { return try resp(200, ["name": "p"]) }               // repo exists
            return try resp(200, [:])
        }

        var project = Project(name: "P")
        project.basePath = dir.path
        let manager = CloudSyncManager(protocolClasses: [MockURLProtocol.self])

        do {
            try await manager.push(project: project, username: "tester")
            XCTFail("Push should throw when uploads fail")
        } catch {
            // expected
        }

        if case .error = manager.syncState {
            // correct: reported as an error, not .lastSynced
        } else {
            XCTFail("syncState must be .error after failed uploads, got \(manager.syncState)")
        }
    }

    // WS4.3: git blob SHA must match git's algorithm so unchanged files are
    // correctly recognised and skipped. Values from `git hash-object`.
    func testGitBlobSHAMatchesGit() {
        XCTAssertEqual(CloudSyncManager.gitBlobSHA(Data()),
                       "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")            // empty
        XCTAssertEqual(CloudSyncManager.gitBlobSHA(Data("hello\n".utf8)),
                       "ce013625030ba8dba906f756967f9e9ca394464a")            // "hello\n"
    }
}
