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
import DirectorsChairCore

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

// MARK: - Tools for a scrap

/// What you reach for when the right-click landed ON something. The wall's
/// ring makes things; this one acts on the thing already there.
public enum VisionScrapTool: String, CaseIterable, Identifiable, Sendable {
    case connect
    case duplicate
    case pin
    case restyle          // palette from a picture, or a new cut for words
    case paper            // what the words are written on
    case details
    case remove

    public var id: String { rawValue }

    public func title(pinned: Bool, isText: Bool) -> String {
        switch self {
        case .connect: return "Connect"
        case .duplicate: return "Copy"
        case .pin: return pinned ? "Unpin" : "Pin"
        case .restyle: return isText ? "Cut" : "Palette"
        case .paper: return "Paper"
        case .details: return "Details"
        case .remove: return "Remove"
        }
    }

    public func systemImage(pinned: Bool, isText: Bool) -> String {
        switch self {
        case .connect: return "arrow.triangle.branch"
        case .duplicate: return "plus.square.on.square"
        case .pin: return pinned ? "pin.slash" : "pin"
        case .restyle: return isText ? "scissors" : "eyedropper.halffull"
        case .paper: return "doc.plaintext"
        case .details: return "info.circle"
        case .remove: return "trash"
        }
    }

    /// Restyle only means something for pictures and words; a link or a
    /// frame gets a five-tool ring instead of a dead chip.
    /// Restyle only means something for pictures and words; paper only
    /// for the things actually made of it. A scrap never shows a dead chip.
    public static func ring(isText: Bool, hasPicture: Bool,
                            isPaper: Bool = false) -> [VisionScrapTool] {
        var tools: [VisionScrapTool] = [.connect, .duplicate, .pin]
        if isText || hasPicture { tools.append(.restyle) }
        if isPaper { tools.append(.paper) }
        tools.append(contentsOf: [.details, .remove])
        return tools
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

// MARK: - What the click landed on

public enum VisionWallHitTest {

    /// The topmost scrap under a point, or nil for bare wall. Walks in
    /// draw order so the sheet you can see is the one you get; frames sit
    /// under everything and are only hit where nothing else covers them.
    public static func scrap(at worldPoint: CGPoint,
                             cards: [VisionCard],
                             frameTypeRaw: String = "frame") -> VisionCard? {
        let ordered = cards.sorted { left, right in
            let leftFrame = left.cardType == frameTypeRaw
            let rightFrame = right.cardType == frameTypeRaw
            if leftFrame != rightFrame { return rightFrame }   // frames last
            return left.zOrder > right.zOrder                  // topmost first
        }
        return ordered.first { card in
            CGRect(x: card.canvasX ?? 0, y: card.canvasY ?? 0,
                   width: card.canvasWidth ?? 200,
                   height: card.canvasHeight ?? 200).contains(worldPoint)
        }
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
