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
    /// Prop-shop registry — the props a shot names ride along as references (DC-0079).
    var props: [Prop] = []
    /// DC-0091: every shot in the project — the pool of continuity references.
    var allShots: [Shot] = []
    let projectBasePath: URL?
    let onPreviewGenerated: (String) -> Void
    /// DC-0091: the shot's chosen continuity references changed.
    var onShotUpdated: ((Shot) -> Void)?
    /// DC-0102: open a mentioned element's page from the annotation editor.
    var onOpenMention: ((ResolvedMention) -> Void)?
    @State private var showingContinuityPicker = false

    @State private var isGenerating = false
    @State private var previewImage: NSImage?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingPromptEditor = false
    @State private var showingFullSizePreview = false
    @State private var showingAnnotationEditor = false
    @State private var editablePrompt: String = ""
    @State private var lastUsedPrompt: String = ""
    /// The prompt as parts with sources, for the sectioned editor.
    @State private var promptSections: [PromptSection] = []
    /// A generation held back because the shot has no location (owner 2026-08-29).
    @State private var promptAwaitingLocation: String?
    @State private var allPreviewImages: [URL] = []
    /// Which history picture is the shot's picture (latest.png) right now.
    @State private var defaultPreviewIndex: Int?
    @State private var currentImageIndex: Int = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Preview container
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#1A1A1A"))

                if let image = previewImage {
                    // DC-0090: the WHOLE picture, never a centre crop — the
                    // container takes the picture's own shape (below).
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            // AI shot image generation is Creator (§3.3);
                            // Upload below stays free — your own images
                            // always work.
                            .requiresTier(.creator, feature: "AI shot images")

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
                            .requiresTier(.creator, feature: "AI shot images")

                            if !startFromOptions.isEmpty {
                                startFromMenu
                            }

                            Button(action: { uploadPreviewImage() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 12))
                                    Text("Upload")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#2A2A2A"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .help("Upload a custom image as the shot preview")
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
                                .requiresTier(.creator, feature: "AI shot images")

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

                                // Upload custom image button
                                Button(action: { uploadPreviewImage() }) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Upload custom image")
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

                            // Owner 2026-08-29: any generated picture can be the shot's picture.
                            if allPreviewImages.count > 1 {
                                if currentImageIndex == defaultPreviewIndex {
                                    Text("Shot picture")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.25))
                                        .cornerRadius(4)
                                } else {
                                    Button("Use as shot picture") { useCurrentAsShotPicture() }
                                        .font(.system(size: 9, weight: .semibold))
                                        .buttonStyle(.plain)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.7))
                                        .cornerRadius(4)
                                        .help("Make this the picture the shot shows and sends as its reference")
                                        .accessibilityIdentifier("preview-use-as-shot-picture")
                                }
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
            // DC-0090: a picture sets the frame's shape (a 16:9 preview is a
            // 16:9 box, capped so the page stays scrollable); the empty and
            // loading states keep the old 420-pt box.
            .modifier(PreviewFrameShape(image: previewImage))
            .alert("No location set", isPresented: Binding(get: { promptAwaitingLocation != nil },
                                                            set: { if !$0 { promptAwaitingLocation = nil } })) {
                Button("Generate anyway") {
                    if let prompt = promptAwaitingLocation { generatePreview(with: prompt, locationConfirmed: true) }
                    promptAwaitingLocation = nil
                }
                Button("Cancel", role: .cancel) { promptAwaitingLocation = nil }
            } message: {
                Text("This shot's scene has no location, so the preview won't know where it takes place. Set one in Shot Context or type #location in the description — or generate anyway.")
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
            )

            // DC-0091: the frames this shot keeps continuity with.
            continuityRow

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
                sections: $promptSections,
                onReset: { promptSections = builtSectionsWithPictures() },
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
                    characters: characters,
                    locations: locations,
                    props: props,
                    shots: shot.referenceShotIds.compactMap { id in allShots.first { $0.id == id } },
                    projectDirectory: projectBasePath?.deletingLastPathComponent(),
                    onOpenMention: onOpenMention,
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
        promptSections = promptSectionsForEditor()
        showingPromptEditor = true
    }

    /// What the sectioned editor opens with: the built parts; a previous
    /// annotation edit shows its marked changes above the base parts; a
    /// prompt the user wrote by hand shows as one part.
    /// The reference pictures this generation will send, with their labels.
    private func referencePictures() -> [PromptPicture] {
        guard let scene = scene, let projDir = projectBasePath?.deletingLastPathComponent() else { return [] }
        var refs = CharacterReferenceHelper.collectReferenceImages(
            forShot: shot, in: scene, characters: characters, locations: locations, props: props, projectDirectory: projDir)
        let continuity = ContinuityReferences.referenceImages(for: shot, allShots: allShots, projectDirectory: projDir)
        refs = ContinuityReferences.merged(continuity: continuity, others: refs,
                                           onDevice: AIProviderSelection.shared.provider(for: .image) == .onDevice)
        return refs.compactMap { ref in
            guard let data = Data(base64Encoded: ref.base64), let image = NSImage(data: data) else { return nil }
            let parts = ref.label.split(separator: ":", maxSplits: 1).map(String.init)
            let kind = parts.first ?? "reference"
            let name = parts.count > 1 ? parts[1] : ref.label
            return PromptPicture(label: "\(name) · \(kind)", image: image)
        }
    }

    /// The built parts with the pictures each one sends (owner 2026-08-29).
    private func builtSectionsWithPictures() -> [PromptSection] {
        var sections = ShotPromptBuilder.previewSections(shot: shot, scene: scene, locations: locations, characters: characters)
        let pictures = referencePictures()
        guard !pictures.isEmpty else { return sections }
        func attach(_ id: String, _ kinds: [String]) {
            guard let index = sections.firstIndex(where: { $0.id == id }) else { return }
            sections[index].pictures = pictures.filter { picture in kinds.contains { picture.label.hasSuffix("· \($0)") } }
        }
        attach("location", ["location"])
        attach("characters", ["character", "costume"])
        let rest = pictures.filter { picture in !["location", "character", "costume"].contains { picture.label.hasSuffix("· \($0)") } }
        if !rest.isEmpty {
            let references = PromptSection(id: "references", title: "Reference pictures", source: "Props · continuity shots",
                                           text: "", isFixed: true, pictures: rest)
            let at = sections.firstIndex { $0.id == "description" }.map { $0 + 1 } ?? sections.count
            sections.insert(references, at: at)
        }
        return sections
    }

    private func promptSectionsForEditor() -> [PromptSection] {
        let built = builtSectionsWithPictures()
        guard !lastUsedPrompt.isEmpty, lastUsedPrompt != buildPrompt() else { return built }
        if let edit = PromptSections.splitEditPrompt(lastUsedPrompt) {
            let changes = PromptSection(id: "changes", title: "Changes you marked", source: "Annotation editor",
                                        text: edit.changes.trimmingCharacters(in: .whitespacesAndNewlines))
            return [changes] + built
        }
        return [PromptSection(id: "custom", title: "Your prompt", source: "Written by you", text: lastUsedPrompt)]
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
                collageData = ShotCollageRenderer.createCollage(leftImage: aiImage, leftLabel: "AI PREVIEW", rightImage: takeFrame, rightLabel: "TAKE")
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

    // MARK: - Image History

    /// The scene location's picture, if the scene has a location with one.
    private var locationPicturePath: String? {
        guard let name = scene?.location, !name.isEmpty,
              let location = locations.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
        let path = location.primaryImage ?? location.images.first
        return (path?.isEmpty == false) ? path : nil
    }

    /// Owner 2026-08-29: a shot's preview can start from a picture that already
    /// exists — the scene location's picture or a continuity shot's preview —
    /// and be annotated into this shot from there.
    private struct StartFromOption: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let path: String
        let accessibilityId: String
    }

    private var startFromOptions: [StartFromOption] {
        var options: [StartFromOption] = []
        if let path = locationPicturePath {
            let name = scene?.location.flatMap { $0.isEmpty ? nil : " · \($0)" } ?? ""
            options.append(StartFromOption(id: "location", title: "Location picture\(name)",
                                           systemImage: "mappin.and.ellipse", path: path,
                                           accessibilityId: "preview-use-location"))
        }
        for other in referencedShots {
            guard let path = other.previewImage, !path.isEmpty else { continue }
            options.append(StartFromOption(id: other.id, title: "Shot #\(other.shotId) preview (continuity)",
                                           systemImage: "film.stack", path: path,
                                           accessibilityId: "preview-use-shot-\(other.shotId)"))
        }
        return options
    }

    private var startFromMenu: some View {
        Menu {
            ForEach(startFromOptions) { option in
                Button {
                    usePictureAsPreview(relativePath: option.path)
                } label: {
                    Label(option.title, systemImage: option.systemImage)
                }
                .accessibilityIdentifier(option.accessibilityId)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 12))
                Text("Start from")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.18))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Put an existing picture in as this shot's preview — the location's picture or a continuity shot's preview — then annotate it into this shot")
        .accessibilityIdentifier("preview-start-from")
    }

    /// DC-0102 / owner 2026-08-29: an existing picture (the location's, or a
    /// continuity shot's preview) becomes this shot's preview (history +
    /// latest, like an upload), ready to be annotated into the shot.
    private func usePictureAsPreview(relativePath path: String) {
        guard let basePath = projectBasePath,
              let data = try? Data(contentsOf: basePath.deletingLastPathComponent().appendingPathComponent(path)),
              let png = UploadedImage.normalizedPNG(from: data) else { return }
        do {
            let shotDir = "assets/shots/shot_\(shot.shotId)"
            try UploadedImage.writePNG(png, projectBasePath: basePath, relativeDirectory: shotDir,
                                       filename: "preview_\(UploadedImage.historyTimestamp()).png")
            let relativePath = try UploadedImage.writePNG(png, projectBasePath: basePath, relativeDirectory: shotDir,
                                                          filename: "latest.png")
            if let image = NSImage(data: png) { previewImage = image }
            onPreviewGenerated(relativePath)
            discoverPreviewImages()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func uploadPreviewImage() {
        guard let basePath = projectBasePath,
              let data = UploadedImage.pickData(message: "Choose a preview image for this shot"),
              let png = UploadedImage.normalizedPNG(from: data) else { return }
        do {
            let shotDir = "assets/shots/shot_\(shot.shotId)"
            // Same history convention as generation: timestamped copy + latest.
            try UploadedImage.writePNG(png, projectBasePath: basePath,
                                       relativeDirectory: shotDir,
                                       filename: "preview_\(UploadedImage.historyTimestamp()).png")
            let relativePath = try UploadedImage.writePNG(png, projectBasePath: basePath,
                                                          relativeDirectory: shotDir,
                                                          filename: "latest.png")
            if let image = NSImage(data: png) {
                previewImage = image
            }
            onPreviewGenerated(relativePath)
            discoverPreviewImages()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

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
            // The shot's picture is latest.png — find which history file it is.
            let latest = shotDir.appendingPathComponent("latest.png")
            if let latestData = try? Data(contentsOf: latest) {
                defaultPreviewIndex = images.firstIndex { (try? Data(contentsOf: $0)) == latestData }
            } else {
                defaultPreviewIndex = nil
            }
        } catch {
            // Directory doesn't exist or can't be read
        }
    }

    /// Copy the browsed history picture over latest.png so every consumer
    /// (thumbnails, references, exports) uses it.
    private func useCurrentAsShotPicture() {
        guard let basePath = projectBasePath, currentImageIndex < allPreviewImages.count else { return }
        let source = allPreviewImages[currentImageIndex]
        let relativePath = "assets/shots/shot_\(shot.shotId)/latest.png"
        let latest = basePath.deletingLastPathComponent().appendingPathComponent(relativePath)
        do {
            let data = try Data(contentsOf: source)
            try data.write(to: latest, options: .atomic)
            defaultPreviewIndex = currentImageIndex
            onPreviewGenerated(relativePath)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func loadPreviewImageAtIndex(_ index: Int) {
        guard index >= 0, index < allPreviewImages.count else { return }
        let url = allPreviewImages[index]
        if let image = NSImage(contentsOf: url) {
            previewImage = image
        }
    }

    // MARK: - Continuity references (DC-0091)

    private var sceneShotIds: [String] { scene?.shots.map(\.id) ?? [] }

    private var referencedShots: [Shot] {
        shot.referenceShotIds.compactMap { id in allShots.first { $0.id == id } }
    }

    private var continuityCandidates: [Shot] {
        ContinuityReferences.candidates(for: shot, sceneShotIds: sceneShotIds, allShots: allShots)
            .filter { !shot.referenceShotIds.contains($0.id) }
    }

    private var continuityRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "film.stack")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("Continuity")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .help("Other shots' finished previews sent along as references so this shot keeps the same place, light, cast and wardrobe")

            ForEach(referencedShots, id: \.id) { other in
                HStack(spacing: 5) {
                    if let path = other.previewImage, let base = projectBasePath?.deletingLastPathComponent() {
                        AsyncThumbnail(url: base.appendingPathComponent(path), displaySize: 28) {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 36, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    Text("Shot #\(other.shotId)")
                        .font(.system(size: 10, weight: .medium))
                    if let path = other.previewImage, !path.isEmpty {
                        Button {
                            usePictureAsPreview(relativePath: path)
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Use Shot #\(other.shotId)'s preview as this shot's picture, to annotate from")
                        .accessibilityIdentifier("continuity-use-\(other.shotId)")
                    }
                    Button {
                        var updated = shot
                        updated.referenceShotIds.removeAll { $0 == other.id }
                        onShotUpdated?(updated)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Stop using Shot #\(other.shotId) as a reference")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.12)))
                .accessibilityIdentifier("continuity-ref-\(other.shotId)")
            }

            Button {
                showingContinuityPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .medium))
                    Text(referencedShots.isEmpty ? "Use another shot as reference" : "Add")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.accentColor.opacity(0.9))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
            }
            .buttonStyle(.plain)
            .disabled(continuityCandidates.isEmpty)
            .help(continuityCandidates.isEmpty
                  ? "Generate a preview on another shot first — finished previews can be used as references"
                  : "Pick a shot whose preview this shot should keep continuity with")
            .accessibilityIdentifier("continuity-add")
            .popover(isPresented: $showingContinuityPicker, arrowEdge: .bottom) {
                continuityPicker
            }

            Spacer()
        }
    }

    private var continuityPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Keep continuity with")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(continuityCandidates, id: \.id) { other in
                        Button {
                            var updated = shot
                            updated.referenceShotIds.append(other.id)
                            onShotUpdated?(updated)
                            showingContinuityPicker = false
                        } label: {
                            HStack(spacing: 8) {
                                if let path = other.previewImage, let base = projectBasePath?.deletingLastPathComponent() {
                                    AsyncThumbnail(url: base.appendingPathComponent(path), displaySize: 64) {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 64, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Shot #\(other.shotId)\(sceneShotIds.contains(other.id) ? "" : " · other scene")")
                                        .font(.system(size: 11, weight: .medium))
                                    Text(other.description.isEmpty ? other.shotType : String(other.description.prefix(60)))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("continuity-pick-\(other.shotId)")
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 260)
        }
        .frame(width: 320)
    }

    // MARK: - Generate Preview

    private func generatePreview(with prompt: String, locationConfirmed: Bool = false) {
        // Owner 2026-08-29: a shot without a location has nowhere to happen — ask first.
        if !locationConfirmed, (scene?.location ?? "").isEmpty {
            promptAwaitingLocation = prompt
            return
        }
        isGenerating = true
        errorMessage = nil
        lastUsedPrompt = prompt

        Task {
            do {
                let aiClient = AIServiceClient.shared

                guard await aiClient.imageServiceReachable() else {
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
                        forShot: shot, in: scene,
                        characters: characters,
                        locations: locations,
                        props: props,
                        projectDirectory: projDir
                    )
                }

                // DC-0091: other shots' finished frames come first, within
                // the provider's reference budget.
                if let projDir = projectBasePath?.deletingLastPathComponent() {
                    let continuity = ContinuityReferences.referenceImages(for: shot, allShots: allShots, projectDirectory: projDir)
                    refs = ContinuityReferences.merged(
                        continuity: continuity, others: refs,
                        onDevice: AIProviderSelection.shared.provider(for: .image) == .onDevice)
                }

                // Prepend reference image instructions to the prompt
                let fullPrompt: String
                if !refs.isEmpty {
                    let prefix = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: refs)
                    fullPrompt = prefix + prompt
                } else {
                    fullPrompt = prompt
                }

                // DC-0066: the on-device engine draws from the shot's own
                // facts (or the user's edited prompt, cleaned), never from
                // the photoreal wording above.
                let onDeviceSubject = prompt == buildPrompt()
                    ? StoryboardSubjects.subject(for: shot, in: scene,
                                                 locations: locations, characters: characters)
                    : StoryboardSubjects.plainSubject(from: prompt)
                let request = ImageGenerationRequest(
                    prompt: fullPrompt,
                    provider: AIProviderSelection.shared.provider(for: .image),
                    aspectRatio: "16:9",
                    numberOfImages: 1,
                    referenceImages: refs.isEmpty ? nil : refs,
                    brief: VisualBrief(purpose: .shot, subject: onDeviceSubject,
                                       framing: StoryboardSubjects.notes(for: shot)),
                    targetSize: .projectPreview   // DC-0090: the project's preview size
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
        guard let currentImage = previewImage,
              let tiffData = currentImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let source = bitmap.representation(using: .png, properties: [:]) else { return }
        // Never nest an edit inside an edit (owner report 2026-08-29).
        let basePrompt = PromptSections.baseForEdit(lastUsed: lastUsedPrompt, built: buildPrompt())
        // The scene's pictures ride behind the preview for likeness (cloud);
        // the on-device repaint takes the preview alone.
        // Owner 2026-08-29: an edit carries the picture and the pictures of what
        // the instructions mention — not the scene's whole reference bundle,
        // which made the model start the picture over.
        var context: [ReferenceImage] = []
        // DC-0102: the pictures of everything the instructions mention ride
        // along (cloud edits; on-device repaints take the source alone).
        if let projDir = projectBasePath?.deletingLastPathComponent() {
            let mentioned = MentionParser.mentions(in: annotations.map(\.text).joined(separator: "\n"),
                                                   characters: characters, locations: locations, props: props,
                                                   shots: shot.referenceShotIds.compactMap { id in allShots.first { $0.id == id } })
            for mention in mentioned {
                guard let path = mention.imagePath, !path.isEmpty,
                      let data = try? Data(contentsOf: projDir.appendingPathComponent(path)) else { continue }
                let kind: String
                switch mention.kind {
                case .character: kind = "character"
                case .location: kind = "location"
                case .prop: kind = "prop"
                case .shot: kind = "shot"
                }
                let label = "\(kind):\(mention.name)"
                if !context.contains(where: { $0.label == label }) {
                    context.append(ReferenceImage(base64: data.base64EncodedString(), mimeType: "image/png", label: label))
                }
            }
        }
        // DC-0073: one description of the edit; the client composes the request.
        let edit = AnnotationEdit(source: source, annotations: annotations, context: "shot preview",
                                  originalPrompt: basePrompt, contextPictures: context, aspectRatio: "16:9",
                                  targetSize: .projectPreview)
        let combinedPrompt = AnnotationEditComposer.prompt(for: edit)

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let imageData = try await AIServiceClient.shared.editImage(edit)
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
                AnnotationEditRecord(edit: edit, provider: AIProviderSelection.shared.provider(for: .image)).write(besides: imagePath)
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
    @Binding var sections: [PromptSection]
    var onReset: (() -> Void)? = nil
    @Binding var isPresented: Bool
    let onGenerate: (String) -> Void

    var body: some View {
        StructuredPromptEditor(
            title: "Shot preview prompt",
            sections: $sections,
            onReset: onReset,
            onCancel: { isPresented = false },
            onGenerate: { prompt in
                isPresented = false
                onGenerate(prompt)
            }
        )
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

// MARK: - Preview frame shape (DC-0090)

/// The hero box follows the picture: its aspect ratio, full width, height
/// capped at 640 pt (a 1920×1080 preview in a wide column would otherwise
/// be taller than the window). Without a picture: the fixed 420-pt box.
private struct PreviewFrameShape: ViewModifier {
    let image: NSImage?

    func body(content: Content) -> some View {
        if let image, image.size.height > 0 {
            content
                .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 640)
        } else {
            content.frame(height: 420)
        }
    }
}
