// SyncEngineTests.swift
//
// SyncEngine v1: manifest building + exclusion rules, wire error mapping, and
// the push/pull/conflict flows against a scripted in-memory sync server
// (MockURLProtocol, the module's transport-faking convention).

import XCTest
@testable import DirectorsChairServices

// MARK: - Scripted sync server

/// Minimal in-memory stand-in for platform-service: routes the sync API and
/// presigned-transfer URLs through one MockURLProtocol handler.
final class ScriptedSyncServer {
    var headRevision = 0
    var revisions: [Int: [String: Any]] = [:]
    var blobs: [String: Data] = [:]
    var committedBlobs: Set<String> = []
    var createdProjects: [String] = []

    func install() {
        MockURLProtocol.handler = { [weak self] request in
            guard let self else { throw URLError(.cancelled) }
            return try self.route(request)
        }
    }

    private func ok(_ object: Any, status: Int = 200, url: URL) throws -> (HTTPURLResponse, Data) {
        let data = try JSONSerialization.data(withJSONObject: object)
        let response = HTTPURLResponse(url: url, statusCode: status,
                                       httpVersion: nil, headerFields: nil)!
        return (response, data)
    }

    private func body(of request: URLRequest) -> [String: Any] {
        guard let stream = request.httpBodyStream else { return [:] }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func rawBody(of request: URLRequest) -> Data {
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    private func route(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let url = request.url!
        let path = url.path
        let method = request.httpMethod ?? "GET"

        // Presigned transfer endpoints (fake storage host).
        if url.host == "storage.test" {
            let sha = url.lastPathComponent
            if method == "PUT" {
                blobs[sha] = rawBody(of: request)
                return try ok([:], url: url)
            }
            let response = HTTPURLResponse(url: url, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, blobs[sha] ?? Data())
        }

        switch (method, path) {
        case ("POST", let p) where p.hasSuffix("/blobs/lookup"):
            let raw = rawBody(of: request)
            let refs = (try? JSONSerialization.jsonObject(with: raw) as? [[String: Any]]) ?? []
            let missing = refs.compactMap { $0["sha256"] as? String }
                .filter { !committedBlobs.contains($0) }
            return try ok(["missing": missing], url: url)

        case ("POST", let p) where p.contains("/blobs/") && p.hasSuffix("/complete"):
            let sha = p.components(separatedBy: "/").dropLast().last!
            committedBlobs.insert(sha)
            return try ok(["sha256": sha, "state": "committed"], url: url)

        case ("POST", let p) where p.hasSuffix("/blobs"):
            let staged = body(of: request)
            let sha = staged["sha256"] as? String ?? "?"
            return try ok(["upload_url": "https://storage.test/put/\(sha)",
                           "headers": ["Content-Length": "\(staged["size"] ?? 0)"]],
                          url: url)

        case ("GET", let p) where p.contains("/blobs/"):
            let sha = p.components(separatedBy: "/").last!
            return try ok(["download_url": "https://storage.test/get/\(sha)"], url: url)

        case ("POST", let p) where p.hasSuffix("/revisions"):
            let payload = body(of: request)
            let base = payload["base_revision"] as? Int ?? -1
            guard base == headRevision else {
                return try ok(["detail": ["head_revision": headRevision]],
                              status: 409, url: url)
            }
            headRevision += 1
            revisions[headRevision] = [
                "revision": headRevision, "parent_revision": base,
                "merged_from": payload["merged_from"] as Any? ?? NSNull(),
                "manifest": payload["manifest"] ?? [:],
                "device_name": payload["device_name"] ?? "",
                "created_at": "2026-07-19T00:00:00Z",
            ]
            return try ok(["revision": headRevision, "cursor": headRevision],
                          status: 201, url: url)

        case ("GET", let p) where p.contains("/revisions/"):
            let number = Int(p.components(separatedBy: "/").last!) ?? 0
            return try ok(revisions[number] ?? [:], url: url)

        case ("GET", let p) where p.hasSuffix("/revisions"):
            let since = Int(url.query?.components(separatedBy: "since=").last ?? "0") ?? 0
            let newer = revisions.keys.filter { $0 > since }.sorted()
                .compactMap { revisions[$0] }
            return try ok(["revisions": newer, "cursor": headRevision], url: url)

        case ("POST", "/api/v1/projects"):
            let payload = body(of: request)
            createdProjects.append(payload["id"] as? String ?? "?")
            return try ok(["id": payload["id"] ?? "", "name": payload["name"] ?? "",
                           "head_revision": 0, "bytes_total": 0,
                           "archived_at": NSNull(), "updated_at": NSNull()],
                          status: 201, url: url)

        default:
            return try ok(["detail": "not found"], status: 404, url: url)
        }
    }
}

// MARK: - Tests

@MainActor
final class SyncEngineTests: XCTestCase {
    var server: ScriptedSyncServer!
    var engine: SyncEngine!
    var projectDir: URL!

    override func setUp() async throws {
        server = ScriptedSyncServer()
        server.install()
        let client = SyncAPIClient(baseURL: URL(string: "https://sync.test")!,
                                   deviceName: "test-mac",
                                   protocolClasses: [MockURLProtocol.self])
        await client.setTokenProvider({ "test-token" }, refresher: { nil })
        engine = SyncEngine(client: client)
        projectDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectDir,
                                                withIntermediateDirectories: true)
        try write("project.json", #"{"uuid":"p-1","name":"Film"}"#)
    }

    override func tearDown() async throws {
        MockURLProtocol.handler = nil
        try? FileManager.default.removeItem(at: projectDir)
    }

    func write(_ relative: String, _ content: String) throws {
        let url = projectDir.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try content.data(using: .utf8)!.write(to: url)
    }

    // MARK: Manifest builder

    func testManifestExcludesDeviceLocalAndHeavyPaths() throws {
        try write("assets/characters/alex/face.png", "png")
        try write(".backups/project_old.json", "backup")
        try write("exports/final.mov", "movie")
        try write("footage/Scene/Shot_001/Take_001.mov", "take")
        try write(".sync-state.json", "{}")
        try write(".DS_Store", "junk")
        let manifest = try SyncManifestBuilder.build(projectDir: projectDir, previous: nil)
        XCTAssertEqual(manifest.assets.map(\.path), ["assets/characters/alex/face.png"])
        XCTAssertEqual(manifest.deleted, [])
        XCTAssertGreaterThan(manifest.projectBlob.size, 0)
    }

    func testTombstonesComeFromPreviousManifest() throws {
        try write("assets/a.png", "a")
        let first = try SyncManifestBuilder.build(projectDir: projectDir, previous: nil)
        try FileManager.default.removeItem(
            at: projectDir.appendingPathComponent("assets/a.png"))
        let second = try SyncManifestBuilder.build(projectDir: projectDir, previous: first)
        XCTAssertEqual(second.deleted, ["assets/a.png"])
    }

    // MARK: Push

    func testFirstPushCreatesProjectUploadsAndCommits() async throws {
        try write("assets/a.png", "aaa")
        let pushed = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        XCTAssertTrue(pushed)
        XCTAssertEqual(server.createdProjects, ["p-1"])
        XCTAssertEqual(server.headRevision, 1)
        XCTAssertEqual(server.committedBlobs.count, 2)   // project.json + a.png
        let checkpoint = SyncCheckpoint.load(projectDir: projectDir)
        XCTAssertEqual(checkpoint?.lastRevision, 1)
        guard case .synced = engine.state else { return XCTFail("state \(engine.state)") }
    }

    func testUnchangedPushShortCircuits() async throws {
        _ = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        let revisionsBefore = server.headRevision
        _ = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        XCTAssertEqual(server.headRevision, revisionsBefore)   // no new revision
    }

    func testAssetOnlyDivergenceAutoMerges() async throws {
        _ = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        // Another device adds an asset on top (head moves to 2, project.json same).
        let checkpoint = SyncCheckpoint.load(projectDir: projectDir)!
        let theirAsset = SyncManifestAsset(path: "assets/theirs.png",
                                           sha256: String(repeating: "b", count: 64),
                                           size: 3)
        server.committedBlobs.insert(theirAsset.sha256)
        server.headRevision = 2
        server.revisions[2] = [
            "revision": 2, "parent_revision": 1, "merged_from": NSNull(),
            "manifest": ["schema": 1,
                         "project_blob": ["sha256": checkpoint.lastManifest!.projectBlob.sha256,
                                          "size": checkpoint.lastManifest!.projectBlob.size],
                         "assets": [["path": theirAsset.path,
                                     "sha256": theirAsset.sha256,
                                     "size": theirAsset.size]],
                         "deleted": []],
            "device_name": "other-mac", "created_at": "2026-07-19T00:00:00Z",
        ]
        // We add a different asset locally and push from the stale base.
        try write("assets/ours.png", "ooo")
        let pushed = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        XCTAssertTrue(pushed)
        XCTAssertEqual(server.headRevision, 3)
        let merged = server.revisions[3]!["manifest"] as! [String: Any]
        let paths = (merged["assets"] as! [[String: Any]]).map { $0["path"] as! String }
        XCTAssertEqual(Set(paths), ["assets/theirs.png", "assets/ours.png"])
        guard case .synced = engine.state else { return XCTFail("state \(engine.state)") }
    }

    func testProjectJSONOverlapSurfacesConflictAndKeepMineWins() async throws {
        _ = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        // Another device changed project.json (head 2, different project blob).
        server.committedBlobs.insert(String(repeating: "c", count: 64))
        server.headRevision = 2
        server.revisions[2] = [
            "revision": 2, "parent_revision": 1, "merged_from": NSNull(),
            "manifest": ["schema": 1,
                         "project_blob": ["sha256": String(repeating: "c", count: 64),
                                          "size": 10],
                         "assets": [], "deleted": []],
            "device_name": "other-mac", "created_at": "2026-07-19T00:00:00Z",
        ]
        // We ALSO changed project.json → true overlap.
        try write("project.json", #"{"uuid":"p-1","name":"Film","edited":"mine"}"#)
        let pushed = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        XCTAssertFalse(pushed)
        guard case .conflict(let conflict) = engine.state else {
            return XCTFail("expected conflict, got \(engine.state)")
        }
        XCTAssertEqual(conflict.headRevision, 2)

        await engine.resolveKeepMine(projectDir: projectDir)
        XCTAssertEqual(server.headRevision, 3)
        XCTAssertEqual(SyncCheckpoint.load(projectDir: projectDir)?.lastRevision, 3)
        guard case .synced = engine.state else { return XCTFail("state \(engine.state)") }
    }

    // MARK: Pull

    func testPullAppliesNewRevisionAndTombstones() async throws {
        try write("assets/old.png", "old")
        _ = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        // Remote head 2: new project.json + a new asset; old.png tombstoned.
        let newProject = Data(#"{"uuid":"p-1","name":"Renamed"}"#.utf8)
        let newProjectSHA = SyncHashing.sha256Hex(newProject)
        let newAsset = Data("fresh".utf8)
        let newAssetSHA = SyncHashing.sha256Hex(newAsset)
        server.blobs[newProjectSHA] = newProject
        server.blobs[newAssetSHA] = newAsset
        server.committedBlobs.formUnion([newProjectSHA, newAssetSHA])
        server.headRevision = 2
        server.revisions[2] = [
            "revision": 2, "parent_revision": 1, "merged_from": NSNull(),
            "manifest": ["schema": 1,
                         "project_blob": ["sha256": newProjectSHA, "size": newProject.count],
                         "assets": [["path": "assets/fresh.png",
                                     "sha256": newAssetSHA, "size": newAsset.count]],
                         "deleted": ["assets/old.png"]],
            "device_name": "other-mac", "created_at": "2026-07-19T00:00:00Z",
        ]
        let applied = await engine.pull(projectDir: projectDir)
        XCTAssertTrue(applied)
        let projectData = try Data(contentsOf: projectDir.appendingPathComponent("project.json"))
        XCTAssertTrue(String(data: projectData, encoding: .utf8)!.contains("Renamed"))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: projectDir.appendingPathComponent("assets/fresh.png").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: projectDir.appendingPathComponent("assets/old.png").path),
            "tombstoned file must not survive the pull")
        XCTAssertEqual(SyncCheckpoint.load(projectDir: projectDir)?.lastRevision, 2)
    }

    func testPullRefusesPathTraversal() async throws {
        _ = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        let evil = Data("evil".utf8)
        let evilSHA = SyncHashing.sha256Hex(evil)
        server.blobs[evilSHA] = evil
        server.committedBlobs.insert(evilSHA)
        let checkpoint = SyncCheckpoint.load(projectDir: projectDir)!
        server.headRevision = 2
        server.revisions[2] = [
            "revision": 2, "parent_revision": 1, "merged_from": NSNull(),
            "manifest": ["schema": 1,
                         "project_blob": ["sha256": checkpoint.lastManifest!.projectBlob.sha256,
                                          "size": checkpoint.lastManifest!.projectBlob.size],
                         "assets": [["path": "../../escape.txt",
                                     "sha256": evilSHA, "size": evil.count]],
                         "deleted": []],
            "device_name": "evil", "created_at": "2026-07-19T00:00:00Z",
        ]
        _ = await engine.pull(projectDir: projectDir)
        let escapePath = projectDir.deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("escape.txt").path
        XCTAssertFalse(FileManager.default.fileExists(atPath: escapePath),
                       "path traversal must never write outside the project dir")
    }
}
