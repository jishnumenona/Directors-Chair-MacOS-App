//
// CollapsibleCard.swift
//
// Progressive-disclosure building block for the Shots view. Every advanced
// section collapses to a single header row that still SHOWS its current state
// via a live summary — features stay discoverable and glanceable without the
// expanded UI overwhelming a first-time user. Expansion preferences persist
// per section across shots and launches (@AppStorage).
//

import SwiftUI
import DirectorsChairCore

// MARK: - Collapsible Card

struct CollapsibleCard<Content: View>: View {
    let icon: String
    var iconColor: Color = .accentColor
    let title: String
    /// Live one-line description of the state inside, shown while collapsed.
    var summary: String = ""
    /// Persistence key for the expansion preference ("shotCard.<key>").
    let storageKey: String
    var defaultExpanded: Bool = false
    @ViewBuilder let content: () -> Content

    @AppStorage private var isExpanded: Bool

    init(icon: String,
         iconColor: Color = .accentColor,
         title: String,
         summary: String = "",
         storageKey: String,
         defaultExpanded: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.summary = summary
        self.storageKey = storageKey
        self.defaultExpanded = defaultExpanded
        self.content = content
        self._isExpanded = AppStorage(wrappedValue: defaultExpanded, "shotCard.\(storageKey)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(iconColor)
                        .frame(width: 16)
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.85))

                    if !isExpanded && !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.leading, 4)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
        .background(Color(hex: "#222222"))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#333333"), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

// MARK: - Summaries (pure, tested)

/// One-line state summaries shown on collapsed cards.
enum ShotViewSummaries {

    /// "MS · Eye Level · 50mm f/2.8 · Dolly In · 5.0s"
    static func camera(for shot: Shot) -> String {
        var parts = ["\(shot.shotType)", shot.cameraAngle]
        if let lens = shot.lensMm {
            parts.append("\(lens)mm \(shot.aperture)")
        } else {
            parts.append(shot.aperture)
        }
        if shot.movement != "Static" { parts.append(shot.movement) }
        if let duration = shot.duration { parts.append(String(format: "%.1fs", duration)) }
        return parts.joined(separator: " · ")
    }

    /// "3 characters · Warehouse · 2 props · 1 sound"
    static func context(characterCount: Int, location: String?, propCount: Int, soundCount: Int) -> String {
        var parts: [String] = []
        parts.append("\(characterCount) character\(characterCount == 1 ? "" : "s")")
        parts.append(location?.isEmpty == false ? location! : "no location")
        if propCount > 0 { parts.append("\(propCount) prop\(propCount == 1 ? "" : "s")") }
        if soundCount > 0 { parts.append("\(soundCount) sound\(soundCount == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    /// "2 of 3 frames set"
    static func keyframes(withImages: Int, total: Int) -> String {
        "\(withImages) of \(total) frame\(total == 1 ? "" : "s") set"
    }

    /// "2 of 3 selected"
    static func references(selected: Int, limit: Int = 3) -> String {
        selected == 0 ? "none selected" : "\(selected) of \(limit) selected"
    }

    /// "Film Noir · Golden Hour · Rain · Low-key"
    static func lookLighting(styleName: String?, timeOfDay: String?, weather: String?, keyMood: String?) -> String {
        let parts = [styleName, timeOfDay, weather, keyMood].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return parts.isEmpty ? "defaults" : parts.joined(separator: " · ")
    }

    /// "Slow Dolly In"
    static func motion(cameraMotion: String, speed: String) -> String {
        speed == "Normal" ? cameraMotion : "\(speed) \(cameraMotion)"
    }

    /// "High · 16:9 · negative prompt set"
    static func advanced(quality: String, aspectRatio: String, subjectMotion: String, hasNegativePrompt: Bool) -> String {
        var parts = [quality, aspectRatio]
        if subjectMotion != "Static" { parts.append("subject: \(subjectMotion.lowercased())") }
        if hasNegativePrompt { parts.append("negative prompt set") }
        return parts.joined(separator: " · ")
    }
}
