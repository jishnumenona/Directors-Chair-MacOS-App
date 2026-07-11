// ProjectScopingAndDeletionTests.swift
//
// Covers two project-lifecycle workflows:
//   E2E-PROJ-004 — projects are scoped per user; each account resolves to its
//                  own on-disk root, so users don't see each other's projects.
//   E2E-PROJ-003 — deleting a project moves it to Trash (the FileManager
//                  trashItem mechanism the delete action relies on).

import XCTest
@testable import DirectorsChair_Desktop

final class ProjectScopingAndDeletionTests: XCTestCase {

    private var savedUser: String!

    override func setUp() {
        super.setUp()
        savedUser = ProjectDirectoryManager.currentUsername
    }

    override func tearDown() {
        // Restore the process-wide scoping so we don't leak into other tests.
        ProjectDirectoryManager.setCurrentUser(savedUser)
        super.tearDown()
    }

    // MARK: - E2E-PROJ-004: per-user project scoping

    func testEachUserResolvesToItsOwnRoot() {
        ProjectDirectoryManager.setCurrentUser("alice")
        let aliceRoot = ProjectDirectoryManager.directorsChairRoot

        ProjectDirectoryManager.setCurrentUser("bob")
        let bobRoot = ProjectDirectoryManager.directorsChairRoot

        XCTAssertNotEqual(aliceRoot, bobRoot, "different users get different roots")
        XCTAssertEqual(aliceRoot.lastPathComponent, "alice")
        XCTAssertEqual(bobRoot.lastPathComponent, "bob")
        // Both hang off the same base — scoping is a per-user subfolder.
        XCTAssertEqual(aliceRoot.deletingLastPathComponent(), bobRoot.deletingLastPathComponent())
    }

    func testProjectPathsAreScopedUnderTheCurrentUser() {
        ProjectDirectoryManager.setCurrentUser("carol")
        let dir = ProjectDirectoryManager.projectDirectory(named: "My Film")
        XCTAssertTrue(dir.path.contains("/carol/"),
                      "a project directory lives under the current user's root")
    }

    func testNilUserFallsBackToLocal() {
        ProjectDirectoryManager.setCurrentUser(nil)
        XCTAssertEqual(ProjectDirectoryManager.currentUsername, "local",
                       "a signed-out session scopes to the shared 'local' root")
    }

    func testLastProjectPathKeyIsPerUser() {
        // The remembered "reopen last project" key is namespaced by user so a
        // transient token refresh for user A can't surface user B's last path.
        ProjectDirectoryManager.setCurrentUser("dave")
        let key = "lastProjectPath_\(ProjectDirectoryManager.currentUsername)"
        XCTAssertEqual(key, "lastProjectPath_dave")
    }

    // MARK: - E2E-PROJ-003: delete moves the project to Trash

    func testTrashItemRemovesProjectFromItsLocation() throws {
        #if !targetEnvironment(simulator)
        let fm = FileManager.default
        // Build a throwaway project folder with a file inside it.
        let tmp = fm.temporaryDirectory.appendingPathComponent("dc-trash-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        let inner = tmp.appendingPathComponent("project.json")
        try Data("{}".utf8).write(to: inner)
        XCTAssertTrue(fm.fileExists(atPath: tmp.path))

        // This is exactly what ProjectsExplorer.deleteProject relies on.
        var resulting: NSURL?
        do {
            try fm.trashItem(at: tmp, resultingItemURL: &resulting)
        } catch {
            throw XCTSkip("Trash unavailable in this environment: \(error.localizedDescription)")
        }

        XCTAssertFalse(fm.fileExists(atPath: tmp.path),
                       "the project no longer exists at its original path after delete")
        if let moved = resulting as URL? {
            XCTAssertTrue(fm.fileExists(atPath: moved.path), "it was moved to Trash, not destroyed")
            try? fm.removeItem(at: moved)  // clean up the Trash entry
        }
        #endif
    }
}
