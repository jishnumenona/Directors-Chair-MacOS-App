//
//  ProjectsExplorerView.swift
//  DirectorsChair-Desktop
//
//  Projects explorer view - displays all projects in ~/Directors Chair/
//  Allows browsing, opening, and creating projects
//

import SwiftUI
import DirectorsChairCore

// MARK: - Project Info Model

/// Lightweight model for displaying project information in the explorer
struct ProjectInfo: Identifiable {
    let id: UUID
    let name: String
    let path: URL
    let lastModified: Date?
    let iconPath: URL?
    let sceneCount: Int
    let characterCount: Int

    /// Display-friendly last modified string
    var lastModifiedString: String {
        guard let date = lastModified else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Projects Explorer View

struct ProjectsExplorerView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var projects: [ProjectInfo] = []
    @State private var isLoading = true
    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var hoveredProjectId: UUID?

    // Grid layout
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)
    ]

    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Discovering projects...")
            } else if projects.isEmpty {
                emptyStateView
            } else {
                projectsGridView
            }
        }
        .onAppear {
            discoverProjects()
        }
        .sheet(isPresented: $showingNewProjectSheet) {
            newProjectSheet
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Projects Found")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create your first project to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Button(action: { showingNewProjectSheet = true }) {
                Label("New Project", systemImage: "plus")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Projects Grid

    private var projectsGridView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Projects")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("\(projects.count) project\(projects.count == 1 ? "" : "s") in ~/Directors Chair/")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { showingNewProjectSheet = true }) {
                        Label("New Project", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: discoverProjects) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh project list")
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Projects Grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(projects) { project in
                        ProjectCard(
                            project: project,
                            isHovered: hoveredProjectId == project.id,
                            onOpen: { openProject(project) }
                        )
                        .onHover { hovering in
                            hoveredProjectId = hovering ? project.id : nil
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - New Project Sheet

    private var newProjectSheet: some View {
        VStack(spacing: 20) {
            Text("Create New Project")
                .font(.headline)

            TextField("Project Name", text: $newProjectName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit {
                    createNewProject()
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    newProjectName = ""
                    showingNewProjectSheet = false
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    createNewProject()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    // MARK: - Actions

    private func discoverProjects() {
        isLoading = true

        // Run discovery on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let projectDirs = ProjectDirectoryManager.listProjects()

            let discoveredProjects: [ProjectInfo] = projectDirs.compactMap { dir in
                let projectFile = ProjectDirectoryManager.projectFileURL(in: dir)

                // Skip if no project.json
                guard FileManager.default.fileExists(atPath: projectFile.path) else {
                    return nil
                }

                // Get file attributes
                let attrs = try? FileManager.default.attributesOfItem(atPath: projectFile.path)
                let modified = attrs?[.modificationDate] as? Date

                // Quick parse project.json for metadata
                var projectName = dir.lastPathComponent
                var sceneCount = 0
                var characterCount = 0
                var iconPath: URL? = nil

                if let data = try? Data(contentsOf: projectFile),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    if let name = json["name"] as? String, !name.isEmpty {
                        projectName = name
                    }

                    // Count scenes from sequences
                    if let sequences = json["sequences"] as? [[String: Any]] {
                        for seq in sequences {
                            if let scenes = seq["scenes"] as? [[String: Any]] {
                                sceneCount += scenes.count
                            }
                        }
                    }

                    // Count characters
                    if let characters = json["characters"] as? [[String: Any]] {
                        characterCount = characters.count
                    }

                    // Check for project icon (JSON uses snake_case)
                    if let iconRelativePath = json["project_icon"] as? String, !iconRelativePath.isEmpty {
                        let possibleIconPath = dir.appendingPathComponent(iconRelativePath)
                        if FileManager.default.fileExists(atPath: possibleIconPath.path) {
                            iconPath = possibleIconPath
                        }
                    }
                }

                return ProjectInfo(
                    id: UUID(),
                    name: projectName,
                    path: dir,
                    lastModified: modified,
                    iconPath: iconPath,
                    sceneCount: sceneCount,
                    characterCount: characterCount
                )
            }

            // Sort by last modified (most recent first)
            let sortedProjects = discoveredProjects.sorted { p1, p2 in
                guard let d1 = p1.lastModified else { return false }
                guard let d2 = p2.lastModified else { return true }
                return d1 > d2
            }

            DispatchQueue.main.async {
                self.projects = sortedProjects
                self.isLoading = false
            }
        }
    }

    private func openProject(_ project: ProjectInfo) {
        let projectFile = ProjectDirectoryManager.projectFileURL(in: project.path)

        Task {
            do {
                try await projectViewModel.load(from: projectFile)
                // Navigate to Overview after opening
                coordinator.navigateTo(.overview)
            } catch {
                debugLog("Failed to open project: \(error)")
            }
        }
    }

    private func createNewProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        projectViewModel.createNew(named: name)
        newProjectName = ""
        showingNewProjectSheet = false

        // Navigate to Overview after creating
        coordinator.navigateTo(.overview)
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: ProjectInfo
    let isHovered: Bool
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon and Name
            HStack(spacing: 12) {
                // Project Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    if let iconPath = project.iconPath,
                       let nsImage = NSImage(contentsOf: iconPath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "film.stack")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text("Modified \(project.lastModifiedString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Metadata
            HStack(spacing: 16) {
                Label("\(project.sceneCount) scene\(project.sceneCount == 1 ? "" : "s")", systemImage: "film")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(project.characterCount) character\(project.characterCount == 1 ? "" : "s")", systemImage: "person.2")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Open Button (shown on hover)
            if isHovered {
                Button(action: onOpen) {
                    Text("Open")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHovered ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isHovered ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onTapGesture(count: 2) {
            onOpen()
        }
    }
}

// MARK: - Preview

#Preview {
    ProjectsExplorerView()
        .environmentObject(AppCoordinator())
        .environmentObject(ProjectViewModel())
        .frame(width: 800, height: 600)
}
