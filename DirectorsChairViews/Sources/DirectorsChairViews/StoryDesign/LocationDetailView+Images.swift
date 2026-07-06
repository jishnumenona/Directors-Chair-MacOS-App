//
// LocationDetailView+Images.swift
//
// Extracted from LocationDetailView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import AppKit

extension LocationDetailView {

    // MARK: - Placeholder

    var locationPlaceholder: some View {
        VStack {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No image")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Generate Variation Image

    func generateVariationImage(variation: String, prompt: String) {
        guard generatingProgress[variation] == nil else { return }
        generatingProgress[variation] = 0.0

        onGenerateImage?(variation, prompt) { progress in
            if progress >= 1.0 {
                self.imageRefreshIds[variation] = UUID()
                if variation == "primary" {
                    self.imageRefreshIds["primary"] = UUID()
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    self.generatingProgress.removeValue(forKey: variation)
                }
                self.discoveredImages = DiscoveredLocationImages.discover(
                    for: self.location.name,
                    basePath: self.projectBasePath
                )
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.generatingProgress[variation] = progress
                }
            }
        }
    }

    // MARK: - Variation Image Count

    var variationImageCount: Int {
        let variations = ["day", "night", "golden_hour", "overcast", "wide", "detail"]
        return variations.filter { effectiveImagePath(for: $0) != nil }.count
    }

    // MARK: - Build Prompts

    // Prompt construction lives in StoryDesignPromptBuilder (WS6.2).
    func buildLocationPrompt() -> String {
        StoryDesignPromptBuilder.locationPrompt(location: location)
    }

    func buildVariationPrompt(override: String) -> String {
        StoryDesignPromptBuilder.locationVariationPrompt(location: location, override: override,
                                                         hasPrimaryImage: effectiveImagePath(for: "primary") != nil)
    }

    // MARK: - Variation Thumbnail Builder

    func variationThumbnail(_ variation: String, label: String) -> some View {
        let override = variationDefaultOverride(variation)
        return LocationVariationThumbnail(
            label: label,
            imagePath: effectiveImagePath(for: variation),
            projectBasePath: projectBasePath,
            isSelected: selectedPreviewVariation == variation,
            generationProgress: generatingProgress[variation],
            refreshId: imageRefreshIds[variation],
            onSelect: { withAnimation(.easeInOut(duration: 0.2)) { selectedPreviewVariation = variation } },
            onView: { url in
                fullScreenImageURL = url
                fullScreenImageTitle = "\(location.name) - \(label)"
                showingFullScreenImage = true
            },
            onDownload: { url in downloadImage(from: url, suggestedName: "\(location.name)_\(variation).png") },
            onGenerate: {
                generateVariationImage(variation: variation, prompt: buildVariationPrompt(override: override))
            },
            onEditGenerate: {
                if effectiveImagePath(for: variation) != nil {
                    openAnnotationEditor(variation: variation, label: label)
                } else {
                    openPromptEditor(variation: variation, defaultPrompt: buildVariationPrompt(override: override))
                }
            }
        )
    }

    // MARK: - Open Prompt Editor

    func openPromptEditor(variation: String, defaultPrompt: String) {
        promptEditorVariation = variation
        promptEditorText = defaultPrompt
        showingPromptEditor = true
    }

    func openAnnotationEditor(variation: String, label: String) {
        guard let imagePath = effectiveImagePath(for: variation),
              let basePath = projectBasePath else { return }
        let fullPath = basePath.appendingPathComponent(imagePath)
        guard let image = NSImage(contentsOf: fullPath) else { return }
        annotationEditorImage = image
        annotationEditorVariation = variation
        annotationEditorTitle = label
        showingAnnotationEditor = true
    }

    func generateVariationWithAnnotations(variation: String, annotations: [KeyframeAnnotation]) {
        let editPrompt = ImageAnnotationEditor.buildEditPrompt(from: annotations, context: "location \(variation) image")
        let override = variationDefaultOverride(variation)
        let basePrompt = buildVariationPrompt(override: override)
        let combinedPrompt = editPrompt + "\n\nOriginal prompt: " + basePrompt
        generateVariationImage(variation: variation, prompt: combinedPrompt)
    }

    func variationDefaultOverride(_ variation: String) -> String {
        switch variation {
        case "day": return "bright daylight, clear sky, midday sun"
        case "night": return "nighttime, moonlit, artificial lighting, dark shadows"
        case "golden_hour": return "golden hour, warm sunset, long shadows, amber tones"
        case "overcast": return "overcast sky, diffused light, muted colors, fog or rain"
        case "wide": return "wide establishing shot, full environment, 14mm ultra-wide"
        case "detail": return "extreme close-up, texture and material focus, 100mm macro"
        default: return ""
        }
    }

    // MARK: - Variation Display Name

    func variationDisplayName(_ variation: String) -> String {
        switch variation {
        case "primary": return "Primary"
        case "day": return "Day"
        case "night": return "Night"
        case "golden_hour": return "Golden Hour"
        case "overcast": return "Overcast"
        case "wide": return "Wide Shot"
        case "detail": return "Detail"
        default: return variation.capitalized
        }
    }

    // MARK: - Download Image

    func downloadImage(from url: URL, suggestedName: String) {
        guard let imageData = try? Data(contentsOf: url) else { return }

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

    // MARK: - Bindings

    func styleBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { location.styleAttributes[key] ?? "" },
            set: { location.styleAttributes[key] = $0.isEmpty ? nil : $0 }
        )
    }

    var parentLocationBinding: Binding<String> {
        Binding(
            get: { location.parentLocation ?? "" },
            set: { location.parentLocation = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - Scene Data

    var scenesAtLocation: [String] {
        var names: [String] = []
        for sequence in project.sequences {
            for scene in sequence.scenes {
                let sceneLocation = (scene.location ?? "").uppercased()
                if sceneLocation.contains(location.name.uppercased()) {
                    names.append(scene.name)
                }
            }
        }
        return names
    }

    var scenesAtLocationDetailed: [LocationSceneInfo] {
        var scenes: [LocationSceneInfo] = []
        for sequence in project.sequences {
            for scene in sequence.scenes {
                let sceneLocation = (scene.location ?? "").uppercased()
                if sceneLocation.contains(location.name.uppercased()) {
                    let dialogues = scene.dialogues
                    let actions = scene.actions

                    let sampleDialogues = dialogues.prefix(2).map { d in
                        LocationDialogueSample(character: d.character, text: d.text)
                    }
                    let sampleActions = actions.prefix(1).map { $0.description }

                    scenes.append(LocationSceneInfo(
                        sceneName: scene.name,
                        dialogueCount: dialogues.count,
                        actionCount: actions.count,
                        sampleDialogues: Array(sampleDialogues),
                        sampleActions: Array(sampleActions)
                    ))
                }
            }
        }
        return scenes
    }
}
