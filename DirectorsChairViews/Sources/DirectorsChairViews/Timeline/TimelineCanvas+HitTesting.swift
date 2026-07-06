//
// TimelineCanvas+HitTesting.swift
//
// Extracted from TimelineCanvas.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import Foundation

extension TimelineCanvas {

    // MARK: - Hit Testing

    /// Find a lane label at the given point (for track toggle hit-testing, accounts for verticalOffset)
    func findLaneLabelToggle(at point: CGPoint) -> String? {
        var yCursor: CGFloat = -verticalOffset

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let isCollapsed = hiddenTracks.contains(character)

            let labelRect = CGRect(
                x: 4,
                y: yCursor + (isCollapsed ? 2 : 4),
                width: TimelineLayoutConstants.rowLabelWidth - 12,
                height: laneHeight - (isCollapsed ? 4 : 8)
            )

            if isCollapsed {
                if labelRect.contains(point) {
                    return character
                }
            } else {
                let eyeRect = CGRect(
                    x: labelRect.minX,
                    y: labelRect.minY,
                    width: 28,
                    height: labelRect.height
                )
                if eyeRect.contains(point) {
                    return character
                }
            }

            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }

        return nil
    }

    /// Find a segment at the given point (for gesture hit-testing, accounts for verticalOffset)
    func findSegment(at point: CGPoint) -> TimelineSegment? {
        let segmentsByCharacter = Dictionary(grouping: segments) { $0.character }

        var yCursor: CGFloat = -verticalOffset

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let laneY = yCursor

            guard let characterSegments = segmentsByCharacter[character] else {
                yCursor += laneHeight + TimelineLayoutConstants.rowGap
                continue
            }

            for segment in characterSegments {
                let rx = originX + segment.start * pxPerSec
                let bubbleWidth = DurationEstimator.bubbleWidth(for: segment, pxPerSec: pxPerSec, showThumbs: showThumbs)

                let subLane = subLaneAssignments[segment.id] ?? 0
                let subLaneY = laneY + CGFloat(subLane) * TimelineLayoutConstants.subLaneHeight

                let bubbleRect = CGRect(
                    x: rx + TimelineLayoutConstants.tailWidth,
                    y: subLaneY + 6,
                    width: bubbleWidth - TimelineLayoutConstants.tailWidth,
                    height: TimelineLayoutConstants.subLaneHeight - 12
                )

                if bubbleRect.contains(point) {
                    return segment
                }
            }

            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }

        return nil
    }

    /// Find which character track lane contains the given point
    func findTrackCharacter(at point: CGPoint) -> String? {
        var yCursor: CGFloat = -verticalOffset

        for (index, character) in charactersInOrder.enumerated() {
            let laneHeight = laneHeights[index]
            let laneRect = CGRect(x: 0, y: yCursor, width: totalWidth, height: laneHeight)
            if laneRect.contains(point) {
                return character
            }
            yCursor += laneHeight + TimelineLayoutConstants.rowGap
        }
        return nil
    }

    /// Load character images into cache for efficient canvas rendering.
    /// The path list is gathered on the main actor; the disk reads happen on a
    /// background queue so avatar loading never blocks the UI (WS9.2), and the
    /// cache is published back on main.
    func loadCharacterImages() {
        guard let basePath = projectBasePath else { return }

        var wanted: [(key: String, url: URL)] = []
        for segment in segments {
            guard let avatarPath = segment.avatarPath, !avatarPath.isEmpty else { continue }
            let fullPath = basePath.appendingPathComponent(avatarPath)
            wanted.append((segment.character, fullPath))
            if let parentName = segment.parentCharacterName {
                wanted.append((parentName, fullPath))
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [wanted] in
            var newCache: [String: NSImage] = [:]
            for (key, url) in wanted where newCache[key] == nil {
                if let image = NSImage(contentsOf: url) {
                    newCache[key] = image
                }
            }
            DispatchQueue.main.async {
                if newCache != imageCache {
                    imageCache = newCache
                }
            }
        }
    }
}
