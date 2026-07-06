//
// TimelineView+Components.swift
//
// Extracted from TimelineView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import Combine
import DirectorsChairCore
import AppKit


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
    func formatDuration(_ seconds: CGFloat) -> String {
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
struct TimelineScrollHelper: NSViewRepresentable {
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

extension NSView {
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
struct TrackVerticalScrollHelper: NSViewRepresentable {
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
class TrackMenuHandler: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
    }
    @objc func execute() {
        action()
    }
}
