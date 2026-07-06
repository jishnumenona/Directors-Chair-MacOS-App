//
// ProjectOverviewView+Boards.swift
//
// Extracted from ProjectOverviewView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices
import AppKit


// MARK: - 6. Shot Board

struct OverviewShotBoard: View {
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

struct ShotCard: View {
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

struct OverviewLocationGallery: View {
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

struct LocationCard: View {
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

struct OverviewQuickActions: View {
    @EnvironmentObject var coordinator: AppCoordinator

    private let actions: [(icon: String, label: String, color: Color, target: AppView)] = [
        ("bubble.left.and.bubble.right", "Dialogue", .blue, .bubble),
        ("book", "Characters", .purple, .storyDesign),
        ("square.grid.2x2", "Vision Board", .pink, .visionBoard),
        ("camera", "Shots", .orange, .shotList),
        ("theatermasks", "Production", .red, .production),
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

struct SectionHeader: View {
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
