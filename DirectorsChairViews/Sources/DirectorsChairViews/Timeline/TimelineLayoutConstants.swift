// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineLayoutConstants.swift
//
// Layout constants for timeline rendering (matching Python implementation)

import Foundation
import SwiftUI

/// Layout constants for the timeline canvas
/// These values match the Python implementation for visual parity
public struct TimelineLayoutConstants {
    // MARK: - Margins and Spacing

    /// Top margin above the ruler
    public static let topMargin: CGFloat = 48

    /// Left margin for the canvas
    public static let leftMargin: CGFloat = 60

    /// Width of the row label area (character names)
    public static let rowLabelWidth: CGFloat = 160

    /// Height of the time ruler
    public static let rulerHeight: CGFloat = 24

    /// Gap between ruler and first lane
    public static let rulerGap: CGFloat = 10

    /// Base height for character lanes
    public static let baseRowHeight: CGFloat = 56

    /// Gap between character lanes
    public static let rowGap: CGFloat = 12

    /// Padding at the bottom of the canvas
    public static let bottomPadding: CGFloat = 28

    // MARK: - Bubble Layout

    /// Padding inside the bubble
    public static let contentPadding: CGFloat = 10

    /// Size of the character avatar thumbnail
    public static let avatarSize: CGFloat = 28

    /// Gap between avatar and text
    public static let avatarGap: CGFloat = 8

    /// Width of the speech bubble tail
    public static let tailWidth: CGFloat = 10

    /// Height of the speech bubble tail
    public static let tailHeight: CGFloat = 10

    // MARK: - Zoom/Scale Limits

    /// Minimum pixels per second (most zoomed out)
    public static let minPxPerSec: CGFloat = 20

    /// Maximum pixels per second (most zoomed in)
    public static let maxPxPerSec: CGFloat = 240

    /// Default pixels per second
    public static let defaultPxPerSec: CGFloat = 60

    // MARK: - Viewport Culling Buffer

    /// Buffer time in seconds for viewport culling (render slightly off-screen)
    public static let viewportBuffer: CGFloat = 10

    // MARK: - Interactive Elements

    /// Minimum bubble width
    public static let minBubbleWidth: CGFloat = 16

    /// Corner radius for bubbles (0 = rectangular, like Python)
    public static let bubbleCornerRadius: CGFloat = 0

    /// Selection border width
    public static let selectionBorderWidth: CGFloat = 2

    // MARK: - Time Ruler

    /// Major tick interval (shows label)
    public static let majorTickInterval: Int = 5

    /// Minor tick height
    public static let minorTickHeight: CGFloat = 6

    /// Medium tick height (every 5 seconds)
    public static let mediumTickHeight: CGFloat = 10

    /// Major tick height (every 10 seconds)
    public static let majorTickHeight: CGFloat = 14

    /// Minute tick height (every 60 seconds)
    public static let minuteTickHeight: CGFloat = 18

    // MARK: - Marker Dimensions

    /// User marker diamond size
    public static let markerDiamondSize: CGFloat = 6

    /// Marker label padding
    public static let markerLabelPadding: CGFloat = 5

    // MARK: - Performance

    /// Maximum text length to display in bubbles (for performance)
    public static let maxTextDisplayLength: Int = 200

    /// Minimum canvas width
    public static let minCanvasWidth: CGFloat = 1000

    /// Minimum canvas height
    public static let minCanvasHeight: CGFloat = 280
}

// MARK: - WPM Constants

/// Words-per-minute configuration for duration estimation
public struct TimelineWPMConstants {
    /// Default words per minute for dialogue duration calculation
    public static let defaultWPM: Int = 150

    /// Minimum WPM
    public static let minWPM: Int = 80

    /// Maximum WPM
    public static let maxWPM: Int = 260

    /// Minimum dialogue duration in seconds
    public static let minDuration: CGFloat = 0.8

    /// Pause bonus for comma/semicolon
    public static let commaPause: CGFloat = 0.25

    /// Pause bonus for period/exclamation/question
    public static let sentencePause: CGFloat = 0.50

    /// Pause bonus for ellipsis/em-dash
    public static let ellipsisPause: CGFloat = 0.60

    /// Pause bonus for stage directions
    public static let stageDirectionPause: CGFloat = 0.40

    /// Default action duration (fixed)
    public static let actionDuration: CGFloat = 2.0

    /// Default note duration (no timeline space)
    public static let noteDuration: CGFloat = 0.0

    /// Minimum scene duration if empty
    public static let minSceneDuration: CGFloat = 5.0
}

// MARK: - Default Colors

/// Default colors for timeline elements
public struct TimelineDefaultColors {
    /// Default bubble color
    public static let bubbleDefault = "#5D5D5D"

    /// Action bubble color
    public static let actionBubble = "#FFB34D"

    /// Narration bubble color
    public static let narrationBubble = "#4ECDC4"

    /// Note marker color
    public static let noteMarker = "#FFDF5F"

    /// Default user marker color
    public static let userMarker = "#FF5F5F"

    /// Scene boundary marker color
    public static let sceneBoundary = "#6AA9FF"

    /// Sequence boundary marker color
    public static let sequenceBoundary = "#FFB34D"

    /// Default text color
    public static let defaultText = "#FFFFFF"

    /// Secondary text color
    public static let secondaryText = "#AAAAAA"

    /// Lane background alpha
    public static let laneBackgroundAlpha: CGFloat = 0.08
}
