//
// TimelineViewModel+Rebuild.swift
//
// Extracted from TimelineViewModel.swift (WS9.1 god-file decomposition).
//

import Foundation
import SwiftUI
import Combine
import DirectorsChairCore

extension TimelineViewModel {

    // MARK: - Private Methods

    /// Rebuild segments from current scene/sequence/project data
    func rebuild() {
        PerfSignpost.measure("timeline.rebuild") { rebuildBody() }
    }

    private func rebuildBody() {
        // Clear per-track hiding when content changes
        hiddenTracks.removeAll()

        // Build character lookup dictionary for O(1) access
        let characters = project?.characters ?? []
        characterByName = Dictionary(uniqueKeysWithValues: characters.map { ($0.name, $0) })

        // Expose all character names so every character gets a timeline lane
        allCharacterNames = characters.map { $0.name }

        // Clear DurationEstimator plain-text cache to avoid stale data
        DurationEstimator.clearCaches()

        switch mode {
        case .scene:
            rebuildForScene()
        case .sequence:
            rebuildForSequence()
        case .global:
            rebuildForGlobal()
        }
    }

    /// Build segments for a single scene
    /// Rebuild for the currently selected scene.
    func rebuildForScene() {
        guard let scene = currentScene else {
            segments = []
            markers = []
            sceneBoundaries = []
            sequenceBoundaries = []
            return
        }
        var t: CGFloat = 0
        var newSegments: [TimelineSegment] = []
        var newMarkers: [TimelineMarker] = []
        var newSceneBoundaries: [TimelineBoundary] = []
        var newShotLabels: [TimelineShotLabel] = []

        appendScene(scene, t: &t, newSegments: &newSegments, newMarkers: &newMarkers,
                    newSceneBoundaries: &newSceneBoundaries, newShotLabels: &newShotLabels)

        finishRebuild(segments: newSegments, markers: newMarkers,
                      sceneBoundaries: newSceneBoundaries, sequenceBoundaries: [],
                      shotLabels: newShotLabels, scenesInScope: [scene], t: t)
    }

    /// Rebuild for the currently selected sequence (all its scenes back to back).
    func rebuildForSequence() {
        guard let sequence = currentSequence else {
            segments = []
            markers = []
            sceneBoundaries = []
            sequenceBoundaries = []
            return
        }
        var t: CGFloat = 0
        var newSegments: [TimelineSegment] = []
        var newMarkers: [TimelineMarker] = []
        var newSceneBoundaries: [TimelineBoundary] = []
        var newShotLabels: [TimelineShotLabel] = []

        for scene in sequence.scenes {
            appendScene(scene, t: &t, newSegments: &newSegments, newMarkers: &newMarkers,
                        newSceneBoundaries: &newSceneBoundaries, newShotLabels: &newShotLabels)
        }

        finishRebuild(segments: newSegments, markers: newMarkers,
                      sceneBoundaries: newSceneBoundaries,
                      sequenceBoundaries: [TimelineBoundary(time: 0, name: sequence.name)],
                      shotLabels: newShotLabels, scenesInScope: sequence.scenes, t: t)
    }

    /// Rebuild for the whole project (all sequences and scenes).
    func rebuildForGlobal() {
        guard let project = project else {
            segments = []
            markers = []
            sceneBoundaries = []
            sequenceBoundaries = []
            return
        }
        var t: CGFloat = 0
        var newSegments: [TimelineSegment] = []
        var newMarkers: [TimelineMarker] = []
        var newSceneBoundaries: [TimelineBoundary] = []
        var newSequenceBoundaries: [TimelineBoundary] = []
        var newShotLabels: [TimelineShotLabel] = []
        var allScenes: [DCScene] = []

        for sequence in project.sequences {
            newSequenceBoundaries.append(TimelineBoundary(time: t, name: sequence.name))
            for scene in sequence.scenes {
                appendScene(scene, t: &t, newSegments: &newSegments, newMarkers: &newMarkers,
                            newSceneBoundaries: &newSceneBoundaries, newShotLabels: &newShotLabels)
            }
            allScenes.append(contentsOf: sequence.scenes)
        }

        finishRebuild(segments: newSegments, markers: newMarkers,
                      sceneBoundaries: newSceneBoundaries,
                      sequenceBoundaries: newSequenceBoundaries,
                      shotLabels: newShotLabels, scenesInScope: allScenes, t: t)
    }

    // MARK: - Shared scene builder (WS5.6)
    //
    // This body was previously TRIPLICATED across the scene/sequence/global
    // rebuilds and had drifted (narration-duration naming, shot-label
    // placement). One canonical implementation now serves all three scopes.

    private func appendScene(_ scene: DCScene,
                             t: inout CGFloat,
                             newSegments: inout [TimelineSegment],
                             newMarkers: inout [TimelineMarker],
                             newSceneBoundaries: inout [TimelineBoundary],
                             newShotLabels: inout [TimelineShotLabel]) {
        // Add scene boundary
        newSceneBoundaries.append(TimelineBoundary(time: t, name: scene.name))

        // Build dialogue timing map for this scene
        var dialogueTiming: [String: (start: CGFloat, duration: CGFloat, character: String)] = [:]

        // Collect all independent items and sort by chronology number
        enum TimelineItem {
            case dialogue(Dialogue)
            case action(Action)
            case narration(Narration)

            var chronologyNumber: Int {
                switch self {
                case .dialogue(let d): return d.chronologyNumber
                case .action(let a): return a.chronologyNumber
                case .narration(let n): return n.chronologyNumber
                }
            }
        }

        var allItems: [TimelineItem] = []

        for dialogue in scene.dialogues {
            allItems.append(.dialogue(dialogue))
        }
        for action in scene.actions where action.parentDialogueId == nil {
            allItems.append(.action(action))
        }
        for narration in scene.narrations where narration.parentDialogueId == nil {
            allItems.append(.narration(narration))
        }

        allItems.sort { $0.chronologyNumber < $1.chronologyNumber }

        // Process items in chronology order
        for item in allItems {
            switch item {
            case .dialogue(let dialogue):
                let duration = DurationEstimator.getEffectiveDuration(
                    manualDuration: dialogue.manualDuration,
                    text: dialogue.text,
                    wpm: wpm
                )

                dialogueTiming[dialogue.id] = (start: t, duration: duration, character: dialogue.character)

                let characterColor = getCharacterColor(dialogue.character)
                let characterTextColor = getCharacterTextColor(dialogue.character)

                newSegments.append(TimelineSegment(
                    start: t,
                    duration: duration,
                    character: dialogue.character,
                    color: characterColor,
                    textColor: characterTextColor,
                    text: dialogue.text,
                    sceneName: scene.name,
                    contentType: .dialogue,
                    chronologyNumber: dialogue.chronologyNumber,
                    avatarPath: getCharacterAvatar(dialogue.character),
                    propsCount: 0,
                    hasAudio: dialogue.audioFilePath != nil,
                    sourceItemId: dialogue.id
                ))

                t += duration

            case .action(let action):
                let actionDuration = TimelineWPMConstants.actionDuration

                newSegments.append(TimelineSegment(
                    start: t,
                    duration: actionDuration,
                    character: "Action",
                    color: TimelineDefaultColors.actionBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: action.description,
                    sceneName: scene.name,
                    contentType: .action,
                    chronologyNumber: action.chronologyNumber,
                    propsCount: action.effects.count,
                    sourceItemId: action.id
                ))

                t += actionDuration

            case .narration(let narration):
                let estimatedDuration = max(
                    TimelineWPMConstants.actionDuration,
                    DurationEstimator.estimateDialogueDuration(text: narration.text, wpm: wpm)
                )

                newSegments.append(TimelineSegment(
                    start: t,
                    duration: estimatedDuration,
                    character: "Narration",
                    color: TimelineDefaultColors.narrationBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: narration.text,
                    sceneName: scene.name,
                    contentType: .narration,
                    chronologyNumber: narration.chronologyNumber,
                    sourceItemId: narration.id
                ))

                t += estimatedDuration
            }
        }

        // Process connected actions (those with parentDialogueId)
        for action in scene.actions {
            if let parentId = action.parentDialogueId,
               let parentTiming = dialogueTiming[parentId] {
                newSegments.append(TimelineSegment(
                    start: parentTiming.start,
                    duration: parentTiming.duration,
                    character: "Action",
                    color: TimelineDefaultColors.actionBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: action.description,
                    sceneName: scene.name,
                    contentType: .action,
                    chronologyNumber: action.chronologyNumber,
                    avatarPath: getCharacterAvatar(parentTiming.character),
                    propsCount: action.effects.count,
                    sourceItemId: action.id,
                    parentCharacterName: parentTiming.character
                ))
            }
        }

        // Process connected narrations (those with parentDialogueId)
        for narration in scene.narrations {
            if let parentId = narration.parentDialogueId,
               let parentTiming = dialogueTiming[parentId] {
                newSegments.append(TimelineSegment(
                    start: parentTiming.start,
                    duration: parentTiming.duration,
                    character: "Narration",
                    color: TimelineDefaultColors.narrationBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: narration.text,
                    sceneName: scene.name,
                    contentType: .narration,
                    chronologyNumber: narration.chronologyNumber,
                    avatarPath: getCharacterAvatar(parentTiming.character),
                    sourceItemId: narration.id,
                    parentCharacterName: parentTiming.character
                ))
            }
        }

        // Process notes as markers - connected ones use parent dialogue timing
        for note in scene.sceneNotes {
            let noteTime: CGFloat
            if let parentId = note.parentDialogueId,
               let parentTiming = dialogueTiming[parentId] {
                noteTime = parentTiming.start
            } else {
                noteTime = t
            }

            newMarkers.append(TimelineMarker(
                time: noteTime,
                label: "Note: \(note.title)",
                kind: .note,
                color: TimelineDefaultColors.noteMarker
            ))
        }

        // Process SoundNotes for this scene
        for soundNote in scene.soundNotes {
            let soundStart: CGFloat
            let soundDuration: CGFloat

            if let parentId = soundNote.parentDialogueId,
               let parentTiming = dialogueTiming[parentId] {
                soundStart = parentTiming.start
                soundDuration = parentTiming.duration
            } else if let startTime = soundNote.startTime, let endTime = soundNote.endTime {
                soundStart = CGFloat(startTime)
                soundDuration = CGFloat(endTime - startTime)
            } else {
                soundStart = t
                soundDuration = TimelineWPMConstants.soundNoteDuration
            }

            let icon: String
            switch soundNote.soundType {
            case "music": icon = "music.note"
            case "effects", "dialogue_sfx": icon = "speaker.wave.2"
            default: icon = "speaker.wave.2"
            }

            newSegments.append(TimelineSegment(
                start: soundStart,
                duration: soundDuration,
                character: "Sound",
                color: TimelineDefaultColors.soundNoteBubble,
                textColor: TimelineDefaultColors.defaultText,
                text: "\(icon) \(soundNote.description)",
                sceneName: scene.name,
                contentType: .soundNote,
                chronologyNumber: soundNote.chronologyNumber,
                sourceItemId: soundNote.uuid
            ))
        }

        // Process shots as labels for the shots lane (no markers)
        let sceneStartTime = newSceneBoundaries.last?.time ?? 0
        let sceneShotCount = scene.shots.count

        for (index, shot) in scene.shots.enumerated() {
            var earliestStart: CGFloat = .infinity
            var latestEnd: CGFloat = 0
            var foundTime = false

            for dialogueId in shot.linkedDialogueIds {
                if let timing = dialogueTiming[dialogueId] {
                    earliestStart = min(earliestStart, timing.start)
                    latestEnd = max(latestEnd, timing.start + timing.duration)
                    foundTime = true
                }
            }

            let shotTime: CGFloat
            let shotDuration: CGFloat

            if foundTime {
                shotTime = earliestStart
                shotDuration = latestEnd - earliestStart
            } else if sceneShotCount > 0 {
                let sceneDuration = max(t - sceneStartTime, TimelineWPMConstants.minSceneDuration)
                shotTime = sceneStartTime + sceneDuration * CGFloat(index) / CGFloat(max(sceneShotCount, 1))
                shotDuration = shot.duration.map { CGFloat($0) } ?? 0
            } else {
                shotTime = sceneStartTime
                shotDuration = shot.duration.map { CGFloat($0) } ?? 0
            }

            newShotLabels.append(TimelineShotLabel(
                time: shotTime,
                duration: shotDuration,
                shotName: "Shot \(shot.shotId)",
                shotId: shot.shotId,
                sceneName: scene.name,
                linkedDialogueIds: shot.linkedDialogueIds,
                shotType: shot.shotType,
                cameraAngle: shot.cameraAngle,
                lensMm: shot.lensMm,
                movement: shot.movement,
                previewImagePath: shot.previewImage,
                hasVideo: shot.videoPath != nil && !(shot.videoPath?.isEmpty ?? true)
            ))
        }

        // Ensure minimum scene duration
        if scene.dialogues.isEmpty && scene.actions.isEmpty && scene.narrations.isEmpty {
            t += TimelineWPMConstants.minSceneDuration
        }
    }

    /// Common tail of every rebuild: sort labels, publish, re-derive layout.
    private func finishRebuild(segments newSegments: [TimelineSegment],
                               markers newMarkers: [TimelineMarker],
                               sceneBoundaries newSceneBoundaries: [TimelineBoundary],
                               sequenceBoundaries newSequenceBoundaries: [TimelineBoundary],
                               shotLabels newShotLabels: [TimelineShotLabel],
                               scenesInScope: [DCScene],
                               t: CGFloat) {
        var t = t
        var sortedShotLabels = newShotLabels
        // Sort shot labels by time, then by shotId for stable ordering
        sortedShotLabels.sort {
            if $0.time != $1.time {
                return $0.time < $1.time
            }
            return $0.shotId < $1.shotId
        }

        segments = newSegments
        markers = newMarkers
        sceneBoundaries = newSceneBoundaries
        sequenceBoundaries = newSequenceBoundaries
        shotLabels = sortedShotLabels

        // Apply manual position overrides from saved project data
        applyManualPositionOverrides()

        // Compute sub-lane layout for overlapping bubbles
        recomputeAllSubLanes()

        // Update scenes in scope and duration
        allScenesInScope = scenesInScope
        currentSceneIndex = 0
        // Extend duration if any cue bubbles exceed the last dialogue
        let cueMax = maxCueEndTime()
        if cueMax > t { t = cueMax }
        totalDuration = t
        currentSceneDuration = t
    }

    // MARK: - Cue Duration Extension

    /// Returns the maximum end time across all cue lanes (light, SFX, support) + soundtrack tracks.
    func maxCueEndTime() -> CGFloat {
        let lightMax = lightCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let sfxMax = sfxCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let supportMax = supportCues.map { CGFloat($0.startTime + $0.duration) }.max() ?? 0
        let soundtrackMax = soundtrackTracks.map { CGFloat($0.startTimeOffset + $0.duration) }.max() ?? 0
        return max(lightMax, sfxMax, supportMax, soundtrackMax)
    }
}
