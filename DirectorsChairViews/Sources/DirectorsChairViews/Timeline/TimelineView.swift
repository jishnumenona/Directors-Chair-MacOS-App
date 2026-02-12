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

    // MARK: - Init

    public init(
        viewModel: TimelineViewModel,
        projectBasePath: URL? = nil,
        onSegmentClicked: ((TimelineSegment) -> Void)? = nil,
        onSegmentDoubleClicked: ((TimelineSegment) -> Void)? = nil,
        onOptionClickSegment: ((TimelineSegment) -> Void)? = nil,
        onOptionClickShotLabel: ((Int, String) -> Void)? = nil,
        onShotLabelDoubleClicked: ((Int, String) -> Void)? = nil,
        onShotLabelMoved: ((Int, String, CGFloat) -> Void)? = nil,
        onShotLabelResized: ((Int, String, CGFloat) -> Void)? = nil,
        onSegmentMoved: ((TimelineSegment, CGFloat) -> Void)? = nil,
        onSegmentsMoved: (([(TimelineSegment, CGFloat)]) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.projectBasePath = projectBasePath
        self.onSegmentClicked = onSegmentClicked
        self.onSegmentDoubleClicked = onSegmentDoubleClicked
        self.onOptionClickSegment = onOptionClickSegment
        self.onOptionClickShotLabel = onOptionClickShotLabel
        self.onShotLabelDoubleClicked = onShotLabelDoubleClicked
        self.onShotLabelMoved = onShotLabelMoved
        self.onShotLabelResized = onShotLabelResized
        self.onSegmentMoved = onSegmentMoved
        self.onSegmentsMoved = onSegmentsMoved
    }

    // MARK: - Computed Header Height

    /// Height of the fixed header area (scope markers + ruler + ruler gap + shot lane)
    private var headerHeight: CGFloat {
        let shotLaneOffset = viewModel.showShotLabels
            ? CGFloat(viewModel.shotLaneSubLaneCount) * TimelineLayoutConstants.shotLaneHeight
            : 0
        return TimelineLayoutConstants.topMargin +
               TimelineLayoutConstants.rulerHeight +
               TimelineLayoutConstants.rulerGap +
               shotLaneOffset
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { outerGeometry in
            VStack(spacing: 8) {
                // Control buttons row
                TimelineControlsView(viewModel: viewModel, viewportWidth: outerGeometry.size.width)

                // Timeline area: fixed header + vertically-scrollable tracks
                GeometryReader { geometry in
                    let availableTrackHeight = max(0, geometry.size.height - headerHeight)

                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Fixed header: time ruler, shot labels, scope marker labels
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
                                onShotLabelDoubleClicked: { shotId, sceneName in
                                    onShotLabelDoubleClicked?(shotId, sceneName)
                                },
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
                                    viewModel.togglePlayhead(at: x)
                                },
                                onPlayheadDragged: { x in
                                    viewModel.setPlayheadFromX(x)
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

                            // Vertically-scrollable tracks: character lanes + segments
                            ScrollView(.vertical, showsIndicators: true) {
                                TimelineCanvas(
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
                                .gesture(magnificationGesture)
                            }
                            .frame(height: availableTrackHeight)
                        }
                        .background(
                            // Invisible helper inside scroll content — finds enclosing NSScrollView
                            TimelineScrollHelper(
                                scrollOffset: viewModel.viewportOffset.x,
                                trigger: viewModel.scrollRequestId
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
        }
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
