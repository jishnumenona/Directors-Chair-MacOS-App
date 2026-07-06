//
// ProjectsExplorerView+Components.swift
//
// Extracted from ProjectsExplorerView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices


// MARK: - Example Download Card

struct ExampleDownloadCard: View {
    let example: ExampleProjectDefinition
    let downloadState: ExampleDownloadState
    let isHovered: Bool
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Icon + type badge row
            HStack(spacing: 8) {
                Image(systemName: example.iconName)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.cyan)
                    .frame(width: 28, height: 28)

                Spacer()

                Text(example.projectType)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Name
            Text(example.name)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)

            // Tagline
            Text(example.tagline)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Stats row
            HStack(spacing: 8) {
                miniStat(icon: "film", value: "\(example.sceneCount)")
                miniStat(icon: "person.2", value: "\(example.characterCount)")
                miniStat(icon: "camera", value: "\(example.shotCount)")
                Spacer()
                Text("\(example.fileSizeKB) KB")
                    .font(.system(size: 9))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }

            // Download button
            downloadButton
        }
        .padding(14)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHovered ? Color.cyan.opacity(0.6) : Color(nsColor: .separatorColor).opacity(0.3),
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    @ViewBuilder
    var downloadButton: some View {
        switch downloadState {
        case .notDownloaded:
            Button(action: onDownload) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 11))
                    Text("Download")
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.15))
                .foregroundColor(.cyan)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

        case .downloading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Downloading...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

        case .downloaded:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("Downloaded")
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundColor(.green)

        case .failed:
            Button(action: onDownload) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Retry")
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }

    func miniStat(icon: String, value: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            Text(value)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: ProjectInfo
    let isHovered: Bool
    let onOpen: () -> Void

    let posterHeight: CGFloat = 170

    /// Tint color — cyan for examples, accent for regular
    var tintColor: Color {
        project.isExample ? .cyan : Color.accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Poster area
            posterArea

            // Info area
            infoArea
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHovered ? tintColor.opacity(0.8) : Color(nsColor: .separatorColor).opacity(0.3),
                    lineWidth: isHovered ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: isHovered ? tintColor.opacity(0.15) : .black.opacity(0.06),
            radius: isHovered ? 12 : 4,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen()
        }
    }

    // MARK: - Poster Area

    var posterArea: some View {
        ZStack(alignment: .bottom) {
            // Poster image, icon fallback, or gradient fallback
            if let posterURL = project.posterPath,
               let nsImage = NSImage(contentsOf: posterURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: posterHeight)
                    .clipped()
            } else if let iconPath = project.iconPath,
                      let nsImage = NSImage(contentsOf: iconPath) {
                // Use icon as full backdrop instead of circle
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: posterHeight)
                    .clipped()
            } else {
                // Stylized gradient fallback with initials
                ZStack {
                    LinearGradient(
                        colors: [
                            tintColor.opacity(0.7),
                            tintColor.opacity(0.2),
                            Color(nsColor: .controlBackgroundColor)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 8) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.white.opacity(0.7))

                        Text(project.initials)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(height: posterHeight)
            }

            // Bottom gradient overlay for badges
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)

            // Genre & Status badges overlaid at bottom
            HStack(spacing: 6) {
                if !project.genre.isEmpty {
                    Text(project.genre)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                if !project.isExample && !project.status.isEmpty {
                    Text(project.status)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(project.statusColor.opacity(0.85))
                        .clipShape(Capsule())
                }

                Spacer()

                // Example badge
                if project.isExample {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7))
                        Text("EXAMPLE")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.85))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(height: posterHeight)
        .clipped()
    }

    // MARK: - Info Area

    var infoArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Project name
            Text(project.name)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(1)

            // Tagline or project type fallback
            if !project.tagline.isEmpty {
                Text(project.tagline)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(1)
            } else if !project.projectType.isEmpty {
                Text(project.projectType)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(1)
            }

            // Stats grid
            HStack(spacing: 0) {
                statItem(icon: "film", value: "\(project.sceneCount)", label: "scenes")
                Spacer()
                statItem(icon: "person.2", value: "\(project.characterCount)", label: "chars")
                Spacer()
                statItem(icon: "camera", value: "\(project.shotCount)", label: "shots")
                Spacer()
                if project.isExample && !project.projectType.isEmpty {
                    // Show project type instead of last modified for examples
                    statItem(icon: "tag", value: project.projectType, label: "")
                } else {
                    statItem(icon: "clock", value: project.lastModifiedString, label: "")
                }
            }
            .padding(.top, 2)

            // Open button on hover
            if isHovered {
                Button(action: onOpen) {
                    HStack {
                        Spacer()
                        Text("Open Project")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                    }
                    .padding(.vertical, 7)
                    .background(tintColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(14)
    }

    // MARK: - Stat Item

    func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Import Progress Overlay

struct ImportProgressOverlay: View {
    @ObservedObject var progress: ImportProgressTracker

    var body: some View {
        VStack(spacing: 0) {
            // Main progress section
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                    Text("Importing Screenplay")
                        .font(.headline)
                    Spacer()
                }

                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: progress.progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)

                    HStack {
                        Text(progress.stepLabel)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(progress.progress * 100))%")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(20)

            Divider()

            // Debug log toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    progress.isDebugExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: progress.isDebugExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .frame(width: 12)
                    Text("Activity Log")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("(\(progress.logMessages.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Collapsible debug log
            if progress.isDebugExpanded {
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(progress.logMessages) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(entry.timeString)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)

                                    Text(entry.message)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(entry.isError ? .red : .primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 160)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .onChange(of: progress.logMessages.count) { _ in
                        if let last = progress.logMessages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .frame(maxWidth: 460)
    }
}

// MARK: - Preview

#Preview {
    ProjectsExplorerView()
        .environmentObject(AppCoordinator())
        .environmentObject(ProjectViewModel())
        .frame(width: 800, height: 600)
}
