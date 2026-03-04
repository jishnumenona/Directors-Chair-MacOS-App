// DirectorsChairServices/Sources/DirectorsChairServices/Sync/CloudSyncManager.swift
//
// Manages cloud sync of projects to/from Gitea repositories via REST API

import Foundation
import DirectorsChairCore

// MARK: - Sync State

/// Current state of a sync operation.
public enum SyncState: Equatable {
    case idle
    case syncing(progress: Double, message: String)
    case error(String)
    case lastSynced(Date)
}

// MARK: - Sync Error

public enum SyncError: LocalizedError {
    case notAuthenticated
    case serializationFailed(String)
    case remoteFailed(String)
    case conflictDetected(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be logged in to sync."
        case .serializationFailed(let msg): return "Serialization failed: \(msg)"
        case .remoteFailed(let msg): return "Remote operation failed: \(msg)"
        case .conflictDetected(let msg): return "Sync conflict: \(msg)"
        }
    }
}

// MARK: - Cloud Sync Manager

/// Manages push/pull of DirectorsChair projects to Gitea repos via the Contents API.
///
/// Uses `GitSerializer` to serialize projects to a temp directory, then pushes
/// individual files via the Gitea REST API (no local git required).
@MainActor
public class CloudSyncManager: ObservableObject {

    // MARK: - Published State

    @Published public var syncState: SyncState = .idle
    @Published public var pendingChanges: Int = 0
    @Published public var debugLogs: [String] = []

    // MARK: - Dependencies

    private let giteaClient: GiteaClient
    private let serializer = GitSerializer()

    // MARK: - Configuration

    private let giteaBaseURL: String

    // MARK: - Initialization

    public init(giteaBaseURL: String = "http://localhost:3000") {
        self.giteaBaseURL = giteaBaseURL
        self.giteaClient = GiteaClient(
            baseURL: URL(string: giteaBaseURL)!,
            timeout: 30
        )
    }

    /// Set the auth token (call after login).
    public func setAuthToken(_ token: String) async {
        log("Setting auth token (\(token.prefix(8))...)")
        await giteaClient.setToken(token)
        log("Auth token set on GiteaClient")
    }

    // MARK: - Debug Logging

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        debugLogs.append(entry)
        print("CloudSync: \(entry)")
    }

    // MARK: - Increment Pending Changes

    /// Call after each local save to track unsaved-to-cloud changes.
    public func markLocalChange() {
        pendingChanges += 1
    }

    // MARK: - Push (Local → Cloud)

    /// Push a project to the user's Gitea repository.
    ///
    /// 1. Ensures a private repo exists for the project
    /// 2. Serializes the project to a temp directory
    /// 3. Diffs against remote tree
    /// 4. Creates/updates/deletes files as needed
    public func push(project: Project, username: String) async throws {
        debugLogs = []
        syncState = .syncing(progress: 0, message: "Preparing sync...")
        log("Starting push for project '\(project.name)' as user '\(username)'")

        let repoName = sanitizeRepoName(project.name)
        log("Sanitized repo name: '\(repoName)'")

        // 1. Ensure remote repo exists
        syncState = .syncing(progress: 0.1, message: "Checking remote repository...")
        log("Checking if repo '\(username)/\(repoName)' exists...")
        let repoExists = await ensureRemoteRepo(owner: username, name: repoName)
        guard repoExists else {
            log("FAILED: Could not create or find remote repository")
            syncState = .error("Failed to create or find remote repository")
            throw SyncError.remoteFailed("Failed to create or find remote repository")
        }
        log("Repo confirmed: '\(username)/\(repoName)'")

        // 2. Serialize project to temp directory
        syncState = .syncing(progress: 0.2, message: "Serializing project...")
        log("Serializing project to temp directory...")
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("directorschair-sync-\(UUID().uuidString)")

        do {
            _ = try await serializer.serializeProject(project, to: tempDir)
            log("Serialization complete: \(tempDir.path)")
        } catch {
            log("FAILED serialization: \(error.localizedDescription)")
            syncState = .error("Serialization failed: \(error.localizedDescription)")
            throw SyncError.serializationFailed(error.localizedDescription)
        }

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // 3. Collect local files
        syncState = .syncing(progress: 0.3, message: "Scanning local files...")
        let localFiles = collectLocalFiles(at: tempDir)
        log("Found \(localFiles.count) local files to sync")

        // 4. Get remote tree for SHAs
        syncState = .syncing(progress: 0.4, message: "Fetching remote tree...")
        log("Fetching remote tree...")
        var remoteSHAs: [String: String] = [:]
        do {
            let tree = try await giteaClient.getTree(owner: username, repo: repoName)
            for entry in tree where entry.type == "blob" {
                remoteSHAs[entry.path] = entry.sha
            }
            log("Remote tree: \(remoteSHAs.count) existing files")
        } catch {
            log("Remote tree fetch failed (empty repo?): \(error.localizedDescription)")
        }

        // 5. Push files
        let total = localFiles.count
        log("Uploading \(total) files...")
        for (index, (relativePath, fileURL)) in localFiles.enumerated() {
            let progress = 0.5 + (Double(index) / Double(max(total, 1))) * 0.4
            syncState = .syncing(progress: progress, message: "Uploading \(relativePath)...")

            guard let content = try? Data(contentsOf: fileURL) else {
                log("SKIP: Could not read \(relativePath)")
                continue
            }

            let commitMessage = "Sync from DirectorsChair Desktop"

            do {
                if let existingSHA = remoteSHAs[relativePath] {
                    try await giteaClient.updateFile(
                        owner: username,
                        repo: repoName,
                        path: relativePath,
                        content: content,
                        sha: existingSHA,
                        message: commitMessage
                    )
                    log("Updated: \(relativePath)")
                } else {
                    try await giteaClient.createFile(
                        owner: username,
                        repo: repoName,
                        path: relativePath,
                        content: content,
                        message: commitMessage
                    )
                    log("Created: \(relativePath)")
                }
            } catch {
                log("FAILED upload \(relativePath): \(error)")
            }
        }

        // 6. Delete remote files that no longer exist locally
        syncState = .syncing(progress: 0.9, message: "Cleaning up removed files...")
        let localPaths = Set(localFiles.map { $0.0 })
        for (remotePath, sha) in remoteSHAs {
            if !localPaths.contains(remotePath) {
                try? await giteaClient.deleteFile(
                    owner: username,
                    repo: repoName,
                    path: remotePath,
                    sha: sha,
                    message: "Remove \(remotePath)"
                )
            }
        }

        pendingChanges = 0
        let now = Date()
        syncState = .lastSynced(now)
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastSyncTime_\(repoName)")
    }

    // MARK: - Pull (Cloud → Local)

    /// Pull a project from the user's Gitea repository.
    ///
    /// 1. Gets the remote tree
    /// 2. Downloads all files to a temp directory
    /// 3. Deserializes into a Project
    public func pull(username: String, repoName: String) async throws -> Project {
        syncState = .syncing(progress: 0, message: "Fetching remote tree...")

        // 1. Get tree
        let tree = try await giteaClient.getTree(owner: username, repo: repoName)
        let blobs = tree.filter { $0.type == "blob" }

        // 2. Download all files
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("directorschair-pull-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let total = blobs.count
        for (index, blob) in blobs.enumerated() {
            let progress = 0.1 + (Double(index) / Double(max(total, 1))) * 0.7
            syncState = .syncing(progress: progress, message: "Downloading \(blob.path)...")

            let data = try await giteaClient.getRawFile(
                owner: username,
                repo: repoName,
                path: blob.path
            )

            let localPath = tempDir.appendingPathComponent(blob.path)
            try FileManager.default.createDirectory(
                at: localPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: localPath)
        }

        // 3. Deserialize
        syncState = .syncing(progress: 0.9, message: "Loading project...")
        let project = try await serializer.deserializeProject(from: tempDir)

        syncState = .lastSynced(Date())
        return project
    }

    // MARK: - Helpers

    /// Ensure a private repository exists for the project.
    private func ensureRemoteRepo(owner: String, name: String) async -> Bool {
        log("getRepository(\(owner)/\(name))...")
        do {
            let repo = try await giteaClient.getRepository(owner: owner, name: name)
            log("Repo exists: \(repo.name)")
            return true
        } catch {
            log("Repo not found: \(error.localizedDescription). Creating...")
            do {
                let repo = try await giteaClient.createRepository(
                    name: name,
                    description: "DirectorsChair project",
                    isPrivate: true
                )
                log("Repo created: \(repo.name)")
                return true
            } catch {
                log("FAILED to create repo: \(error)")
                return false
            }
        }
    }

    /// Collect all files in a directory recursively, returning (relativePath, fileURL).
    private func collectLocalFiles(at directory: URL) -> [(String, URL)] {
        var files: [(String, URL)] = []
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                continue
            }
            let relativePath = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")
            files.append((relativePath, fileURL))
        }

        return files
    }

    /// Convert a project name into a valid repository name.
    private func sanitizeRepoName(_ name: String) -> String {
        let sanitized = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9\\-_.]", with: "", options: .regularExpression)

        return sanitized.isEmpty ? "untitled-project" : sanitized
    }
}
