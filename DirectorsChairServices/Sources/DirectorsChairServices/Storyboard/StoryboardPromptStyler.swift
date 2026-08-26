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
        }
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
                              style: VisualStyle = .sketch) -> String {
        var body = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.count > subjectCharacterBudget {
            body = String(body.prefix(subjectCharacterBudget)) + "…"
        }
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let framing = trimmedNotes.isEmpty
            ? defaultFraming(for: purpose)
            : Self.framingSentence(trimmedNotes)
        return [
            lead(for: style),
            subjectLead(for: purpose) + body,
            framing,
            tail(for: style),
        ].joined(separator: "\n")
    }

    public static func prompt(_ spec: StoryboardFrameSpec, style: VisualStyle) -> String {
        prompt(subject: spec.subject, notes: spec.notes,
               purpose: spec.purpose, style: style)
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
