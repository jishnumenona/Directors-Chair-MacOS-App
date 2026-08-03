// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionWallTools.swift
//
// The Wall, pass 2 — what your hand can reach for.
//
// Right-clicking the wall used to drop a list of nine card types. This is
// the replacement: a small set of TOOLS, arranged in a ring around the
// cursor. Everything here is pure — the tools, where they sit on the ring,
// and what a pasted link turns out to be — so the menu's behaviour is
// unit-testable without rendering it.

import CoreGraphics
import Foundation

// MARK: - The tools

public enum VisionWallTool: String, CaseIterable, Identifiable, Sendable {
    case imagine
    case write
    case paste
    case picture
    case link
    case video

    public var id: String { rawValue }

    /// Verb first — you are reaching for an action, not filing a record.
    public var title: String {
        switch self {
        case .imagine: return "Imagine"
        case .write: return "Write"
        case .paste: return "Paste"
        case .picture: return "Picture"
        case .link: return "Link"
        case .video: return "Video"
        }
    }

    public var systemImage: String {
        switch self {
        case .imagine: return "sparkles"
        case .write: return "textformat"
        case .paste: return "doc.on.clipboard"
        case .picture: return "photo"
        case .link: return "link"
        case .video: return "play.rectangle"
        }
    }

    /// What the caret asks for when the tool needs words first.
    public var prompt: String? {
        switch self {
        case .imagine: return "Describe what you see…"
        case .link: return "Paste a link…"
        case .video: return "Paste a video link…"
        case .write, .paste, .picture: return nil
        }
    }

    /// The ring reads clockwise from the top in this order.
    public static var ringOrder: [VisionWallTool] {
        [.imagine, .picture, .video, .link, .paste, .write]
    }
}

// MARK: - Ring geometry

public enum VisionRadialGeometry {

    /// Where each tool sits on a ring around the cursor. First item at the
    /// top, then clockwise, so muscle memory can form.
    public static func positions(count: Int, radius: CGFloat) -> [CGPoint] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let angle = -CGFloat.pi / 2 + (2 * .pi / CGFloat(count)) * CGFloat(index)
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }

    /// Keeps the whole ring on screen when you click near an edge — the
    /// menu slides inward instead of spilling off the wall.
    public static func anchor(for point: CGPoint, in viewport: CGSize,
                              radius: CGFloat, margin: CGFloat = 46) -> CGPoint {
        let inset = radius + margin
        guard viewport.width > inset * 2, viewport.height > inset * 2 else {
            return CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        }
        return CGPoint(x: min(max(point.x, inset), viewport.width - inset),
                       y: min(max(point.y, inset), viewport.height - inset))
    }
}

// MARK: - Links

/// What a pasted link turns out to be. YouTube and Vimeo are worth knowing
/// by name: they hand us a still we can pin as the scrap's face.
public enum VisionLinkKind: Equatable, Sendable {
    case youtube(id: String)
    case vimeo(id: String)
    case web

    public var isVideo: Bool {
        switch self {
        case .youtube, .vimeo: return true
        case .web: return false
        }
    }

    /// A frame from the video to pin up, when the host publishes one.
    public var thumbnailURL: URL? {
        switch self {
        case .youtube(let id):
            return URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")
        case .vimeo, .web:
            return nil          // Vimeo needs an API call; not worth one here.
        }
    }
}

public enum VisionLink {

    /// Accepts what people actually paste: full URLs, share links, and
    /// bare hosts without a scheme.
    public static func normalized(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let candidate = trimmed.lowercased().hasPrefix("http")
            ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), let host = url.host,
              host.contains(".") else { return nil }
        return url
    }

    public static func classify(_ url: URL) -> VisionLinkKind {
        let host = (url.host ?? "").lowercased()
            .replacingOccurrences(of: "www.", with: "")
        if host == "youtu.be" {
            let id = url.lastPathComponent
            return id.isEmpty ? .web : .youtube(id: id)
        }
        if host == "youtube.com" || host == "m.youtube.com" {
            if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "v" })?.value, !id.isEmpty {
                return .youtube(id: id)
            }
            // /embed/ID and /shorts/ID
            let parts = url.pathComponents.filter { $0 != "/" }
            if parts.count >= 2, ["embed", "shorts", "live"].contains(parts[0]) {
                return .youtube(id: parts[1])
            }
            return .web
        }
        if host == "vimeo.com" || host == "player.vimeo.com" {
            let id = url.pathComponents.filter { $0 != "/" }.last ?? ""
            return id.allSatisfy(\.isNumber) && !id.isEmpty ? .vimeo(id: id) : .web
        }
        return .web
    }

    /// What the scrap is called when nobody typed a title: the host, and
    /// the first meaningful path segment if there is one.
    public static func displayName(for url: URL) -> String {
        let host = (url.host ?? "link").replacingOccurrences(of: "www.", with: "")
        let slug = url.pathComponents.filter { $0 != "/" }.last ?? ""
        guard !slug.isEmpty, slug.count <= 48, !slug.allSatisfy(\.isNumber) else {
            return host
        }
        let words = slug
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return "\(host) · \(words)"
    }
}
