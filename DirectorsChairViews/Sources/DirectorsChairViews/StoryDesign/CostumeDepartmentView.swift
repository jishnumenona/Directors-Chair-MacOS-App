//
// CostumeDepartmentView.swift
//
// The Costumes mode of Story Design — the wardrobe department's home.
// Costume DESIGN happens here (the full editor with AI angle generation,
// references, and outfit try-on), presented the way a costume department
// works: one rack of every costume in the production, grouped by the
// character it's built for, with the fitting pipeline (Concept → Sourcing →
// Fitting → Ready) visible at a glance. Scene-by-scene ASSIGNMENT lives in
// each character's Wardrobe tab and in the Shots view.
//

import SwiftUI
import AppKit
import DirectorsChairCore

struct CostumeDepartmentView: View {
    @Binding var project: Project
    let projectBasePath: URL?
    var onGenerateImage: ((Character, String, String, @escaping @MainActor (Double) -> Void) -> Void)?

    @State private var selectedCharacterId: String?
    @State private var selectedCostumeIndex: Int = 0
    @State private var statusFilter: String = "All"

    /// Fitting-pipeline stages, in production order.
    static let pipelineStages = ["Concept", "Sourcing", "Fitting", "Ready", "Retired"]

    /// Count costumes per pipeline stage across the whole production. Pure — tested.
    static func pipelineCounts(for characters: [Character]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for character in characters {
            for costume in character.costumes ?? [] {
                counts[costume.status ?? "Concept", default: 0] += 1
            }
        }
        return counts
    }

    private var allEntries: [(character: Character, costume: CharacterCostume, index: Int)] {
        project.characters.flatMap { character in
            (character.costumes ?? []).enumerated().compactMap { index, costume in
                guard statusFilter == "All" || costume.status == statusFilter else { return nil }
                return (character, costume, index)
            }
        }
    }

    var body: some View {
        HSplitView {
            rackSidebar
                .frame(minWidth: 260, maxWidth: 320)
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if selectedCharacterId == nil {
                selectedCharacterId = project.characters.first { !($0.costumes ?? []).isEmpty }?.id
                    ?? project.characters.first?.id
            }
        }
    }

    // MARK: - Rack sidebar

    private var rackSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Department board: pipeline at a glance
            VStack(alignment: .leading, spacing: 8) {
                Text("COSTUME DEPARTMENT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
                let counts = Self.pipelineCounts(for: project.characters)
                HStack(spacing: 6) {
                    ForEach(Self.pipelineStages, id: \.self) { stage in
                        VStack(spacing: 1) {
                            Text("\(counts[stage] ?? 0)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(stageColor(stage))
                            Text(stage)
                                .font(.system(size: 7))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Menu {
                    Button("All") { statusFilter = "All" }
                    Divider()
                    ForEach(Self.pipelineStages, id: \.self) { stage in
                        Button(stage) { statusFilter = stage }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 10))
                        Text(statusFilter == "All" ? "All stages" : statusFilter)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.gray)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(12)

            Divider()

            // The rack — every costume in the production, grouped by character
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(project.characters) { character in
                        let entries = allEntries.filter { $0.character.id == character.id }
                        if !entries.isEmpty || statusFilter == "All" {
                            characterRackSection(character, entries: entries)
                        }
                    }
                    if project.characters.isEmpty {
                        Text("Create characters in the Characters tab first — costumes are designed for a character.")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(12)
                    }
                }
                .padding(10)
            }

            Divider()
            Text("Scene-by-scene assignment lives in the character's Wardrobe tab and in the Shots view.")
                .font(.system(size: 8))
                .foregroundColor(.gray.opacity(0.55))
                .padding(10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func characterRackSection(_ character: Character,
                                      entries: [(character: Character, costume: CharacterCostume, index: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                characterAvatar(character)
                Text(character.name)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\((character.costumes ?? []).count)")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
            ForEach(entries, id: \.costume.id) { entry in
                costumeRackRow(entry)
            }
            Button(action: {
                selectedCharacterId = character.id
                selectedCostumeIndex = max(0, (character.costumes ?? []).count - 1)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 9))
                    Text("New costume")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.accentColor.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Open \(character.name)'s costume editor to add a design")
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
    }

    @ViewBuilder
    private func costumeRackRow(_ entry: (character: Character, costume: CharacterCostume, index: Int)) -> some View {
        let isSelected = selectedCharacterId == entry.character.id && selectedCostumeIndex == entry.index
        Button(action: {
            selectedCharacterId = entry.character.id
            selectedCostumeIndex = entry.index
        }) {
            HStack(spacing: 8) {
                costumeThumbnail(entry.costume)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.costume.name)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(entry.costume.status ?? "Concept")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(stageColor(entry.costume.status ?? "Concept"))
                        if let era = entry.costume.era, !era.isEmpty {
                            Text("· \(era)")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                if let palette = entry.costume.colorPalette, !palette.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(palette.prefix(3), id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 7, height: 7)
                        }
                    }
                }
            }
            .padding(6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail: the full costume editor (AI generation included)

    @ViewBuilder
    private var detailPane: some View {
        if let characterId = selectedCharacterId,
           let index = project.characters.firstIndex(where: { $0.id == characterId }) {
            CostumeTab(
                character: $project.characters[index],
                projectBasePath: projectBasePath,
                project: project,
                initialCostumeIndex: selectedCostumeIndex,
                onGenerateImage: { angle, prompt, progressHandler in
                    onGenerateImage?(project.characters[index], angle, prompt, progressHandler)
                }
            )
            .id("\(characterId)-\(selectedCostumeIndex)")
        } else {
            VStack(spacing: 12) {
                Image(systemName: "tshirt")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.4))
                Text("Select a costume from the rack")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Helpers

    private func stageColor(_ stage: String) -> Color {
        switch stage {
        case "Concept": return .purple
        case "Sourcing": return .orange
        case "Fitting": return .yellow
        case "Ready": return .green
        case "Retired": return .gray
        default: return .gray
        }
    }

    @ViewBuilder
    private func characterAvatar(_ character: Character) -> some View {
        if let basePath = projectBasePath,
           let path = character.imageFront ?? character.baseImage ?? character.avatar,
           let image = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 20, height: 20)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 20, height: 20)
                .overlay(Image(systemName: "person.fill").font(.system(size: 9)).foregroundColor(.blue))
        }
    }

    @ViewBuilder
    private func costumeThumbnail(_ costume: CharacterCostume) -> some View {
        if let basePath = projectBasePath,
           let path = costume.imageFront ?? costume.imageFullBody,
           let image = NSImage(contentsOf: basePath.appendingPathComponent(path)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.purple.opacity(0.12))
                .frame(width: 26, height: 26)
                .overlay(Image(systemName: "tshirt").font(.system(size: 10)).foregroundColor(.purple.opacity(0.7)))
        }
    }
}
