// SyncManifestBuilder.swift
//
// Builds the wire manifest from a project directory on disk, applying the
// exclusion rules from Identity doc §8.3 (never sync backups, exports, footage,
// or dot-files), and derives tombstones by diffing against the last-synced
// manifest so deletions propagate instead of resurrecting on pull.

import CryptoKit
import Foundation

public enum SyncHashing {
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// Device-local sync bookkeeping, stored as `.sync-state.json` inside the
/// project directory (dot-file → excluded from manifests and from Gitea-era
/// collectors alike). Records what this device last saw from the server.
public struct SyncCheckpoint: Codable, Sendable, Equatable {
    public var projectID: String
    public var lastRevision: Int
    public var lastManifest: SyncManifest?

    public init(projectID: String, lastRevision: Int = 0, lastManifest: SyncManifest? = nil) {
        self.projectID = projectID
        self.lastRevision = lastRevision
        self.lastManifest = lastManifest
    }

    public static let filename = ".sync-state.json"

    public static func load(projectDir: URL) -> SyncCheckpoint? {
        let url = projectDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SyncCheckpoint.self, from: data)
    }

    public func save(projectDir: URL) throws {
        let url = projectDir.appendingPathComponent(Self.filename)
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }
}

public enum SyncManifestBuilder {
    /// Directories (top-level, relative) that never sync — device-local or
    /// deliberately excluded heavyweight content (Identity §8.3; footage is
    /// v1.1 scope). `assets` media DOES sync.
    public static let excludedDirectories: Set<String> = [
        ".backups", "exports", "footage",
    ]

    public static func isExcluded(relativePath: String) -> Bool {
        let components = relativePath.split(separator: "/").map(String.init)
        guard let first = components.first else { return true }
        // Any dot-file or dot-directory anywhere in the path is device-local
        // (.sync-state.json, .DS_Store, .backups/…).
        if components.contains(where: { $0.hasPrefix(".") }) { return true }
        return excludedDirectories.contains(first)
    }

    /// Walk the project directory and build the manifest. `previous` supplies
    /// tombstones: paths present in the last-synced manifest but gone locally.
    public static func build(projectDir: URL,
                             previous: SyncManifest?) throws -> SyncManifest {
        let fileManager = FileManager.default
        let projectJSONURL = projectDir.appendingPathComponent("project.json")
        let projectData = try Data(contentsOf: projectJSONURL)
        let projectBlob = SyncBlobRef(sha256: SyncHashing.sha256Hex(projectData),
                                      size: projectData.count)

        var assets: [SyncManifestAsset] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        if let enumerator = fileManager.enumerator(at: projectDir,
                                                   includingPropertiesForKeys: keys,
                                                   options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: Set(keys))
                // Symlinks are never followed or shipped (footage curation links).
                if values?.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                guard values?.isRegularFile == true else { continue }
                let relative = relativePath(of: fileURL, under: projectDir)
                guard !relative.isEmpty, relative != "project.json",
                      !isExcluded(relativePath: relative) else { continue }
                let data = try Data(contentsOf: fileURL)
                assets.append(SyncManifestAsset(path: relative,
                                                sha256: SyncHashing.sha256Hex(data),
                                                size: data.count))
            }
        }
        assets.sort { $0.path < $1.path }

        var deleted: [String] = []
        if let previous {
            let present = Set(assets.map(\.path))
            deleted = previous.assets.map(\.path)
                .filter { !present.contains($0) }
                .sorted()
        }
        return SyncManifest(projectBlob: projectBlob, assets: assets, deleted: deleted)
    }

    static func relativePath(of fileURL: URL, under directory: URL) -> String {
        let filePath = fileURL.standardizedFileURL.path
        let directoryPath = directory.standardizedFileURL.path
        guard filePath.hasPrefix(directoryPath + "/") else { return "" }
        return String(filePath.dropFirst(directoryPath.count + 1))
    }

    /// The blob refs a push must ensure exist server-side (project.json + assets).
    public static func blobRefs(of manifest: SyncManifest) -> [SyncBlobRef] {
        var refs = [manifest.projectBlob]
        refs.append(contentsOf: manifest.assets.map {
            SyncBlobRef(sha256: $0.sha256, size: $0.size)
        })
        return refs
    }
}
