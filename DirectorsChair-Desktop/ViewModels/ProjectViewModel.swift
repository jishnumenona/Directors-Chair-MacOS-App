//
//  ProjectViewModel.swift
//  DirectorsChair
//
//  Phase 8: Main App Integration
//  Central project state management with auto-save
//

import Foundation
import SwiftUI
import Combine
import DirectorsChairCore

/// Main project view model - manages project state and persistence
/// Replaces Python's Project QObject with auto-save
@MainActor
class ProjectViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current project
    @Published var project: Project

    /// Whether project has unsaved changes
    @Published var isDirty = false

    /// Last save timestamp
    @Published var lastSaved: Date?

    /// Current project file path
    @Published var projectPath: URL?

    /// Whether a project is currently loaded
    @Published var hasProject: Bool

    /// Error alert for user-facing errors
    @Published var errorAlert: ErrorAlert?

    /// Loading state for async operations
    @Published var isLoading = false

    // MARK: - Private Properties

    private let persistence: ProjectPersistence
    private let autoSaveManager: DebouncedSaveManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(project: Project? = nil) {
        self.project = project ?? Project.empty()
        self.hasProject = project != nil
        self.persistence = ProjectPersistence()
        self.autoSaveManager = DebouncedSaveManager()

        setupAutoSave()
    }

    // MARK: - Auto-Save Setup

    private func setupAutoSave() {
        // Watch for project changes and mark as dirty
        $project
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.isDirty = true
                Task { @MainActor in
                    await self?.autoSaveManager.requestSave()
                }
            }
            .store(in: &cancellables)

        // Subscribe to auto-save manager's save events
        autoSaveManager.$shouldSave
            .filter { $0 } // Only when shouldSave is true
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.save()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Project Operations

    /// Create a new empty project
    func createNew() {
        project = Project.empty()
        projectPath = nil
        isDirty = false
        lastSaved = nil
        hasProject = true
    }

    /// Load project from file path
    func load(from path: URL) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedProject = try await persistence.load(from: path)
            project = loadedProject
            projectPath = path
            isDirty = false
            lastSaved = Date()
            hasProject = true
        } catch {
            errorAlert = ErrorAlert(
                error: error,
                title: "Failed to Load Project"
            )
            throw error
        }
    }

    /// Save current project
    func save() async {
        guard let path = projectPath else {
            // No path set - need to show save dialog first
            errorAlert = ErrorAlert(
                title: "Cannot Save",
                message: "No save location set. Use Save As to choose a location."
            )
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await persistence.save(project, to: path)
            isDirty = false
            lastSaved = Date()
        } catch {
            errorAlert = ErrorAlert(
                error: error,
                title: "Failed to Save Project"
            )
        }
    }

    /// Save project to a new location
    func saveAs(to path: URL) async throws {
        try await persistence.save(project, to: path)
        projectPath = path
        isDirty = false
        lastSaved = Date()
    }

    /// Force immediate save (flush pending)
    func forceSave() async {
        guard isDirty else { return }
        await save()
    }

    /// Close current project
    func close() async {
        // Save if dirty
        if isDirty {
            await forceSave()
        }

        project = Project.empty()
        projectPath = nil
        isDirty = false
        lastSaved = nil
        hasProject = false
    }

    // MARK: - Project Modification Methods

    /// Add a sequence to the project
    func addSequence(_ sequence: DirectorsChairCore.Sequence) {
        project.sequences.append(sequence)
        isDirty = true
    }

    /// Remove a sequence from the project
    func removeSequence(_ sequence: DirectorsChairCore.Sequence) {
        project.sequences.removeAll { $0.id == sequence.id }
        isDirty = true
    }

    /// Add a character to the project
    func addCharacter(_ character: Character) {
        project.characters.append(character)
        isDirty = true
    }

    /// Remove a character from the project
    func removeCharacter(_ character: Character) {
        project.characters.removeAll { $0.id == character.id }
        isDirty = true
    }

    /// Update project metadata
    func updateMetadata(
        name: String? = nil,
        director: String? = nil,
        productionCompany: String? = nil,
        genre: String? = nil
    ) {
        if let name = name {
            project.name = name
        }
        if let director = director {
            project.director = director
        }
        if let productionCompany = productionCompany {
            project.productionCompany = productionCompany
        }
        if let genre = genre {
            project.genre = genre
        }
        isDirty = true
    }

    // MARK: - Convenience Accessors

    /// Get all scenes across all sequences
    var allScenes: [DirectorsChairCore.Scene] {
        project.sequences.flatMap { $0.scenes }
    }

    /// Get all shots across all scenes
    var allShots: [Shot] {
        allScenes.flatMap { $0.shots }
    }

    /// Get all characters in the project
    var characters: [Character] {
        project.characters
    }

    /// Get all sequences in the project
    var sequences: [DirectorsChairCore.Sequence] {
        project.sequences
    }
}

// MARK: - Project Extension

extension Project {
    /// Create an empty project with default structure
    static func empty() -> Project {
        Project(
            name: "Untitled Project",
            basePath: "",
            description: "",
            director: "",
            productionCompany: "",
            genre: "",
            projectType: "Skit",
            targetDuration: "",
            budget: "",
            startDate: "",
            endDate: "",
            status: "Pre-production",
            projectNotes: "",
            projectIcon: "",
            languages: ["English"],
            characters: [],
            props: [],
            costumes: [],
            lighting: [],
            effects: [],
            locations: [],
            sequences: [],
            beats: [],
            scheduleItems: [],
            filmStyles: [],
            defaultFilmStyle: nil,
            castMembers: [],
            crewMembers: [],
            teams: [],
            equipmentLibrary: [],
            userManager: nil,
            projectBudget: nil,
            overviewPosterPath: nil,
            overviewPosterPaths: [],
            overviewPosterCurrentIndex: 0,
            overviewPosterCustom: false,
            overviewSummary: "",
            overviewSummaryGeneratedAt: nil,
            overviewTagline: "",
            overviewLogline: "",
            overviewMoodAnalysis: nil
        )
    }
}
