//
//  ProjectsExplorerView.swift
//  DirectorsChair-Desktop
//
//  Projects explorer view - displays all projects in ~/Directors Chair/
//  Allows browsing, opening, and creating projects
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairServices

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
    let genre: String
    let status: String
    let tagline: String
    let projectType: String
    let posterPath: URL?
    let shotCount: Int

    /// Display-friendly last modified string
    var lastModifiedString: String {
        guard let date = lastModified else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Color for the status badge
    var statusColor: Color {
        switch status.lowercased() {
        case "completed", "complete":
            return .green
        case "production":
            return .blue
        case "pre-production":
            return .orange
        case "post-production":
            return .purple
        case "analysis":
            return .cyan
        default:
            return .gray
        }
    }

    /// Initials from the project name for fallback display
    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Projects Explorer View

struct ProjectsExplorerView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var cloudSyncManager: CloudSyncManager

    @State private var projects: [ProjectInfo] = []
    @State private var isLoading = true
    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var hoveredProjectId: UUID?
    @State private var showingImportPicker = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var importStats: ScreenplayImporter.ImportStats?
    @State private var showingImportSuccess = false
    @StateObject private var importProgress = ImportProgressTracker()

    // Grid layout — wider for poster cards
    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 320), spacing: 20)
    ]

    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Account status bar
                HStack(spacing: 12) {
                    Spacer()

                    SyncStatusView(syncManager: cloudSyncManager)
                    AccountMenuView()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))

                // Main content
                if isLoading {
                    Spacer()
                    ProgressView("Discovering projects...")
                    Spacer()
                } else if projects.isEmpty {
                    emptyStateView
                } else {
                    projectsGridView
                }
            }

            if isImporting {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                ImportProgressOverlay(progress: importProgress)
            }
        }
        .onAppear {
            discoverProjects()
        }
        .sheet(isPresented: $showingNewProjectSheet) {
            newProjectSheet
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
        .alert("Screenplay Imported", isPresented: $showingImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            if let stats = importStats {
                Text("Successfully imported \(stats.sceneCount) scenes, \(stats.shotCount) shots, \(stats.dialogueCount) dialogues, \(stats.actionCount) actions, \(stats.characterCount) characters, \(stats.propCount) props, and \(stats.locationCount) locations.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 28) {
            Image(systemName: "clapperboard")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(
                    colors: [.accentColor, .accentColor.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            VStack(spacing: 8) {
                Text("Start Your First Production")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Create a new project or import a screenplay to begin")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 14) {
                Button(action: { showingNewProjectSheet = true }) {
                    Label("New Project", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { showingImportPicker = true }) {
                    Label("Import Screenplay", systemImage: "doc.text")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(Capsule().stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isImporting)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Projects Grid

    private var projectsGridView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "clapperboard.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.accentColor)
                            Text("DIRECTOR'S CHAIR")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.2)
                                .foregroundColor(.accentColor)
                        }

                        Text("Your Projects")
                            .font(.system(size: 28, weight: .bold))

                        Text("\(projects.count) project\(projects.count == 1 ? "" : "s") in ~/Directors Chair/")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Button(action: { showingNewProjectSheet = true }) {
                            Label("New", systemImage: "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: { showingImportPicker = true }) {
                            Label("Import", systemImage: "doc.text")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isImporting)

                        Button(action: discoverProjects) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .padding(7)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .overlay(Circle().stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Refresh project list")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Projects Grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(projects) { project in
                        ProjectCard(
                            project: project,
                            isHovered: hoveredProjectId == project.id,
                            onOpen: { openProject(project) }
                        )
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                hoveredProjectId = hovering ? project.id : nil
                            }
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
                var shotCount = 0
                var iconPath: URL? = nil
                var genre = ""
                var status = ""
                var tagline = ""
                var projectType = ""
                var posterPath: URL? = nil

                if let data = try? Data(contentsOf: projectFile),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    if let name = json["name"] as? String, !name.isEmpty {
                        projectName = name
                    }

                    // Genre
                    if let g = json["genre"] as? String, !g.isEmpty {
                        genre = g
                    }

                    // Status
                    if let s = json["status"] as? String, !s.isEmpty {
                        status = s
                    }

                    // Tagline
                    if let t = json["overview_tagline"] as? String, !t.isEmpty {
                        tagline = t
                    }

                    // Project type
                    if let pt = json["project_type"] as? String, !pt.isEmpty {
                        projectType = pt
                    }

                    // Poster path — first entry from overview_poster_paths
                    if let paths = json["overview_poster_paths"] as? [String], let first = paths.first, !first.isEmpty {
                        let possiblePoster = dir.appendingPathComponent(first)
                        if FileManager.default.fileExists(atPath: possiblePoster.path) {
                            posterPath = possiblePoster
                        }
                    }

                    // Count scenes and shots from sequences
                    if let sequences = json["sequences"] as? [[String: Any]] {
                        for seq in sequences {
                            if let scenes = seq["scenes"] as? [[String: Any]] {
                                sceneCount += scenes.count
                                for scene in scenes {
                                    if let shots = scene["shots"] as? [[String: Any]] {
                                        shotCount += shots.count
                                    }
                                }
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
                    characterCount: characterCount,
                    genre: genre,
                    status: status,
                    tagline: tagline,
                    projectType: projectType,
                    posterPath: posterPath,
                    shotCount: shotCount
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

    // MARK: - Screenplay Import

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importScreenplay(from: url)
        case .failure(let error):
            importError = error.localizedDescription
            showingImportError = true
        }
    }

    private func importScreenplay(from url: URL) {
        isImporting = true
        importProgress.progress = 0
        importProgress.stepLabel = "Preparing..."
        importProgress.logMessages = []

        Task {
            do {
                // Derive project name from filename, stripping common suffixes iteratively
                var baseName = url.deletingPathExtension().lastPathComponent
                let suffixPatterns = [" - Screenplay", " - screenplay", " Screenplay", " screenplay", " - Script", " - script", " Script", " script", " - Draft", " - draft", " Draft", " draft", " - Final", " - final", " Final", " final", " - Latest", " - latest", " Latest", " latest"]
                var didStrip = true
                while didStrip {
                    didStrip = false
                    for suffix in suffixPatterns {
                        if baseName.hasSuffix(suffix) {
                            baseName = String(baseName.dropLast(suffix.count))
                            didStrip = true
                            break
                        }
                    }
                }
                baseName = baseName.trimmingCharacters(in: .whitespaces)
                let uniqueName = ProjectDirectoryManager.uniqueProjectName(baseName: baseName)

                // Parse the screenplay PDF using AI
                let importResult = try await ScreenplayImporter.importFromPDF(url: url, projectName: uniqueName, progress: importProgress)

                // Create project directory
                let projectDir = try ProjectDirectoryManager.createProjectDirectory(named: uniqueName)
                let projectFileURL = ProjectDirectoryManager.projectFileURL(in: projectDir)

                // Update project with basePath
                var project = importResult.project
                project.basePath = projectDir.path

                // Save project.json
                let persistence = ProjectPersistence()
                try await persistence.save(project, to: projectFileURL)

                isImporting = false
                importStats = importResult.stats
                showingImportSuccess = true

                // Open the imported project
                try await projectViewModel.load(from: projectFileURL)
                coordinator.navigateTo(.overview)
            } catch {
                isImporting = false
                importError = error.localizedDescription
                showingImportError = true
            }
        }
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: ProjectInfo
    let isHovered: Bool
    let onOpen: () -> Void

    private let posterHeight: CGFloat = 170

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
                    isHovered ? Color.accentColor.opacity(0.8) : Color(nsColor: .separatorColor).opacity(0.3),
                    lineWidth: isHovered ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: isHovered ? Color.accentColor.opacity(0.15) : .black.opacity(0.06),
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

    private var posterArea: some View {
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
                            Color.accentColor.opacity(0.7),
                            Color.accentColor.opacity(0.2),
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

                if !project.status.isEmpty {
                    Text(project.status)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(project.statusColor.opacity(0.85))
                        .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(height: posterHeight)
        .clipped()
    }

    // MARK: - Info Area

    private var infoArea: some View {
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
                statItem(icon: "clock", value: project.lastModifiedString, label: "")
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
                    .background(Color.accentColor)
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

    private func statItem(icon: String, value: String, label: String) -> some View {
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
