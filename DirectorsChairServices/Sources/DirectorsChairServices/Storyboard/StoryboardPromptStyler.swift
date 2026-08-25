// DirectorsChairServices/Storyboard/StoryboardPromptStyler.swift
//
// The locked storyboard look (DC-0062, owner decision 2026-08-25: one
// model, ONE style). Callers hand over plain scene/shot language; this
// is the only place style words exist, so every frame in every project
// shares a line language — and swapping the look later is a one-file
// change, not a hunt.

import Foundation

public enum StoryboardPromptStyler {

    /// Words the style is anchored on. "ink sketch" is deliberate: it is
    /// the trigger phrase of the licensed storyboard adapter
    /// (style4_storyboard, resale-permitting) so an offline-fused
    /// checkpoint later activates with the SAME prompts — zero caller
    /// churn on that upgrade.
    public static let requiredMarkers = ["ink sketch", "storyboard"]

    static let styleLead = """
    ink sketch storyboard panel: rough monochrome ink and pencil linework, \
    loose confident strokes, clear cinematic staging, white paper background.
    """

    static let styleTail = """
    Hand-drawn film previsualization sketch. Black-and-white line art only — \
    no photorealism, no color, no painterly rendering, no text captions.
    """

    /// Subjects beyond this are cut from the END — a shot description
    /// leads with what matters (framing, subject, action), and the small
    /// text encoder reads the front best.
    public static let subjectCharacterBudget = 1_200

    /// The one composition point: locked lead + the caller's subject
    /// (+ optional framing notes) + locked tail.
    public static func prompt(subject: String, notes: String? = nil) -> String {
        var body = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.count > subjectCharacterBudget {
            body = String(body.prefix(subjectCharacterBudget)) + "…"
        }
        var lines = [styleLead, "SHOT: \(body)"]
        if let notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines),
           !notes.isEmpty {
            lines.append("FRAMING: \(notes)")
        }
        lines.append(styleTail)
        return lines.joined(separator: "\n")
    }
}
