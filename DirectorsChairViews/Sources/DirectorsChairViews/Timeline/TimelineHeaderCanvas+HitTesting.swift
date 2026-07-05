//
// TimelineHeaderCanvas+HitTesting.swift
//
// Extracted from TimelineHeaderCanvas.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension. Behaviour unchanged.
//

import SwiftUI
import AppKit
import DirectorsChairCore

extension TimelineHeaderCanvas {

    // MARK: - Duration Input

    /// Apply the duration text field input to the context menu shot
    func applyDurationInput() {
        guard let shot = contextMenuShot,
              let value = Double(durationInputText),
              value > 0 else {
            showDurationPopover = false
            contextMenuShot = nil
            return
        }
        let newDuration = max(0.5, CGFloat(value))
        onShotLabelResized?(shot.shotId, shot.sceneName, newDuration)
        showDurationPopover = false
        contextMenuShot = nil
    }

    // MARK: - Hit Testing

    /// Find a boundary marker (scene or sequence) at the given point.
    /// Returns the boundary and a bool indicating whether it's a sequence boundary.
    func findBoundaryMarker(at point: CGPoint) -> (TimelineBoundary, Bool)? {
        let labelHeight: CGFloat = 18

        // Check sequence boundaries first (stackLevel 0 in global mode)
        if mode == .global {
            for boundary in sequenceBoundaries {
                let x = originX + boundary.time * pxPerSec
                let labelWidth = max(50, CGFloat(boundary.name.count) * 7 + 16)
                let labelY: CGFloat = 4
                let labelRect = CGRect(x: x - labelWidth / 2, y: labelY, width: labelWidth, height: labelHeight)
                if labelRect.contains(point) {
                    return (boundary, true)
                }
            }
        }

        // Check scene boundaries (stackLevel depends on mode)
        if mode == .sequence || mode == .global {
            let stackLevel = mode == .global ? 1 : 0
            for boundary in sceneBoundaries {
                let x = originX + boundary.time * pxPerSec
                let labelWidth = max(50, CGFloat(boundary.name.count) * 7 + 16)
                let labelY: CGFloat = 4 + CGFloat(stackLevel) * (labelHeight + 4)
                let labelRect = CGRect(x: x - labelWidth / 2, y: labelY, width: labelWidth, height: labelHeight)
                if labelRect.contains(point) {
                    return (boundary, false)
                }
            }
        }

        return nil
    }

    /// Find a shot label at the given point
    func findShotLabel(at point: CGPoint) -> TimelineShotLabel? {
        guard showShotLabels else { return nil }

        let laneY = TimelineLayoutConstants.topMargin +
                    TimelineLayoutConstants.rulerHeight +
                    TimelineLayoutConstants.rulerGap
        let totalLaneHeight = shotLaneOffset
        let singleLaneHeight = TimelineLayoutConstants.shotLaneHeight
        let perfSize = TimelineLayoutConstants.filmPerforationSize

        guard point.y >= laneY && point.y <= laneY + totalLaneHeight else { return nil }

        let cardInset = perfSize + 6
        let cardHeight = singleLaneHeight - cardInset * 2

        for shotLabel in shotLabels {
            let x = originX + shotLabel.time * pxPerSec
            let cardWidth = shotLabel.displayWidth(pxPerSec: pxPerSec)

            let subLane = shotSubLaneAssignments[shotLabel.id] ?? 0
            let subLaneY = laneY + CGFloat(subLane) * singleLaneHeight
            let cardTopY = subLaneY + cardInset

            let shotRect = CGRect(
                x: x + 2,
                y: cardTopY,
                width: cardWidth - 4,
                height: cardHeight
            )

            if shotRect.contains(point) {
                return shotLabel
            }
        }

        return nil
    }

    /// Find a shot label whose right edge is within 8px of the given point
    func findShotLabelRightEdge(at point: CGPoint) -> TimelineShotLabel? {
        guard showShotLabels else { return nil }

        let laneY = TimelineLayoutConstants.topMargin +
                    TimelineLayoutConstants.rulerHeight +
                    TimelineLayoutConstants.rulerGap
        let totalLaneHeight = shotLaneOffset
        let singleLaneHeight = TimelineLayoutConstants.shotLaneHeight
        let perfSize = TimelineLayoutConstants.filmPerforationSize

        guard point.y >= laneY && point.y <= laneY + totalLaneHeight else { return nil }

        let cardInset = perfSize + 6
        let cardHeight = singleLaneHeight - cardInset * 2
        let edgeThreshold: CGFloat = 8

        for shotLabel in shotLabels {
            let x = originX + shotLabel.time * pxPerSec
            let cardWidth = shotLabel.displayWidth(pxPerSec: pxPerSec)

            let subLane = shotSubLaneAssignments[shotLabel.id] ?? 0
            let subLaneY = laneY + CGFloat(subLane) * singleLaneHeight
            let cardTopY = subLaneY + cardInset

            let cardRight = x + cardWidth - 2  // right edge of card (accounting for 2px inset)

            // Check if point is within edgeThreshold of the right edge and within card height
            if point.y >= cardTopY && point.y <= cardTopY + cardHeight &&
               abs(point.x - cardRight) <= edgeThreshold {
                return shotLabel
            }
        }

        return nil
    }

    /// Check if a point hits the shot track eye toggle area
    func isShotEyeToggleHit(at point: CGPoint) -> Bool {
        let laneY = TimelineLayoutConstants.topMargin +
                    TimelineLayoutConstants.rulerHeight +
                    TimelineLayoutConstants.rulerGap
        let totalLaneHeight = shotLaneOffset

        if showShotLabels {
            // Expanded: eye icon area within the label rect
            let labelRect = CGRect(x: 4, y: laneY + 4, width: TimelineLayoutConstants.rowLabelWidth - 12, height: totalLaneHeight - 8)
            let eyeRect = CGRect(x: labelRect.minX, y: labelRect.minY, width: 28, height: labelRect.height)
            return eyeRect.contains(point)
        } else {
            // Collapsed: entire label strip is clickable to re-expand
            let labelRect = CGRect(x: 4, y: laneY + 2, width: TimelineLayoutConstants.rowLabelWidth - 12, height: 20)
            return labelRect.contains(point)
        }
    }

    // MARK: - Playhead Hit Testing

    /// Check if a point is within the playhead triangle handle
    func findPlayheadHandle(at point: CGPoint) -> Bool {
        guard let time = playheadTime else { return false }
        let x = originX + time * pxPerSec
        let handleY = TimelineLayoutConstants.topMargin
        let radius = TimelineLayoutConstants.playheadHitRadius
        return abs(point.x - x) <= radius && abs(point.y - handleY) <= radius
    }

    // MARK: - User Marker Hit Testing

    /// Find a user marker at the given point
    func findUserMarker(at point: CGPoint) -> TimelineMarker? {
        let rulerBaselineY = TimelineLayoutConstants.topMargin + TimelineLayoutConstants.rulerHeight - 1
        let diamondSize = TimelineLayoutConstants.userMarkerDiamondSize
        let hitRadius: CGFloat = 12

        for marker in userMarkers {
            let x = originX + marker.time * pxPerSec
            if abs(point.x - x) <= hitRadius && abs(point.y - rulerBaselineY) <= (diamondSize + hitRadius) {
                return marker
            }
        }
        return nil
    }

    // MARK: - Soundtrack Hit Testing

    /// Find soundtrack track ID at a given point (for drag repositioning)
    func findSoundtrackTrack(at point: CGPoint) -> String? {
        guard showSoundtracks, !soundtrackTracks.isEmpty else { return nil }
        let soundtrackBaseY = TimelineLayoutConstants.topMargin +
                              TimelineLayoutConstants.rulerHeight +
                              TimelineLayoutConstants.rulerGap +
                              shotLaneOffset
        let laneH = TimelineLayoutConstants.soundtrackLaneHeight

        for (index, track) in soundtrackTracks.enumerated() {
            let y = soundtrackBaseY + CGFloat(index) * laneH
            let trackX = originX + CGFloat(track.startTimeOffset) * pxPerSec
            let trackW = CGFloat(track.duration) * pxPerSec
            let rect = CGRect(x: trackX, y: y, width: trackW, height: laneH)
            if rect.contains(point) {
                return track.id
            }
        }
        return nil
    }
}
