// DirectorsChairCore/Sources/DirectorsChairCore/Models/VisionCardLinkRef.swift
//
// What travels between the outline and the wall.
//
// Dragging a scene or a shot onto an element has to carry three things:
// which kind of thing it is, which one, and what to call it on the board.
// It rides as plain text because that is the one drag type every part of
// this app already accepts — but it is written as a URI with our own
// scheme so the wall can tell "this is a shot" from "this is the word
// shot", which is the difference between linking and typing.

import Foundation

public struct VisionCardLinkRef: Equatable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case scene
        case shot
    }

    public let kind: Kind
    public let id: String
    /// What the element shows: "SC 12" or "4B". Stored alongside the id
    /// so the board can label a link without holding the whole project.
    public let label: String
    /// A shot belongs to a scene, and knowing which lets a link to a shot
    /// answer questions about its scene too.
    public let sceneId: String?

    public init(kind: Kind, id: String, label: String, sceneId: String? = nil) {
        self.kind = kind
        self.id = id
        self.label = label
        self.sceneId = sceneId
    }

    public static let scheme = "dcref"

    /// The text that actually gets dragged.
    public var dragText: String {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = kind.rawValue
        components.path = "/" + id
        var query = [URLQueryItem(name: "label", value: label)]
        if let sceneId { query.append(URLQueryItem(name: "scene", value: sceneId)) }
        components.queryItems = query
        return components.url?.absoluteString ?? ""
    }

    /// Reads one back, or nil if this was just text somebody dragged.
    ///
    /// Deliberately strict: anything that isn't unmistakably one of ours
    /// must fall through to being treated as words, or dropping a line of
    /// text on the wall would start behaving unpredictably.
    public static func parse(_ text: String) -> VisionCardLinkRef? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme == scheme,
              let host = components.host,
              let kind = Kind(rawValue: host)
        else { return nil }

        let id = String(components.path.dropFirst())      // leading "/"
        guard !id.isEmpty else { return nil }

        let query = components.queryItems ?? []
        let label = query.first { $0.name == "label" }?.value ?? id
        let sceneId = query.first { $0.name == "scene" }?.value
        return VisionCardLinkRef(kind: kind, id: id,
                                 label: label, sceneId: sceneId)
    }
}

public extension VisionCard {
    /// The scene or shot pinned to this element, if any. A shot wins over
    /// its scene, because linking a shot records both and the shot is the
    /// more specific of the two.
    var linkedRef: VisionCardLinkRef? {
        let label = linkedLabel ?? ""
        if let shotId = linkedShotId, !shotId.isEmpty {
            return VisionCardLinkRef(kind: .shot, id: shotId,
                                     label: label, sceneId: linkedSceneId)
        }
        if let sceneId = linkedSceneId, !sceneId.isEmpty {
            return VisionCardLinkRef(kind: .scene, id: sceneId, label: label)
        }
        return nil
    }
}
