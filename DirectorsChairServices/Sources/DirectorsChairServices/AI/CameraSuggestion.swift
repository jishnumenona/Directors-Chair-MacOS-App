// DirectorsChairServices/AI/CameraSuggestion.swift
//
// DC-0094: a one-line camera direction the AI suggests for a shot, shown as
// the hint of "Camera in your own words" (Tab accepts it). Built from the
// shot's own facts — description, framing chips, scene, location, cast —
// through the account's text provider (on-device = free). One call per set
// of facts per session; "Suggest again" forgets the cached line.

import DirectorsChairCore
import Foundation

public enum CameraSuggestion {
    public static let systemPrompt =
        "You are a feature-film cinematographer. Reply with ONE sentence of plain English, at most 25 words, " +
        "describing where the camera is and what it sees for this shot. No lens numbers, no jargon, no quotes, no preamble."

    /// What the model is told about the shot — pure, so it is tested.
    public static func prompt(shot: Shot, scene: Scene?, location: Location?, characters: [Character]) -> String {
        var lines: [String] = []
        let description = shot.description.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("Shot: " + (description.isEmpty ? "(no description yet)" : description))
        var framing: [String] = []
        if !shot.shotType.isEmpty { framing.append("\(shot.shotType) shot") }
        if !shot.cameraAngle.isEmpty { framing.append("\(shot.cameraAngle) angle") }
        if let lens = shot.lensMm { framing.append("\(lens)mm lens") }
        if !shot.movement.isEmpty && shot.movement != "Static" { framing.append("camera movement: \(shot.movement.lowercased())") }
        if !framing.isEmpty { lines.append("Framing already chosen: " + framing.joined(separator: ", ")) }
        if let scene {
            var sceneLine = "Scene: \(scene.name)"
            if let time = scene.timeOfDay, !time.isEmpty { sceneLine += ", \(time)" }
            lines.append(sceneLine)
        }
        if let location {
            var locationLine = "Location: \(location.name)"
            if !location.description.isEmpty { locationLine += " — \(location.description.prefix(160))" }
            lines.append(locationLine)
        }
        if !characters.isEmpty {
            lines.append("Characters in the shot: " + characters.map(\.name).joined(separator: ", "))
        }
        lines.append("Write the camera direction now.")
        return lines.joined(separator: "\n")
    }

    /// The model's reply as one clean line: first sentence only, quotes and
    /// "Camera:"-style preambles stripped, capped at 200 characters.
    public static func clean(_ raw: String) -> String {
        var line = raw.split(whereSeparator: \.isNewline).map(String.init)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        line = line.trimmingCharacters(in: .whitespaces)
        for prefix in ["Camera direction:", "Camera:", "Suggestion:", "Direction:"] where line.lowercased().hasPrefix(prefix.lowercased()) {
            line = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'`"))
        if line.count > 200 { line = String(line.prefix(200)) }
        return line
    }

    /// The facts a suggestion depends on; a change in any of them is a new ask.
    public static func cacheKey(shot: Shot) -> String {
        "\(shot.id)|\(shot.description)|\(shot.shotType)|\(shot.cameraAngle)|\(shot.movement)|\(shot.lensMm ?? 0)"
    }

    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [String: String] = [:]
        subscript(key: String) -> String? {
            get { lock.lock(); defer { lock.unlock() }; return entries[key] }
            set { lock.lock(); entries[key] = newValue; lock.unlock() }
        }
    }
    private static let cache = Cache()

    /// The suggestion for this shot — cached per set of facts for the session.
    public static func suggest(shot: Shot, scene: Scene?, location: Location?, characters: [Character],
                               client: AIServiceClient = .shared) async throws -> String {
        let key = cacheKey(shot: shot)
        if let hit = cache[key] { return hit }
        let request = TextGenerationRequest(
            prompt: prompt(shot: shot, scene: scene, location: location, characters: characters),
            provider: AIProviderSelection.shared.provider(for: .text),
            maxTokens: 80,
            temperature: 0.6,
            systemPrompt: systemPrompt)
        let response = try await client.generateText(request)
        let line = clean(response.text)
        if !line.isEmpty { cache[key] = line }
        return line
    }

    /// "Suggest again": drop the cached line so the next ask is fresh.
    public static func forget(shot: Shot) {
        cache[cacheKey(shot: shot)] = nil
    }
}
