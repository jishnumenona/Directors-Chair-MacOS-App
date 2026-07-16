//
// ShotVideoGenerationSection+ShotContext.swift
//
// Extracted from ShotVideoGenerationSection.swift (WS9.1 god-file decomposition).
// Behaviour unchanged.
//

import SwiftUI
import AVKit
import AppKit
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Shot Context Card

struct ShotContextCard: View {
    let shot: Shot
    let scene: DCScene?
    let characters: [Character]
    let locations: [Location]
    let projectBasePath: URL?
    /// False when hosted inside a CollapsibleCard, which supplies the title.
    var showsHeader: Bool = true
    var onNavigateToCharacter: ((Character) -> Void)?
    var onNavigateToLocation: ((Location) -> Void)?
    var onNavigateToStoryDesign: (() -> Void)?
    var onSceneUpdated: ((DCScene) -> Void)?

    @State private var showingCharacterPicker = false
    @State private var showingPropInput = false
    @State private var newPropName = ""
    @State private var showingSoundInput = false
    @State private var newSoundDescription = ""
    @State private var newSoundType = "effects"
    @State private var editingSoundId: String? = nil
    @State private var editingSoundText: String = ""
    @State private var isDetecting = false
    @State private var showingLocationPicker = false
    @State private var showingLocationInput = false
    @State private var newLocationName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header (title omitted when the hosting card provides it)
            HStack(spacing: 8) {
                if showsHeader {
                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text("SHOT CONTEXT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()

                Button(action: { Task { await detectFromScript() } }) {
                    HStack(spacing: 4) {
                        if isDetecting {
                            ProgressView()
                                .controlSize(.mini)
                                .scaleEffect(0.6)
                                .frame(width: 10, height: 10)
                            Text("Detecting...")
                                .font(.system(size: 9, weight: .medium))
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 9))
                            Text("Detect from Script")
                                .font(.system(size: 9, weight: .medium))
                        }
                    }
                    .foregroundColor(.accentColor.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isDetecting || scene == nil)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Characters
                if let currentScene = scene {
                    let charNames = resolveAllCharacterNames(scene: currentScene)
                    contextSection(icon: "person.2.fill", iconColor: .blue, title: "CHARACTERS") {
                        VideoContextFlowLayout(spacing: 8) {
                            ForEach(charNames, id: \.self) { name in
                                characterChip(name: name)
                            }
                            addButton { showingCharacterPicker = true }
                        }
                    }

                    // Costumes — click to assign what each character wears in THIS scene
                    let allCostumes = charNames.flatMap { name -> [(Character, CharacterCostume)] in
                        guard let char = characters.first(where: { $0.name == name }),
                              let costumes = char.costumes else { return [] }
                        return costumes.map { (char, $0) }
                    }
                    if !allCostumes.isEmpty {
                        contextSection(icon: "tshirt.fill", iconColor: .purple, title: "WARDROBE (THIS SCENE)") {
                            VStack(alignment: .leading, spacing: 6) {
                                VideoContextFlowLayout(spacing: 8) {
                                    ForEach(allCostumes, id: \.1.id) { char, costume in
                                        costumeChip(character: char, costume: costume)
                                    }
                                }
                                Text("Click a costume to assign it for this scene — prompts and reference images follow the assignment.")
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                    }

                    // Location
                    contextSection(icon: "mappin.and.ellipse", iconColor: .green, title: "LOCATION") {
                        VideoContextFlowLayout(spacing: 8) {
                            if let loc = currentScene.location, !loc.isEmpty {
                                deletableLocationChip(locationName: loc)
                            } else if showingLocationInput {
                                locationInputField
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.slash")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray.opacity(0.4))
                                    Text("No location set")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                                if !locations.isEmpty {
                                    addButton { showingLocationPicker = true }
                                } else {
                                    addButton { showingLocationInput = true }
                                }
                            }
                        }
                    }

                    // Props
                    contextSection(icon: "cube.fill", iconColor: .orange, title: "PROPS") {
                        VideoContextFlowLayout(spacing: 8) {
                            ForEach(currentScene.props, id: \.self) { prop in
                                deletablePropChip(prop: prop)
                            }
                            if currentScene.props.isEmpty && !showingPropInput {
                                HStack(spacing: 4) {
                                    Image(systemName: "cube.transparent")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray.opacity(0.4))
                                    Text("No props")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                            }
                            if showingPropInput {
                                propInputField
                            } else {
                                addButton { showingPropInput = true }
                            }
                        }
                    }

                    // Sounds
                    contextSection(icon: "speaker.wave.2.fill", iconColor: .pink, title: "SOUNDS") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(currentScene.soundNotes) { sound in
                                deletableSoundRow(sound: sound)
                            }
                            if currentScene.soundNotes.isEmpty && !showingSoundInput {
                                HStack(spacing: 4) {
                                    Image(systemName: "speaker.slash")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray.opacity(0.4))
                                    Text("No sounds")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                            }
                            if showingSoundInput {
                                soundInputField
                            } else {
                                addButton { showingSoundInput = true }
                            }
                        }
                    }

                    // Linked Dialogue
                    let linkedDialogues = shot.linkedDialogueIds.compactMap { id in
                        currentScene.dialogues.first(where: { $0.id == id })
                    }
                    if !linkedDialogues.isEmpty {
                        contextSection(icon: "text.bubble.fill", iconColor: .cyan, title: "DIALOGUE") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(linkedDialogues.prefix(4)) { d in
                                    dialogueRow(dialogue: d)
                                }
                            }
                        }
                    }

                    // Linked Actions
                    let linkedActions = shot.linkedActionIds.compactMap { id in
                        currentScene.actions.first(where: { $0.id == id })
                    }
                    if !linkedActions.isEmpty {
                        contextSection(icon: "figure.walk", iconColor: .yellow, title: "ACTIONS") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(linkedActions.prefix(3)) { a in
                                    actionRow(action: a)
                                }
                            }
                        }
                    }
                }

                // Camera (always present)
                contextSection(icon: "camera.fill", iconColor: .white, title: "CAMERA") {
                    VideoContextFlowLayout(spacing: 8) {
                        cameraChip(icon: "camera.viewfinder", text: "\(shot.shotType), \(shot.cameraAngle)")
                        if let lens = shot.lensMm {
                            cameraChip(icon: "circle.dotted", text: "\(lens)mm \(shot.aperture)")
                        }
                        if shot.movement != "Static" {
                            cameraChip(icon: "arrow.left.and.right", text: shot.movement)
                        }
                    }
                }
            }
        }
        .padding(showsHeader ? 16 : 0)
        .background(
            Group {
                if showsHeader {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#222222"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#333333"), lineWidth: 1)
                        )
                }
            }
        )
        .popover(isPresented: $showingCharacterPicker) {
            characterPickerPopover
        }
        .popover(isPresented: $showingLocationPicker) {
            locationPickerPopover
        }
    }

    // MARK: - Scene Mutation Helpers

    private func setLocation(_ name: String) {
        guard var updated = scene else { return }
        updated.location = name
        onSceneUpdated?(updated)
    }

    private func removeProp(_ prop: String) {
        guard var updated = scene else { return }
        updated.props.removeAll { $0 == prop }
        onSceneUpdated?(updated)
    }

    private func addProp(_ name: String) {
        guard var updated = scene, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !updated.props.contains(trimmed) {
            updated.props.append(trimmed)
            onSceneUpdated?(updated)
        }
    }

    private func removeLocation() {
        guard var updated = scene else { return }
        updated.location = nil
        onSceneUpdated?(updated)
    }

    private func removeSound(_ soundId: String) {
        guard var updated = scene else { return }
        updated.soundNotes.removeAll { $0.id == soundId }
        onSceneUpdated?(updated)
    }

    private func addSound(description: String, type: String) {
        guard var updated = scene, !description.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let nextChronology = (updated.soundNotes.map { $0.chronologyNumber }.max() ?? 0) + 1
        let sound = SoundNote(
            description: description.trimmingCharacters(in: .whitespaces),
            soundType: type,
            chronologyNumber: nextChronology
        )
        updated.soundNotes.append(sound)
        onSceneUpdated?(updated)
    }

    private func updateSoundDescription(_ soundId: String, newDescription: String) {
        guard var updated = scene else { return }
        if let idx = updated.soundNotes.firstIndex(where: { $0.id == soundId }) {
            updated.soundNotes[idx].description = newDescription
            onSceneUpdated?(updated)
        }
    }

    // MARK: - Detect from Script

    private func detectFromScript() async {
        guard let currentScene = scene else { return }

        await MainActor.run { isDetecting = true }

        // Context parts (always included)
        var contextParts: [String] = []
        if !shot.description.isEmpty {
            contextParts.append("Shot description: \(shot.description)")
        }
        contextParts.append("Scene: \(currentScene.name)")
        if !currentScene.description.isEmpty {
            contextParts.append("Scene description: \(currentScene.description)")
        }
        if let existingLocation = currentScene.location, !existingLocation.isEmpty {
            contextParts.append("Current scene location: \(existingLocation)")
        }

        // Gather linked script text for this shot
        var linkedParts: [String] = []
        for dialogueId in shot.linkedDialogueIds {
            if let dialogue = currentScene.dialogues.first(where: { $0.id == dialogueId }) {
                linkedParts.append("\(dialogue.character.uppercased())\n\(dialogue.text)")
            }
        }
        for actionId in shot.linkedActionIds {
            if let action = currentScene.actions.first(where: { $0.id == actionId }) {
                linkedParts.append(action.description)
            }
        }
        for narrationId in shot.linkedNarrationIds {
            if let narration = currentScene.narrations.first(where: { $0.id == narrationId }) {
                linkedParts.append("(V.O.) \(narration.text)")
            }
        }

        // Fallback to entire scene script if no linked elements
        if linkedParts.isEmpty {
            for dialogue in currentScene.dialogues {
                linkedParts.append("\(dialogue.character.uppercased())\n\(dialogue.text)")
            }
            for action in currentScene.actions {
                linkedParts.append(action.description)
            }
            for narration in currentScene.narrations {
                linkedParts.append("(V.O.) \(narration.text)")
            }
        }

        let allParts = contextParts + linkedParts
        guard !allParts.isEmpty else {
            await MainActor.run { isDetecting = false }
            return
        }

        let scriptText = allParts.joined(separator: "\n\n")

        let prompt = """
        Analyze the following screenplay excerpt. Extract exactly these three things:

        1. "characters" — Names of all characters present, speaking, or mentioned
        2. "location" — The filming location. Look at the scene name for slug lines (e.g. "Scene 3 - INT. KITCHEN - DAY"). If the scene name contains INT./EXT., extract it. Also infer from action descriptions and shot description.
        3. "props" — Physical objects, weapons, vehicles, or items characters interact with

        Text to analyze:
        ---
        \(scriptText)
        ---

        IMPORTANT: You MUST respond with ONLY a raw JSON object (no markdown, no code fences, no explanation):
        {"characters": ["Name1", "Name2"], "location": "INT. PLACE - TIME", "props": ["item1", "item2"]}
        """

        // Ensure auth token is set (tokenProvider may fail off-main-actor)
        if let token = await AIServiceClient.shared.tokenProvider?() {
            await AIServiceClient.shared.setAuthToken(token)
        }

        do {
            let request = TextGenerationRequest(
                prompt: prompt,
                provider: .google,
                maxTokens: 2000,
                temperature: 0.1,
                systemPrompt: "You extract structured data from screenplay text. Output raw JSON only, never markdown code fences."
            )
            let response = try await AIServiceClient.shared.generateText(request)

            // Strip markdown code fences if present
            var jsonText = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonText.hasPrefix("```") {
                let lines = jsonText.components(separatedBy: "\n")
                let inner = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
                jsonText = inner.joined(separator: "\n")
            }
            if jsonText.hasSuffix("```") {
                jsonText = String(jsonText.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Try parsing JSON, with recovery for truncated responses
            var json: [String: Any]?
            if let data = jsonText.data(using: .utf8) {
                json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
            // If parsing failed, try to repair truncated JSON
            if json == nil {
                var repaired = jsonText
                let quoteCount = repaired.filter { $0 == "\"" }.count
                if quoteCount % 2 != 0 { repaired += "\"" }
                let openBrackets = repaired.filter { $0 == "[" }.count
                let closeBrackets = repaired.filter { $0 == "]" }.count
                for _ in 0..<(openBrackets - closeBrackets) { repaired += "]" }
                let openBraces = repaired.filter { $0 == "{" }.count
                let closeBraces = repaired.filter { $0 == "}" }.count
                for _ in 0..<(openBraces - closeBraces) { repaired += "}" }
                if let data = repaired.data(using: .utf8) {
                    json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                }
            }
            guard let json = json else {
                var updated = currentScene
                if let slug = parseSlugLineFromSceneName(currentScene.name) {
                    updated.location = slug
                    await MainActor.run {
                        onSceneUpdated?(updated)
                        isDetecting = false
                    }
                } else {
                    await MainActor.run { isDetecting = false }
                }
                return
            }

            var updated = currentScene

            // Update location
            if let location = json["location"] as? String,
               !location.isEmpty,
               !location.lowercased().contains("not specified"),
               !location.lowercased().contains("unknown"),
               !location.lowercased().contains("n/a") {
                updated.location = location
            }

            // Fallback: parse slug line from scene name
            if updated.location == nil || updated.location?.isEmpty == true {
                if let slug = parseSlugLineFromSceneName(currentScene.name) {
                    updated.location = slug
                }
            }

            // Merge props (add new, keep existing)
            if let props = json["props"] as? [String] {
                let existingLower = Set(updated.props.map { $0.lowercased() })
                for prop in props {
                    let trimmed = prop.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && !existingLower.contains(trimmed.lowercased()) {
                        updated.props.append(trimmed)
                    }
                }
            }

            // Merge characters — add detected names to a linked action's character list
            if let detectedChars = json["characters"] as? [String] {
                let existingChars = Set(resolveAllCharacterNames(scene: currentScene))
                let newChars = detectedChars.filter { !$0.isEmpty && !existingChars.contains($0) }

                if !newChars.isEmpty {
                    let actionIndex: Int?
                    if let firstLinkedId = shot.linkedActionIds.first {
                        actionIndex = updated.actions.firstIndex(where: { $0.id == firstLinkedId })
                    } else {
                        actionIndex = updated.actions.indices.first
                    }
                    if let idx = actionIndex {
                        for name in newChars {
                            if !updated.actions[idx].characters.contains(name) {
                                updated.actions[idx].characters.append(name)
                            }
                        }
                    }
                }
            }

            await MainActor.run {
                onSceneUpdated?(updated)
                isDetecting = false
            }

        } catch {
            var updated = currentScene
            if let slug = parseSlugLineFromSceneName(currentScene.name) {
                updated.location = slug
                await MainActor.run {
                    onSceneUpdated?(updated)
                    isDetecting = false
                }
            } else {
                await MainActor.run { isDetecting = false }
            }
        }
    }

    // MARK: - Section Builder

    @ViewBuilder
    private func contextSection<Content: View>(icon: String, iconColor: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.gray)
            }
            content()
        }
    }

    // MARK: - Character Chip

    @ViewBuilder
    private func characterChip(name: String) -> some View {
        let char = characters.first(where: { $0.name == name })
        // Character is removable only if they come from action character lists, not dialogue speakers
        let speaksDialogue = scene?.dialogues.contains(where: { $0.character == name }) ?? false

        HStack(spacing: 0) {
            Button(action: {
                if let char = char { onNavigateToCharacter?(char) }
            }) {
                HStack(spacing: 6) {
                    // Thumbnail
                    if let char = char, let basePath = projectBasePath {
                        let imgPath = char.imageFront ?? char.baseImage ?? char.avatar
                        if let path = imgPath, let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 22, height: 22)
                                .clipShape(Circle())
                        } else {
                            defaultCircleIcon(icon: "person.fill", color: .blue)
                        }
                    } else {
                        defaultCircleIcon(icon: "person.fill", color: .blue)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        if let char = char {
                            Text("\(char.gender), \(char.age)")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 7))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            if !speaksDialogue {
                Button(action: { removeCharacterFromScene(name) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.leading, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.blue.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.15), lineWidth: 1))
        .cornerRadius(8)
    }

    // MARK: - Costume Chip (scene wardrobe assignment)

    /// Whether this costume is the one the character wears in this scene.
    private func isAssigned(_ costume: CharacterCostume, for character: Character) -> Bool {
        scene?.costumeAssignments?[character.name] == costume.costumeId
    }

    /// Toggle the scene's wardrobe assignment for a character.
    private func toggleCostumeAssignment(_ costume: CharacterCostume, for character: Character) {
        guard var updated = scene else { return }
        var assignments = updated.costumeAssignments ?? [:]
        if assignments[character.name] == costume.costumeId {
            assignments.removeValue(forKey: character.name)
        } else {
            assignments[character.name] = costume.costumeId
        }
        updated.costumeAssignments = assignments.isEmpty ? nil : assignments
        onSceneUpdated?(updated)
    }

    @ViewBuilder
    private func costumeChip(character: Character, costume: CharacterCostume) -> some View {
        let assigned = isAssigned(costume, for: character)

        Button(action: { toggleCostumeAssignment(costume, for: character) }) {
            HStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    if let basePath = projectBasePath, let path = costume.imageFront,
                       let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        defaultSquareIcon(icon: "tshirt", color: .purple)
                    }
                    if assigned {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                            .background(Circle().fill(Color.black).frame(width: 8, height: 8))
                            .offset(x: 3, y: 3)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(costume.name)
                        .font(.system(size: 10, weight: assigned ? .semibold : .medium))
                        .foregroundColor(.white.opacity(assigned ? 1.0 : 0.9))
                        .lineLimit(1)
                    Text(assigned ? "\(character.name) — worn in scene" : character.name)
                        .font(.system(size: 8))
                        .foregroundColor(assigned ? .green.opacity(0.8) : .gray)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(assigned ? Color.green.opacity(0.10) : Color.purple.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(assigned ? Color.green.opacity(0.45) : Color.purple.opacity(0.15),
                        lineWidth: assigned ? 1.5 : 1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help(assigned ? "Worn in this scene — click to unassign"
                       : "Click to assign for this scene")
        .contextMenu {
            Button(action: { onNavigateToCharacter?(character) }) {
                Label("Open in Story Design", systemImage: "person.crop.square")
            }
        }
    }

    // MARK: - Deletable Location Chip

    @ViewBuilder
    private func deletableLocationChip(locationName: String) -> some View {
        let location = locations.first(where: { $0.name == locationName })

        HStack(spacing: 0) {
            Button(action: {
                if let loc = location { onNavigateToLocation?(loc) }
            }) {
                HStack(spacing: 6) {
                    if let loc = location, let basePath = projectBasePath,
                       let path = loc.primaryImage ?? loc.images.first,
                       let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        defaultSquareIcon(icon: "mappin", color: .green)
                    }

                    Text(locationName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 7))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            Button(action: { removeLocation() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.leading, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.green.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.15), lineWidth: 1))
        .cornerRadius(8)
    }

    // MARK: - Deletable Prop Chip

    @ViewBuilder
    private func deletablePropChip(prop: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "cube")
                .font(.system(size: 9))
                .foregroundColor(.orange.opacity(0.7))
            Text(prop)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)

            Button(action: { removeProp(prop) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.orange.opacity(0.15), lineWidth: 1))
        .cornerRadius(7)
    }

    // MARK: - Prop Input Field

    private var propInputField: some View {
        HStack(spacing: 4) {
            Image(systemName: "cube.fill")
                .font(.system(size: 9))
                .foregroundColor(.orange.opacity(0.5))
            TextField("Prop name", text: $newPropName)
                .font(.system(size: 10))
                .textFieldStyle(.plain)
                .frame(width: 100)
                .onSubmit {
                    addProp(newPropName)
                    newPropName = ""
                    showingPropInput = false
                }
            Button(action: {
                addProp(newPropName)
                newPropName = ""
                showingPropInput = false
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(newPropName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button(action: {
                newPropName = ""
                showingPropInput = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.orange.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .cornerRadius(7)
    }

    // MARK: - Location Input Field

    private var locationInputField: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin")
                .font(.system(size: 9))
                .foregroundColor(.green.opacity(0.5))
            TextField("Location name", text: $newLocationName)
                .font(.system(size: 10))
                .textFieldStyle(.plain)
                .frame(width: 140)
                .onSubmit {
                    setLocation(newLocationName)
                    newLocationName = ""
                    showingLocationInput = false
                }
            Button(action: {
                setLocation(newLocationName)
                newLocationName = ""
                showingLocationInput = false
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(newLocationName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button(action: {
                newLocationName = ""
                showingLocationInput = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.green.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .cornerRadius(7)
    }

    // MARK: - Location Picker Popover

    private var locationPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set Location")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(locations) { loc in
                        Button(action: {
                            showingLocationPicker = false
                            setLocation(loc.name)
                        }) {
                            HStack(spacing: 8) {
                                if let basePath = projectBasePath,
                                   let path = loc.primaryImage ?? loc.images.first,
                                   let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 24, height: 24)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    defaultSquareIcon(icon: "mappin", color: .green)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(loc.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                    if !loc.locationType.isEmpty {
                                        Text(loc.locationType)
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider().opacity(0.3)

            Button(action: {
                showingLocationPicker = false
                showingLocationInput = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 10))
                    Text("Enter Custom Location")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 240)
        .background(Color(hex: "#2A2A2A"))
    }

    // MARK: - Deletable Sound Row

    @ViewBuilder
    private func deletableSoundRow(sound: SoundNote) -> some View {
        HStack(spacing: 8) {
            Image(systemName: soundIcon(sound.soundType))
                .font(.system(size: 10))
                .foregroundColor(.pink.opacity(0.7))
                .frame(width: 16)

            if editingSoundId == sound.id {
                TextField("Description", text: $editingSoundText)
                    .font(.system(size: 10))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        updateSoundDescription(sound.id, newDescription: editingSoundText)
                        editingSoundId = nil
                    }
                Button(action: {
                    updateSoundDescription(sound.id, newDescription: editingSoundText)
                    editingSoundId = nil
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green.opacity(0.8))
                }
                .buttonStyle(.plain)
            } else {
                Text(sound.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
                    .onTapGesture(count: 2) {
                        editingSoundId = sound.id
                        editingSoundText = sound.description
                    }
            }

            Spacer()

            Button(action: { removeSound(sound.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pink.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.pink.opacity(0.1), lineWidth: 1))
        .cornerRadius(7)
    }

    // MARK: - Sound Input Field

    private var soundInputField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                // Sound type selector
                Menu {
                    Button("Effects") { newSoundType = "effects" }
                    Button("Ambient") { newSoundType = "ambient" }
                    Button("Music") { newSoundType = "music" }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: soundIcon(newSoundType))
                            .font(.system(size: 9))
                        Text(newSoundType.capitalized)
                            .font(.system(size: 9, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 6))
                    }
                    .foregroundColor(.pink.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.1))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                TextField("Sound description", text: $newSoundDescription)
                    .font(.system(size: 10))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        addSound(description: newSoundDescription, type: newSoundType)
                        newSoundDescription = ""
                        showingSoundInput = false
                    }

                Button(action: {
                    addSound(description: newSoundDescription, type: newSoundType)
                    newSoundDescription = ""
                    showingSoundInput = false
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green.opacity(0.8))
                }
                .buttonStyle(.plain)
                .disabled(newSoundDescription.trimmingCharacters(in: .whitespaces).isEmpty)

                Button(action: {
                    newSoundDescription = ""
                    showingSoundInput = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pink.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.pink.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .cornerRadius(7)
    }

    // MARK: - Dialogue Row

    @ViewBuilder
    private func dialogueRow(dialogue: Dialogue) -> some View {
        let char = characters.first(where: { $0.name == dialogue.character })

        Button(action: {
            if let char = char { onNavigateToCharacter?(char) }
        }) {
            HStack(alignment: .top, spacing: 8) {
                // Mini avatar
                if let char = char, let basePath = projectBasePath,
                   let path = char.imageFront ?? char.baseImage ?? char.avatar,
                   let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text(String(dialogue.character.prefix(1)))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.cyan)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(dialogue.character)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.cyan)
                    Text("\"\(dialogue.text)\"")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                        .italic()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cyan.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.cyan.opacity(0.1), lineWidth: 1))
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Row

    @ViewBuilder
    private func actionRow(action: Action) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.yellow.opacity(0.7))
                .frame(width: 16, alignment: .center)
                .padding(.top, 2)
            Text(action.description)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.yellow.opacity(0.1), lineWidth: 1))
        .cornerRadius(7)
    }

    // MARK: - Camera Chip

    @ViewBuilder
    private func cameraChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .cornerRadius(7)
    }

    // MARK: - Add Button

    @ViewBuilder
    private func addButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .medium))
                Text("Add")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.accentColor.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.accentColor.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icon Helpers

    @ViewBuilder
    private func defaultCircleIcon(icon: String, color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.12))
            .frame(width: 22, height: 22)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color.opacity(0.7))
            )
    }

    @ViewBuilder
    private func defaultSquareIcon(icon: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(0.12))
            .frame(width: 22, height: 22)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color.opacity(0.7))
            )
    }

    // MARK: - Character Picker Popover

    private var characterPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Character")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 4)

            let existingNames = scene.map { resolveAllCharacterNames(scene: $0) } ?? []
            let availableChars = characters.filter { !existingNames.contains($0.name) }

            if availableChars.isEmpty {
                VStack(spacing: 8) {
                    Text("All characters are in this scene")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)

                    Button(action: {
                        showingCharacterPicker = false
                        onNavigateToStoryDesign?()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 10))
                            Text("Create New Character")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(availableChars) { char in
                            Button(action: {
                                showingCharacterPicker = false
                                onNavigateToCharacter?(char)
                            }) {
                                HStack(spacing: 8) {
                                    if let basePath = projectBasePath,
                                       let path = char.imageFront ?? char.baseImage ?? char.avatar,
                                       let img = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
                                        Image(nsImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 24, height: 24)
                                            .clipShape(Circle())
                                    } else {
                                        defaultCircleIcon(icon: "person.fill", color: .blue)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(char.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                        Text("\(char.gender), \(char.age)")
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 200)

                Divider().opacity(0.3)

                Button(action: {
                    showingCharacterPicker = false
                    onNavigateToStoryDesign?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 10))
                        Text("Create New Character")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 240)
        .background(Color(hex: "#2A2A2A"))
    }

    // MARK: - Helpers

    private func resolveAllCharacterNames(scene: DCScene) -> [String] {
        var names = Set<String>()
        for dialogue in scene.dialogues { names.insert(dialogue.character) }
        for action in scene.actions {
            for char in action.characters { names.insert(char) }
        }
        return Array(names).sorted()
    }

    private func soundIcon(_ type: String) -> String {
        switch type {
        case "music": return "music.note"
        case "ambient": return "waveform"
        case "effects": return "bolt.fill"
        default: return "speaker.wave.1"
        }
    }

    /// Parse a slug line from a scene name like "Scene 3 - INT. KITCHEN - DAY"
    private func parseSlugLineFromSceneName(_ name: String) -> String? {
        let upper = name.uppercased()
        for prefix in ["INT./EXT.", "INT/EXT.", "INT/EXT", "INT.", "EXT.", "INT ", "EXT "] {
            if let range = upper.range(of: prefix) {
                // Return from the prefix onwards
                return String(name[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Remove a character name from all action character lists in the scene
    private func removeCharacterFromScene(_ charName: String) {
        guard var updated = scene else { return }
        for i in updated.actions.indices {
            updated.actions[i].characters.removeAll { $0 == charName }
        }
        onSceneUpdated?(updated)
    }
}

// MARK: - Keyframe Prompt Sheet

struct KeyframePromptSheet: View {
    @Binding var prompt: String
    @Binding var isPresented: Bool
    let keyframeLabel: String
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.accentColor)
                Text("Generate \(keyframeLabel) Frame")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .foregroundColor(.gray)
            }

            Text("Edit the prompt below, then generate the keyframe image.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: $prompt)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(8)
                .frame(minHeight: 180)

            HStack {
                Spacer()
                Button(action: {
                    onGenerate()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12))
                        Text("Generate Keyframe")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 520, height: 380)
        .background(Color(hex: "#252525"))
    }
}
