//
// CinematographyView+ShotList.swift
//
// Extracted from CinematographyView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were file-private helpers, now module-internal.
//

import SwiftUI
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Shot List Row

struct ShotListRow: View {
    let shot: Shot
    let isSelected: Bool
    var onEdit: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onDelete: (() -> Void)?
    var onStatusChange: ((ShotStatus) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Shot number
            Text("#\(shot.shotId)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 40)

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            // Shot info
            VStack(alignment: .leading, spacing: 2) {
                Text(shot.shotType)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(shot.description.isEmpty ? shot.cameraAngle : shot.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // Video indicator
            if let videoPath = shot.videoPath, !videoPath.isEmpty {
                Image(systemName: "video.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green.opacity(0.8))
                    .help("Has generated video")
            }

            // Duration
            if let duration = shot.duration {
                Text("\(String(format: "%.1f", duration))s")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
        .contextMenu {
            Button {
                onEdit?()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                onDuplicate?()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Divider()

            Menu("Set Status") {
                ForEach(ShotStatus.allCases) { status in
                    Button {
                        onStatusChange?(status)
                    } label: {
                        Label(status.rawValue, systemImage: status.systemImage)
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var statusColor: Color {
        (ShotStatus(rawValue: shot.status) ?? .planning).color
    }
}

// MARK: - Shot Status Badge

struct ShotStatusBadge: View {
    let status: ShotStatus
    var onStatusChange: ((ShotStatus) -> Void)? = nil

    @State private var showingPopover = false

    var body: some View {
        if onStatusChange != nil {
            Button {
                showingPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: status.systemImage)
                        .font(.caption2)
                    Text(status.rawValue)
                        .font(.caption)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(status.color.opacity(0.2))
                .foregroundColor(status.color)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(ShotStatus.allCases) { option in
                        Button {
                            onStatusChange?(option)
                            showingPopover = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: option.systemImage)
                                    .frame(width: 16)
                                    .foregroundColor(option.color)
                                Text(option.rawValue)
                                Spacer()
                                if option == status {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(option == status ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                    }
                }
                .padding(8)
                .frame(width: 180)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: status.systemImage)
                    .font(.caption2)
                Text(status.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(12)
        }
    }
}
