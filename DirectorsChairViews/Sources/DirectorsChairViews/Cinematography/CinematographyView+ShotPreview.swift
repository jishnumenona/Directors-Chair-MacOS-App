//
// CinematographyView+ShotPreview.swift
//
// Extracted from CinematographyView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were file-private helpers, now module-internal.
//

import SwiftUI
import AVFoundation
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Shot Preview Section

struct ShotPreviewSection: View {
    let shot: Shot
    let scene: DCScene?
    let characters: [Character]
    let locations: [Location]
    let projectBasePath: URL?
    let onPreviewGenerated: (String) -> Void

    @State private var isGenerating = false
    @State private var previewImage: NSImage?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingPromptEditor = false
    @State private var showingFullSizePreview = false
    @State private var showingAnnotationEditor = false
    @State private var editablePrompt: String = ""
    @State private var lastUsedPrompt: String = ""
    @State private var allPreviewImages: [URL] = []
    @State private var currentImageIndex: Int = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Preview container
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#1A1A1A"))

                if let image = previewImage {
                    // Display preview image
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: 420)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if isGenerating {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text("Generating shot preview...")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)

                        Text(buildPromptSummary())
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)
                } else {
                    // Empty state with generate button
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#2A2A2A"))
                                .frame(width: 72, height: 72)

                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 28))
                                .foregroundColor(.gray)
                        }

                        VStack(spacing: 6) {
                            Text("Shot Preview")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))

                            Text("Generate a preview based on shot settings")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        HStack(spacing: 12) {
                            Button(action: { openPromptEditor() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "text.badge.plus")
                                        .font(.system(size: 12))
                                    Text("Edit Prompt")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#3A3A3A"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button(action: { generateWithDefaultPrompt() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 12))
                                    Text("Generate")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)
                }

                // Overlay buttons (when image exists)
                if previewImage != nil {
                    VStack {
                        HStack {
                            Spacer()
                            if !isGenerating {
                                // View full size button
                                Button(action: { showingFullSizePreview = true }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("View full size")

                                // Annotate & edit button
                                Button(action: { showingAnnotationEditor = true }) {
                                    Image(systemName: "pencil.and.outline")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Annotate & edit image")

                                // Edit prompt button
                                Button(action: { openPromptEditor() }) {
                                    Image(systemName: "text.badge.plus")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Edit prompt")

                                // Download button
                                Button(action: { downloadPreviewImage() }) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Download image")
                            }

                            // Regenerate button (shows spinner when generating)
                            Button(action: { generateWithDefaultPrompt() }) {
                                ZStack {
                                    if isGenerating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 27, height: 27)
                                .background(isGenerating ? Color.accentColor.opacity(0.8) : Color.black.opacity(0.6))
                                .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isGenerating)
                            .help(isGenerating ? "Generating..." : "Regenerate preview")
                        }
                        .padding(12)
                        Spacer()
                    }
                }

                // Image history navigation
                if allPreviewImages.count > 1 {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Button {
                                if currentImageIndex > 0 {
                                    currentImageIndex -= 1
                                    loadPreviewImageAtIndex(currentImageIndex)
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(currentImageIndex > 0 ? .white : .white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                            .disabled(currentImageIndex <= 0)

                            Text("\(currentImageIndex + 1) / \(allPreviewImages.count)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)

                            Button {
                                if currentImageIndex < allPreviewImages.count - 1 {
                                    currentImageIndex += 1
                                    loadPreviewImageAtIndex(currentImageIndex)
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(currentImageIndex < allPreviewImages.count - 1 ? .white : .white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                            .disabled(currentImageIndex >= allPreviewImages.count - 1)

                            if currentImageIndex == allPreviewImages.count - 1 {
                                let isFromTake = allPreviewImages[currentImageIndex].lastPathComponent == "preview_take.png"
                                Text(isFromTake ? "Take" : "Latest")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isFromTake ? Color.green.opacity(0.7) : Color.accentColor.opacity(0.7))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .padding(.bottom, 10)
                    }
                }
            }
            .frame(height: 420)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
            )

            // Shot info pills and prompt info
            HStack(spacing: 8) {
                ShotInfoPill(icon: "camera.viewfinder", text: shot.cameraAngle)
                ShotInfoPill(icon: "circle.dotted", text: shot.lensMm != nil ? "\(shot.lensMm!)mm" : "—")
                ShotInfoPill(icon: "rectangle.expand.vertical", text: shot.shotType)
                ShotInfoPill(icon: "arrow.left.and.right", text: shot.movement)

                Spacer()

                // Show prompt button if we have a last used prompt
                if !lastUsedPrompt.isEmpty {
                    Button(action: { openPromptEditor() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 9))
                            Text("View Prompt")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.accentColor.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("View or edit the prompt used for this preview")
                }

                if scene != nil {
                    Text("Scene: \(scene!.name)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
        }
        .onAppear {
            loadExistingPreview()
            loadSavedPrompt()
            generateTakePreviewIfNeeded()
            discoverPreviewImages()
        }
        .onChange(of: shot.previewImage) { _, newPath in
            if let path = newPath {
                loadPreviewImage(from: path)
            }
        }
        .alert("Preview Generation Failed", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $showingPromptEditor) {
            PromptEditorSheet(
                prompt: $editablePrompt,
                isPresented: $showingPromptEditor,
                onGenerate: { customPrompt in
                    generatePreview(with: customPrompt)
                }
            )
        }
        .sheet(isPresented: $showingFullSizePreview) {
            ShotPreviewFullSizeSheet(
                image: previewImage,
                shotId: shot.shotId,
                isPresented: $showingFullSizePreview,
                onDownload: { downloadPreviewImage() }
            )
        }
        .sheet(isPresented: $showingAnnotationEditor) {
            if let image = previewImage {
                ImageAnnotationEditor(
                    image: image,
                    title: "EDIT SHOT PREVIEW",
                    subtitle: "Shot \(shot.shotId) — \(shot.shotType) \(shot.cameraAngle)",
                    isPresented: $showingAnnotationEditor,
                    onApplyEdits: { annotations in
                        generatePreviewWithAnnotations(annotations)
                    }
                )
            }
        }
    }

    // MARK: - Prompt Editor

    private func openPromptEditor() {
        editablePrompt = lastUsedPrompt.isEmpty ? buildPrompt() : lastUsedPrompt
        showingPromptEditor = true
    }

    private func generateWithDefaultPrompt() {
        let prompt = buildPrompt()
        generatePreview(with: prompt)
    }

    // MARK: - Download Preview Image

    private func downloadPreviewImage() {
        guard let image = previewImage else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "shot_\(shot.shotId)_preview.png"
        savePanel.title = "Save Shot Preview"
        savePanel.message = "Choose a location to save the preview image"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                // Determine format based on extension
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
                        do {
                            try data.write(to: url)
                        } catch {
                            debugLog("Error saving image: \(error)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Load Existing Preview

    private func loadExistingPreview() {
        guard let imagePath = shot.previewImage,
              let basePath = projectBasePath else { return }

        let fullPath = basePath.deletingLastPathComponent().appendingPathComponent(imagePath)
        if let image = NSImage(contentsOf: fullPath) {
            previewImage = image
        }
    }

    private func loadPreviewImage(from relativePath: String) {
        guard let basePath = projectBasePath else { return }
        let fullPath = basePath.deletingLastPathComponent().appendingPathComponent(relativePath)
        if let image = NSImage(contentsOf: fullPath) {
            previewImage = image
        }
    }

    private func loadSavedPrompt() {
        guard let basePath = projectBasePath else { return }
        let projectDir = basePath.deletingLastPathComponent()
        let shotDir = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("shots")
            .appendingPathComponent("shot_\(shot.shotId)")
        let promptFile = shotDir.appendingPathComponent("prompt.txt")

        if let savedPrompt = try? String(contentsOf: promptFile, encoding: .utf8) {
            lastUsedPrompt = savedPrompt
        }
    }

    // MARK: - Take Preview Generation

    /// Generates `preview_take.png` as a collage: AI-generated preview (left) + take frame (right).
    /// If no AI preview exists, saves just the take frame. Runs on appear if file doesn't exist yet.
    private func generateTakePreviewIfNeeded() {
        // Only generate collage for post-shooting statuses (Review, Approved, etc.)
        let preShootingStatuses = ["Planning", "Ready", "Shooting"]
        guard !preShootingStatuses.contains(shot.status) else { return }
        guard let basePath = projectBasePath else { return }
        let projectDir = basePath.deletingLastPathComponent()
        let shotDir = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("shots")
            .appendingPathComponent("shot_\(shot.shotId)")
        let takePreviewURL = shotDir.appendingPathComponent("preview_take.png")

        // Skip if already exists
        if FileManager.default.fileExists(atPath: takePreviewURL.path) { return }

        // Prefer a circled take with video; fall back to latest take with video
        let selectedTake = shot.circledTakes.first(where: { $0.capturedVideoPath != nil })
            ?? shot.takes.last(where: { $0.capturedVideoPath != nil })
        guard let selectedTake, let videoRelPath = selectedTake.capturedVideoPath else { return }

        let videoURL = projectDir.appendingPathComponent(videoRelPath)
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return }

        // Find latest AI-generated preview (exclude preview_take.png itself)
        let aiPreviewImage: CGImage? = {
            guard FileManager.default.fileExists(atPath: shotDir.path),
                  let contents = try? FileManager.default.contentsOfDirectory(at: shotDir, includingPropertiesForKeys: nil) else { return nil }
            let aiPreviews = contents
                .filter { $0.pathExtension.lowercased() == "png" }
                .filter { $0.lastPathComponent.hasPrefix("preview_") && $0.lastPathComponent != "preview_take.png" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard let latestAI = aiPreviews.last,
                  let nsImage = NSImage(contentsOf: latestAI),
                  let cgImg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            return cgImg
        }()

        Task {
            let asset = AVAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1280, height: 720)

            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            let targetSeconds = max(0, durationSeconds - 2.0)
            let time = CMTime(seconds: targetSeconds, preferredTimescale: 600)

            guard let takeFrame = try? await generator.image(at: time).image else { return }

            let collageData: Data?
            if let aiImage = aiPreviewImage {
                collageData = Self.createCollage(leftImage: aiImage, leftLabel: "AI PREVIEW", rightImage: takeFrame, rightLabel: "TAKE")
            } else {
                // No AI preview — just save the take frame at full resolution
                let bitmapRep = NSBitmapImageRep(cgImage: takeFrame)
                collageData = bitmapRep.representation(using: .png, properties: [:])
            }

            guard let pngData = collageData else { return }

            try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
            try? pngData.write(to: takePreviewURL)

            await MainActor.run {
                discoverPreviewImages()
                if let image = NSImage(contentsOf: takePreviewURL) {
                    previewImage = image
                }
            }
        }
    }

    /// Creates a side-by-side collage at 1920x540 with labeled panels and a dark gap.
    private static func createCollage(leftImage: CGImage, leftLabel: String, rightImage: CGImage, rightLabel: String) -> Data? {
        let canvasWidth: CGFloat = 1920
        let canvasHeight: CGFloat = 540
        let gap: CGFloat = 4
        let panelWidth = (canvasWidth - gap) / 2
        let labelHeight: CGFloat = 28
        let labelFontSize: CGFloat = 13

        guard let ctx = CGContext(
            data: nil,
            width: Int(canvasWidth),
            height: Int(canvasHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Fill background black
        ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

        // Draw each panel fitted within its half
        func drawPanel(image: CGImage, label: String, originX: CGFloat) {
            let imgW = CGFloat(image.width)
            let imgH = CGFloat(image.height)
            let availableHeight = canvasHeight - labelHeight
            let scale = min(panelWidth / imgW, availableHeight / imgH)
            let drawW = imgW * scale
            let drawH = imgH * scale
            let x = originX + (panelWidth - drawW) / 2
            let y = labelHeight + (availableHeight - drawH) / 2
            ctx.draw(image, in: CGRect(x: x, y: y, width: drawW, height: drawH))

            // Draw label background
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
            ctx.fill(CGRect(x: originX, y: 0, width: panelWidth, height: labelHeight))

            // Draw label text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: labelFontSize, weight: .semibold),
                .foregroundColor: NSColor.white,
                .kern: 1.5
            ]
            let attrString = NSAttributedString(string: label, attributes: attributes)
            let textSize = attrString.size()
            let textX = originX + (panelWidth - textSize.width) / 2
            let textY = (labelHeight - textSize.height) / 2

            // Use NSGraphicsContext to draw text into the CGContext
            NSGraphicsContext.saveGraphicsState()
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.current = nsCtx
            attrString.draw(at: NSPoint(x: textX, y: textY))
            NSGraphicsContext.restoreGraphicsState()
        }

        drawPanel(image: leftImage, label: leftLabel, originX: 0)
        drawPanel(image: rightImage, label: rightLabel, originX: panelWidth + gap)

        guard let compositeImage = ctx.makeImage() else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: compositeImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }

    // MARK: - Image History

    private func discoverPreviewImages() {
        guard let basePath = projectBasePath else { return }
        let projectDir = basePath.deletingLastPathComponent()
        let shotDir = projectDir
            .appendingPathComponent("assets")
            .appendingPathComponent("shots")
            .appendingPathComponent("shot_\(shot.shotId)")

        guard FileManager.default.fileExists(atPath: shotDir.path) else { return }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: shotDir, includingPropertiesForKeys: nil)
            let images = contents
                .filter { $0.pathExtension.lowercased() == "png" }
                .filter { $0.lastPathComponent.hasPrefix("preview_") }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            allPreviewImages = images
            if !images.isEmpty {
                currentImageIndex = images.count - 1
            }
        } catch {
            // Directory doesn't exist or can't be read
        }
    }

    private func loadPreviewImageAtIndex(_ index: Int) {
        guard index >= 0, index < allPreviewImages.count else { return }
        let url = allPreviewImages[index]
        if let image = NSImage(contentsOf: url) {
            previewImage = image
        }
    }

    // MARK: - Generate Preview

    private func generatePreview(with prompt: String) {
        isGenerating = true
        errorMessage = nil
        lastUsedPrompt = prompt

        Task {
            do {
                let aiClient = AIServiceClient.shared

                guard await aiClient.testConnection() else {
                    await MainActor.run {
                        errorMessage = "Could not connect to AI server. Please ensure the AI Proxy server is running."
                        showingError = true
                        isGenerating = false
                    }
                    return
                }

                // Collect all reference images (location, characters, costumes)
                var refs: [ReferenceImage] = []
                if let scene = scene, let projDir = projectBasePath?.deletingLastPathComponent() {
                    refs = CharacterReferenceHelper.collectReferenceImages(
                        forScene: scene,
                        characters: characters,
                        locations: locations,
                        projectDirectory: projDir
                    )
                }

                // Prepend reference image instructions to the prompt
                let fullPrompt: String
                if !refs.isEmpty {
                    let prefix = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: refs)
                    fullPrompt = prefix + prompt
                } else {
                    fullPrompt = prompt
                }

                let request = ImageGenerationRequest(
                    prompt: fullPrompt,
                    provider: .googleImagen,
                    aspectRatio: "16:9",
                    numberOfImages: 1,
                    referenceImages: refs.isEmpty ? nil : refs
                )

                let response = try await aiClient.generateImage(request)

                guard let imageData = response.images.first else {
                    throw AIClientError.invalidResponse("No image generated")
                }

                // Save to project directory with proper structure
                guard let basePath = projectBasePath else {
                    throw AIClientError.invalidResponse("No project path")
                }

                let projectDir = basePath.deletingLastPathComponent()

                // Create shot-specific directory: assets/shots/shot_{id}/
                let shotDir = projectDir
                    .appendingPathComponent("assets")
                    .appendingPathComponent("shots")
                    .appendingPathComponent("shot_\(shot.shotId)")

                if !FileManager.default.fileExists(atPath: shotDir.path) {
                    try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
                }

                // Generate timestamped filename
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let imageFilename = "preview_\(timestamp).png"
                let promptFilename = "prompt.txt"

                // Save the image
                let imagePath = shotDir.appendingPathComponent(imageFilename)
                try imageData.write(to: imagePath)

                // Save the prompt
                let promptPath = shotDir.appendingPathComponent(promptFilename)
                try prompt.write(to: promptPath, atomically: true, encoding: .utf8)

                // Also save prompt history
                let historyFilename = "prompt_\(timestamp).txt"
                let historyPath = shotDir.appendingPathComponent(historyFilename)
                try prompt.write(to: historyPath, atomically: true, encoding: .utf8)

                // Update the "current" symlink/reference (save as latest.png too)
                let latestPath = shotDir.appendingPathComponent("latest.png")
                if FileManager.default.fileExists(atPath: latestPath.path) {
                    try FileManager.default.removeItem(at: latestPath)
                }
                try imageData.write(to: latestPath)

                let relativePath = "assets/shots/shot_\(shot.shotId)/latest.png"

                await MainActor.run {
                    if let image = NSImage(data: imageData) {
                        previewImage = image
                    }
                    onPreviewGenerated(relativePath)
                    isGenerating = false
                    discoverPreviewImages()
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isGenerating = false
                }
            }
        }
    }

    // MARK: - Generate Preview With Annotations

    private func generatePreviewWithAnnotations(_ annotations: [KeyframeAnnotation]) {
        guard let currentImage = previewImage else { return }

        let editPrompt = ImageAnnotationEditor.buildEditPrompt(from: annotations, context: "shot preview")
        let basePrompt = lastUsedPrompt.isEmpty ? buildPrompt() : lastUsedPrompt
        let combinedPrompt = editPrompt + "\n\nOriginal prompt: " + basePrompt

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let aiClient = AIServiceClient.shared

                // Encode current image as reference
                var refs: [ReferenceImage] = []
                if let tiffData = currentImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    refs.append(ReferenceImage(
                        base64: pngData.base64EncodedString(),
                        mimeType: "image/png",
                        label: "Current shot preview to edit"
                    ))
                }

                // Also collect scene reference images
                if let scene = scene, let projDir = projectBasePath?.deletingLastPathComponent() {
                    let sceneRefs = CharacterReferenceHelper.collectReferenceImages(
                        forScene: scene,
                        characters: characters,
                        locations: locations,
                        projectDirectory: projDir
                    )
                    refs.append(contentsOf: sceneRefs)
                }

                let request = ImageGenerationRequest(
                    prompt: combinedPrompt,
                    provider: .googleImagen,
                    aspectRatio: "16:9",
                    numberOfImages: 1,
                    referenceImages: refs.isEmpty ? nil : refs
                )

                let response = try await aiClient.generateImage(request)

                guard let imageData = response.images.first else {
                    throw AIClientError.invalidResponse("No image generated")
                }

                guard let basePath = projectBasePath else {
                    throw AIClientError.invalidResponse("No project path")
                }

                let projectDir = basePath.deletingLastPathComponent()
                let shotDir = projectDir
                    .appendingPathComponent("assets")
                    .appendingPathComponent("shots")
                    .appendingPathComponent("shot_\(shot.shotId)")

                if !FileManager.default.fileExists(atPath: shotDir.path) {
                    try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let imageFilename = "preview_\(timestamp).png"

                let imagePath = shotDir.appendingPathComponent(imageFilename)
                try imageData.write(to: imagePath)

                // Save the edit prompt
                let promptPath = shotDir.appendingPathComponent("prompt.txt")
                try combinedPrompt.write(to: promptPath, atomically: true, encoding: .utf8)

                let latestPath = shotDir.appendingPathComponent("latest.png")
                if FileManager.default.fileExists(atPath: latestPath.path) {
                    try FileManager.default.removeItem(at: latestPath)
                }
                try imageData.write(to: latestPath)

                let relativePath = "assets/shots/shot_\(shot.shotId)/latest.png"

                await MainActor.run {
                    if let image = NSImage(data: imageData) {
                        previewImage = image
                    }
                    lastUsedPrompt = combinedPrompt
                    onPreviewGenerated(relativePath)
                    isGenerating = false
                    discoverPreviewImages()
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isGenerating = false
                }
            }
        }
    }

    // MARK: - Build Prompt

    // Prompt construction lives in ShotPromptBuilder (WS6.2 — pure + tested).
    private func buildPrompt() -> String {
        ShotPromptBuilder.previewPrompt(shot: shot, scene: scene, locations: locations, characters: characters)
    }

    private func buildPromptSummary() -> String {
        ShotPromptBuilder.promptSummary(shot: shot, scene: scene)
    }
}

// MARK: - Prompt Editor Sheet

private struct PromptEditorSheet: View {
    @Binding var prompt: String
    @Binding var isPresented: Bool
    let onGenerate: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Shot Preview Prompt")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(hex: "#1E1E1E"))

            Divider()

            // Prompt editor
            VStack(alignment: .leading, spacing: 12) {
                Text("Edit the prompt below to customize the generated image:")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                TextEditor(text: $prompt)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
                    )
                    .frame(minHeight: 200)

                // Tips
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tips:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)

                    Group {
                        Label("Be specific about camera angles, lighting, and mood", systemImage: "lightbulb")
                        Label("Include character descriptions for better results", systemImage: "person")
                        Label("Add style keywords like 'cinematic', 'film noir', '35mm'", systemImage: "film")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.7))
                }
                .padding(.top, 8)
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
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
            .background(Color(hex: "#1E1E1E"))
        }
        .frame(width: 600, height: 480)
        .background(Color(hex: "#252525"))
    }
}

// MARK: - Shot Preview Full Size Sheet

struct ShotPreviewFullSizeSheet: View {
    let image: NSImage?
    let shotId: Int
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
            // Header
            HStack {
                Text("Shot #\(shotId) Preview")
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
                    Text("\(Int(image.size.width)) × \(Int(image.size.height))")
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
