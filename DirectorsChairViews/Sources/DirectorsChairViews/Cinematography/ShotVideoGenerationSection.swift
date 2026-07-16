// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/ShotVideoGenerationSection.swift
//
// Video Generation Section for Shot Detail View
// Supports keyframe timeline, multi-provider video generation, inline playback

import SwiftUI
import AVKit
import AppKit
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices

// MARK: - Video Provider

enum VideoProvider: String, CaseIterable {
    case veo3 = "google_veo"
    case sora2 = "sora_2"
    case kling = "kling"

    var displayName: String {
        switch self {
        case .veo3: return "Veo 3"
        case .sora2: return "Sora 2"
        case .kling: return "Kling"
        }
    }

    var icon: String {
        switch self {
        case .veo3: return "play.rectangle.fill"
        case .sora2: return "film.fill"
        case .kling: return "video.fill"
        }
    }

    var minDuration: Double {
        switch self {
        case .veo3: return 5
        case .sora2: return 5
        case .kling: return 3
        }
    }

    var maxDuration: Double {
        switch self {
        case .veo3: return 10
        case .sora2: return 20
        case .kling: return 15
        }
    }

    var costPerSecond: Double {
        switch self {
        case .veo3: return 0.02
        case .sora2: return 0.02
        case .kling: return 0.01
        }
    }

    var folderName: String {
        switch self {
        case .veo3: return "veo3"
        case .sora2: return "sora2"
        case .kling: return "kling"
        }
    }

    var aiProvider: AIProvider {
        switch self {
        case .veo3: return .google
        case .sora2: return .openai
        case .kling: return .openai
        }
    }

    /// Aspect ratios the provider actually accepts (Veo rejects 1:1 with a 400).
    var supportedAspectRatios: [String] {
        switch self {
        case .veo3: return ["16:9", "9:16"]
        case .sora2, .kling: return ["16:9", "9:16", "1:1"]
        }
    }

    /// Output resolutions the gateway accepts for this provider.
    var supportedResolutions: [String] {
        ["720p", "1080p"]
    }

    /// Whether this provider supports start→end frame interpolation (bridging).
    var supportsEndFrameInterpolation: Bool {
        self == .veo3
    }

    /// Veo's end-frame interpolation ignores the requested duration and fixes
    /// the clip length itself (~8s), so cost estimation and usage tracking must
    /// use that length, not the slider value.
    static let interpolationDurationSeconds: Double = 8.0

    /// The duration the job will actually bill/run at.
    func effectiveDuration(requested: Double, bridgesEndFrame: Bool) -> Double {
        guard bridgesEndFrame && supportsEndFrameInterpolation else { return requested }
        return Self.interpolationDurationSeconds
    }

    static func fromFolderName(_ name: String) -> VideoProvider? {
        allCases.first { $0.folderName == name }
    }
}

// MARK: - Video Version

struct VideoVersion: Identifiable {
    let id: String
    var url: URL
    var relativePath: String
    let timestamp: Date
    let fileSize: Int64
    var isSelected: Bool
    let provider: VideoProvider?
    let takeIndex: Int
    var userLabel: String

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var displayName: String {
        let prefix = "take_\(takeIndex)"
        if userLabel.isEmpty { return prefix }
        return "\(prefix) \(userLabel)"
    }

    /// Parse a filename like "take_3 Best Shot.mp4" into (takeIndex, userLabel)
    static func parseTakeName(_ filename: String) -> (takeIndex: Int, userLabel: String)? {
        let name = (filename as NSString).deletingPathExtension
        guard name.hasPrefix("take_") else { return nil }
        let afterPrefix = String(name.dropFirst(5)) // drop "take_"
        // Split on first space: "3 Best Shot" -> index=3, label="Best Shot"
        if let spaceIdx = afterPrefix.firstIndex(of: " ") {
            let indexStr = String(afterPrefix[afterPrefix.startIndex..<spaceIdx])
            let label = String(afterPrefix[afterPrefix.index(after: spaceIdx)...])
            if let idx = Int(indexStr) { return (idx, label) }
        } else {
            // No space — just "take_3"
            if let idx = Int(afterPrefix) { return (idx, "") }
        }
        return nil
    }
}

// MARK: - Shot Video Generation Section

struct ShotVideoGenerationSection: View {
    let shot: Shot
    let scene: DCScene?
    let characters: [Character]
    let locations: [Location]
    let projectBasePath: URL?
    let onShotUpdated: (Shot) -> Void
    var onSceneUpdated: ((DCScene) -> Void)?
    var onNavigateToCharacter: ((Character) -> Void)?
    var onNavigateToLocation: ((Location) -> Void)?
    var onNavigateToStoryDesign: (() -> Void)?

    // MARK: - State

    @State private var isExpanded: Bool = true
    @State private var selectedProvider: VideoProvider = .veo3
    @State private var duration: Double = 5.0
    @State private var quality: String = "High"
    @State private var aspectRatio: String = "16:9"
    @State private var resolution: String = "720p"
    @State private var cameraMotion: String = "Static"
    @State private var subjectMotion: String = "Static"
    @State private var negativePromptText: String = ""
    @State private var keyframes: [VideoKeyframe] = []
    @State private var isGenerating: Bool = false
    @State private var generationJobId: String? = nil
    @State private var generationProgress: Double = 0
    @State private var generationStatus: String = ""
    @State private var errorMessage: String? = nil
    @State private var showingError: Bool = false
    @State private var showingPromptEditor: Bool = false
    @State private var editablePrompt: String = ""
    @State private var useCustomPrompt: Bool = false
    @State private var videoURL: URL? = nil
    @State private var showingFullScreenPlayer: Bool = false
    @State private var syncDuration: Bool = true
    /// App-scoped owner of the generation lifecycle. Polling/download/persist
    /// happen here so a job is never orphaned by navigating away (WS6.1).
    @EnvironmentObject private var videoJobs: VideoJobCoordinator
    @State private var activeKeyframeId: String? = nil
    @State private var keyframePrompt: String = ""
    @State private var showingKeyframePromptSheet: Bool = false
    @State private var isGeneratingKeyframe: Bool = false
    @State private var videoVersions: [VideoVersion] = []

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. Shot Context (above keyframes)
                    ShotContextCard(
                        shot: shot,
                        scene: scene,
                        characters: characters,
                        locations: locations,
                        projectBasePath: projectBasePath,
                        onNavigateToCharacter: onNavigateToCharacter,
                        onNavigateToLocation: onNavigateToLocation,
                        onNavigateToStoryDesign: onNavigateToStoryDesign,
                        onSceneUpdated: onSceneUpdated
                    )

                    // 2. Keyframe Gallery
                    KeyframeGallery(
                        keyframes: $keyframes,
                        duration: duration,
                        shot: shot,
                        projectBasePath: projectBasePath,
                        isGeneratingKeyframe: isGeneratingKeyframe,
                        activeKeyframeId: activeKeyframeId,
                        onGenerateKeyframe: { kfId in
                            activeKeyframeId = kfId
                            keyframePrompt = buildKeyframePrompt(for: kfId)
                            showingKeyframePromptSheet = true
                        },
                        onRemoveKeyframe: { kfId in
                            keyframes.removeAll { $0.id == kfId }
                        },
                        onAddKeyframe: addIntermediateKeyframe,
                        onAnnotationsApplied: { kfId, annotations in
                            // Set annotations and trigger regeneration with edit prompt
                            if let idx = keyframes.firstIndex(where: { $0.id == kfId }) {
                                keyframes[idx].annotations = annotations
                            }
                            activeKeyframeId = kfId
                            generateKeyframeWithAnnotations(keyframeId: kfId, annotations: annotations)
                        }
                    )

                    // 3. Video Settings
                    VideoSettingsCard(
                        selectedProvider: $selectedProvider,
                        duration: $duration,
                        quality: $quality,
                        aspectRatio: $aspectRatio,
                        resolution: $resolution,
                        cameraMotion: $cameraMotion,
                        subjectMotion: $subjectMotion,
                        negativePrompt: $negativePromptText,
                        syncDuration: $syncDuration,
                        interpolatesEndFrame: hasEndFrame,
                        shot: shot,
                        onDurationChanged: { newDuration in
                            if syncDuration {
                                var updated = shot
                                updated.videoDuration = newDuration
                                updated.duration = newDuration
                                onShotUpdated(updated)
                            }
                        }
                    )

                    // 4. Cost Estimate
                    CostEstimateBar(
                        provider: selectedProvider,
                        duration: selectedProvider.effectiveDuration(requested: duration,
                                                                     bridgesEndFrame: hasEndFrame),
                        quality: quality
                    )

                    // 5. Version Picker (only when multiple versions exist)
                    if videoVersions.count > 1 {
                        VideoVersionPicker(
                            versions: videoVersions,
                            projectBasePath: projectBasePath,
                            onSelect: { version in selectVideoVersion(version) },
                            onDelete: { version in deleteVideoVersion(version) },
                            onRename: { version, newLabel in renameVideoVersion(version, newLabel: newLabel) },
                            onShowInFinder: { version in
                                NSWorkspace.shared.activateFileViewerSelecting([version.url])
                            }
                        )
                    }

                    // 6. Generation / Player Area
                    if isGenerating {
                        GenerationProgressView(
                            progress: generationProgress,
                            status: generationStatus,
                            onCancel: cancelGeneration
                        )
                    } else if let url = videoURL {
                        VideoPlayerCard(
                            videoURL: url,
                            duration: duration,
                            showingFullScreen: $showingFullScreenPlayer,
                            onRegenerate: { startGeneration() },
                            onDownload: downloadToDesktop,
                            onShowInFinder: { showVideoInFinder(url) },
                            onShowPrompt: { openPromptEditor() }
                        )
                    } else {
                        generateButtons
                    }

                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(16)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(12)
            }
        }
        .onAppear {
            setupInitialState()
            resumeJobIfNeeded()
        }
        // No .onDisappear cancel: the coordinator owns the job so it keeps
        // running (and persists) when this view is recreated or navigated away.
        .onChange(of: videoJobs.jobs[shot.id]) { _, state in
            syncFromCoordinator(state)
        }
        .sheet(isPresented: $showingPromptEditor) {
            VideoPromptEditorSheet(
                prompt: $editablePrompt,
                useCustom: $useCustomPrompt,
                autoPrompt: buildAutoPrompt(),
                isPresented: $showingPromptEditor
            )
        }
        .sheet(isPresented: $showingKeyframePromptSheet) {
            KeyframePromptSheet(
                prompt: $keyframePrompt,
                isPresented: $showingKeyframePromptSheet,
                keyframeLabel: keyframes.first(where: { $0.id == activeKeyframeId })?.label ?? "Keyframe",
                onGenerate: {
                    generateKeyframeImage()
                }
            )
        }
        .sheet(isPresented: $showingFullScreenPlayer) {
            if let url = videoURL {
                FullScreenVideoSheet(videoURL: url, isPresented: $showingFullScreenPlayer)
            }
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
            HStack {
                Image(systemName: "film.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)

                Text("VIDEO GENERATION")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#252525"))
            .cornerRadius(isExpanded ? 0 : 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Buttons

    private var generateButtons: some View {
        HStack(spacing: 12) {
            Button(action: { startGeneration() }) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13))
                    Text("Generate Video")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button(action: { openPromptEditor() }) {
                HStack(spacing: 6) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 12))
                    Text("Edit Prompt")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "#3A3A3A"))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }

    // MARK: - Keyframe Helpers

    private func addIntermediateKeyframe() {
        let positions = keyframes.map { $0.position }.sorted()
        var maxGap = 0.0
        var gapPosition = 0.5
        for i in 0..<(positions.count - 1) {
            let gap = positions[i + 1] - positions[i]
            if gap > maxGap {
                maxGap = gap
                gapPosition = (positions[i] + positions[i + 1]) / 2
            }
        }
        let newKf = VideoKeyframe(
            position: gapPosition,
            label: String(format: "%.1fs", gapPosition * duration),
            timestamp: gapPosition * duration
        )
        keyframes.append(newKf)
    }

    // Prompt construction lives in ShotPromptBuilder (WS6.2).
    private func buildKeyframePrompt(for keyframeId: String) -> String {
        guard let kf = keyframes.first(where: { $0.id == keyframeId }) else { return "" }
        let names = scene.map { ShotPromptBuilder.characterNames(in: $0) } ?? []
        return ShotPromptBuilder.keyframePrompt(shot: shot, scene: scene, characterNames: names,
                                                characters: characters, locations: locations,
                                                position: kf.position)
    }

    /// Collect all reference images for the current scene.
    private func collectSceneReferenceImages() -> [ReferenceImage] {
        guard let currentScene = scene, let projDir = projectBasePath else { return [] }
        return CharacterReferenceHelper.collectReferenceImages(
            forScene: currentScene,
            characters: characters,
            locations: locations,
            projectDirectory: projDir
        )
    }

    private func generateKeyframeImage() {
        guard let kfId = activeKeyframeId else { return }
        showingKeyframePromptSheet = false
        isGeneratingKeyframe = true

        let basePrompt = keyframePrompt

        // Collect all reference images (location, characters, costumes)
        let refs = collectSceneReferenceImages()

        let fullPrompt: String
        if !refs.isEmpty {
            let prefix = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: refs)
            fullPrompt = prefix + basePrompt
        } else {
            fullPrompt = basePrompt
        }

        let request = ImageGenerationRequest(
            prompt: fullPrompt,
            provider: .googleImagen,
            aspectRatio: aspectRatio,
            referenceImages: refs.isEmpty ? nil : refs
        )

        Task {
            do {
                let response = try await AIServiceClient.shared.generateImage(request)

                if let imageData = response.images.first, let basePath = projectBasePath {
                    let dir = basePath.appendingPathComponent("assets/shots/shot_\(shot.shotId)/keyframes")
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let filename = "keyframe_\(kfId.prefix(8))_\(Int(Date().timeIntervalSince1970)).png"
                    let filePath = dir.appendingPathComponent(filename)
                    try imageData.write(to: filePath)
                    let relativePath = "assets/shots/shot_\(shot.shotId)/keyframes/\(filename)"

                    await MainActor.run {
                        if let idx = keyframes.firstIndex(where: { $0.id == kfId }) {
                            keyframes[idx].imagePath = relativePath
                        }
                        isGeneratingKeyframe = false
                        activeKeyframeId = nil

                        var updated = shot
                        updated.videoKeyframes = keyframes
                        onShotUpdated(updated)
                    }
                } else {
                    await MainActor.run {
                        isGeneratingKeyframe = false
                        errorMessage = "No image returned"
                    }
                }
            } catch {
                await MainActor.run {
                    isGeneratingKeyframe = false
                    errorMessage = "Keyframe generation failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Annotation-Enhanced Regeneration

    private func generateKeyframeWithAnnotations(keyframeId: String, annotations: [KeyframeAnnotation]) {
        guard let kfIndex = keyframes.firstIndex(where: { $0.id == keyframeId }) else { return }
        let kf = keyframes[kfIndex]

        isGeneratingKeyframe = true

        // Build annotation edit prompt
        var promptParts: [String] = []
        promptParts.append("Edit this image by making the following changes while keeping everything else identical:")
        for ann in annotations.sorted(by: { $0.number < $1.number }) {
            let xPercent = Int(ann.normalizedX * 100)
            let yPercent = Int(ann.normalizedY * 100)
            promptParts.append("\(ann.number). \(ann.text) at position (\(xPercent)%, \(yPercent)%)")
        }
        let editPrompt = promptParts.joined(separator: "\n")

        // Load reference image as base64
        var referenceBase64: String? = nil
        if let imagePath = kf.imagePath, let basePath = projectBasePath {
            let fullPath = basePath.appendingPathComponent(imagePath)
            if let data = try? Data(contentsOf: fullPath) {
                referenceBase64 = data.base64EncodedString()
            }
        }

        let request = ImageGenerationRequest(
            prompt: editPrompt,
            provider: .googleImagen,
            aspectRatio: aspectRatio,
            referenceImageBase64: referenceBase64,
            referenceMimeType: "image/png"
        )

        Task {
            do {
                let response = try await AIServiceClient.shared.generateImage(request)

                if let imageData = response.images.first, let basePath = projectBasePath {
                    let dir = basePath.appendingPathComponent("assets/shots/shot_\(shot.shotId)/keyframes")
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let filename = "keyframe_\(keyframeId.prefix(8))_edited_\(Int(Date().timeIntervalSince1970)).png"
                    let filePath = dir.appendingPathComponent(filename)
                    try imageData.write(to: filePath)
                    let relativePath = "assets/shots/shot_\(shot.shotId)/keyframes/\(filename)"

                    await MainActor.run {
                        if let idx = keyframes.firstIndex(where: { $0.id == keyframeId }) {
                            keyframes[idx].imagePath = relativePath
                            keyframes[idx].annotations = nil  // Clear annotations after apply
                        }
                        isGeneratingKeyframe = false
                        activeKeyframeId = nil

                        var updated = shot
                        updated.videoKeyframes = keyframes
                        onShotUpdated(updated)
                    }
                } else {
                    await MainActor.run {
                        isGeneratingKeyframe = false
                        errorMessage = "No image returned from annotation edit"
                    }
                }
            } catch {
                await MainActor.run {
                    isGeneratingKeyframe = false
                    errorMessage = "Annotation edit failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Setup

    private func setupInitialState() {
        if let shotDuration = shot.videoDuration ?? shot.duration {
            duration = shotDuration
        }
        if !shot.movement.isEmpty && shot.movement != "Static" {
            cameraMotion = shot.movement
        }
        if let provider = shot.videoProvider, let vp = VideoProvider(rawValue: provider) {
            selectedProvider = vp
        }
        // Clamp duration to provider's valid range
        duration = max(selectedProvider.minDuration, min(selectedProvider.maxDuration, duration))
        if let q = shot.videoQuality {
            quality = q
        }
        if let r = shot.videoResolution, selectedProvider.supportedResolutions.contains(r) {
            resolution = r
        }
        if let existing = shot.videoKeyframes, !existing.isEmpty {
            keyframes = existing
        } else {
            keyframes = [
                VideoKeyframe(position: 0.0, imagePath: shot.previewImage, label: "Start", timestamp: 0),
                VideoKeyframe(position: 1.0, label: "End", timestamp: duration)
            ]
        }
        if let videoPath = shot.videoPath, let basePath = projectBasePath {
            let fullPath = basePath.appendingPathComponent(videoPath)
            if FileManager.default.fileExists(atPath: fullPath.path) {
                videoURL = fullPath
            }
        }
        editablePrompt = buildAutoPrompt()
        discoverVideoVersions()
        // If video_path was stale but a version exists on disk, auto-select it
        if videoURL == nil, let firstVersion = videoVersions.first {
            videoURL = firstVersion.url
            var updated = shot
            updated.videoPath = firstVersion.relativePath
            onShotUpdated(updated)
            discoverVideoVersions()
        }
    }

    // MARK: - Prompt Building

    /// True when the End keyframe has an image, meaning the provider bridges
    /// start→end (interpolation) and fixes the clip duration itself.
    private var hasEndFrame: Bool {
        keyframes.contains { $0.position == 1.0 && $0.imagePath != nil }
    }

    // Prompt construction lives in ShotPromptBuilder (WS6.2) so it is pure and
    // unit-tested. Duration is omitted while interpolating — the provider
    // ignores it in that mode.
    private func buildAutoPrompt() -> String {
        ShotPromptBuilder.videoPrompt(
            shot: shot, scene: scene, characters: characters, locations: locations,
            cameraMotion: cameraMotion,
            duration: hasEndFrame ? nil : duration
        )
    }

    // MARK: - Generation

    private func startGeneration() {
        // Clamp duration to provider's valid range before submitting
        duration = max(selectedProvider.minDuration, min(selectedProvider.maxDuration, duration))
        let prompt = useCustomPrompt ? editablePrompt : buildAutoPrompt()
        isGenerating = true
        generationProgress = 0
        generationStatus = "Submitting..."
        errorMessage = nil

        var updated = shot
        updated.videoPrompt = prompt
        updated.videoDuration = duration
        updated.videoProvider = selectedProvider.rawValue
        updated.videoQuality = quality
        updated.videoResolution = resolution
        updated.videoKeyframes = keyframes
        onShotUpdated(updated)

        var startFrameBase64: String? = nil
        var endFrameBase64: String? = nil
        if let startKf = keyframes.first(where: { $0.position == 0.0 }),
           let imagePath = startKf.imagePath, let basePath = projectBasePath {
            if let data = try? Data(contentsOf: basePath.appendingPathComponent(imagePath)) {
                startFrameBase64 = data.base64EncodedString()
            }
        }
        if let endKf = keyframes.first(where: { $0.position == 1.0 }),
           let imagePath = endKf.imagePath, let basePath = projectBasePath {
            if let data = try? Data(contentsOf: basePath.appendingPathComponent(imagePath)) {
                endFrameBase64 = data.base64EncodedString()
            }
        }
        // Mid keyframes (0 < position < 1) ride along as reference frames for
        // subject/scene consistency through the shot. The gateway forwards ≤3.
        let referenceFrames: [ReferenceImage] = keyframes
            .filter { $0.position > 0.0 && $0.position < 1.0 }
            .sorted { $0.position < $1.position }
            .prefix(3)
            .compactMap { kf in
                guard let imagePath = kf.imagePath, let basePath = projectBasePath,
                      let data = try? Data(contentsOf: basePath.appendingPathComponent(imagePath))
                else { return nil }
                return ReferenceImage(base64: data.base64EncodedString(), label: kf.label)
            }
        // With an end frame the provider interpolates and fixes the length
        // itself; bill/estimate at that length, not the slider value.
        let bridging = endFrameBase64 != nil
        let effectiveDuration = selectedProvider.effectiveDuration(requested: duration,
                                                                   bridgesEndFrame: bridging)
        let trimmedNegative = negativePromptText.trimmingCharacters(in: .whitespacesAndNewlines)

        let request = VideoGenerationRequest(
            prompt: prompt,
            provider: selectedProvider.aiProvider,
            durationSeconds: effectiveDuration,
            quality: quality,
            aspectRatio: aspectRatio,
            fps: 24,
            cameraMotion: cameraMotion,
            subjectMotion: subjectMotion,
            negativePrompt: trimmedNegative.isEmpty ? nil : trimmedNegative,
            startFrameBase64: startFrameBase64,
            endFrameBase64: endFrameBase64,
            referenceFrames: referenceFrames.isEmpty ? nil : referenceFrames,
            resolution: resolution,
            shotId: shot.id,
            projectId: nil
        )

        guard let context = makeJobContext() else {
            isGenerating = false
            errorMessage = "Open the project from disk before generating video."
            return
        }
        // Hand the job to the app-scoped coordinator. It submits, polls,
        // downloads, and persists independently of this view's lifecycle.
        videoJobs.submit(request, context: context)
    }

    /// Build the context the coordinator needs to run/resume a job for this shot.
    /// Returns nil if the project isn't on disk (no place to save the video).
    private func makeJobContext() -> VideoJobContext? {
        guard let basePath = projectBasePath else { return nil }
        return VideoJobContext(
            shotId: shot.id,
            shotShotId: shot.shotId,
            aiProvider: selectedProvider.aiProvider,
            folderName: selectedProvider.folderName,
            providerRawValue: selectedProvider.rawValue,
            providerDisplayName: selectedProvider.displayName,
            basePath: basePath,
            // Usage tracking bills interpolation jobs at the provider-fixed
            // length, not the slider value.
            duration: selectedProvider.effectiveDuration(requested: duration,
                                                         bridgesEndFrame: hasEndFrame),
            quality: quality
        )
    }

    /// Mirror the coordinator's job state into this view's display state.
    private func syncFromCoordinator(_ state: VideoJobState?) {
        guard let state else { return }
        generationJobId = state.jobId.isEmpty ? nil : state.jobId
        generationProgress = state.progress
        generationStatus = state.message
        switch state.phase {
        case .submitting, .active, .downloading:
            isGenerating = true
            errorMessage = nil
        case .completed:
            isGenerating = false
            // The coordinator downloaded the file and persisted the path to the
            // shot; refresh the on-disk versions to surface it.
            discoverVideoVersions()
            if videoURL == nil, let first = videoVersions.first { videoURL = first.url }
        case .failed:
            isGenerating = false
            errorMessage = state.errorMessage
        }
    }

    /// Resume tracking an in-flight job for this shot (after navigation/relaunch).
    private func resumeJobIfNeeded() {
        syncFromCoordinator(videoJobs.state(forShot: shot.id))
        guard let jobId = shot.videoGenerationJobId, !jobId.isEmpty,
              videoJobs.state(forShot: shot.id) == nil,
              let context = makeJobContext() else { return }
        videoJobs.resume(jobId: jobId, context: context)
    }

    private func cancelGeneration() {
        videoJobs.cancel(shotId: shot.id, aiProvider: selectedProvider.aiProvider)
        isGenerating = false
        generationJobId = nil
        generationProgress = 0
        generationStatus = ""
    }

    private func openPromptEditor() {
        if !useCustomPrompt { editablePrompt = buildAutoPrompt() }
        showingPromptEditor = true
    }

    private func downloadToDesktop() {
        guard let url = videoURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "Shot_\(shot.shotId)_video.mp4"
        panel.begin { response in
            if response == .OK, let destination = panel.url {
                try? FileManager.default.copyItem(at: url, to: destination)
            }
        }
    }

    private func showVideoInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Video Version Discovery

    private func discoverVideoVersions() {
        guard let basePath = projectBasePath else { return }
        let videoDir = basePath.appendingPathComponent("assets/shots/shot_\(shot.shotId)/video")
        let fm = FileManager.default
        guard fm.fileExists(atPath: videoDir.path) else { videoVersions = []; return }

        var allVersions: [VideoVersion] = []
        let currentRelativePath = shot.videoPath

        // Scan provider subfolders
        for provider in VideoProvider.allCases {
            let providerDir = videoDir.appendingPathComponent(provider.folderName)
            guard fm.fileExists(atPath: providerDir.path) else { continue }
            guard let files = try? fm.contentsOfDirectory(at: providerDir, includingPropertiesForKeys: nil) else { continue }
            let mp4Files = files.filter { $0.pathExtension.lowercased() == "mp4" }

            for fileURL in mp4Files {
                guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path) else { continue }
                let fileSize = (attrs[.size] as? Int64) ?? 0
                let creationDate = (attrs[.creationDate] as? Date) ?? Date()
                let relativePath = "assets/shots/shot_\(shot.shotId)/video/\(provider.folderName)/\(fileURL.lastPathComponent)"
                let parsed = VideoVersion.parseTakeName(fileURL.lastPathComponent)
                allVersions.append(VideoVersion(
                    id: "\(provider.folderName)/\(fileURL.lastPathComponent)",
                    url: fileURL,
                    relativePath: relativePath,
                    timestamp: creationDate,
                    fileSize: fileSize,
                    isSelected: relativePath == currentRelativePath,
                    provider: provider,
                    takeIndex: parsed?.takeIndex ?? 0,
                    userLabel: parsed?.userLabel ?? ""
                ))
            }
        }

        // Also scan root video/ for legacy files (not in provider subfolder)
        if let rootFiles = try? fm.contentsOfDirectory(at: videoDir, includingPropertiesForKeys: nil) {
            let legacyMp4 = rootFiles.filter { $0.pathExtension.lowercased() == "mp4" }
            for fileURL in legacyMp4 {
                guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path) else { continue }
                let fileSize = (attrs[.size] as? Int64) ?? 0
                let creationDate = (attrs[.creationDate] as? Date) ?? Date()
                let relativePath = "assets/shots/shot_\(shot.shotId)/video/\(fileURL.lastPathComponent)"
                allVersions.append(VideoVersion(
                    id: fileURL.lastPathComponent,
                    url: fileURL,
                    relativePath: relativePath,
                    timestamp: creationDate,
                    fileSize: fileSize,
                    isSelected: relativePath == currentRelativePath,
                    provider: nil,
                    takeIndex: 0,
                    userLabel: (fileURL.lastPathComponent as NSString).deletingPathExtension
                ))
            }
        }

        videoVersions = allVersions.sorted { $0.timestamp > $1.timestamp }
    }

    private func selectVideoVersion(_ version: VideoVersion) {
        videoURL = version.url
        var updated = shot
        updated.videoPath = version.relativePath
        // Extract first frame as preview image for timeline
        extractPreviewImage(from: version.url) { previewPath in
            if let previewPath = previewPath {
                updated.previewImage = previewPath
            }
            onShotUpdated(updated)
        }
        discoverVideoVersions()
    }

    private func deleteVideoVersion(_ version: VideoVersion) {
        guard !version.isSelected else { return }
        try? FileManager.default.removeItem(at: version.url)
        discoverVideoVersions()
    }

    private func renameVideoVersion(_ version: VideoVersion, newLabel: String) {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        // Build new filename: "take_N label.mp4" or "take_N.mp4" if empty
        let newFilename = trimmed.isEmpty ? "take_\(version.takeIndex).mp4" : "take_\(version.takeIndex) \(trimmed).mp4"
        let newURL = version.url.deletingLastPathComponent().appendingPathComponent(newFilename)

        guard newURL != version.url else { return }
        do {
            try FileManager.default.moveItem(at: version.url, to: newURL)
            // Update shot.videoPath if this was the selected version
            if version.isSelected {
                let providerFolder = version.provider?.folderName
                let newRelative: String
                if let folder = providerFolder {
                    newRelative = "assets/shots/shot_\(shot.shotId)/video/\(folder)/\(newFilename)"
                } else {
                    newRelative = "assets/shots/shot_\(shot.shotId)/video/\(newFilename)"
                }
                videoURL = newURL
                var updated = shot
                updated.videoPath = newRelative
                onShotUpdated(updated)
            }
            discoverVideoVersions()
        } catch {
            errorMessage = "Failed to rename: \(error.localizedDescription)"
        }
    }

    private func extractPreviewImage(from videoURL: URL, completion: @escaping (String?) -> Void) {
        guard let basePath = projectBasePath else { completion(nil); return }
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 360)

        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
            guard let cgImage = cgImage else { completion(nil); return }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                completion(nil); return
            }

            let previewDir = basePath.appendingPathComponent("assets/shots/shot_\(shot.shotId)")
            try? FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)
            let filename = "preview_\(Int(Date().timeIntervalSince1970)).png"
            let filePath = previewDir.appendingPathComponent(filename)
            do {
                try pngData.write(to: filePath)
                let relativePath = "assets/shots/shot_\(shot.shotId)/\(filename)"
                DispatchQueue.main.async { completion(relativePath) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
