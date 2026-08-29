// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/SpokenLength.swift
//
// How long a line takes to say — the pure estimate behind the Timeline's
// "Reset to spoken length" (owner 2026-08-29). Kept apart from
// DurationEstimator, whose per-punctuation bonuses size the default block:
// this is the plain reading-rate figure a director expects to see.

import Foundation

public enum SpokenLength {
    /// No line is shorter than this (seconds).
    public static let minimumSeconds: CGFloat = 0.5

    /// Breath taken at the end of every sentence (seconds).
    public static let sentencePause: CGFloat = 0.3

    /// Seconds a line takes to say at a reading rate: word count ÷ WPM × 60,
    /// plus a short pause per sentence, never under `minimumSeconds`.
    /// HTML is stripped first; a non-positive WPM falls back to the timeline default.
    public static func seconds(forText text: String?, wordsPerMinute: Int) -> CGFloat {
        let plain = DurationEstimator.htmlToPlainText(text)
        let words = DurationEstimator.countWords(in: plain)
        let wpm = wordsPerMinute > 0 ? wordsPerMinute : TimelineWPMConstants.defaultWPM
        let speaking = CGFloat(words) / CGFloat(wpm) * 60
        let pauses = CGFloat(sentenceCount(in: plain)) * sentencePause
        return max(minimumSeconds, speaking + pauses)
    }

    /// Sentences in a plain-text line: each run of . ! ? … counts once, so an
    /// ellipsis or "?!" is one pause, not three.
    static func sentenceCount(in plain: String) -> Int {
        var count = 0
        var inRun = false
        for scalar in plain.unicodeScalars {
            let terminator = scalar == "." || scalar == "!" || scalar == "?" || scalar == "\u{2026}"
            if terminator && !inRun { count += 1 }
            inRun = terminator
        }
        return count
    }

    // MARK: - Voice pace → words per minute

    /// A character's voice pace (Voice tab: Very Slow … Rapid) scaled onto the
    /// timeline's WPM. The pace is a relative delivery rate, not a number, so
    /// it multiplies the WPM the owner set on the timeline rather than
    /// replacing it — "Normal" is exactly the timeline WPM, and a character
    /// with no pace (or the legacy "Varied") reads at the timeline WPM too.
    /// Keys are lower-cased.
    public static let paceMultipliers: [String: Double] = [
        "very slow": 0.70,
        "slow": 0.85,
        "normal": 1.00,
        "moderate": 1.10,
        "fast": 1.25,
        "rapid": 1.45,
    ]

    /// Words per minute for a speaker: `timelineWPM` scaled by the voice pace
    /// (see `paceMultipliers`), kept inside the timeline's WPM range.
    public static func wordsPerMinute(voicePace: String?, timelineWPM: Int) -> Int {
        let base = timelineWPM > 0 ? timelineWPM : TimelineWPMConstants.defaultWPM
        let key = (voicePace ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let multiplier = paceMultipliers[key] else { return base }
        let scaled = Int((Double(base) * multiplier).rounded())
        return min(TimelineWPMConstants.maxWPM, max(TimelineWPMConstants.minWPM, scaled))
    }
}
