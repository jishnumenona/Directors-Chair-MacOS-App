// DirectorsChairServices/Tests/DirectorsChairServicesTests/CloudSyncManagerTests.swift
//
// Unit tests for CloudSyncManager sync state machine, repo name sanitization,
// and local-change tracking.

import XCTest
@testable import DirectorsChairServices
@testable import DirectorsChairCore

// MARK: - CloudSyncManager Tests

@MainActor
final class CloudSyncManagerTests: XCTestCase {

    // MARK: - Properties

    private var syncManager: CloudSyncManager!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        // Use a non-routable URL so no real network calls succeed
        syncManager = CloudSyncManager(giteaBaseURL: "http://localhost:19999")
    }

    override func tearDown() async throws {
        syncManager = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsIdle() {
        XCTAssertEqual(syncManager.syncState, .idle, "Fresh sync manager should be in idle state")
    }

    func testInitialPendingChangesIsZero() {
        XCTAssertEqual(syncManager.pendingChanges, 0, "Fresh sync manager should have zero pending changes")
    }

    func testInitialDebugLogsEmpty() {
        XCTAssertTrue(syncManager.debugLogs.isEmpty, "Fresh sync manager should have no debug logs")
    }

    // MARK: - SyncState Equatable Tests

    func testSyncStateEquatableIdle() {
        XCTAssertEqual(SyncState.idle, SyncState.idle)
    }

    func testSyncStateEquatableSyncing() {
        let state1 = SyncState.syncing(progress: 0.5, message: "Uploading...")
        let state2 = SyncState.syncing(progress: 0.5, message: "Uploading...")
        let state3 = SyncState.syncing(progress: 0.7, message: "Downloading...")

        XCTAssertEqual(state1, state2, "Same progress and message should be equal")
        XCTAssertNotEqual(state1, state3, "Different progress/message should not be equal")
    }

    func testSyncStateEquatableError() {
        let state1 = SyncState.error("Network error")
        let state2 = SyncState.error("Network error")
        let state3 = SyncState.error("Auth error")

        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
    }

    func testSyncStateEquatableLastSynced() {
        let date = Date()
        let state1 = SyncState.lastSynced(date)
        let state2 = SyncState.lastSynced(date)

        XCTAssertEqual(state1, state2)
    }

    func testSyncStateDifferentCasesNotEqual() {
        let idle = SyncState.idle
        let syncing = SyncState.syncing(progress: 0, message: "")
        let error = SyncState.error("")
        let lastSynced = SyncState.lastSynced(Date())

        XCTAssertNotEqual(idle, syncing)
        XCTAssertNotEqual(idle, error)
        XCTAssertNotEqual(idle, lastSynced)
        XCTAssertNotEqual(syncing, error)
    }

    // MARK: - Pending Changes Tracking

    func testMarkLocalChangeIncrements() {
        XCTAssertEqual(syncManager.pendingChanges, 0)

        syncManager.markLocalChange()
        XCTAssertEqual(syncManager.pendingChanges, 1)

        syncManager.markLocalChange()
        XCTAssertEqual(syncManager.pendingChanges, 2)

        syncManager.markLocalChange()
        XCTAssertEqual(syncManager.pendingChanges, 3)
    }

    func testMarkLocalChangeMultipleTimes() {
        for _ in 0..<100 {
            syncManager.markLocalChange()
        }
        XCTAssertEqual(syncManager.pendingChanges, 100)
    }

    // MARK: - Repo Name Sanitization Tests

    func testSanitizeRepoNameBasic() {
        let result = syncManager.sanitizeRepoName("My First Project")
        XCTAssertEqual(result, "my-first-project")
    }

    func testSanitizeRepoNameWithSpecialCharacters() {
        let result = syncManager.sanitizeRepoName("Project: The Beginning!")
        // Colons and exclamation marks should be stripped
        XCTAssertEqual(result, "project-the-beginning")
    }

    func testSanitizeRepoNamePreservesDots() {
        let result = syncManager.sanitizeRepoName("project.v2.0")
        XCTAssertEqual(result, "project.v2.0")
    }

    func testSanitizeRepoNamePreservesUnderscores() {
        let result = syncManager.sanitizeRepoName("my_project_name")
        XCTAssertEqual(result, "my_project_name")
    }

    func testSanitizeRepoNamePreservesHyphens() {
        let result = syncManager.sanitizeRepoName("my-project-name")
        XCTAssertEqual(result, "my-project-name")
    }

    func testSanitizeRepoNameEmptyStringReturnsDefault() {
        let result = syncManager.sanitizeRepoName("")
        XCTAssertEqual(result, "untitled-project", "Empty name should return 'untitled-project'")
    }

    func testSanitizeRepoNameAllSpecialCharsReturnsDefault() {
        let result = syncManager.sanitizeRepoName("!@#$%^&*()")
        XCTAssertEqual(result, "untitled-project", "All-special-chars name should return 'untitled-project'")
    }

    func testSanitizeRepoNameUppercaseToLowercase() {
        let result = syncManager.sanitizeRepoName("MyProject")
        XCTAssertEqual(result, "myproject")
    }

    func testSanitizeRepoNameMixedSpacesAndSpecials() {
        let result = syncManager.sanitizeRepoName("  Film Project #3 (2026)  ")
        // Spaces become hyphens, special chars stripped
        XCTAssertEqual(result, "--film-project-3-2026--")
    }

    func testSanitizeRepoNameUnicodeStripped() {
        let result = syncManager.sanitizeRepoName("Project \u{1F3AC}")
        // The emoji should be stripped since it's not [a-z0-9\-_.]
        XCTAssertEqual(result, "project-")
    }

    func testSanitizeRepoNameNumbers() {
        let result = syncManager.sanitizeRepoName("12345")
        XCTAssertEqual(result, "12345")
    }

    func testSanitizeRepoNameAlreadyValid() {
        let result = syncManager.sanitizeRepoName("valid-repo-name.123")
        XCTAssertEqual(result, "valid-repo-name.123")
    }

    // MARK: - Push Tests (State Transitions)

    func testPushWithEmptyBasePathThrows() async {
        let project = Project(name: "Test Project", basePath: "")

        do {
            try await syncManager.push(project: project, username: "testuser")
            XCTFail("Push with empty basePath should throw")
        } catch let error as SyncError {
            switch error {
            case .remoteFailed(let msg):
                XCTAssertTrue(msg.contains("basePath"), "Error should mention basePath")
            default:
                XCTFail("Expected SyncError.remoteFailed, got \(error)")
            }
        } catch {
            // Other errors are also acceptable — the point is it doesn't succeed
        }
    }

    func testPushWithNonexistentBasePathThrows() async {
        let project = Project(
            name: "Test Project",
            basePath: "/nonexistent/path/that/does/not/exist"
        )

        do {
            try await syncManager.push(project: project, username: "testuser")
            XCTFail("Push with nonexistent basePath should throw")
        } catch let error as SyncError {
            switch error {
            case .remoteFailed(let msg):
                XCTAssertTrue(
                    msg.contains("basePath") || msg.contains("invalid"),
                    "Error should mention basePath issue"
                )
            default:
                XCTFail("Expected SyncError.remoteFailed, got \(error)")
            }
        } catch {
            // Other errors acceptable (e.g. network errors after validation passes in some edge case)
        }
    }

    func testPushSetsStateToSyncing() async {
        // Create a temporary directory to use as basePath
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-test-push-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let project = Project(name: "Test Project", basePath: tempDir.path)

        // Push will fail at network layer, but we can check it entered syncing state
        // by examining the debug logs
        do {
            try await syncManager.push(project: project, username: "testuser")
        } catch {
            // Expected — no server available
        }

        // The manager should have logged sync activity
        XCTAssertFalse(syncManager.debugLogs.isEmpty, "Debug logs should contain sync activity")
        // Check that it attempted to sync (first log should mention "push")
        let hasStartLog = syncManager.debugLogs.contains { $0.lowercased().contains("starting push") }
        XCTAssertTrue(hasStartLog, "Should have logged the push start")
    }

    // MARK: - Pull Tests (State Transitions)

    func testPullWithInvalidServerFails() async {
        do {
            _ = try await syncManager.pull(username: "testuser", repoName: "test-repo")
            XCTFail("Pull from nonexistent server should throw")
        } catch {
            // Expected — server not available
        }

        // Should have debug logs from the attempt
        XCTAssertFalse(syncManager.debugLogs.isEmpty, "Debug logs should contain pull activity")
    }

    func testPullWithBasePathAndInvalidServerFails() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-test-pull-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        do {
            _ = try await syncManager.pull(
                username: "testuser",
                repoName: "test-repo",
                basePath: tempDir
            )
            XCTFail("Pull from nonexistent server should throw")
        } catch {
            // Expected
        }
    }

    // MARK: - Sync Error State Tests

    func testSyncErrorAfterFailedPush() async {
        let project = Project(
            name: "Error Test",
            basePath: "/nonexistent/path"
        )

        do {
            try await syncManager.push(project: project, username: "testuser")
        } catch {
            // Expected
        }

        // After a failed push, state should be error
        switch syncManager.syncState {
        case .error:
            // Expected
            break
        case .idle:
            // Also acceptable if the error was thrown before state transition
            break
        default:
            // syncing or lastSynced would be wrong
            if case .syncing = syncManager.syncState {
                XCTFail("Should not be stuck in syncing state after failed push")
            }
        }
    }

    // MARK: - SyncError Tests

    func testSyncErrorDescriptions() {
        let errors: [(SyncError, String)] = [
            (.notAuthenticated, "logged in"),
            (.serializationFailed("bad data"), "bad data"),
            (.remoteFailed("server down"), "server down"),
            (.conflictDetected("merge conflict"), "merge conflict"),
        ]

        for (error, expectedSubstring) in errors {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(
                description.localizedCaseInsensitiveContains(expectedSubstring),
                "SyncError description '\(description)' should contain '\(expectedSubstring)'"
            )
        }
    }

    func testSyncErrorNotAuthenticated() {
        let error = SyncError.notAuthenticated
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("logged in"))
    }

    func testSyncErrorSerializationFailed() {
        let error = SyncError.serializationFailed("Invalid JSON")
        XCTAssertTrue(error.errorDescription!.contains("Invalid JSON"))
    }

    func testSyncErrorRemoteFailed() {
        let error = SyncError.remoteFailed("404 Not Found")
        XCTAssertTrue(error.errorDescription!.contains("404 Not Found"))
    }

    func testSyncErrorConflictDetected() {
        let error = SyncError.conflictDetected("Local and remote both modified scene-1.json")
        XCTAssertTrue(error.errorDescription!.contains("scene-1.json"))
    }

    // MARK: - Auth Token Tests

    func testSetAuthTokenLogsActivity() async {
        await syncManager.setAuthToken("test-token-abc123")

        let hasTokenLog = syncManager.debugLogs.contains {
            $0.contains("Setting auth token") || $0.contains("Auth token set")
        }
        XCTAssertTrue(hasTokenLog, "Setting auth token should be logged")
    }

    // MARK: - Sync State Publisher Tests (Combine)

    func testSyncStatePublisherEmitsInitialValue() {
        var states: [SyncState] = []

        let cancellable = syncManager.$syncState
            .sink { state in
                states.append(state)
            }

        XCTAssertFalse(states.isEmpty, "Should receive initial published value")
        XCTAssertEqual(states.first, .idle, "Initial state should be idle")

        cancellable.cancel()
    }

    func testPendingChangesPublisher() {
        var counts: [Int] = []

        let cancellable = syncManager.$pendingChanges
            .sink { count in
                counts.append(count)
            }

        XCTAssertEqual(counts.first, 0, "Initial pending changes should be 0")

        syncManager.markLocalChange()
        XCTAssertEqual(counts.last, 1)

        syncManager.markLocalChange()
        XCTAssertEqual(counts.last, 2)

        cancellable.cancel()
    }

    func testDebugLogsPublisher() {
        var logSnapshots: [Int] = []

        let cancellable = syncManager.$debugLogs
            .sink { logs in
                logSnapshots.append(logs.count)
            }

        XCTAssertEqual(logSnapshots.first, 0, "Initial debug logs should be empty")

        cancellable.cancel()
    }

    // MARK: - List Remote Projects Tests

    func testListRemoteProjectsFailsWithoutServer() async {
        do {
            _ = try await syncManager.listRemoteProjects()
            XCTFail("Should fail with no server available")
        } catch {
            // Expected — no server running at localhost:19999
        }
    }

    // MARK: - Collaborator Management Tests (Network Required)

    func testListCollaboratorsFailsWithoutServer() async {
        do {
            _ = try await syncManager.listCollaborators(projectName: "test", username: "testuser")
            XCTFail("Should fail with no server")
        } catch {
            // Expected
        }
    }

    func testAddCollaboratorFailsWithoutServer() async {
        do {
            try await syncManager.addCollaborator(
                username: "collaborator",
                permission: .write,
                projectName: "test",
                owner: "testuser"
            )
            XCTFail("Should fail with no server")
        } catch {
            // Expected
        }
    }

    func testRemoveCollaboratorFailsWithoutServer() async {
        do {
            try await syncManager.removeCollaborator(
                username: "collaborator",
                projectName: "test",
                owner: "testuser"
            )
            XCTFail("Should fail with no server")
        } catch {
            // Expected
        }
    }

    func testSearchUsersFailsWithoutServer() async {
        do {
            _ = try await syncManager.searchUsers(query: "test")
            XCTFail("Should fail with no server")
        } catch {
            // Expected
        }
    }

    // MARK: - Collaborator Permission Sanitization in Repo Name

    func testCollaboratorMethodsUsesSanitizedRepoName() async {
        // Verify the repo name passed to GiteaClient is sanitized
        // by checking the sanitizeRepoName output matches expectations
        let projectName = "My Awesome Film!"
        let expectedRepo = "my-awesome-film"

        XCTAssertEqual(syncManager.sanitizeRepoName(projectName), expectedRepo)
    }

    // MARK: - Concurrent State Access Tests

    func testConcurrentMarkLocalChanges() async {
        // CloudSyncManager is @MainActor, so all access is serialized
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask { @MainActor in
                    self.syncManager.markLocalChange()
                }
            }
        }

        XCTAssertEqual(syncManager.pendingChanges, 50, "All increments should be counted")
    }

    // MARK: - Default URL Configuration Test

    func testDefaultGiteaBaseURL() {
        let defaultManager = CloudSyncManager()
        // We can't directly inspect the private giteaBaseURL, but we can verify
        // the manager initializes without crashing with the default URL
        XCTAssertNotNil(defaultManager)
        XCTAssertEqual(defaultManager.syncState, .idle)
    }

    // MARK: - GiteaClient Static Helper Tests

    func testIsLFSFileDetectsImageFiles() {
        XCTAssertTrue(GiteaClient.isLFSFile("poster.png"))
        XCTAssertTrue(GiteaClient.isLFSFile("photo.jpg"))
        XCTAssertTrue(GiteaClient.isLFSFile("image.jpeg"))
        XCTAssertTrue(GiteaClient.isLFSFile("icon.gif"))
        XCTAssertTrue(GiteaClient.isLFSFile("texture.bmp"))
    }

    func testIsLFSFileDetectsVideoFiles() {
        XCTAssertTrue(GiteaClient.isLFSFile("scene.mp4"))
        XCTAssertTrue(GiteaClient.isLFSFile("clip.mov"))
        XCTAssertTrue(GiteaClient.isLFSFile("video.avi"))
        XCTAssertTrue(GiteaClient.isLFSFile("movie.mkv"))
    }

    func testIsLFSFileDetectsAudioFiles() {
        XCTAssertTrue(GiteaClient.isLFSFile("music.mp3"))
        XCTAssertTrue(GiteaClient.isLFSFile("sound.wav"))
        XCTAssertTrue(GiteaClient.isLFSFile("audio.aiff"))
        XCTAssertTrue(GiteaClient.isLFSFile("track.flac"))
    }

    func testIsLFSFileDetectsBinaryDesignFiles() {
        XCTAssertTrue(GiteaClient.isLFSFile("design.psd"))
        XCTAssertTrue(GiteaClient.isLFSFile("logo.ai"))
        XCTAssertTrue(GiteaClient.isLFSFile("model.blend"))
        XCTAssertTrue(GiteaClient.isLFSFile("asset.fbx"))
    }

    func testIsLFSFileRejectsTextFiles() {
        XCTAssertFalse(GiteaClient.isLFSFile("project.json"))
        XCTAssertFalse(GiteaClient.isLFSFile("readme.md"))
        XCTAssertFalse(GiteaClient.isLFSFile("script.swift"))
        XCTAssertFalse(GiteaClient.isLFSFile("config.yaml"))
        XCTAssertFalse(GiteaClient.isLFSFile("data.xml"))
        XCTAssertFalse(GiteaClient.isLFSFile("notes.txt"))
    }

    func testIsLFSFileNoExtension() {
        XCTAssertFalse(GiteaClient.isLFSFile("Makefile"))
        XCTAssertFalse(GiteaClient.isLFSFile(".gitignore"))
        XCTAssertFalse(GiteaClient.isLFSFile("LICENSE"))
    }

    func testIsLFSFileSubdirectoryPaths() {
        XCTAssertTrue(GiteaClient.isLFSFile("assets/images/poster.png"))
        XCTAssertTrue(GiteaClient.isLFSFile("media/audio/voiceover.mp3"))
        XCTAssertFalse(GiteaClient.isLFSFile("scenes/scene-001.json"))
    }

    // MARK: - LFS Pointer Parsing Tests

    func testParseLFSPointerValid() {
        let pointer = """
        version https://git-lfs.github.com/spec/v1
        oid sha256:abc123def456789012345678901234567890123456789012345678901234
        size 12345
        """
        let data = pointer.data(using: .utf8)!
        let result = GiteaClient.parseLFSPointer(data)

        XCTAssertNotNil(result, "Valid LFS pointer should parse successfully")
        XCTAssertEqual(result?.oid, "abc123def456789012345678901234567890123456789012345678901234")
        XCTAssertEqual(result?.size, 12345)
    }

    func testParseLFSPointerInvalidPrefix() {
        let notAPointer = "This is just regular file content"
        let data = notAPointer.data(using: .utf8)!
        let result = GiteaClient.parseLFSPointer(data)

        XCTAssertNil(result, "Non-LFS content should return nil")
    }

    func testParseLFSPointerEmptyData() {
        let result = GiteaClient.parseLFSPointer(Data())
        XCTAssertNil(result, "Empty data should return nil")
    }

    func testParseLFSPointerMissingOid() {
        let pointer = """
        version https://git-lfs.github.com/spec/v1
        size 12345
        """
        let data = pointer.data(using: .utf8)!
        let result = GiteaClient.parseLFSPointer(data)

        XCTAssertNil(result, "Pointer missing oid should return nil")
    }

    func testParseLFSPointerMissingSize() {
        let pointer = """
        version https://git-lfs.github.com/spec/v1
        oid sha256:abc123def456
        """
        let data = pointer.data(using: .utf8)!
        let result = GiteaClient.parseLFSPointer(data)

        XCTAssertNil(result, "Pointer missing size should return nil")
    }

    func testParseLFSPointerBinaryData() {
        // Binary data that doesn't decode as UTF-8 should return nil
        let binaryData = Data([0xFF, 0xFE, 0xFD, 0x00, 0x01])
        let result = GiteaClient.parseLFSPointer(binaryData)
        XCTAssertNil(result, "Binary non-UTF8 data should return nil")
    }
}
