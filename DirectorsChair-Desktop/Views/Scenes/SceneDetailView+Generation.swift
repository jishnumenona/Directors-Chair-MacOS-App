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
                guard await aiClient.testConnection() else {
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
                    provider: .googleImagen,
                    aspectRatio: "16:9",
                    numberOfImages: 1,
                    referenceImageBase64: ref?.base64,
                    referenceMimeType: ref?.mimeType
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
