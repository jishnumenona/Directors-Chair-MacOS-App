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
    func lightCueSubLaneCount(_ cues: [LightCue]) -> Int {
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
    func sfxCueSubLaneCount(_ cues: [SFXCue]) -> Int {
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
    func supportCueSubLaneCount(_ cues: [SupportCue]) -> Int {
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

    func totalTracksContentHeight() -> CGFloat {
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
    var headerHeight: CGFloat {
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
    @State var tracksVerticalOffset: CGFloat = 0

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
}
