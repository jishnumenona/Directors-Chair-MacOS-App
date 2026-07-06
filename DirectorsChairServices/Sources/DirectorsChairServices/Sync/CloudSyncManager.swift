// DirectorsChairServices/Sources/DirectorsChairServices/Sync/CloudSyncManager.swift
//
// Manages cloud sync of projects to/from Gitea repositories via REST API
// Uses direct mirror sync — the remote repo is a byte-for-byte copy of the local project folder.

import Foundation
import CryptoKit
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
/// Directly mirrors the local project folder — no serialization or transformation.
/// The remote repo contains the exact same files and directory structure as basePath.
@MainActor
public class CloudSyncManager: ObservableObject {

    // MARK: - Published State

    @Published public var syncState: SyncState = .idle
    @Published public var pendingChanges: Int = 0
    @Published public var debugLogs: [String] = []

    // MARK: - Dependencies

    private let giteaClient: GiteaClient

    // MARK: - Configuration

    private let giteaBaseURL: String

    // MARK: - LFS Extensions

    private static let lfsTrackedExtensions = [
        "*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp",
        "*.mp4", "*.mov", "*.avi", "*.mkv",
        "*.mp3", "*.wav", "*.aiff", "*.flac",
        "*.psd", "*.ai", "*.blend", "*.fbx",
        "*.pdf"
    ]

    // MARK: - Initialization

    /// - Parameter protocolClasses: URLProtocol stubs for the underlying client,
    ///   so the sync flow can be tested without a live server (WS4.5).
    public init(giteaBaseURL: String = ServiceEnvironment.giteaBaseURLString,
                protocolClasses: [AnyClass]? = nil) {
        self.giteaBaseURL = giteaBaseURL
        self.giteaClient = GiteaClient(
            baseURL: URL(string: giteaBaseURL) ?? ServiceEnvironment.giteaBaseURL,
            timeout: 30,
            protocolClasses: protocolClasses
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
        debugLog("CloudSync: \(entry)")
    }

    // MARK: - Increment Pending Changes

    /// Call after each local save to track unsaved-to-cloud changes.
    public func markLocalChange() {
        pendingChanges += 1
    }

    // MARK: - Push (Local → Cloud) — Direct Mirror

    /// Push a project to the user's Gitea repository.
    ///
    /// Directly mirrors the local project folder (basePath) to the remote repo.
    /// No serialization or transformation — the remote repo contains the exact
    /// same files and directory structure as the local project folder.
    ///
    /// 1. Ensures a private repo exists for the project
    /// 2. Walks basePath to collect ALL files (no serialization)
    /// 3. Generates .gitattributes virtually for LFS tracking
    /// 4. Diffs against remote tree via SHA comparison
    /// 5. Uploads: LFS for binaries, Contents API for text/JSON
    /// 6. Deletes remote files that no longer exist locally
    public func push(project: Project, username: String) async throws {
        debugLogs = []
        syncState = .syncing(progress: 0, message: "Preparing sync...")
        log("Starting push for project '\(project.name)' as user '\(username)'")

        let repoName = sanitizeRepoName(project.name)
        log("Sanitized repo name: '\(repoName)'")

        let basePath = URL(fileURLWithPath: project.basePath)
        log("Project basePath: \(basePath.path)")

        // Guard against empty or invalid basePath — would delete all remote files
        guard !project.basePath.isEmpty,
              FileManager.default.fileExists(atPath: basePath.path) else {
            log("FAILED: basePath is empty or does not exist: '\(project.basePath)'")
            syncState = .error("Project directory not found. Re-open the project and try again.")
            throw SyncError.remoteFailed("Project basePath is empty or invalid: '\(project.basePath)'")
        }

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

        // 2. Walk basePath directly to collect ALL project files
        syncState = .syncing(progress: 0.2, message: "Scanning project files...")
        log("Scanning project folder at \(basePath.path)...")
        var localFiles = collectProjectFiles(at: basePath)
        log("Found \(localFiles.count) project files")

        // 3. Generate .gitattributes content virtually and add to file list
        let gitattributesContent = generateGitAttributesContent()
        let gitattributesURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(".gitattributes-\(UUID().uuidString)")
        try gitattributesContent.write(to: gitattributesURL, atomically: true, encoding: .utf8)
        localFiles.append((".gitattributes", gitattributesURL))

        defer {
            try? FileManager.default.removeItem(at: gitattributesURL)
        }

        // 4. Get remote tree for SHA diffing
        syncState = .syncing(progress: 0.3, message: "Fetching remote tree...")
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

        // 5. Sort: .gitattributes first → regular text files → LFS binary files
        let sortedFiles = localFiles.sorted { a, b in
            let aIsGitattributes = a.0 == ".gitattributes"
            let bIsGitattributes = b.0 == ".gitattributes"
            let aIsLFS = GiteaClient.isLFSFile(a.0)
            let bIsLFS = GiteaClient.isLFSFile(b.0)

            if aIsGitattributes { return true }
            if bIsGitattributes { return false }
            if !aIsLFS && bIsLFS { return true }
            if aIsLFS && !bIsLFS { return false }
            return a.0 < b.0
        }

        // 6. Upload each file
        let total = sortedFiles.count
        let lfsCount = sortedFiles.filter { GiteaClient.isLFSFile($0.0) }.count
        log("Uploading \(total) files (\(lfsCount) via LFS, \(total - lfsCount) via Contents API)...")

        var failedPaths: [String] = []
        var abortedForAuth = false

        for (index, (relativePath, fileURL)) in sortedFiles.enumerated() {
            let progress = 0.4 + (Double(index) / Double(max(total, 1))) * 0.45
            syncState = .syncing(progress: progress, message: "Uploading \(relativePath)...")

            guard let content = try? Data(contentsOf: fileURL) else {
                log("FAILED: could not read \(relativePath)")
                failedPaths.append(relativePath)
                continue
            }

            // Skip files whose content already matches the remote, by git blob
            // SHA — previously every file was re-uploaded on every sync. Only for
            // non-LFS files: an LFS tree entry is its pointer's SHA, not content's.
            if !GiteaClient.isLFSFile(relativePath),
               let remoteSHA = remoteSHAs[relativePath],
               remoteSHA == Self.gitBlobSHA(content) {
                continue
            }

            let commitMessage = "Sync from DirectorsChair Desktop"

            do {
                if GiteaClient.isLFSFile(relativePath) {
                    // LFS path: upload binary via LFS, then push pointer via Contents API
                    log("LFS upload: \(relativePath) (\(content.count) bytes)")
                    let pointer = try await giteaClient.lfsUpload(
                        owner: username,
                        repo: repoName,
                        data: content
                    )
                    let pointerData = Data(pointer.utf8)

                    if let existingSHA = remoteSHAs[relativePath] {
                        try await giteaClient.updateFile(
                            owner: username,
                            repo: repoName,
                            path: relativePath,
                            content: pointerData,
                            sha: existingSHA,
                            message: commitMessage
                        )
                        log("LFS updated pointer: \(relativePath)")
                    } else {
                        try await giteaClient.createFile(
                            owner: username,
                            repo: repoName,
                            path: relativePath,
                            content: pointerData,
                            message: commitMessage
                        )
                        log("LFS created pointer: \(relativePath)")
                    }
                } else {
                    // Regular file: push via Contents API
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
                }
            } catch {
                log("FAILED upload \(relativePath): \(error)")
                failedPaths.append(relativePath)
                // An auth failure makes every remaining upload fail identically —
                // stop and report it rather than hammering the server.
                if Self.isAuthError(error) {
                    abortedForAuth = true
                    break
                }
            }
        }

        // 7. Log remote-only files (never auto-delete — sync is additive only)
        let localPaths = Set(localFiles.map { $0.0 })
        let remoteOnlyFiles = remoteSHAs.keys.filter { !localPaths.contains($0) }
        if !remoteOnlyFiles.isEmpty {
            log("Remote-only files (kept): \(remoteOnlyFiles.joined(separator: ", "))")
        }

        // Only report success when every file uploaded. Reporting .lastSynced
        // after swallowed failures is a silent data-loss illusion: the user
        // believes the project is safely in the cloud when it is not.
        guard failedPaths.isEmpty else {
            let detail = abortedForAuth
                ? "authentication failed — please sign in again"
                : "\(failedPaths.count) of \(total) file(s) failed to upload"
            syncState = .error("Sync incomplete: \(detail)")
            log("Push FAILED: \(detail); failed: \(failedPaths.joined(separator: ", "))")
            throw SyncError.remoteFailed(detail)
        }

        pendingChanges = 0
        let now = Date()
        syncState = .lastSynced(now)
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastSyncTime_\(repoName)")
        log("Push complete: \(total) files synced")
    }

    /// Git's blob object id for content: SHA-1 of "blob <bytes>\0" + content.
    /// Matches the sha in a Gitea tree entry, so identical files can be skipped.
    static func gitBlobSHA(_ data: Data) -> String {
        var hasher = Insecure.SHA1()
        hasher.update(data: Data("blob \(data.count)\u{0}".utf8))
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// True for errors that mean the credential is bad (401/403), as opposed to
    /// a transient per-file failure worth continuing past.
    private static func isAuthError(_ error: Error) -> Bool {
        switch error {
        case RemoteRepositoryError.authenticationFailed,
             RemoteRepositoryError.permissionDenied,
             RemoteRepositoryError.invalidCredentials:
            return true
        default:
            return false
        }
    }

    // MARK: - Pull (Cloud → Local) — Direct Download to basePath

    /// Pull a project from the user's Gitea repository directly into basePath.
    ///
    /// Downloads all remote files directly to the project's base directory,
    /// preserving the exact directory structure. Then reads project.json
    /// from basePath and decodes it into a Project object.
    ///
    /// - Parameters:
    ///   - username: The Gitea username (repo owner)
    ///   - repoName: The repository name
    ///   - basePath: The local project directory to download files into
    /// - Returns: The decoded Project object
    public func pull(username: String, repoName: String, basePath: URL) async throws -> Project {
        debugLogs = []
        syncState = .syncing(progress: 0, message: "Fetching remote tree...")
        log("Starting pull for '\(username)/\(repoName)' into \(basePath.path)")

        // 1. Get remote tree
        let tree = try await giteaClient.getTree(owner: username, repo: repoName)
        let blobs = tree.filter { $0.type == "blob" }
        log("Remote tree: \(blobs.count) files")

        // 2. Ensure basePath exists
        try FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true)

        // 3. Download each blob directly to basePath/{blob.path}
        let total = blobs.count
        var failedDownloads: [String] = []
        var abortedForAuth = false
        for (index, blob) in blobs.enumerated() {
            let progress = 0.1 + (Double(index) / Double(max(total, 1))) * 0.7
            syncState = .syncing(progress: progress, message: "Downloading \(blob.path)...")

            // Skip .gitattributes — not needed locally
            if blob.path == ".gitattributes" {
                log("Skip .gitattributes (not needed locally)")
                continue
            }

            do {
                var data = try await giteaClient.getRawFile(
                    owner: username,
                    repo: repoName,
                    path: blob.path
                )

                // Resolve LFS pointers: if the raw content is an LFS pointer,
                // download the actual binary via the LFS batch API
                if let lfsInfo = GiteaClient.parseLFSPointer(data) {
                    log("LFS resolve: \(blob.path) (oid \(lfsInfo.oid.prefix(12))..., \(lfsInfo.size) bytes)")
                    data = try await giteaClient.lfsDownload(
                        owner: username,
                        repo: repoName,
                        oid: lfsInfo.oid,
                        size: lfsInfo.size
                    )
                    log("LFS downloaded: \(blob.path) (\(data.count) bytes)")
                }

                let localPath = basePath.appendingPathComponent(blob.path)
                try FileManager.default.createDirectory(
                    at: localPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: localPath)
                log("Downloaded: \(blob.path) (\(data.count) bytes)")
            } catch {
                log("FAILED download \(blob.path): \(error)")
                failedDownloads.append(blob.path)
                if Self.isAuthError(error) {
                    abortedForAuth = true
                    break
                }
            }
        }

        // A partial pull leaves an incomplete local project — fail rather than
        // silently returning a project that is missing files.
        guard failedDownloads.isEmpty else {
            let detail = abortedForAuth
                ? "authentication failed — please sign in again"
                : "\(failedDownloads.count) of \(total) file(s) failed to download"
            syncState = .error("Sync incomplete: \(detail)")
            log("Pull FAILED: \(detail)")
            throw SyncError.remoteFailed(detail)
        }

        // 4. Read project.json from basePath and decode into Project
        syncState = .syncing(progress: 0.9, message: "Loading project...")
        let projectJsonURL = basePath.appendingPathComponent("project.json")

        guard FileManager.default.fileExists(atPath: projectJsonURL.path) else {
            log("FAILED: project.json not found at \(projectJsonURL.path)")
            throw SyncError.remoteFailed("project.json not found in remote repository")
        }

        let projectData = try Data(contentsOf: projectJsonURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var project = try decoder.decode(Project.self, from: projectData)

        // Ensure basePath is set to the download location
        project.basePath = basePath.path
        log("Project decoded: '\(project.name)'")

        syncState = .lastSynced(Date())
        log("Pull complete: \(total) files downloaded")
        return project
    }

    /// Legacy pull for backward compatibility (no basePath).
    /// Downloads to a temp directory and decodes project.json directly.
    public func pull(username: String, repoName: String) async throws -> Project {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("directorschair-pull-\(UUID().uuidString)")
        return try await pull(username: username, repoName: repoName, basePath: tempDir)
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

    /// Collect all files in the project folder recursively.
    ///
    /// Excludes: .DS_Store, .backups/ directory, hidden files (dot-prefixed).
    /// Returns (relativePath, fileURL) pairs.
    private func collectProjectFiles(at directory: URL) -> [(String, URL)] {
        var files: [(String, URL)] = []
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [] // Don't skip hidden — we handle exclusions manually
        ) else {
            return files
        }

        let directoryPath = directory.path.hasSuffix("/") ? directory.path : directory.path + "/"

        while let fileURL = enumerator.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent

            // Skip .DS_Store
            if fileName == ".DS_Store" {
                continue
            }

            // Skip .backups directory entirely
            if fileName == ".backups" {
                enumerator.skipDescendants()
                continue
            }

            // Skip other hidden files/directories (dot-prefixed)
            if fileName.hasPrefix(".") {
                if (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            // Only include regular files
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                continue
            }

            let relativePath = fileURL.path.replacingOccurrences(of: directoryPath, with: "")
            files.append((relativePath, fileURL))
        }

        return files
    }

    /// Generate .gitattributes content for LFS tracking.
    private func generateGitAttributesContent() -> String {
        var lines = ["# Git LFS tracking rules for DirectorsChair binary assets"]
        for ext in Self.lfsTrackedExtensions {
            lines.append("\(ext) filter=lfs diff=lfs merge=lfs -text")
        }
        lines.append("") // trailing newline
        return lines.joined(separator: "\n")
    }

    /// Convert a project name into a valid repository name.
    public func sanitizeRepoName(_ name: String) -> String {
        let sanitized = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9\\-_.]", with: "", options: .regularExpression)

        return sanitized.isEmpty ? "untitled-project" : sanitized
    }

    /// List all remote project repositories for the authenticated user (owned + shared).
    public func listRemoteProjects() async throws -> [RemoteRepository] {
        return try await giteaClient.listRepositories()
    }

    // MARK: - Collaborator Management

    /// List collaborators for a project repository.
    public func listCollaborators(projectName: String, username: String) async throws -> [RemoteUser] {
        let repoName = sanitizeRepoName(projectName)
        return try await giteaClient.listCollaborators(owner: username, repo: repoName)
    }

    /// Add a collaborator to a project repository.
    public func addCollaborator(
        username: String,
        permission: CollaboratorPermission,
        projectName: String,
        owner: String
    ) async throws {
        let repoName = sanitizeRepoName(projectName)
        try await giteaClient.addCollaborator(
            username: username,
            permission: permission,
            toRepo: owner,
            repoName
        )
    }

    /// Remove a collaborator from a project repository.
    public func removeCollaborator(username: String, projectName: String, owner: String) async throws {
        let repoName = sanitizeRepoName(projectName)
        try await giteaClient.removeCollaborator(
            username: username,
            fromRepo: owner,
            repoName
        )
    }

    /// Search for users by query string.
    public func searchUsers(query: String) async throws -> [RemoteUser] {
        return try await giteaClient.searchUsers(query: query)
    }
}
