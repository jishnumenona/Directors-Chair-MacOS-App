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
    var onSelect: (() -> Void)?
    var onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail area (placeholder)
            ZStack {
                Rectangle()
                    .fill(Color(hex: "#2A2A2A"))
                    .aspectRatio(16/9, contentMode: .fit)

                VStack {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(shot.shotType)
                        .font(.caption)
                        .foregroundColor(.gray)
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
