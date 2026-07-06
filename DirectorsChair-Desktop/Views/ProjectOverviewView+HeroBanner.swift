//
// ProjectOverviewView+HeroBanner.swift
//
// Extracted from ProjectOverviewView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices
import AppKit


// MARK: - 1. Hero Banner

struct OverviewHeroBanner: View {
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
    @State private var allPosterImages: [URL] = []
    @State private var currentImageIndex: Int = -1

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

            // Image history navigation
            if allPosterImages.count > 1 {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Button {
                            if currentImageIndex > 0 {
                                currentImageIndex -= 1
                                loadPosterImageAtIndex(currentImageIndex)
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(currentImageIndex > 0 ? .white : .white.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentImageIndex <= 0)

                        Text("\(currentImageIndex + 1) / \(allPosterImages.count)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)

                        Button {
                            if currentImageIndex < allPosterImages.count - 1 {
                                currentImageIndex += 1
                                loadPosterImageAtIndex(currentImageIndex)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(currentImageIndex < allPosterImages.count - 1 ? .white : .white.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentImageIndex >= allPosterImages.count - 1)

                        if currentImageIndex == allPosterImages.count - 1 {
                            Text("Latest")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.7))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(20)
                    .padding(.bottom, 12)
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
        .onAppear {
            loadHeroImage()
            discoverPosterImages()
        }
        .onChange(of: project.projectIcon) { _ in loadHeroImage() }
        .onChange(of: project.overviewPosterPaths) { _ in
            loadHeroImage()
            discoverPosterImages()
        }
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

    // MARK: - Image History

    private func discoverPosterImages() {
        guard let projectDir = projectDir else { return }
        let postersDir = projectDir.appendingPathComponent("posters")
        guard FileManager.default.fileExists(atPath: postersDir.path) else { return }

        let sanitizedName = sanitizeFilename(project.name)
        let prefix = "\(sanitizedName)_poster_"

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: postersDir, includingPropertiesForKeys: nil)
            let images = contents
                .filter { $0.pathExtension.lowercased() == "png" }
                .filter { $0.lastPathComponent.hasPrefix(prefix) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            allPosterImages = images
            if !images.isEmpty {
                currentImageIndex = images.count - 1
            }
        } catch {
            // Directory doesn't exist or can't be read
        }
    }

    private func loadPosterImageAtIndex(_ index: Int) {
        guard index >= 0, index < allPosterImages.count else { return }
        let url = allPosterImages[index]
        let cacheKey = url.path

        if let cached = OverviewImageCache.shared.image(forKey: cacheKey) {
            heroImage = cached
            imageRefreshId = UUID()
            return
        }

        if let image = NSImage(contentsOf: url) {
            OverviewImageCache.shared.setImage(image, forKey: cacheKey)
            heroImage = image
            imageRefreshId = UUID()
        }
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

                // Save timestamped copy for history
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let timestampedFilename = "\(sanitizedName)_poster_\(timestamp).png"
                let timestampedPath = postersDir.appendingPathComponent(timestampedFilename)
                try imageData.write(to: timestampedPath)

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
                    discoverPosterImages()
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
