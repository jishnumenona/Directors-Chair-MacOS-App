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
    let isExample: Bool

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

// MARK: - Download State

enum ExampleDownloadState: Equatable {
    case notDownloaded
    case downloading
    case downloaded
    case failed(String)
}

// MARK: - Projects Explorer View

struct ProjectsExplorerView: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var cloudSyncManager: CloudSyncManager

    @State var projects: [ProjectInfo] = []
    @State var isLoading = true
    @State var showingNewProjectSheet = false
    @State var newProjectName = ""
    @State var hoveredProjectId: UUID?
    @State var showingImportPicker = false
    @State var isImporting = false
    @State var importError: String?
    @State var showingImportError = false
    @State var importStats: ScreenplayImporter.ImportStats?
    @State var showingImportSuccess = false
    @StateObject var importProgress = ImportProgressTracker()

    // Example project state
    @State var exampleDownloadStates: [String: ExampleDownloadState] = [:]
    @State var showingExampleError = false
    @State var exampleErrorMessage = ""
    @State var hoveredExampleId: String?

    // Grid layout — wider for poster cards
    let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 320), spacing: 20)
    ]

    /// Examples that haven't been downloaded yet
    var uninstalledExamples: [ExampleProjectDefinition] {
        ExampleProjectManager.shared.examples.filter { example in
            !ExampleProjectManager.shared.isInstalled(example)
        }
    }

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
            syncUsernameAndDiscover()
        }
        .onChange(of: authManager.currentUser?.username) { _, newVal in
            NSLog("[ProjectsExplorer] .onChange fired -> %@", newVal ?? "nil")
            syncUsernameAndDiscover()
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
        .alert("Download Error", isPresented: $showingExampleError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exampleErrorMessage)
        }
    }
}
