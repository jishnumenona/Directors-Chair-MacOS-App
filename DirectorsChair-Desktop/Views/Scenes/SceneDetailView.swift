//
//  SceneDetailView.swift
//  DirectorsChair-Desktop
//
//  Magazine-style scene detail with hero image, stats bar, and two-column layout
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairServices

struct SceneDetailView: View {
    let scene: DirectorsChairCore.Scene
    let characters: [Character]
    let projectBasePath: URL?
    let onBack: () -> Void
    let onOpenBubble: (DirectorsChairCore.Scene) -> Void
    let onOpenShotList: (DirectorsChairCore.Scene) -> Void
    var onSelectShot: ((DirectorsChairCore.Scene, Shot) -> Void)? = nil
    var onJumpShotToScript: ((DirectorsChairCore.Scene, Shot) -> Void)? = nil
    var onImageGenerated: ((String) -> Void)? = nil
    var onPromptUsed: ((String) -> Void)? = nil
    var onSceneAboutChanged: ((String) -> Void)? = nil
    var onSceneDescriptionChanged: ((String) -> Void)? = nil
    var onSceneNotesChanged: ((String) -> Void)? = nil

    @State private var heroImage: NSImage?
    @State private var isGeneratingImage = false
    @State private var isHoveringHero = false
    @State private var showingFullSize = false
    @State private var showingPromptEditor = false
    @State private var showingAnnotationEditor = false
    @State private var editablePrompt = ""
    @State private var lastUsedPrompt = ""
    @State private var allOverviewImages: [URL] = []
    @State private var currentImageIndex: Int = -1

    private var parsed: (prefix: String?, location: String, time: String?) {
        SceneCardHelpers.parseSceneLocation(scene.location)
    }

    private var duration: Double {
        SceneCardHelpers.estimateSceneDuration(scene: scene)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                statsBar
                mainContent
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .top, spacing: 0) { backBar }
        .onAppear {
            loadHeroImage()
            lastUsedPrompt = scene.sceneOverviewPrompt ?? ""
            discoverOverviewImages()
        }
        .onChange(of: scene.id) { _ in
            heroImage = nil
            isGeneratingImage = false
            allOverviewImages = []
            currentImageIndex = -1
            loadHeroImage()
            lastUsedPrompt = scene.sceneOverviewPrompt ?? ""
            discoverOverviewImages()
        }
        .sheet(isPresented: $showingFullSize) {
            ScenePreviewFullSizeSheet(
                image: heroImage,
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
        .sheet(isPresented: $showingAnnotationEditor) {
            if let image = heroImage {
                ImageAnnotationEditor(
                    image: image,
                    title: "EDIT SCENE PREVIEW",
                    subtitle: scene.name,
                    isPresented: $showingAnnotationEditor,
                    onApplyEdits: { annotations in
                        generateOverviewWithAnnotations(annotations)
                    }
                )
            }
        }
    }

    // MARK: - Back Bar

    private var backBar: some View {
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

    private var heroSection: some View {
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

    private var heroControlButtons: some View {
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

    private func heroControlButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
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

    private var imageHistoryNav: some View {
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

    private func discoverOverviewImages() {
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

    private func loadImageAtIndex(_ index: Int) {
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

    private var statusBadge: some View {
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

    private var statsBar: some View {
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

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
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

    // MARK: - Main Content (Two Columns)

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 1) {
            // Left: Primary content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    aboutCard
                    scriptPreviewCard
                    shotsCard
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Right: Metadata sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    charactersCard
                    emotionsCard
                    propsCard
                    notesCard
                }
                .padding(20)
            }
            .frame(width: 280)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        }
        .frame(minHeight: 400)
    }

    // MARK: - About Card

    @State private var editAbout: String = ""
    @State private var editDescription: String = ""
    @State private var editNotes: String = ""
    @State private var aboutFieldsInitialized = false

    private var aboutCard: some View {
        DetailCard(title: "About", icon: "doc.text") {
            VStack(alignment: .leading, spacing: 12) {
                // About / Summary — inline editable
                inlineTextField(
                    text: $editAbout,
                    placeholder: "Write about this scene...",
                    font: .body,
                    lineSpacing: 4,
                    foreground: .primary
                ) { onSceneAboutChanged?($0) }

                Divider()

                // Description — inline editable
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    inlineTextField(
                        text: $editDescription,
                        placeholder: "Add a description...",
                        font: .callout,
                        lineSpacing: 3,
                        foreground: .secondary
                    ) { onSceneDescriptionChanged?($0) }
                }

                Divider()

                // Notes — inline editable
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    inlineTextField(
                        text: $editNotes,
                        placeholder: "Add notes...",
                        font: .callout,
                        lineSpacing: 3,
                        foreground: .secondary
                    ) { onSceneNotesChanged?($0) }
                }

                if let context = scene.locationContext, !context.isEmpty {
                    Divider()
                    locationContextRows(context)
                }
            }
        }
        .onAppear { initAboutFields() }
        .onChange(of: scene.name) { _, _ in initAboutFields() }
    }

    private func initAboutFields() {
        editAbout = scene.sceneOverviewSummary ?? ""
        editDescription = scene.description
        editNotes = scene.notes
    }

    private func inlineTextField(
        text: Binding<String>,
        placeholder: String,
        font: Font,
        lineSpacing: CGFloat,
        foreground: Color,
        onChange: @escaping (String) -> Void
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundColor(.secondary.opacity(0.35))
                    .italic()
                    .padding(.vertical, 2)
                    .allowsHitTesting(false)
            }
            TextEditor(text: text)
                .font(font)
                .foregroundColor(foreground)
                .scrollContentBackground(.hidden)
                .lineSpacing(lineSpacing)
                .frame(minHeight: 20)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: text.wrappedValue) { _, newValue in
                    onChange(newValue)
                }
        }
    }

    private func locationContextRows(_ context: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location Details")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ForEach(Array(context.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                HStack(alignment: .top, spacing: 8) {
                    Text(key.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 90, alignment: .trailing)
                    Text(value)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Script Preview Card

    private var scriptPreviewCard: some View {
        DetailCard(title: "Script", icon: "text.justify.left") {
            VStack(alignment: .leading, spacing: 12) {
                // Dialogue preview (first 4)
                if !scene.dialogues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(scene.dialogues.prefix(4).enumerated()), id: \.offset) { _, dialogue in
                            dialoguePreviewRow(dialogue)
                        }
                        if scene.dialogues.count > 4 {
                            Text("+ \(scene.dialogues.count - 4) more dialogues")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 32)
                        }
                    }
                }

                // Action preview (first 2)
                if !scene.actions.isEmpty {
                    if !scene.dialogues.isEmpty { Divider() }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(scene.actions.prefix(2).enumerated()), id: \.offset) { _, action in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "figure.walk")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                    .frame(width: 16)
                                Text(DurationEstimator.htmlToPlainText(action.description))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        if scene.actions.count > 2 {
                            Text("+ \(scene.actions.count - 2) more actions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                }

                // Open button
                Button {
                    onOpenBubble(scene)
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("Open in Bubble View")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dialoguePreviewRow(_ dialogue: Dialogue) -> some View {
        let character = characters.first { $0.name == dialogue.character }
        return HStack(alignment: .top, spacing: 8) {
            CharacterAvatarView(
                character: character,
                characterName: dialogue.character,
                size: 22,
                projectBasePath: projectBasePath
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(dialogue.character)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(DurationEstimator.htmlToPlainText(dialogue.text))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Shots Card

    private var shotsCard: some View {
        DetailCard(title: "Shots (\(scene.shots.count))", icon: "camera.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if scene.shots.isEmpty {
                    HStack {
                        Image(systemName: "camera")
                            .foregroundColor(.secondary)
                        Text("No shots planned yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                        ForEach(scene.shots) { shot in
                            miniShotCard(shot)
                        }
                    }

                    Button {
                        onOpenShotList(scene)
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("Open Shot List")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func miniShotCard(_ shot: Shot) -> some View {
        let statusColor = SceneCardHelpers.productionStatusColor(shot.status)
        let hasCallback = onSelectShot != nil

        return Button {
            if NSEvent.modifierFlags.contains(.option) {
                onJumpShotToScript?(scene, shot)
            } else {
                onSelectShot?(scene, shot)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Shot preview thumbnail
                shotThumbnail(shot)

                // Shot info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("#\(shot.shotId)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text(shot.shotType)
                            .font(.caption2)
                            .fontWeight(.medium)
                        Spacer()
                        Circle().fill(statusColor).frame(width: 6, height: 6)
                    }

                    HStack(spacing: 8) {
                        miniPill(shot.cameraAngle)
                        if let lens = shot.lensMm { miniPill("\(lens)mm") }
                        if shot.movement != "Static" { miniPill(shot.movement) }
                    }

                    if !shot.description.isEmpty {
                        Text(shot.description)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(10)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hasCallback {
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
    }

    @ViewBuilder
    private func shotThumbnail(_ shot: Shot) -> some View {
        if let previewPath = shot.previewImage, !previewPath.isEmpty,
           let basePath = projectBasePath {
            let fullURL = basePath.appendingPathComponent(previewPath)
            AsyncImage(url: fullURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 90)
                        .clipped()
                case .failure:
                    shotThumbnailPlaceholder
                case .empty:
                    shotThumbnailPlaceholder
                        .overlay(ProgressView().scaleEffect(0.5))
                @unknown default:
                    shotThumbnailPlaceholder
                }
            }
        } else {
            shotThumbnailPlaceholder
        }
    }

    private var shotThumbnailPlaceholder: some View {
        Rectangle()
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .frame(height: 90)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(nsColor: .separatorColor))
                    Text("No Preview")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
            )
    }

    private func miniPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundColor(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(nsColor: .separatorColor).opacity(0.3))
            .cornerRadius(3)
    }

    // MARK: - Characters Card (Sidebar)

    private var charactersCard: some View {
        let charNames = SceneCardHelpers.sceneCharacters(scene: scene)
        return Group {
            if !charNames.isEmpty {
                SidebarCard(title: "Characters", icon: "person.2") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(charNames, id: \.self) { name in
                            let character = characters.first { $0.name == name }
                            HStack(spacing: 8) {
                                CharacterAvatarView(
                                    character: character,
                                    characterName: name,
                                    size: 28,
                                    projectBasePath: projectBasePath
                                )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if let role = character?.role, !role.isEmpty {
                                        Text(role)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                // Dialogue count for this character
                                let dialogueCount = scene.dialogues.filter { $0.character == name }.count
                                if dialogueCount > 0 {
                                    Text("\(dialogueCount)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(nsColor: .separatorColor).opacity(0.3))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Emotions Card (Sidebar)

    private var emotionsCard: some View {
        Group {
            if let analysis = scene.sceneEmotionalAnalysis, !analysis.isEmpty {
                let sorted = analysis.sorted { $0.value > $1.value }
                let maxVal = sorted.first?.value ?? 1.0

                SidebarCard(title: "Emotional Tone", icon: "heart.text.clipboard") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(sorted, id: \.key) { emotion, value in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(emotion.capitalized)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(String(format: "%.0f%%", value * 100))
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(nsColor: .separatorColor).opacity(0.2))
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(SceneCardHelpers.emotionColor(emotion))
                                            .frame(width: max(4, geo.size.width * (value / maxVal)))
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Props Card (Sidebar)

    private var propsCard: some View {
        Group {
            if !scene.props.isEmpty {
                SidebarCard(title: "Props", icon: "cube") {
                    FlowLayout(spacing: 4) {
                        ForEach(scene.props, id: \.self) { prop in
                            Text(prop)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notes Card (Sidebar)

    private var notesCard: some View {
        let hasNotes = !scene.sceneNotes.isEmpty || !scene.soundNotes.isEmpty
        return Group {
            if hasNotes {
                SidebarCard(title: "Notes", icon: "note.text") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(scene.sceneNotes) { note in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                                    .padding(.top, 3)
                                Text(note.content)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        ForEach(scene.soundNotes) { note in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.purple)
                                    .padding(.top, 3)
                                Text(note.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Image Loading & Generation

    private func loadHeroImage() {
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

    private func generateOverviewImage(with customPrompt: String? = nil) {
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

    private func generateOverviewWithAnnotations(_ annotations: [KeyframeAnnotation]) {
        let editPrompt = ImageAnnotationEditor.buildEditPrompt(from: annotations, context: "scene preview")
        let basePrompt = lastUsedPrompt.isEmpty ? SceneCardHelpers.buildSceneOverviewPrompt(scene: scene) : lastUsedPrompt
        let combinedPrompt = editPrompt + "\n\nOriginal prompt: " + basePrompt
        generateOverviewImage(with: combinedPrompt)
    }

    // MARK: - Download

    private func downloadImage() {
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

// MARK: - Reusable Card Components

/// Card for the main content column (left side)
private struct DetailCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

/// Card for the sidebar column (right side) — more compact
private struct SidebarCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
        }

        return (CGSize(width: totalWidth, height: y + rowHeight), positions)
    }
}
