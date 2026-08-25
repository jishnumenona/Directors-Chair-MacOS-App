//
// CinematographyView+Storyboard.swift
//
// Extracted from CinematographyView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were file-private helpers, now module-internal.
//

import SwiftUI
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Storyboard Card

struct StoryboardCard: View {
    let shot: Shot
    let isSelected: Bool
    /// The project FILE url (package convention — asset base is its parent).
    var projectBasePath: URL?
    /// Whether the on-device storyboard engine can draw right now (owned
    /// once by the grid, not polled per card).
    var engineReady: Bool = false
    var isGenerating: Bool = false
    var onSelect: (() -> Void)?
    var onEdit: (() -> Void)?
    var onGenerateStoryboard: (() -> Void)?

    @State private var thumbnail: NSImage?

    /// The sketch leads; the cloud previz is the fallback so the grid
    /// stays useful for projects made before DC-0064.
    private var thumbnailRelativePath: String? {
        shot.storyboardImage ?? shot.previewImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail: the shot's storyboard sketch when it has one.
            ZStack {
                Rectangle()
                    .fill(Color(hex: "#2A2A2A"))
                    .aspectRatio(16/9, contentMode: .fit)

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipped()
                } else {
                    VStack {
                        Image(systemName: "film")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text(shot.shotType)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                if isGenerating {
                    Rectangle().fill(Color.black.opacity(0.45))
                    ProgressView()
                        .controlSize(.small)
                }
            }

            // Info footer
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(shot.shotId)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if let videoPath = shot.videoPath, !videoPath.isEmpty {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green.opacity(0.8))
                    }

                    Spacer()

                    // On-device sketch: visible even when the model isn't
                    // downloaded — greyed with a pointer beats vanished
                    // (the AI Services pane rule).
                    Button {
                        onGenerateStoryboard?()
                    } label: {
                        Image(systemName: shot.storyboardImage == nil
                              ? "pencil.and.outline" : "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(engineReady ? .accentColor : .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(!engineReady || isGenerating)
                    .help(engineReady
                          ? (shot.storyboardImage == nil
                             ? "Draw a storyboard sketch on this Mac (free)"
                             : "Redraw the storyboard sketch")
                          : "Download the Storyboard model in Settings → AI Services to draw frames on this Mac")
                    .accessibilityIdentifier("storyboard-generate-\(shot.shotId)")

                    ShotStatusBadge(status: ShotStatus(rawValue: shot.status) ?? .planning)
                }

                Text(shot.description.isEmpty ? shot.cameraAngle : shot.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .padding(12)
            .background(Color(hex: "#252525"))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect?()
        }
        .onTapGesture(count: 2) {
            onEdit?()
        }
        .onAppear { loadThumbnail() }
        .onChange(of: shot.storyboardImage) { _ in loadThumbnail() }
        .onChange(of: shot.previewImage) { _ in loadThumbnail() }
    }

    private func loadThumbnail() {
        guard let relative = thumbnailRelativePath,
              let base = projectBasePath?.deletingLastPathComponent() else {
            thumbnail = nil
            return
        }
        thumbnail = NSImage(contentsOf: base.appendingPathComponent(relative))
    }
}

// MARK: - Preset Card

struct PresetCard: View {
    let preset: CameraPreset
    let isSelected: Bool
    var onSelect: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(preset.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }

            HStack(spacing: 16) {
                Label("\(preset.lensMm)mm", systemImage: "circle.dotted")
                Label(preset.aperture, systemImage: "camera.aperture")
            }
            .font(.caption)
            .foregroundColor(.gray)

            Text(preset.description)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(hex: "#2A2A2A"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            onSelect?()
        }
    }
}
