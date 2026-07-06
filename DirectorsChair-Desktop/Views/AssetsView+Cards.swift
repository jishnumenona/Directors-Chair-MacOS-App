//
// AssetsView+Cards.swift
//
// Extracted from AssetsView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVFoundation


// MARK: - Section View

struct AssetSectionView: View {
    let category: AssetCategory
    let assets: [DiscoveredAsset]
    let onSelect: (DiscoveredAsset) -> Void

    /// For characters/locations, group assets by entity name extracted from path
    private var groupedByEntity: [(String, [DiscoveredAsset])]? {
        guard category == .characters || category == .locations else { return nil }

        let folderKey = category == .characters ? "characters" : "locations"
        var groups: [String: [DiscoveredAsset]] = [:]
        var order: [String] = []

        for asset in assets {
            let parts = asset.relativePath.components(separatedBy: "/")
            let entityName: String
            if let idx = parts.firstIndex(of: folderKey), idx + 1 < parts.count {
                entityName = parts[idx + 1]
            } else {
                entityName = "Other"
            }

            if groups[entityName] == nil {
                order.append(entityName)
            }
            groups[entityName, default: []].append(asset)
        }

        let result = order.compactMap { name -> (String, [DiscoveredAsset])? in
            guard let items = groups[name], !items.isEmpty else { return nil }
            return (name, items)
        }
        return result.isEmpty ? nil : result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 13))
                    .foregroundColor(category.accentColor)

                Text(category.rawValue.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)

                Text("\(assets.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(category.accentColor.opacity(0.8)))
            }

            if let grouped = groupedByEntity {
                // Grouped view: sub-sections by entity name
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(grouped, id: \.0) { entityName, entityAssets in
                        VStack(alignment: .leading, spacing: 8) {
                            // Entity sub-header
                            HStack(spacing: 6) {
                                Image(systemName: category == .characters ? "person.fill" : "mappin.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(category.accentColor.opacity(0.7))

                                Text(entityName)
                                    .font(.system(size: 12, weight: .semibold))

                                Text("\(entityAssets.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(category.accentColor)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule().fill(category.accentColor.opacity(0.15))
                                    )
                            }

                            // Horizontal scroll of cards for this entity
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(entityAssets) { asset in
                                        AssetCardView(asset: asset)
                                            .onTapGesture { onSelect(asset) }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            } else {
                // Default flat horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(assets) { asset in
                            AssetCardView(asset: asset)
                                .onTapGesture { onSelect(asset) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Asset Card

struct AssetCardView: View {
    let asset: DiscoveredAsset
    @State private var isHovered = false
    @State private var thumbnail: NSImage? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false

    var body: some View {
        Group {
            switch asset.mediaType {
            case .image:
                imageCard
            case .audio:
                audioCard
            case .video:
                videoCard
            }
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.25 : 0.1), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .help(asset.relativePath)
        .contextMenu {
            if asset.mediaType == .audio {
                Button(action: { toggleAudioPlayback() }) {
                    Label(isPlayingAudio ? "Stop Playback" : "Play Audio", systemImage: isPlayingAudio ? "stop.fill" : "play.fill")
                }
                Divider()
            }
            Button(action: { saveToDownloads(asset: asset) }) {
                Label("Save to Downloads", systemImage: "arrow.down.circle")
            }
            Button(action: { saveAs(asset: asset) }) {
                Label("Save As...", systemImage: "square.and.arrow.down")
            }
            Divider()
            Button(action: { revealInFinder(asset: asset) }) {
                Label("Reveal in Finder", systemImage: "folder")
            }
            Button(action: { NSWorkspace.shared.open(asset.fullURL) }) {
                Label("Open with Default App", systemImage: "arrow.up.right.square")
            }
            Divider()
            Button(action: { copyPath(asset: asset) }) {
                Label("Copy File Path", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: Image Card

    private var imageCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail
            Group {
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 160, height: 140)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            // Label
            VStack(alignment: .leading, spacing: 2) {
                if !asset.contextLabel.isEmpty {
                    Text(asset.contextLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(asset.category.accentColor)
                        .textCase(.uppercase)
                }
                Text(asset.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(8)
        }
        .frame(width: 160, height: 140)
        .cornerRadius(10)
        .task {
            thumbnail = await AssetThumbnailCache.generateThumbnail(for: asset.fullURL)
        }
    }

    // MARK: Audio Card

    private var audioCard: some View {
        VStack(spacing: 0) {
            // Icon area with play button
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [asset.category.accentColor.opacity(0.3), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 70)
                .overlay(
                    ZStack {
                        VStack(spacing: 6) {
                            Image(systemName: isPlayingAudio ? "speaker.wave.3.fill" : "waveform")
                                .font(.system(size: 24))
                                .foregroundColor(asset.category.accentColor)
                                .symbolEffect(.variableColor.iterative, isActive: isPlayingAudio)
                            Text(asset.fileExtension.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        // Play/Stop button on hover
                        if isHovered {
                            Button(action: { toggleAudioPlayback() }) {
                                Image(systemName: isPlayingAudio ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                )

            // Info area
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                HStack {
                    Text(asset.formattedSize)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    if !asset.contextLabel.isEmpty {
                        Text(asset.contextLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(asset.category.accentColor)
                    }
                }
            }
            .padding(8)
        }
        .frame(width: 160, height: 120)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    private func toggleAudioPlayback() {
        if isPlayingAudio {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlayingAudio = false
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: asset.fullURL)
                audioPlayer?.delegate = AssetAudioDelegate.shared
                AssetAudioDelegate.shared.onFinished = { [weak audioPlayer] in
                    if audioPlayer != nil {
                        self.isPlayingAudio = false
                    }
                }
                audioPlayer?.play()
                isPlayingAudio = true
            } catch {
                debugLog("Error playing audio asset: \(error)")
            }
        }
    }

    // MARK: Video Card

    private var videoCard: some View {
        VStack(spacing: 0) {
            // Icon area with play badge
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [asset.category.accentColor.opacity(0.3), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 70)
                .overlay(
                    ZStack {
                        Image(systemName: "film")
                            .font(.system(size: 24))
                            .foregroundColor(asset.category.accentColor)

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .offset(x: 20, y: 14)
                    }
                )

            // Info area
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                HStack {
                    Text(asset.formattedSize)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    if !asset.contextLabel.isEmpty {
                        Text(asset.contextLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(asset.category.accentColor)
                    }
                }
            }
            .padding(8)
        }
        .frame(width: 160, height: 120)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Context Menu Actions

    private func saveToDownloads(asset: DiscoveredAsset) {
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
        let destURL = uniqueDestination(for: asset.fileName, in: downloadsURL)
        do {
            try FileManager.default.copyItem(at: asset.fullURL, to: destURL)
            NSWorkspace.shared.activateFileViewerSelecting([destURL])
        } catch {
            debugLog("Failed to save asset to Downloads: \(error)")
        }
    }

    private func saveAs(asset: DiscoveredAsset) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = asset.fileName
        panel.canCreateDirectories = true
        if let contentType = UTType(filenameExtension: asset.fileExtension) {
            panel.allowedContentTypes = [contentType]
        }
        panel.begin { response in
            guard response == .OK, let destURL = panel.url else { return }
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: asset.fullURL, to: destURL)
            } catch {
                debugLog("Failed to save asset: \(error)")
            }
        }
    }

    private func revealInFinder(asset: DiscoveredAsset) {
        NSWorkspace.shared.activateFileViewerSelecting([asset.fullURL])
    }

    private func copyPath(asset: DiscoveredAsset) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(asset.fullURL.path, forType: .string)
    }

    private func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var dest = directory.appendingPathComponent(fileName)
        var counter = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            let newName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            dest = directory.appendingPathComponent(newName)
            counter += 1
        }
        return dest
    }
}

// MARK: - Stats Components

struct AssetStatPill: View {
    let icon: String
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AssetStatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.4))
            .frame(width: 1, height: 28)
    }
}
