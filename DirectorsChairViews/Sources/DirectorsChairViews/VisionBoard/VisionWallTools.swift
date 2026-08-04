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
    case note             // a slip of paper stuck under it
    case annotate         // mark up a picture and regenerate it
    case prompt           // read the words that made it
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
        case .note: return "Note"
        case .annotate: return "Annotate"
        case .prompt: return "Prompt"
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
        case .note: return "note.text"
        case .annotate: return "pencil.and.outline"
        case .prompt: return "text.quote"
        case .details: return "info.circle"
        case .remove: return "trash"
        }
    }

    /// Restyle only means something for pictures and words; a link or a
    /// frame gets a five-tool ring instead of a dead chip.
    /// Restyle only means something for pictures and words; paper only
    /// for the things actually made of it. A scrap never shows a dead chip.
    /// A ring only ever shows tools that mean something for what you
    /// clicked: no palette on a link, no paper under a photograph, and no
    /// annotating or prompt-reading unless there is a picture to work on.
    public static func ring(isText: Bool, hasPicture: Bool,
                            isPaper: Bool = false,
                            hasPrompt: Bool = false) -> [VisionScrapTool] {
        var tools: [VisionScrapTool] = [.connect, .duplicate, .pin, .note]
        if hasPicture { tools.append(.annotate) }
        if hasPrompt { tools.append(.prompt) }
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

    /// The cord under a point, if the click landed on one.
    ///
    /// Thread hangs in a sagging curve between two pins, and it is thin,
    /// so this walks the same quadratic the cord is drawn along and takes
    /// the closest sample. Checked BEFORE scraps: a cord usually crosses
    /// the very sheets it connects, and a click within a few points of
    /// something that thin was meant for it.
    public static func thread(at worldPoint: CGPoint,
                              connectors: [VisionConnector],
                              tack: (String) -> CGPoint?,
                              tolerance: CGFloat) -> VisionConnector? {
        var best: (connector: VisionConnector, distance: CGFloat)?
        for connector in connectors {
            guard let from = tack(connector.fromCardId),
                  let to = tack(connector.toCardId) else { continue }
            let distance = distanceToCord(worldPoint, from: from, to: to)
            guard distance <= tolerance else { continue }
            if best == nil || distance < best!.distance {
                best = (connector, distance)
            }
        }
        return best?.connector
    }

    /// Distance from a point to the hanging cord between two pins. The
    /// sag MUST match ConnectorArrow's or the cord you can see is not the
    /// cord you can click.
    static func distanceToCord(_ point: CGPoint,
                               from: CGPoint, to: CGPoint,
                               samples: Int = 24) -> CGFloat {
        let sag = min(58, hypot(to.x - from.x, to.y - from.y) * 0.15)
        let control = CGPoint(x: (from.x + to.x) / 2,
                              y: (from.y + to.y) / 2 + sag * 2)
        var closest = CGFloat.greatestFiniteMagnitude
        for step in 0...samples {
            let t = CGFloat(step) / CGFloat(samples)
            let inverse = 1 - t
            // Quadratic Bezier, the curve the cord is stroked along.
            let x = inverse * inverse * from.x
                + 2 * inverse * t * control.x + t * t * to.x
            let y = inverse * inverse * from.y
                + 2 * inverse * t * control.y + t * t * to.y
            closest = min(closest, hypot(point.x - x, point.y - y))
        }
        return closest
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


// MARK: - Redrawing a picture

/// An instruction to redraw an existing picture: what to change, and the
/// picture to change. The board hands this to the app, which owns the
/// generation client.
public struct VisionImageEdit: Sendable {
    public let prompt: String
    /// PNG bytes of the picture being edited, sent as the reference.
    public let baseImage: Data

    public init(prompt: String, baseImage: Data) {
        self.prompt = prompt
        self.baseImage = baseImage
    }
}


// MARK: - Space held while a picture is imagined

/// A blank sheet pinned up where a picture will land. It exists only
/// while the work is in flight — nothing is written to the project — so
/// closing or panning away costs nothing.
public struct PendingImagine: Identifiable, Equatable, Sendable {
    public let id: String
    public let prompt: String
    public var origin: CGPoint
    public var size: CGSize

    public init(id: String, prompt: String, origin: CGPoint, size: CGSize) {
        self.id = id
        self.prompt = prompt
        self.origin = origin
        self.size = size
    }
}
