// DirectorsChairExports/Sources/DirectorsChairExports/SceneHeadingFormatter.swift
//
// Single, shared slug-line builder used by all four exporters (WS8.5).
// Previously PDF/HTML/FDX hardcoded "INT. <location> - DAY", so every night or
// exterior scene exported wrong. This honours any INT/EXT prefix or
// time-of-day the author already wrote into the location, and only defaults
// (INT. / - DAY) when they are genuinely absent.

import Foundation
import DirectorsChairCore

enum SceneHeadingFormatter {

    /// Recognised time-of-day tokens (screenplay convention).
    private static let timesOfDay: Set<String> = [
        "DAY", "NIGHT", "DAWN", "DUSK", "MORNING", "EVENING", "AFTERNOON",
        "CONTINUOUS", "LATER", "SUNSET", "SUNRISE", "NOON", "MIDNIGHT"
    ]

    /// Build the uppercase slug line, e.g. "EXT. BEACH - NIGHT".
    static func heading(for scene: Scene, sequenceLocation: String? = nil) -> String {
        let raw = (scene.location ?? sequenceLocation ?? scene.name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var text = raw.uppercased()

        if !(text.hasPrefix("INT") || text.hasPrefix("EXT") || text.hasPrefix("I/E")) {
            text = "INT. \(text)"
        }
        if !hasTimeOfDay(text) {
            text += " - DAY"
        }
        return text
    }

    /// True if the heading already ends with a recognised time-of-day after a
    /// " - " separator (e.g. "- NIGHT", "- LATER THAT NIGHT").
    private static func hasTimeOfDay(_ heading: String) -> Bool {
        guard let sep = heading.range(of: " - ", options: .backwards) else { return false }
        let suffix = String(heading[sep.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !suffix.isEmpty else { return false }
        if timesOfDay.contains(suffix) { return true }
        let firstToken = suffix.split(separator: " ").first.map(String.init) ?? suffix
        return timesOfDay.contains(firstToken)
    }
}
