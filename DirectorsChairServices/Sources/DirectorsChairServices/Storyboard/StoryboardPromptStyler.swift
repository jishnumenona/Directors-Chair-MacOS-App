// DirectorsChairServices/Storyboard/StoryboardPromptStyler.swift
//
// The on-device looks (DC-0062 one model; DC-0066 two looks: Sketch and
// Comic). Callers hand over plain subject language and a purpose; this
// is the only place style words exist, so every drawing in a project
// shares a line language — and tuning the look is a one-file change.
//
// Written for how Z-Image Turbo actually reads prompts (researched and
// A/B-rendered 2026-08-25, seed 42, against the sampler frames):
//  • It is CFG-distilled — NEGATIVES ARE IGNORED. "No colour, no
//    photorealism" did nothing except inject the very concepts; every
//    constraint here is stated as what TO draw.
//  • Medium first, then subject, then framing, then the medium again as
//    a closing constraint — long, precise, structured; not poetic.
//  • The word "storyboard" on its own makes it draw a multi-panel grid;
//    "one frame filling the whole page" keeps it to a single drawing.
//  • Anything in quotes or that reads like a caption gets lettered onto
//    the page; camera/lens words get drawn as objects. Subjects arrive
//    already cleaned (StoryboardSubjects.plainSubject).

import Foundation

public enum StoryboardPromptStyler {

    /// Words each look is anchored on — tests pin that they survive every
    /// composition. "ink sketch" is deliberate: it is the trigger phrase
    /// of the licensed storyboard adapter (style4_storyboard), so an
    /// offline-fused checkpoint later activates with the SAME prompts.
    public static func requiredMarkers(for style: VisualStyle) -> [String] {
        switch style {
        case .sketch: return ["ink sketch", "whole page"]
        case .comic: return ["comic book panel", "whole page"]
        }
    }

    /// The sketch look's markers — the default look's anchors.
    public static let requiredMarkers = requiredMarkers(for: .sketch)

    static func lead(for style: VisualStyle) -> String {
        switch style {
        case .sketch:
            return "A single hand-drawn ink sketch on white paper, one frame filling the whole page: " +
                "loose confident black ink linework with light pencil construction lines and sparse " +
                "hatching for shadow, drawn the way a professional film storyboard artist sketches a " +
                "shot for the director."
        case .comic:
            return "A single comic book panel filling the whole page, drawn by a professional comic " +
                "artist: bold clean black ink outlines, confident inked shadows, flat printed colors " +
                "with subtle halftone dot shading, crisp readable composition."
        }
    }

    static func tail(for style: VisualStyle) -> String {
        switch style {
        case .sketch:
            return "Monochrome black ink on white paper, every surface left as clean line and " +
                "hatching; the page holds the drawing only."
        case .comic:
            return "Printed color comic art, one full-page panel, correct human anatomy; the page " +
                "holds the artwork only."
        }
    }

    /// How each purpose introduces its subject.
    static func subjectLead(for purpose: VisualPurpose) -> String {
        switch purpose {
        case .character: return "Character design study of "
        case .costume: return "Costume design sheet for "
        case .shot, .scene, .location, .moodboard: return "The drawing shows: "
        case .edit: return ""
        }
    }

    /// What the engine should take from the reference pictures (DC-0068).
    /// Continuity purposes follow the reference's own look — a photo
    /// character turned to profile must stay a photo — so those skip the
    /// Sketch/Comic lead; storytelling purposes keep the look and borrow
    /// only who and where.
    static func referenceClause(for purpose: VisualPurpose, count: Int) -> String? {
        guard count > 0 else { return nil }
        switch purpose {
        case .character:
            return "The same person as in the reference picture — same face, hair, skin and build — drawn in exactly the same style as the reference."
        case .costume:
            return count > 1
                ? "The person from the first reference picture wearing the garments shown in the other reference pictures, in the same style as the first reference."
                : "The same person as in the reference picture, in the same style as the reference."
        case .location:
            return "The same place as in the reference picture — same architecture, layout and details."
        case .shot, .scene, .moodboard:
            return "The people and places match the reference pictures."
        case .edit:
            return nil
        }
    }

    /// The app's "kind:name" reference labels as one sentence per picture,
    /// so a scene composed from a location, two characters and a prop
    /// tells the model which picture carries whom (klein reads "the first
    /// picture", "the second picture" reliably; it cannot read our labels).
    public static func labelledReferenceClause(_ labels: [String]) -> String? {
        let sentences = labels.enumerated().compactMap { index, label -> String? in
            let parts = label.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            let kind = parts.first?.lowercased() ?? ""
            let ordinal = Self.ordinal(index + 1)
            switch kind {
            case "location":
                let name = parts.dropFirst().joined(separator: ":")
                return "The \(ordinal) picture is the location\(name.isEmpty ? "" : " \(name)"): keep its architecture, layout and details."
            case "character":
                let name = parts.dropFirst().joined(separator: ":")
                return "The \(ordinal) picture is \(name.isEmpty ? "a character" : name): keep this person's face, hair, skin and build exactly."
            case "costume":
                let who = parts.count > 1 ? parts[1] : ""
                let outfit = parts.count > 2 ? parts[2...].joined(separator: ":") : ""
                return "The \(ordinal) picture is the costume\(outfit.isEmpty ? "" : " \(outfit)")\(who.isEmpty ? "" : " worn by \(who)"): keep these garments."
            case "prop":
                let name = parts.dropFirst().joined(separator: ":")
                return "The \(ordinal) picture is the prop\(name.isEmpty ? "" : " \(name)"): keep its exact design."
            default:
                return label.isEmpty ? nil : "The \(ordinal) picture shows \(label)."
            }
        }
        guard !sentences.isEmpty else { return nil }
        // Several pictures tempt the model into a multi-panel page; say
        // what the page IS instead (positives only — negatives are ignored).
        let opening = sentences.count > 1
            ? "Compose one single frame, one continuous scene across the whole page, in which all of these appear together. "
            : ""
        return opening + sentences.joined(separator: " ")
    }

    static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "first"
        case 2: return "second"
        case 3: return "third"
        case 4: return "fourth"
        default: return "\(n)th"
        }
    }

    /// Purposes whose look is dictated by the reference, not by Settings.
    static func followsReferenceStyle(_ purpose: VisualPurpose, referenceCount: Int) -> Bool {
        referenceCount > 0 && [.character, .costume, .location, .edit].contains(purpose)
    }

    /// The framing a purpose gets when the caller supplies none — the
    /// difference between a costume sheet and a random picture of a coat.
    public static func defaultFraming(for purpose: VisualPurpose) -> String {
        switch purpose {
        case .shot:
            return "Eye-level view with the subject clearly staged in the frame."
        case .scene:
            return "Wide establishing view at eye level, the whole setting visible."
        case .location:
            return "Wide establishing view of the place at eye level, its layout and character readable."
        case .character:
            return "Front view, head-and-shoulders portrait centered on the page, neutral expression, plain white background."
        case .costume:
            return "Full figure standing in a front view from head to feet, centered on the page, arms relaxed, plain white background, garments drawn clearly with fabric folds and seam detail."
        case .moodboard:
            return "One clear composition filling the page."
        case .edit:
            return "Keep everything not mentioned exactly as it is in the picture."
        }
    }

    /// Subjects beyond this are cut from the END — a description leads
    /// with what matters, and the text encoder reads the front best
    /// (512-token budget shared with the style lines).
    public static let subjectCharacterBudget = 1_200

    /// The one composition point: medium lead + purpose-led subject +
    /// framing (caller's notes or the purpose default) + medium tail.
    public static func prompt(subject: String, notes: String? = nil,
                              purpose: VisualPurpose = .shot,
                              style: VisualStyle = .sketch,
                              referenceCount: Int = 0,
                              referenceLabels: [String] = []) -> String {
        var body = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.count > subjectCharacterBudget {
            body = String(body.prefix(subjectCharacterBudget)) + "…"
        }
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let framing = trimmedNotes.isEmpty
            ? defaultFraming(for: purpose)
            : Self.framingSentence(trimmedNotes)
        // An edit is the instruction itself plus the keep-everything-else
        // rule; the picture being edited supplies the look.
        if purpose == .edit {
            return [body, framing].joined(separator: "\n")
        }
        var lines: [String] = []
        let referenceLed = followsReferenceStyle(purpose, referenceCount: referenceCount)
        if !referenceLed { lines.append(lead(for: style)) }
        lines.append(subjectLead(for: purpose) + body)
        if let named = labelledReferenceClause(referenceLabels) {
            lines.append(named)
        } else if let clause = referenceClause(for: purpose, count: referenceCount) {
            lines.append(clause)
        }
        lines.append(framing)
        if !referenceLed { lines.append(tail(for: style)) }
        return lines.joined(separator: "\n")
    }

    public static func prompt(_ spec: StoryboardFrameSpec, style: VisualStyle) -> String {
        prompt(subject: spec.subject, notes: spec.notes,
               purpose: spec.purpose, style: style,
               referenceCount: spec.references.count,
               referenceLabels: spec.referenceLabels)
    }

    /// Caller notes become a "Framing:" sentence — the model treats a
    /// labelled clause as direction rather than as something to draw.
    static func framingSentence(_ notes: String) -> String {
        var sentence = notes
        if !sentence.lowercased().hasPrefix("framing:") {
            sentence = "Framing: " + sentence
        }
        if let last = sentence.last, !".!?".contains(last) { sentence += "." }
        return sentence
    }
}
