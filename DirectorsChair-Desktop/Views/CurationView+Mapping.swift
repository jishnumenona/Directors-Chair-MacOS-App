//
// CurationView+Mapping.swift
//
// Extracted from CurationView.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension; private -> internal.
//

import SwiftUI
import AVKit
import DirectorsChairCore
import DirectorsChairViews

extension CurationView {

    // MARK: - Tab Bar

    var curationTabBar: some View {
        HStack(spacing: 0) {
            ForEach(CurationTab.allCases, id: \.self) { tab in
                Button { selectedTab = tab } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                        Text(tab.displayName)
                    }
                    .font(.subheadline)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    if selectedTab == tab {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                    }
                }
            }
            Spacer()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Curation Tab Content

    var curationTabContent: some View {
        HStack(spacing: 0) {
            navigatorPanel
                .frame(width: 300)

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.3))
                .frame(width: 1)

            detailPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Mapping Tab Content

    var mappingTabContent: some View {
        VStack(spacing: 0) {
            mediaSourcesPanel
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.2))
                .frame(height: 1)

            // Mapping detail — show all takes with their match status
            mappingDetailView
                .frame(maxHeight: .infinity)
        }
    }

    var mappingDetailView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Column headers
                HStack(spacing: 0) {
                    Text("STATUS")
                        .frame(width: 70, alignment: .leading)
                    Text("TAKE")
                        .frame(width: 110, alignment: .leading)
                    Text("CLIP NAME")
                        .frame(width: 90, alignment: .leading)
                    Text("TIMESTAMP")
                        .frame(width: 130, alignment: .leading)
                    Text("VIDEO")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("AUDIO")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("")
                        .frame(width: 24)
                    Text("SYNC")
                        .frame(width: 36, alignment: .center)
                    Text("ACTIONS")
                        .frame(width: 70, alignment: .center)
                }
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundColor(.gray.opacity(0.4))
                .padding(.horizontal, 32).padding(.vertical, 6)
                .background(Color(hex: "#1E1E1E"))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                }

                let allScenes = project.sequences.flatMap { $0.scenes }
                ForEach(allScenes, id: \.name) { scene in
                    let shotsWithTakes = scene.shots.filter { !$0.takes.isEmpty }
                    if !shotsWithTakes.isEmpty {
                        // Scene header
                        HStack(spacing: 8) {
                            Image(systemName: "film.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.accentColor.opacity(0.5))
                            Text(scene.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            // Per-scene mapping stats
                            let sceneTakes = shotsWithTakes.flatMap { $0.takes }
                            let videoMapped = sceneTakes.filter { $0.cameraSourceFileName != nil }.count
                            let audioMapped = sceneTakes.filter { $0.externalAudioFileName != nil || $0.useAudioFromVideo }.count
                            let sceneReady = videoMapped == sceneTakes.count && audioMapped == sceneTakes.count && !sceneTakes.isEmpty
                            HStack(spacing: 8) {
                                if sceneReady {
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark.seal.fill").font(.system(size: 8))
                                        Text("Ready")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .foregroundColor(.green)
                                } else {
                                    mappingStatusPill(mapped: videoMapped, total: sceneTakes.count, icon: "video.fill", color: .accentColor)
                                    mappingStatusPill(mapped: audioMapped, total: sceneTakes.count, icon: "waveform", color: .blue)
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(hex: "#1E1E1E"))

                        ForEach(shotsWithTakes) { shot in
                            // Shot subheader with shot-level status
                            let shotTakes = viewModel.sortedTakes(shot.takes)
                            let shotVideoMapped = shotTakes.filter { $0.cameraSourceFileName != nil }.count
                            let shotAudioMapped = shotTakes.filter { $0.externalAudioFileName != nil || $0.useAudioFromVideo }.count
                            let shotReady = shotVideoMapped == shotTakes.count && shotAudioMapped == shotTakes.count && !shotTakes.isEmpty
                            HStack(spacing: 6) {
                                // Shot ready indicator
                                Image(systemName: shotReady ? "checkmark.circle.fill" : "circle.dotted")
                                    .font(.system(size: 9))
                                    .foregroundColor(shotReady ? .green : .gray.opacity(0.3))

                                Image(systemName: "camera.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray.opacity(0.4))
                                Text("Shot #\(shot.shotId)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                if !shot.description.isEmpty {
                                    Text("— \(shot.description)")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray.opacity(0.3))
                                        .lineLimit(1)
                                }

                                Spacer()

                                if shotReady {
                                    Text("Ready")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.1)))
                                } else {
                                    mappingStatusPill(mapped: shotVideoMapped, total: shotTakes.count, icon: "video.fill", color: .accentColor)
                                    mappingStatusPill(mapped: shotAudioMapped, total: shotTakes.count, icon: "waveform", color: .blue)
                                }
                            }
                            .padding(.horizontal, 24).padding(.vertical, 5)
                            .background(Color(hex: "#1C1C1C"))

                            ForEach(shotTakes) { take in
                                mappingTakeRow(take: take, shot: shot, scene: scene)
                            }
                        }
                    }
                }

                if allScenes.flatMap({ $0.shots }).flatMap({ $0.takes }).isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.12))
                        Text("No takes to map")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Record takes from the Shot List view first")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.2))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
        }
        .background(Color(hex: "#1A1A1A"))
    }

    func mappingStatusPill(mapped: Int, total: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 7))
            Text("\(mapped)/\(total)")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(mapped == total && mapped > 0 ? color : .gray.opacity(0.3))
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(
            mapped == total && mapped > 0 ? color.opacity(0.1) : Color.white.opacity(0.03)
        ))
    }

    func takeReadyStatus(_ take: Take) -> (label: String, color: Color, icon: String) {
        let hasVideo = take.cameraSourceFileName != nil
        let hasAudio = take.externalAudioFileName != nil || take.useAudioFromVideo
        if hasVideo && hasAudio {
            return ("Ready", .green, "checkmark.circle.fill")
        } else if hasVideo || hasAudio {
            return ("Partial", .yellow, "exclamationmark.circle.fill")
        } else {
            return ("Pending", .gray.opacity(0.4), "circle.dotted")
        }
    }

    func mappingTakeRow(take: Take, shot: Shot, scene: DCScene) -> some View {
        let status = takeReadyStatus(take)
        return HStack(spacing: 0) {
            // Status
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.system(size: 9))
                Text(status.label)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(status.color)
            .frame(width: 70, alignment: .leading)

            // Take info
            HStack(spacing: 6) {
                Circle()
                    .fill(ratingColor(take.rating))
                    .frame(width: 6, height: 6)
                Text("T\(take.takeNumber)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                Text(take.rating.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ratingColor(take.rating).opacity(0.7))
            }
            .frame(width: 110, alignment: .leading)

            // Camera clip name (OCR-extracted)
            if let clipName = take.cameraClipName {
                Text(clipName)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange.opacity(0.8))
                    .frame(width: 90, alignment: .leading)
            } else {
                Text("—")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.2))
                    .frame(width: 90, alignment: .leading)
            }

            // Timestamp
            if let ts = take.startTimestamp {
                Text(Take.formatForCameraMatch(ts))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.accentColor.opacity(0.5))
                    .frame(width: 130, alignment: .leading)
            } else {
                Text("—")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.2))
                    .frame(width: 130, alignment: .leading)
            }

            // Video status
            HStack(spacing: 3) {
                if let name = take.cameraSourceFileName {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                    Text(name)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(0.85))
                        .lineLimit(1)

                    // Copy path
                    if let url = viewModel.cameraFileURL(for: name) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.path, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Copy path")

                        // Reveal in Finder
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                } else {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.4))
                    Text("Not mapped")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Audio status
            HStack(spacing: 3) {
                if take.useAudioFromVideo {
                    Image(systemName: "video.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.purple)
                    Text("From video")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.purple.opacity(0.85))
                } else if let name = take.externalAudioFileName {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    Text(name)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue.opacity(0.85))
                        .lineLimit(1)

                    // Copy path
                    if let url = viewModel.audioFileURL(for: name) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.path, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Copy path")

                        // Reveal in Finder
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                } else {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.4))
                    Text("Not mapped")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Audio from video toggle
            Menu {
                if take.useAudioFromVideo {
                    Button {
                        updateTake(take, in: shot) { $0.useAudioFromVideo = false }
                    } label: {
                        Label("Use External Audio", systemImage: "waveform")
                    }
                } else {
                    Button {
                        updateTake(take, in: shot) {
                            $0.useAudioFromVideo = true
                            $0.externalAudioFileName = nil
                        }
                    } label: {
                        Label("Use Audio from Video", systemImage: "video.fill")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(width: 24, height: 20)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Sync status
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 8))
                .foregroundColor({
                    if take.isAudioVideoSynced == true { return Color.green }
                    if take.isAudioVideoSynced == false { return Color.red }
                    if take.useAudioFromVideo { return Color.green }
                    if take.cameraSourceFileName != nil && take.externalAudioFileName != nil { return Color.yellow }
                    return Color.gray.opacity(0.15)
                }())
                .frame(width: 36, alignment: .center)

            // Per-row actions: map / remap / clear
            HStack(spacing: 4) {
                let hasVideo = take.cameraSourceFileName != nil
                let hasAudio = take.externalAudioFileName != nil || take.useAudioFromVideo

                // Map / Remap button
                Button {
                    // Try video match
                    if let videoMatch = viewModel.matchSingleTake(take) {
                        updateTake(take, in: shot) { $0.cameraSourceFileName = videoMatch }
                    }
                    // Try audio match (only if not using audio from video)
                    if !take.useAudioFromVideo {
                        if let audioMatch = viewModel.matchSingleTakeAudio(take) {
                            updateTake(take, in: shot) { $0.externalAudioFileName = audioMatch }
                        }
                    }
                } label: {
                    Image(systemName: hasVideo || hasAudio ? "arrow.triangle.2.circlepath" : "link")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.accentColor.opacity(0.7))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.plain)
                .help(hasVideo || hasAudio ? "Remap this take" : "Map this take")

                // Clear mapping
                if hasVideo || (take.externalAudioFileName != nil) {
                    Button {
                        updateTake(take, in: shot) {
                            $0.cameraSourceFileName = nil
                            $0.externalAudioFileName = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.4))
                            .frame(width: 22, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all mappings for this take")
                }
            }
            .frame(width: 70, alignment: .center)
        }
        .padding(.horizontal, 32).padding(.vertical, 5)
        .background(Color(hex: "#1A1A1A"))
    }
}
