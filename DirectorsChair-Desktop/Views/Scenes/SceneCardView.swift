//
//  SceneCardView.swift
//  DirectorsChair-Desktop
//
//  Rich scene card for the grid overview with image generation controls
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairServices

struct SceneCardView: View {
    let scene: DirectorsChairCore.Scene
    let characters: [Character]
    let projectBasePath: URL?
    var onImageGenerated: ((String) -> Void)? = nil
    var onPromptUsed: ((String) -> Void)? = nil

    @State private var isHovering = false
    @State private var isHoveringImage = false
    @State private var overviewImage: NSImage?
    @State private var isGenerating = false
    @State private var showingFullSize = false
    @State private var showingPromptEditor = false
    @State private var editablePrompt = ""
    @State private var lastUsedPrompt = ""

    private var parsed: (prefix: String?, location: String, time: String?) {
        SceneCardHelpers.parseSceneLocation(scene.location)
    }

    private var characterNames: [String] {
        SceneCardHelpers.sceneCharacters(scene: scene)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroImage
            VStack(alignment: .leading, spacing: 10) {
                headingRow
                summaryText
                if !characterNames.isEmpty { characterAvatarsRow }
                contentCountsRow
                if let topEmotion = topEmotion { emotionTag(topEmotion) }
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(isHovering ? 0.2 : 0.1), radius: isHovering ? 8 : 4, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        .onAppear {
            loadOverviewImage()
            lastUsedPrompt = scene.sceneOverviewPrompt ?? ""
        }
        .onChange(of: scene.id) { _ in
            overviewImage = nil
            isGenerating = false
            loadOverviewImage()
            lastUsedPrompt = scene.sceneOverviewPrompt ?? ""
        }
        .sheet(isPresented: $showingFullSize) {
            ScenePreviewFullSizeSheet(
                image: overviewImage,
                sceneName: scene.name,
                isPresented: $showingFullSize,
                onDownload: { downloadImage() }
            )
        }
        .sheet(isPresented: $showingPromptEditor) {
            ScenePromptEditorSheet(
                prompt: $editablePrompt,
                isPresented: $showingPromptEditor,
                onGenerate: { prompt in
                    generateOverviewImage(with: prompt)
                }
            )
        }
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        ZStack {
            if isGenerating {
                Color(nsColor: .controlBackgroundColor)
                    .frame(height: 140)
                    .overlay(
                        VStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("Generating...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    )
            } else if let image = overviewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipped()
                    .overlay {
                        if isHoveringImage {
                            Color.black.opacity(0.35)
                                .overlay(alignment: .topTrailing) {
                                    imageControlButtons
                                        .padding(8)
                                }
                        }
                    }
            } else {
                // Placeholder with generate button
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor),
                        Color.accentColor.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 140)
                .overlay(
                    Group {
                        if isHoveringImage {
                            Button { generateOverviewImage() } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 22))
                                    Text("Generate Preview")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Image(systemName: "film")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                    }
                )
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHoveringImage = hovering }
        }
    }

    // MARK: - Image Control Buttons

    private var imageControlButtons: some View {
        HStack(spacing: 6) {
            imageControlButton(icon: "arrow.up.left.and.arrow.down.right", help: "View full size") {
                showingFullSize = true
            }
            imageControlButton(icon: "text.badge.plus", help: "Edit prompt") {
                editablePrompt = lastUsedPrompt.isEmpty ? SceneCardHelpers.buildSceneOverviewPrompt(scene: scene) : lastUsedPrompt
                showingPromptEditor = true
            }
            imageControlButton(icon: "arrow.down.circle", help: "Download image") {
                downloadImage()
            }
            imageControlButton(icon: "photo.badge.plus", help: "Upload custom image") {
                uploadOverviewImage()
            }
            imageControlButton(icon: "arrow.clockwise", help: "Regenerate") {
                generateOverviewImage()
            }
        }
    }

    private func imageControlButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Heading Row

    private var headingRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(SceneCardHelpers.sceneNumber(scene.name))
                    .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                HStack(spacing: 4) {
                    if let prefix = parsed.prefix {
                        Text(prefix).font(.caption2).fontWeight(.bold).foregroundColor(.orange)
                    }
                    Text(parsed.location).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    if let time = parsed.time {
                        Text("· \(time)").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        let color = SceneCardHelpers.productionStatusColor(scene.productionStatus)
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(scene.productionStatus).font(.caption2).fontWeight(.medium)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.12)).cornerRadius(6)
    }

    // MARK: - Summary

    private var summaryText: some View {
        Group {
            if let summary = scene.sceneOverviewSummary, !summary.isEmpty {
                Text(summary).font(.caption).foregroundColor(.secondary).lineLimit(2)
            } else if !scene.description.isEmpty {
                Text(scene.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
        }
    }

    // MARK: - Character Avatars

    private var characterAvatarsRow: some View {
        HStack(spacing: -6) {
            ForEach(Array(characterNames.prefix(4).enumerated()), id: \.offset) { index, name in
                let character = characters.first { $0.name == name }
                CharacterAvatarView(
                    character: character, characterName: name,
                    size: 24, projectBasePath: projectBasePath
                )
                .overlay(Circle().stroke(Color(nsColor: .controlBackgroundColor), lineWidth: 2))
                .zIndex(Double(4 - index))
            }
            if characterNames.count > 4 {
                Text("+\(characterNames.count - 4)")
                    .font(.caption2).fontWeight(.medium).foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
        }
    }

    // MARK: - Content Counts

    private var contentCountsRow: some View {
        let counts = SceneCardHelpers.contentCounts(scene: scene)
        return HStack(spacing: 12) {
            ForEach(Array(counts.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 3) {
                    Image(systemName: item.icon).font(.caption2)
                    Text("\(item.count)").font(.caption2).fontWeight(.medium)
                }
                .foregroundColor(.secondary).help(item.label)
            }
        }
    }

    // MARK: - Emotion Tag

    private var topEmotion: (name: String, value: Double)? {
        guard let analysis = scene.sceneEmotionalAnalysis, !analysis.isEmpty else { return nil }
        return analysis.max(by: { $0.value < $1.value }).map { ($0.key, $0.value) }
    }

    private func emotionTag(_ emotion: (name: String, value: Double)) -> some View {
        let color = SceneCardHelpers.emotionColor(emotion.name)
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(emotion.name.capitalized).font(.caption2).fontWeight(.medium)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.12)).cornerRadius(6)
    }

    // MARK: - Image Loading

    private func loadOverviewImage() {
        guard let basePath = projectBasePath,
              let imagePath = scene.sceneOverviewImage, !imagePath.isEmpty else { return }

        let fullPath = basePath.appendingPathComponent(imagePath)
        let cacheKey = fullPath.path

        if let cached = SceneImageCache.shared.image(forKey: cacheKey) {
            overviewImage = cached
            return
        }

        Task.detached(priority: .utility) {
            guard let image = NSImage(contentsOf: fullPath) else { return }
            SceneImageCache.shared.setImage(image, forKey: cacheKey)
            await MainActor.run { overviewImage = image }
        }
    }

    // MARK: - Image Generation

    private func generateOverviewImage(with customPrompt: String? = nil) {
        guard let basePath = projectBasePath else { return }
        isGenerating = true

        let prompt = customPrompt ?? SceneCardHelpers.buildSceneOverviewPrompt(scene: scene)
        lastUsedPrompt = prompt

        Task {
            do {
                let aiClient = AIServiceClient.shared
                guard await aiClient.testConnection() else {
                    await MainActor.run { isGenerating = false }
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
                    await MainActor.run { isGenerating = false }
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
                        overviewImage = image
                        SceneImageCache.shared.setImage(image, forKey: latestPath.path)
                    }
                    onImageGenerated?(relativePath)
                    onPromptUsed?(prompt)
                    isGenerating = false
                }
            } catch {
                await MainActor.run { isGenerating = false }
            }
        }
    }

    // MARK: - Custom upload

    private func uploadOverviewImage() {
        guard let basePath = projectBasePath,
              let data = UploadedImage.pickData(message: "Choose an image for \(scene.name)"),
              let png = UploadedImage.normalizedPNG(from: data) else { return }
        do {
            let sanitizedName = SceneCardHelpers.sanitizeFilename(scene.name)
            let sceneDir = "assets/scenes/\(sanitizedName)"
            // Same history convention as generation: timestamped copy + latest.
            try UploadedImage.writePNG(png, projectBasePath: basePath,
                                       relativeDirectory: sceneDir,
                                       filename: "overview_\(UploadedImage.historyTimestamp()).png")
            let relativePath = try UploadedImage.writePNG(png, projectBasePath: basePath,
                                                          relativeDirectory: sceneDir,
                                                          filename: "overview_latest.png")
            if let image = NSImage(data: png) {
                overviewImage = image
                SceneImageCache.shared.setImage(image, forKey: basePath.appendingPathComponent(relativePath).path)
            }
            onImageGenerated?(relativePath)
        } catch {
            debugLog("SceneCardView: custom image upload failed: \(error)")
        }
    }

    // MARK: - Download

    private func downloadImage() {
        guard let image = overviewImage else { return }

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

// MARK: - Full Size Preview Sheet

struct ScenePreviewFullSizeSheet: View {
    let image: NSImage?
    let sceneName: String
    @Binding var isPresented: Bool
    let onDownload: () -> Void

    private var imageSize: CGSize {
        guard let image = image else { return CGSize(width: 900, height: 506) }
        return image.size
    }

    private var sheetSize: (width: CGFloat, height: CGFloat) {
        let chromeHeight: CGFloat = 100 // header + footer + dividers
        let aspectRatio = imageSize.width / max(imageSize.height, 1)
        let displayWidth = min(imageSize.width, 1200)
        let displayHeight = displayWidth / aspectRatio
        return (displayWidth, displayHeight + chromeHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(sceneName) Preview")
                    .font(.headline)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

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
                        .foregroundColor(.secondary)
                    Text("No preview available")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }

            Divider()

            HStack {
                if let image = image {
                    Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onDownload) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        Text("Download")
                    }
                }
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: sheetSize.width, height: sheetSize.height)
    }
}

// MARK: - Prompt Editor Sheet

struct ScenePromptEditorSheet: View {
    @Binding var prompt: String
    @Binding var isPresented: Bool
    let onGenerate: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scene Preview Prompt")
                    .font(.headline)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Edit the prompt below to customize the generated image:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                TextEditor(text: $prompt)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .frame(minHeight: 200)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tips:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Group {
                        Label("Describe the location, lighting, and mood of the scene", systemImage: "lightbulb")
                        Label("Include character descriptions for better results", systemImage: "person")
                        Label("Add style keywords like 'cinematic', 'film noir', '35mm'", systemImage: "film")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.top, 4)
            }
            .padding()

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    isPresented = false
                    onGenerate(prompt)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Generate with Prompt")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 600, height: 480)
    }
}
