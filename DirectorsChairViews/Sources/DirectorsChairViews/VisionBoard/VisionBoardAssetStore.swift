// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionBoardAssetStore.swift
//
// Vision Board repair, Slice 2: the no-orphan asset pipeline. Generated
// and pasted images are STAGED in a temp directory and only FINALIZED into
// the project's assets on Save — dismissing the editor (Cancel, Esc, close)
// leaves the project untouched and the OS reaps the staging dir. Browse
// imports copy external files in so projects stay self-contained; remote
// URLs are downloaded at save time. Deletion (Slice 4) is guarded to the
// vision-board asset folder and trashes rather than removes.

import Foundation

public struct VisionBoardAssetStore: @unchecked Sendable {
    public let projectBase: URL
    private let fileManager: FileManager
    /// Injected for tests; defaults to a real URLSession fetch.
    private let fetchData: @Sendable (URL) async throws -> Data

    private let stagingRoot: URL

    public static let assetSubfolder = "assets/visionboard"

    public init(projectBase: URL,
                fileManager: FileManager = .default,
                fetchData: @escaping @Sendable (URL) async throws -> Data = { url in
                    try await URLSession.shared.data(from: url).0
                }) {
        self.projectBase = projectBase
        self.fileManager = fileManager
        self.fetchData = fetchData
        self.stagingRoot = fileManager.temporaryDirectory
            .appendingPathComponent("dc-visionboard-staging-\(UUID().uuidString)",
                                    isDirectory: true)
    }

    // MARK: - Staging

    public func stagingDirectory() throws -> URL {
        try fileManager.createDirectory(at: stagingRoot,
                                        withIntermediateDirectories: true)
        return stagingRoot
    }

    /// Stages pasted image data (replaces the old OS-temp scatter).
    public func stagePastedPNG(_ data: Data) throws -> URL {
        let url = try stagingDirectory()
            .appendingPathComponent("pasted_\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    /// Stages arbitrary image data under a chosen file name (the generation
    /// executor uses this so the finalized name stays recognizable).
    public func stage(_ data: Data, fileName: String) throws -> URL {
        let url = try stagingDirectory().appendingPathComponent(fileName)
        try data.write(to: url)
        return url
    }

    public func isStaged(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(stagingRoot.standardizedFileURL.path)
    }

    public func discardStaging() {
        try? fileManager.removeItem(at: stagingRoot)
    }

    // MARK: - Finalizing into the project

    private func assetsDirectory() throws -> URL {
        let dir = projectBase.appendingPathComponent(Self.assetSubfolder,
                                                     isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Collision-safe destination for a file name inside the asset folder.
    private func destination(for fileName: String) throws -> URL {
        let dir = try assetsDirectory()
        var candidate = dir.appendingPathComponent(fileName)
        var counter = 1
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        while fileManager.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            candidate = dir.appendingPathComponent(name)
            counter += 1
        }
        return candidate
    }

    /// Moves a staged file into the project and returns its relative path.
    public func finalize(_ stagedURL: URL) throws -> String {
        let dest = try destination(for: stagedURL.lastPathComponent)
        try fileManager.moveItem(at: stagedURL, to: dest)
        return "\(Self.assetSubfolder)/\(dest.lastPathComponent)"
    }

    /// Copies an external file (Browse…) into the project; returns the
    /// relative path. Projects stay self-contained.
    public func importExternal(_ url: URL) throws -> String {
        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
        let dest = try destination(for: "imported_\(UUID().uuidString.prefix(8)).\(ext)")
        try fileManager.copyItem(at: url, to: dest)
        return "\(Self.assetSubfolder)/\(dest.lastPathComponent)"
    }

    /// Downloads a remote image into staging (finalized on save like any
    /// other staged file).
    public func downloadRemote(_ url: URL) async throws -> URL {
        let data = try await fetchData(url)
        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
        return try stage(data, fileName: "remote_\(UUID().uuidString.prefix(8)).\(ext)")
    }

    // MARK: - Save-time normalization

    /// The editor's Save pipeline: whatever the editing session left in
    /// `imagePath` becomes a stored project-relative reference — staged
    /// files are finalized, absolute paths inside the project relativized,
    /// external files imported, remote URLs downloaded. When a step fails
    /// the input passes through unchanged (resolve-on-load still renders
    /// legacy absolute paths; remote refs render a placeholder).
    public func normalizedForSave(_ imagePath: String?) async -> String? {
        switch VisionImageRef.classify(imagePath) {
        case .none, .relative:
            return imagePath
        case .legacyAbsolute(let absolute):
            let url = URL(fileURLWithPath: absolute)
            if isStaged(url) {
                return (try? finalize(url)) ?? imagePath
            }
            if let relative = VisionBoardImagePath.relativized(
                absolute, projectBase: projectBase) {
                return relative
            }
            return (try? importExternal(url)) ?? imagePath
        case .remote(let url):
            guard let staged = try? await downloadRemote(url),
                  let relative = try? finalize(staged) else { return imagePath }
            return relative
        }
    }

    // MARK: - Deletion (Slice 4)

    public enum RemoveError: Error, Equatable {
        case outsideManagedFolder
    }

    /// Trashes (recoverable) a vision-board asset. REFUSES anything that
    /// doesn't resolve inside assets/visionboard/ — legacy absolute paths
    /// pointing at the user's own files are never touched.
    public func removeAsset(relativePath: String) throws {
        let resolved = projectBase.appendingPathComponent(relativePath)
            .standardizedFileURL
        let managed = projectBase.appendingPathComponent(Self.assetSubfolder)
            .standardizedFileURL
        guard resolved.path.hasPrefix(managed.path + "/") else {
            throw RemoveError.outsideManagedFolder
        }
        guard fileManager.fileExists(atPath: resolved.path) else { return }
        do {
            try fileManager.trashItem(at: resolved, resultingItemURL: nil)
        } catch {
            try fileManager.removeItem(at: resolved)
        }
    }
}
