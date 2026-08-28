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
    Show only the people the shot names — never add a person, a figure, a crowd or a silhouette the shot \
    does not mention; a shot that names one person shows one person. \
    Never include speech, dialogue, captions, sound, thoughts, backstory or camera terms — turn any spoken \
    line into the expression or gesture it would produce.
    """

    static func prompt(for subject: String) -> String {
        guard let cast = castLine(in: subject) else { return "Shot:\n\(subject)\n\nWhat the frame shows:" }
        let who = cast.names.isEmpty ? "" : " — \(cast.names.joined(separator: " and "))"
        let count = ["one person", "two people", "three people"][min(cast.count, 3) - 1]
        return "Shot:\n\(subject)\n\nWhat the frame shows (exactly \(count)\(who), and no one else):"
    }

    /// The head count and names the subject's cast line declares, if any.
    static func castLine(in subject: String) -> (count: Int, names: [String])? {
        let counts = ["One person in the frame:": 1, "Two people in the frame:": 2, "Three people in the frame:": 3]
        for (marker, count) in counts {
            guard let range = subject.range(of: marker) else { continue }
            let rest = subject[range.upperBound...]
            let names = rest.components(separatedBy: ";").compactMap { item -> String? in
                let head = item.split(separator: ":").first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
                let name = head.split(separator: "(").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? head
                return name.isEmpty || name.count > 40 ? nil : name
            }
            return (count, Array(names.prefix(count)))
        }
        return nil
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
            guard let usable = accepted(reply),
                  let visual = accepted(keepingToTheCast(usable, subject: trimmed)) else { return trimmed }
            let facts = factLines(in: trimmed)
            return facts.isEmpty ? visual : visual + " " + facts.joined(separator: " ")
        } catch {
            return trimmed
        }
    }

    /// The reply without any sentence that names someone the shot did not
    /// (DC-0072: "Teo at the cottage wall" came back with "Noor and Idris
    /// follow behind him" — the writer invented walkers from the setting).
    /// A name is a capitalised word that occurs nowhere in the subject and
    /// is not an ordinary sentence opener; a sentence with one is dropped.
    /// Conservative on purpose: a dropped legitimate sentence costs a
    /// detail, an invented person costs the frame.
    static func keepingToTheCast(_ reply: String, subject: String) -> String {
        let known = Set(subject.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty })
        // Company the head count rules out ("two other figures", "they")
        // is dropped too — the writer rarely names the people it invents.
        let crowdCues: NSRegularExpression? = castLine(in: subject).flatMap { cast in
            let words: [String]
            switch cast.count {
            case 1: words = ["two", "three", "four", "five", "several", "both", "other", "others", "another", "second",
                             "people", "figures", "men", "women", "children", "group", "crowd", "couple", "companions",
                             "companion", "strangers", "stranger", "walkers", "silhouettes", "they", "them", "their", "themselves"]
            case 2: words = ["three", "four", "five", "several", "third", "people", "figures", "group", "crowd",
                             "others", "strangers", "walkers", "silhouettes"]
            default: words = ["four", "five", "several", "fourth", "crowd", "others", "strangers"]
            }
            return try? NSRegularExpression(pattern: "\\b(" + words.joined(separator: "|") + ")\\b", options: [.caseInsensitive])
        }
        let sentences = reply.split(omittingEmptySubsequences: true) { ".!?".contains($0) }
        var kept: [String] = []
        for raw in sentences {
            let sentence = raw.trimmingCharacters(in: .whitespaces)
            guard !sentence.isEmpty else { continue }
            let words = sentence.split(separator: " ").map(String.init)
            var invented = false
            for word in words {
                let cleaned = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                    .replacingOccurrences(of: "'s", with: "").replacingOccurrences(of: "’s", with: "")
                guard cleaned.count >= 2, let first = cleaned.first, first.isUppercase,
                      cleaned.dropFirst().allSatisfy({ $0.isLetter }) else { continue }
                let lower = cleaned.lowercased()
                if !known.contains(lower) && !ordinaryCapitalisedWords.contains(lower) { invented = true; break }
            }
            if !invented, let cues = crowdCues,
               cues.firstMatch(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) != nil {
                invented = true
            }
            if !invented { kept.append(sentence + ".") }
        }
        return kept.joined(separator: " ")
    }

    /// Words that open a sentence capitalised without being anyone's name.
    static let ordinaryCapitalisedWords: Set<String> = [
        "the", "a", "an", "in", "on", "at", "by", "from", "with", "without", "behind", "beside", "before",
        "above", "below", "through", "under", "over", "beyond", "between", "across", "along", "around",
        "against", "inside", "outside", "near", "far", "beneath", "up", "down", "out", "off", "into", "onto",
        "upon", "toward", "towards", "amid", "among", "after", "until", "since", "during", "despite",
        "his", "her", "their", "its", "he", "she", "they", "it", "there", "here", "this", "that", "these",
        "those", "one", "two", "three", "four", "both", "all", "no", "only", "then", "now", "still", "just",
        "nothing", "everything", "someone", "nobody", "each", "every", "some", "another", "other", "half",
        "most", "much", "many", "few", "little", "less", "more", "not", "nor", "and", "but", "or", "so",
        "yet", "as", "if", "when", "while", "where", "whose", "which", "what", "who", "how", "why",
        "because", "although", "though", "once", "light", "sunlight", "daylight", "lamplight", "firelight",
        "fog", "mist", "rain", "wind", "snow", "sun", "moon", "moonlight", "shadow", "shadows", "water",
        "waves", "sea", "sky", "cloud", "clouds", "smoke", "steam", "dust", "sand", "mud", "grass", "rock",
        "rocks", "stone", "morning", "dawn", "dusk", "night", "evening", "afternoon", "old", "new", "young",
        "small", "large", "big", "tall", "short", "dark", "bright", "pale", "cold", "warm", "wet", "dry",
        "soft", "hard", "rough", "smooth", "thick", "thin", "heavy", "grey", "gray", "black", "white", "red",
        "blue", "green", "yellow", "brown", "gold", "silver", "beside", "close", "low", "high", "wide",
    ]

    /// The "Setting: …", "The place: …" and "People in the frame: …"
    /// sentences StoryboardSubjects writes, if present.
    static func factLines(in subject: String) -> [String] {
        let markers = ["Setting:", "The place:", "People in the frame:",
                       "One person in the frame:", "Two people in the frame:", "Three people in the frame:"]
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
