// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineSegment.swift
//
// Timeline segment representing a dialogue, action, or narration on the timeline

import Foundation
import SwiftUI
import DirectorsChairCore

/// Represents a segment (dialogue, action, narration) on the timeline canvas
public struct TimelineSegment: Identifiable, Equatable {
    public let id: UUID

    /// Start time in seconds from the beginning of the timeline scope
    public var start: CGFloat

    /// Duration in seconds
    public var duration: CGFloat

    /// Character name (for dialogue/narration) or type ("Action", "Narration")
    public var character: String

    /// Bubble fill color (hex string)
    public var color: String

    /// Text color (hex string)
    public var textColor: String

    /// The text content to display
    public var text: String

    /// Reference to the source scene (weak reference pattern)
    public var sceneName: String

    /// Type of content this segment represents
    public var contentType: ContentType

    /// Chronology number within the scene
    public var chronologyNumber: Int

    /// Path to character avatar image (optional)
    public var avatarPath: String?

    /// Count of props associated with this segment
    public var propsCount: Int

    /// Whether this segment has an associated audio file
    public var hasAudio: Bool

    /// Content type enumeration
    public enum ContentType: String, Sendable {
        case dialogue
        case action
        case narration
        case note
    }

    public init(
        id: UUID = UUID(),
        start: CGFloat,
        duration: CGFloat,
        character: String,
        color: String,
        textColor: String = "#FFFFFF",
        text: String,
        sceneName: String,
        contentType: ContentType,
        chronologyNumber: Int = 0,
        avatarPath: String? = nil,
        propsCount: Int = 0,
        hasAudio: Bool = false
    ) {
        self.id = id
        self.start = start
        self.duration = duration
        self.character = character
        self.color = color
        self.textColor = textColor
        self.text = text
        self.sceneName = sceneName
        self.contentType = contentType
        self.chronologyNumber = chronologyNumber
        self.avatarPath = avatarPath
        self.propsCount = propsCount
        self.hasAudio = hasAudio
    }

    /// End time in seconds
    public var end: CGFloat {
        start + duration
    }

    /// SwiftUI Color from hex string (uses existing Color extension)
    public var fillColor: Color {
        Color(hex: color)
    }

    /// SwiftUI Color for text from hex string (uses existing Color extension)
    public var textFillColor: Color {
        Color(hex: textColor)
    }
}
