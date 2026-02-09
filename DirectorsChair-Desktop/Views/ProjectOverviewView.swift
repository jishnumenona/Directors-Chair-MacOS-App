//
//  ProjectOverviewView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Cinematic Pitch Deck — investor/stakeholder-ready overview
//

import SwiftUI
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
    @State private var isGeneratingIcon = false
    @State private var iconError: String?
    @State private var showingIconError = false
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            if let heroImage = heroImage {
                Image(nsImage: heroImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipped()
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
                    .frame(height: 320)
            }

            // Dark gradient overlay
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.7), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)

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

            // Generate icon button on hover
            if isHovered {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: generateProjectIcon) {
                            HStack(spacing: 6) {
                                if isGeneratingIcon {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .progressViewStyle(.circular)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text(heroImage != nil ? "Regenerate Poster" : "Generate Poster")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingIcon)
                        .padding(16)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 320)
        .clipped()
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear { loadHeroImage() }
        .onChange(of: project.projectIcon) { _ in loadHeroImage() }
        .alert("Icon Generation Failed", isPresented: $showingIconError) {
            Button("OK") { }
        } message: {
            Text(iconError ?? "Unknown error")
        }
    }

    private func loadHeroImage() {
        // Try project icon first, then first poster path
        let imagePaths = [project.projectIcon] + project.overviewPosterPaths
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

    // MARK: - Icon Generation (preserved from original)

    private func generateProjectIcon() {
        guard let projectPath = projectPath else {
            iconError = "No project path set. Please save the project first."
            showingIconError = true
            return
        }

        isGeneratingIcon = true

        Task {
            do {
                let aiClient = AIServiceClient.shared

                guard await aiClient.testConnection() else {
                    await MainActor.run {
                        iconError = "Could not connect to AI server."
                        showingIconError = true
                        isGeneratingIcon = false
                    }
                    return
                }

                let prompt = buildIconPrompt()

                let request = ImageGenerationRequest(
                    prompt: prompt,
                    provider: .googleImagen,
                    aspectRatio: "1:1",
                    numberOfImages: 1
                )

                let response = try await aiClient.generateImage(request)

                guard let imageData = response.images.first else {
                    throw AIClientError.invalidResponse("No image generated")
                }

                let projectDir = projectPath.deletingLastPathComponent()
                let iconsDir = projectDir.appendingPathComponent("assets").appendingPathComponent("icons")

                if !FileManager.default.fileExists(atPath: iconsDir.path) {
                    try FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
                }

                let sanitizedName = sanitizeFilename(project.name)
                let iconFilename = "\(sanitizedName)_icon.png"
                let iconPath = iconsDir.appendingPathComponent(iconFilename)

                try imageData.write(to: iconPath)

                let relativePath = "assets/icons/\(iconFilename)"

                await MainActor.run {
                    project.projectIcon = relativePath
                    onProjectChanged()
                    isGeneratingIcon = false
                }

            } catch {
                await MainActor.run {
                    iconError = error.localizedDescription
                    showingIconError = true
                    isGeneratingIcon = false
                }
            }
        }
    }

    private func buildIconPrompt() -> String {
        var parts: [String] = []
        parts.append("A cinematic movie poster icon for a film project")
        parts.append("titled '\(project.name)'")
        if !project.genre.isEmpty {
            parts.append("in the \(project.genre) genre")
        }
        if !project.description.isEmpty {
            parts.append("about: \(String(project.description.prefix(200)))")
        }
        if !project.overviewTagline.isEmpty {
            parts.append("with the tagline: '\(project.overviewTagline)'")
        }
        parts.append("Style: professional movie poster art, cinematic lighting, dramatic composition, high quality digital art, suitable as an app icon")
        return parts.joined(separator: ". ")
    }

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
            // Logline in cinematic quote style
            if !project.overviewLogline.isEmpty && !isEditing {
                Text("\"\(project.overviewLogline)\"")
                    .font(.system(size: 20, weight: .regular).italic())
                    .foregroundColor(.primary.opacity(0.9))
                    .lineSpacing(4)
                    .padding(.vertical, 4)
            }

            // Description / pitch body
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("The Pitch")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.2)

                        Spacer()

                        Button(action: {
                            isEditing.toggle()
                            if !isEditing { onProjectChanged() }
                        }) {
                            Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if isEditing {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Logline")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Enter a 1-2 sentence logline...", text: $project.overviewLogline, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)

                            Text("Tagline")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Enter a tagline...", text: $project.overviewTagline)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)

                            Text("Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: Binding(
                                get: { project.description },
                                set: { project.description = $0 }
                            ))
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    } else {
                        if !project.description.isEmpty {
                            Text(project.description)
                                .font(.system(size: 14))
                                .foregroundColor(.primary.opacity(0.85))
                                .lineSpacing(3)
                        } else {
                            Text("No pitch written yet. Click Edit to add a pitch.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
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
        ("calendar", "Schedule", .red, .schedule),
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
