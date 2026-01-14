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

    /// Callback when a segment is clicked
    public var onSegmentClicked: ((TimelineSegment) -> Void)?

    /// Callback when a segment is double-clicked
    public var onSegmentDoubleClicked: ((TimelineSegment) -> Void)?

    // MARK: - Init

    public init(
        viewModel: TimelineViewModel,
        onSegmentClicked: ((TimelineSegment) -> Void)? = nil,
        onSegmentDoubleClicked: ((TimelineSegment) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onSegmentClicked = onSegmentClicked
        self.onSegmentDoubleClicked = onSegmentDoubleClicked
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 8) {
            // Header with controls
            TimelineControlsView(viewModel: viewModel)

            // Scrollable timeline canvas
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    TimelineCanvas(
                        segments: viewModel.segments,
                        markers: viewModel.markers,
                        sceneBoundaries: viewModel.sceneBoundaries,
                        sequenceBoundaries: viewModel.sequenceBoundaries,
                        pxPerSec: viewModel.pxPerSec,
                        showThumbs: viewModel.showThumbs,
                        mode: viewModel.mode,
                        selectedSegmentId: $viewModel.selectedSegmentId,
                        viewportOffset: $viewModel.viewportOffset,
                        onSegmentSelected: { segment in
                            onSegmentClicked?(segment)
                        },
                        onSegmentDoubleClicked: { segment in
                            onSegmentDoubleClicked?(segment)
                        }
                    )
                    .gesture(magnificationGesture)
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

/// Header controls for the timeline (zoom, WPM, navigation buttons)
struct TimelineControlsView: View {
    @ObservedObject var viewModel: TimelineViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Title
            Text("Timeline")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#E6E6E6") ?? .white)

            Spacer()

            // Global view toggle
            Toggle("Global", isOn: Binding(
                get: { viewModel.mode == .global },
                set: { if $0 { viewModel.showGlobal() } }
            ))
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .font(.system(size: 11))

            Divider()
                .frame(height: 20)

            // Navigation buttons
            HStack(spacing: 4) {
                Button(action: { viewModel.navigateToPreviousMarker() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .help("Previous Marker")

                Button(action: { viewModel.navigateToNextMarker() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .help("Next Marker")
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
                .frame(width: 120)

                Text("\(Int(viewModel.pxPerSec))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 30, alignment: .trailing)
            }

            Divider()
                .frame(height: 20)

            // Thumbnails toggle
            Toggle(isOn: $viewModel.showThumbs) {
                Text("Thumbs")
                    .font(.system(size: 11))
            }
            .toggleStyle(.checkbox)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(hex: "#2D2D2D") ?? .gray)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Preview

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
