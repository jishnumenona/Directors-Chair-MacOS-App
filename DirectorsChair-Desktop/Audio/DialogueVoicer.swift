//
//  DialogueVoicer.swift
//  DirectorsChair-Desktop
//
//  The ONE place that turns a dialogue line into a speech request and a
//  saved take (DC-0081). Before this the Timeline's per-line button and the
//  assistant's generate_dialogue_audio each carried their own copy of the
//  casting rule; the Playback "voice all dialogue" batch is the third
//  caller, so the rule lives here and all three read it.
//

import Foundation
import DirectorsChairCore
import DirectorsChairServices

enum DialogueVoicer {

    /// The provider call, injectable so tests never touch the network.
    typealias Generate = @Sendable (SpeechGenerationRequest) async throws -> Data

    /// Where takes live, relative to the project folder.
    static let audioDirectory = "assets/audio/dialogues"

    /// Gateway parity (services/cost.py): $0.30 per 1k characters.
    static func estimate(characters: Int) -> Double {
        0.30 * Double(max(1, characters)) / 1000.0
    }

    /// The spoken text: script HTML stripped, whitespace trimmed.
    static func plainText(_ text: String) -> String {
        var result = text
        if result.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<"),
           let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The character record a line belongs to, by name (case-insensitive).
    static func character(named name: String, in project: Project) -> Character? {
        project.characters.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Voice casting: the character's cast voice, else the gender default.
    static func voiceName(for character: Character?) -> String {
        character?.voice ?? (character?.gender.lowercased() == "female" ? "Kore" : "Charon")
    }

    /// The emotion direction: the character's voice style plus the line's tags.
    static func emotion(for character: Character?, tags: [String]) -> String? {
        var parts: [String] = []
        if let style = character?.voiceStyle, !style.isEmpty { parts.append(style) }
        parts.append(contentsOf: tags)
        return parts.isEmpty ? nil : "Say \(parts.joined(separator: ", "))"
    }

    /// The request for one line. `text` is already plain.
    static func request(text: String, characterName: String, tags: [String],
                        character: Character?, provider: AIProvider) -> SpeechGenerationRequest {
        SpeechGenerationRequest(
            text: text,
            provider: provider,
            voiceName: voiceName(for: character),
            emotion: emotion(for: character, tags: tags),
            characterName: characterName,
            voiceTone: character?.voiceTone,
            voicePersonality: character?.voicePersonality,
            voicePace: character?.voicePace,
            voiceAccent: character?.voiceAccent,
            voiceAge: character?.voiceAge)
    }

    /// The take's path as stored on `Dialogue.audioFilePath`.
    static func relativePath(for uuid: String) -> String {
        "\(audioDirectory)/\(uuid).wav"
    }

    /// The takes folder next to the project file (created on demand).
    static func directory(besides projectFile: URL) throws -> URL {
        let directory = projectFile.deletingLastPathComponent()
            .appendingPathComponent(audioDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
