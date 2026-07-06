// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/ShotPromptBuilder.swift
//
// WS6.2 — shot image-generation prompt construction as PURE functions,
// extracted from CinematographyView+ShotPreview so the prompt text is
// unit-testable and views hold no prompt strings.

import Foundation
import DirectorsChairCore

public enum ShotPromptBuilder {

    static func previewPrompt(shot: Shot, scene: DCScene?, locations: [Location], characters: [Character]) -> String {
        var parts: [String] = []

        // Base cinematic instruction
        parts.append("Cinematic film still, professional cinematography")

        // Shot type and framing
        parts.append("\(shot.shotType) shot")

        // Camera angle
        parts.append("\(shot.cameraAngle) angle")

        // Lens characteristics
        if let lens = shot.lensMm {
            if lens <= 24 {
                parts.append("wide angle lens, expansive view")
            } else if lens >= 85 {
                parts.append("telephoto lens, compressed perspective, shallow depth of field")
            } else if lens >= 50 {
                parts.append("natural perspective, cinematic depth")
            }
        }

        // Aperture / depth of field
        if shot.aperture.contains("1.") || shot.aperture.contains("2.") {
            parts.append("shallow depth of field, bokeh background")
        } else if shot.aperture.contains("8") || shot.aperture.contains("11") || shot.aperture.contains("16") {
            parts.append("deep focus, sharp throughout")
        }

        // Movement hint
        if shot.movement != "Static" {
            parts.append("sense of \(shot.movement.lowercased()) movement")
        }

        // Shot description
        if !shot.description.isEmpty {
            parts.append(shot.description)
        }

        // Scene context
        if let scene = scene {
            // Location — detailed description
            if let locationName = scene.location, !locationName.isEmpty {
                if let location = locations.first(where: { $0.name.lowercased() == locationName.lowercased() }) {
                    var locDesc = "Location: \(location.name)"
                    if !location.locationType.isEmpty {
                        locDesc += " (\(location.locationType))"
                    }
                    if !location.description.isEmpty {
                        locDesc += " — \(location.description.prefix(200))"
                    }
                    parts.append(locDesc)
                } else {
                    parts.append("set in \(locationName)")
                }
            }

            // Scene description
            if !scene.description.isEmpty {
                parts.append(scene.description.prefix(200).description)
            }

            // Characters in scene — detailed descriptions for visual accuracy
            let sceneCharacters = charactersInScene(scene, from: characters)
            if !sceneCharacters.isEmpty {
                let charDescriptions = sceneCharacters.prefix(3).map { char -> String in
                    var desc = char.name
                    let physicalDesc = characterDescription(char)
                    if !physicalDesc.isEmpty {
                        desc += " (\(physicalDesc.prefix(150)))"
                    }
                    if let costumes = char.costumes, let first = costumes.first {
                        desc += ", wearing \(first.name)"
                    }
                    return desc
                }
                parts.append("Characters: \(charDescriptions.joined(separator: "; "))")
            }

            // Sample dialogue for mood
            if let firstDialogue = scene.dialogues.first, !firstDialogue.text.isEmpty {
                parts.append("mood: \"\(firstDialogue.text.prefix(80))...\"")
            }
        }

        // Style and format
        parts.append("Dramatic lighting, film grain, cinematic color grading, 35mm film aesthetic, photorealistic")
        parts.append("Widescreen 16:9 landscape composition, full frame edge-to-edge, no black bars or letterboxing")

        return parts.joined(separator: ". ")
    }

    static func promptSummary(shot: Shot, scene: DCScene?) -> String {
        var summary: [String] = []
        summary.append("\(shot.shotType) • \(shot.cameraAngle)")
        if let scene = scene {
            summary.append(scene.name)
        }
        return summary.joined(separator: " • ")
    }

    static func charactersInScene(_ scene: DCScene, from characters: [Character]) -> [Character] {
        let characterNames = Set(scene.dialogues.map { $0.character })
        return characters.filter { characterNames.contains($0.name) }
    }

    /// Build a brief physical description from character attributes
    static func characterDescription(_ char: Character) -> String {
        var parts: [String] = []

        // Use about field if available
        if !char.about.isEmpty {
            return char.about
        }

        // Otherwise build from physical attributes
        if char.age > 0 {
            parts.append("\(char.age) year old")
        }

        if !char.gender.isEmpty && char.gender != "neutral" {
            parts.append(char.gender)
        }

        if !char.build.isEmpty && char.build != "Average" {
            parts.append(char.build.lowercased())
        }

        if !char.hairColor.isEmpty && !char.hairColor.hasPrefix("#") {
            parts.append("\(char.hairColor) hair")
        } else if !char.hairStyle.isEmpty {
            parts.append("\(char.hairStyle) hair")
        }

        if !char.distinguishingFeatures.isEmpty {
            parts.append(char.distinguishingFeatures)
        }

        return parts.joined(separator: ", ")
    }
    /// Video keyframe prompt for a position within a shot (0 = opening frame,
    /// 1 = final frame).
    public static func keyframePrompt(shot: Shot, scene: DCScene?, characterNames: [String],
                                      characters: [Character], locations: [Location],
                                      position: Double) -> String {
        var parts: [String] = []
        parts.append("A single cinematic film frame. \(shot.shotType) shot, \(shot.cameraAngle) angle.")
        if let lens = shot.lensMm {
            parts.append("\(lens)mm lens, \(shot.aperture).")
        }
        if !shot.description.isEmpty {
            parts.append(shot.description)
        }
        if let currentScene = scene {
            if !characterNames.isEmpty {
                let charDescs = characterNames.compactMap { name -> String? in
                    guard let char = characters.first(where: { $0.name == name }) else { return name }
                    var desc = name
                    desc += ", age \(char.age)"
                    if !char.gender.isEmpty { desc += ", \(char.gender)" }
                    if !char.about.isEmpty {
                        desc += ", \(String(char.about.prefix(100)))"
                    } else {
                        if !char.build.isEmpty && char.build != "Average" { desc += ", \(char.build.lowercased())" }
                        if !char.hairColor.isEmpty && !char.hairColor.hasPrefix("#") { desc += ", \(char.hairColor) hair" }
                        else if !char.hairStyle.isEmpty { desc += ", \(char.hairStyle) hair" }
                        if !char.distinguishingFeatures.isEmpty { desc += ", \(char.distinguishingFeatures)" }
                    }
                    if let costumes = char.costumes, let first = costumes.first {
                        desc += ", wearing \(first.name)"
                    }
                    return desc
                }
                parts.append("Characters: \(charDescs.joined(separator: "; "))")
            }
            if let loc = currentScene.location, !loc.isEmpty {
                if let location = locations.first(where: { $0.name.lowercased() == loc.lowercased() }) {
                    var locDesc = "Location: \(location.name)"
                    if !location.locationType.isEmpty { locDesc += " (\(location.locationType))" }
                    if !location.description.isEmpty { locDesc += " — \(location.description.prefix(200))" }
                    parts.append(locDesc)
                } else {
                    parts.append("Location: \(loc)")
                }
            }
            if !currentScene.props.isEmpty {
                parts.append("Props: \(currentScene.props.joined(separator: ", "))")
            }
        }
        if position == 0.0 {
            parts.append("This is the opening frame of the shot.")
        } else if position == 1.0 {
            parts.append("This is the final frame of the shot.")
        } else {
            parts.append("This frame is at \(String(format: "%.0f%%", position * 100)) through the shot.")
        }
        parts.append("Dramatic lighting, cinematic quality, professional filmmaking, photorealistic.")
        return parts.joined(separator: "\n")
    }

    /// Emotion-tag inference prompt for a dialogue line (TTS delivery hints).
    public static func dialogueEmotionPrompt(characterName: String, text: String) -> String {
        """
        Analyze the emotion/tone of this dialogue line spoken by \(characterName):

        "\(text)"

        Return ONLY a comma-separated list of 1-3 emotion tags (single words, lowercase).
        Examples: angry, sarcastic, tender, fearful, joyful, melancholic, anxious, determined, playful, bitter, hopeful, resigned, threatening, pleading, nostalgic, disgusted, confused, amused, defiant, vulnerable
        Do not include any other text, explanation, or formatting.
        """
    }

}
