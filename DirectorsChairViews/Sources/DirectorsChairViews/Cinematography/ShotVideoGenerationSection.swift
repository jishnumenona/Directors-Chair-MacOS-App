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

    static func fromFolderName(_ name: String) -> VideoProvider? {
        allCases.first { $0.folderName == name }
    }
}

// MARK: - Video Version

private struct VideoVersion: Identifiable {
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
    @State private var cameraMotion: String = "Static"
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
                        cameraMotion: $cameraMotion,
                        syncDuration: $syncDuration,
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
                        duration: duration,
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
                            onShowInFinder: { showVideoInFinder(url) }
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
            PromptEditorSheet(
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

    private func buildKeyframePrompt(for keyframeId: String) -> String {
        guard let kf = keyframes.first(where: { $0.id == keyframeId }) else { return "" }

        var parts: [String] = []

        parts.append("A single cinematic film frame. \(shot.shotType) shot, \(shot.cameraAngle) angle.")
        if let lens = shot.lensMm {
            parts.append("\(lens)mm lens, \(shot.aperture).")
        }

        if !shot.description.isEmpty {
            parts.append(shot.description)
        }

        if let currentScene = scene {
            let charNames = resolveCharacterNames(from: currentScene)
            if !charNames.isEmpty {
                let charDescs = charNames.compactMap { name -> String? in
                    guard let char = characters.first(where: { $0.name == name }) else { return name }
                    var desc = name
                    desc += ", age \(char.age)"
                    if !char.gender.isEmpty { desc += ", \(char.gender)" }
                    if !char.about.isEmpty {
                        desc += ", \(String(char.about.prefix(100)))"
                    } else {
                        if !char.build.isEmpty && char.build != "Average" { desc += ", \(char.build.lowercased())" }
                        if !char.hairColor.isEmpty && !char.hairColor.hasPrefix("#") { desc += ", \(char.hairColor) hair" }
                        else if !char.hairStyle.isEmpty { desc += ", \(char.hairStyle) hair" }
                        if !char.distinguishingFeatures.isEmpty { desc += ", \(char.distinguishingFeatures)" }
                    }
                    if let costumes = char.costumes, let first = costumes.first {
                        desc += ", wearing \(first.name)"
                    }
                    return desc
                }
                parts.append("Characters: \(charDescs.joined(separator: "; "))")
            }

            if let loc = currentScene.location, !loc.isEmpty {
                if let location = locations.first(where: { $0.name.lowercased() == loc.lowercased() }) {
                    var locDesc = "Location: \(location.name)"
                    if !location.locationType.isEmpty { locDesc += " (\(location.locationType))" }
                    if !location.description.isEmpty { locDesc += " — \(location.description.prefix(200))" }
                    parts.append(locDesc)
                } else {
                    parts.append("Location: \(loc)")
                }
            }

            if !currentScene.props.isEmpty {
                parts.append("Props: \(currentScene.props.joined(separator: ", "))")
            }
        }

        // Position context
        if kf.position == 0.0 {
            parts.append("This is the opening frame of the shot.")
        } else if kf.position == 1.0 {
            parts.append("This is the final frame of the shot.")
        } else {
            parts.append("This frame is at \(String(format: "%.0f%%", kf.position * 100)) through the shot.")
        }

        parts.append("Dramatic lighting, cinematic quality, professional filmmaking, photorealistic.")
        return parts.joined(separator: "\n")
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

    private func buildAutoPrompt() -> String {
        var parts: [String] = []
        parts.append("Cinematic video shot. \(shot.shotType) shot, \(shot.cameraAngle) angle")
        if let lens = shot.lensMm {
            parts.append("\(lens)mm lens, \(shot.aperture)")
        }
        if !shot.description.isEmpty {
            parts.append(shot.description)
        }
        if let currentScene = scene {
            let sceneCharNames = resolveCharacterNames(from: currentScene)
            if !sceneCharNames.isEmpty {
                let charDescriptions = sceneCharNames.compactMap { name -> String? in
                    guard let char = characters.first(where: { $0.name == name }) else { return name }
                    var desc = name
                    desc += ", age \(char.age)"
                    if !char.gender.isEmpty { desc += ", \(char.gender)" }
                    return desc
                }
                parts.append("Characters: \(charDescriptions.joined(separator: "; "))")
            }
            let costumeDescriptions = sceneCharNames.compactMap { name -> String? in
                guard let char = characters.first(where: { $0.name == name }),
                      let costumes = char.costumes, !costumes.isEmpty else { return nil }
                let costumeNames = costumes.prefix(2).map { $0.name }
                return "\(name): \(costumeNames.joined(separator: ", "))"
            }
            if !costumeDescriptions.isEmpty {
                parts.append("Costumes: \(costumeDescriptions.joined(separator: "; "))")
            }
            if let loc = currentScene.location, !loc.isEmpty {
                parts.append("Location: \(loc)")
            }
            if !currentScene.props.isEmpty {
                parts.append("Props: \(currentScene.props.joined(separator: ", "))")
            }
            let dialogueTexts = shot.linkedDialogueIds.prefix(3).compactMap { dialogueId -> String? in
                guard let dialogue = currentScene.dialogues.first(where: { $0.id == dialogueId }) else { return nil }
                return "\(dialogue.character): \"\(dialogue.text)\""
            }
            if !dialogueTexts.isEmpty {
                parts.append("Dialogue: \(dialogueTexts.joined(separator: " "))")
            }
            let actionTexts = shot.linkedActionIds.prefix(2).compactMap { actionId -> String? in
                guard let action = currentScene.actions.first(where: { $0.id == actionId }) else { return nil }
                return action.description
            }
            if !actionTexts.isEmpty {
                parts.append("Action: \(actionTexts.joined(separator: ". "))")
            }
            if !currentScene.soundNotes.isEmpty {
                let sounds = currentScene.soundNotes.prefix(3).map { $0.description }
                parts.append("Sound atmosphere: \(sounds.joined(separator: ", "))")
            }
        }
        parts.append("Camera motion: \(cameraMotion). Duration: \(String(format: "%.1f", duration))s.")
        parts.append("Dramatic lighting, cinematic quality, professional filmmaking.")
        return parts.joined(separator: "\n")
    }

    private func resolveCharacterNames(from scene: DCScene) -> [String] {
        var names = Set<String>()
        for dialogue in scene.dialogues { names.insert(dialogue.character) }
        for action in scene.actions {
            for char in action.characters { names.insert(char) }
        }
        return Array(names).sorted()
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

        let request = VideoGenerationRequest(
            prompt: prompt,
            provider: selectedProvider.aiProvider,
            durationSeconds: duration,
            quality: quality,
            aspectRatio: aspectRatio,
            fps: 24,
            cameraMotion: cameraMotion,
            subjectMotion: "Static",
            startFrameBase64: startFrameBase64,
            endFrameBase64: endFrameBase64,
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
            duration: duration,
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

// MARK: - Keyframe Gallery (Redesigned — large cards)

private struct KeyframeGallery: View {
    @Binding var keyframes: [VideoKeyframe]
    let duration: Double
    let shot: Shot
    let projectBasePath: URL?
    let isGeneratingKeyframe: Bool
    let activeKeyframeId: String?
    let onGenerateKeyframe: (String) -> Void
    let onRemoveKeyframe: (String) -> Void
    let onAddKeyframe: () -> Void
    let onAnnotationsApplied: (String, [KeyframeAnnotation]) -> Void

    @State private var previewKeyframeImage: NSImage? = nil
    @State private var previewKeyframeLabel: String = ""
    @State private var showingKeyframePreview: Bool = false
    @State private var annotatingKeyframeId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "film")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("KEYFRAMES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                Text("\(keyframes.count) frame\(keyframes.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.6))
            }

            // Timeline track
            timelineTrack

            // Keyframe cards — horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(sortedKeyframes) { kf in
                        KeyframeCard(
                            keyframe: kf,
                            duration: duration,
                            projectBasePath: projectBasePath,
                            isGenerating: isGeneratingKeyframe && activeKeyframeId == kf.id,
                            isStartOrEnd: kf.position == 0.0 || kf.position == 1.0,
                            onGenerate: { onGenerateKeyframe(kf.id) },
                            onRemove: { onRemoveKeyframe(kf.id) },
                            onView: { image in
                                previewKeyframeImage = image
                                previewKeyframeLabel = kf.label.isEmpty ? String(format: "%.1fs", kf.position * duration) : kf.label
                                showingKeyframePreview = true
                            },
                            onDownload: { image in
                                downloadKeyframeImage(image: image, keyframe: kf)
                            },
                            onEdit: {
                                annotatingKeyframeId = kf.id
                            }
                        )
                    }

                    // Add keyframe button
                    addKeyframeCard
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
        .sheet(isPresented: $showingKeyframePreview) {
            KeyframePreviewSheet(
                image: $previewKeyframeImage,
                label: previewKeyframeLabel,
                shotId: shot.shotId,
                isPresented: $showingKeyframePreview,
                onDownload: {
                    if let img = previewKeyframeImage {
                        downloadKeyframeImage(image: img, keyframe: nil)
                    }
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { annotatingKeyframeId != nil },
            set: { if !$0 { annotatingKeyframeId = nil } }
        )) {
            if let kfId = annotatingKeyframeId,
               let kfIndex = keyframes.firstIndex(where: { $0.id == kfId }) {
                KeyframeAnnotationOverlay(
                    keyframe: $keyframes[kfIndex],
                    projectBasePath: projectBasePath,
                    shotId: shot.shotId,
                    isPresented: Binding(
                        get: { annotatingKeyframeId != nil },
                        set: { if !$0 { annotatingKeyframeId = nil } }
                    ),
                    onApplyEdits: { annotations in
                        onAnnotationsApplied(kfId, annotations)
                    }
                )
            }
        }
    }

    private var sortedKeyframes: [VideoKeyframe] {
        keyframes.sorted { $0.position < $1.position }
    }

    // Mini timeline track showing keyframe positions
    private var timelineTrack: some View {
        GeometryReader { geo in
            let w = geo.size.width

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color(hex: "#3A3A3A"))
                    .frame(height: 4)

                // Filled portion (start to end)
                Capsule()
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(height: 4)

                // Keyframe dots
                ForEach(sortedKeyframes) { kf in
                    Circle()
                        .fill(kf.imagePath != nil ? Color.accentColor : Color.gray)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#252525"), lineWidth: 2)
                        )
                        .position(x: max(5, min(kf.position * w, w - 5)), y: 5)
                }
            }
        }
        .frame(height: 10)
        .padding(.horizontal, 2)
    }

    private var addKeyframeCard: some View {
        Button(action: onAddKeyframe) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#2A2A2A"))
                        .frame(width: 380, height: 240)

                    VStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor.opacity(0.7))
                        Text("Add Keyframe")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }

                Text("")
                    .font(.system(size: 9))
            }
        }
        .buttonStyle(.plain)
    }

    private func downloadKeyframeImage(image: NSImage, keyframe: VideoKeyframe?) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        let label = keyframe?.label ?? "keyframe"
        let safeName = label.replacingOccurrences(of: " ", with: "_").lowercased()
        savePanel.nameFieldStringValue = "shot_\(shot.shotId)_\(safeName).png"
        savePanel.title = "Save Keyframe Image"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let ext = url.pathExtension.lowercased()
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData) {
                    let imageData: Data?
                    if ext == "jpg" || ext == "jpeg" {
                        imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                    } else {
                        imageData = bitmap.representation(using: .png, properties: [:])
                    }
                    if let data = imageData {
                        try? data.write(to: url)
                    }
                }
            }
        }
    }
}

// MARK: - Single Keyframe Card

private struct KeyframeCard: View {
    let keyframe: VideoKeyframe
    let duration: Double
    let projectBasePath: URL?
    let isGenerating: Bool
    let isStartOrEnd: Bool
    let onGenerate: () -> Void
    let onRemove: () -> Void
    let onView: (NSImage) -> Void
    let onDownload: (NSImage) -> Void
    let onEdit: () -> Void

    @State private var isHovering: Bool = false

    private let cardWidth: CGFloat = 380
    private let cardHeight: CGFloat = 240

    private var loadedImage: NSImage? {
        guard let imagePath = keyframe.imagePath,
              let basePath = projectBasePath else { return nil }
        return NSImage(contentsOf: basePath.appendingPathComponent(imagePath))
    }

    var body: some View {
        VStack(spacing: 6) {
            // Image preview area
            ZStack {
                if let image = loadedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    // Empty placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#1E1E1E"))
                        .frame(width: cardWidth, height: cardHeight)
                        .overlay(
                            VStack(spacing: 6) {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                    Text("Generating...")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("No image")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                            }
                        )
                }

                // Position badge (top-left)
                VStack {
                    HStack {
                        Text(keyframe.label.isEmpty ? String(format: "%.1fs", keyframe.position * duration) : keyframe.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)

                // Hover action buttons (top-right) — only when image exists
                if let image = loadedImage, isHovering {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                // View full size
                                Button(action: { onView(image) }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("View full size")

                                // Download
                                Button(action: { onDownload(image) }) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Download image")

                                // Edit / Annotate
                                Button(action: onEdit) {
                                    Image(systemName: "pencil.and.outline")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Edit with annotations")

                                // Regenerate
                                Button(action: onGenerate) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Regenerate")
                                .disabled(isGenerating)
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                    .transition(.opacity)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        keyframe.imagePath != nil ? Color.accentColor.opacity(0.4) : Color(hex: "#3A3A3A"),
                        lineWidth: 1
                    )
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            // Time label + annotation badge
            HStack(spacing: 6) {
                Text(String(format: "%.1fs", keyframe.position * duration))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                if let annotations = keyframe.annotations, !annotations.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 9))
                        Text("\(annotations.count)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
                }
            }

            // Actions row
            HStack(spacing: 6) {
                Button(action: onGenerate) {
                    HStack(spacing: 3) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 9))
                        Text("Generate")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)

                if !isStartOrEnd {
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundColor(.red.opacity(0.7))
                            .padding(4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Keyframe Full-Size Preview Sheet

private struct KeyframePreviewSheet: View {
    @Binding var image: NSImage?
    let label: String
    let shotId: Int
    @Binding var isPresented: Bool
    let onDownload: () -> Void

    private var imageSize: CGSize {
        guard let image = image else { return CGSize(width: 900, height: 506) }
        return image.size
    }

    private var sheetSize: (width: CGFloat, height: CGFloat) {
        let chromeHeight: CGFloat = 100
        let aspectRatio = imageSize.width / max(imageSize.height, 1)
        let displayWidth = min(imageSize.width, 1200)
        let displayHeight = displayWidth / aspectRatio
        return (displayWidth, displayHeight + chromeHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Shot #\(shotId) — \(label) Keyframe")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))

            Divider()

            // Image
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No preview available")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#1A1A1A"))
            }

            Divider()

            // Footer
            HStack {
                if let image = image {
                    Text("\(Int(image.size.width)) \u{00D7} \(Int(image.size.height))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: onDownload) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        Text("Download")
                    }
                }

                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))
        }
        .frame(width: sheetSize.width, height: sheetSize.height)
        .background(Color(hex: "#252525"))
    }
}

// MARK: - Keyframe Annotation Overlay

private struct KeyframeAnnotationOverlay: View {
    @Binding var keyframe: VideoKeyframe
    let projectBasePath: URL?
    let shotId: Int
    @Binding var isPresented: Bool
    let onApplyEdits: ([KeyframeAnnotation]) -> Void

    private var loadedImage: NSImage? {
        guard let imagePath = keyframe.imagePath,
              let basePath = projectBasePath else { return nil }
        return NSImage(contentsOf: basePath.appendingPathComponent(imagePath))
    }

    var body: some View {
        if let image = loadedImage {
            ImageAnnotationEditor(
                image: image,
                title: "EDIT KEYFRAME",
                subtitle: keyframe.label.isEmpty ? String(format: "%.1fs", keyframe.position) : keyframe.label,
                initialAnnotations: keyframe.annotations ?? [],
                isPresented: $isPresented,
                onApplyEdits: { annotations in
                    keyframe.annotations = annotations
                    onApplyEdits(annotations)
                }
            )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.4))
                Text("No keyframe image")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .frame(width: 900, height: 600)
            .background(Color(hex: "#252525"))
        }
    }
}

// MARK: - Shot Context Card

private struct ShotContextCard: View {
    let shot: Shot
    let scene: DCScene?
    let characters: [Character]
    let locations: [Location]
    let projectBasePath: URL?
    var onNavigateToCharacter: ((Character) -> Void)?
    var onNavigateToLocation: ((Location) -> Void)?
    var onNavigateToStoryDesign: (() -> Void)?
    var onSceneUpdated: ((DCScene) -> Void)?

    @State private var showingCharacterPicker = false
    @State private var showingPropInput = false
    @State private var newPropName = ""
    @State private var showingSoundInput = false
    @State private var newSoundDescription = ""
    @State private var newSoundType = "effects"
    @State private var editingSoundId: String? = nil
    @State private var editingSoundText: String = ""
    @State private var isDetecting = false
    @State private var showingLocationPicker = false
    @State private var showingLocationInput = false
    @State private var newLocationName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("SHOT CONTEXT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()

                Button(action: { Task { await detectFromScript() } }) {
                    HStack(spacing: 4) {
                        if isDetecting {
                            ProgressView()
                                .controlSize(.mini)
                                .scaleEffect(0.6)
                                .frame(width: 10, height: 10)
                            Text("Detecting...")
                                .font(.system(size: 9, weight: .medium))
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 9))
                            Text("Detect from Script")
                                .font(.system(size: 9, weight: .medium))
                        }
                    }
                    .foregroundColor(.accentColor.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isDetecting || scene == nil)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Characters
                if let currentScene = scene {
                    let charNames = resolveAllCharacterNames(scene: currentScene)
                    contextSection(icon: "person.2.fill", iconColor: .blue, title: "CHARACTERS") {
                        VideoContextFlowLayout(spacing: 8) {
                            ForEach(charNames, id: \.self) { name in
                                characterChip(name: name)
                            }
                            addButton { showingCharacterPicker = true }
                        }
                    }

                    // Costumes
                    let allCostumes = charNames.flatMap { name -> [(Character, CharacterCostume)] in
                        guard let char = characters.first(where: { $0.name == name }),
                              let costumes = char.costumes else { return [] }
                        return costumes.map { (char, $0) }
                    }
                    if !allCostumes.isEmpty {
                        contextSection(icon: "tshirt.fill", iconColor: .purple, title: "COSTUMES") {
                            VideoContextFlowLayout(spacing: 8) {
                                ForEach(allCostumes, id: \.1.id) { char, costume in
                                    costumeChip(character: char, costume: costume)
                                }
                            }
                        }
                    }

                    // Location
                    contextSection(icon: "mappin.and.ellipse", iconColor: .green, title: "LOCATION") {
                        VideoContextFlowLayout(spacing: 8) {
                            if let loc = currentScene.location, !loc.isEmpty {
                                deletableLocationChip(locationName: loc)
                            } else if showingLocationInput {
                                locationInputField
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.slash")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray.opacity(0.4))
                                    Text("No location set")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                                if !locations.isEmpty {
                                    addButton { showingLocationPicker = true }
                                } else {
                                    addButton { showingLocationInput = true }
                                }
                            }
                        }
                    }

                    // Props
                    contextSection(icon: "cube.fill", iconColor: .orange, title: "PROPS") {
                        VideoContextFlowLayout(spacing: 8) {
                            ForEach(currentScene.props, id: \.self) { prop in
                                deletablePropChip(prop: prop)
                            }
                            if currentScene.props.isEmpty && !showingPropInput {
                                HStack(spacing: 4) {
                                    Image(systemName: "cube.transparent")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray.opacity(0.4))
                                    Text("No props")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                            }
                            if showingPropInput {
                                propInputField
                            } else {
                                addButton { showingPropInput = true }
                            }
                        }
                    }

                    // Sounds
                    contextSection(icon: "speaker.wave.2.fill", iconColor: .pink, title: "SOUNDS") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(currentScene.soundNotes) { sound in
                                deletableSoundRow(sound: sound)
                            }
                            if currentScene.soundNotes.isEmpty && !showingSoundInput {
                                HStack(spacing: 4) {
                                    Image(systemName: "speaker.slash")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray.opacity(0.4))
                                    Text("No sounds")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                            }
                            if showingSoundInput {
                                soundInputField
                            } else {
                                addButton { showingSoundInput = true }
                            }
                        }
                    }

                    // Linked Dialogue
                    let linkedDialogues = shot.linkedDialogueIds.compactMap { id in
                        currentScene.dialogues.first(where: { $0.id == id })
                    }
                    if !linkedDialogues.isEmpty {
                        contextSection(icon: "text.bubble.fill", iconColor: .cyan, title: "DIALOGUE") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(linkedDialogues.prefix(4)) { d in
                                    dialogueRow(dialogue: d)
                                }
                            }
                        }
                    }

                    // Linked Actions
                    let linkedActions = shot.linkedActionIds.compactMap { id in
                        currentScene.actions.first(where: { $0.id == id })
                    }
                    if !linkedActions.isEmpty {
                        contextSection(icon: "figure.walk", iconColor: .yellow, title: "ACTIONS") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(linkedActions.prefix(3)) { a in
                                    actionRow(action: a)
                                }
                            }
                        }
                    }
                }

                // Camera (always present)
                contextSection(icon: "camera.fill", iconColor: .white, title: "CAMERA") {
                    VideoContextFlowLayout(spacing: 8) {
                        cameraChip(icon: "camera.viewfinder", text: "\(shot.shotType), \(shot.cameraAngle)")
                        if let lens = shot.lensMm {
                            cameraChip(icon: "circle.dotted", text: "\(lens)mm \(shot.aperture)")
                        }
                        if shot.movement != "Static" {
                            cameraChip(icon: "arrow.left.and.right", text: shot.movement)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#222222"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#333333"), lineWidth: 1)
                )
        )
        .popover(isPresented: $showingCharacterPicker) {
            characterPickerPopover
        }
        .popover(isPresented: $showingLocationPicker) {
            locationPickerPopover
        }
    }

    // MARK: - Scene Mutation Helpers

    private func setLocation(_ name: String) {
        guard var updated = scene else { return }
        updated.location = name
        onSceneUpdated?(updated)
    }

    private func removeProp(_ prop: String) {
        guard var updated = scene else { return }
        updated.props.removeAll { $0 == prop }
        onSceneUpdated?(updated)
    }

    private func addProp(_ name: String) {
        guard var updated = scene, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !updated.props.contains(trimmed) {
            updated.props.append(trimmed)
            onSceneUpdated?(updated)
        }
    }

    private func removeLocation() {
        guard var updated = scene else { return }
        updated.location = nil
        onSceneUpdated?(updated)
    }

    private func removeSound(_ soundId: String) {
        guard var updated = scene else { return }
        updated.soundNotes.removeAll { $0.id == soundId }
        onSceneUpdated?(updated)
    }

    private func addSound(description: String, type: String) {
        guard var updated = scene, !description.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let nextChronology = (updated.soundNotes.map { $0.chronologyNumber }.max() ?? 0) + 1
        let sound = SoundNote(
            description: description.trimmingCharacters(in: .whitespaces),
            soundType: type,
            chronologyNumber: nextChronology
        )
        updated.soundNotes.append(sound)
        onSceneUpdated?(updated)
    }

    private func updateSoundDescription(_ soundId: String, newDescription: String) {
        guard var updated = scene else { return }
        if let idx = updated.soundNotes.firstIndex(where: { $0.id == soundId }) {
            updated.soundNotes[idx].description = newDescription
            onSceneUpdated?(updated)
        }
    }

    // MARK: - Detect from Script

    private func detectFromScript() async {
        guard let currentScene = scene else { return }

        await MainActor.run { isDetecting = true }

        // Context parts (always included)
        var contextParts: [String] = []
        if !shot.description.isEmpty {
            contextParts.append("Shot description: \(shot.description)")
        }
        contextParts.append("Scene: \(currentScene.name)")
        if !currentScene.description.isEmpty {
            contextParts.append("Scene description: \(currentScene.description)")
        }
        if let existingLocation = currentScene.location, !existingLocation.isEmpty {
            contextParts.append("Current scene location: \(existingLocation)")
        }

        // Gather linked script text for this shot
        var linkedParts: [String] = []
        for dialogueId in shot.linkedDialogueIds {
            if let dialogue = currentScene.dialogues.first(where: { $0.id == dialogueId }) {
                linkedParts.append("\(dialogue.character.uppercased())\n\(dialogue.text)")
            }
        }
        for actionId in shot.linkedActionIds {
            if let action = currentScene.actions.first(where: { $0.id == actionId }) {
                linkedParts.append(action.description)
            }
        }
        for narrationId in shot.linkedNarrationIds {
            if let narration = currentScene.narrations.first(where: { $0.id == narrationId }) {
                linkedParts.append("(V.O.) \(narration.text)")
            }
        }

        // Fallback to entire scene script if no linked elements
        if linkedParts.isEmpty {
            for dialogue in currentScene.dialogues {
                linkedParts.append("\(dialogue.character.uppercased())\n\(dialogue.text)")
            }
            for action in currentScene.actions {
                linkedParts.append(action.description)
            }
            for narration in currentScene.narrations {
                linkedParts.append("(V.O.) \(narration.text)")
            }
        }

        let allParts = contextParts + linkedParts
        guard !allParts.isEmpty else {
            await MainActor.run { isDetecting = false }
            return
        }

        let scriptText = allParts.joined(separator: "\n\n")

        let prompt = """
        Analyze the following screenplay excerpt. Extract exactly these three things:

        1. "characters" — Names of all characters present, speaking, or mentioned
        2. "location" — The filming location. Look at the scene name for slug lines (e.g. "Scene 3 - INT. KITCHEN - DAY"). If the scene name contains INT./EXT., extract it. Also infer from action descriptions and shot description.
        3. "props" — Physical objects, weapons, vehicles, or items characters interact with

        Text to analyze:
        ---
        \(scriptText)
        ---

        IMPORTANT: You MUST respond with ONLY a raw JSON object (no markdown, no code fences, no explanation):
        {"characters": ["Name1", "Name2"], "location": "INT. PLACE - TIME", "props": ["item1", "item2"]}
        """

        // Ensure auth token is set (tokenProvider may fail off-main-actor)
        if let token = await AIServiceClient.shared.tokenProvider?() {
            await AIServiceClient.shared.setAuthToken(token)
        }

        do {
            let request = TextGenerationRequest(
                prompt: prompt,
                provider: .google,
                maxTokens: 2000,
                temperature: 0.1,
                systemPrompt: "You extract structured data from screenplay text. Output raw JSON only, never markdown code fences."
            )
            let response = try await AIServiceClient.shared.generateText(request)

            // Strip markdown code fences if present
            var jsonText = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonText.hasPrefix("```") {
                let lines = jsonText.components(separatedBy: "\n")
                let inner = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
                jsonText = inner.joined(separator: "\n")
            }
            if jsonText.hasSuffix("```") {
                jsonText = String(jsonText.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Try parsing JSON, with recovery for truncated responses
            var json: [String: Any]?
            if let data = jsonText.data(using: .utf8) {
                json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
            // If parsing failed, try to repair truncated JSON
            if json == nil {
                var repaired = jsonText
                let quoteCount = repaired.filter { $0 == "\"" }.count
                if quoteCount % 2 != 0 { repaired += "\"" }
                let openBrackets = repaired.filter { $0 == "[" }.count
                let closeBrackets = repaired.filter { $0 == "]" }.count
                for _ in 0..<(openBrackets - closeBrackets) { repaired += "]" }
                let openBraces = repaired.filter { $0 == "{" }.count
                let closeBraces = repaired.filter { $0 == "}" }.count
                for _ in 0..<(openBraces - closeBraces) { repaired += "}" }
                if let data = repaired.data(using: .utf8) {
                    json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                }
            }
            guard let json = json else {
                var updated = currentScene
                if let slug = parseSlugLineFromSceneName(currentScene.name) {
                    updated.location = slug
                    await MainActor.run {
                        onSceneUpdated?(updated)
                        isDetecting = false
                    }
                } else {
                    await MainActor.run { isDetecting = false }
                }
                return
            }

            var updated = currentScene

            // Update location
            if let location = json["location"] as? String,
               !location.isEmpty,
               !location.lowercased().contains("not specified"),
               !location.lowercased().contains("unknown"),
               !location.lowercased().contains("n/a") {
                updated.location = location
            }

            // Fallback: parse slug line from scene name
            if updated.location == nil || updated.location?.isEmpty == true {
                if let slug = parseSlugLineFromSceneName(currentScene.name) {
                    updated.location = slug
                }
            }

            // Merge props (add new, keep existing)
            if let props = json["props"] as? [String] {
                let existingLower = Set(updated.props.map { $0.lowercased() })
                for prop in props {
                    let trimmed = prop.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && !existingLower.contains(trimmed.lowercased()) {
                        updated.props.append(trimmed)
                    }
                }
            }

            // Merge characters — add detected names to a linked action's character list
            if let detectedChars = json["characters"] as? [String] {
                let existingChars = Set(resolveAllCharacterNames(scene: currentScene))
                let newChars = detectedChars.filter { !$0.isEmpty && !existingChars.contains($0) }

                if !newChars.isEmpty {
                    let actionIndex: Int?
                    if let firstLinkedId = shot.linkedActionIds.first {
                        actionIndex = updated.actions.firstIndex(where: { $0.id == firstLinkedId })
                    } else {
                        actionIndex = updated.actions.indices.first
                    }
                    if let idx = actionIndex {
                        for name in newChars {
                            if !updated.actions[idx].characters.contains(name) {
                                updated.actions[idx].characters.append(name)
                            }
                        }
                    }
                }
            }

            await MainActor.run {
                onSceneUpdated?(updated)
                isDetecting = false
            }

        } catch {
            var updated = currentScene
            if let slug = parseSlugLineFromSceneName(currentScene.name) {
                updated.location = slug
                await MainActor.run {
                    onSceneUpdated?(updated)
                    isDetecting = false
                }
            } else {
                await MainActor.run { isDetecting = false }
            }
        }
    }

    // MARK: - Section Builder

    @ViewBuilder
    private func contextSection<Content: View>(icon: String, iconColor: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.gray)
            }
            content()
        }
    }

    // MARK: - Character Chip

    @ViewBuilder
    private func characterChip(name: String) -> some View {
        let char = characters.first(where: { $0.name == name })
        // Character is removable only if they come from action character lists, not dialogue speakers
        let speaksDialogue = scene?.dialogues.contains(where: { $0.character == name }) ?? false

        HStack(spacing: 0) {
            Button(action: {
                if let char = char { onNavigateToCharacter?(char) }
            }) {
                HStack(spacing: 6) {
                    // Thumbnail
                    if let char = char, let basePath = projectBasePath {
                        let imgPath = char.imageFront ?? char.baseImage ?? char.avatar
                        if let path = imgPath, let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 22, height: 22)
                                .clipShape(Circle())
                        } else {
                            defaultCircleIcon(icon: "person.fill", color: .blue)
                        }
                    } else {
                        defaultCircleIcon(icon: "person.fill", color: .blue)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        if let char = char {
                            Text("\(char.gender), \(char.age)")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 7))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            if !speaksDialogue {
                Button(action: { removeCharacterFromScene(name) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.leading, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.blue.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.15), lineWidth: 1))
        .cornerRadius(8)
    }

    // MARK: - Costume Chip

    @ViewBuilder
    private func costumeChip(character: Character, costume: CharacterCostume) -> some View {
        Button(action: {
            onNavigateToCharacter?(character)
        }) {
            HStack(spacing: 6) {
                if let basePath = projectBasePath, let path = costume.imageFront,
                   let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    defaultSquareIcon(icon: "tshirt", color: .purple)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(costume.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                    Text(character.name)
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 7))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.purple.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.15), lineWidth: 1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Deletable Location Chip

    @ViewBuilder
    private func deletableLocationChip(locationName: String) -> some View {
        let location = locations.first(where: { $0.name == locationName })

        HStack(spacing: 0) {
            Button(action: {
                if let loc = location { onNavigateToLocation?(loc) }
            }) {
                HStack(spacing: 6) {
                    if let loc = location, let basePath = projectBasePath,
                       let path = loc.primaryImage ?? loc.images.first,
                       let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        defaultSquareIcon(icon: "mappin", color: .green)
                    }

                    Text(locationName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 7))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            Button(action: { removeLocation() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.leading, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.green.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.15), lineWidth: 1))
        .cornerRadius(8)
    }

    // MARK: - Deletable Prop Chip

    @ViewBuilder
    private func deletablePropChip(prop: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "cube")
                .font(.system(size: 9))
                .foregroundColor(.orange.opacity(0.7))
            Text(prop)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)

            Button(action: { removeProp(prop) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.orange.opacity(0.15), lineWidth: 1))
        .cornerRadius(7)
    }

    // MARK: - Prop Input Field

    private var propInputField: some View {
        HStack(spacing: 4) {
            Image(systemName: "cube.fill")
                .font(.system(size: 9))
                .foregroundColor(.orange.opacity(0.5))
            TextField("Prop name", text: $newPropName)
                .font(.system(size: 10))
                .textFieldStyle(.plain)
                .frame(width: 100)
                .onSubmit {
                    addProp(newPropName)
                    newPropName = ""
                    showingPropInput = false
                }
            Button(action: {
                addProp(newPropName)
                newPropName = ""
                showingPropInput = false
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(newPropName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button(action: {
                newPropName = ""
                showingPropInput = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.orange.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .cornerRadius(7)
    }

    // MARK: - Location Input Field

    private var locationInputField: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin")
                .font(.system(size: 9))
                .foregroundColor(.green.opacity(0.5))
            TextField("Location name", text: $newLocationName)
                .font(.system(size: 10))
                .textFieldStyle(.plain)
                .frame(width: 140)
                .onSubmit {
                    setLocation(newLocationName)
                    newLocationName = ""
                    showingLocationInput = false
                }
            Button(action: {
                setLocation(newLocationName)
                newLocationName = ""
                showingLocationInput = false
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(newLocationName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button(action: {
                newLocationName = ""
                showingLocationInput = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.green.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .cornerRadius(7)
    }

    // MARK: - Location Picker Popover

    private var locationPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set Location")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(locations) { loc in
                        Button(action: {
                            showingLocationPicker = false
                            setLocation(loc.name)
                        }) {
                            HStack(spacing: 8) {
                                if let basePath = projectBasePath,
                                   let path = loc.primaryImage ?? loc.images.first,
                                   let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 24, height: 24)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    defaultSquareIcon(icon: "mappin", color: .green)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(loc.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                    if !loc.locationType.isEmpty {
                                        Text(loc.locationType)
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider().opacity(0.3)

            Button(action: {
                showingLocationPicker = false
                showingLocationInput = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 10))
                    Text("Enter Custom Location")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 240)
        .background(Color(hex: "#2A2A2A"))
    }

    // MARK: - Deletable Sound Row

    @ViewBuilder
    private func deletableSoundRow(sound: SoundNote) -> some View {
        HStack(spacing: 8) {
            Image(systemName: soundIcon(sound.soundType))
                .font(.system(size: 10))
                .foregroundColor(.pink.opacity(0.7))
                .frame(width: 16)

            if editingSoundId == sound.id {
                TextField("Description", text: $editingSoundText)
                    .font(.system(size: 10))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        updateSoundDescription(sound.id, newDescription: editingSoundText)
                        editingSoundId = nil
                    }
                Button(action: {
                    updateSoundDescription(sound.id, newDescription: editingSoundText)
                    editingSoundId = nil
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green.opacity(0.8))
                }
                .buttonStyle(.plain)
            } else {
                Text(sound.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
                    .onTapGesture(count: 2) {
                        editingSoundId = sound.id
                        editingSoundText = sound.description
                    }
            }

            Spacer()

            Button(action: { removeSound(sound.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pink.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.pink.opacity(0.1), lineWidth: 1))
        .cornerRadius(7)
    }

    // MARK: - Sound Input Field

    private var soundInputField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                // Sound type selector
                Menu {
                    Button("Effects") { newSoundType = "effects" }
                    Button("Ambient") { newSoundType = "ambient" }
                    Button("Music") { newSoundType = "music" }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: soundIcon(newSoundType))
                            .font(.system(size: 9))
                        Text(newSoundType.capitalized)
                            .font(.system(size: 9, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 6))
                    }
                    .foregroundColor(.pink.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.1))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                TextField("Sound description", text: $newSoundDescription)
                    .font(.system(size: 10))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        addSound(description: newSoundDescription, type: newSoundType)
                        newSoundDescription = ""
                        showingSoundInput = false
                    }

                Button(action: {
                    addSound(description: newSoundDescription, type: newSoundType)
                    newSoundDescription = ""
                    showingSoundInput = false
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green.opacity(0.8))
                }
                .buttonStyle(.plain)
                .disabled(newSoundDescription.trimmingCharacters(in: .whitespaces).isEmpty)

                Button(action: {
                    newSoundDescription = ""
                    showingSoundInput = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pink.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.pink.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .cornerRadius(7)
    }

    // MARK: - Dialogue Row

    @ViewBuilder
    private func dialogueRow(dialogue: Dialogue) -> some View {
        let char = characters.first(where: { $0.name == dialogue.character })

        Button(action: {
            if let char = char { onNavigateToCharacter?(char) }
        }) {
            HStack(alignment: .top, spacing: 8) {
                // Mini avatar
                if let char = char, let basePath = projectBasePath,
                   let path = char.imageFront ?? char.baseImage ?? char.avatar,
                   let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text(String(dialogue.character.prefix(1)))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.cyan)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(dialogue.character)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.cyan)
                    Text("\"\(dialogue.text)\"")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                        .italic()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cyan.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cyan.opacity(0.1), lineWidth: 1))
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Row

    @ViewBuilder
    private func actionRow(action: Action) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.yellow.opacity(0.7))
                .frame(width: 16, alignment: .center)
                .padding(.top, 2)
            Text(action.description)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.yellow.opacity(0.1), lineWidth: 1))
        .cornerRadius(7)
    }

    // MARK: - Camera Chip

    @ViewBuilder
    private func cameraChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .cornerRadius(7)
    }

    // MARK: - Add Button

    @ViewBuilder
    private func addButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .medium))
                Text("Add")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.accentColor.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.accentColor.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icon Helpers

    @ViewBuilder
    private func defaultCircleIcon(icon: String, color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.12))
            .frame(width: 22, height: 22)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color.opacity(0.7))
            )
    }

    @ViewBuilder
    private func defaultSquareIcon(icon: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(0.12))
            .frame(width: 22, height: 22)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color.opacity(0.7))
            )
    }

    // MARK: - Character Picker Popover

    private var characterPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Character")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 4)

            let existingNames = scene.map { resolveAllCharacterNames(scene: $0) } ?? []
            let availableChars = characters.filter { !existingNames.contains($0.name) }

            if availableChars.isEmpty {
                VStack(spacing: 8) {
                    Text("All characters are in this scene")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)

                    Button(action: {
                        showingCharacterPicker = false
                        onNavigateToStoryDesign?()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 10))
                            Text("Create New Character")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(availableChars) { char in
                            Button(action: {
                                showingCharacterPicker = false
                                onNavigateToCharacter?(char)
                            }) {
                                HStack(spacing: 8) {
                                    if let basePath = projectBasePath,
                                       let path = char.imageFront ?? char.baseImage ?? char.avatar,
                                       let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                                        Image(nsImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 24, height: 24)
                                            .clipShape(Circle())
                                    } else {
                                        defaultCircleIcon(icon: "person.fill", color: .blue)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(char.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                        Text("\(char.gender), \(char.age)")
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 200)

                Divider().opacity(0.3)

                Button(action: {
                    showingCharacterPicker = false
                    onNavigateToStoryDesign?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 10))
                        Text("Create New Character")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 240)
        .background(Color(hex: "#2A2A2A"))
    }

    // MARK: - Helpers

    private func resolveAllCharacterNames(scene: DCScene) -> [String] {
        var names = Set<String>()
        for dialogue in scene.dialogues { names.insert(dialogue.character) }
        for action in scene.actions {
            for char in action.characters { names.insert(char) }
        }
        return Array(names).sorted()
    }

    private func soundIcon(_ type: String) -> String {
        switch type {
        case "music": return "music.note"
        case "ambient": return "waveform"
        case "effects": return "bolt.fill"
        default: return "speaker.wave.1"
        }
    }

    /// Parse a slug line from a scene name like "Scene 3 - INT. KITCHEN - DAY"
    private func parseSlugLineFromSceneName(_ name: String) -> String? {
        let upper = name.uppercased()
        for prefix in ["INT./EXT.", "INT/EXT.", "INT/EXT", "INT.", "EXT.", "INT ", "EXT "] {
            if let range = upper.range(of: prefix) {
                // Return from the prefix onwards
                return String(name[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Remove a character name from all action character lists in the scene
    private func removeCharacterFromScene(_ charName: String) {
        guard var updated = scene else { return }
        for i in updated.actions.indices {
            updated.actions[i].characters.removeAll { $0 == charName }
        }
        onSceneUpdated?(updated)
    }
}

// MARK: - Keyframe Prompt Sheet

private struct KeyframePromptSheet: View {
    @Binding var prompt: String
    @Binding var isPresented: Bool
    let keyframeLabel: String
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.accentColor)
                Text("Generate \(keyframeLabel) Frame")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .foregroundColor(.gray)
            }

            Text("Edit the prompt below, then generate the keyframe image.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: $prompt)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(8)
                .frame(minHeight: 180)

            HStack {
                Spacer()
                Button(action: {
                    onGenerate()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12))
                        Text("Generate Keyframe")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 520, height: 380)
        .background(Color(hex: "#252525"))
    }
}

// MARK: - Flow Layout

private struct VideoContextFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0; var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height); x += size.width + spacing; maxX = max(maxX, x)
        }
        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Video Settings Card

private struct VideoSettingsCard: View {
    @Binding var selectedProvider: VideoProvider
    @Binding var duration: Double
    @Binding var quality: String
    @Binding var aspectRatio: String
    @Binding var cameraMotion: String
    @Binding var syncDuration: Bool
    let shot: Shot
    let onDurationChanged: (Double) -> Void

    private let qualities = ["Standard", "High", "Ultra"]
    private let aspectRatios = ["16:9", "9:16", "1:1"]
    private let cameraMotions = ["Static", "Pan Left", "Pan Right", "Zoom In", "Zoom Out", "Dolly", "Crane", "Tracking"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("VIDEO SETTINGS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
            }

            // Provider
            VStack(alignment: .leading, spacing: 6) {
                Text("Provider")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                HStack(spacing: 6) {
                    ForEach(VideoProvider.allCases, id: \.rawValue) { provider in
                        chipButton(icon: provider.icon, label: provider.displayName, isSelected: selectedProvider == provider) {
                            selectedProvider = provider
                            if duration > provider.maxDuration { duration = provider.maxDuration; onDurationChanged(duration) }
                            if duration < provider.minDuration { duration = provider.minDuration; onDurationChanged(duration) }
                        }
                    }
                }
            }

            // Duration
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Duration").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: syncDuration ? "link" : "link.badge.plus").font(.system(size: 9)).foregroundColor(syncDuration ? .accentColor : .gray)
                        Text("Sync timeline").font(.system(size: 9)).foregroundColor(.gray)
                        Toggle("", isOn: $syncDuration).toggleStyle(.switch).scaleEffect(0.6).frame(width: 30)
                    }
                }
                HStack(spacing: 12) {
                    Text(String(format: "%.1f", duration))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("sec").font(.system(size: 11)).foregroundColor(.gray)
                    Slider(value: $duration, in: selectedProvider.minDuration...selectedProvider.maxDuration, step: 0.5)
                        .onChange(of: duration) { _, newValue in onDurationChanged(newValue) }
                }
            }

            // Quality & Aspect
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quality").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                    HStack(spacing: 6) {
                        ForEach(qualities, id: \.self) { q in
                            chipButton(icon: q == "Ultra" ? "star.fill" : q == "High" ? "sparkles" : "circle", label: q, isSelected: quality == q) { quality = q }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aspect Ratio").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                    HStack(spacing: 6) {
                        ForEach(aspectRatios, id: \.self) { ar in
                            chipButton(icon: ar == "16:9" ? "rectangle" : ar == "9:16" ? "rectangle.portrait" : "square", label: ar, isSelected: aspectRatio == ar) { aspectRatio = ar }
                        }
                    }
                }
            }

            // Camera Motion
            VStack(alignment: .leading, spacing: 6) {
                Text("Camera Motion").font(.system(size: 9, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
                    ForEach(cameraMotions, id: \.self) { motion in
                        chipButton(icon: motionIcon(motion), label: motion, isSelected: cameraMotion == motion) { cameraMotion = motion }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    private func motionIcon(_ motion: String) -> String {
        switch motion {
        case "Static": return "viewfinder"; case "Pan Left": return "arrow.left"; case "Pan Right": return "arrow.right"
        case "Zoom In": return "plus.magnifyingglass"; case "Zoom Out": return "minus.magnifyingglass"
        case "Dolly": return "arrow.up.and.down"; case "Crane": return "arrow.up.forward"; case "Tracking": return "figure.walk"
        default: return "arrow.left.and.right"
        }
    }

    @ViewBuilder
    private func chipButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(hex: "#3A3A3A"))
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cost Estimate Bar

private struct CostEstimateBar: View {
    let provider: VideoProvider
    let duration: Double
    let quality: String

    private var estimatedCost: Double {
        duration * provider.costPerSecond
    }

    var body: some View {
        HStack {
            Image(systemName: "dollarsign.circle").font(.system(size: 11)).foregroundColor(.accentColor)
            Text(provider.displayName).font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
            Text("·").foregroundColor(.gray.opacity(0.5))
            Text(String(format: "%.1fs", duration)).font(.system(size: 10)).foregroundColor(.gray)
            Text("·").foregroundColor(.gray.opacity(0.5))
            Text(quality).font(.system(size: 10)).foregroundColor(.gray)
            Spacer()
            Text("Estimated:").font(.system(size: 10)).foregroundColor(.gray)
            Text(String(format: "$%.2f", estimatedCost))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)
        }
        .padding(10)
        .background(Color(hex: "#252525"))
        .cornerRadius(8)
    }
}

// MARK: - Generation Progress View

private struct GenerationProgressView: View {
    let progress: Double
    let status: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform").font(.system(size: 10)).foregroundColor(.accentColor)
                Text("GENERATING").font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundColor(.gray)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#2A2A2A")).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(Color.accentColor)
                        .frame(width: geo.size.width * (progress / 100), height: 8)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)
            HStack {
                Text(String(format: "%.0f%%", progress)).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text(status).font(.system(size: 11)).foregroundColor(.gray)
                Spacer()
                Button(action: onCancel) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark").font(.system(size: 9))
                        Text("Cancel").font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.red).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.red.opacity(0.15)).cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12).background(Color(hex: "#252525")).cornerRadius(8)
    }
}

// MARK: - Video Player Card

private struct VideoPlayerCard: View {
    let videoURL: URL
    let duration: Double
    @Binding var showingFullScreen: Bool
    let onRegenerate: () -> Void
    let onDownload: () -> Void
    var onShowInFinder: (() -> Void)?
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var videoDuration: Double = 0
    @State private var timeObserver: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("VIDEO PREVIEW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
                Spacer()
                // File path pill
                Text(videoURL.lastPathComponent)
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.5))
                    .lineLimit(1)
            }

            // Video Player
            ZStack {
                if let player = player {
                    NativeVideoPlayerView(player: player)
                        .allowsHitTesting(false)
                        .frame(height: 240)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
                        )
                        .overlay(
                            // Transparent overlay for click-to-play/pause
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { togglePlayback() }
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#1A1A1A"))
                        .frame(height: 240)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
            }

            // Transport Controls
            VStack(spacing: 6) {
                // Seek Bar
                HStack(spacing: 8) {
                    Text(formatTime(currentTime))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 40, alignment: .trailing)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "#3A3A3A"))
                                .frame(height: 4)

                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor)
                                .frame(width: videoDuration > 0 ? geo.size.width * CGFloat(currentTime / videoDuration) : 0, height: 4)

                            // Scrubber handle
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .offset(x: videoDuration > 0 ? geo.size.width * CGFloat(currentTime / videoDuration) - 5 : -5)
                        }
                        .frame(height: 10)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let fraction = max(0, min(1, value.location.x / geo.size.width))
                                    let seekTime = Double(fraction) * videoDuration
                                    player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
                                    currentTime = seekTime
                                }
                        )
                    }
                    .frame(height: 10)

                    Text(formatTime(videoDuration))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 40, alignment: .leading)
                }

                // Play/Pause + Action Buttons
                HStack(spacing: 8) {
                    // Playback controls
                    HStack(spacing: 4) {
                        Button(action: { seekBackward() }) {
                            Image(systemName: "gobackward.5")
                                .font(.system(size: 11))
                                .frame(width: 28, height: 28)
                                .background(Color(hex: "#3A3A3A"))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { togglePlayback() }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13))
                                .frame(width: 34, height: 28)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { seekForward() }) {
                            Image(systemName: "goforward.5")
                                .font(.system(size: 11))
                                .frame(width: 28, height: 28)
                                .background(Color(hex: "#3A3A3A"))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Action buttons
                    actionBtn(icon: "arrow.up.left.and.arrow.down.right", label: "Full Screen") { showingFullScreen = true }
                    actionBtn(icon: "folder", label: "Show in Finder") { onShowInFinder?() }
                    actionBtn(icon: "square.and.arrow.down", label: "Export", action: onDownload)
                    actionBtn(icon: "arrow.triangle.2.circlepath", label: "Regenerate", action: onRegenerate)
                }
            }
        }
        .padding(12)
        .background(Color(hex: "#252525"))
        .cornerRadius(8)
        .onAppear { setupPlayer() }
        .onDisappear { cleanupPlayer() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("toggleShotVideoPlayback"))) { _ in
            togglePlayback()
        }
    }

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: videoURL)
        player = avPlayer

        // Observe time updates
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
        }

        // Get video duration
        Task {
            if let duration = try? await avPlayer.currentItem?.asset.load(.duration) {
                await MainActor.run {
                    videoDuration = duration.seconds.isFinite ? duration.seconds : self.duration
                }
            }
        }

        // Observe end of playback to reset
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            avPlayer.seek(to: .zero)
            currentTime = 0
        }
    }

    private func cleanupPlayer() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player = nil
    }

    private func togglePlayback() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func seekBackward() {
        guard let player = player else { return }
        let newTime = max(0, currentTime - 5)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        currentTime = newTime
    }

    private func seekForward() {
        guard let player = player else { return }
        let newTime = min(videoDuration, currentTime + 5)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
        currentTime = newTime
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    @ViewBuilder
    private func actionBtn(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(hex: "#3A3A3A")).foregroundColor(.white).cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Video Version Picker

private struct VideoVersionPicker: View {
    let versions: [VideoVersion]
    let projectBasePath: URL?
    let onSelect: (VideoVersion) -> Void
    let onDelete: (VideoVersion) -> Void
    let onRename: (VideoVersion, String) -> Void
    let onShowInFinder: (VideoVersion) -> Void

    private var providerGroups: [(provider: VideoProvider?, versions: [VideoVersion])] {
        var grouped: [String: [VideoVersion]] = [:]
        for v in versions {
            let key = v.provider?.folderName ?? "_legacy"
            grouped[key, default: []].append(v)
        }
        // Order: known providers first (in enum order), then legacy
        var result: [(provider: VideoProvider?, versions: [VideoVersion])] = []
        for provider in VideoProvider.allCases {
            if let group = grouped[provider.folderName], !group.isEmpty {
                result.append((provider, group.sorted { $0.takeIndex < $1.takeIndex }))
            }
        }
        if let legacy = grouped["_legacy"], !legacy.isEmpty {
            result.append((nil, legacy.sorted { $0.timestamp > $1.timestamp }))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("VIDEO TAKES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(versions.count) take\(versions.count == 1 ? "" : "s")")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.5))
            }

            // Provider sections
            ForEach(Array(providerGroups.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: 8) {
                    // Provider header
                    HStack(spacing: 6) {
                        if let provider = group.provider {
                            Image(systemName: provider.icon)
                                .font(.system(size: 10))
                                .foregroundColor(providerColor(provider))
                            Text(provider.displayName.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(providerColor(provider))
                        } else {
                            Image(systemName: "film")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Text("IMPORTED")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(.gray)
                        }
                        Text("\(group.versions.count)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(4)
                    }

                    // Filmstrip for this provider
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(group.versions) { version in
                                VersionCard(
                                    version: version,
                                    providerColor: group.provider.map { providerColor($0) } ?? .gray,
                                    onSelect: onSelect,
                                    onDelete: onDelete,
                                    onRename: onRename,
                                    onShowInFinder: onShowInFinder
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .background(Color(hex: "#1E1E1E"))
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    private func providerColor(_ provider: VideoProvider) -> Color {
        switch provider {
        case .veo3: return .blue
        case .sora2: return .purple
        case .kling: return .orange
        }
    }
}

// MARK: - Version Card (with inline rename)

private struct VersionCard: View {
    let version: VideoVersion
    let providerColor: Color
    let onSelect: (VideoVersion) -> Void
    let onDelete: (VideoVersion) -> Void
    let onRename: (VideoVersion, String) -> Void
    let onShowInFinder: (VideoVersion) -> Void

    @State private var isEditing: Bool = false
    @State private var editText: String = ""

    var body: some View {
        VStack(spacing: 5) {
            // Thumbnail
            Button(action: { onSelect(version) }) {
                ZStack {
                    VideoThumbnailView(videoURL: version.url)
                        .frame(width: 140, height: 85)
                        .clipped()
                        .cornerRadius(6)

                    // Selected badge
                    if version.isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.accentColor)
                                    .background(Circle().fill(Color.black).frame(width: 12, height: 12))
                            }
                            Spacer()
                        }
                        .padding(4)
                    }

                    // Take badge (bottom left)
                    VStack {
                        Spacer()
                        HStack {
                            Text("take \(version.takeIndex)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(providerColor.opacity(0.8))
                                .cornerRadius(3)
                            Spacer()
                        }
                    }
                    .padding(4)
                }
                .frame(width: 140, height: 85)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(version.isSelected ? Color.accentColor : Color(hex: "#3A3A3A"), lineWidth: version.isSelected ? 2 : 1)
                )
            }
            .buttonStyle(.plain)

            // Editable name
            if isEditing {
                HStack(spacing: 3) {
                    Text("take_\(version.takeIndex)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(providerColor)
                    TextField("name", text: $editText, onCommit: {
                        onRename(version, editText)
                        isEditing = false
                    })
                    .font(.system(size: 9))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(4)
                    .frame(maxWidth: 80)
                }
                .frame(width: 140)
            } else {
                HStack(spacing: 2) {
                    Text(version.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: 140, alignment: .center)
                .onTapGesture(count: 2) {
                    editText = version.userLabel
                    isEditing = true
                }
            }

            // Date + size
            VStack(spacing: 1) {
                Text(version.dateFormatted)
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.6))
                    .lineLimit(1)
                Text(version.fileSizeFormatted)
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .contextMenu {
            Button(action: { onSelect(version) }) {
                Label("Use This Take", systemImage: "checkmark.circle")
            }
            .disabled(version.isSelected)

            Button(action: {
                editText = version.userLabel
                isEditing = true
            }) {
                Label("Rename", systemImage: "pencil")
            }

            Button(action: { onShowInFinder(version) }) {
                Label("Show in Finder", systemImage: "folder")
            }

            Divider()

            Button(role: .destructive, action: { onDelete(version) }) {
                Label("Delete Take", systemImage: "trash")
            }
            .disabled(version.isSelected)
        }
    }
}

// MARK: - Video Thumbnail View

private struct VideoThumbnailView: View {
    let videoURL: URL
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(hex: "#1E1E1E"))
                    .overlay(
                        Image(systemName: "film")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.4))
                    )
            }
        }
        .onAppear { generateThumbnail() }
    }

    private func generateThumbnail() {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 260, height: 160)

        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, _, _ in
            guard let cgImage = cgImage else { return }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            DispatchQueue.main.async {
                self.thumbnail = nsImage
            }
        }
    }
}

// MARK: - Prompt Editor Sheet

private struct PromptEditorSheet: View {
    @Binding var prompt: String
    @Binding var useCustom: Bool
    let autoPrompt: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Video Prompt").font(.headline).foregroundColor(.white)
                Spacer()
                Button("Done") { isPresented = false }
            }
            HStack(spacing: 12) {
                Button(action: { useCustom = false; prompt = autoPrompt }) {
                    Text("Auto-Generated").font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(useCustom ? Color(hex: "#3A3A3A") : Color.accentColor)
                        .foregroundColor(useCustom ? .gray : .white).cornerRadius(6)
                }
                .buttonStyle(.plain)
                Button(action: { useCustom = true }) {
                    Text("Custom").font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(useCustom ? Color.accentColor : Color(hex: "#3A3A3A"))
                        .foregroundColor(useCustom ? .white : .gray).cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            TextEditor(text: $prompt).font(.system(size: 12)).scrollContentBackground(.hidden)
                .padding(10).background(Color(hex: "#1A1A1A")).cornerRadius(8)
                .frame(minHeight: 200).disabled(!useCustom).opacity(useCustom ? 1.0 : 0.7)
            if !useCustom {
                Text("Switch to Custom to edit the prompt directly").font(.system(size: 10)).foregroundColor(.gray)
            }
        }
        .padding(20).frame(width: 500, height: 400).background(Color(hex: "#252525"))
    }
}

// MARK: - Full Screen Video Sheet

private struct FullScreenVideoSheet: View {
    let videoURL: URL
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundColor(.gray)
                }
                .buttonStyle(.plain).padding()
            }
            if let player = player {
                NativeVideoPlayerView(player: player).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 500).background(Color.black)
        .onAppear { player = AVPlayer(url: videoURL); player?.play() }
        .onDisappear { player?.pause(); player = nil }
    }
}

// MARK: - Native Video Player (bypasses _AVKit_SwiftUI metadata crash on macOS 15)

private class NonInteractiveAVPlayerView: AVPlayerView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

private struct NativeVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NonInteractiveAVPlayerView {
        let view = NonInteractiveAVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ nsView: NonInteractiveAVPlayerView, context: Context) {
        nsView.player = player
    }
}
