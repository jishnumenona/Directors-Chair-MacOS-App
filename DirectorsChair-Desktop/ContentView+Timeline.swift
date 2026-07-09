//
// ContentView+Timeline.swift
//
// Extracted from ContentView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were already internal helper views.
//

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairProduction
import DirectorsChairServices


// MARK: - Timeline Divider (Resizable)

struct TimelineDivider: View {
    @Binding var timelineHeightRatio: CGFloat
    let totalHeight: CGFloat

    @State private var isDragging = false
    @State private var previousRatio: CGFloat? = nil

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isDragging ? Color.accentColor : Color.gray.opacity(0.5))
                    .frame(width: 40, height: 4)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        // Clear saved ratio when user manually drags
                        previousRatio = nil
                        // Calculate new ratio based on drag
                        let dragOffset = value.translation.height
                        let newTimelineHeight = (totalHeight * timelineHeightRatio) - dragOffset
                        let newRatio = newTimelineHeight / totalHeight

                        // Clamp between 10% and 60%
                        timelineHeightRatio = min(0.60, max(0.10, newRatio))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .help("Drag to resize timeline panel")
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if abs(timelineHeightRatio - 0.50) < 0.01, let saved = previousRatio {
                        // Already at 50% — restore previous size
                        timelineHeightRatio = saved
                        previousRatio = nil
                    } else {
                        // Save current and snap to 50%
                        previousRatio = timelineHeightRatio
                        timelineHeightRatio = 0.50
                    }
                }
            }
    }
}

// MARK: - Timeline Container

struct TimelineContainer: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    /// Track sequence count to detect actual changes (not just any array mutation)
    @State private var lastSequenceCount: Int = 0

    /// Perf (audit A3, measured 65% of publish-tick main-thread time in the
    /// timeline canvases): fingerprint of everything the timeline renders.
    /// Project publishes that don't change this skip the setProject/refresh
    /// cycle entirely — no view-model churn, no full canvas repaint.
    @State private var lastTimelineFingerprint: Int?

    /// Audio player for timeline TTS playback
    @State private var timelineAudioPlayer: AVAudioPlayer?

    /// Whether the soundtrack file importer is showing
    @State private var showSoundtrackImporter: Bool = false

    /// Project base path as URL for image loading (matches CinematographyView resolution)
    private var projectBaseURL: URL? {
        projectViewModel.projectPath?.deletingLastPathComponent()
    }

    var body: some View {
        TimelineView(
            viewModel: timelineViewModel,
            projectBasePath: projectBaseURL,
            onSegmentClicked: { segment in
                // Handle segment click - navigate to the appropriate scene
                if !segment.sceneName.isEmpty {
                    // Find scene by name and select it
                    if let scene = projectViewModel.allScenes.first(where: { $0.name == segment.sceneName }) {
                        coordinator.selectScene(scene)
                        // Navigate to bubble view
                        coordinator.navigateTo(.bubble)
                    }
                }
            },
            onSegmentDoubleClicked: { segment in
                // Handle double-click - highlight the corresponding bubble
                let itemType: String
                switch segment.contentType {
                case .dialogue:
                    itemType = "dialogue"
                case .action:
                    itemType = "action"
                case .narration:
                    itemType = "narration"
                case .note:
                    itemType = "note"
                case .soundNote:
                    itemType = "soundNote"
                }

                // Use sourceItemId (the original dialogue/action/narration ID) for matching
                let itemId = segment.sourceItemId ?? segment.id.uuidString

                // Trigger highlight in bubble view
                coordinator.highlightBubbleItem(
                    id: itemId,
                    type: itemType,
                    sceneName: segment.sceneName
                )

                // Navigate to bubble view if not already there
                if coordinator.selectedView != .bubble {
                    coordinator.navigateTo(.bubble)
                }
            },
            onOptionClickSegment: { segment in
                // Option+Click: jump to script element
                if let sourceItemId = segment.sourceItemId {
                    let itemType: String
                    switch segment.contentType {
                    case .dialogue: itemType = "dialogue"
                    case .action: itemType = "action"
                    case .narration: itemType = "narration"
                    case .note: itemType = "note"
                    case .soundNote: itemType = "soundNote"
                    }
                    coordinator.jumpToScriptElement(itemId: sourceItemId, itemType: itemType)
                }
            },
            onOptionClickShotLabel: { shotId, sceneName in
                // Option+Click on shot label: resolve the full Shot and jump to script
                if let scene = projectViewModel.allScenes.first(where: { $0.name == sceneName }),
                   let shot = scene.shots.first(where: { $0.shotId == shotId }) {
                    coordinator.jumpToScriptForShot(shot, scene: scene)
                }
            },
            onShotLabelDoubleClicked: { shotId, sceneName in
                // Find the shot by shotId and sceneName to ensure correct match
                if let scene = projectViewModel.allScenes.first(where: { $0.name == sceneName }),
                   let shot = scene.shots.first(where: { $0.shotId == shotId }) {
                    coordinator.selectScene(scene)
                    coordinator.selectShot(shot)
                    coordinator.navigateTo(.shotList)
                }
            },
            onSceneMarkerDoubleClicked: { sceneName in
                // Double-click scene marker → open scene in Scenes view
                if let scene = projectViewModel.allScenes.first(where: { $0.name == sceneName }) {
                    coordinator.selectScene(scene)
                    coordinator.navigateTo(.scenes)
                }
            },
            onLightCueDoubleClicked: { cueId in
                // Double-click light cue → open in Lighting Cue Editor
                coordinator.selectedLightCueId = cueId
                coordinator.preferredStoryDesignMode = "lighting"
                coordinator.navigateTo(.storyDesign)
            },
            onSFXCueDoubleClicked: { cueId in
                // Double-click SFX cue → open in SFX Editor
                coordinator.selectedSFXCueId = cueId
                coordinator.preferredStoryDesignMode = "lighting"
                coordinator.navigateTo(.storyDesign)
            },
            onSupportCueDoubleClicked: { cueId in
                // Double-click support cue → open in choreography editor
                coordinator.selectedSupportCueId = cueId
                coordinator.preferredStoryDesignMode = "lighting"
                coordinator.navigateTo(.storyDesign)
            },
            onShotLabelMoved: { _, _, _ in
                // Sync updated project and save silently (no loading overlay)
                if let updatedProject = timelineViewModel.getProject() {
                    projectViewModel.project = updatedProject
                    Task { await projectViewModel.saveSilently() }
                }
            },
            onSegmentMoved: { _, _ in
                // Sync updated project and save silently (no loading overlay)
                if let updatedProject = timelineViewModel.getProject() {
                    projectViewModel.project = updatedProject
                    Task { await projectViewModel.saveSilently() }
                }
            },
            onSegmentsMoved: { _ in
                // Sync updated project and save silently (no loading overlay)
                if let updatedProject = timelineViewModel.getProject() {
                    projectViewModel.project = updatedProject
                    Task { await projectViewModel.saveSilently() }
                }
            },
            onAnalyzeTimeline: {
                coordinator.requestTimelineAnalysis(scope: .all)
            },
            onGenerateAudio: { segment in
                guard segment.contentType == .dialogue,
                      let sourceId = segment.sourceItemId else { return }

                timelineViewModel.generatingAudioSourceIds.insert(sourceId)

                Task {
                    do {
                        let dialogue = timelineViewModel.findDialogue(sourceItemId: sourceId)
                        let character = timelineViewModel.findCharacter(name: segment.character)
                        let voiceName = character?.voice ?? (character?.gender.lowercased() == "female" ? "Kore" : "Charon")

                        var emotionParts: [String] = []
                        if let style = character?.voiceStyle, !style.isEmpty {
                            emotionParts.append(style)
                        }
                        if let tags = dialogue?.tags, !tags.isEmpty {
                            emotionParts.append(contentsOf: tags)
                        }
                        let emotion = emotionParts.isEmpty ? nil : "Say \(emotionParts.joined(separator: ", "))"

                        // Strip HTML from text
                        var text = dialogue?.text ?? segment.text
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("<") {
                            let tagPattern = "<[^>]+>"
                            if let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) {
                                let range = NSRange(location: 0, length: text.utf16.count)
                                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }

                        let request = SpeechGenerationRequest(
                            text: text,
                            provider: .google,
                            voiceName: voiceName,
                            emotion: emotion,
                            characterName: segment.character,
                            voiceTone: character?.voiceTone,
                            voicePersonality: character?.voicePersonality,
                            voicePace: character?.voicePace,
                            voiceAccent: character?.voiceAccent,
                            voiceAge: character?.voiceAge
                        )

                        let response = try await AIServiceClient.shared.generateSpeech(request)

                        // Save audio file
                        if let projectPath = projectViewModel.projectPath {
                            let projectDir = projectPath.deletingLastPathComponent()
                            let audioDir = projectDir.appendingPathComponent("assets/audio/dialogues")
                            try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

                            let fileName = "\(sourceId).wav"
                            let filePath = audioDir.appendingPathComponent(fileName)
                            try response.audioData.write(to: filePath)

                            let relativePath = "assets/audio/dialogues/\(fileName)"
                            timelineViewModel.updateDialogueAudioPath(sourceItemId: sourceId, audioFilePath: relativePath)

                            // Sync project back
                            if let updatedProject = timelineViewModel.getProject() {
                                projectViewModel.project = updatedProject
                                Task { await projectViewModel.saveSilently() }
                            }

                            // Refresh timeline to update hasAudio
                            timelineViewModel.setProject(projectViewModel.project)
                        }

                        // Play the generated audio
                        timelineAudioPlayer?.stop()
                        timelineAudioPlayer = try AVAudioPlayer(data: response.audioData)
                        timelineViewModel.playingAudioSourceId = sourceId
                        timelineAudioPlayer?.play()

                        // Monitor playback completion
                        Task {
                            while timelineAudioPlayer?.isPlaying == true {
                                try? await Task.sleep(nanoseconds: 200_000_000)
                            }
                            if timelineViewModel.playingAudioSourceId == sourceId {
                                timelineViewModel.playingAudioSourceId = nil
                            }
                        }

                    } catch {
                        debugLog("Timeline TTS generation error: \(error)")
                    }

                    timelineViewModel.generatingAudioSourceIds.remove(sourceId)
                }
            },
            onPlayAudio: { segment in
                guard let sourceId = segment.sourceItemId,
                      let dialogue = timelineViewModel.findDialogue(sourceItemId: sourceId),
                      let audioPath = dialogue.audioFilePath,
                      let projectPath = projectViewModel.projectPath else { return }

                let projectDir = projectPath.deletingLastPathComponent()
                let fileURL = projectDir.appendingPathComponent(audioPath)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

                do {
                    timelineAudioPlayer?.stop()
                    timelineAudioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                    timelineViewModel.playingAudioSourceId = sourceId
                    timelineAudioPlayer?.play()

                    // Monitor playback completion
                    Task {
                        while timelineAudioPlayer?.isPlaying == true {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                        }
                        if timelineViewModel.playingAudioSourceId == sourceId {
                            timelineViewModel.playingAudioSourceId = nil
                        }
                    }
                } catch {
                    debugLog("Timeline audio playback error: \(error)")
                }
            },
            onStopAudio: {
                timelineAudioPlayer?.stop()
                timelineAudioPlayer = nil
                timelineViewModel.playingAudioSourceId = nil
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            // Set project and show global timeline view
            timelineViewModel.projectFilePath = projectViewModel.projectPath
            timelineViewModel.setProject(projectViewModel.project)
            timelineViewModel.showGlobal()
            lastSequenceCount = projectViewModel.project.sequences.count

            // Load existing soundtracks from project
            timelineViewModel.soundtrackTracks = projectViewModel.project.soundtracks

            // Load existing light cues from project
            timelineViewModel.lightCues = projectViewModel.project.lightCues

            // Load existing SFX cues from project
            timelineViewModel.sfxCues = projectViewModel.project.sfxCues

            // Load existing support cues from project
            timelineViewModel.supportCues = projectViewModel.project.supportCues

            // Wire soundtrack import callback
            timelineViewModel.onImportSoundtrack = {
                showSoundtrackImporter = true
            }

            // Wire soundtrack changed callback to persist
            timelineViewModel.onSoundtracksChanged = { tracks in
                projectViewModel.project.soundtracks = tracks
                Task { await projectViewModel.saveSilently() }
            }

            // Wire light cues changed callback to persist
            timelineViewModel.onLightCuesChanged = { cues in
                projectViewModel.project.lightCues = cues
                Task { await projectViewModel.saveSilently() }
            }

            // Wire SFX cues changed callback to persist
            timelineViewModel.onSFXCuesChanged = { cues in
                projectViewModel.project.sfxCues = cues
                Task { await projectViewModel.saveSilently() }
            }

            // Wire support cues changed callback to persist
            timelineViewModel.onSupportCuesChanged = { cues in
                projectViewModel.project.supportCues = cues
                Task { await projectViewModel.saveSilently() }
            }
        }
        .fileImporter(
            isPresented: $showSoundtrackImporter,
            allowedContentTypes: [.audio, .mp3, .wav, .aiff],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importSoundtrackFile(url: url)
            case .failure(let error):
                debugLog("Soundtrack import error: \(error)")
            }
        }
        // Refresh when project finishes loading (catches async restoreLastProject)
        .onChange(of: projectViewModel.hasProject) { _, hasProject in
            if hasProject {
                timelineViewModel.projectFilePath = projectViewModel.projectPath
                timelineViewModel.setProject(projectViewModel.project)
                timelineViewModel.showGlobal()
                lastSequenceCount = projectViewModel.project.sequences.count
                timelineViewModel.soundtrackTracks = projectViewModel.project.soundtracks
                timelineViewModel.lightCues = projectViewModel.project.lightCues
                timelineViewModel.sfxCues = projectViewModel.project.sfxCues
                timelineViewModel.supportCues = projectViewModel.project.supportCues

                // Auto-open AI chat on first launch after project loads
                if !UserDefaults.standard.bool(forKey: "hasShownAIChatWelcome") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if !coordinator.showingAIChat {
                            coordinator.showingAIChat = true
                        }
                    }
                }
            }
        }
        // Only refresh when sequence COUNT changes, not on every array comparison
        .onChange(of: projectViewModel.project.sequences.count) { _, newCount in
            if newCount != lastSequenceCount {
                lastSequenceCount = newCount
                timelineViewModel.setProject(projectViewModel.project)
                timelineViewModel.refresh()
            }
        }
        // Keep timeline cue lanes in sync when editor changes project cues
        .onChange(of: projectViewModel.project.lightCues) { _, newCues in
            if timelineViewModel.lightCues != newCues {
                timelineViewModel.lightCues = newCues
                timelineViewModel.extendDurationIfNeeded()
                Task { await projectViewModel.saveSilently() }
            }
        }
        .onChange(of: projectViewModel.project.sfxCues) { _, newCues in
            if timelineViewModel.sfxCues != newCues {
                timelineViewModel.sfxCues = newCues
                timelineViewModel.extendDurationIfNeeded()
                Task { await projectViewModel.saveSilently() }
            }
        }
        .onChange(of: projectViewModel.project.supportCues) { _, newCues in
            if timelineViewModel.supportCues != newCues {
                timelineViewModel.supportCues = newCues
                timelineViewModel.extendDurationIfNeeded()
                Task { await projectViewModel.saveSilently() }
            }
        }
        // Subscribe to project changed events (e.g., when bubbles are reordered)
        .onReceive(coordinator.projectEvents) { event in
            // Timeline renders script + shots + structure; schedule/budget
            // edits don't require a rebuild.
            guard event != .production else { return }
            // Skip when nothing the timeline renders actually changed —
            // rebuilding published VM state invalidates the Canvas display
            // lists and forces a full repaint of every segment.
            var hasher = Hasher()
            hasher.combine(projectViewModel.project.sequences)
            hasher.combine(projectViewModel.project.lightCues)
            hasher.combine(projectViewModel.project.sfxCues)
            hasher.combine(projectViewModel.project.supportCues)
            hasher.combine(projectViewModel.project.characters)
            let fingerprint = hasher.finalize()
            guard fingerprint != lastTimelineFingerprint else { return }
            lastTimelineFingerprint = fingerprint

            debugLog("🎬 TimelineContainer: projectChanged received, refreshing timeline")
            PerfCounters.shared.increment("event.TimelineContainer.refresh")
            timelineViewModel.setProject(projectViewModel.project)
            timelineViewModel.refresh()
        }
    }

    // MARK: - Soundtrack Import

    private func importSoundtrackFile(url: URL) {
        guard let projectPath = projectViewModel.projectPath else { return }
        let projectDir = projectPath.deletingLastPathComponent()

        // Start security-scoped access
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        Task {
            do {
                // Extract waveform data
                let waveformData = try WaveformExtractor.extract(from: url)

                // Create soundtrack directory
                let soundtrackDir = projectDir.appendingPathComponent("assets/audio/soundtracks")
                try FileManager.default.createDirectory(at: soundtrackDir, withIntermediateDirectories: true)

                // Copy audio file
                let trackId = UUID().uuidString
                let ext = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
                let destFileName = "\(trackId).\(ext)"
                let destURL = soundtrackDir.appendingPathComponent(destFileName)
                try FileManager.default.copyItem(at: url, to: destURL)

                let relativePath = "assets/audio/soundtracks/\(destFileName)"

                // Assign a color based on existing track count
                let colors = ["#00BCD4", "#E91E63", "#4CAF50", "#FF9800", "#9C27B0", "#03A9F4"]
                let colorIndex = timelineViewModel.soundtrackTracks.count % colors.count

                // Create track model
                let track = SoundtrackTrack(
                    id: trackId,
                    name: url.deletingPathExtension().lastPathComponent,
                    audioFilePath: relativePath,
                    startTimeOffset: 0,
                    duration: waveformData.duration,
                    volume: 1.0,
                    color: colors[colorIndex],
                    isMuted: false,
                    waveformSamples: waveformData.samples,
                    sortOrder: timelineViewModel.soundtrackTracks.count
                )

                await MainActor.run {
                    timelineViewModel.addSoundtrack(track)
                }
            } catch {
                debugLog("Failed to import soundtrack: \(error)")
            }
        }
    }
}

// MARK: - Production Container

/// Combines Schedule, Cast & Crew, and Budget into a single tabbed view
