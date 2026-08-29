// DirectorsChairViews/Shared/StoryReferenceClipboard.swift
//
// DC-0100 (owner 2026-08-29): copy a story element's identity from its page
// and paste it on a shot or a scene, where it files itself in the right
// list — a location replaces (after confirmation), characters and props
// append, a costume dresses its character for that scene.

import AppKit
import DirectorsChairCore
import SwiftUI

public enum StoryReferenceKind: String, Codable, Sendable {
    case character, location, prop, costume

    var symbol: String {
        switch self {
        case .character: return "person.fill"
        case .location: return "mappin.and.ellipse"
        case .prop: return "shippingbox.fill"
        case .costume: return "tshirt.fill"
        }
    }

    var noun: String { rawValue }
}

/// One story element, by identity.
public struct StoryReference: Codable, Equatable, Sendable {
    public var kind: StoryReferenceKind
    public var id: String
    public var name: String
    /// A costume's character.
    public var ownerName: String?

    public init(kind: StoryReferenceKind, id: String, name: String, ownerName: String? = nil) {
        self.kind = kind
        self.id = id
        self.name = name
        self.ownerName = ownerName
    }

    public static func character(_ c: Character) -> StoryReference { .init(kind: .character, id: c.id, name: c.name) }
    public static func location(_ l: Location) -> StoryReference { .init(kind: .location, id: l.id, name: l.name) }
    public static func prop(_ p: Prop) -> StoryReference { .init(kind: .prop, id: p.id, name: p.name) }
    public static func costume(_ costume: CharacterCostume, of character: Character) -> StoryReference {
        .init(kind: .costume, id: costume.costumeId, name: costume.name, ownerName: character.name)
    }

    /// "Susan · character", "Tweed · Eli's costume".
    public var label: String {
        if kind == .costume, let ownerName, !ownerName.isEmpty { return "\(name) · \(ownerName)'s costume" }
        return "\(name) · \(kind.noun)"
    }

    /// The reference as text — what lands in the pasteboard beside the typed
    /// item, and what other apps or a text field see.
    public var urlString: String {
        var components = URLComponents()
        components.scheme = "directorschair"
        components.host = "ref"
        components.path = "/\(kind.rawValue)/\(id)"
        var items = [URLQueryItem(name: "name", value: name)]
        if let ownerName { items.append(URLQueryItem(name: "owner", value: ownerName)) }
        components.queryItems = items
        return components.string ?? "directorschair://ref/\(kind.rawValue)/\(id)"
    }

    public init?(urlString: String) {
        guard let components = URLComponents(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme == "directorschair", components.host == "ref" else { return nil }
        let parts = components.path.split(separator: "/").map(String.init)
        guard parts.count == 2, let kind = StoryReferenceKind(rawValue: parts[0]) else { return nil }
        let name = components.queryItems?.first { $0.name == "name" }?.value ?? ""
        let owner = components.queryItems?.first { $0.name == "owner" }?.value
        self.init(kind: kind, id: parts[1], name: name, ownerName: owner)
    }
}

/// The pasteboard, read through DirectorsChair's eyes.
@MainActor
public final class ReferenceClipboard: ObservableObject {
    public static let shared = ReferenceClipboard()
    public static let pasteboardType = NSPasteboard.PasteboardType("com.directorschair.story-reference")

    @Published public private(set) var current: StoryReference?
    @Published public private(set) var copiedAt: Date?
    private var seenChangeCount = -1

    public init() {}

    public func copy(_ reference: StoryReference) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let data = try? JSONEncoder().encode(reference) {
            pasteboard.setData(data, forType: Self.pasteboardType)
        }
        pasteboard.setString(reference.urlString, forType: .string)
        seenChangeCount = pasteboard.changeCount
        current = reference
        copiedAt = Date()
    }

    /// What the pasteboard holds now (cheap: only re-reads after a change).
    public func refreshFromPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != seenChangeCount else { return }
        seenChangeCount = pasteboard.changeCount
        if let data = pasteboard.data(forType: Self.pasteboardType),
           let reference = try? JSONDecoder().decode(StoryReference.self, from: data) {
            current = reference
        } else if let text = pasteboard.string(forType: .string), let reference = StoryReference(urlString: text) {
            current = reference
        } else {
            current = nil
        }
    }
}

/// The teal reference colour — one look for copy and paste everywhere.
enum ReferenceStyle {
    static let tint = Color(red: 0.22, green: 0.76, blue: 0.70)
}

/// "Copy reference" — the tag on a story element's page.
public struct CopyReferenceButton: View {
    let reference: StoryReference
    var onDark: Bool = false
    @ObservedObject private var clipboard = ReferenceClipboard.shared
    @State private var flashCopied = false

    public init(reference: StoryReference, onDark: Bool = false) {
        self.reference = reference
        self.onDark = onDark
    }

    private var isHeld: Bool { clipboard.current == reference }

    public var body: some View {
        Button {
            clipboard.copy(reference)
            withAnimation(.easeInOut(duration: 0.15)) { flashCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.2)) { flashCopied = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: flashCopied ? "checkmark" : "link.badge.plus")
                    .font(.system(size: 9, weight: .semibold))
                Text(flashCopied ? "Copied" : (isHeld ? "Reference copied" : "Copy reference"))
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(onDark ? .white : ReferenceStyle.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(ReferenceStyle.tint.opacity(onDark ? 0.55 : 0.14)))
            .overlay(Capsule().stroke(ReferenceStyle.tint.opacity(isHeld || flashCopied ? 0.9 : 0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Copy this \(reference.kind.noun) as a reference, then use \"Paste reference\" on a shot or a scene")
        .accessibilityIdentifier("copy-reference-\(reference.kind.rawValue)")
    }
}

/// "Paste reference" — on a shot or a scene; shows what it holds.
public struct PasteReferenceButton: View {
    let accepts: [StoryReferenceKind]
    let onPaste: (StoryReference) -> Void
    @ObservedObject private var clipboard = ReferenceClipboard.shared

    public init(accepts: [StoryReferenceKind], onPaste: @escaping (StoryReference) -> Void) {
        self.accepts = accepts
        self.onPaste = onPaste
    }

    private var held: StoryReference? { clipboard.current }
    private var usable: Bool { held.map { accepts.contains($0.kind) } ?? false }

    public var body: some View {
        Button {
            clipboard.refreshFromPasteboard()
            if let held, accepts.contains(held.kind) { onPaste(held) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: held?.kind.symbol ?? "link")
                    .font(.system(size: 9, weight: .semibold))
                Text(held.map { "Paste \($0.name)" } ?? "Paste reference")
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                if let held {
                    Text(held.kind == .costume ? "costume" : held.kind.noun)
                        .font(.system(size: 8))
                        .opacity(0.8)
                }
            }
            .foregroundColor(usable ? ReferenceStyle.tint : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(ReferenceStyle.tint.opacity(usable ? 0.14 : 0.04)))
            .overlay(
                Capsule().stroke(ReferenceStyle.tint.opacity(usable ? 0.9 : 0.3),
                                 style: StrokeStyle(lineWidth: 1, dash: usable ? [] : [3, 3]))
            )
        }
        .buttonStyle(.plain)
        .disabled(!usable)
        .help(helpText)
        .onAppear { clipboard.refreshFromPasteboard() }
        .onHover { hovering in if hovering { clipboard.refreshFromPasteboard() } }
        .accessibilityIdentifier("paste-reference")
    }

    private var helpText: String {
        guard let held else {
            return "Copy a reference from a character, location, prop or costume page first (the \"Copy reference\" tag), then paste it here"
        }
        if accepts.contains(held.kind) { return "Add \(held.label) here" }
        return "This place can't take a \(held.kind.noun) — \(held.kind == .character ? "paste it on a shot instead" : "copy something else")"
    }
}
