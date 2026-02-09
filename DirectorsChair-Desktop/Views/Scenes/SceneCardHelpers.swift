//
//  SceneCardHelpers.swift
//  DirectorsChair-Desktop
//
//  Shared helpers for scene card and detail views
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairServices

// MARK: - Scene Image Cache

/// Simple NSCache wrapper for scene overview images
final class SceneImageCache {
    static let shared = SceneImageCache()
    private let cache = NSCache<NSString, NSImage>()
    private init() { cache.countLimit = 30 }

    func image(forKey key: String) -> NSImage? { cache.object(forKey: key as NSString) }
    func setImage(_ image: NSImage, forKey key: String) { cache.setObject(image, forKey: key as NSString) }
}

// MARK: - Scene Helpers

enum SceneCardHelpers {

    /// Extract unique character names from a scene's dialogues
    static func sceneCharacters(scene: DirectorsChairCore.Scene) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for dialogue in scene.dialogues {
            let name = dialogue.character
            if !name.isEmpty && seen.insert(name).inserted {
                result.append(name)
            }
        }
        return result
    }

    /// Map production status string to a color
    static func productionStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "planning":   return .gray
        case "scheduled":  return .blue
        case "ready":      return .blue
        case "shooting":   return .orange
        case "shot":       return .green
        case "complete":   return .purple
        case "approved":   return .green
        default:           return .gray
        }
    }

    /// Parse a location string like "INT. KITCHEN - DAY" into parts
    static func parseSceneLocation(_ location: String?) -> (prefix: String?, location: String, time: String?) {
        guard let loc = location, !loc.isEmpty else {
            return (nil, "Unknown", nil)
        }

        let upper = loc.uppercased()
        var prefix: String? = nil
        var stripped = upper

        for p in ["INT./EXT. ", "INT/EXT. ", "INT. ", "EXT. ", "INT/EXT ", "INT ", "EXT "] {
            if stripped.hasPrefix(p) {
                prefix = String(p.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: ""))
                stripped = String(stripped.dropFirst(p.count))
                break
            }
        }

        if let dashRange = stripped.range(of: " - ") {
            let place = String(stripped[stripped.startIndex..<dashRange.lowerBound])
            let time = String(stripped[dashRange.upperBound...])
            return (prefix, place.capitalized, time.capitalized)
        }

        return (prefix, stripped.capitalized, nil)
    }

    /// Extract scene number from name (e.g. "Scene 3" from "Scene 3 - Kitchen")
    static func sceneNumber(_ name: String) -> String {
        if let range = name.range(of: #"^Scene\s+\d+"#, options: .regularExpression) {
            return String(name[range])
        }
        return name
    }

    /// Estimate scene duration from shot durations + dialogue word count
    static func estimateSceneDuration(scene: DirectorsChairCore.Scene) -> Double {
        // Sum explicit shot durations
        var totalDuration: Double = 0
        for shot in scene.shots {
            if let d = shot.duration, d > 0 {
                totalDuration += d
            }
        }

        // If no shot durations, estimate from dialogue word count
        if totalDuration == 0 {
            for dialogue in scene.dialogues {
                let words = DurationEstimator.countWords(in: dialogue.text)
                if words > 0 {
                    totalDuration += Double(words) / 150.0 * 60.0 // ~150 WPM
                }
            }
            // Add ~3s per action line
            totalDuration += Double(scene.actions.count) * 3.0
        }

        return totalDuration
    }

    /// Total content count for a scene
    static func contentCounts(scene: DirectorsChairCore.Scene) -> [(icon: String, count: Int, label: String)] {
        var items: [(icon: String, count: Int, label: String)] = []
        if scene.dialogues.count > 0 { items.append(("bubble.left.fill", scene.dialogues.count, "Dialogues")) }
        if scene.actions.count > 0 { items.append(("figure.walk", scene.actions.count, "Actions")) }
        if scene.narrations.count > 0 { items.append(("text.quote", scene.narrations.count, "Narrations")) }
        if scene.shots.count > 0 { items.append(("camera.fill", scene.shots.count, "Shots")) }
        let noteCount = scene.sceneNotes.count + scene.soundNotes.count
        if noteCount > 0 { items.append(("note.text", noteCount, "Notes")) }
        return items
    }

    /// Build an AI prompt for scene overview image generation
    static func buildSceneOverviewPrompt(scene: DirectorsChairCore.Scene) -> String {
        var parts: [String] = []

        parts.append("Cinematic film still, professional cinematography, establishing shot")

        if let location = scene.location, !location.isEmpty {
            parts.append("set in \(location)")
        }

        if let summary = scene.sceneOverviewSummary, !summary.isEmpty {
            parts.append(String(summary.prefix(200)))
        } else if !scene.description.isEmpty {
            parts.append(String(scene.description.prefix(200)))
        }

        if let emotions = scene.sceneEmotionalAnalysis,
           let topEmotion = emotions.max(by: { $0.value < $1.value }) {
            parts.append("\(topEmotion.key) mood and atmosphere")
        }

        let charNames = sceneCharacters(scene: scene).prefix(3)
        if !charNames.isEmpty {
            parts.append("featuring characters in the scene")
        }

        parts.append("dramatic lighting, cinematic color grading, movie quality, 16:9 widescreen composition")

        return parts.joined(separator: ", ")
    }

    /// Sanitize a name for filesystem use
    static func sanitizeFilename(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        sanitized = sanitized.unicodeScalars.filter { allowedChars.contains($0) }.map { String($0) }.joined()
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        return sanitized.isEmpty ? "scene" : String(sanitized.prefix(80))
    }

    /// Get the primary character's base image as base64 for AI reference.
    /// Delegates to CharacterReferenceHelper in DirectorsChairViews.
    static func characterReferenceImage(
        scene: DirectorsChairCore.Scene,
        characters: [Character],
        projectBasePath: URL?
    ) -> (base64: String, mimeType: String)? {
        CharacterReferenceHelper.referenceImage(
            forScene: scene,
            characters: characters,
            projectDirectory: projectBasePath
        )
    }

    /// Emotion name → Color mapping
    static func emotionColor(_ emotion: String) -> Color {
        switch emotion.lowercased() {
        case "joy", "happiness", "happy":     return .yellow
        case "sadness", "sad", "melancholy":  return .blue
        case "anger", "angry", "rage":        return .red
        case "fear", "anxiety", "tension":    return .purple
        case "surprise", "shock":             return .orange
        case "love", "romance":               return .pink
        case "hope", "optimism":              return .green
        case "disgust":                       return .brown
        default:                              return .gray
        }
    }
}
