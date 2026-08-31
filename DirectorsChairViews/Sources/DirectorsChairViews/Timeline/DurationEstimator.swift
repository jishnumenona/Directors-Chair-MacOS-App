// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/DurationEstimator.swift
//
// WPM-based duration estimation for dialogue segments

import Foundation
import AppKit

/// Utility for estimating dialogue duration based on text and WPM
public struct DurationEstimator {
    // MARK: - Regex Patterns

    /// Pattern for comma/semicolon pauses
    private static let commaPausePattern = try! NSRegularExpression(pattern: "[,;]", options: [])

    /// Pattern for sentence-ending pauses
    private static let sentencePausePattern = try! NSRegularExpression(pattern: "[.!?]", options: [])

    /// Pattern for ellipsis/em-dash pauses
    private static let ellipsisPausePattern = try! NSRegularExpression(pattern: "\\.{3}|—|-{2,}", options: [])

    /// Pattern for stage directions in parentheses/brackets/braces
    private static let stageDirectionPattern = try! NSRegularExpression(pattern: "[\\(\\[\\{].*?[\\)\\]\\}]", options: [])

    /// Pattern for HTML tags
    private static let htmlTagPattern = try! NSRegularExpression(pattern: "<[^>]+>", options: [])

    /// Pattern for word extraction
    private static let wordPattern = try! NSRegularExpression(pattern: "\\b[\\w']+\\b", options: [])

    // MARK: - Plain Text Cache

    /// Cache for htmlToPlainText results to avoid redundant regex operations
    private static var plainTextCache: [String: String] = [:]
    private static let cacheLimit = 500

    /// Clear all internal caches (call on scene switch or rebuild)
    public static func clearCaches() {
        plainTextCache.removeAll()
        labelWidthCache.removeAll()
    }

    // MARK: - Public Methods

    /// Convert HTML text to plain text
    /// - Parameter htmlOrText: HTML string or plain text
    /// - Returns: Plain text with HTML tags removed
    public static func htmlToPlainText(_ htmlOrText: String?) -> String {
        guard let text = htmlOrText, !text.isEmpty else {
            return ""
        }

        // Check cache first
        if let cached = plainTextCache[text] {
            return cached
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let result: String
        // Check if it looks like HTML
        if trimmed.hasPrefix("<") && (trimmed.contains("</p>") || trimmed.contains("</div>") || trimmed.contains("</span>")) {
            // Remove HTML tags
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            let plainText = htmlTagPattern.stringByReplacingMatches(
                in: trimmed,
                options: [],
                range: range,
                withTemplate: ""
            )
            // Decode common HTML entities
            result = plainText
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
        } else {
            result = text
        }

        // Store in cache (evict if over limit)
        if plainTextCache.count >= cacheLimit {
            plainTextCache.removeAll()
        }
        plainTextCache[text] = result

        return result
    }

    /// Estimate dialogue duration in seconds based on text and WPM
    /// - Parameters:
    ///   - text: The dialogue text (may be HTML)
    ///   - wpm: Words per minute
    /// - Returns: Estimated duration in seconds
    public static func estimateDialogueDuration(text: String?, wpm: Int) -> CGFloat {
        let plainText = htmlToPlainText(text)

        guard !plainText.isEmpty else {
            return TimelineWPMConstants.minDuration
        }

        let effectiveWPM = max(1, wpm)
        let range = NSRange(location: 0, length: plainText.utf16.count)

        // Count words
        let wordMatches = wordPattern.matches(in: plainText, options: [], range: range)
        let wordCount = wordMatches.count

        // Base duration from word count
        var duration = (CGFloat(wordCount) / CGFloat(effectiveWPM)) * 60.0

        // Add pause bonuses
        let commaCount = commaPausePattern.numberOfMatches(in: plainText, options: [], range: range)
        duration += CGFloat(commaCount) * TimelineWPMConstants.commaPause

        let sentenceCount = sentencePausePattern.numberOfMatches(in: plainText, options: [], range: range)
        duration += CGFloat(sentenceCount) * TimelineWPMConstants.sentencePause

        let ellipsisCount = ellipsisPausePattern.numberOfMatches(in: plainText, options: [], range: range)
        duration += CGFloat(ellipsisCount) * TimelineWPMConstants.ellipsisPause

        // Stage direction bonus
        let stageDirectionCount = stageDirectionPattern.numberOfMatches(in: plainText, options: [], range: range)
        if stageDirectionCount > 0 {
            duration += TimelineWPMConstants.stageDirectionPause
        }

        return max(TimelineWPMConstants.minDuration, duration)
    }

    /// Get effective dialogue duration, prioritizing manual duration > audio duration > WPM estimate
    /// - Parameters:
    ///   - manualDuration: User-specified duration override (optional)
    ///   - audioDuration: Duration from audio file (optional)
    ///   - text: The dialogue text
    ///   - wpm: Words per minute for fallback calculation
    /// - Returns: Effective duration in seconds
    public static func getEffectiveDuration(
        manualDuration: Double?,
        audioDuration: Double? = nil,
        text: String?,
        wpm: Int
    ) -> CGFloat {
        // Priority 1: Manual duration (user override)
        if let manual = manualDuration, manual > 0 {
            return CGFloat(manual)
        }

        // Priority 2: Audio file duration
        if let audio = audioDuration, audio > 0 {
            return CGFloat(audio)
        }

        // Priority 3: WPM-based estimation
        return estimateDialogueDuration(text: text, wpm: wpm)
    }

    /// Effective duration for blocks that have no WPM estimate of their own
    /// (actions, narrations, sound notes, connected sub-bubbles): a manual
    /// duration set by trimming on the timeline wins over the fallback.
    public static func effectiveDuration(manualDuration: Double?, fallback: CGFloat) -> CGFloat {
        if let manual = manualDuration, manual > 0 {
            return CGFloat(manual)
        }
        return fallback
    }

    /// Count words in text
    /// - Parameter text: The text to count words in
    /// - Returns: Word count
    public static func countWords(in text: String?) -> Int {
        let plainText = htmlToPlainText(text)
        guard !plainText.isEmpty else { return 0 }

        let range = NSRange(location: 0, length: plainText.utf16.count)
        return wordPattern.numberOfMatches(in: plainText, options: [], range: range)
    }
}

// MARK: - Bubble Width Calculation

extension DurationEstimator {
    /// Cache of label widths (display text → points at the canvas label font)
    private static var labelWidthCache: [String: CGFloat] = [:]

    /// The canvas label font (TimelineCanvas+DrawSegments draws labels at 11 pt)
    private static let labelFont = NSFont.systemFont(ofSize: 11)

    /// The text a bubble actually draws: plain, on one line, at most
    /// `maxTextDisplayLength` characters plus an ellipsis.
    public static func displayLabel(for text: String?) -> String {
        var label = htmlToPlainText(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if label.count > TimelineLayoutConstants.maxTextDisplayLength {
            label = String(label.prefix(TimelineLayoutConstants.maxTextDisplayLength)) + "..."
        }
        return label
    }

    /// Width of a bubble's label in points: the wider of the canvas's
    /// per-character estimate (the rule it truncates by) and the measured
    /// text (so wide glyphs aren't clipped either).
    public static func labelWidth(for text: String?) -> CGFloat {
        let label = displayLabel(for: text)
        if let cached = labelWidthCache[label] { return cached }
        let estimated = CGFloat(label.count) * TimelineLayoutConstants.minWidthPerCharacter
        let measured: CGFloat = label.isEmpty
            ? 0
            : (label as NSString).size(withAttributes: [.font: labelFont]).width
        let width = max(estimated, measured.rounded(.up))
        if labelWidthCache.count >= cacheLimit { labelWidthCache.removeAll() }
        labelWidthCache[label] = width
        return width
    }

    /// Width a dialogue bubble needs for its whole label to stay visible:
    /// the label plus avatar (when thumbnails are on), padding and tail.
    public static func dialogueLabelWidth(for text: String?, showThumbs: Bool) -> CGFloat {
        labelWidth(for: text)
            + (showThumbs ? TimelineLayoutConstants.avatarSize + TimelineLayoutConstants.avatarGap : 0)
            + TimelineLayoutConstants.contentPadding * 2
            + TimelineLayoutConstants.tailWidth
    }

    /// Compute the visual pixel width of a timeline bubble.
    /// Shared between TimelineCanvas (draw + hit-test) and TimelineViewModel (sub-lane layout).
    ///
    /// A dialogue bubble is never narrower than its label (capped), so the
    /// line stays readable. Action, narration and sound blocks are as wide as
    /// their duration and clip their text — they can be trimmed right down to
    /// the 0.5 s floor whatever they say (owner 2026-08-29).
    public static func bubbleWidth(
        for segment: TimelineSegment,
        pxPerSec: CGFloat,
        showThumbs: Bool
    ) -> CGFloat {
        let durationBasedWidth = segment.duration * pxPerSec
        guard segment.contentType == .dialogue else {
            return max(TimelineLayoutConstants.minClippedBubbleWidth, durationBasedWidth)
        }
        let textBasedMinWidth = min(
            dialogueLabelWidth(for: segment.text, showThumbs: showThumbs),
            TimelineLayoutConstants.maxTextBasedBubbleWidth
        )
        return max(TimelineLayoutConstants.minBubbleWidth, max(durationBasedWidth, textBasedMinWidth))
    }
}

// MARK: - Time Formatting

extension DurationEstimator {
    /// Format time in seconds to MM:SS or HH:MM:SS string
    /// - Parameter seconds: Time in seconds
    /// - Returns: Formatted time string
    public static func formatTime(_ seconds: CGFloat) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    /// Format time in seconds to human-readable string (e.g., "1m 30.5s")
    /// - Parameter seconds: Time in seconds
    /// - Returns: Human-readable time string
    public static func formatTimeReadable(_ seconds: CGFloat) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            let secs = seconds.truncatingRemainder(dividingBy: 60)
            return String(format: "%dm %.1fs", mins, secs)
        } else {
            let hours = Int(seconds / 3600)
            let remainder = seconds.truncatingRemainder(dividingBy: 3600)
            let mins = Int(remainder / 60)
            let secs = remainder.truncatingRemainder(dividingBy: 60)
            return String(format: "%dh %dm %.1fs", hours, mins, secs)
        }
    }
}
