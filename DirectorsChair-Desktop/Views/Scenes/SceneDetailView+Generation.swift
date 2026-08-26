//
// SceneDetailView+Generation.swift
//
// Extracted from SceneDetailView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairServices

extension SceneDetailView {

    // MARK: - Image Loading & Generation

    func loadHeroImage() {
        guard let basePath = projectBasePath,
              let imagePath = scene.sceneOverviewImage, !imagePath.isEmpty else { return }

        let fullPath = basePath.appendingPathComponent(imagePath)
        let cacheKey = fullPath.path

        if let cached = SceneImageCache.shared.image(forKey: cacheKey) {
            heroImage = cached
            return
        }

        Task.detached(priority: .utility) {
            guard let image = NSImage(contentsOf: fullPath) else { return }
            SceneImageCache.shared.setImage(image, forKey: cacheKey)
            await MainActor.run { heroImage = image }
        }
    }

    func generateOverviewImage(with customPrompt: String? = nil) {
        guard let basePath = projectBasePath else { return }
        isGeneratingImage = true

        let prompt = customPrompt ?? SceneCardHelpers.buildSceneOverviewPrompt(scene: scene)
        lastUsedPrompt = prompt

        Task {
            do {
                let aiClient = AIServiceClient.shared
                guard await aiClient.imageServiceReachable() else {
                    await MainActor.run { isGeneratingImage = false }
                    return
                }

                let ref = CharacterReferenceHelper.referenceImage(
                    forScene: scene,
                    characters: characters,
                    projectDirectory: basePath
                )

                let request = ImageGenerationRequest(
                    prompt: prompt,
                    provider: AIProviderSelection.shared.provider(for: .image),
                    aspectRatio: "16:9",
                    numberOfImages: 1,
                    referenceImageBase64: ref?.base64,
                    referenceMimeType: ref?.mimeType,
                    brief: VisualBrief(
                        purpose: .scene,
                        subject: customPrompt.map(StoryboardSubjects.plainSubject)
                            ?? StoryboardSubjects.subject(for: scene))
                )

                let response = try await aiClient.generateImage(request)
                guard let imageData = response.images.first else {
                    await MainActor.run { isGeneratingImage = false }
                    return
                }

                let sanitizedName = SceneCardHelpers.sanitizeFilename(scene.name)
                let sceneDir = basePath
                    .appendingPathComponent("assets")
                    .appendingPathComponent("scenes")
                    .appendingPathComponent(sanitizedName)

                if !FileManager.default.fileExists(atPath: sceneDir.path) {
                    try FileManager.default.createDirectory(at: sceneDir, withIntermediateDirectories: true)
                }

                // Save timestamped version
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let timestampedPath = sceneDir.appendingPathComponent("overview_\(timestamp).png")
                try imageData.write(to: timestampedPath)

                // Save as latest
                let latestPath = sceneDir.appendingPathComponent("overview_latest.png")
                if FileManager.default.fileExists(atPath: latestPath.path) {
                    try FileManager.default.removeItem(at: latestPath)
                }
                try imageData.write(to: latestPath)

                // Save prompt
                let promptPath = sceneDir.appendingPathComponent("prompt.txt")
                try prompt.write(to: promptPath, atomically: true, encoding: .utf8)
                let promptHistoryPath = sceneDir.appendingPathComponent("prompt_\(timestamp).txt")
                try prompt.write(to: promptHistoryPath, atomically: true, encoding: .utf8)

                let relativePath = "assets/scenes/\(sanitizedName)/overview_latest.png"

                await MainActor.run {
                    if let image = NSImage(data: imageData) {
                        heroImage = image
                        SceneImageCache.shared.setImage(image, forKey: latestPath.path)
                    }
                    onImageGenerated?(relativePath)
                    onPromptUsed?(prompt)
                    isGeneratingImage = false
                    discoverOverviewImages()
                }
            } catch {
                await MainActor.run { isGeneratingImage = false }
            }
        }
    }

    // MARK: - Generate With Annotations

    func generateOverviewWithAnnotations(_ annotations: [KeyframeAnnotation]) {
        let editPrompt = ImageAnnotationEditor.buildEditPrompt(from: annotations, context: "scene preview")
        let basePrompt = lastUsedPrompt.isEmpty ? SceneCardHelpers.buildSceneOverviewPrompt(scene: scene) : lastUsedPrompt
        let combinedPrompt = editPrompt + "\n\nOriginal prompt: " + basePrompt
        generateOverviewImage(with: combinedPrompt)
    }

    // MARK: - Download

    func downloadImage() {
        guard let image = heroImage else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        let sanitizedName = SceneCardHelpers.sanitizeFilename(scene.name)
        savePanel.nameFieldStringValue = "\(sanitizedName)_preview.png"
        savePanel.title = "Save Scene Preview"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }
}

// MARK: - On-device storyboard sketch (DC-0064)

extension SceneDetailView {

    /// A slim strip under the stats bar: the scene's ink-sketch frame,
    /// drawn locally by the Storyboard model. States explain themselves —
    /// undownloaded shows a pointer to Settings, never a dead button.
    var storyboardSection: some View {
        HStack(spacing: 12) {
            Group {
                if let sketch = storyboardSketch {
                    Image(nsImage: sketch)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Rectangle().fill(Color(nsColor: .quaternarySystemFill))
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 128, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text("Storyboard sketch")
                    .font(.system(size: 13, weight: .semibold))
                Text(storyboardEngineReady
                     ? "Ink-sketch frame drawn on this Mac — free, works offline"
                     : "Download the local image model in Settings → AI Services (\(ByteCountFormatter.string(fromByteCount: LocalImageEngine.model.approxBytes, countStyle: .file)), free)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                if let error = storyboardErrorText {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .accessibilityIdentifier("scene-storyboard-error")
                }
            }

            Spacer()

            if isSketchingStoryboard {
                ProgressView().controlSize(.small)
            }

            Button(scene.sceneStoryboardImage == nil ? "Sketch" : "Redraw") {
                sketchStoryboardFrame()
            }
            .disabled(!storyboardEngineReady || isSketchingStoryboard)
            .help(storyboardEngineReady
                  ? "Draw this scene as an ink-sketch storyboard frame on this Mac"
                  : "The Storyboard model isn't downloaded yet — Settings → AI Services")
            .accessibilityIdentifier("scene-storyboard-generate")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .task {
            storyboardEngineReady =
                await LocalImageEngine.shared.availability() == .ready
            loadStoryboardSketch()
        }
    }

    func loadStoryboardSketch() {
        guard let relative = scene.sceneStoryboardImage,
              let basePath = projectBasePath else { return }
        storyboardSketch = NSImage(contentsOf:
            basePath.appendingPathComponent(relative))
    }

    /// One frame through the on-device engine: subject from the scene's
    /// own fields, saved beside its other assets, relative path persisted
    /// through the same write-back the hero image uses.
    func sketchStoryboardFrame() {
        guard !isSketchingStoryboard, let basePath = projectBasePath else { return }
        isSketchingStoryboard = true
        storyboardErrorText = nil
        Task {
            do {
                let spec = StoryboardFrameSpec(
                    subject: StoryboardSubjects.subject(for: scene),
                    purpose: .scene)
                let png = try await LocalImageEngine.shared.generateFrame(spec)
                let directory = "assets/scenes/\(SceneCardHelpers.sanitizeFilename(scene.name))"
                let saved = try StoryboardFrameStore.save(
                    png: png, projectBasePath: basePath,
                    relativeDirectory: directory)
                await MainActor.run {
                    storyboardSketch = NSImage(data: png)
                    onStoryboardGenerated?(saved.relativePath)
                    isSketchingStoryboard = false
                }
            } catch let error as StoryboardEngineError {
                await MainActor.run {
                    storyboardErrorText = error.userMessage
                    isSketchingStoryboard = false
                }
            } catch {
                await MainActor.run {
                    storyboardErrorText = error.localizedDescription
                    isSketchingStoryboard = false
                }
            }
        }
    }
}
