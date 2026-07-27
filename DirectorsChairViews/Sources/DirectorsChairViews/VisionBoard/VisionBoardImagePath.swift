// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionBoardImagePath.swift
//
// Vision Board repair, Slice 2: image path scheme. The app-wide convention
// is PROJECT-RELATIVE paths resolved against the project directory; the
// vision board historically stored absolute paths (breaking portability)
// and raw http URLs (which the file-based loader spun on forever).
//
// Policy: RESOLVE-ON-LOAD accepts everything legacy files contain;
// STORE-RELATIVE-ON-WRITE is enforced at every site that sets imagePath.

import Foundation

/// Classification of a `VisionCard.imagePath` value.
public enum VisionImageRef: Equatable, Sendable {
    case none
    case relative(String)
    case legacyAbsolute(String)
    case remote(URL)

    public static func classify(_ path: String?) -> VisionImageRef {
        guard let path, !path.isEmpty else { return .none }
        if path.hasPrefix("http://") || path.hasPrefix("https://"),
           let url = URL(string: path) {
            return .remote(url)
        }
        if path.hasPrefix("/") || path.hasPrefix("~") {
            return .legacyAbsolute((path as NSString).expandingTildeInPath)
        }
        return .relative(path)
    }
}

public enum VisionBoardImagePath {

    /// Resolves a stored path to a file URL for loading. Remote URLs return
    /// nil — the card view renders a placeholder for those (downloads
    /// happen at save time, never in the render path).
    public static func resolveImageURL(_ path: String?,
                                       projectBase: URL?) -> URL? {
        switch VisionImageRef.classify(path) {
        case .none, .remote:
            return nil
        case .legacyAbsolute(let absolute):
            return URL(fileURLWithPath: absolute)
        case .relative(let relative):
            guard let projectBase else { return nil }
            return projectBase.appendingPathComponent(relative)
        }
    }

    /// Rewrites an absolute path to project-relative when it lies inside
    /// the project directory; nil when it doesn't (caller imports the file
    /// instead). Component-based — "/project" never matches "/project2".
    public static func relativized(_ absolutePath: String,
                                   projectBase: URL) -> String? {
        let fileComponents = URL(fileURLWithPath: absolutePath)
            .standardizedFileURL.pathComponents
        let baseComponents = projectBase.standardizedFileURL.pathComponents
        guard fileComponents.count > baseComponents.count,
              Array(fileComponents.prefix(baseComponents.count)) == baseComponents else {
            return nil
        }
        return fileComponents.dropFirst(baseComponents.count)
            .joined(separator: "/")
    }
}
