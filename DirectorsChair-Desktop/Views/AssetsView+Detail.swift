//
// AssetsView+Detail.swift
//
// Extracted from AssetsView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVFoundation


// MARK: - Detail Sheet

struct AssetDetailSheet: View {
    let asset: DiscoveredAsset
    @State private var thumbnail: NSImage? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: asset.category.icon)
                    .foregroundColor(asset.category.accentColor)
                Text(asset.fileName)
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    previewArea
                        .frame(maxHeight: 300)

                    // File info
                    fileInfoSection

                    // Actions
                    actionsSection
                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 560)
        .task {
            if asset.mediaType == .image {
                thumbnail = await AssetThumbnailCache.generateThumbnail(for: asset.fullURL, maxSize: 400)
            }
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        switch asset.mediaType {
        case .image:
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
            } else {
                ProgressView()
                    .frame(height: 200)
            }
        case .audio:
            VStack(spacing: 16) {
                Image(systemName: isPlayingAudio ? "speaker.wave.3.fill" : "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(asset.category.accentColor)
                    .symbolEffect(.variableColor.iterative, isActive: isPlayingAudio)

                Text(asset.fileExtension.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)

                Button(action: { toggleDetailAudioPlayback() }) {
                    HStack(spacing: 6) {
                        Image(systemName: isPlayingAudio ? "stop.fill" : "play.fill")
                        Text(isPlayingAudio ? "Stop" : "Play")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(isPlayingAudio ? .red : asset.category.accentColor)
            }
            .frame(height: 180)
        case .video:
            VStack(spacing: 12) {
                ZStack {
                    Image(systemName: "film")
                        .font(.system(size: 64))
                        .foregroundColor(asset.category.accentColor)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .offset(x: 28, y: 20)
                }
                Text(asset.fileExtension.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(height: 150)
        }
    }

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FILE INFO")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1.2)

            infoRow(label: "Name", value: asset.fileName)
            infoRow(label: "Type", value: asset.mediaType.rawValue)
            infoRow(label: "Category", value: asset.category.rawValue)
            infoRow(label: "Extension", value: asset.fileExtension.uppercased())
            infoRow(label: "Size", value: asset.formattedSize)
            infoRow(label: "Path", value: asset.relativePath)
            if let date = asset.modificationDate {
                infoRow(label: "Modified", value: date.formatted(date: .abbreviated, time: .shortened))
            }
            if !asset.contextLabel.isEmpty {
                infoRow(label: "Context", value: asset.contextLabel)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 12))
                .textSelection(.enabled)
            Spacer()
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button(action: saveToDownloads) {
                    Label("Save to Downloads", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)

                Button(action: saveAs) {
                    Label("Save As...", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: revealInFinder) {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button(action: openWithDefault) {
                    Label("Open", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)

                Button(action: copyPath) {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    private func saveToDownloads() {
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
        let destURL = uniqueDestination(for: asset.fileName, in: downloadsURL)
        do {
            try FileManager.default.copyItem(at: asset.fullURL, to: destURL)
            NSWorkspace.shared.activateFileViewerSelecting([destURL])
        } catch {
            debugLog("Failed to save asset to Downloads: \(error)")
        }
    }

    private func saveAs() {
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

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([asset.fullURL])
    }

    private func openWithDefault() {
        NSWorkspace.shared.open(asset.fullURL)
    }

    private func copyPath() {
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

    private func toggleDetailAudioPlayback() {
        if isPlayingAudio {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlayingAudio = false
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: asset.fullURL)
                audioPlayer?.delegate = AssetAudioDelegate.shared
                AssetAudioDelegate.shared.onFinished = {
                    self.isPlayingAudio = false
                }
                audioPlayer?.play()
                isPlayingAudio = true
            } catch {
                print("Error playing audio asset: \(error)")
            }
        }
    }
}

// MARK: - Asset Audio Delegate

class AssetAudioDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AssetAudioDelegate()
    var onFinished: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.onFinished?()
        }
    }
}

// MARK: - Preview

#Preview {
    AssetsView()
        .environmentObject(ProjectViewModel())
}
