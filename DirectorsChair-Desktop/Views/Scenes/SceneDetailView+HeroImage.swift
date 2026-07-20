//
// SceneDetailView+HeroImage.swift
//
// Extracted from SceneDetailView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairServices

extension SceneDetailView {

    // MARK: - Back Bar

    var backBar: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Scenes")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Hero Section

    var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image or gradient
            if let image = heroImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .overlay(
                        // Gradient scrim for text readability
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .topTrailing) {
                        if isHoveringHero || isGeneratingImage {
                            heroControlButtons
                                .padding(12)
                        }
                    }
            } else {
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor),
                        Color.accentColor.opacity(0.08),
                        Color(nsColor: .controlBackgroundColor).opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 260)
                .overlay(alignment: .center) {
                    if isGeneratingImage {
                        VStack(spacing: 8) {
                            ProgressView().scaleEffect(1.0)
                            Text("Generating preview...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if isHoveringHero {
                        Button { generateOverviewImage() } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 28))
                                Text("Generate Scene Preview")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "film")
                            .font(.system(size: 42))
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                }
            }

            // Image history navigation
            if allOverviewImages.count > 1 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        imageHistoryNav
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
            }

            // Overlaid scene info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if let prefix = parsed.prefix {
                        Text(prefix)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                    }
                    statusBadge
                }

                Text(parsed.location)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(heroImage != nil ? .white : .primary)

                HStack(spacing: 12) {
                    Text(SceneCardHelpers.sceneNumber(scene.name))
                        .font(.subheadline)
                        .foregroundColor(heroImage != nil ? .white.opacity(0.8) : .secondary)

                    if let time = parsed.time {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(time)
                        }
                        .font(.subheadline)
                        .foregroundColor(heroImage != nil ? .white.opacity(0.8) : .secondary)
                    }

                    if duration > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption2)
                            Text("~\(DurationEstimator.formatTimeReadable(CGFloat(duration)))")
                        }
                        .font(.subheadline)
                        .foregroundColor(heroImage != nil ? .white.opacity(0.8) : .secondary)
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHoveringHero = hovering }
        }
    }

    // MARK: - Hero Control Buttons

    var heroControlButtons: some View {
        HStack(spacing: 6) {
            if !isGeneratingImage {
                heroControlButton(icon: "arrow.up.left.and.arrow.down.right", help: "View full size") {
                    showingFullSize = true
                }
                heroControlButton(icon: "pencil.and.outline", help: "Annotate & edit image") {
                    showingAnnotationEditor = true
                }
                heroControlButton(icon: "text.badge.plus", help: "Edit prompt") {
                    editablePrompt = lastUsedPrompt.isEmpty ? SceneCardHelpers.buildSceneOverviewPrompt(scene: scene) : lastUsedPrompt
                    showingPromptEditor = true
                }
                heroControlButton(icon: "arrow.down.circle", help: "Download image") {
                    downloadImage()
                }
                heroControlButton(icon: "photo.badge.plus", help: "Upload custom image") {
                    uploadHeroImage()
                }
            }

            // Regenerate button with spinner during generation
            Button(action: { generateOverviewImage() }) {
                ZStack {
                    if isGeneratingImage {
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
                .background(isGeneratingImage ? Color.accentColor.opacity(0.8) : Color.black.opacity(0.6))
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingImage)
            .help(isGeneratingImage ? "Generating..." : "Regenerate")
        }
    }

    func heroControlButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
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

    // MARK: - Image History Navigation

    var imageHistoryNav: some View {
        HStack(spacing: 10) {
            Button {
                if currentImageIndex > 0 {
                    currentImageIndex -= 1
                    loadImageAtIndex(currentImageIndex)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(currentImageIndex > 0 ? .white : .white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(currentImageIndex <= 0)

            Text("\(currentImageIndex + 1) / \(allOverviewImages.count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            Button {
                if currentImageIndex < allOverviewImages.count - 1 {
                    currentImageIndex += 1
                    loadImageAtIndex(currentImageIndex)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(currentImageIndex < allOverviewImages.count - 1 ? .white : .white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(currentImageIndex >= allOverviewImages.count - 1)

            if currentImageIndex == allOverviewImages.count - 1 {
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
    }

    func uploadHeroImage() {
        guard let basePath = projectBasePath,
              let data = UploadedImage.pickData(message: "Choose an image for \(scene.name)"),
              let png = UploadedImage.normalizedPNG(from: data) else { return }
        do {
            let sanitizedName = SceneCardHelpers.sanitizeFilename(scene.name)
            let sceneDir = "assets/scenes/\(sanitizedName)"
            try UploadedImage.writePNG(png, projectBasePath: basePath,
                                       relativeDirectory: sceneDir,
                                       filename: "overview_\(UploadedImage.historyTimestamp()).png")
            let relativePath = try UploadedImage.writePNG(png, projectBasePath: basePath,
                                                          relativeDirectory: sceneDir,
                                                          filename: "overview_latest.png")
            if let image = NSImage(data: png) {
                SceneImageCache.shared.setImage(image, forKey: basePath.appendingPathComponent(relativePath).path)
                heroImage = image
            }
            discoverOverviewImages()
            onImageGenerated?(relativePath)
        } catch {
            debugLog("SceneDetailView: custom image upload failed: \(error)")
        }
    }

    func discoverOverviewImages() {
        guard let basePath = projectBasePath else { return }
        let sanitizedName = SceneCardHelpers.sanitizeFilename(scene.name)
        let sceneDir = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("scenes")
            .appendingPathComponent(sanitizedName)

        guard FileManager.default.fileExists(atPath: sceneDir.path) else { return }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: sceneDir, includingPropertiesForKeys: nil)
            let images = contents
                .filter { $0.pathExtension.lowercased() == "png" }
                .filter { $0.lastPathComponent.hasPrefix("overview_") && $0.lastPathComponent != "overview_latest.png" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            allOverviewImages = images
            if !images.isEmpty {
                currentImageIndex = images.count - 1 // default to latest
            }
        } catch {
            // Directory doesn't exist or can't be read
        }
    }

    func loadImageAtIndex(_ index: Int) {
        guard index >= 0, index < allOverviewImages.count else { return }
        let url = allOverviewImages[index]
        let cacheKey = url.path

        if let cached = SceneImageCache.shared.image(forKey: cacheKey) {
            heroImage = cached
            return
        }

        Task.detached(priority: .utility) {
            guard let image = NSImage(contentsOf: url) else { return }
            SceneImageCache.shared.setImage(image, forKey: cacheKey)
            await MainActor.run { heroImage = image }
        }
    }

    var statusBadge: some View {
        let color = SceneCardHelpers.productionStatusColor(scene.productionStatus)
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(scene.productionStatus)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(6)
    }

    // MARK: - Stats Bar

    var statsBar: some View {
        HStack(spacing: 0) {
            statItem(value: "\(scene.dialogues.count)", label: "Dialogues", icon: "bubble.left.fill", color: .blue)
            Divider().frame(height: 30)
            statItem(value: "\(scene.actions.count)", label: "Actions", icon: "figure.walk", color: .yellow)
            Divider().frame(height: 30)
            statItem(value: "\(scene.narrations.count)", label: "Narrations", icon: "text.quote", color: .cyan)
            Divider().frame(height: 30)
            statItem(value: "\(scene.shots.count)", label: "Shots", icon: "camera.fill", color: .orange)
            Divider().frame(height: 30)
            let charCount = SceneCardHelpers.sceneCharacters(scene: scene).count
            statItem(value: "\(charCount)", label: "Characters", icon: "person.2.fill", color: .green)
        }
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
