//
//  ProjectOverviewView.swift
//  DirectorsChair-Desktop
//
//  Phase 8E: Project Management
//  Project overview and pitch information
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices

struct ProjectOverviewView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @State private var isEditingPitch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Project Header with Icon
                ProjectHeaderSection(
                    project: $projectViewModel.project,
                    projectPath: projectViewModel.projectPath,
                    onProjectChanged: { projectViewModel.isDirty = true }
                )

                Divider()

                // Project Pitch
                ProjectPitchSection(
                    project: $projectViewModel.project,
                    isEditing: $isEditingPitch
                )

                Divider()

                // Quick Actions
                QuickActionsSection()

                Divider()

                // Project Statistics
                ProjectStatisticsSection(projectViewModel: projectViewModel)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Project Header Section

struct ProjectHeaderSection: View {
    @Binding var project: Project
    let projectPath: URL?
    let onProjectChanged: () -> Void

    @State private var isGeneratingIcon = false
    @State private var iconError: String?
    @State private var showingIconError = false

    /// Computed icon URL from project base path
    private var iconURL: URL? {
        guard !project.projectIcon.isEmpty,
              let projectPath = projectPath else { return nil }
        let projectDir = projectPath.deletingLastPathComponent()
        return projectDir.appendingPathComponent(project.projectIcon)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Project Icon
            ProjectIconView(
                iconURL: iconURL,
                isGenerating: isGeneratingIcon,
                onGenerate: generateProjectIcon
            )

            // Project Info
            VStack(alignment: .leading, spacing: 12) {
                Text(project.name)
                    .font(.system(size: 32, weight: .bold))

                HStack(spacing: 16) {
                    if !project.director.isEmpty {
                        Label(project.director, systemImage: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    if !project.productionCompany.isEmpty {
                        Label(project.productionCompany, systemImage: "building.2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    if !project.genre.isEmpty {
                        Label(project.genre, systemImage: "theatermasks.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .alert("Icon Generation Failed", isPresented: $showingIconError) {
            Button("OK") { }
        } message: {
            Text(iconError ?? "Unknown error")
        }
    }

    // MARK: - Icon Generation

    private func generateProjectIcon() {
        guard let projectPath = projectPath else {
            iconError = "No project path set. Please save the project first."
            showingIconError = true
            return
        }

        isGeneratingIcon = true

        Task {
            do {
                let aiClient = AIServiceClient.shared

                // Check if AI server is available
                guard await aiClient.testConnection() else {
                    await MainActor.run {
                        iconError = "Could not connect to AI server. Please ensure the AI Proxy server is running."
                        showingIconError = true
                        isGeneratingIcon = false
                    }
                    return
                }

                // Build a prompt based on project metadata
                let prompt = buildIconPrompt()

                let request = ImageGenerationRequest(
                    prompt: prompt,
                    provider: .googleImagen,
                    aspectRatio: "1:1",
                    numberOfImages: 1
                )

                let response = try await aiClient.generateImage(request)

                guard let imageData = response.images.first else {
                    throw AIClientError.invalidResponse("No image generated")
                }

                // Save icon to project directory
                let projectDir = projectPath.deletingLastPathComponent()
                let iconsDir = projectDir.appendingPathComponent("assets").appendingPathComponent("icons")

                // Create icons directory if needed
                if !FileManager.default.fileExists(atPath: iconsDir.path) {
                    try FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
                }

                // Save with project name
                let sanitizedName = sanitizeFilename(project.name)
                let iconFilename = "\(sanitizedName)_icon.png"
                let iconPath = iconsDir.appendingPathComponent(iconFilename)

                try imageData.write(to: iconPath)

                // Update project with relative path
                let relativePath = "assets/icons/\(iconFilename)"

                await MainActor.run {
                    project.projectIcon = relativePath
                    onProjectChanged()
                    isGeneratingIcon = false
                }

            } catch {
                await MainActor.run {
                    iconError = error.localizedDescription
                    showingIconError = true
                    isGeneratingIcon = false
                }
            }
        }
    }

    private func buildIconPrompt() -> String {
        var promptParts: [String] = []

        // Base prompt for cinematic icon
        promptParts.append("A cinematic movie poster icon for a film project")

        // Add project name
        promptParts.append("titled '\(project.name)'")

        // Add genre if available
        if !project.genre.isEmpty {
            promptParts.append("in the \(project.genre) genre")
        }

        // Add description/pitch if available
        if !project.description.isEmpty {
            let shortDesc = String(project.description.prefix(200))
            promptParts.append("about: \(shortDesc)")
        }

        // Add tagline if available
        if !project.overviewTagline.isEmpty {
            promptParts.append("with the tagline: '\(project.overviewTagline)'")
        }

        // Style guidance
        promptParts.append("Style: professional movie poster art, cinematic lighting, dramatic composition, high quality digital art, suitable as an app icon")

        return promptParts.joined(separator: ". ")
    }

    private func sanitizeFilename(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        // Remove other special characters
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        sanitized = sanitized.unicodeScalars.filter { allowedChars.contains($0) }.map { String($0) }.joined()

        // Collapse multiple underscores
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        return sanitized.isEmpty ? "project" : sanitized
    }
}

// MARK: - Project Icon View

struct ProjectIconView: View {
    let iconURL: URL?
    let isGenerating: Bool
    let onGenerate: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack {
            // Icon container
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 120, height: 120)

            if isGenerating {
                // Loading state
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Generating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let iconURL = iconURL,
                      let nsImage = NSImage(contentsOf: iconURL) {
                // Display existing icon
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // Placeholder
                VStack(spacing: 8) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No Icon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Hover overlay with generate button
            if isHovered && !isGenerating {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 120, height: 120)

                Button(action: onGenerate) {
                    VStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 24))
                        Text(iconURL != nil ? "Regenerate" : "Generate")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Click to generate a project icon using AI")
    }
}

// MARK: - Project Pitch Section

struct ProjectPitchSection: View {
    @Binding var project: Project
    @Binding var isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Project Pitch")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    isEditing.toggle()
                }) {
                    Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                }
                .buttonStyle(.borderedProminent)
            }

            if isEditing {
                TextEditor(text: Binding(
                    get: { project.description },
                    set: { project.description = $0 }
                ))
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            } else {
                if !project.description.isEmpty {
                    Text(project.description)
                        .font(.body)
                        .foregroundColor(.primary)
                } else {
                    Text("No pitch written yet. Click Edit to add a pitch.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
}

// MARK: - Project Statistics Section

struct ProjectStatisticsSection: View {
    @ObservedObject var projectViewModel: ProjectViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Statistics")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    icon: "film.stack",
                    title: "Sequences",
                    value: "\(projectViewModel.sequences.count)",
                    color: .blue
                )

                StatCard(
                    icon: "film",
                    title: "Scenes",
                    value: "\(projectViewModel.allScenes.count)",
                    color: .green
                )

                StatCard(
                    icon: "person.3.fill",
                    title: "Characters",
                    value: "\(projectViewModel.characters.count)",
                    color: .purple
                )

                StatCard(
                    icon: "camera.fill",
                    title: "Beats",
                    value: "\(projectViewModel.project.beats.count)",
                    color: .orange
                )

                StatCard(
                    icon: "square.grid.2x2",
                    title: "Locations",
                    value: "\(projectViewModel.project.locations.count)",
                    color: .pink
                )

                StatCard(
                    icon: "calendar",
                    title: "Schedule Items",
                    value: "\(projectViewModel.project.scheduleItems.count)",
                    color: .red
                )
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold))

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .help("\(value) \(title)")
    }
}

// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Edit Dialogue",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                ) {
                    coordinator.navigateTo(.bubble)
                }

                QuickActionButton(
                    title: "Manage Characters",
                    icon: "book",
                    color: .purple
                ) {
                    coordinator.navigateTo(.storyDesign)
                }

                QuickActionButton(
                    title: "Vision Board",
                    icon: "square.grid.2x2",
                    color: .pink
                ) {
                    coordinator.navigateTo(.visionBoard)
                }

                QuickActionButton(
                    title: "Shot List",
                    icon: "camera",
                    color: .orange
                ) {
                    coordinator.navigateTo(.shotList)
                }

                QuickActionButton(
                    title: "Production Schedule",
                    icon: "calendar",
                    color: .red
                ) {
                    coordinator.navigateTo(.schedule)
                }

                QuickActionButton(
                    title: "Project Settings",
                    icon: "gear",
                    color: .gray
                ) {
                    coordinator.navigateTo(.settings)
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 32)

                Text(title)
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

// MARK: - Preview

#Preview {
    ProjectOverviewView()
        .environmentObject(AppCoordinator())
        .environmentObject(ProjectViewModel())
}
