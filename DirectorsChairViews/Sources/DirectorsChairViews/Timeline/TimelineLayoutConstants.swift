// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineLayoutConstants.swift
//
// Layout constants for timeline rendering (matching Python implementation)

import Foundation
import SwiftUI

/// Layout constants for the timeline canvas
/// These values match the Python implementation for visual parity
public struct TimelineLayoutConstants {
    // MARK: - Margins and Spacing

    /// Top margin above the ruler (space for scene/shot markers and boundary labels)
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

    /// Height of a single sub-lane within a character lane (matches baseRowHeight for single-row lanes)
    public static let subLaneHeight: CGFloat = 56

    /// Height for collapsed (hidden) lanes
    public static let collapsedRowHeight: CGFloat = 20

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

    /// Minimum bubble width (for very short dialogues)
    public static let minBubbleWidth: CGFloat = 80

    /// Minimum width per character for text-based bubble sizing (approximate)
    public static let minWidthPerCharacter: CGFloat = 6.5

    /// Maximum bubble width based on text (to prevent overly wide bubbles)
    public static let maxTextBasedBubbleWidth: CGFloat = 800

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

    // MARK: - Shot Labels Lane

    /// Height of the shot labels lane between ruler and content
    public static let shotLaneHeight: CGFloat = 80

    /// Minimum width for a shot card (ensures zero-duration shots are visible)
    public static let minShotCardWidth: CGFloat = 60

    /// Internal padding within shot cards
    public static let shotCardInternalPadding: CGFloat = 4

    /// Width of the left color accent bar on shot cards
    public static let shotAccentBarWidth: CGFloat = 4

    /// Size of film perforation holes
    public static let filmPerforationSize: CGFloat = 4

    /// Spacing between film perforation holes
    public static let filmPerforationSpacing: CGFloat = 8

    // MARK: - Lighting Cue Lane

    /// Height of the lighting cue lane
    public static let lightingLaneHeight: CGFloat = 44

    // MARK: - SFX Cue Lane

    /// Height of the SFX cue lane
    public static let sfxLaneHeight: CGFloat = 44

    // MARK: - Support Cue Lane

    /// Height of the support cue lane
    public static let supportLaneHeight: CGFloat = 44

    // MARK: - Soundtrack Lane

    /// Height of a single soundtrack waveform lane
    public static let soundtrackLaneHeight: CGFloat = 48

    /// Vertical padding inside the waveform lane
    public static let soundtrackWaveformPadding: CGFloat = 4

    // MARK: - Playhead

    /// Width of the playhead triangle handle
    public static let playheadHandleWidth: CGFloat = 12

    /// Height of the playhead triangle handle
    public static let playheadHandleHeight: CGFloat = 10

    /// Hit-test radius for the playhead handle
    public static let playheadHitRadius: CGFloat = 12

    // MARK: - User Marker Drawing

    /// Size of user marker diamond on the ruler
    public static let userMarkerDiamondSize: CGFloat = 7

    /// Icon size for user markers on the ruler
    public static let userMarkerIconSize: CGFloat = 10

    // MARK: - Control Layout

    /// Height of the primary control row
    public static let controlRowHeight: CGFloat = 32

    /// Height of the secondary control row
    public static let secondControlRowHeight: CGFloat = 28
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

    /// Default sound note duration (when no startTime/endTime specified)
    public static let soundNoteDuration: CGFloat = 3.0

    /// Minimum scene duration if empty
    public static let minSceneDuration: CGFloat = 5.0
}

// MARK: - Default Colors

/// Default colors for timeline elements
public struct TimelineDefaultColors {
    /// Default bubble color
    public static let bubbleDefault = "#5D5D5D"

    /// Action bubble color (matches ActionBubbleCard - orange)
    public static let actionBubble = "#FF9500"

    /// Narration bubble color (matches NarrationBubbleCard - purple)
    public static let narrationBubble = "#9966CC"

    /// SoundNote bubble color (cyan/teal)
    public static let soundNoteBubble = "#17A2B8"

    /// Note marker color
    public static let noteMarker = "#FFDF5F"

    /// Shot marker color (camera blue)
    public static let shotMarker = "#4A8FBF"

    /// Playhead color (white)
    public static let playheadColor = "#FFFFFF"

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

    /// Soundtrack waveform color
    public static let soundtrackWaveform = "#00BCD4"

    /// Lane background alpha
    public static let laneBackgroundAlpha: CGFloat = 0.08

    // MARK: - Shot Type Colors

    /// Returns hex color string for a given shot type
    public static func colorForShotType(_ shotType: String) -> String {
        switch shotType.lowercased() {
        case "wide", "extreme wide":
            return "#00897B"   // teal
        case "medium", "medium wide", "medium close-up":
            return "#F57F17"   // amber
        case "close-up", "extreme close-up":
            return "#D32F2F"   // red
        case "over-the-shoulder", "over the shoulder":
            return "#7B1FA2"   // purple
        case "pov":
            return "#388E3C"   // green
        case "insert", "cutaway":
            return "#E64A19"   // orange
        default:
            return "#4A8FBF"   // steel blue (Standard/default)
        }
    }

    /// SF Symbol name for shot movement type
    public static func iconForMovement(_ movement: String) -> String? {
        switch movement.lowercased() {
        case "static":
            return nil
        case "pan":
            return "arrow.left.and.right"
        case "tilt":
            return "arrow.up.and.down"
        case "dolly":
            return "arrow.right"
        case "crane", "jib":
            return "arrow.up.right"
        case "steadicam", "handheld":
            return "figure.walk"
        case "zoom":
            return "plus.magnifyingglass"
        case "tracking":
            return "arrow.triangle.turn.up.right.diamond"
        default:
            return "arrow.right"
        }
    }
}
