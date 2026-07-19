// SyncEngine.swift
//
// SyncEngine v1 (Webapp architecture §5.4, W3): manifest-revision sync of a
// project directory against the first-party sync API. Optimistic concurrency —
// push carries the last-synced revision as its base; a 409 means another
// device moved the head, and the engine either auto-merges (asset-only
// divergence) or surfaces a keep-mine / use-theirs choice. Deletions travel as
// tombstones; local overwrites are backed up device-side before "use theirs".

import Foundation

@MainActor
public final class SyncEngine: ObservableObject {

    public struct Conflict: Equatable, Sendable {
        public let projectID: String
        public let baseRevision: Int
        public let headRevision: Int
    }

    public enum EngineState: Equatable {
        case idle
        case syncing(String)
        case conflict(Conflict)
        case error(String)
        case synced(Date)
    }

    @Published public private(set) var state: EngineState = .idle
    @Published public private(set) var pendingChanges: Int = 0

    private let client: SyncAPIClient
    private var pendingConflictManifest: SyncManifest?

    public init(client: SyncAPIClient) {
        self.client = client
    }

    public func markLocalChange() {
        pendingChanges += 1
    }

    // MARK: Push

    /// Push the project directory. Returns true when the server accepted a new
    /// revision (or everything was already up to date).
    @discardableResult
    public func push(projectDir: URL, projectID: String, name: String) async -> Bool {
        state = .syncing("Preparing…")
        do {
            var syncState = SyncCheckpoint.load(projectDir: projectDir)
                ?? SyncCheckpoint(projectID: projectID)
            if syncState.lastRevision == 0 {
                _ = try await client.createProject(id: projectID, name: name)
            }
            let manifest = try SyncManifestBuilder.build(projectDir: projectDir,
                                                         previous: syncState.lastManifest)
            if manifest == syncState.lastManifest, syncState.lastRevision > 0 {
                state = .synced(Date())
                pendingChanges = 0
                return true
            }
            try await uploadMissing(projectDir: projectDir, projectID: projectID,
                                    manifest: manifest)
            state = .syncing("Committing…")
            do {
                let result = try await client.commit(projectID: projectID,
                                                     baseRevision: syncState.lastRevision,
                                                     manifest: manifest)
                syncState.lastRevision = result.revision
                syncState.lastManifest = manifest
                try syncState.save(projectDir: projectDir)
                pendingChanges = 0
                state = .synced(Date())
                return true
            } catch SyncAPIError.staleBase(let head) {
                return try await resolveStaleBase(projectDir: projectDir,
                                                  projectID: projectID,
                                                  ourManifest: manifest,
                                                  syncState: syncState,
                                                  headRevision: head)
            }
        } catch {
            state = .error(Self.describe(error))
            return false
        }
    }

    private func uploadMissing(projectDir: URL, projectID: String,
                               manifest: SyncManifest) async throws {
        let refs = SyncManifestBuilder.blobRefs(of: manifest)
        let missing = Set(try await client.missingBlobs(projectID: projectID, refs: refs))
        guard !missing.isEmpty else { return }
        var uploaded = 0
        for ref in refs where missing.contains(ref.sha256) {
            uploaded += 1
            state = .syncing("Uploading \(uploaded)/\(missing.count)…")
            let data = try dataFor(sha256: ref.sha256, manifest: manifest,
                                   projectDir: projectDir)
            try await client.uploadBlob(projectID: projectID, sha256: ref.sha256,
                                        data: data)
        }
    }

    private func dataFor(sha256: String, manifest: SyncManifest,
                         projectDir: URL) throws -> Data {
        if manifest.projectBlob.sha256 == sha256 {
            return try Data(contentsOf: projectDir.appendingPathComponent("project.json"))
        }
        guard let asset = manifest.assets.first(where: { $0.sha256 == sha256 }) else {
            throw SyncAPIError.malformedResponse
        }
        return try Data(contentsOf: projectDir.appendingPathComponent(asset.path))
    }

    // MARK: Conflict handling (Webapp §5.4)

    private func resolveStaleBase(projectDir: URL, projectID: String,
                                  ourManifest: SyncManifest, syncState: SyncCheckpoint,
                                  headRevision: Int) async throws -> Bool {
        let head = try await client.revision(projectID: projectID, number: headRevision)
        // Asset-only divergence: the other device didn't touch project.json we
        // changed (or vice versa) → union merge, ours wins per-path, no UI.
        let baseProjectBlob = syncState.lastManifest?.projectBlob
        let theyChangedProject = head.manifest.projectBlob != baseProjectBlob
        let weChangedProject = ourManifest.projectBlob != baseProjectBlob
        if !(theyChangedProject && weChangedProject) {
            let merged = Self.unionMerge(ours: ourManifest, theirs: head.manifest,
                                         projectFromThem: theyChangedProject)
            var refreshed = syncState
            state = .syncing("Merging…")
            try await uploadMissing(projectDir: projectDir, projectID: projectID,
                                    manifest: merged)
            let result = try await client.commit(projectID: projectID,
                                                 baseRevision: headRevision,
                                                 manifest: merged,
                                                 mergedFrom: syncState.lastRevision)
            refreshed.lastRevision = result.revision
            refreshed.lastManifest = merged
            try refreshed.save(projectDir: projectDir)
            pendingChanges = 0
            state = .synced(Date())
            return true
        }
        // True overlap on project.json → the human decides. Both versions
        // survive regardless: theirs is the head revision, ours is local (and
        // becomes a revision if they pick "keep mine").
        pendingConflictManifest = ourManifest
        state = .conflict(Conflict(projectID: projectID,
                                   baseRevision: syncState.lastRevision,
                                   headRevision: headRevision))
        return false
    }

    /// Merge for asset-only divergence: assets union (ours wins on path
    /// collisions), tombstones union, project blob from whichever side
    /// actually changed it.
    static func unionMerge(ours: SyncManifest, theirs: SyncManifest,
                           projectFromThem: Bool) -> SyncManifest {
        var byPath: [String: SyncManifestAsset] = [:]
        for asset in theirs.assets { byPath[asset.path] = asset }
        for asset in ours.assets { byPath[asset.path] = asset }
        let deleted = Set(ours.deleted).union(theirs.deleted)
            .filter { byPath[$0] == nil }
        return SyncManifest(projectBlob: projectFromThem ? theirs.projectBlob
                                                         : ours.projectBlob,
                            assets: byPath.values.sorted { $0.path < $1.path },
                            deleted: deleted.sorted())
    }

    /// "Keep mine": recommit our version on top of the head. Theirs survives
    /// as the previous revision (restorable server-side).
    public func resolveKeepMine(projectDir: URL) async {
        guard case .conflict(let conflict) = state,
              let manifest = pendingConflictManifest else { return }
        state = .syncing("Committing yours…")
        do {
            let result = try await client.commit(projectID: conflict.projectID,
                                                 baseRevision: conflict.headRevision,
                                                 manifest: manifest,
                                                 mergedFrom: conflict.baseRevision)
            var syncState = SyncCheckpoint.load(projectDir: projectDir)
                ?? SyncCheckpoint(projectID: conflict.projectID)
            syncState.lastRevision = result.revision
            syncState.lastManifest = manifest
            try syncState.save(projectDir: projectDir)
            pendingConflictManifest = nil
            pendingChanges = 0
            state = .synced(Date())
        } catch {
            state = .error(Self.describe(error))
        }
    }

    /// "Use theirs": back up the local project.json device-side, then apply
    /// the head revision to disk.
    public func resolveUseTheirs(projectDir: URL) async {
        guard case .conflict = state else { return }
        pendingConflictManifest = nil
        backUpLocalProjectJSON(projectDir: projectDir)
        await pull(projectDir: projectDir)
    }

    // MARK: Pull

    /// Apply the newest server revision to disk. The CALLER must quiesce the
    /// editor first (flush pending saves, reload the project afterwards).
    /// Returns true when new content was applied.
    @discardableResult
    public func pull(projectDir: URL) async -> Bool {
        guard var syncState = SyncCheckpoint.load(projectDir: projectDir) else {
            state = .error("Project has never been synced from this device")
            return false
        }
        state = .syncing("Checking for changes…")
        do {
            let feed = try await client.revisions(projectID: syncState.projectID,
                                                  since: syncState.lastRevision)
            guard let target = feed.revisions.last else {
                state = .synced(Date())
                return false
            }
            let known: [String: String] = Dictionary(
                uniqueKeysWithValues: (syncState.lastManifest?.assets ?? [])
                    .map { ($0.path, $0.sha256) })

            // project.json first: the document is the source of truth.
            if target.manifest.projectBlob != syncState.lastManifest?.projectBlob {
                state = .syncing("Downloading project…")
                let data = try await client.downloadBlob(projectID: syncState.projectID,
                                                         sha256: target.manifest.projectBlob.sha256)
                try write(data: data, relativePath: "project.json", projectDir: projectDir)
            }
            var fetched = 0
            for asset in target.manifest.assets where known[asset.path] != asset.sha256 {
                fetched += 1
                state = .syncing("Downloading assets (\(fetched))…")
                let data = try await client.downloadBlob(projectID: syncState.projectID,
                                                         sha256: asset.sha256)
                try write(data: data, relativePath: asset.path, projectDir: projectDir)
            }
            // Tombstones from every revision we skipped over (no resurrection).
            for revision in feed.revisions {
                for path in revision.manifest.deleted {
                    removeLocal(relativePath: path, projectDir: projectDir)
                }
            }
            syncState.lastRevision = target.revision
            syncState.lastManifest = target.manifest
            try syncState.save(projectDir: projectDir)
            state = .synced(Date())
            return true
        } catch {
            state = .error(Self.describe(error))
            return false
        }
    }

    // MARK: Filesystem helpers

    private func write(data: Data, relativePath: String, projectDir: URL) throws {
        guard !SyncManifestBuilder.isExcluded(relativePath: relativePath)
                || relativePath == "project.json" else { return }
        let target = projectDir.appendingPathComponent(relativePath)
        guard target.standardizedFileURL.path
            .hasPrefix(projectDir.standardizedFileURL.path + "/") else { return }
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: target, options: .atomic)
    }

    private func removeLocal(relativePath: String, projectDir: URL) {
        guard !SyncManifestBuilder.isExcluded(relativePath: relativePath) else { return }
        let target = projectDir.appendingPathComponent(relativePath)
        let standardized = target.standardizedFileURL.path
        guard standardized.hasPrefix(projectDir.standardizedFileURL.path + "/") else { return }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: standardized, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            try? FileManager.default.removeItem(atPath: standardized)
        }
    }

    private func backUpLocalProjectJSON(projectDir: URL) {
        let source = projectDir.appendingPathComponent("project.json")
        guard let data = try? Data(contentsOf: source) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backups = projectDir.appendingPathComponent(".backups")
        try? FileManager.default.createDirectory(at: backups,
                                                 withIntermediateDirectories: true)
        try? data.write(to: backups.appendingPathComponent("project_pre-sync_\(stamp).json"))
    }

    private static func describe(_ error: Error) -> String {
        if let apiError = error as? SyncAPIError {
            switch apiError {
            case .notAuthenticated: return "Sign in to sync"
            case .serviceUnavailable: return "Sync service unavailable — try again shortly"
            case .payloadTooLarge: return "A file exceeds the sync size limit"
            case .staleBase: return "Sync conflict"
            case .notFound: return "Project not found on the server"
            case .uncommittedBlobs: return "Upload incomplete — try again"
            case .server(let status): return "Sync failed (server \(status))"
            case .transport(let message): return "Network problem: \(message)"
            case .malformedResponse: return "Unexpected server response"
            }
        }
        return error.localizedDescription
    }
}
