//
//  PlaybackMetadataSidebar.swift
//  DirectorsChair-Desktop
//
//  Full production metadata sidebar showing current shot details,
//  scene info, takes, props, sound, and linked script items.
//  Double-click any card to navigate to the corresponding view.
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairViews

struct PlaybackMetadataSidebar: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                if let item = viewModel.currentItem {
                    charactersCard
                    locationsCard
                    costumesCard
                    currentShotCard(item)
                    sceneCard
                    takesCard(item)
                    propsCard
                    soundCard
                    scriptCard
                } else {
                    emptyState
                }
            }
            .padding(14)
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Current Shot Card

    private func currentShotCard(_ item: PlaybackItem) -> some View {
        MetadataCard(icon: "camera.fill", title: "CURRENT SHOT") {
            VStack(alignment: .leading, spacing: 8) {
                if let shotId = item.shotId {
                    metadataRow("Shot", value: "\(shotId)")
                }
                metadataRow("Type", value: item.shotType)
                metadataRow("Angle", value: item.cameraAngle)
                if let lens = item.lensMm {
                    metadataRow("Lens", value: "\(lens)mm")
                }
                metadataRow("Movement", value: item.movement, icon: TimelineDefaultColors.iconForMovement(item.movement))
                if item.duration > 0 {
                    metadataRow("Duration", value: String(format: "%.1fs", item.duration))
                }
                if !item.description.isEmpty {
                    Divider().opacity(0.3)
                    Text(item.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
            }
        }
        .onTapGesture(count: 2) {
            navigateToShot(item)
        }
    }

    // MARK: - Scene Card

    private var sceneCard: some View {
        MetadataCard(icon: "film", title: "SCENE") {
            if let scene = viewModel.currentScene {
                VStack(alignment: .leading, spacing: 8) {
                    metadataRow("Name", value: scene.name)
                    if let location = scene.location, !location.isEmpty {
                        metadataRow("Location", value: location, icon: "mappin")
                    }
                    metadataRow("Status", value: scene.productionStatus, icon: "circle.fill")
                    metadataRow("Shots", value: "\(scene.shots.count)")
                    metadataRow("Dialogues", value: "\(scene.dialogues.count)")

                    // Characters in scene
                    let characters = Array(Set(scene.dialogues.map { $0.character })).sorted()
                    if !characters.isEmpty {
                        Divider().opacity(0.3)
                        Text("CHARACTERS")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1.0)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 4) {
                            ForEach(characters, id: \.self) { character in
                                Text(character)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.6))
                                    .cornerRadius(10)
                            }
                        }
                    }

                    if !scene.description.isEmpty {
                        Divider().opacity(0.3)
                        Text(scene.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                }
            } else {
                Text("No scene")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .onTapGesture(count: 2) {
            navigateToScene()
        }
    }

    // MARK: - Takes Card

    private func takesCard(_ item: PlaybackItem) -> some View {
        MetadataCard(icon: "film.stack", title: "TAKES") {
            if let shot = item.shot, !shot.takes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    metadataRow("Total Takes", value: "\(shot.takes.count)")
                    let circled = shot.circledTakes.count
                    if circled > 0 {
                        metadataRow("Circled", value: "\(circled)", icon: "checkmark.circle.fill")
                    }
                    if let provider = shot.videoProvider, !provider.isEmpty {
                        metadataRow("Provider", value: provider)
                    }
                    if let quality = shot.videoQuality, !quality.isEmpty {
                        metadataRow("Quality", value: quality)
                    }
                }
            } else {
                Text("No takes recorded")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .onTapGesture(count: 2) {
            coordinator.scrollToShotSection = "takes"
            navigateToShot(item)
        }
    }

    // MARK: - Props Card

    private var propsCard: some View {
        MetadataCard(icon: "archivebox", title: "PROPS") {
            if let scene = viewModel.currentScene, !scene.props.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(scene.props, id: \.self) { prop in
                        Text(prop)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(8)
                    }
                }
            } else {
                Text("No props listed")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .onTapGesture(count: 2) {
            navigateToScene()
        }
    }

    // MARK: - Sound Card

    private var soundCard: some View {
        MetadataCard(icon: "speaker.wave.2", title: "SOUND") {
            if let scene = viewModel.currentScene, !scene.soundNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(scene.soundNotes, id: \.uuid) { note in
                        HStack(spacing: 6) {
                            let icon: String = {
                                switch note.soundType {
                                case "music": return "music.note"
                                case "effects", "dialogue_sfx": return "speaker.wave.2"
                                default: return "speaker.wave.2"
                                }
                            }()
                            Image(systemName: icon)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(note.description)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                    }
                }
            } else {
                Text("No sound notes")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .onTapGesture(count: 2) {
            navigateToScene()
        }
    }

    // MARK: - Script Card

    private var scriptCard: some View {
        MetadataCard(icon: "text.alignleft", title: "SCRIPT") {
            let hasContent = !viewModel.currentLinkedDialogues.isEmpty ||
                            !viewModel.currentLinkedActions.isEmpty ||
                            !viewModel.currentLinkedNarrations.isEmpty

            if hasContent {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.currentLinkedDialogues) { dialogue in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dialogue.character.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(Color.accentColor)
                            Text(DurationEstimator.htmlToPlainText(dialogue.text))
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                                .lineLimit(4)
                        }
                    }
                    ForEach(viewModel.currentLinkedActions) { action in
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                            Text(action.description)
                                .font(.system(size: 11, weight: .regular))
                                .italic()
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    ForEach(viewModel.currentLinkedNarrations) { narration in
                        HStack(spacing: 4) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 9))
                                .foregroundStyle(.purple)
                            Text(DurationEstimator.htmlToPlainText(narration.text))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
            } else {
                Text("No linked script items")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .onTapGesture(count: 2) {
            navigateToScript()
        }
    }

    // MARK: - Characters Card

    private var charactersCard: some View {
        let characterNames = sceneCharacterNames
        return MetadataCard(icon: "person.2.fill", title: "CHARACTERS") {
            if !characterNames.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(characterNames, id: \.self) { name in
                        let matched = projectViewModel.project.characters.first { $0.name.lowercased() == name.lowercased() }
                        Button {
                            viewModel.pause()
                            if let character = matched {
                                coordinator.selectCharacter(character)
                            } else {
                                coordinator.selectedCharacter = nil
                                coordinator.selectedLocation = nil
                                coordinator.navigateTo(.storyDesign)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 8))
                                Text(name)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("No characters in scene")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Locations Card

    private var locationsCard: some View {
        let locationInfo = resolvedLocation
        return MetadataCard(icon: "mappin.and.ellipse", title: "LOCATIONS") {
            if let info = locationInfo {
                Button {
                    viewModel.pause()
                    if let location = info.location {
                        coordinator.preferredStoryDesignMode = nil
                        coordinator.selectLocation(location)
                    } else {
                        coordinator.selectedCharacter = nil
                        coordinator.selectedLocation = nil
                        coordinator.preferredStoryDesignMode = "locations"
                        coordinator.navigateTo(.storyDesign)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 8))
                        Text(info.displayName)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            } else {
                Text("No location set")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Costumes Card

    private var costumesCard: some View {
        let costumePairs = sceneCostumePairs
        return MetadataCard(icon: "tshirt.fill", title: "COSTUMES") {
            if !costumePairs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(costumePairs, id: \.character.name) { pair in
                        Button {
                            viewModel.pause()
                            coordinator.selectCharacter(pair.character)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "tshirt")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pair.character.name)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(pair.costumeName)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("No costumes defined")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No playback data")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Add shots to your scenes to preview them here.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Navigation

    private func navigateToShot(_ item: PlaybackItem) {
        guard let shot = item.shot,
              let scene = viewModel.currentScene else { return }
        viewModel.pause()
        coordinator.selectScene(scene)
        coordinator.selectShot(shot)
        coordinator.navigateTo(.shotList)
    }

    private func navigateToScene() {
        guard let scene = viewModel.currentScene else { return }
        viewModel.pause()
        coordinator.selectScene(scene)
        coordinator.navigateTo(.scenes)
    }

    private func navigateToScript() {
        guard let item = viewModel.currentItem else { return }
        viewModel.pause()
        if let dialogueId = item.linkedDialogueIds.first {
            coordinator.jumpToScriptElement(itemId: dialogueId, itemType: "dialogue")
        } else if let actionId = item.linkedActionIds.first {
            coordinator.jumpToScriptElement(itemId: actionId, itemType: "action")
        } else if let narrationId = item.linkedNarrationIds.first {
            coordinator.jumpToScriptElement(itemId: narrationId, itemType: "narration")
        } else if let scene = viewModel.currentScene {
            coordinator.selectScene(scene)
            coordinator.navigateTo(.script)
        }
    }

    // MARK: - Helpers

    /// All unique character names from the current scene's dialogues/actions/narrations
    private var sceneCharacterNames: [String] {
        guard let scene = viewModel.currentScene else { return [] }
        var names = Set<String>()
        for d in scene.dialogues { names.insert(d.character) }
        for a in scene.actions { for c in a.characters where !c.isEmpty { names.insert(c) } }
        for n in scene.narrations { for c in n.characters where !c.isEmpty { names.insert(c) } }
        return names.sorted()
    }

    /// Characters in the scene paired with their costume info (from character costumes or project costumes)
    private var sceneCostumePairs: [(character: Character, costumeName: String)] {
        let names = sceneCharacterNames
        var pairs: [(character: Character, costumeName: String)] = []
        for name in names {
            if let character = projectViewModel.project.characters.first(where: { $0.name.lowercased() == name.lowercased() }) {
                // Check CharacterCostume array first
                if let costumes = character.costumes, !costumes.isEmpty {
                    let activeIdx = character.activeCostumeIndex ?? 0
                    let costume = costumes[min(activeIdx, costumes.count - 1)]
                    pairs.append((character: character, costumeName: costume.name))
                }
                // Then check legacy single costume description
                else if let costume = character.costume, !costume.isEmpty {
                    pairs.append((character: character, costumeName: costume))
                }
                // Then check project-level Costume objects linked to this character
                else if let projectCostume = projectViewModel.project.costumes.first(where: { $0.character?.lowercased() == name.lowercased() }) {
                    pairs.append((character: character, costumeName: projectCostume.name))
                }
            }
        }
        return pairs
    }

    /// Try to find a project Location by flexible matching against a name string
    private func findMatchingLocation(_ name: String) -> Location? {
        let nameLower = name.lowercased()
        let locations = projectViewModel.project.locations

        // Exact match
        if let loc = locations.first(where: { $0.name.lowercased() == nameLower }) {
            return loc
        }
        // Location name contains the search name, or vice versa
        if let loc = locations.first(where: { $0.name.lowercased().contains(nameLower) || nameLower.contains($0.name.lowercased()) }) {
            return loc
        }
        // Word overlap: any significant word from the name appears in a location name
        let words = nameLower.components(separatedBy: .whitespaces).filter { $0.count > 2 }
        for word in words {
            if let loc = locations.first(where: { $0.name.lowercased().contains(word) }) {
                return loc
            }
        }
        return nil
    }

    /// Resolve location from scene.location, scene name, or project locations
    private var resolvedLocation: (displayName: String, location: Location?)? {
        guard let scene = viewModel.currentScene else { return nil }

        // 1. Direct scene.location field
        if let locationName = scene.location, !locationName.isEmpty {
            return (displayName: locationName, location: findMatchingLocation(locationName))
        }

        // 2. Try matching project locations by name appearing in scene name
        let sceneNameLower = scene.name.lowercased()
        for location in projectViewModel.project.locations {
            if sceneNameLower.contains(location.name.lowercased()) {
                return (displayName: location.name, location: location)
            }
        }

        // 3. Try parsing slug line from scene name (e.g. "Scene 3 - INT. KITCHEN - DAY")
        let pattern = #"(?:INT\.|EXT\.|INT/EXT\.)\s*(.+?)(?:\s*-\s*(?:DAY|NIGHT|DAWN|DUSK|MORNING|EVENING|CONTINUOUS|LATER))?$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: scene.name, range: NSRange(scene.name.startIndex..., in: scene.name)),
           let range = Range(match.range(at: 1), in: scene.name) {
            let locationName = String(scene.name[range]).trimmingCharacters(in: .whitespaces)
            if !locationName.isEmpty {
                return (displayName: locationName, location: findMatchingLocation(locationName))
            }
        }

        // 4. Try matching scene name words against project locations
        let sceneWords = sceneNameLower.components(separatedBy: .whitespaces).filter { $0.count > 2 }
        for location in projectViewModel.project.locations {
            let locWords = location.name.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 2 }
            if !locWords.isEmpty && locWords.contains(where: { sceneWords.contains($0) }) {
                return (displayName: location.name, location: location)
            }
        }

        return nil
    }

    private func metadataRow(_ label: String, value: String, icon: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - MetadataCard

struct MetadataCard<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3))
        )
    }
}
