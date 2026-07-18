//
// WardrobePlotTab.swift
//
// The character's Wardrobe tab — a costume PLOT, the industry document that
// maps a character to a costume for every scene they appear in. Design
// happens in the Costumes department tab; this tab answers the continuity
// question "what is this character wearing in scene N, at that location?".
// Assignments write to scene.costume_assignments and drive the AI prompts and
// reference collages everywhere (keyframes, previews, video).
//

import SwiftUI
import AppKit
import DirectorsChairCore

struct WardrobePlotTab: View {
    @Binding var character: Character
    @Binding var project: Project
    let projectBasePath: URL?
    /// Jump to the Costumes department tab to design a new look.
    var onOpenCostumeDepartment: (() -> Void)?

    // MARK: - Pure helpers (tested)

    /// Scenes in script order that feature the character (speaking or acting).
    static func scenesFeaturing(_ characterName: String, in scenes: [DCScene]) -> [DCScene] {
        scenes.filter { scene in
            ShotPromptBuilder.characterNames(in: scene).contains(characterName)
        }
    }

    /// Plot completeness: how many of the character's scenes have an explicit
    /// costume assignment.
    static func assignmentProgress(characterName: String, scenes: [DCScene]) -> (assigned: Int, total: Int) {
        let featured = scenesFeaturing(characterName, in: scenes)
        let assigned = featured.filter { $0.costumeAssignments?[characterName] != nil }.count
        return (assigned, featured.count)
    }

    private var allScenes: [DCScene] {
        project.sequences.flatMap(\.scenes)
    }

    private var featuredScenes: [DCScene] {
        Self.scenesFeaturing(character.name, in: allScenes)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if (character.costumes ?? []).isEmpty {
                    emptyWardrobeState
                } else if featuredScenes.isEmpty {
                    Text("\(character.name) doesn't appear in any scene yet — add them to dialogue or action in the Bubble view.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .padding(.vertical, 20)
                } else {
                    ForEach(featuredScenes) { scene in
                        sceneRow(scene)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Header

    private var header: some View {
        let progress = Self.assignmentProgress(characterName: character.name, scenes: allScenes)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wardrobe Plot")
                        .font(.system(size: 15, weight: .semibold))
                    Text("What \(character.name) wears, scene by scene. Assignments drive every AI prompt and reference image.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: { onOpenCostumeDepartment?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "tshirt.fill")
                            .font(.system(size: 10))
                        Text("Design costumes")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Open the Costumes department to create or edit looks")
            }

            HStack(spacing: 8) {
                ProgressView(value: progress.total == 0 ? 0 : Double(progress.assigned) / Double(progress.total))
                    .frame(maxWidth: 220)
                Text("\(progress.assigned) of \(progress.total) scenes assigned")
                    .font(.system(size: 10))
                    .foregroundColor(progress.assigned == progress.total && progress.total > 0 ? .green : .gray)
            }
        }
    }

    private var emptyWardrobeState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tshirt")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.4))
            Text("\(character.name) has no costumes yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            Button("Design their first costume") { onOpenCostumeDepartment?() }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Scene rows

    @ViewBuilder
    private func sceneRow(_ scene: DCScene) -> some View {
        let assignedId = scene.costumeAssignments?[character.name]
        let assigned = (character.costumes ?? []).first { $0.costumeId == assignedId }
        let effective = assigned ?? ShotPromptBuilder.assignedCostume(for: character, in: scene)

        HStack(alignment: .center, spacing: 12) {
            // Scene + context
            VStack(alignment: .leading, spacing: 3) {
                Text(scene.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let location = scene.location, !location.isEmpty {
                        contextTag(icon: "mappin.and.ellipse", text: location, tint: .green)
                    }
                    if let timeOfDay = scene.timeOfDay, !timeOfDay.isEmpty {
                        contextTag(icon: "sun.max", text: timeOfDay, tint: .yellow)
                    }
                    contextTag(icon: "video", text: "\(scene.shots.count) shot\(scene.shots.count == 1 ? "" : "s")",
                               tint: .gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Costume assignment
            costumeThumbnail(effective)
            Menu {
                ForEach(character.costumes ?? [], id: \.costumeId) { costume in
                    Button(action: { assign(costume.costumeId, to: scene) }) {
                        if costume.costumeId == assignedId {
                            Label(costume.name, systemImage: "checkmark")
                        } else {
                            Text(costume.name)
                        }
                    }
                }
                Divider()
                Button("No explicit assignment (use default)") { assign(nil, to: scene) }
            } label: {
                HStack(spacing: 5) {
                    Text(effective?.name ?? "Unassigned")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(assigned != nil ? .white : .gray)
                    if assigned == nil && effective != nil {
                        Text("default")
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if let effective {
                let status = effective.status ?? "Concept"
                Text(status)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(status == "Ready" ? .green : .orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((status == "Ready" ? Color.green : Color.orange).opacity(0.12))
                    .cornerRadius(4)
                    .help("Fitting-pipeline status from the Costumes department")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(assigned != nil ? Color.green.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func assign(_ costumeId: String?, to scene: DCScene) {
        var updated = scene
        var assignments = updated.costumeAssignments ?? [:]
        if let costumeId {
            assignments[character.name] = costumeId
        } else {
            assignments.removeValue(forKey: character.name)
        }
        updated.costumeAssignments = assignments.isEmpty ? nil : assignments
        for sequenceIndex in project.sequences.indices {
            if let sceneIndex = project.sequences[sequenceIndex].scenes.firstIndex(where: { $0.id == updated.id }) {
                project.sequences[sequenceIndex].scenes[sceneIndex] = updated
                return
            }
        }
    }

    // MARK: - Small pieces

    @ViewBuilder
    private func contextTag(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 7))
            Text(text)
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundColor(tint.opacity(0.9))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(tint.opacity(0.08))
        .cornerRadius(4)
    }

    @ViewBuilder
    private func costumeThumbnail(_ costume: CharacterCostume?) -> some View {
        if let costume, let basePath = projectBasePath,
           let path = costume.imageFront ?? costume.imageFullBody,
           let image = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.purple.opacity(0.1))
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: "tshirt").font(.system(size: 11)).foregroundColor(.purple.opacity(0.6)))
        }
    }
}
