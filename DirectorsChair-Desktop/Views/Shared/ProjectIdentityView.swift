//
//  ProjectIdentityView.swift
//  DirectorsChair-Desktop
//
//  Reusable component for displaying project identity (icon + name)
//  Used across the app wherever project identity is shown
//

import SwiftUI
import DirectorsChairCore

// MARK: - Project Identity View

/// Reusable view for displaying project identity with icon
/// Available in multiple sizes: compact, standard, large
struct ProjectIdentityView: View {
    let project: Project
    let projectPath: URL?
    let size: ProjectIdentitySize
    let showMetadata: Bool

    init(
        project: Project,
        projectPath: URL?,
        size: ProjectIdentitySize = .standard,
        showMetadata: Bool = false
    ) {
        self.project = project
        self.projectPath = projectPath
        self.size = size
        self.showMetadata = showMetadata
    }

    /// Computed icon URL from project base path
    private var iconURL: URL? {
        guard !project.projectIcon.isEmpty,
              let projectPath = projectPath else { return nil }
        let projectDir = projectPath.deletingLastPathComponent()
        return projectDir.appendingPathComponent(project.projectIcon)
    }

    var body: some View {
        HStack(spacing: size.spacing) {
            // Project Icon
            ProjectIconThumbnail(
                iconURL: iconURL,
                size: size.iconSize
            )

            // Project Info
            VStack(alignment: .leading, spacing: size.textSpacing) {
                Text(project.name)
                    .font(size.titleFont)
                    .fontWeight(size.titleWeight)
                    .lineLimit(1)

                if showMetadata {
                    metadataRow
                }
            }
        }
    }

    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: 8) {
            if !project.genre.isEmpty {
                Text(project.genre)
                    .font(size.subtitleFont)
                    .foregroundColor(.secondary)
            }

            if !project.director.isEmpty {
                if !project.genre.isEmpty {
                    Text("·")
                        .foregroundColor(.secondary)
                }
                Text(project.director)
                    .font(size.subtitleFont)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Project Identity Size

enum ProjectIdentitySize {
    case compact    // For toolbars, lists
    case standard   // For headers, sidebars
    case large      // For main headers

    var iconSize: CGFloat {
        switch self {
        case .compact: return 24
        case .standard: return 36
        case .large: return 48
        }
    }

    var spacing: CGFloat {
        switch self {
        case .compact: return 8
        case .standard: return 12
        case .large: return 16
        }
    }

    var textSpacing: CGFloat {
        switch self {
        case .compact: return 0
        case .standard: return 2
        case .large: return 4
        }
    }

    var titleFont: Font {
        switch self {
        case .compact: return .system(size: 12, weight: .medium)
        case .standard: return .system(size: 14, weight: .semibold)
        case .large: return .system(size: 18, weight: .bold)
        }
    }

    var titleWeight: Font.Weight {
        switch self {
        case .compact: return .medium
        case .standard: return .semibold
        case .large: return .bold
        }
    }

    var subtitleFont: Font {
        switch self {
        case .compact: return .system(size: 10)
        case .standard: return .system(size: 11)
        case .large: return .system(size: 13)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 4
        case .standard: return 6
        case .large: return 8
        }
    }
}

// MARK: - Project Icon Thumbnail

/// Small thumbnail version of the project icon
struct ProjectIconThumbnail: View {
    let iconURL: URL?
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.15)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: size, height: size)

            if let iconURL = iconURL,
               let nsImage = NSImage(contentsOf: iconURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
            } else {
                Image(systemName: "film.stack")
                    .font(.system(size: size * 0.45))
                    .foregroundColor(.accentColor)
            }
        }
    }
}

// MARK: - Project Header Banner

/// Full-width header banner with project identity
/// Used at the top of production views
struct ProjectHeaderBanner: View {
    let project: Project
    let projectPath: URL?
    let subtitle: String?

    init(project: Project, projectPath: URL?, subtitle: String? = nil) {
        self.project = project
        self.projectPath = projectPath
        self.subtitle = subtitle
    }

    /// Computed icon URL from project base path
    private var iconURL: URL? {
        guard !project.projectIcon.isEmpty,
              let projectPath = projectPath else { return nil }
        let projectDir = projectPath.deletingLastPathComponent()
        return projectDir.appendingPathComponent(project.projectIcon)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Project Icon
            ProjectIconThumbnail(
                iconURL: iconURL,
                size: 48
            )

            // Project Info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 12) {
                        if !project.genre.isEmpty {
                            Label(project.genre, systemImage: "theatermasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !project.director.isEmpty {
                            Label(project.director, systemImage: "person")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !project.productionCompany.isEmpty {
                            Label(project.productionCompany, systemImage: "building.2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Preview

#Preview("Compact") {
    VStack(spacing: 20) {
        ProjectIdentityView(
            project: .empty(),
            projectPath: nil,
            size: .compact
        )

        ProjectIdentityView(
            project: .empty(),
            projectPath: nil,
            size: .standard,
            showMetadata: true
        )

        ProjectIdentityView(
            project: .empty(),
            projectPath: nil,
            size: .large,
            showMetadata: true
        )

        ProjectHeaderBanner(
            project: .empty(),
            projectPath: nil,
            subtitle: "Production Schedule"
        )
    }
    .padding()
    .frame(width: 400)
}
