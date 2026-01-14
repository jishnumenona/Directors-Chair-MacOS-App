// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineViewModel.swift
//
// ViewModel for Timeline - builds segments from Scene/Dialogue data

import Foundation
import SwiftUI
import Combine
import DirectorsChairCore

// Note: DCScene typealias is defined in SceneListSidebar.swift
// Using DirectorsChairCore.Sequence for Sequence disambiguation

/// ViewModel for TimelineView
/// Builds TimelineSegments from Scene/Dialogue/Action/Narration data
@MainActor
public class TimelineViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current mode (scene, sequence, global)
    @Published public var mode: TimelineMode = .scene

    /// Computed timeline segments
    @Published public private(set) var segments: [TimelineSegment] = []

    /// Timeline markers (user + boundaries)
    @Published public private(set) var markers: [TimelineMarker] = []

    /// Scene boundaries
    @Published public private(set) var sceneBoundaries: [TimelineBoundary] = []

    /// Sequence boundaries
    @Published public private(set) var sequenceBoundaries: [TimelineBoundary] = []

    /// Currently selected segment ID
    @Published public var selectedSegmentId: UUID?

    /// Viewport scroll offset
    @Published public var viewportOffset: CGPoint = .zero

    /// Zoom level (pixels per second)
    @Published public var pxPerSec: CGFloat = TimelineLayoutConstants.defaultPxPerSec

    /// Words per minute for duration calculation
    @Published public var wpm: Int = TimelineWPMConstants.defaultWPM

    /// Whether to show character avatars
    @Published public var showThumbs: Bool = true

    /// Loading state
    @Published public var isLoading: Bool = false

    /// Error state
    @Published public var error: Error?

    // MARK: - Private Properties

    /// Current project reference
    private var project: Project?

    /// Current scene (for scene mode)
    private var currentScene: DCScene?

    /// Current sequence (for sequence mode)
    private var currentSequence: DirectorsChairCore.Sequence?

    /// Event bus subscription cancellable
    private var eventSubscription: AnyCancellable?

    // MARK: - Init

    public init() {}

    // MARK: - Public Methods

    /// Set the project reference
    public func setProject(_ project: Project) {
        self.project = project
        // Subscribe to project changes if EventBus is available
    }

    /// Show a single scene on the timeline
    public func showScene(_ scene: DCScene) {
        currentScene = scene
        currentSequence = nil
        mode = .scene
        rebuild()
    }

    /// Show all scenes in a sequence on the timeline
    public func showSequence(_ sequence: DirectorsChairCore.Sequence) {
        currentSequence = sequence
        currentScene = nil
        mode = .sequence
        rebuild()
    }

    /// Show all sequences and scenes (global view)
    public func showGlobal() {
        currentScene = nil
        currentSequence = nil
        mode = .global
        rebuild()
    }

    /// Refresh the timeline (rebuild segments)
    public func refresh() {
        rebuild()
    }

    /// Select a segment by ID
    public func selectSegment(_ id: UUID?) {
        selectedSegmentId = id
    }

    /// Set zoom level
    public func setZoom(_ pxPerSec: CGFloat) {
        self.pxPerSec = max(
            TimelineLayoutConstants.minPxPerSec,
            min(TimelineLayoutConstants.maxPxPerSec, pxPerSec)
        )
    }

    /// Zoom by factor (for pinch gesture)
    public func zoomByFactor(_ factor: CGFloat) {
        let newZoom = pxPerSec * factor
        setZoom(newZoom)
    }

    /// Scroll to a specific time
    public func scrollToTime(_ time: CGFloat) {
        let originX = TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
        let x = originX + time * pxPerSec
        viewportOffset = CGPoint(x: max(0, x - 100), y: viewportOffset.y)
    }

    /// Navigate to next marker
    public func navigateToNextMarker() {
        let allTimes = getAllMarkerTimes()
        let currentTime = getCurrentTimeFromViewport()

        if let nextTime = allTimes.first(where: { $0 > currentTime }) {
            scrollToTime(nextTime)
        }
    }

    /// Navigate to previous marker
    public func navigateToPreviousMarker() {
        let allTimes = getAllMarkerTimes()
        let currentTime = getCurrentTimeFromViewport()

        if let prevTime = allTimes.last(where: { $0 < currentTime }) {
            scrollToTime(prevTime)
        }
    }

    // MARK: - Private Methods

    /// Rebuild segments from current scene/sequence/project data
    private func rebuild() {
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
    private func rebuildForScene() {
        guard let scene = currentScene else {
            segments = []
            markers = []
            sceneBoundaries = []
            sequenceBoundaries = []
            return
        }

        var newSegments: [TimelineSegment] = []
        var newMarkers: [TimelineMarker] = []
        var t: CGFloat = 0

        // Add scene boundary at start
        sceneBoundaries = [TimelineBoundary(time: 0, name: scene.name)]

        // Process dialogues
        for dialogue in scene.dialogues {
            let duration = DurationEstimator.getEffectiveDuration(
                manualDuration: dialogue.manualDuration,
                text: dialogue.text,
                wpm: wpm
            )

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
                propsCount: 0,  // TODO: Count props from dialogue
                hasAudio: dialogue.audioFilePath != nil
            ))

            t += duration
        }

        // Process actions
        for action in scene.actions {
            let duration = TimelineWPMConstants.actionDuration

            newSegments.append(TimelineSegment(
                start: t,
                duration: duration,
                character: "Action",
                color: TimelineDefaultColors.actionBubble,
                textColor: TimelineDefaultColors.defaultText,
                text: action.description,
                sceneName: scene.name,
                contentType: .action,
                chronologyNumber: 0,
                propsCount: action.effects.count
            ))

            t += duration
        }

        // Process narrations
        for narration in scene.narrations {
            let duration = DurationEstimator.estimateDialogueDuration(
                text: narration.text,
                wpm: wpm
            )

            newSegments.append(TimelineSegment(
                start: t,
                duration: max(TimelineWPMConstants.actionDuration, duration),
                character: "Narration",
                color: TimelineDefaultColors.narrationBubble,
                textColor: TimelineDefaultColors.defaultText,
                text: narration.text,
                sceneName: scene.name,
                contentType: .narration,
                chronologyNumber: 0
            ))

            t += max(TimelineWPMConstants.actionDuration, duration)
        }

        // Process notes as markers
        for note in scene.sceneNotes {
            newMarkers.append(TimelineMarker(
                time: t,
                label: "Note: \(note.title)",
                kind: .note,
                color: TimelineDefaultColors.noteMarker
            ))
        }

        segments = newSegments
        markers = newMarkers
        sequenceBoundaries = []
    }

    /// Build segments for a sequence (all scenes)
    private func rebuildForSequence() {
        guard let sequence = currentSequence else {
            segments = []
            markers = []
            sceneBoundaries = []
            sequenceBoundaries = []
            return
        }

        var newSegments: [TimelineSegment] = []
        var newMarkers: [TimelineMarker] = []
        var newSceneBoundaries: [TimelineBoundary] = []
        var t: CGFloat = 0

        sequenceBoundaries = [TimelineBoundary(time: 0, name: sequence.name)]

        for scene in sequence.scenes {
            // Add scene boundary
            newSceneBoundaries.append(TimelineBoundary(time: t, name: scene.name))

            // Process dialogues
            for dialogue in scene.dialogues {
                let duration = DurationEstimator.getEffectiveDuration(
                    manualDuration: dialogue.manualDuration,
                    text: dialogue.text,
                    wpm: wpm
                )

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
                    hasAudio: dialogue.audioFilePath != nil
                ))

                t += duration
            }

            // Process actions
            for action in scene.actions {
                newSegments.append(TimelineSegment(
                    start: t,
                    duration: TimelineWPMConstants.actionDuration,
                    character: "Action",
                    color: TimelineDefaultColors.actionBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: action.description,
                    sceneName: scene.name,
                    contentType: .action,
                    chronologyNumber: 0,
                    propsCount: action.effects.count
                ))

                t += TimelineWPMConstants.actionDuration
            }

            // Process narrations
            for narration in scene.narrations {
                let duration = max(
                    TimelineWPMConstants.actionDuration,
                    DurationEstimator.estimateDialogueDuration(text: narration.text, wpm: wpm)
                )

                newSegments.append(TimelineSegment(
                    start: t,
                    duration: duration,
                    character: "Narration",
                    color: TimelineDefaultColors.narrationBubble,
                    textColor: TimelineDefaultColors.defaultText,
                    text: narration.text,
                    sceneName: scene.name,
                    contentType: .narration,
                    chronologyNumber: 0
                ))

                t += duration
            }

            // Process notes as markers
            for note in scene.sceneNotes {
                newMarkers.append(TimelineMarker(
                    time: t,
                    label: "Note: \(note.title)",
                    kind: .note,
                    color: TimelineDefaultColors.noteMarker
                ))
            }

            // Ensure minimum scene duration
            if scene.dialogues.isEmpty && scene.actions.isEmpty && scene.narrations.isEmpty {
                t += TimelineWPMConstants.minSceneDuration
            }
        }

        segments = newSegments
        markers = newMarkers
        sceneBoundaries = newSceneBoundaries
    }

    /// Build segments for global view (all sequences and scenes)
    private func rebuildForGlobal() {
        guard let project = project else {
            segments = []
            markers = []
            sceneBoundaries = []
            sequenceBoundaries = []
            return
        }

        var newSegments: [TimelineSegment] = []
        var newMarkers: [TimelineMarker] = []
        var newSceneBoundaries: [TimelineBoundary] = []
        var newSequenceBoundaries: [TimelineBoundary] = []
        var t: CGFloat = 0

        for sequence in project.sequences {
            // Add sequence boundary
            newSequenceBoundaries.append(TimelineBoundary(time: t, name: sequence.name))

            for scene in sequence.scenes {
                // Add scene boundary
                newSceneBoundaries.append(TimelineBoundary(time: t, name: scene.name))

                // Process dialogues
                for dialogue in scene.dialogues {
                    let duration = DurationEstimator.getEffectiveDuration(
                        manualDuration: dialogue.manualDuration,
                        text: dialogue.text,
                        wpm: wpm
                    )

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
                        hasAudio: dialogue.audioFilePath != nil
                    ))

                    t += duration
                }

                // Process actions
                for action in scene.actions {
                    newSegments.append(TimelineSegment(
                        start: t,
                        duration: TimelineWPMConstants.actionDuration,
                        character: "Action",
                        color: TimelineDefaultColors.actionBubble,
                        textColor: TimelineDefaultColors.defaultText,
                        text: action.description,
                        sceneName: scene.name,
                        contentType: .action,
                        chronologyNumber: 0,
                        propsCount: action.effects.count
                    ))

                    t += TimelineWPMConstants.actionDuration
                }

                // Process narrations
                for narration in scene.narrations {
                    let duration = max(
                        TimelineWPMConstants.actionDuration,
                        DurationEstimator.estimateDialogueDuration(text: narration.text, wpm: wpm)
                    )

                    newSegments.append(TimelineSegment(
                        start: t,
                        duration: duration,
                        character: "Narration",
                        color: TimelineDefaultColors.narrationBubble,
                        textColor: TimelineDefaultColors.defaultText,
                        text: narration.text,
                        sceneName: scene.name,
                        contentType: .narration,
                        chronologyNumber: 0
                    ))

                    t += duration
                }

                // Process notes as markers
                for note in scene.sceneNotes {
                    newMarkers.append(TimelineMarker(
                        time: t,
                        label: "Note: \(note.title)",
                        kind: .note,
                        color: TimelineDefaultColors.noteMarker
                    ))
                }

                // Ensure minimum scene duration
                if scene.dialogues.isEmpty && scene.actions.isEmpty && scene.narrations.isEmpty {
                    t += TimelineWPMConstants.minSceneDuration
                }
            }
        }

        segments = newSegments
        markers = newMarkers
        sceneBoundaries = newSceneBoundaries
        sequenceBoundaries = newSequenceBoundaries
    }

    // MARK: - Helper Methods

    /// Get character color from project
    private func getCharacterColor(_ name: String) -> String {
        guard let project = project,
              let character = project.characters.first(where: { $0.name == name }) else {
            return TimelineDefaultColors.bubbleDefault
        }
        return character.color
    }

    /// Get character text color from project
    private func getCharacterTextColor(_ name: String) -> String {
        guard let project = project,
              let character = project.characters.first(where: { $0.name == name }) else {
            return TimelineDefaultColors.defaultText
        }
        return character.textColor
    }

    /// Get character avatar path from project
    private func getCharacterAvatar(_ name: String) -> String? {
        guard let project = project,
              let character = project.characters.first(where: { $0.name == name }) else {
            return nil
        }
        return character.avatar
    }

    /// Get all marker times (for navigation)
    private func getAllMarkerTimes() -> [CGFloat] {
        var times: [CGFloat] = []

        // Add scene boundaries
        times.append(contentsOf: sceneBoundaries.map { $0.time })

        // Add sequence boundaries
        times.append(contentsOf: sequenceBoundaries.map { $0.time })

        // Add user markers
        times.append(contentsOf: markers.map { $0.time })

        return times.sorted()
    }

    /// Get current time from viewport position
    private func getCurrentTimeFromViewport() -> CGFloat {
        let originX = TimelineLayoutConstants.leftMargin + TimelineLayoutConstants.rowLabelWidth
        let scrollX = viewportOffset.x + 100
        return max(0, (scrollX - originX) / pxPerSec)
    }
}
