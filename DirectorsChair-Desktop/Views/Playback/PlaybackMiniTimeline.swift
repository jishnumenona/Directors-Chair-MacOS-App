//
//  PlaybackMiniTimeline.swift
//  DirectorsChair-Desktop
//
//  Colored shot strip with playhead indicator and scene boundary markers.
//  Each shot is rendered as a colored rectangle proportional to its duration.
//

import SwiftUI
import DirectorsChairViews

struct PlaybackMiniTimeline: View {
    @ObservedObject var viewModel: PlaybackViewModel

    @State private var isDragging = false
    @State private var dragTime: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                // Background
                Color(nsColor: .controlBackgroundColor).opacity(0.8)

                // Shot blocks
                ForEach(viewModel.playlistItems) { item in
                    let startRatio = viewModel.totalDuration > 0 ? item.startTime / viewModel.totalDuration : 0
                    let durationRatio = viewModel.totalDuration > 0 ? item.duration / viewModel.totalDuration : 0
                    let blockX = startRatio * width
                    let blockW = max(2, durationRatio * width - 1)
                    let isCurrentItem = item.id == viewModel.currentItem?.id

                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForShotType(item.shotType).opacity(isCurrentItem ? 1.0 : 0.6))
                        .frame(width: blockW, height: 28)
                        .offset(x: blockX)
                        .overlay(
                            // Shot number text for wider blocks
                            Group {
                                if blockW > 24, let shotId = item.shotId {
                                    Text("\(shotId)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .offset(x: blockX)
                                }
                            }
                        )
                }

                // Scene boundary markers
                ForEach(viewModel.sceneBoundaries) { boundary in
                    let bx = viewModel.totalDuration > 0 ? (boundary.time / viewModel.totalDuration) * width : 0
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1, height: 40)
                        .offset(x: bx)
                }

                // Playhead
                let displayTime = isDragging ? dragTime : viewModel.currentTime
                let playheadX = viewModel.totalDuration > 0 ? (displayTime / viewModel.totalDuration) * width : 0

                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 40)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .offset(x: max(0, playheadX - 1))

                // Playhead handle (triangle)
                VStack(spacing: 0) {
                    PlayheadTriangle()
                        .fill(Color.white)
                        .frame(width: 10, height: 6)
                        .offset(x: playheadX - 5)
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let ratio = max(0, min(1, value.location.x / width))
                        dragTime = ratio * viewModel.totalDuration
                    }
                    .onEnded { value in
                        let ratio = max(0, min(1, value.location.x / width))
                        viewModel.seekTo(time: ratio * viewModel.totalDuration)
                        isDragging = false
                    }
            )
        }
        .frame(height: 40)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Color Helper

    private func colorForShotType(_ shotType: String) -> Color {
        let hex = TimelineDefaultColors.colorForShotType(shotType)
        return colorFromHex(hex)
    }
}

// MARK: - Playhead Triangle Shape

struct PlayheadTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Hex Color Helper

private func colorFromHex(_ hex: String) -> Color {
    var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexStr = hexStr.replacingOccurrences(of: "#", with: "")
    guard hexStr.count == 6 else { return .blue }
    var rgb: UInt64 = 0
    Scanner(string: hexStr).scanHexInt64(&rgb)
    return Color(
        red: Double((rgb >> 16) & 0xFF) / 255.0,
        green: Double((rgb >> 8) & 0xFF) / 255.0,
        blue: Double(rgb & 0xFF) / 255.0
    )
}
