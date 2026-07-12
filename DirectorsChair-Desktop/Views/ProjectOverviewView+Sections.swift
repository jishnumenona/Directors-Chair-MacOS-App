//
// ProjectOverviewView+Sections.swift
//
// Extracted from ProjectOverviewView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices
import AppKit


// MARK: - 2. Logline & Pitch

struct OverviewLoglineSection: View {
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

struct OverviewStatsBar: View {
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

struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.4))
            .frame(width: 1, height: 28)
    }
}

// MARK: - 4. Scene Gallery

struct OverviewSceneGallery: View {
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

struct SceneCard: View {
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
        // Try sceneOverviewImage first, then first locationImage.
        let paths = [scene.sceneOverviewImage, scene.locationImages.first?.imagePath].compactMap { $0 }
        OverviewImageCache.shared.loadAsync(paths: paths, base: projectDir) { cardImage = $0 }
    }
}

// MARK: - 5. Characters Strip

struct OverviewCharacterStrip: View {
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

struct CharacterPortrait: View {
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
        // Priority: overviewPortrait -> baseImage -> imageFront.
        let paths = [character.overviewPortrait, character.baseImage, character.imageFront].compactMap { $0 }
        OverviewImageCache.shared.loadAsync(paths: paths, base: projectDir) { portraitImage = $0 }
    }
}

// MARK: - NSColor hex extension

extension NSColor {
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
