//
// TimelineViewModel+SubLanes.swift
//
// Extracted from TimelineViewModel.swift (WS9.1 god-file decomposition).
//

import Foundation
import SwiftUI
import Combine
import DirectorsChairCore

extension TimelineViewModel {

    /// Extends totalDuration if any cue bubble extends beyond the current timeline length.
    public func extendDurationIfNeeded() {
        let cueMax = maxCueEndTime()
        if cueMax > totalDuration {
            totalDuration = cueMax
            currentSceneDuration = cueMax
        }
    }

    // MARK: - Manual Position Overrides

    /// Apply manual start time overrides from the project model to computed segments and shot labels.
    /// Called after each rebuild to honor user-dragged positions.
    func applyManualPositionOverrides() {
        guard let project = project else { return }

        // Build a lookup of sourceItemId → manualStartTime from all scenes
        var manualStartTimes: [String: Double] = [:]
        var shotPositions: [Int: (sceneName: String, position: Double)] = [:]

        for sequence in project.sequences {
            for scene in sequence.scenes {
                for dialogue in scene.dialogues {
                    if let manual = dialogue.manualStartTime {
                        manualStartTimes[dialogue.id] = manual
                    }
                }
                for action in scene.actions {
                    if let manual = action.manualStartTime {
                        manualStartTimes[action.id] = manual
                    }
                }
                for narration in scene.narrations {
                    if let manual = narration.manualStartTime {
                        manualStartTimes[narration.id] = manual
                    }
                }
                for soundNote in scene.soundNotes {
                    if let manual = soundNote.manualStartTime {
                        manualStartTimes[soundNote.uuid] = manual
                    }
                }
                for shot in scene.shots {
                    if let pos = shot.timelinePosition {
                        shotPositions[shot.shotId] = (sceneName: scene.name, position: pos)
                    }
                }
            }
        }

        // Apply segment overrides
        for i in segments.indices {
            if let sourceId = segments[i].sourceItemId,
               let manualTime = manualStartTimes[sourceId] {
                segments[i].start = CGFloat(manualTime)
            }
        }

        // Apply shot label overrides
        for i in shotLabels.indices {
            if let info = shotPositions[shotLabels[i].shotId],
               info.sceneName == shotLabels[i].sceneName {
                shotLabels[i].time = CGFloat(info.position)
            }
        }

        // Re-sort shot labels after overrides
        shotLabels.sort {
            if $0.time != $1.time { return $0.time < $1.time }
            return $0.shotId < $1.shotId
        }
    }

    // MARK: - Sub-Lane Computation

    /// Recompute all sub-lane layouts (segments + shots) and connections.
    /// All results are computed into local vars first, then assigned in a single batch
    /// to coalesce @Published updates into fewer SwiftUI redraw passes.
    func recomputeAllSubLanes() {
        let (segAssign, segCounts) = computeSubLanesResult()
        let (shotAssign, shotCount) = computeShotSubLanesResult()
        let connections = computeShotDialogueConnectionsResult()

        subLaneAssignments = segAssign
        laneSubLaneCounts = segCounts
        shotSubLaneAssignments = shotAssign
        shotLaneSubLaneCount = shotCount
        shotDialogueConnections = connections
    }

    /// Compute sub-lane assignments using greedy interval partitioning.
    /// Returns results without assigning to @Published properties.
    func computeSubLanesResult() -> (assignments: [UUID: Int], counts: [String: Int]) {
        let visible = visibleSegments
        let grouped = Dictionary(grouping: visible) { $0.character }

        var newAssignments: [UUID: Int] = [:]
        var newCounts: [String: Int] = [:]

        for (character, charSegments) in grouped {
            var intervals: [(segment: TimelineSegment, start: CGFloat, end: CGFloat)] = []
            for seg in charSegments {
                let rx = seg.start * pxPerSec
                let w = DurationEstimator.bubbleWidth(for: seg, pxPerSec: pxPerSec, showThumbs: showThumbs)
                intervals.append((seg, rx, rx + w))
            }
            intervals.sort { $0.start < $1.start }

            var subLaneEnds: [CGFloat] = []

            for interval in intervals {
                var placed = false
                for lane in 0..<subLaneEnds.count {
                    if subLaneEnds[lane] <= interval.start {
                        subLaneEnds[lane] = interval.end
                        newAssignments[interval.segment.id] = lane
                        placed = true
                        break
                    }
                }
                if !placed {
                    newAssignments[interval.segment.id] = subLaneEnds.count
                    subLaneEnds.append(interval.end)
                }
            }

            newCounts[character] = max(1, subLaneEnds.count)
        }

        return (newAssignments, newCounts)
    }

    /// Compute sub-lane assignments for shot labels using greedy interval partitioning.
    /// Returns results without assigning to @Published properties.
    func computeShotSubLanesResult() -> (assignments: [UUID: Int], count: Int) {
        guard !shotLabels.isEmpty else {
            return ([:], 1)
        }

        var intervals: [(label: TimelineShotLabel, start: CGFloat, end: CGFloat)] = []
        for label in shotLabels {
            let rx = label.time * pxPerSec
            let w = label.displayWidth(pxPerSec: pxPerSec)
            intervals.append((label, rx, rx + w))
        }
        intervals.sort { $0.start < $1.start }

        var newAssignments: [UUID: Int] = [:]
        var subLaneEnds: [CGFloat] = []

        for interval in intervals {
            var placed = false
            for lane in 0..<subLaneEnds.count {
                if subLaneEnds[lane] <= interval.start {
                    subLaneEnds[lane] = interval.end
                    newAssignments[interval.label.id] = lane
                    placed = true
                    break
                }
            }
            if !placed {
                newAssignments[interval.label.id] = subLaneEnds.count
                subLaneEnds.append(interval.end)
            }
        }

        return (newAssignments, max(1, subLaneEnds.count))
    }

    /// Compute shot-dialogue connections from shot labels and segments.
    /// Returns results without assigning to @Published properties.
    func computeShotDialogueConnectionsResult() -> [ShotDialogueConnection] {
        var dialogueSourceToSegment: [String: UUID] = [:]
        for segment in segments where segment.contentType == .dialogue {
            if let sourceId = segment.sourceItemId {
                dialogueSourceToSegment[sourceId] = segment.id
            }
        }

        var connections: [ShotDialogueConnection] = []
        for shotLabel in shotLabels {
            for dialogueId in shotLabel.linkedDialogueIds {
                if let segmentId = dialogueSourceToSegment[dialogueId] {
                    connections.append(ShotDialogueConnection(
                        shotLabelId: shotLabel.id,
                        shotTime: shotLabel.time,
                        dialogueSegmentId: segmentId,
                        color: TimelineDefaultColors.colorForShotType(shotLabel.shotType)
                    ))
                }
            }
        }

        return connections
    }

    /// Legacy convenience methods for callers that need individual recomputation
    func computeSubLanes() {
        let (assign, counts) = computeSubLanesResult()
        subLaneAssignments = assign
        laneSubLaneCounts = counts
    }

    func computeShotSubLanes() {
        let (assign, count) = computeShotSubLanesResult()
        shotSubLaneAssignments = assign
        shotLaneSubLaneCount = count
    }

    func computeShotDialogueConnections() {
        shotDialogueConnections = computeShotDialogueConnectionsResult()
    }

    // MARK: - Helper Methods

    /// Get character color from project
    func getCharacterColor(_ name: String) -> String {
        guard let character = characterByName[name] else {
            return TimelineDefaultColors.bubbleDefault
        }
        return character.color
    }

    /// Get character text color from project
    func getCharacterTextColor(_ name: String) -> String {
        guard let character = characterByName[name] else {
            return TimelineDefaultColors.defaultText
        }
        return character.textColor
    }

    /// Get character avatar path from project
    /// Priority: avatar > baseImage > imageFront
    func getCharacterAvatar(_ name: String) -> String? {
        guard let character = characterByName[name] else {
            return nil
        }

        // Priority 1: Legacy avatar
        if let avatar = character.avatar, !avatar.isEmpty {
            return avatar
        }

        // Priority 2: Base image (AI-generated)
        if let baseImage = character.baseImage, !baseImage.isEmpty {
            return baseImage
        }

        // Priority 3: Front image
        if let imageFront = character.imageFront, !imageFront.isEmpty {
            return imageFront
        }

        return nil
    }

    /// Get all marker times (for navigation)
    func getAllMarkerTimes() -> [CGFloat] {
        var times: [CGFloat] = []

        // Add scene boundaries
        times.append(contentsOf: sceneBoundaries.map { $0.time })

        // Add sequence boundaries
        times.append(contentsOf: sequenceBoundaries.map { $0.time })

        // Add auto-generated markers (notes, etc.)
        times.append(contentsOf: markers.map { $0.time })

        // Add user-created markers
        times.append(contentsOf: userMarkers.map { $0.time })

        return times.sorted()
    }

    /// Get current time from viewport position
    func getCurrentTimeFromViewport() -> CGFloat {
        let originX = TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
        let scrollX = viewportOffset.x + 100
        return max(0, (scrollX - originX) / pxPerSec)
    }

    // MARK: - TTS Audio Helpers

    /// Find a Dialogue by its sourceItemId across all scenes
    public func findDialogue(sourceItemId: String) -> Dialogue? {
        guard let project = project else { return nil }
        for sequence in project.sequences {
            for scene in sequence.scenes {
                if let dialogue = scene.dialogues.first(where: { $0.id == sourceItemId }) {
                    return dialogue
                }
            }
        }
        return nil
    }

    /// Find a Character by name
    public func findCharacter(name: String) -> Character? {
        return project?.characters.first(where: { $0.name == name })
    }

    /// Update a dialogue's audioFilePath across all scenes in the project
    public func updateDialogueAudioPath(sourceItemId: String, audioFilePath: String) {
        guard project != nil else { return }
        for seqIdx in project!.sequences.indices {
            for sceneIdx in project!.sequences[seqIdx].scenes.indices {
                if let dlgIdx = project!.sequences[seqIdx].scenes[sceneIdx].dialogues.firstIndex(where: { $0.id == sourceItemId }) {
                    project!.sequences[seqIdx].scenes[sceneIdx].dialogues[dlgIdx].audioFilePath = audioFilePath
                    return
                }
            }
        }
    }
}
