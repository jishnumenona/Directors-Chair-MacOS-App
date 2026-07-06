//
// PhysicalAppearanceTab+Images.swift
//
// Extracted from PhysicalAppearanceTab.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit
import UniformTypeIdentifiers

extension PhysicalAppearanceTab {

    // MARK: - Delete Base Image

    func deleteBaseImage(at url: URL) {
        guard let basePath = projectBasePath else { return }

        do {
            _ = basePath.startAccessingSecurityScopedResource()
            defer { basePath.stopAccessingSecurityScopedResource() }
            try FileManager.default.removeItem(at: url)
        } catch {
            debugLog("Failed to delete base image: \(error)")
            return
        }

        character.baseImage = nil
        imageRefreshIds["base"] = UUID()

        discoveredImages = DiscoveredCharacterImages.discover(
            for: character.name,
            basePath: projectBasePath
        )
    }

    // MARK: - Annotation Editor

    func openAnnotationEditor(angle: String, label: String, imageType: ImageType) {
        guard let imagePath = effectiveImagePath(for: imageType),
              let basePath = projectBasePath else { return }
        let fullPath = basePath.appendingPathComponent(imagePath)
        guard let image = NSImage(contentsOf: fullPath) else { return }
        annotationEditorImage = image
        annotationEditorAngle = angle
        annotationEditorTitle = label
        annotationEditorImageType = imageType
        showingAnnotationEditor = true
    }

    func generateAngleWithAnnotations(angle: String, annotations: [KeyframeAnnotation]) {
        guard let imagePath = effectiveImagePath(for: annotationEditorImageType),
              let basePath = projectBasePath else { return }

        let fullPath = basePath.appendingPathComponent(imagePath)
        guard let imageData = try? Data(contentsOf: fullPath) else { return }

        // Build edit prompt (same pattern as shot annotation)
        var promptParts: [String] = []
        promptParts.append("Edit this image by making the following changes while keeping everything else identical:")
        for ann in annotations.sorted(by: { $0.number < $1.number }) {
            let xPercent = Int(ann.normalizedX * 100)
            let yPercent = Int(ann.normalizedY * 100)
            promptParts.append("\(ann.number). \(ann.text) at position (\(xPercent)%, \(yPercent)%)")
        }
        let editPrompt = promptParts.joined(separator: "\n")

        let referenceBase64 = imageData.base64EncodedString()
        let request = ImageGenerationRequest(
            prompt: editPrompt,
            provider: .googleImagen,
            aspectRatio: "1:1",
            referenceImageBase64: referenceBase64,
            referenceMimeType: "image/png"
        )

        // Show progress
        generatingProgress[angle] = 0.0

        Task {
            do {
                let response = try await AIServiceClient.shared.generateImage(request)

                guard let newImageData = response.images.first else {
                    await MainActor.run {
                        generatingProgress.removeValue(forKey: angle)
                    }
                    return
                }

                // Save edited image back to the same path
                _ = basePath.startAccessingSecurityScopedResource()
                defer { basePath.stopAccessingSecurityScopedResource() }
                try newImageData.write(to: fullPath)

                await MainActor.run {
                    imageRefreshIds[angle] = UUID()
                    if angle == "base" {
                        imageRefreshIds["base"] = UUID()
                    }
                    withAnimation(.easeOut(duration: 0.3)) {
                        generatingProgress.removeValue(forKey: angle)
                    }
                    discoveredImages = DiscoveredCharacterImages.discover(
                        for: character.name,
                        basePath: projectBasePath
                    )
                }
            } catch {
                await MainActor.run {
                    generatingProgress.removeValue(forKey: angle)
                }
                debugLog("Annotation edit failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Download Image

    func downloadImage(from url: URL, suggestedName: String) {
        guard let imageData = try? Data(contentsOf: url) else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = suggestedName
        savePanel.title = "Save Image"
        savePanel.message = "Choose a location to save the image"

        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                do {
                    try imageData.write(to: saveURL)
                } catch {
                    debugLog("Failed to save image: \(error)")
                }
            }
        }
    }

    var placeholderImage: some View {
        VStack {
            Image(systemName: "person.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No image")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Generate Angle Image (Background)

    func generateAngleImage(angle: String, prompt: String) {
        guard generatingProgress[angle] == nil else { return } // Already generating
        generatingProgress[angle] = 0.0

        onGenerateImage?(angle, prompt) { progress in
            if progress >= 1.0 {
                // Generation complete — bust cache and clear progress
                self.imageRefreshIds[angle] = UUID()
                // Also refresh base image display if it was the base
                if angle == "base" {
                    self.imageRefreshIds["base"] = UUID()
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    self.generatingProgress.removeValue(forKey: angle)
                }
                // Re-discover images from filesystem
                self.discoveredImages = DiscoveredCharacterImages.discover(
                    for: self.character.name,
                    basePath: self.projectBasePath
                )
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.generatingProgress[angle] = progress
                }
            }
        }
    }

    // MARK: - Angle Image Count

    var angleImageCount: Int {
        let angles: [ImageType] = [.front, .threeQuarterLeft, .threeQuarterRight, .profileLeft, .profileRight, .back]
        return angles.filter { effectiveImagePath(for: $0) != nil }.count
    }

    // MARK: - Build Image Prompt

    // Prompt construction lives in StoryDesignPromptBuilder (WS6.2).
    func buildAnglePrompt(angle: String) -> String {
        StoryDesignPromptBuilder.anglePrompt(base: buildImagePrompt(), angle: angle,
                                             hasBaseImage: effectiveImagePath(for: .base) != nil)
    }

    func buildImagePrompt() -> String {
        StoryDesignPromptBuilder.characterAppearancePrompt(character: character)
    }

    // MARK: - Reference Image Upload

    func browseForImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a reference image for \(character.name)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? Data(contentsOf: url) else { return }
        handleImageUpload(data: data)
    }

    func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        var imageData: Data?

        if let pngData = pasteboard.data(forType: .png) {
            imageData = pngData
        } else if let tiffData = pasteboard.data(forType: .tiff) {
            if let image = NSImage(data: tiffData), let tiffRep = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffRep),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                imageData = pngData
            }
        }

        guard let data = imageData else { return }
        handleImageUpload(data: data)
    }

    func handleImageUpload(data: Data) {
        guard let basePath = projectBasePath else { return }

        let sanitizedName = DiscoveredCharacterImages.sanitizedName(for: character.name)
        let imageDir = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("characters")
            .appendingPathComponent(sanitizedName)
            .appendingPathComponent("face")

        let imagePath = imageDir.appendingPathComponent("base.png")

        // Ensure PNG format
        let pngData: Data
        if let nsImage = NSImage(data: data), let tiffRep = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffRep),
           let converted = bitmap.representation(using: .png, properties: [:]) {
            pngData = converted
        } else {
            pngData = data
        }

        // Create directory and save
        do {
            _ = basePath.startAccessingSecurityScopedResource()
            defer { basePath.stopAccessingSecurityScopedResource() }

            try FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
            try pngData.write(to: imagePath)
        } catch {
            debugLog("Failed to save uploaded image: \(error)")
            return
        }

        // Update character base image path
        character.baseImage = "assets/characters/\(sanitizedName)/face/base.png"
        imageRefreshIds["base"] = UUID()

        // Re-discover filesystem images
        discoveredImages = DiscoveredCharacterImages.discover(
            for: character.name,
            basePath: projectBasePath
        )

        // Trigger AI analysis
        isAnalyzingUpload = true
        analysisProgress = 0
        onUploadReferenceImage?(pngData) { progress in
            self.analysisProgress = progress
            if progress >= 1.0 {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.isAnalyzingUpload = false
                }
            }
        }
    }
}
