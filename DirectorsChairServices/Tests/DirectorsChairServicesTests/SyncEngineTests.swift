// SyncEngineTests.swift
//
// SyncEngine v1: manifest building + exclusion rules, wire error mapping, and
// the push/pull/conflict flows against a scripted in-memory sync server
// (MockURLProtocol, the module's transport-faking convention).

import Combine
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
    /// Orgs §12B.7 directory routes.
    var orgs: [[String: Any]] = []
    var orgProjects: [String: [[String: Any]]] = [:]
    var projectList: [[String: Any]] = []
    /// When true, commits 409 with the archived marker (server _not_archived).
    var archived = false

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
            if archived {
                return try ok(["detail": ["error": "project archived",
                                          "message": "unarchive in the portal"]],
                              status: 409, url: url)
            }
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

        case ("GET", "/api/v1/projects"):
            return try ok(projectList, url: url)

        case ("GET", "/api/v1/orgs"):
            return try ok(orgs, url: url)

        case ("GET", let p) where p.hasPrefix("/api/v1/orgs/") && p.hasSuffix("/projects"):
            let orgID = p.components(separatedBy: "/")[4]
            return try ok(orgProjects[orgID] ?? [], url: url)

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

    func testPushPublishesByteWeightedProgress() async throws {
        // The toolbar renders engine.progress as a percent: it must start
        // low, climb monotonically to 1.0 as blob bytes land, and clear to
        // nil at the terminal state so the button falls back to its icon.
        try write("assets/big.bin", String(repeating: "x", count: 9_000))
        try write("assets/small.bin", "yy")
        var seen: [Double] = []
        let cancellable = engine.$progress.sink { value in
            if let value { seen.append(value) }
        }
        defer { cancellable.cancel() }

        let pushed = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")

        XCTAssertTrue(pushed)
        XCTAssertEqual(seen.last, 1.0, "all bytes accounted for at the end")
        XCTAssertEqual(seen, seen.sorted(), "progress never goes backwards")
        XCTAssertTrue(seen.contains { $0 > 0 && $0 < 1 },
                      "intermediate percentages exist (byte-weighted, not 0→1)")
        XCTAssertNil(engine.progress, "terminal state clears the percent")
    }

    func testPullPublishesDownloadProgress() async throws {
        _ = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        // Another device committed a new asset; our pull must report
        // byte-weighted download progress the same way push does.
        let checkpoint = SyncCheckpoint.load(projectDir: projectDir)!
        let payload = Data("their-asset-bytes".utf8)
        let sha = SyncHashing.sha256Hex(payload)
        server.blobs[sha] = payload
        server.committedBlobs.insert(sha)
        server.headRevision = 2
        server.revisions[2] = [
            "revision": 2, "parent_revision": 1, "merged_from": NSNull(),
            "manifest": ["schema": 1,
                         "project_blob": ["sha256": checkpoint.lastManifest!.projectBlob.sha256,
                                          "size": checkpoint.lastManifest!.projectBlob.size],
                         "assets": [["path": "assets/theirs.bin",
                                     "sha256": sha, "size": payload.count]],
                         "deleted": []],
            "device_name": "other-mac", "created_at": "2026-07-19T00:00:00Z",
        ]
        var seen: [Double] = []
        let cancellable = engine.$progress.sink { value in
            if let value { seen.append(value) }
        }
        defer { cancellable.cancel() }

        let pulled = await engine.pull(projectDir: projectDir)

        XCTAssertTrue(pulled)
        XCTAssertEqual(seen.last, 1.0)
        XCTAssertNil(engine.progress, "terminal state clears the percent")
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

    // MARK: Orgs desktop echoes (§12B.7)

    private func seedOrgDirectory(role: String = "editor") {
        server.orgs = [
            ["id": "u-1", "slug": "me", "name": "me", "kind": "personal",
             "my_role": "org_admin"],
            ["id": "o-1", "slug": "studio", "name": "Aurora Studio",
             "kind": "team", "my_role": "member"],
        ]
        server.projectList = [
            ["id": "p-1", "name": "Film", "head_revision": 1, "bytes_total": 9,
             "archived_at": NSNull(), "updated_at": NSNull(), "org_id": "o-1"],
        ]
        server.orgProjects = [
            "u-1": [],
            "o-1": [["id": "p-1", "name": "Film", "head_revision": 1,
                     "bytes_total": 9, "archived_at": NSNull(),
                     "updated_at": NSNull(), "org_id": "o-1",
                     "my_role": role],
                    ["id": "p-2", "name": "Locked", "org_id": "o-1",
                     "my_role": NSNull()]],
        ]
    }

    func testCloudDirectoryGroupsProjectsByOrg() async throws {
        seedOrgDirectory()
        let listings = try await engine.cloudDirectory()
        XCTAssertEqual(listings.map(\.org.name), ["me", "Aurora Studio"])
        XCTAssertEqual(listings[1].projects.map(\.id), ["p-1", "p-2"])
        XCTAssertEqual(listings[1].projects[0].myRole, "editor")
        XCTAssertNil(listings[1].projects[1].myRole,
                     "list-only visibility decodes as no role")
    }

    func testRefreshRemoteContextCachesOrgAndRole() async throws {
        seedOrgDirectory(role: "viewer")
        try SyncCheckpoint(projectID: "p-1", lastRevision: 1)
            .save(projectDir: projectDir)
        await engine.refreshRemoteContext(projectDir: projectDir)
        XCTAssertEqual(engine.orgName, "Aurora Studio")
        XCTAssertEqual(engine.myRole, "viewer")
        XCTAssertTrue(engine.isViewer)
        // Cached: a fresh engine reads it offline from the checkpoint.
        let checkpoint = SyncCheckpoint.load(projectDir: projectDir)
        XCTAssertEqual(checkpoint?.orgName, "Aurora Studio")
        XCTAssertEqual(checkpoint?.myRole, "viewer")
    }

    func testPersonalOrgRendersAsPersonal() async throws {
        seedOrgDirectory()
        server.projectList = [["id": "p-1", "name": "Film", "head_revision": 1,
                               "bytes_total": 9, "archived_at": NSNull(),
                               "updated_at": NSNull(), "org_id": "u-1"]]
        server.orgProjects["u-1"] = [["id": "p-1", "name": "Film",
                                      "org_id": "u-1", "my_role": "owner"]]
        try SyncCheckpoint(projectID: "p-1", lastRevision: 1)
            .save(projectDir: projectDir)
        await engine.refreshRemoteContext(projectDir: projectDir)
        XCTAssertEqual(engine.orgName, "Personal")
        XCTAssertFalse(engine.isViewer)
    }

    func testArchivedProjectPushSurfacesClearState() async throws {
        _ = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        server.archived = true
        try write("project.json", #"{"uuid":"p-1","name":"Film","edited":true}"#)
        let pushed = await engine.push(projectDir: projectDir, projectID: "p-1",
                                       name: "Film")
        XCTAssertFalse(pushed)
        guard case .error(let message) = engine.state else {
            return XCTFail("expected error state")
        }
        XCTAssertTrue(message.contains("archived"), message)
        XCTAssertTrue(message.contains("portal"), message)
    }

    func testCloneBootstrapsDirectoryAndPulls() async throws {
        // Seed the server with one pushed revision from THIS device...
        try write("assets/a.png", "aaa")
        let pushed = await engine.push(projectDir: projectDir, projectID: "p-1",
                                       name: "Film")
        XCTAssertTrue(pushed)
        // ...then clone it as if on a brand-new Mac.
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("clone-parent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent,
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let dir = await engine.clone(projectID: "p-1", name: "Film",
                                     orgName: "Aurora Studio", myRole: "editor",
                                     into: parent)
        let cloned = try XCTUnwrap(dir)
        XCTAssertEqual(cloned.lastPathComponent, "Film")
        let json = try String(contentsOf: cloned.appendingPathComponent("project.json"),
                              encoding: .utf8)
        XCTAssertTrue(json.contains(#""uuid":"p-1""#))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: cloned.appendingPathComponent("assets/a.png").path))
        let checkpoint = try XCTUnwrap(SyncCheckpoint.load(projectDir: cloned))
        XCTAssertEqual(checkpoint.lastRevision, 1)
        XCTAssertEqual(checkpoint.orgName, "Aurora Studio")
        XCTAssertEqual(checkpoint.myRole, "editor")
        XCTAssertEqual(engine.orgName, "Aurora Studio")
    }

    func testCloneCollisionPicksFreshDirectoryName() async throws {
        try write("assets/a.png", "aaa")
        _ = await engine.push(projectDir: projectDir, projectID: "p-1", name: "Film")
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("clone-parent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: parent.appendingPathComponent("Film"),
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let dir = await engine.clone(projectID: "p-1", name: "Film",
                                     orgName: nil, myRole: nil, into: parent)
        XCTAssertEqual(try XCTUnwrap(dir).lastPathComponent, "Film 2")
    }
}
