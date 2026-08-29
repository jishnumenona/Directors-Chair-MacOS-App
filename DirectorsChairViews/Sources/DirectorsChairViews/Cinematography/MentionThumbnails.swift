// DirectorsChairViews/Cinematography/MentionThumbnails.swift
//
// Owner 2026-08-29: the things a description mentions — "@" characters,
// "#" locations, "$" props, "&" continuity shots — shown as thumbnails
// right under the text, so the writer sees who and what the shot holds.

import DirectorsChairCore
import SwiftUI

/// The mention text a shot is referred to by ("Shot #3").
enum MentionNames {
    static func shot(_ shot: Shot) -> String { "Shot #\(shot.shotId)" }
}

/// One thing a description mentions, resolved against the project.
struct ResolvedMention: Identifiable, Equatable {
    enum Kind: Equatable { case character, location, prop, shot }
    let kind: Kind
    let id: String
    let name: String
    /// Project-relative picture path, if the thing has one.
    let imagePath: String?
    let symbol: String
    let color: Color
}

enum MentionParser {
    /// Every mention in `text`, in order of first appearance, longest name
    /// first so "Susan Lee" wins over "Susan". Names are matched exactly
    /// after the trigger, case-insensitively.
    static func mentions(in text: String, characters: [Character], locations: [Location],
                         props: [Prop], shots: [Shot]) -> [ResolvedMention] {
        var found: [(Int, ResolvedMention)] = []
        func scan(trigger: String, names: [(String, ResolvedMention)]) {
            for (name, mention) in names.sorted(by: { $0.0.count > $1.0.count }) {
                guard !name.isEmpty,
                      let range = text.range(of: trigger + name, options: .caseInsensitive),
                      !found.contains(where: { $0.1.id == mention.id && $0.1.kind == mention.kind })
                else { continue }
                found.append((text.distance(from: text.startIndex, to: range.lowerBound), mention))
            }
        }
        scan(trigger: "@", names: characters.map { ($0.name, ResolvedMention(
            kind: .character, id: $0.id, name: $0.name, imagePath: $0.representativeImage,
            symbol: "person.fill", color: .blue)) })
        scan(trigger: "#", names: locations.map { ($0.name, ResolvedMention(
            kind: .location, id: $0.id, name: $0.name, imagePath: $0.primaryImage ?? $0.images.first,
            symbol: "mappin.and.ellipse", color: .green)) })
        scan(trigger: "$", names: props.map { ($0.name, ResolvedMention(
            kind: .prop, id: $0.id, name: $0.name, imagePath: $0.thumbnail ?? $0.referencePhotos.first,
            symbol: "shippingbox.fill", color: .orange)) })
        scan(trigger: "&", names: shots.map { (MentionNames.shot($0), ResolvedMention(
            kind: .shot, id: $0.id, name: MentionNames.shot($0), imagePath: $0.previewImage,
            symbol: "film.stack", color: .purple)) })
        return found.sorted { $0.0 < $1.0 }.map(\.1)
    }
}

/// The thumbnails strip under a description.
struct MentionThumbnailStrip: View {
    let mentions: [ResolvedMention]
    let projectDirectory: URL?

    var body: some View {
        if !mentions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(mentions) { mention in
                        HStack(spacing: 6) {
                            if let path = mention.imagePath, !path.isEmpty, let base = projectDirectory {
                                AsyncThumbnail(url: base.appendingPathComponent(path), displaySize: 44) {
                                    placeholder(mention)
                                }
                                .frame(width: mention.kind == .character ? 28 : 44, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: mention.kind == .character ? 14 : 5))
                            } else {
                                placeholder(mention)
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                            }
                            Text(mention.name)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 8).fill(mention.color.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(mention.color.opacity(0.25), lineWidth: 1))
                        .accessibilityIdentifier("mention-thumb-\(mention.name)")
                    }
                }
            }
        }
    }

    private func placeholder(_ mention: ResolvedMention) -> some View {
        ZStack {
            mention.color.opacity(0.2)
            Image(systemName: mention.symbol)
                .font(.system(size: 11))
                .foregroundColor(mention.color)
        }
    }
}
