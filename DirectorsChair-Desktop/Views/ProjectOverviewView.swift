//
//  ProjectOverviewView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Cinematic Pitch Deck — investor/stakeholder-ready overview
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices

// MARK: - Image Cache

final class OverviewImageCache {
    static let shared = OverviewImageCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 200
    }

    func image(forKey key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: NSImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
}


// MARK: - Main View

struct ProjectOverviewView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var isEditingPitch = false

    private var project: Project { projectViewModel.project }

    private var projectDir: URL? {
        projectViewModel.projectPath?.deletingLastPathComponent()
    }

    private var allScenes: [DirectorsChairCore.Scene] {
        project.sequences.flatMap(\.scenes)
    }

    private var allShotsWithImages: [(shot: Shot, sceneName: String)] {
        allScenes.flatMap { scene in
            scene.shots.compactMap { shot in
                guard let _ = shot.previewImage, !shot.previewImage!.isEmpty else { return nil }
                return (shot: shot, sceneName: scene.name)
            }
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // 1. Hero Banner
                OverviewHeroBanner(
                    project: $projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    projectDir: projectDir,
                    onProjectChanged: { projectViewModel.isDirty = true }
                )

                VStack(alignment: .leading, spacing: 32) {
                    // 2. Logline & Pitch
                    OverviewLoglineSection(
                        project: $projectViewModel.project,
                        isEditing: $isEditingPitch,
                        onProjectChanged: { projectViewModel.isDirty = true }
                    )

                    // 3. Stats Bar
                    OverviewStatsBar(
                        sequenceCount: project.sequences.count,
                        sceneCount: allScenes.count,
                        characterCount: project.characters.count,
                        shotCount: allScenes.flatMap(\.shots).count,
                        locationCount: project.locations.count
                    )

                    // 4. Scene Gallery
                    if !allScenes.isEmpty {
                        OverviewSceneGallery(
                            scenes: allScenes,
                            sequences: project.sequences,
                            projectDir: projectDir,
                            onSceneSelected: { scene in
                                coordinator.selectScene(scene)
                                coordinator.navigateTo(.scenes)
                            }
                        )
                    }

                    // 5. Characters Strip
                    if !project.characters.isEmpty {
                        OverviewCharacterStrip(
                            characters: project.characters,
                            projectDir: projectDir,
                            onCharacterSelected: { character in
                                coordinator.selectCharacter(character)
                            }
                        )
                    }

                    // 6. Shot Board
                    if !allShotsWithImages.isEmpty {
                        OverviewShotBoard(
                            shots: allShotsWithImages,
                            projectDir: projectDir,
                            onShotSelected: { shot in
                                coordinator.selectedShot = shot
                                coordinator.navigateTo(.shotList)
                            }
                        )
                    }

                    // 7. Locations Gallery
                    if !project.locations.isEmpty {
                        OverviewLocationGallery(
                            locations: project.locations,
                            projectDir: projectDir,
                            onLocationSelected: { location in
                                coordinator.selectLocation(location)
                            }
                        )
                    }

                    // 8. Quick Actions
                    OverviewQuickActions()
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 1. Hero Banner

private struct OverviewHeroBanner: View {
    @Binding var project: Project
    let projectPath: URL?
    let projectDir: URL?
    let onProjectChanged: () -> Void

    @State private var heroImage: NSImage?
    @State private var isGeneratingPoster = false
    @State private var posterError: String?
    @State private var showingPosterError = false
    @State private var isHovered = false
    @State private var imageRefreshId = UUID()

    // Full screen viewer
    @State private var showingFullScreenImage = false

    // Prompt editor
    @State private var showingPromptEditor = false
    @State private var customPrompt = ""

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            if let heroImage = heroImage {
                Image(nsImage: heroImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 480)
                    .clipped()
                    .id(imageRefreshId)
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.15), Color(white: 0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 480)
            }

            // Dark gradient overlay
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.7), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 480)

            // Text content
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                Text(project.name)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)

                if !project.overviewTagline.isEmpty {
                    Text(project.overviewTagline)
                        .font(.system(size: 16, weight: .regular).italic())
                        .foregroundColor(Color.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                }

                // Metadata pills
                HStack(spacing: 8) {
                    if !project.director.isEmpty {
                        MetadataPill(icon: "person.fill", text: project.director)
                    }
                    if !project.productionCompany.isEmpty {
                        MetadataPill(icon: "building.2.fill", text: project.productionCompany)
                    }
                    if !project.genre.isEmpty {
                        MetadataPill(icon: "theatermasks.fill", text: project.genre)
                    }
                    if !project.status.isEmpty {
                        MetadataPill(icon: "circle.fill", text: project.status)
                    }
                    if !project.projectType.isEmpty {
                        MetadataPill(icon: "film", text: project.projectType)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            // Hover action buttons
            if isHovered && !isGeneratingPoster {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            // View button
                            if heroImage != nil {
                                Button { showingFullScreenImage = true } label: {
                                    Image(systemName: "eye")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .help("View full screen")
                            }

                            // Download button
                            if heroImage != nil {
                                Button { downloadPoster() } label: {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .help("Download poster")
                            }

                            // Regenerate button
                            Button { generatePoster(with: nil) } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 9))
                                    Text(heroImage != nil ? "Regenerate" : "Generate")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.accentColor.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                            .help("Regenerate poster")

                            // Edit Prompt button
                            Button {
                                customPrompt = buildPosterPrompt()
                                showingPromptEditor = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 9))
                                    Text("Edit Prompt")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.orange.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                            .help("Edit prompt and generate")
                        }
                        .padding(16)
                    }
                    Spacer()
                }
            }

            // Generating overlay
            if isGeneratingPoster {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(.circular)
                            Text("Generating poster...")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(16)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 480)
        .clipped()
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear { loadHeroImage() }
        .onChange(of: project.projectIcon) { _ in loadHeroImage() }
        .onChange(of: project.overviewPosterPaths) { _ in loadHeroImage() }
        .alert("Poster Generation Failed", isPresented: $showingPosterError) {
            Button("OK") { }
        } message: {
            Text(posterError ?? "Unknown error")
        }
        .sheet(isPresented: $showingFullScreenImage) {
            PosterFullScreenViewer(
                imageURL: currentPosterURL(),
                title: "\(project.name) — Poster",
                onDownload: { downloadPoster() }
            )
        }
        .sheet(isPresented: $showingPromptEditor) {
            PosterPromptEditor(
                prompt: $customPrompt,
                onGenerate: {
                    showingPromptEditor = false
                    generatePoster(with: customPrompt)
                }
            )
        }
    }

    // MARK: - Load Hero Image

    private func loadHeroImage() {
        // Prioritize poster paths over icon
        let imagePaths = project.overviewPosterPaths + [project.projectIcon]
        guard let projectDir = projectDir else { return }

        for path in imagePaths {
            guard !path.isEmpty else { continue }
            let fullPath = projectDir.appendingPathComponent(path)

            if let cached = OverviewImageCache.shared.image(forKey: fullPath.path) {
                heroImage = cached
                return
            }

            if let image = NSImage(contentsOf: fullPath) {
                OverviewImageCache.shared.setImage(image, forKey: fullPath.path)
                heroImage = image
                return
            }
        }
    }

    private func currentPosterURL() -> URL? {
        guard let projectDir = projectDir else { return nil }
        let imagePaths = project.overviewPosterPaths + [project.projectIcon]
        for path in imagePaths {
            guard !path.isEmpty else { continue }
            let fullPath = projectDir.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: fullPath.path) {
                return fullPath
            }
        }
        return nil
    }

    // MARK: - Poster Generation

    private func generatePoster(with prompt: String?) {
        guard let projectPath = projectPath else {
            posterError = "No project path set. Please save the project first."
            showingPosterError = true
            return
        }

        isGeneratingPoster = true

        Task {
            do {
                let aiClient = AIServiceClient.shared

                guard await aiClient.testConnection() else {
                    await MainActor.run {
                        posterError = "Could not connect to AI server."
                        showingPosterError = true
                        isGeneratingPoster = false
                    }
                    return
                }

                let finalPrompt = prompt ?? buildPosterPrompt()

                let request = ImageGenerationRequest(
                    prompt: finalPrompt,
                    provider: .googleImagen,
                    aspectRatio: "3:4",
                    numberOfImages: 1
                )

                let response = try await aiClient.generateImage(request)

                guard let imageData = response.images.first else {
                    throw AIClientError.invalidResponse("No image generated")
                }

                let projectDir = projectPath.deletingLastPathComponent()
                let sanitizedName = sanitizeFilename(project.name)

                // Save to posters/ directory
                let postersDir = projectDir.appendingPathComponent("posters")
                if !FileManager.default.fileExists(atPath: postersDir.path) {
                    try FileManager.default.createDirectory(at: postersDir, withIntermediateDirectories: true)
                }
                let posterFilename = "\(sanitizedName)_poster.png"
                let posterPath = postersDir.appendingPathComponent(posterFilename)
                try imageData.write(to: posterPath)
                let posterRelativePath = "posters/\(posterFilename)"

                // Also save to assets/icons/ for icon usage
                let iconsDir = projectDir.appendingPathComponent("assets").appendingPathComponent("icons")
                if !FileManager.default.fileExists(atPath: iconsDir.path) {
                    try FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
                }
                let iconFilename = "\(sanitizedName)_icon.png"
                let iconPath = iconsDir.appendingPathComponent(iconFilename)
                try imageData.write(to: iconPath)
                let iconRelativePath = "assets/icons/\(iconFilename)"

                // Invalidate cache for old paths
                let oldPosterPaths = project.overviewPosterPaths
                let oldIconPath = project.projectIcon

                await MainActor.run {
                    // Invalidate old cache entries
                    for oldPath in oldPosterPaths {
                        if !oldPath.isEmpty {
                            let fullPath = projectDir.appendingPathComponent(oldPath)
                            OverviewImageCache.shared.removeImage(forKey: fullPath.path)
                        }
                    }
                    if !oldIconPath.isEmpty {
                        let fullPath = projectDir.appendingPathComponent(oldIconPath)
                        OverviewImageCache.shared.removeImage(forKey: fullPath.path)
                    }
                    // Also invalidate new paths in case they were cached with old data
                    OverviewImageCache.shared.removeImage(forKey: posterPath.path)
                    OverviewImageCache.shared.removeImage(forKey: iconPath.path)

                    // Update model
                    if !project.overviewPosterPaths.contains(posterRelativePath) {
                        project.overviewPosterPaths = [posterRelativePath]
                    }
                    project.projectIcon = iconRelativePath
                    onProjectChanged()

                    // Force image reload
                    if let newImage = NSImage(contentsOf: posterPath) {
                        OverviewImageCache.shared.setImage(newImage, forKey: posterPath.path)
                        heroImage = newImage
                    }
                    imageRefreshId = UUID()
                    isGeneratingPoster = false
                }

            } catch {
                await MainActor.run {
                    posterError = error.localizedDescription
                    showingPosterError = true
                    isGeneratingPoster = false
                }
            }
        }
    }

    private func buildPosterPrompt() -> String {
        var prompt = ""

        // Genre-based typography style
        let genreLower = project.genre.lowercased()
        let typographyStyle: String
        let moodStyle: String
        let colorPalette: String

        switch genreLower {
        case let g where g.contains("horror") || g.contains("thriller"):
            typographyStyle = "distressed, sharp-edged, blood-red or stark white sans-serif"
            moodStyle = "dark, ominous, high-contrast shadows, fog, desaturated tones"
            colorPalette = "deep blacks, blood reds, cold steel blues"
        case let g where g.contains("romance") || g.contains("drama"):
            typographyStyle = "elegant, serif-based with warm gold or silver metallic finish"
            moodStyle = "warm golden-hour lighting, intimate, emotionally evocative, soft bokeh backgrounds"
            colorPalette = "warm golds, deep amber, soft blues, muted earth tones"
        case let g where g.contains("action") || g.contains("adventure"):
            typographyStyle = "bold, metallic, embossed, blockbuster-style sans-serif"
            moodStyle = "explosive, dynamic, dramatic rim lighting, motion energy"
            colorPalette = "fiery oranges, steel blues, bright whites, gunmetal grays"
        case let g where g.contains("comedy"):
            typographyStyle = "playful, bold, rounded sans-serif with vibrant colors"
            moodStyle = "bright, cheerful, well-lit, fun and energetic"
            colorPalette = "vibrant primary colors, warm yellows, bright whites"
        case let g where g.contains("sci-fi") || g.contains("fantasy"):
            typographyStyle = "futuristic, sleek, glowing neon or chrome metallic"
            moodStyle = "otherworldly atmosphere, dramatic cosmic lighting, epic scale"
            colorPalette = "deep space blues, neon purples, electric cyans, starlight whites"
        default:
            typographyStyle = "bold, cinematic, professional serif or sans-serif"
            moodStyle = "dramatic cinematic lighting, professional atmosphere"
            colorPalette = "rich cinematic tones appropriate to the story"
        }

        // Core poster description
        prompt += "Professional theatrical movie poster for '\(project.name)'. "
        prompt += "FULL RECTANGULAR VERTICAL POSTER filling the entire frame edge-to-edge. NO circular frames, NO round borders, NO vignettes, NO circular crops. "
        prompt += "Standard movie poster layout and composition like an official Hollywood theatrical one-sheet. "

        // Genre & story context
        if !project.genre.isEmpty {
            prompt += "Genre: \(project.genre). "
        }
        if !project.description.isEmpty {
            prompt += "Story: \(String(project.description.prefix(250))). "
        }

        // Character imagery — the hero visual
        let mainCharacters = project.characters.prefix(4)
        if !mainCharacters.isEmpty {
            prompt += "MAIN IMAGERY: "
            let charDescriptions = mainCharacters.map { char -> String in
                var desc = char.name
                if !char.about.isEmpty {
                    desc += " (\(String(char.about.prefix(60))))"
                }
                if !char.ethnicity.isEmpty || !char.gender.isEmpty {
                    let traits = [char.gender, char.ethnicity].filter { !$0.isEmpty }.joined(separator: ", ")
                    desc += " — \(traits)"
                }
                if let costume = char.costume, !costume.isEmpty {
                    desc += ", wearing \(String(costume.prefix(40)))"
                }
                return desc
            }
            prompt += charDescriptions.joined(separator: "; ")
            prompt += ". Characters should be positioned dramatically — protagonist prominent in the foreground, supporting characters arranged around them with intentional visual hierarchy. "
        }

        // Mood & atmosphere
        prompt += "MOOD & ATMOSPHERE: \(moodStyle). "
        prompt += "COLOR PALETTE: \(colorPalette). "

        // Title typography
        prompt += "TITLE TEXT: '\(project.name)' displayed prominently in large, \(typographyStyle) typography. "

        // Tagline
        if !project.overviewTagline.isEmpty {
            prompt += "TAGLINE: '\(project.overviewTagline)' in smaller italic text positioned near the title. "
        }

        // Credits billing block — the small text at the bottom of movie posters
        var creditsParts: [String] = []
        if !project.director.isEmpty {
            creditsParts.append("Directed by \(project.director)")
        }

        // Add cast names from castMembers
        let castNames = project.castMembers.prefix(5).map { $0.actorName }.filter { !$0.isEmpty }
        if !castNames.isEmpty {
            creditsParts.append("Starring \(castNames.joined(separator: "  "))")
        } else {
            // Fallback to character names
            let charNames = project.characters.prefix(5).map { $0.name }.filter { !$0.isEmpty }
            if !charNames.isEmpty {
                creditsParts.append("Starring \(charNames.joined(separator: "  "))")
            }
        }

        // Add crew roles
        let keyCrewRoles = ["Producer", "Writer", "Cinematographer", "Director of Photography", "DP", "Editor", "Composer"]
        let keyCrew = project.crewMembers.filter { crew in
            keyCrewRoles.contains { crew.role.localizedCaseInsensitiveContains($0) }
        }.prefix(3)
        for crew in keyCrew {
            creditsParts.append("\(crew.role): \(crew.name)")
        }

        if !project.productionCompany.isEmpty {
            creditsParts.append("A \(project.productionCompany) Production")
        }

        if !creditsParts.isEmpty {
            prompt += "CREDITS BLOCK: At the very bottom of the poster, include a standard movie billing block in the narrow condensed typeface typical of theatrical posters, containing: \(creditsParts.joined(separator: " | ")). "
        }

        // Technical quality
        prompt += "STYLE: Ultra-detailed, photorealistic, professional theatrical release poster quality. High production value cinematic photography with realistic skin textures and detailed environments. Shot on large format camera, printed at high resolution. "
        prompt += "LAYOUT: Vertical 3:4 aspect ratio theatrical one-sheet poster. Full bleed to all edges. No black borders, no rounded corners, no circular framing."

        return prompt
    }

    // MARK: - Download

    private func downloadPoster() {
        guard let url = currentPosterURL(),
              let imageData = try? Data(contentsOf: url) else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "\(sanitizeFilename(project.name))_poster.png"
        savePanel.title = "Save Poster"
        savePanel.message = "Choose a location to save the poster"

        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                do {
                    try imageData.write(to: saveURL)
                } catch {
                    print("Failed to save poster: \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        sanitized = sanitized.unicodeScalars.filter { allowedChars.contains($0) }.map { String($0) }.joined()
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        return sanitized.isEmpty ? "project" : sanitized
    }
}

// MARK: - Poster Full Screen Viewer

private struct PosterFullScreenViewer: View {
    let imageURL: URL?
    let title: String
    var onDownload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()

                Button { onDownload?() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text("Download")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .quaternarySystemFill)))
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                        Text("Close")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.8)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Image content
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        ScrollView([.horizontal, .vertical]) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text("Failed to load image")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .empty:
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No image available")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color.black)
    }
}

// MARK: - Poster Prompt Editor

private struct PosterPromptEditor: View {
    @Binding var prompt: String
    var onGenerate: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text("EDIT PROMPT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)

                Spacer()

                Text("POSTER")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Prompt editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Image Generation Prompt")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                TextEditor(text: $prompt)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(8)
                    .frame(minHeight: 140)

                Text("Describe the poster style, mood, lighting, composition, and any key visual elements...")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .lineLimit(2)
            }
            .padding(20)

            Divider()

            // Action buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    onGenerate()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text("Generate")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Metadata Pill

private struct MetadataPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.15))
        .foregroundColor(.white)
        .cornerRadius(12)
    }
}

// MARK: - 2. Logline & Pitch

private struct OverviewLoglineSection: View {
    @Binding var project: Project
    @Binding var isEditing: Bool
    let onProjectChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Logline — inline editable
            VStack(alignment: .leading, spacing: 4) {
                Text("Logline")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                ZStack(alignment: .topLeading) {
                    if project.overviewLogline.isEmpty {
                        Text("Write a one-sentence logline...")
                            .font(.system(size: 20, weight: .regular).italic())
                            .foregroundColor(.secondary.opacity(0.4))
                            .padding(.vertical, 2)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $project.overviewLogline)
                        .font(.system(size: 20, weight: .regular).italic())
                        .foregroundColor(.primary.opacity(0.9))
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 30)
                        .fixedSize(horizontal: false, vertical: true)
                        .onChange(of: project.overviewLogline) { _, _ in onProjectChanged() }
                }
            }

            // The Pitch — inline editable
            VStack(alignment: .leading, spacing: 4) {
                Text("The Pitch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                ZStack(alignment: .topLeading) {
                    if project.description.isEmpty {
                        Text("Write your pitch here...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.4))
                            .italic()
                            .padding(.vertical, 2)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: Binding(
                        get: { project.description },
                        set: { project.description = $0 }
                    ))
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineSpacing(3)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 40)
                    .fixedSize(horizontal: false, vertical: true)
                    .onChange(of: project.description) { _, _ in onProjectChanged() }
                }
            }
        }
    }
}

// MARK: - 3. Stats Bar

private struct OverviewStatsBar: View {
    let sequenceCount: Int
    let sceneCount: Int
    let characterCount: Int
    let shotCount: Int
    let locationCount: Int

    var body: some View {
        HStack(spacing: 0) {
            StatPill(icon: "rectangle.stack", label: "Sequences", value: sequenceCount)
            StatDivider()
            StatPill(icon: "film", label: "Scenes", value: sceneCount)
            StatDivider()
            StatPill(icon: "person.3.fill", label: "Characters", value: characterCount)
            StatDivider()
            StatPill(icon: "camera.fill", label: "Shots", value: shotCount)
            StatDivider()
            StatPill(icon: "map.fill", label: "Locations", value: locationCount)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
        )
    }
}

private struct StatPill: View {
    let icon: String
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.4))
            .frame(width: 1, height: 28)
    }
}

// MARK: - 4. Scene Gallery

private struct OverviewSceneGallery: View {
    let scenes: [DirectorsChairCore.Scene]
    let sequences: [DirectorsChairCore.Sequence]
    let projectDir: URL?
    let onSceneSelected: (DirectorsChairCore.Scene) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Scenes", icon: "film")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(scenes, id: \.id) { scene in
                        SceneCard(
                            scene: scene,
                            sequenceName: sequenceName(for: scene),
                            projectDir: projectDir,
                            onTap: { onSceneSelected(scene) }
                        )
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private func sequenceName(for scene: DirectorsChairCore.Scene) -> String {
        for seq in sequences {
            if seq.scenes.contains(where: { $0.id == scene.id }) {
                return seq.name
            }
        }
        return ""
    }
}

private struct SceneCard: View {
    let scene: DirectorsChairCore.Scene
    let sequenceName: String
    let projectDir: URL?
    let onTap: () -> Void

    @State private var cardImage: NSImage?
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Background image or placeholder
                if let cardImage = cardImage {
                    Image(nsImage: cardImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 200)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(white: 0.18))
                        .frame(width: 220, height: 200)
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 28))
                                .foregroundColor(Color.white.opacity(0.2))
                        )
                }

                // Gradient overlay
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Text overlay
                VStack(alignment: .leading, spacing: 2) {
                    if !sequenceName.isEmpty {
                        Text(sequenceName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.65))
                            .textCase(.uppercase)
                            .tracking(0.8)
                    }
                    Text(scene.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                .padding(10)
            }
            .frame(width: 220, height: 200)
            .cornerRadius(10)
            .shadow(color: .black.opacity(isHovered ? 0.35 : 0.2), radius: isHovered ? 8 : 4, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .help(scene.sceneOverviewSummary ?? scene.name)
        .onAppear { loadImage() }
    }

    private func loadImage() {
        guard let projectDir = projectDir else { return }

        // Try sceneOverviewImage first, then first locationImage
        var paths: [String] = []
        if let overviewImg = scene.sceneOverviewImage, !overviewImg.isEmpty {
            paths.append(overviewImg)
        }
        if let firstLocImg = scene.locationImages.first {
            paths.append(firstLocImg.imagePath)
        }

        for path in paths {
            let fullPath = projectDir.appendingPathComponent(path)
            if let cached = OverviewImageCache.shared.image(forKey: fullPath.path) {
                cardImage = cached
                return
            }
            if let image = NSImage(contentsOf: fullPath) {
                OverviewImageCache.shared.setImage(image, forKey: fullPath.path)
                cardImage = image
                return
            }
        }
    }
}

// MARK: - 5. Characters Strip

private struct OverviewCharacterStrip: View {
    let characters: [Character]
    let projectDir: URL?
    let onCharacterSelected: (Character) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Characters", icon: "person.3.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(characters, id: \.characterId) { character in
                        CharacterPortrait(
                            character: character,
                            projectDir: projectDir,
                            onTap: { onCharacterSelected(character) }
                        )
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }
}

private struct CharacterPortrait: View {
    let character: Character
    let projectDir: URL?
    let onTap: () -> Void

    @State private var portraitImage: NSImage?
    @State private var isHovered = false

    private var characterColor: Color {
        if character.color.isEmpty { return .gray }
        return Color(nsColor: NSColor(hex: character.color) ?? .gray)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    if let portraitImage = portraitImage {
                        Image(nsImage: portraitImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(white: 0.18))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color.white.opacity(0.2))
                            )
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isHovered ? characterColor : Color.clear, lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                HStack(spacing: 4) {
                    Circle()
                        .fill(characterColor)
                        .frame(width: 6, height: 6)
                    Text(character.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }
            .frame(width: 100)
            .scaleEffect(isHovered ? 1.06 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .help(character.name)
        .onAppear { loadPortrait() }
    }

    private func loadPortrait() {
        guard let projectDir = projectDir else { return }

        // Priority: overviewPortrait -> baseImage -> imageFront
        let paths = [character.overviewPortrait, character.baseImage, character.imageFront].compactMap { $0 }.filter { !$0.isEmpty }

        for path in paths {
            let fullPath = projectDir.appendingPathComponent(path)
            if let cached = OverviewImageCache.shared.image(forKey: fullPath.path) {
                portraitImage = cached
                return
            }
            if let image = NSImage(contentsOf: fullPath) {
                OverviewImageCache.shared.setImage(image, forKey: fullPath.path)
                portraitImage = image
                return
            }
        }
    }
}

// MARK: - NSColor hex extension

private extension NSColor {
    convenience init?(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        guard hexStr.count == 6, let rgb = UInt64(hexStr, radix: 16) else { return nil }
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - 6. Shot Board

private struct OverviewShotBoard: View {
    let shots: [(shot: Shot, sceneName: String)]
    let projectDir: URL?
    let onShotSelected: (Shot) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Shot Board", icon: "camera.fill")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(shots.prefix(18).enumerated()), id: \.offset) { _, item in
                    ShotCard(
                        shot: item.shot,
                        sceneName: item.sceneName,
                        projectDir: projectDir,
                        onTap: { onShotSelected(item.shot) }
                    )
                }
            }
        }
    }
}

private struct ShotCard: View {
    let shot: Shot
    let sceneName: String
    let projectDir: URL?
    let onTap: () -> Void

    @State private var shotImage: NSImage?
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                if let shotImage = shotImage {
                    Image(nsImage: shotImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(white: 0.15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .overlay(
                            Image(systemName: "camera")
                                .font(.system(size: 24))
                                .foregroundColor(Color.white.opacity(0.15))
                        )
                }

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 2) {
                    if !shot.shotType.isEmpty {
                        Text(shot.shotType)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                    }
                    Text(sceneName)
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .cornerRadius(8)
            .shadow(color: .black.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 6 : 3, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .help("\(shot.shotType) — \(sceneName)")
        .onAppear { loadImage() }
    }

    private func loadImage() {
        guard let projectDir = projectDir,
              let previewPath = shot.previewImage, !previewPath.isEmpty else { return }
        let fullPath = projectDir.appendingPathComponent(previewPath)
        if let cached = OverviewImageCache.shared.image(forKey: fullPath.path) {
            shotImage = cached
            return
        }
        if let image = NSImage(contentsOf: fullPath) {
            OverviewImageCache.shared.setImage(image, forKey: fullPath.path)
            shotImage = image
        }
    }
}

// MARK: - 7. Locations Gallery

private struct OverviewLocationGallery: View {
    let locations: [Location]
    let projectDir: URL?
    let onLocationSelected: (Location) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Locations", icon: "map.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(locations, id: \.name) { location in
                        LocationCard(
                            location: location,
                            projectDir: projectDir,
                            onTap: { onLocationSelected(location) }
                        )
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }
}

private struct LocationCard: View {
    let location: Location
    let projectDir: URL?
    let onTap: () -> Void

    @State private var locationImage: NSImage?
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                if let locationImage = locationImage {
                    Image(nsImage: locationImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 180)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(white: 0.18))
                        .frame(width: 200, height: 180)
                        .overlay(
                            Image(systemName: "map")
                                .font(.system(size: 28))
                                .foregroundColor(Color.white.opacity(0.2))
                        )
                }

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if !location.locationType.isEmpty {
                            Text(location.locationType.capitalized)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                        if !location.description.isEmpty {
                            Text("·")
                                .foregroundColor(Color.white.opacity(0.5))
                            Text(location.description)
                                .font(.system(size: 9))
                                .foregroundColor(Color.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(10)
            }
            .frame(width: 200, height: 180)
            .cornerRadius(10)
            .shadow(color: .black.opacity(isHovered ? 0.35 : 0.2), radius: isHovered ? 8 : 4, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .help(location.name)
        .onAppear { loadImage() }
    }

    private func loadImage() {
        guard let projectDir = projectDir else { return }

        // Try primaryImage first, then first from images array
        var paths: [String] = []
        if let primary = location.primaryImage, !primary.isEmpty {
            paths.append(primary)
        }
        if let first = location.images.first, !first.isEmpty {
            paths.append(first)
        }

        for path in paths {
            let fullPath = projectDir.appendingPathComponent(path)
            if let cached = OverviewImageCache.shared.image(forKey: fullPath.path) {
                locationImage = cached
                return
            }
            if let image = NSImage(contentsOf: fullPath) {
                OverviewImageCache.shared.setImage(image, forKey: fullPath.path)
                locationImage = image
                return
            }
        }
    }
}

// MARK: - 8. Quick Actions

private struct OverviewQuickActions: View {
    @EnvironmentObject var coordinator: AppCoordinator

    private let actions: [(icon: String, label: String, color: Color, target: AppView)] = [
        ("bubble.left.and.bubble.right", "Dialogue", .blue, .bubble),
        ("book", "Characters", .purple, .storyDesign),
        ("square.grid.2x2", "Vision Board", .pink, .visionBoard),
        ("camera", "Shots", .orange, .shotList),
        ("theatermasks", "Production", .red, .production),
        ("gear", "Settings", .gray, .settings)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Actions", icon: "bolt.fill")

            HStack(spacing: 10) {
                ForEach(actions, id: \.label) { action in
                    Button(action: { coordinator.navigateTo(action.target) }) {
                        VStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.system(size: 18))
                                .foregroundColor(action.color)
                            Text(action.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(action.label)
                }
            }
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
        }
    }
}

// MARK: - Preview

#Preview {
    ProjectOverviewView()
        .environmentObject(AppCoordinator())
        .environmentObject(ProjectViewModel())
}
