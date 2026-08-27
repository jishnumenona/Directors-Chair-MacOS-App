// DirectorsChairServices/Storyboard/VisualBriefWriter.swift
//
// Turns a screenwriter's action line into what a camera sees (DC-0068
// follow-up, owner report 2026-08-27). Image models draw prose
// literally: "Dana lets it go with a warning she half-swallows" becomes
// a speech bubble of garbage lettering; a slug line becomes a caption.
// A shot brief must therefore be VISUAL — who is where, doing what with
// hands and faces, in what light — and that translation is a language
// task, so it goes through the user's text service (the on-device Qwen
// model when selected). Anything that fails or comes back as junk falls
// back to the original text: never a worse frame than before.

import Foundation

public enum VisualBriefWriter {

    /// The rewriting function — the user's text service by default; tests
    /// and previews swap in a script.
    nonisolated(unsafe) public static var rewrite: @Sendable (String) async throws -> String = { subject in
        let request = TextGenerationRequest(
            prompt: prompt(for: subject),
            provider: AIProviderSelection.shared.provider(for: .text),
            maxTokens: 160,
            temperature: 0.2,
            systemPrompt: system)
        return try await AIServiceClient.shared.generateText(request).text
    }

    /// Subjects shorter than this are already visual ("A lighthouse on a cliff").
    public static let minimumLengthToRewrite = 60

    public static let system = """
    You are a storyboard artist's assistant. You turn a film shot into ONE description of what is visible \
    in a single still frame, for an illustrator who has not read the script.
    Rules: present tense; describe only what can be seen — who is where, what their hands, bodies and faces \
    are doing, the setting, objects, and light; keep every character's name and what they wear; \
    two or three sentences, at most 70 words; plain sentences, no headings, no lists, no quotation marks. \
    Never include speech, dialogue, captions, sound, thoughts, backstory or camera terms — turn any spoken \
    line into the expression or gesture it would produce.
    """

    static func prompt(for subject: String) -> String {
        "Shot:\n\(subject)\n\nWhat the frame shows:"
    }

    /// The visual description of a subject, or the subject itself when it
    /// is short, when the text service is unavailable, or when the reply
    /// is not a usable description. The subject's factual lines (setting,
    /// place, who wears what) are re-attached after the rewrite: small
    /// models drop them, and facts are not prose — they never letter.
    public static func visualDescription(of subject: String) async -> String {
        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumLengthToRewrite else { return trimmed }
        do {
            let reply = try await rewrite(trimmed)
            guard let visual = accepted(reply) else { return trimmed }
            let facts = factLines(in: trimmed)
            return facts.isEmpty ? visual : visual + " " + facts.joined(separator: " ")
        } catch {
            return trimmed
        }
    }

    /// The "Setting: …", "The place: …" and "People in the frame: …"
    /// sentences StoryboardSubjects writes, if present.
    static func factLines(in subject: String) -> [String] {
        let markers = ["Setting:", "The place:", "People in the frame:"]
        var lines: [String] = []
        for sentence in subject.components(separatedBy: ". ") {
            let s = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if markers.contains(where: { s.hasPrefix($0) }) {
                lines.append(s.hasSuffix(".") ? s : s + ".")
            }
        }
        return lines
    }

    /// A reply is usable when it is one plain paragraph of sensible length
    /// with no refusal, no markdown scaffolding and no quoted speech.
    static func accepted(_ reply: String) -> String? {
        var text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("what the frame shows:") {
            text = String(text.dropFirst("what the frame shows:".count)).trimmingCharacters(in: .whitespaces)
        }
        text = text.replacingOccurrences(of: #"^["“”']+|["“”']+$"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard text.count >= 20, text.count <= 700 else { return nil }
        let lower = text.lowercased()
        let refusals = ["i can't", "i cannot", "as an ai", "i'm sorry", "i am sorry"]
        guard !refusals.contains(where: lower.hasPrefix) else { return nil }
        guard !text.contains("\""), !text.contains("“"), !text.contains("#"), !text.contains("- ") else { return nil }
        return text
    }
}
