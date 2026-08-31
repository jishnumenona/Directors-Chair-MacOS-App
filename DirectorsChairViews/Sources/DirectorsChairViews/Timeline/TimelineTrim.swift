// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineTrim.swift
//
// Pure trim math for edge-dragging any timeline block — dialogue, action,
// narration, sound note, or shot card. Both canvases and the view model use
// the same rules so a drag, its live preview, and what gets persisted agree:
//   • durations snap to 0.1 s and never go below 0.5 s — and a dialogue block
//     never below the width its label needs at the current zoom
//     (`minimumSeconds(for:pxPerSec:showThumbs:)`); action, narration and
//     sound blocks go right down to the floor and clip their text;
//   • a trailing-edge drag keeps the start; a leading-edge drag keeps the end;
//   • a block can't be dragged past the timeline origin.

import Foundation
import SwiftUI

public enum TimelineTrim {
    /// Which edge of a block is being dragged.
    public enum Edge: Equatable, Sendable {
        case leading
        case trailing
    }

    /// Resolved placement after a trim drag.
    public struct Result: Equatable, Sendable {
        public let start: CGFloat
        public let duration: CGFloat

        public init(start: CGFloat, duration: CGFloat) {
            self.start = start
            self.duration = duration
        }

        public var end: CGFloat { start + duration }
    }

    /// No block can be trimmed shorter than this (seconds).
    public static let minimumDuration: CGFloat = 0.5

    /// Trimmed durations land on this grid (seconds).
    public static let snapIncrement: CGFloat = 0.1

    private static let stepsPerSecond: CGFloat = 10

    /// Round to the nearest tenth of a second (no floating-point crumbs).
    public static func snap(_ seconds: CGFloat) -> CGFloat {
        (seconds * stepsPerSecond).rounded() / stepsPerSecond
    }

    /// Snap, then enforce the minimum duration. `minimumSeconds` lets a block
    /// carry a larger floor of its own (a dialogue's label width); the 0.5 s
    /// floor always holds.
    public static func clampDuration(_ seconds: CGFloat, minimumSeconds: CGFloat = minimumDuration) -> CGFloat {
        max(max(minimumDuration, minimumSeconds), snap(seconds))
    }

    /// Resolve an edge drag into the block's new placement.
    /// - Parameters:
    ///   - edge: which edge is being dragged
    ///   - start: the block's start when the drag began (seconds)
    ///   - duration: the block's on-screen duration when the drag began (seconds)
    ///   - deltaSeconds: how far the edge has been dragged (positive = right)
    ///   - minimumSeconds: the shortest this block may become (see `minimumSeconds(for:pxPerSec:showThumbs:)`)
    public static func resolve(edge: Edge, start: CGFloat, duration: CGFloat, deltaSeconds: CGFloat,
                               minimumSeconds: CGFloat = minimumDuration) -> Result {
        let floor = max(minimumDuration, minimumSeconds)
        switch edge {
        case .trailing:
            return Result(start: max(0, start), duration: clampDuration(duration + deltaSeconds, minimumSeconds: floor))
        case .leading:
            let end = start + duration
            let newDuration = clampDuration(duration - deltaSeconds, minimumSeconds: floor)
            let newStart = end - newDuration
            guard newStart >= 0 else {
                // Ran into the timeline origin: pin the block at 0 and keep its end.
                return Result(start: 0, duration: max(floor, end))
            }
            return Result(start: newStart, duration: newDuration)
        }
    }

    // MARK: - Per-type minimum

    /// The shortest a block may be trimmed to, in seconds, at the given zoom.
    /// Action, narration and sound blocks go down to the 0.5 s floor whatever
    /// their text (it clips inside the block). A dialogue block can't be made
    /// narrower than its label needs to stay fully visible: the label's
    /// measured width plus avatar, padding and tail (capped like the bubble
    /// itself), converted at the current pixels-per-second and rounded up to
    /// the 0.1 s grid.
    public static func minimumSeconds(for segment: TimelineSegment, pxPerSec: CGFloat, showThumbs: Bool) -> CGFloat {
        guard segment.contentType == .dialogue, pxPerSec > 0 else { return minimumDuration }
        let labelWidth = min(
            DurationEstimator.dialogueLabelWidth(for: segment.text, showThumbs: showThumbs),
            TimelineLayoutConstants.maxTextBasedBubbleWidth
        )
        return max(minimumDuration, snapUp(labelWidth / pxPerSec))
    }

    /// Round up to the next tenth of a second (a hair of tolerance so an
    /// exact tenth doesn't round to the one above).
    static func snapUp(_ seconds: CGFloat) -> CGFloat {
        (seconds * stepsPerSecond - 1e-6).rounded(.up) / stepsPerSecond
    }

    /// The label shown next to the dragged edge, e.g. "3.2 s".
    public static func label(for duration: CGFloat) -> String {
        String(format: "%.1f s", duration)
    }
}

// MARK: - Shared canvas drawing

extension TimelineTrim {
    /// Grip marks on both edges of a block (drawn when it is selected or being trimmed).
    static func drawEdgeGrips(in rect: CGRect, context: GraphicsContext, color: Color = Color.white.opacity(0.5)) {
        guard rect.width > 12 else { return }
        let gripHeight = max(8, rect.height * 0.45)
        let y = rect.midY - gripHeight / 2
        for x in [rect.minX + 2, rect.maxX - 4] {
            context.fill(
                Path(roundedRect: CGRect(x: x, y: y, width: 2, height: gripHeight), cornerRadius: 1),
                with: .color(color)
            )
        }
    }

    /// Small duration badge shown at the dragged edge while trimming.
    static func drawDurationBadge(_ text: String, at anchor: CGPoint, context: GraphicsContext) {
        let width = max(40, CGFloat(text.count) * 6.5 + 12)
        let rect = CGRect(x: anchor.x - width / 2, y: anchor.y - 9, width: width, height: 18)
        context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color.black.opacity(0.82)))
        context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color.white.opacity(0.7)), lineWidth: 1)
        context.draw(
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white),
            at: CGPoint(x: rect.midX, y: rect.midY),
            anchor: .center
        )
    }
}
