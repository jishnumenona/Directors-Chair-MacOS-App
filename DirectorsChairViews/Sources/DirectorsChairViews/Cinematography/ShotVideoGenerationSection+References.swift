//
// ShotVideoGenerationSection+References.swift
//
// Reference tray: gathers every visual anchor the story design already knows
// about (mid keyframes, character faces, the scene's assigned costumes, the
// location at the scene's time of day) and lets the director pick which ≤3
// ride along as provider reference frames for subject/scene consistency.
//

import SwiftUI
import AppKit
import DirectorsChairCore
import DirectorsChairServices

// MARK: - Candidate model

struct VideoReferenceCandidate: Identifiable, Equatable {
    enum Source: String, CaseIterable {
        /// One grid image of every character in the shot (faces + wardrobe).
        case characterCollage
        /// One grid image of the location (and its props, once they have imagery).
        case locationCollage
        case keyframe, character, costume, location
        /// Director-supplied extra (shot reference media).
        case custom

        var icon: String {
            switch self {
            case .characterCollage: return "person.2.crop.square.stack"
            case .locationCollage: return "photo.on.rectangle.angled"
            case .keyframe: return "film"
            case .character: return "person.fill"
            case .costume: return "tshirt.fill"
            case .location: return "mappin.and.ellipse"
            case .custom: return "paperclip"
            }
        }

        var tint: Color {
            switch self {
            case .characterCollage: return .blue
            case .locationCollage: return .green
            case .keyframe: return .accentColor
            case .character: return .blue
            case .costume: return .purple
            case .location: return .green
            case .custom: return .orange
            }
        }
    }

    let id: String
    let source: Source
    let displayName: String
    let reference: ReferenceImage

    static func == (lhs: VideoReferenceCandidate, rhs: VideoReferenceCandidate) -> Bool {
        lhs.id == rhs.id
    }

    /// Default pick when the director hasn't chosen. With collages present the
    /// Veo slot discipline applies: characters collage + location collage,
    /// leaving the third slot free for a director-supplied extra. Without
    /// collages (no scene data), fall back to filling from the pool:
    /// keyframes first, then faces, wardrobe, location. Pure — tested.
    static func defaultSelection(from candidates: [VideoReferenceCandidate], limit: Int = 3) -> [String] {
        let collages = candidates.filter {
            $0.source == .characterCollage || $0.source == .locationCollage
        }
        if !collages.isEmpty {
            return collages.prefix(limit).map(\.id)
        }
        var ids: [String] = []
        for source in [Source.keyframe, .character, .costume, .location, .custom] {
            for candidate in candidates where candidate.source == source && ids.count < limit {
                ids.append(candidate.id)
            }
        }
        return ids
    }

    /// Prompt preamble describing each reference image, in send order, so the
    /// video model knows what every image is for. Pure — tested.
    static func promptPreamble(for candidates: [VideoReferenceCandidate]) -> String {
        guard !candidates.isEmpty else { return "" }
        var lines = ["You are given \(candidates.count) reference image(s) that define this shot's visual identity:"]
        for (index, candidate) in candidates.enumerated() {
            let n = index + 1
            switch candidate.source {
            case .characterCollage:
                lines.append("- Image \(n) is a collage of the characters in this shot (\(candidate.displayName)). Match each person's face, skin tone, hair, build, and wardrobe exactly.")
            case .locationCollage:
                lines.append("- Image \(n) is a collage of the location and its props (\(candidate.displayName)). The shot MUST take place in this environment — match the architecture, decor, props, and atmosphere.")
            case .keyframe:
                lines.append("- Image \(n) is a mid-shot keyframe (\(candidate.displayName)) the video should pass through — match its composition and content at that moment.")
            case .character:
                lines.append("- Image \(n) is character \(candidate.displayName). Match their appearance exactly.")
            case .costume:
                lines.append("- Image \(n) is the costume \(candidate.displayName). Match the clothing exactly.")
            case .location:
                lines.append("- Image \(n) is the location \(candidate.displayName). The shot takes place here.")
            case .custom:
                lines.append("- Image \(n) is an additional reference supplied by the director (\(candidate.displayName)) — honor its subject and style.")
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Tray view

struct VideoReferenceTray: View {
    let candidates: [VideoReferenceCandidate]
    /// Ordered selection — position is the send order (max 3).
    @Binding var selectedIds: [String]

    private let limit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if candidates.isEmpty {
                Text("Generate keyframes, or add character/location images in Story Design, to anchor the video's look.")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(candidates) { candidate in
                            referenceCard(candidate)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Text("Veo accepts \(limit): the character and location collages are pre-selected — add one keyframe or reference-media image as the optional third. Selection order is send order.")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
    }

    private func toggle(_ candidate: VideoReferenceCandidate) {
        if let idx = selectedIds.firstIndex(of: candidate.id) {
            selectedIds.remove(at: idx)
        } else if selectedIds.count < limit {
            selectedIds.append(candidate.id)
        }
    }

    @ViewBuilder
    private func referenceCard(_ candidate: VideoReferenceCandidate) -> some View {
        let sendIndex = selectedIds.firstIndex(of: candidate.id)

        Button(action: { toggle(candidate) }) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    if let data = Data(base64Encoded: candidate.reference.base64),
                       let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 92, height: 56)
                            .clipped()
                            .cornerRadius(6)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(candidate.source.tint.opacity(0.12))
                            .frame(width: 92, height: 56)
                            .overlay(
                                Image(systemName: candidate.source.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(candidate.source.tint.opacity(0.6))
                            )
                    }

                    if let sendIndex {
                        Text("\(sendIndex + 1)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.accentColor))
                            .padding(3)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(sendIndex != nil ? Color.accentColor : Color(hex: "#3A3A3A"),
                                lineWidth: sendIndex != nil ? 2 : 1)
                )

                HStack(spacing: 3) {
                    Image(systemName: candidate.source.icon)
                        .font(.system(size: 7))
                        .foregroundColor(candidate.source.tint.opacity(0.8))
                    Text(candidate.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(sendIndex != nil ? .white.opacity(0.9) : .gray)
                        .lineLimit(1)
                }
                .frame(width: 92)
            }
        }
        .buttonStyle(.plain)
        .help(sendIndex != nil
              ? "Sent as reference \( (sendIndex ?? 0) + 1) — click to remove"
              : "Click to send as a consistency reference (max \(limit))")
    }
}
