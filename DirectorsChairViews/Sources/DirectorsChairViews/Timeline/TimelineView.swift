// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineView.swift
//
// Main Timeline View with controls, scrolling, and interactions

import SwiftUI
import Combine
import DirectorsChairCore

/// Main Timeline View for DirectorsChair
/// Displays dialogue segments on a scrollable, zoomable timeline with viewport culling
public struct TimelineView: View {
    // MARK: - Properties

    @ObservedObject public var viewModel: TimelineViewModel

    /// Project base path for loading character images
    public var projectBasePath: URL?

    /// Callback when a segment is clicked
    public var onSegmentClicked: ((TimelineSegment) -> Void)?

    /// Callback when a segment is double-clicked
    public var onSegmentDoubleClicked: ((TimelineSegment) -> Void)?

    /// Callback when a shot label is double-clicked (passes shotId and sceneName)
    public var onShotLabelDoubleClicked: ((Int, String) -> Void)?

    /// Callback when a scene marker is double-clicked (passes sceneName)
    public var onSceneMarkerDoubleClicked: ((String) -> Void)?

    /// Callback when a light cue is double-clicked (passes cueId)
    public var onLightCueDoubleClicked: ((String) -> Void)?

    /// Callback when an SFX cue is double-clicked (passes cueId)
    public var onSFXCueDoubleClicked: ((String) -> Void)?

    /// Callback when a support cue is double-clicked (passes cueId)
    public var onSupportCueDoubleClicked: ((String) -> Void)?

    /// Callback when a shot label is dragged to a new time (shotId, sceneName, newTime)
    public var onShotLabelMoved: ((Int, String, CGFloat) -> Void)?

    /// Callback when a shot label is resized to a new duration (shotId, sceneName, newDuration)
    public var onShotLabelResized: ((Int, String, CGFloat) -> Void)?

    /// Callback when a segment is Option+clicked (jump to script)
    public var onOptionClickSegment: ((TimelineSegment) -> Void)?

    /// Callback when a shot label is Option+clicked (jump to script) — (shotId, sceneName)
    public var onOptionClickShotLabel: ((Int, String) -> Void)?

    /// Callback when a segment is dragged to a new time (segment, newStartTime)
    public var onSegmentMoved: ((TimelineSegment, CGFloat) -> Void)?

    /// Callback when multiple segments are dragged together (batch move)
    public var onSegmentsMoved: (([(TimelineSegment, CGFloat)]) -> Void)?

    /// Callback when the Analyze button is clicked
    public var onAnalyzeTimeline: (() -> Void)?

    /// Callback when TTS audio should be generated for a dialogue segment
    public var onGenerateAudio: ((TimelineSegment) -> Void)?

    /// Callback when TTS audio should be played for a dialogue segment
    public var onPlayAudio: ((TimelineSegment) -> Void)?

    /// Callback when TTS audio playback should stop
    public var onStopAudio: (() -> Void)?

    // MARK: - Init

    public init(
        viewModel: TimelineViewModel,
        projectBasePath: URL? = nil,
        onSegmentClicked: ((TimelineSegment) -> Void)? = nil,
        onSegmentDoubleClicked: ((TimelineSegment) -> Void)? = nil,
        onOptionClickSegment: ((TimelineSegment) -> Void)? = nil,
        onOptionClickShotLabel: ((Int, String) -> Void)? = nil,
        onShotLabelDoubleClicked: ((Int, String) -> Void)? = nil,
        onSceneMarkerDoubleClicked: ((String) -> Void)? = nil,
        onLightCueDoubleClicked: ((String) -> Void)? = nil,
        onSFXCueDoubleClicked: ((String) -> Void)? = nil,
        onSupportCueDoubleClicked: ((String) -> Void)? = nil,
        onShotLabelMoved: ((Int, String, CGFloat) -> Void)? = nil,
        onShotLabelResized: ((Int, String, CGFloat) -> Void)? = nil,
        onSegmentMoved: ((TimelineSegment, CGFloat) -> Void)? = nil,
        onSegmentsMoved: (([(TimelineSegment, CGFloat)]) -> Void)? = nil,
        onAnalyzeTimeline: (() -> Void)? = nil,
        onGenerateAudio: ((TimelineSegment) -> Void)? = nil,
        onPlayAudio: ((TimelineSegment) -> Void)? = nil,
        onStopAudio: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.projectBasePath = projectBasePath
        self.onSegmentClicked = onSegmentClicked
        self.onSegmentDoubleClicked = onSegmentDoubleClicked
        self.onOptionClickSegment = onOptionClickSegment
        self.onOptionClickShotLabel = onOptionClickShotLabel
        self.onShotLabelDoubleClicked = onShotLabelDoubleClicked
        self.onSceneMarkerDoubleClicked = onSceneMarkerDoubleClicked
        self.onLightCueDoubleClicked = onLightCueDoubleClicked
        self.onSFXCueDoubleClicked = onSFXCueDoubleClicked
        self.onSupportCueDoubleClicked = onSupportCueDoubleClicked
        self.onShotLabelMoved = onShotLabelMoved
        self.onShotLabelResized = onShotLabelResized
        self.onSegmentMoved = onSegmentMoved
        self.onSegmentsMoved = onSegmentsMoved
        self.onAnalyzeTimeline = onAnalyzeTimeline
        self.onGenerateAudio = onGenerateAudio
        self.onPlayAudio = onPlayAudio
        self.onStopAudio = onStopAudio
    }

    // MARK: - Computed Layout

    /// Total content height of all track lanes (for scroll range calculation)
    /// Compute number of sub-lanes for overlapping light cues (greedy interval coloring)
    private func lightCueSubLaneCount(_ cues: [LightCue]) -> Int {
        guard !cues.isEmpty else { return 0 }
        let sorted = cues.sorted { $0.startTime < $1.startTime }
        var subLaneEnds: [Double] = []
        for cue in sorted {
            var placed = false
            for i in 0..<subLaneEnds.count {
                if cue.startTime >= subLaneEnds[i] {
                    subLaneEnds[i] = cue.startTime + cue.duration
                    placed = true
                    break
                }
            }
            if !placed {
                subLaneEnds.append(cue.startTime + cue.duration)
            }
        }
        return subLaneEnds.count
    }

    /// Compute number of sub-lanes for overlapping SFX cues
    private func sfxCueSubLaneCount(_ cues: [SFXCue]) -> Int {
        guard !cues.isEmpty else { return 0 }
        let sorted = cues.sorted { $0.startTime < $1.startTime }
        var subLaneEnds: [Double] = []
        for cue in sorted {
            var placed = false
            for i in 0..<subLaneEnds.count {
                if cue.startTime >= subLaneEnds[i] {
                    subLaneEnds[i] = cue.startTime + cue.duration
                    placed = true
                    break
                }
            }
            if !placed {
                subLaneEnds.append(cue.startTime + cue.duration)
            }
        }
        return subLaneEnds.count
    }

    /// Compute number of sub-lanes for overlapping support cues
    private func supportCueSubLaneCount(_ cues: [SupportCue]) -> Int {
        guard !cues.isEmpty else { return 0 }
        let sorted = cues.sorted { $0.startTime < $1.startTime }
        var subLaneEnds: [Double] = []
        for cue in sorted {
            var placed = false
            for i in 0..<subLaneEnds.count {
                if cue.startTime >= subLaneEnds[i] {
                    subLaneEnds[i] = cue.startTime + cue.duration
                    placed = true
                    break
                }
            }
            if !placed {
                subLaneEnds.append(cue.startTime + cue.duration)
            }
        }
        return subLaneEnds.count
    }

    private func totalTracksContentHeight() -> CGFloat {
        var seen = Set<String>()
        var order: [String] = []
        // Characters with segments
        for segment in viewModel.visibleSegments {
            if !seen.contains(segment.character) {
                seen.insert(segment.character)
                order.append(segment.character)
            }
        }
        // All project characters (even without segments in current scope)
        for name in viewModel.allCharacterNames {
            if !seen.contains(name) {
                seen.insert(name)
                order.append(name)
            }
        }
        let heights: [CGFloat] = order.map { character in
            if viewModel.hiddenTracks.contains(character) {
                return TimelineLayoutConstants.collapsedRowHeight
            }
            let subLaneCount = viewModel.laneSubLaneCounts[character] ?? 1
            return CGFloat(subLaneCount) * TimelineLayoutConstants.subLaneHeight
        }
        let lanesHeight = heights.reduce(0, +)
        let gapsHeight = CGFloat(max(0, heights.count - 1)) * TimelineLayoutConstants.rowGap
        let contentHeight = lanesHeight + gapsHeight + TimelineLayoutConstants.bottomPadding
        return max(TimelineLayoutConstants.minCanvasHeight, contentHeight)
    }

    /// Height of the fixed header area (scope markers + ruler + ruler gap + shot lane + soundtrack lanes + lighting lane)
    private var headerHeight: CGFloat {
        let shotLaneOffset = viewModel.showShotLabels
            ? CGFloat(viewModel.shotLaneSubLaneCount) * TimelineLayoutConstants.shotLaneHeight
            : 0
        let soundtrackOffset: CGFloat = (viewModel.showSoundtracks && !viewModel.soundtrackTracks.isEmpty)
            ? CGFloat(viewModel.soundtrackTracks.count) * TimelineLayoutConstants.soundtrackLaneHeight
            : 0
        let lightingOffset: CGFloat
        if !viewModel.lightCues.isEmpty {
            if viewModel.showLightingLane {
                let lightingSubLaneCount = lightCueSubLaneCount(viewModel.lightCues)
                lightingOffset = CGFloat(lightingSubLaneCount) * TimelineLayoutConstants.lightingLaneHeight
            } else {
                lightingOffset = 24 // Collapsed strip
            }
        } else {
            lightingOffset = 0
        }
        let sfxOffset: CGFloat
        if !viewModel.sfxCues.isEmpty {
            if viewModel.showSFXLane {
                let sfxSubLaneCount = sfxCueSubLaneCount(viewModel.sfxCues)
                sfxOffset = CGFloat(sfxSubLaneCount) * TimelineLayoutConstants.sfxLaneHeight
            } else {
                sfxOffset = 24
            }
        } else {
            sfxOffset = 0
        }
        let supportOffset: CGFloat
        if !viewModel.supportCues.isEmpty {
            if viewModel.showSupportLane {
                let supportSubLaneCount = supportCueSubLaneCount(viewModel.supportCues)
                supportOffset = CGFloat(supportSubLaneCount) * TimelineLayoutConstants.supportLaneHeight
            } else {
                supportOffset = 24
            }
        } else {
            supportOffset = 0
        }
        return TimelineLayoutConstants.topMargin +
               TimelineLayoutConstants.rulerHeight +
               TimelineLayoutConstants.rulerGap +
               shotLaneOffset +
               soundtrackOffset +
               lightingOffset +
               sfxOffset +
               supportOffset
    }

    // MARK: - State

    /// Virtual vertical scroll offset for tracks (avoids nested ScrollView issues)
    @State private var tracksVerticalOffset: CGFloat = 0

    // MARK: - Body

    public var body: some View {
        GeometryReader { outerGeometry in
            VStack(spacing: 8) {
                // Control buttons row
                TimelineControlsView(viewModel: viewModel, viewportWidth: outerGeometry.size.width, onAnalyzeTimeline: onAnalyzeTimeline)
                    .onAppear { viewModel.viewportWidth = outerGeometry.size.width }
                    .onChange(of: outerGeometry.size.width) { _, w in viewModel.viewportWidth = w }

                // Timeline area: fixed header + tracks canvas
                GeometryReader { geometry in
                    // Ensure tracks always get at least some minimum height,
                    // capping the header when the panel is too small
                    let minTrackHeight: CGFloat = 100
                    let naturalHeaderHeight = headerHeight
                    let effectiveHeaderHeight: CGFloat = geometry.size.height >= naturalHeaderHeight + minTrackHeight
                        ? naturalHeaderHeight
                        : max(0, geometry.size.height - minTrackHeight)
                    let availableTrackHeight: CGFloat = geometry.size.height >= naturalHeaderHeight + minTrackHeight
                        ? geometry.size.height - naturalHeaderHeight
                        : min(minTrackHeight, geometry.size.height)

                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Fixed header: time ruler, shot labels, scope marker labels
                            makeHeaderCanvas(geometry: geometry)
                                .frame(height: effectiveHeaderHeight)
                                .clipped()

                            // Tracks canvas with virtual vertical scrolling
                            // (no nested ScrollView — offset-based scrolling within Canvas)
                            makeTimelineCanvas(geometry: geometry)
                            .gesture(magnificationGesture)
                        }
                        .background(
                            // Invisible helper inside scroll content — finds enclosing NSScrollView
                            TimelineScrollHelper(
                                scrollOffset: viewModel.viewportOffset.x,
                                trigger: viewModel.scrollRequestId
                            )
                        )
                        .background(
                            // Vertical scroll helper — captures scroll wheel events
                            // within the enclosing NSScrollView and updates virtual track offset
                            TrackVerticalScrollHelper(
                                verticalOffset: $tracksVerticalOffset,
                                contentHeight: totalTracksContentHeight(),
                                viewportHeight: availableTrackHeight
                            )
                        )
                    }
                    .background(Color(hex: "#1E1E1E") ?? .black)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(hex: "#3A3A3A") ?? .gray, lineWidth: 1)
                    )
                }
            }
            .padding(8)
            .background(Color(hex: "#262626") ?? .black)
            .onAppear {
                UserDefaults.standard.set(0, forKey: "NSInitialToolTipDelay")
            }
            .onChange(of: viewModel.visibleSegments) { _, _ in
                // Clamp vertical offset when content changes (e.g. scene switch)
                let maxOffset = max(0, totalTracksContentHeight() - 100)
                if tracksVerticalOffset > maxOffset {
                    tracksVerticalOffset = maxOffset
                }
            }
        }
    }

    // MARK: - Helpers

    /// Extracted to reduce body expression complexity for the Swift type-checker
    private func makeHeaderCanvas(geometry: GeometryProxy) -> TimelineHeaderCanvas {
        TimelineHeaderCanvas(
            segments: viewModel.visibleSegments,
            sceneBoundaries: viewModel.sceneBoundaries,
            sequenceBoundaries: viewModel.sequenceBoundaries,
            shotLabels: viewModel.shotLabels,
            showShotLabels: viewModel.showShotLabels,
            pxPerSec: viewModel.pxPerSec,
            mode: viewModel.mode,
            viewportSize: geometry.size,
            shotSubLaneAssignments: viewModel.shotSubLaneAssignments,
            shotLaneSubLaneCount: viewModel.shotLaneSubLaneCount,
            shotDialogueConnections: viewModel.shotDialogueConnections,
            showShotConnections: viewModel.showShotConnections,
            playheadTime: viewModel.playheadTime,
            playheadActive: viewModel.playheadActive,
            userMarkers: viewModel.showUserMarkers ? viewModel.userMarkers : [],
            projectBasePath: projectBasePath,
            soundtrackTracks: viewModel.soundtrackTracks,
            showSoundtracks: viewModel.showSoundtracks,
            lightCues: viewModel.lightCues,
            showLightingLane: viewModel.showLightingLane,
            sfxCues: viewModel.sfxCues,
            showSFXLane: viewModel.showSFXLane,
            supportCues: viewModel.supportCues,
            showSupportLane: viewModel.showSupportLane,
            onLightCueAdded: { time, name, number, workflow, fixture, intensity, duration, color in
                let cue = LightCue(
                    name: name,
                    cueNumber: number,
                    workflow: workflow,
                    fixtureType: fixture,
                    startTime: Double(time),
                    duration: duration,
                    intensity: intensity,
                    color: color,
                    markerColor: color
                )
                viewModel.lightCues.append(cue)
                viewModel.onLightCuesChanged?(viewModel.lightCues)
            },
            onLightCueDeleted: { cueId in
                viewModel.removeLightCue(id: cueId)
            },
            onLightCueUpdated: { cue in
                viewModel.updateLightCue(cue)
            },
            onLightCueMoved: { cueId, newStartTime in
                if var cue = viewModel.lightCues.first(where: { $0.id == cueId }) {
                    cue.startTime = newStartTime
                    viewModel.updateLightCue(cue)
                }
            },
            onLightCueResized: { cueId, newDuration in
                if var cue = viewModel.lightCues.first(where: { $0.id == cueId }) {
                    cue.duration = newDuration
                    viewModel.updateLightCue(cue)
                }
            },
            onLightCueDoubleClicked: { cueId in
                onLightCueDoubleClicked?(cueId)
            },
            onLightingLaneToggled: {
                viewModel.showLightingLane.toggle()
            },
            onSFXCueAdded: { time, name, number, effectType, intensity, duration, color in
                let cue = SFXCue(
                    name: name,
                    cueNumber: number,
                    effectType: effectType,
                    startTime: Double(time),
                    duration: duration,
                    intensity: intensity,
                    color: color,
                    markerColor: color
                )
                viewModel.sfxCues.append(cue)
                viewModel.onSFXCuesChanged?(viewModel.sfxCues)
            },
            onSFXCueDeleted: { cueId in
                viewModel.removeSFXCue(id: cueId)
            },
            onSFXCueUpdated: { cue in
                viewModel.updateSFXCue(cue)
            },
            onSFXCueMoved: { cueId, newStartTime in
                if var cue = viewModel.sfxCues.first(where: { $0.id == cueId }) {
                    cue.startTime = newStartTime
                    viewModel.updateSFXCue(cue)
                }
            },
            onSFXCueResized: { cueId, newDuration in
                if var cue = viewModel.sfxCues.first(where: { $0.id == cueId }) {
                    cue.duration = newDuration
                    viewModel.updateSFXCue(cue)
                }
            },
            onSFXCueDoubleClicked: { cueId in
                onSFXCueDoubleClicked?(cueId)
            },
            onSFXLaneToggled: {
                viewModel.showSFXLane.toggle()
            },
            onSupportCueAdded: { time, name, number, actionType, duration, color in
                let cue = SupportCue(
                    name: name,
                    cueNumber: number,
                    actionType: actionType,
                    startTime: Double(time),
                    duration: duration,
                    markerColor: color
                )
                viewModel.supportCues.append(cue)
                viewModel.onSupportCuesChanged?(viewModel.supportCues)
            },
            onSupportCueDeleted: { cueId in
                viewModel.removeSupportCue(id: cueId)
            },
            onSupportCueUpdated: { cue in
                viewModel.updateSupportCue(cue)
            },
            onSupportCueMoved: { cueId, newStartTime in
                if var cue = viewModel.supportCues.first(where: { $0.id == cueId }) {
                    cue.startTime = newStartTime
                    viewModel.updateSupportCue(cue)
                }
            },
            onSupportCueResized: { cueId, newDuration in
                if var cue = viewModel.supportCues.first(where: { $0.id == cueId }) {
                    cue.duration = newDuration
                    viewModel.updateSupportCue(cue)
                }
            },
            onSupportCueDoubleClicked: { cueId in
                onSupportCueDoubleClicked?(cueId)
            },
            onSupportLaneToggled: {
                viewModel.showSupportLane.toggle()
            },
            onSoundtrackMoved: { trackId, newOffset in
                viewModel.moveSoundtrack(id: trackId, newOffset: newOffset)
            },
            onSoundtrackTrackToggled: {
                viewModel.showSoundtracks.toggle()
            },
            onSoundtrackMuteToggled: { trackId in
                viewModel.toggleSoundtrackMute(id: trackId)
            },
            onSoundtrackRemoved: { trackId in
                viewModel.removeSoundtrack(id: trackId)
            },
            onShotLabelDoubleClicked: { shotId, sceneName in
                onShotLabelDoubleClicked?(shotId, sceneName)
            },
            onSceneMarkerDoubleClicked: onSceneMarkerDoubleClicked,
            onShotLabelMoved: { shotId, sceneName, newTime in
                viewModel.moveShotLabel(shotId: shotId, sceneName: sceneName, newTime: newTime)
                onShotLabelMoved?(shotId, sceneName, newTime)
            },
            onShotLabelSelected: { labelId in
                viewModel.selectedShotLabelId = labelId
            },
            onOptionClickShotLabel: { shotId, sceneName in
                onOptionClickShotLabel?(shotId, sceneName)
            },
            onShotTrackToggled: {
                viewModel.showShotLabels.toggle()
            },
            onShotLabelResized: { shotId, sceneName, newDuration in
                viewModel.resizeShotLabel(shotId: shotId, sceneName: sceneName, newDuration: newDuration)
                onShotLabelResized?(shotId, sceneName, newDuration)
            },
            onSceneBoundaryMoved: { name, newTime in
                viewModel.moveSceneBoundary(name: name, newTime: newTime)
            },
            onSequenceBoundaryMoved: { name, newTime in
                viewModel.moveSequenceBoundary(name: name, newTime: newTime)
            },
            onRulerClicked: { x in
                viewModel.seekPlayheadFromX(x)
            },
            onPlayheadDragged: { x in
                viewModel.seekPlayheadFromX(x)
            },
            onMarkerDeleted: { id in
                viewModel.deleteUserMarker(id: id)
            },
            onMarkerUpdated: { id, label, icon, color in
                viewModel.updateUserMarker(id: id, label: label, icon: icon, color: color)
            },
            onMarkerAdded: { time, label, icon, color in
                viewModel.addUserMarker(at: time, label: label, icon: icon, color: color)
            }
        )
    }

    /// Extracted to reduce body expression complexity for the Swift type-checker
    private func makeTimelineCanvas(geometry: GeometryProxy) -> some View {
        let minTrackHeight: CGFloat = 100
        let naturalHeaderHeight = headerHeight
        let computedTrackHeight: CGFloat = geometry.size.height >= naturalHeaderHeight + minTrackHeight
            ? geometry.size.height - naturalHeaderHeight
            : min(minTrackHeight, geometry.size.height)

        var canvas = TimelineCanvas(
            segments: viewModel.visibleSegments,
            markers: viewModel.visibleMarkers,
            sceneBoundaries: viewModel.sceneBoundaries,
            sequenceBoundaries: viewModel.sequenceBoundaries,
            playheadTime: viewModel.playheadTime,
            pxPerSec: viewModel.pxPerSec,
            showThumbs: viewModel.showThumbs,
            mode: viewModel.mode,
            projectBasePath: projectBasePath,
            viewportSize: geometry.size,
            hiddenTracks: viewModel.hiddenTracks,
            subLaneAssignments: viewModel.subLaneAssignments,
            laneSubLaneCounts: viewModel.laneSubLaneCounts,
            shotDialogueConnections: viewModel.shotDialogueConnections,
            showShotConnections: viewModel.showShotConnections,
            selectedShotLabelId: viewModel.selectedShotLabelId,
            allCharacterNames: viewModel.allCharacterNames,
            verticalOffset: tracksVerticalOffset,
            availableHeight: computedTrackHeight,
            selectedSegmentIds: $viewModel.selectedSegmentIds,
            viewportOffset: $viewModel.viewportOffset,
            onSegmentSelected: { segment in
                onSegmentClicked?(segment)
            },
            onSegmentDoubleClicked: { segment in
                onSegmentDoubleClicked?(segment)
            },
            onOptionClickSegment: { segment in
                onOptionClickSegment?(segment)
            },
            onTrackToggled: { trackName in
                viewModel.toggleTrackVisibility(trackName)
            },
            onSegmentMoved: { segment, newTime in
                viewModel.moveSegment(id: segment.id, newStart: newTime)
                onSegmentMoved?(segment, newTime)
            },
            onSegmentsMoved: { moves in
                let tuples = moves.map { (segment: $0.0, newStart: $0.1) }
                viewModel.moveSegments(tuples)
                onSegmentsMoved?(moves)
            }
        )
        canvas.effectiveDuration = viewModel.totalDuration
        canvas.generatingAudioSourceIds = viewModel.generatingAudioSourceIds
        canvas.playingAudioSourceId = viewModel.playingAudioSourceId
        canvas.onEmptySpaceClicked = { x in
            viewModel.seekPlayheadFromX(x)
        }
        canvas.onSegmentRightClicked = { segment, point, nsView in
            let menu = NSMenu()

            if segment.contentType == .dialogue, let sourceId = segment.sourceItemId {
                let isGenerating = viewModel.generatingAudioSourceIds.contains(sourceId)
                let isPlaying = viewModel.playingAudioSourceId == sourceId

                if isGenerating {
                    let item = NSMenuItem(title: "Generating...", action: nil, keyEquivalent: "")
                    item.isEnabled = false
                    item.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: nil)
                    menu.addItem(item)
                } else if isPlaying {
                    let stopItem = NSMenuItem(title: "Stop Voice", action: nil, keyEquivalent: "")
                    stopItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
                    let stopHandler = TrackMenuHandler { [weak viewModel] in
                        viewModel?.playingAudioSourceId = nil
                        self.onStopAudio?()
                    }
                    stopItem.target = stopHandler
                    stopItem.action = #selector(TrackMenuHandler.execute)
                    stopItem.representedObject = stopHandler
                    menu.addItem(stopItem)
                } else if segment.hasAudio {
                    let playItem = NSMenuItem(title: "Play Voice", action: nil, keyEquivalent: "")
                    playItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
                    let playHandler = TrackMenuHandler {
                        self.onPlayAudio?(segment)
                    }
                    playItem.target = playHandler
                    playItem.action = #selector(TrackMenuHandler.execute)
                    playItem.representedObject = playHandler
                    menu.addItem(playItem)

                    let regenItem = NSMenuItem(title: "Regenerate Voice", action: nil, keyEquivalent: "")
                    regenItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
                    let regenHandler = TrackMenuHandler {
                        self.onGenerateAudio?(segment)
                    }
                    regenItem.target = regenHandler
                    regenItem.action = #selector(TrackMenuHandler.execute)
                    regenItem.representedObject = regenHandler
                    menu.addItem(regenItem)
                } else {
                    let genItem = NSMenuItem(title: "Generate Voice", action: nil, keyEquivalent: "")
                    genItem.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
                    let genHandler = TrackMenuHandler {
                        self.onGenerateAudio?(segment)
                    }
                    genItem.target = genHandler
                    genItem.action = #selector(TrackMenuHandler.execute)
                    genItem.representedObject = genHandler
                    menu.addItem(genItem)
                }

                menu.addItem(NSMenuItem.separator())
            }

            // Always include track mute option
            let character = segment.character
            let isMuted = viewModel.mutedTracks.contains(character)
            let muteItem = NSMenuItem(
                title: isMuted ? "Unmute \"\(character)\" TTS" : "Mute \"\(character)\" TTS",
                action: nil,
                keyEquivalent: ""
            )
            muteItem.image = NSImage(systemSymbolName: isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill", accessibilityDescription: nil)
            let muteHandler = TrackMenuHandler {
                if isMuted {
                    viewModel.mutedTracks.remove(character)
                } else {
                    viewModel.mutedTracks.insert(character)
                }
                viewModel.onTrackMuteToggled?(character)
            }
            muteItem.target = muteHandler
            muteItem.action = #selector(TrackMenuHandler.execute)
            muteItem.representedObject = muteHandler
            menu.addItem(muteItem)

            let screenPoint = nsView.window?.convertPoint(toScreen: nsView.convert(
                CGPoint(x: point.x, y: nsView.bounds.height - point.y), to: nil
            )) ?? NSEvent.mouseLocation
            menu.popUp(positioning: nil, at: screenPoint, in: nil)
        }
        canvas.onTrackRightClicked = { character, point, nsView in
            let isMuted = viewModel.mutedTracks.contains(character)
            let menu = NSMenu()

            let muteItem = NSMenuItem(
                title: isMuted ? "Unmute \"\(character)\" TTS" : "Mute \"\(character)\" TTS",
                action: nil,
                keyEquivalent: ""
            )
            let muteIcon = NSImage(systemSymbolName: isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill", accessibilityDescription: nil)
            muteItem.image = muteIcon

            let handler = TrackMenuHandler {
                if isMuted {
                    viewModel.mutedTracks.remove(character)
                } else {
                    viewModel.mutedTracks.insert(character)
                }
                viewModel.onTrackMuteToggled?(character)
            }
            muteItem.target = handler
            muteItem.action = #selector(TrackMenuHandler.execute)
            muteItem.representedObject = handler
            menu.addItem(muteItem)

            let screenPoint = nsView.window?.convertPoint(toScreen: nsView.convert(
                CGPoint(x: point.x, y: nsView.bounds.height - point.y), to: nil
            )) ?? NSEvent.mouseLocation
            menu.popUp(positioning: nil, at: screenPoint, in: nil)
        }
        return canvas
    }

    // MARK: - Gestures

    /// Pinch-to-zoom gesture
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                viewModel.zoomByFactor(scale)
            }
    }
}

// MARK: - Timeline Controls View

/// Header controls for the timeline (two rows: navigation/info and filters/display)
struct TimelineControlsView: View {
    @ObservedObject var viewModel: TimelineViewModel
    var viewportWidth: CGFloat = 800
    var onAnalyzeTimeline: (() -> Void)?

    var body: some View {
        VStack(spacing: 4) {
            // Row 1: Navigation & Info
            HStack(spacing: 12) {
                // Title
                Text("Timeline")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#E6E6E6") ?? .white)

                // Scene navigation (prev / name / next)
                if viewModel.allScenesInScope.count > 1 {
                    HStack(spacing: 4) {
                        Button(action: { viewModel.navigateToPreviousScene() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(viewModel.currentSceneIndex > 0 ? .white : Color(hex: "#555555") ?? .gray)
                        .disabled(viewModel.currentSceneIndex <= 0)
                        .help("Previous Scene")

                        Text(viewModel.currentSceneIndex < viewModel.allScenesInScope.count
                             ? viewModel.allScenesInScope[viewModel.currentSceneIndex].name
                             : "")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#CCCCCC") ?? .white)
                            .lineLimit(1)
                            .frame(maxWidth: 180)

                        Button(action: { viewModel.navigateToNextScene() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(viewModel.currentSceneIndex < viewModel.allScenesInScope.count - 1 ? .white : Color(hex: "#555555") ?? .gray)
                        .disabled(viewModel.currentSceneIndex >= viewModel.allScenesInScope.count - 1)
                        .help("Next Scene")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#333333") ?? .gray)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .help("Navigate between scenes")
                }

                Spacer()

                // Fit button
                Button(action: { viewModel.zoomToFit(viewportWidth: viewportWidth) }) {
                    Image(systemName: "arrow.left.and.right.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("Zoom to Fit (Cmd+Shift+0)")

                // Global view toggle
                Toggle("Global", isOn: Binding(
                    get: { viewModel.mode == .global },
                    set: { if $0 { viewModel.showGlobal() } }
                ))
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .font(.system(size: 11))
                .help("Show all sequences and scenes on timeline")

                Divider()
                    .frame(height: 20)

                // Duration display
                HStack(spacing: 4) {
                    Text("Duration:")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#AAAAAA") ?? .gray)
                    Text(formatDuration(viewModel.currentSceneDuration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                    if viewModel.mode != .scene && viewModel.totalDuration != viewModel.currentSceneDuration {
                        Text("/")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#666666") ?? .gray)
                        Text(formatDuration(viewModel.totalDuration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "#AAAAAA") ?? .gray)
                    }
                }
                .help("Current scene / Total duration")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Row 2: Filters & Display
            HStack(spacing: 12) {
                // Track filter buttons
                HStack(spacing: 2) {
                    Text("Tracks:")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#AAAAAA") ?? .gray)

                    TrackFilterButton(
                        systemImage: "text.bubble.fill",
                        color: Color(hex: "#3498DB") ?? .blue,
                        isEnabled: $viewModel.showDialogue,
                        tooltip: "Toggle Dialogue tracks"
                    )

                    TrackFilterButton(
                        systemImage: "figure.walk",
                        color: Color(hex: TimelineDefaultColors.actionBubble) ?? .orange,
                        isEnabled: $viewModel.showAction,
                        tooltip: "Toggle Action track"
                    )

                    TrackFilterButton(
                        systemImage: "text.quote",
                        color: Color(hex: TimelineDefaultColors.narrationBubble) ?? .purple,
                        isEnabled: $viewModel.showNarration,
                        tooltip: "Toggle Narration track"
                    )

                    TrackFilterButton(
                        systemImage: "speaker.wave.2.fill",
                        color: Color(hex: TimelineDefaultColors.soundNoteBubble) ?? .cyan,
                        isEnabled: $viewModel.showSoundNote,
                        tooltip: "Toggle Sound track"
                    )
                }

                Divider()
                    .frame(height: 20)

                // Marker navigation buttons
                HStack(spacing: 4) {
                    Button(action: { viewModel.navigateToPreviousMarker() }) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                            Text("Marker")
                        }
                        .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .help("Previous Marker (J)")

                    Button(action: { viewModel.navigateToNextMarker() }) {
                        HStack(spacing: 2) {
                            Text("Marker")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .help("Next Marker (L)")

                }

                // Playhead time display
                if let _ = viewModel.playheadTime {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: TimelineDefaultColors.playheadColor))
                        Text(viewModel.playheadTimeFormatted)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: TimelineDefaultColors.playheadColor))
                    }
                    .help("Playhead position")
                }

                Divider()
                    .frame(height: 20)

                // WPM control
                HStack(spacing: 4) {
                    Text("WPM:")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#AAAAAA") ?? .gray)

                    Stepper(
                        value: $viewModel.wpm,
                        in: TimelineWPMConstants.minWPM...TimelineWPMConstants.maxWPM,
                        step: 10
                    ) {
                        Text("\(viewModel.wpm)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 35, alignment: .trailing)
                    }
                    .onChange(of: viewModel.wpm) { _, _ in
                        viewModel.refresh()
                    }
                }
                .help("Words Per Minute - adjusts dialogue duration calculation")

                Divider()
                    .frame(height: 20)

                // Zoom control
                HStack(spacing: 4) {
                    Text("Zoom:")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#AAAAAA") ?? .gray)

                    Slider(
                        value: $viewModel.pxPerSec,
                        in: TimelineLayoutConstants.minPxPerSec...TimelineLayoutConstants.maxPxPerSec
                    )
                    .frame(width: 100)

                    Text("\(Int(viewModel.pxPerSec))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 30, alignment: .trailing)
                }
                .help("Zoom: Pixels per second - adjust timeline scale")

                Spacer()

                // Thumbnails toggle
                Toggle(isOn: $viewModel.showThumbs) {
                    Text("Thumbs")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                .help("Show character avatar thumbnails in dialogue bubbles")

                // Shot labels toggle
                Toggle(isOn: $viewModel.showShotLabels) {
                    Text("Shots")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                .help("Show shots lane on timeline")

                // Soundtrack toggle
                Toggle(isOn: $viewModel.showSoundtracks) {
                    Text("Audio")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                .help("Show/hide soundtrack waveform lanes")

                // Import Audio button
                Button(action: { viewModel.onImportSoundtrack?() }) {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .help("Import audio file (MP3, WAV, M4A)")

                // Shot-dialogue connection lines toggle
                Toggle(isOn: $viewModel.showShotConnections) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                .help("Show connections between shots and linked dialogues")

                // User markers visibility toggle
                Toggle(isOn: $viewModel.showUserMarkers) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                .help("Show custom markers on timeline")

                if let onAnalyze = onAnalyzeTimeline {
                    Divider()
                        .frame(height: 20)

                    Button(action: onAnalyze) {
                        HStack(spacing: 3) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11))
                            Text("Analyze")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("AI-analyze timeline organization")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color(hex: "#2D2D2D") ?? .gray)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Format duration as MM:SS
    private func formatDuration(_ seconds: CGFloat) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Track Filter Button

/// A compact toggle button for track visibility
struct TrackFilterButton: View {
    let systemImage: String
    let color: Color
    @Binding var isEnabled: Bool
    let tooltip: String

    var body: some View {
        Button(action: { isEnabled.toggle() }) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isEnabled ? .white : color)
                .frame(width: 22, height: 22)
                .background(isEnabled ? color : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(color, lineWidth: isEnabled ? 0 : 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Preview

// MARK: - Timeline Scroll Helper

/// NSViewRepresentable that programmatically scrolls the enclosing NSScrollView
/// when triggered. This bridges SwiftUI's ScrollView with AppKit's NSScrollView
/// to enable precise horizontal scroll position control.
private struct TimelineScrollHelper: NSViewRepresentable {
    let scrollOffset: CGFloat
    let trigger: UUID?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard trigger != nil else { return }
        // Defer to next runloop tick so the scroll view layout is settled
        DispatchQueue.main.async {
            guard let scrollView = nsView.findEnclosingScrollView() else { return }
            let targetX = max(0, scrollOffset)
            let maxScrollX = max(0, scrollView.documentView!.frame.width - scrollView.contentView.bounds.width)
            let clampedX = min(targetX, maxScrollX)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                scrollView.contentView.animator().setBoundsOrigin(
                    NSPoint(x: clampedX, y: scrollView.contentView.bounds.origin.y)
                )
            }
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}

private extension NSView {
    func findEnclosingScrollView() -> NSScrollView? {
        var current: NSView? = self.superview
        while let view = current {
            if let sv = view as? NSScrollView {
                return sv
            }
            current = view.superview
        }
        return nil
    }
}

// MARK: - Track Vertical Scroll Helper

/// NSViewRepresentable placed as `.background` inside the horizontal ScrollView content.
/// Uses a local event monitor to capture scroll wheel events within the enclosing
/// NSScrollView's bounds and updates a virtual vertical offset for the tracks canvas.
private struct TrackVerticalScrollHelper: NSViewRepresentable {
    @Binding var verticalOffset: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> TrackVerticalScrollNSView {
        let view = TrackVerticalScrollNSView()
        view.coordinator = context.coordinator
        context.coordinator.update(
            verticalOffset: $verticalOffset,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight
        )
        return view
    }

    func updateNSView(_ nsView: TrackVerticalScrollNSView, context: Context) {
        context.coordinator.update(
            verticalOffset: $verticalOffset,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight
        )
    }

    class Coordinator {
        var verticalOffsetBinding: Binding<CGFloat>?
        var contentHeight: CGFloat = 0
        var viewportHeight: CGFloat = 0

        func update(verticalOffset: Binding<CGFloat>, contentHeight: CGFloat, viewportHeight: CGFloat) {
            self.verticalOffsetBinding = verticalOffset
            self.contentHeight = contentHeight
            self.viewportHeight = viewportHeight
        }

        func handleScroll(deltaY: CGFloat) {
            guard let binding = verticalOffsetBinding else { return }
            let maxOffset = max(0, contentHeight - viewportHeight)
            guard maxOffset > 0 else { return }
            let newOffset = binding.wrappedValue - deltaY
            binding.wrappedValue = min(maxOffset, max(0, newOffset))
        }
    }

    /// NSView placed as background inside scroll content. Uses enclosing NSScrollView
    /// for reliable bounds checking of scroll wheel events.
    class TrackVerticalScrollNSView: NSView {
        var coordinator: Coordinator?
        private var scrollMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && scrollMonitor == nil {
                scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    self?.handleScrollWheel(event)
                    return event // Always pass through for horizontal ScrollView
                }
            }
        }

        private func handleScrollWheel(_ event: NSEvent) {
            // Use enclosing NSScrollView for reliable bounds checking
            guard let scrollView = self.findEnclosingScrollView() else { return }
            let locationInWindow = event.locationInWindow
            let locationInScrollView = scrollView.convert(locationInWindow, from: nil)
            guard scrollView.bounds.contains(locationInScrollView) else { return }

            let deltaY = event.scrollingDeltaY
            if abs(deltaY) > 0 {
                coordinator?.handleScroll(deltaY: deltaY)
            }
        }

        override func removeFromSuperview() {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
                scrollMonitor = nil
            }
            super.removeFromSuperview()
        }

        deinit {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

#if DEBUG
struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = TimelineViewModel()

        // Add some test segments
        TimelineView(viewModel: viewModel)
            .frame(width: 1200, height: 400)
            .preferredColorScheme(.dark)
    }
}
#endif

// MARK: - Track Menu Handler

/// NSObject target for NSMenu items — holds a closure for the menu action
private class TrackMenuHandler: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
    }
    @objc func execute() {
        action()
    }
}
