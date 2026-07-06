//
// SceneDetailView+Cards.swift
//
// Extracted from SceneDetailView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairServices

extension SceneDetailView {

    // MARK: - Main Content (Two Columns)

    var mainContent: some View {
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


    var aboutCard: some View {
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

    func initAboutFields() {
        editAbout = scene.sceneOverviewSummary ?? ""
        editDescription = scene.description
        editNotes = scene.notes
    }

    func inlineTextField(
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

    func locationContextRows(_ context: [String: String]) -> some View {
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

    var scriptPreviewCard: some View {
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

    func dialoguePreviewRow(_ dialogue: Dialogue) -> some View {
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

    var shotsCard: some View {
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

    func miniShotCard(_ shot: Shot) -> some View {
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
    func shotThumbnail(_ shot: Shot) -> some View {
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

    var shotThumbnailPlaceholder: some View {
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

    func miniPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundColor(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(nsColor: .separatorColor).opacity(0.3))
            .cornerRadius(3)
    }

    // MARK: - Characters Card (Sidebar)

    var charactersCard: some View {
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

    var emotionsCard: some View {
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

    var propsCard: some View {
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

    var notesCard: some View {
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
}
