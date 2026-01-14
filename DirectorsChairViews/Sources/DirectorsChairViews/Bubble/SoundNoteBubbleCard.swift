// DirectorsChairViews/Sources/DirectorsChairViews/Bubble/SoundNoteBubbleCard.swift
//
// Sound note bubble card for displaying audio/music/SFX notes

import SwiftUI
import DirectorsChairCore

/// Sound note bubble card - displays audio/music/SFX notes
///
/// Shows:
/// - Sound type icon
/// - Description
/// - Volume indicator
/// - Loop/fade settings
/// - Audio file info
/// - Reference URL (if any)
public struct SoundNoteBubbleCard: View {
    let soundNote: SoundNote
    let isSelected: Bool

    var onTap: (() -> Void)?
    var onEdit: (() -> Void)?
    var onPlay: (() -> Void)?
    var onDelete: (() -> Void)?

    public init(
        soundNote: SoundNote,
        isSelected: Bool = false,
        onTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onPlay: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.soundNote = soundNote
        self.isSelected = isSelected
        self.onTap = onTap
        self.onEdit = onEdit
        self.onPlay = onPlay
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("#\(soundNote.chronologyNumber)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)

                soundTypeIcon

                Text(soundNote.soundType.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)

                Spacer()

                // Play button (if audio file exists)
                if let audioPath = soundNote.audioFilePath, !audioPath.isEmpty {
                    Button(action: { onPlay?() }) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { onEdit?() }) {
                    Text("Edit")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Description
            Text(soundNote.description)
                .font(.body)
                .foregroundColor(.primary)

            // Audio settings row
            HStack(spacing: 12) {
                // Volume indicator
                HStack(spacing: 4) {
                    Image(systemName: volumeIcon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(soundNote.volume)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Loop indicator
                if soundNote.loop {
                    HStack(spacing: 2) {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Loop")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                // Fade indicators
                if soundNote.fadeInDuration > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(String(format: "%.1f", soundNote.fadeInDuration))s in")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                if soundNote.fadeOutDuration > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.right")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(String(format: "%.1f", soundNote.fadeOutDuration))s out")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            // Time range (if specified)
            if let start = soundNote.startTime, let end = soundNote.endTime {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(formatTime(start)) - \(formatTime(end))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Reference URL (if any)
            if let refUrl = soundNote.referenceUrl, !refUrl.isEmpty {
                HStack {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(refUrl)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }

            // Tags
            if !soundNote.tags.isEmpty {
                TagsStackView(tags: soundNote.tags)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cyan.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.cyan.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
            Button("Edit Sound Note") {
                onEdit?()
            }
            if soundNote.audioFilePath != nil {
                Button("Play Audio") {
                    onPlay?()
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        }
    }

    // MARK: - Sound Type Icon

    private var soundTypeIcon: some View {
        Image(systemName: soundIconName)
            .font(.caption)
            .foregroundColor(.cyan)
    }

    private var soundIconName: String {
        switch soundNote.soundType.lowercased() {
        case "music": return "music.note"
        case "sfx", "effect": return "waveform"
        case "ambience", "ambient": return "leaf.fill"
        case "dialogue": return "text.bubble"
        case "foley": return "shoe.fill"
        default: return "speaker.wave.2.fill"
        }
    }

    private var volumeIcon: String {
        switch soundNote.volume {
        case 0: return "speaker.slash.fill"
        case 1..<33: return "speaker.fill"
        case 33..<66: return "speaker.wave.1.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    VStack(spacing: 20) {
        SoundNoteBubbleCard(
            soundNote: SoundNote(
                description: "Dramatic orchestral hit",
                soundType: "music",
                chronologyNumber: 8,
                volume: 80,
                loop: false,
                fadeInDuration: 0.5,
                fadeOutDuration: 1.0,
                tags: ["dramatic", "impact"]
            ),
            isSelected: false
        )

        SoundNoteBubbleCard(
            soundNote: SoundNote(
                description: "Rain and thunder ambience",
                soundType: "ambience",
                chronologyNumber: 9,
                volume: 40,
                loop: true,
                fadeInDuration: 2.0,
                fadeOutDuration: 3.0,
                tags: ["weather", "mood"]
            ),
            isSelected: true
        )
    }
    .padding()
}
