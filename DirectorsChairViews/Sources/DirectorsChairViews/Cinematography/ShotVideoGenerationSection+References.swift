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
        case keyframe, character, costume, location

        var icon: String {
            switch self {
            case .keyframe: return "film"
            case .character: return "person.fill"
            case .costume: return "tshirt.fill"
            case .location: return "mappin.and.ellipse"
            }
        }

        var tint: Color {
            switch self {
            case .keyframe: return .accentColor
            case .character: return .blue
            case .costume: return .purple
            case .location: return .green
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

    /// Default pick when the director hasn't chosen: user-authored mid
    /// keyframes first (shot-specific), then faces (continuity killers),
    /// then wardrobe, then the location plate. Pure — tested.
    static func defaultSelection(from candidates: [VideoReferenceCandidate], limit: Int = 3) -> [String] {
        var ids: [String] = []
        for source in [Source.keyframe, .character, .costume, .location] {
            for candidate in candidates where candidate.source == source && ids.count < limit {
                ids.append(candidate.id)
            }
        }
        return ids
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
            HStack(spacing: 6) {
                Image(systemName: "person.crop.rectangle.stack")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("CONSISTENCY REFERENCES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(selectedIds.count)/\(limit) sent with the video request")
                    .font(.system(size: 9))
                    .foregroundColor(selectedIds.count >= limit ? .orange : .gray.opacity(0.6))
            }

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
            }
        }
        .padding(12)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
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
