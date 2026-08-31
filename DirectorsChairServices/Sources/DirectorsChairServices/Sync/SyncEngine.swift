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

    @Published public private(set) var state: EngineState = .idle {
        // Progress only means something while a transfer runs; any terminal
        // or idle state clears it so the button falls back to its icon.
        didSet { if case .syncing = state {} else { progress = nil } }
    }
    @Published public private(set) var pendingChanges: Int = 0
    /// Byte-weighted transfer progress (0…1) while a push uploads or a pull
    /// downloads blobs; nil during quick phases (prepare, lookup, commit
    /// bookkeeping) and outside syncs. The toolbar renders it as a percent.
    @Published public private(set) var progress: Double?
    /// Remote context for the open project (Orgs §12B.7): the owning org's
    /// name and this user's role there. Served instantly from the checkpoint
    /// cache, refreshed from the server when the project opens.
    @Published public private(set) var orgName: String?
    @Published public private(set) var myRole: String?

    /// Viewer role = pull-only: the server would 404 our commits anyway
    /// (IDOR posture); the UI turns Sync into "get latest" instead.
    public var isViewer: Bool { myRole == "viewer" }

    private let client: SyncAPIClient
    private var pendingConflictManifest: SyncManifest?

    public init(client: SyncAPIClient) {
        self.client = client
    }

    public func markLocalChange() {
        pendingChanges += 1
    }

    // MARK: Remote context (Orgs §12B.7)

    /// Instant, offline: publish the org/role cached in the checkpoint.
    public func loadRemoteContext(projectDir: URL) {
        let checkpoint = SyncCheckpoint.load(projectDir: projectDir)
        orgName = checkpoint?.orgName
        myRole = checkpoint?.myRole
    }

    /// Ask the server who owns this project and what we may do, then cache
    /// it in the checkpoint. Best-effort — sync works without it.
    public func refreshRemoteContext(projectDir: URL) async {
        guard var checkpoint = SyncCheckpoint.load(projectDir: projectDir) else { return }
        do {
            let projects = try await client.listProjects()
            guard let remote = projects.first(where: { $0.id == checkpoint.projectID }),
                  let orgID = remote.orgID else { return }
            let orgs = try await client.listOrgs()
            let org = orgs.first { $0.id == orgID }
            let role = try await client.orgProjects(orgID: orgID)
                .first { $0.id == checkpoint.projectID }?.myRole
            checkpoint.orgName = org.map {
                $0.kind == "personal" ? "Personal" : $0.name
            }
            checkpoint.myRole = role
            try? checkpoint.save(projectDir: projectDir)
            orgName = checkpoint.orgName
            myRole = checkpoint.myRole
        } catch {
            // Offline or token trouble — keep whatever the cache said.
        }
    }

    // MARK: Cloud directory (Open from Cloud, Orgs §12B.7)

    /// One org and its projects, as the picker renders them.
    public struct CloudOrgListing: Sendable, Equatable, Identifiable {
        public let org: SyncOrg
        public let projects: [SyncProject]
        public var id: String { org.id }
    }

    /// Everything the signed-in user can see in the cloud, grouped by org.
    /// An org whose project list can't be fetched still appears (empty) —
    /// partial visibility beats a blank picker.
    public func cloudDirectory() async throws -> [CloudOrgListing] {
        let orgs = try await client.listOrgs()
        var listings: [CloudOrgListing] = []
        for org in orgs {
            let projects = (try? await client.orgProjects(orgID: org.id)) ?? []
            listings.append(CloudOrgListing(org: org, projects: projects))
        }
        // DC-0108: projects SHARED with me live in orgs I'm not a member of —
        // they appear only in the flat listing. Group them per owning org so
        // the invitee can download and open them like any cloud project.
        let mine = Set(orgs.map(\.id))
        let shared = ((try? await client.listProjects()) ?? [])
            .filter { project in
                guard let orgID = project.orgID else { return false }
                return !mine.contains(orgID) && project.archivedAt == nil
            }
        for (orgID, projects) in Dictionary(grouping: shared, by: { $0.orgID ?? "" })
            .sorted(by: { $0.key < $1.key }) where !orgID.isEmpty {
            let first = projects[0]
            let owner = SyncOrg(id: orgID,
                                slug: first.orgSlug ?? orgID,
                                name: "Shared with you — \(first.orgName ?? "another user")",
                                kind: "personal", myRole: nil)
            listings.append(CloudOrgListing(org: owner, projects: projects))
        }
        return listings
    }

    // MARK: Clone (Open from Cloud, Orgs §12B.7)

    /// Bootstrap a project that exists server-side but not on this device:
    /// create the directory, write a revision-0 checkpoint, pull. Returns
    /// the project directory, or nil with the failure in `state`.
    public func clone(projectID: String, name: String, orgName: String?,
                      myRole: String?, into parentDir: URL) async -> URL? {
        let sanitized = name.replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var dir = parentDir.appendingPathComponent(
            sanitized.isEmpty ? "Cloud Project" : sanitized)
        var suffix = 2
        while FileManager.default.fileExists(atPath: dir.path) {
            dir = parentDir.appendingPathComponent("\(sanitized) \(suffix)")
            suffix += 1
        }
        do {
            try FileManager.default.createDirectory(at: dir,
                                                    withIntermediateDirectories: true)
            try SyncCheckpoint(projectID: projectID, orgName: orgName,
                               myRole: myRole).save(projectDir: dir)
        } catch {
            state = .error(Self.describe(error))
            return nil
        }
        guard await pull(projectDir: dir) else {
            try? FileManager.default.removeItem(at: dir)
            return nil
        }
        self.orgName = orgName
        self.myRole = myRole
        return dir
    }

    // MARK: Push

    /// Push the project directory. Returns true when the server accepted a new
    /// revision (or everything was already up to date).
    /// Why the last overview push failed, if it did (sync itself stays
    /// green — the projection is best-effort).
    public private(set) var lastOverviewPushProblem: String?

    /// True when the last push replaced project.json on disk (a merge took
    /// the other device's document) — the caller must reload the editor
    /// even though a following pull finds nothing newer.
    public private(set) var projectChangedOnDisk = false

    /// Hashing every asset is CPU and disk work — never on the main actor
    /// (audit 2026-08-28: a few hundred MB of storyboard PNGs froze the UI
    /// for seconds per Sync click).
    nonisolated private static func buildManifest(projectDir: URL,
                                                  previous: SyncManifest?) async throws -> SyncManifest {
        try await Task.detached(priority: .userInitiated) {
            try SyncManifestBuilder.build(projectDir: projectDir, previous: previous)
        }.value
    }

    @discardableResult
    public func push(projectDir: URL, projectID: String, name: String) async -> Bool {
        state = .syncing("Preparing…")
        projectChangedOnDisk = false
        do {
            var syncState = SyncCheckpoint.load(projectDir: projectDir)
                ?? SyncCheckpoint(projectID: projectID)
            if syncState.lastRevision == 0 {
                _ = try await client.createProject(id: projectID, name: name)
            }
            let manifest = try await Self.buildManifest(projectDir: projectDir,
                                                        previous: syncState.lastManifest)
            if manifest == syncState.lastManifest, syncState.lastRevision > 0 {
                await pushOverview(projectDir: projectDir, projectID: projectID)
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
                await pushOverview(projectDir: projectDir, projectID: projectID)
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

    /// §12A projection: best-effort pitch-deck push after a successful
    /// sync. Never fails the sync — the portal simply keeps its empty
    /// state until a later push lands.
    private func pushOverview(projectDir: URL, projectID: String) async {
        do {
            let data = try Data(contentsOf:
                projectDir.appendingPathComponent("project.json"))
            let project = try Self.decodeProject(data)
            // Re-reads and hashes every referenced image — off the main actor.
            let deck = await Task.detached(priority: .utility) {
                ProjectOverviewBuilder.deck(project: project,
                                            projectDir: projectDir,
                                            projectID: projectID)
            }.value
            try await client.putOverview(projectID: projectID, deck: deck)
            lastOverviewPushProblem = nil
        } catch {
            // Best effort by design — but never invisible again: the
            // original silent catch hid an ISO-8601 decode failure that
            // suppressed every overview push.
            lastOverviewPushProblem = Self.describe(error)
        }
    }

    /// Decodes a persisted project the way ProjectPersistence wrote it —
    /// dates are ISO-8601 strings; a bare JSONDecoder throws on any
    /// project whose characters carry calibration/created dates.
    nonisolated static func decodeProject(_ data: Data) throws -> Project {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Project.self, from: data)
    }

    private func uploadMissing(projectDir: URL, projectID: String,
                               manifest: SyncManifest) async throws {
        let refs = SyncManifestBuilder.blobRefs(of: manifest)
        let missing = Set(try await client.missingBlobs(projectID: projectID, refs: refs))
        guard !missing.isEmpty else { return }
        // Dedupe by sha: identical files share one blob — uploading it twice
        // would waste bandwidth AND make byte progress overshoot its total.
        var seen: Set<String> = []
        let toUpload = refs.filter { missing.contains($0.sha256) && seen.insert($0.sha256).inserted }
        let totalBytes = max(1, toUpload.reduce(0) { $0 + $1.size })
        var sentBytes = 0
        var uploaded = 0
        progress = 0
        for ref in toUpload {
            uploaded += 1
            state = .syncing("Uploading \(uploaded)/\(toUpload.count)…")
            progress = Double(sentBytes) / Double(totalBytes)
            let data = try dataFor(sha256: ref.sha256, manifest: manifest,
                                   projectDir: projectDir)
            try await client.uploadBlob(projectID: projectID, sha256: ref.sha256,
                                        data: data)
            sentBytes += ref.size
            progress = Double(sentBytes) / Double(totalBytes)
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
        // Byte-identical documents on both sides are no conflict — a partial
        // pull or two quick Syncs can leave ours equal to the head.
        let sameProject = ourManifest.projectBlob == head.manifest.projectBlob
        if sameProject || !(theyChangedProject && weChangedProject) {
            state = .syncing("Merging…")
            // Bring the head onto THIS disk before merging. The union manifest
            // used to record the other device's files without downloading
            // them, so our next push tombstoned their assets and — when they
            // alone had changed project.json — committed our stale document
            // over theirs with no conflict raised (audit 2026-08-28).
            try await materialise(head: head.manifest, projectID: projectID,
                                  projectDir: projectDir, ours: ourManifest,
                                  base: syncState.lastManifest,
                                  takeTheirProject: theyChangedProject && !weChangedProject,
                                  sinceRevision: syncState.lastRevision)
            // Rebuild from what is actually on disk, against the head: the only
            // tombstones are deletions made here.
            let merged = try await Self.buildManifest(projectDir: projectDir,
                                                      previous: head.manifest)
            var refreshed = syncState
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
    /// Bring the head revision's content onto this disk without disturbing
    /// what changed here: their assets we don't have (ours win per path),
    /// their project.json only when they alone changed it, and their
    /// deletions of files we never touched. Files deleted here stay deleted;
    /// a path they deleted and later re-added is kept.
    private func materialise(head: SyncManifest, projectID: String, projectDir: URL,
                             ours: SyncManifest, base: SyncManifest?,
                             takeTheirProject: Bool, sinceRevision: Int) async throws {
        let onDisk = Dictionary(uniqueKeysWithValues: ours.assets.map { ($0.path, $0.sha256) })
        let inBase = Dictionary(uniqueKeysWithValues: (base?.assets ?? []).map { ($0.path, $0.sha256) })
        let deletedHere = Set(ours.deleted)
        let wanted = head.assets.filter { onDisk[$0.path] == nil && !deletedHere.contains($0.path) }
        var fetched = 0
        for asset in wanted {
            fetched += 1
            state = .syncing("Merging — downloading (\(fetched)/\(wanted.count))…")
            let data = try await client.downloadBlob(projectID: projectID, sha256: asset.sha256)
            try write(data: data, relativePath: asset.path, projectDir: projectDir)
        }
        if takeTheirProject {
            state = .syncing("Merging — downloading project…")
            let data = try await client.downloadBlob(projectID: projectID,
                                                     sha256: head.projectBlob.sha256)
            try write(data: data, relativePath: "project.json", projectDir: projectDir)
            projectChangedOnDisk = true
        }
        // Their deletions, from every revision since our base, apply to files
        // we did not touch — never to a path the head still carries.
        let inHead = Set(head.assets.map(\.path))
        let feed = try await client.revisions(projectID: projectID, since: sinceRevision)
        for revision in feed.revisions {
            for path in revision.manifest.deleted
            where !inHead.contains(path) && onDisk[path] != nil && onDisk[path] == inBase[path] {
                removeLocal(relativePath: path, projectDir: projectDir)
            }
        }
    }

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

            let projectChanged = target.manifest.projectBlob != syncState.lastManifest?.projectBlob
            let changedAssets = target.manifest.assets.filter { known[$0.path] != $0.sha256 }
            let totalBytes = max(1, (projectChanged ? target.manifest.projectBlob.size : 0)
                                 + changedAssets.reduce(0) { $0 + $1.size })
            var gotBytes = 0
            progress = 0

            // project.json first: the document is the source of truth.
            if projectChanged {
                state = .syncing("Downloading project…")
                let data = try await client.downloadBlob(projectID: syncState.projectID,
                                                         sha256: target.manifest.projectBlob.sha256)
                try write(data: data, relativePath: "project.json", projectDir: projectDir)
                gotBytes += target.manifest.projectBlob.size
                progress = Double(gotBytes) / Double(totalBytes)
            }
            var fetched = 0
            for asset in changedAssets {
                fetched += 1
                state = .syncing("Downloading assets (\(fetched)/\(changedAssets.count))…")
                let data = try await client.downloadBlob(projectID: syncState.projectID,
                                                         sha256: asset.sha256)
                try write(data: data, relativePath: asset.path, projectDir: projectDir)
                gotBytes += asset.size
                progress = Double(gotBytes) / Double(totalBytes)
            }
            // Tombstones from every revision we skipped over (no resurrection)
            // — except a path a later revision re-added, which was just
            // downloaded and must stay.
            let carried = Set(target.manifest.assets.map(\.path))
            for revision in feed.revisions {
                for path in revision.manifest.deleted where !carried.contains(path) {
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
            case .notFound:
                return "Not available with your current access — the project "
                     + "may have been removed or your role changed"
            case .archived:
                return "Project is archived — unarchive it in the web portal to sync"
            case .planLimit(_, let message):
                return message + " — delete a cloud project to free a slot, "
                     + "or upgrade to Creator (coming soon)"
            case .uncommittedBlobs: return "Upload incomplete — try again"
            case .server(let status): return "Sync failed (server \(status))"
            case .transport(let message): return "Network problem: \(message)"
            case .malformedResponse: return "Unexpected server response"
            }
        }
        return error.localizedDescription
    }
}
