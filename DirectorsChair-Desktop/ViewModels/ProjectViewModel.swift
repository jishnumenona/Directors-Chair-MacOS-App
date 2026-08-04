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
import DirectorsChairServices

/// Main project view model - manages project state and persistence
/// Replaces Python's Project QObject with auto-save
@MainActor
class ProjectViewModel: ObservableObject {
    // MARK: - UserDefaults Keys

    private enum UserDefaultsKeys {
        /// Per-user key so each login remembers their own last project
        static var lastProjectPath: String {
            "lastProjectPath_\(ProjectDirectoryManager.currentUsername)"
        }
    }

    // MARK: - Published Properties

    /// Current project
    @Published var project: Project

    /// Whether project has unsaved changes
    @Published var isDirty = false

    /// Last save timestamp
    @Published var lastSaved: Date?

    /// Current project file path
    @Published var projectPath: URL? {
        didSet {
            // Save to UserDefaults whenever project path changes
            saveLastProjectPath()
        }
    }

    /// Whether a project is currently loaded
    @Published var hasProject: Bool

    /// Error alert for user-facing errors
    @Published var errorAlert: ErrorAlert?

    /// Loading state for async operations
    @Published var isLoading = false

    /// Project directory storage size in bytes
    @Published var projectStorageSize: Int64 = 0

    // MARK: - Private Properties

    private let persistence: ProjectPersistence
    private let autoSaveManager: DebouncedSaveManager
    private var cancellables = Set<AnyCancellable>()
    private var storageSizeTimer: Timer?

    // MARK: - Initialization

    init(project: Project? = nil) {
        self.project = project ?? Project.empty()
        self.hasProject = project != nil
        self.persistence = ProjectPersistence()
        self.autoSaveManager = DebouncedSaveManager()

        setupAutoSave()
    }

    // MARK: - Last Project Persistence

    /// Save the current project path to UserDefaults
    private func saveLastProjectPath() {
        if let path = projectPath {
            UserDefaults.standard.set(path.path, forKey: UserDefaultsKeys.lastProjectPath)
        } else {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastProjectPath)
        }
    }

    /// Get the last opened project path from UserDefaults
    static func getLastProjectPath() -> URL? {
        guard let pathString = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastProjectPath) else {
            return nil
        }
        let url = URL(fileURLWithPath: pathString)
        // Verify file still exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    /// Restore the last opened project on app launch
    func restoreLastProject() async {
        guard let lastPath = Self.getLastProjectPath() else {
            return
        }

        do {
            try await load(from: lastPath)
        } catch {
            // Failed to load last project - clear the saved path
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastProjectPath)
        }
    }

    // MARK: - Auto-Save Setup

    private func setupAutoSave() {
        // Watch for project changes and trigger auto-save
        $project
            .dropFirst() // Skip initial value
            .sink { [weak self] project in
                guard let self = self else { return }

                // Defer property changes to avoid publishing during view updates
                Task { @MainActor in
                    self.isDirty = true

                    // Request auto-save if we have a project path and it's writable
                    if let path = self.projectPath, self.isWritable(url: path) {
                        self.autoSaveManager.requestSave(project: project, to: path)
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// Check if a file location is writable
    private func isWritable(url: URL) -> Bool {
        let parentDir = url.deletingLastPathComponent()
        return FileManager.default.isWritableFile(atPath: parentDir.path)
    }

    // MARK: - Project Operations

    /// Create a new empty project with default name
    func createNew() {
        createNew(named: "Untitled Project")
    }

    /// Create a new project with a specific name
    /// Automatically creates directory structure in ~/Directors Chair/{ProjectName}/
    func createNew(named projectName: String) {
        // Generate unique name if project already exists
        let uniqueName = ProjectDirectoryManager.uniqueProjectName(baseName: projectName)

        do {
            // Create project directory structure
            let projectDir = try ProjectDirectoryManager.createProjectDirectory(named: uniqueName)
            let projectFileURL = ProjectDirectoryManager.projectFileURL(in: projectDir)

            // Create new project with the name and base path
            var newProject = Project.empty()
            newProject.name = uniqueName
            newProject.basePath = projectDir.path

            // Set project state
            project = newProject
            projectPath = projectFileURL
            isDirty = true
            lastSaved = nil
            hasProject = true

            startStorageSizeTimer()
            AIUsageTracker.shared.setProjectName(uniqueName)

            // Auto-save the new project immediately
            Task {
                await save()
            }
        } catch {
            // Fallback to in-memory project if directory creation fails
            errorAlert = ErrorAlert(
                title: "Failed to Create Project Directory",
                message: "Could not create project folder: \(error.localizedDescription). Project will be created in memory - use Save As to choose a location."
            )

            project = Project.empty()
            project.name = uniqueName
            projectPath = nil
            isDirty = false
            lastSaved = nil
            hasProject = true
        }
    }

    /// Load project from file path
    func load(from path: URL) async throws {
        isLoading = true
        let loadStart = DispatchTime.now().uptimeNanoseconds
        defer {
            isLoading = false
            PerfCounters.shared.record(name: "project.load",
                                       nanoseconds: DispatchTime.now().uptimeNanoseconds - loadStart)
        }

        do {
            var loadedProject = try await persistence.load(from: path)
            // Ensure basePath is set to the project directory (path points to project.json)
            let projectDir = path.deletingLastPathComponent()
            if loadedProject.basePath.isEmpty || !FileManager.default.fileExists(atPath: loadedProject.basePath) {
                loadedProject.basePath = projectDir.path
            }
            project = loadedProject
            projectPath = path
            isDirty = false
            lastSaved = Date()
            hasProject = true
            startStorageSizeTimer()
            AIUsageTracker.shared.setProjectName(loadedProject.name)

            // Warn if location is read-only
            if !isWritable(url: path) {
                errorAlert = ErrorAlert(
                    title: "Read-Only Location",
                    message: "This project is in a read-only location. Changes cannot be auto-saved. Use 'Save As' to save to a writable location."
                )
            }
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

        // Check if location is writable
        guard isWritable(url: path) else {
            errorAlert = ErrorAlert(
                title: "Cannot Save",
                message: "This project is in a read-only location. Use 'Save As' to save to a writable location."
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

    /// Save silently without showing loading indicator (for frequent background saves like timeline drag)
    func saveSilently() async {
        guard let path = projectPath, isWritable(url: path) else { return }
        do {
            try await persistence.save(project, to: path)
            isDirty = false
            lastSaved = Date()
        } catch {
            // Silent save failures are non-critical; log but don't show alert
            debugLog("[ProjectViewModel] Silent save failed: \(error.localizedDescription)")
        }
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

        stopStorageSizeTimer()
        project = Project.empty()
        projectPath = nil
        isDirty = false
        lastSaved = nil
        hasProject = false
        projectStorageSize = 0
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

    /// Remove a scene from a specific sequence
    func removeScene(_ scene: DirectorsChairCore.Scene, fromSequenceId sequenceId: String) {
        guard let index = project.sequences.firstIndex(where: { $0.id == sequenceId }) else { return }
        // Explicit copy-and-reassign to guarantee @Published fires objectWillChange
        // for all observers (OutlineTab, ScenesListView, etc.).
        // In-place mutation of nested structs can be missed by SwiftUI change detection.
        var updated = project
        updated.sequences[index].scenes.removeAll { $0.id == scene.id }
        project = updated
        isDirty = true
    }

    /// Add a scene to a specific sequence
    func addScene(_ scene: DirectorsChairCore.Scene, toSequenceId sequenceId: String) {
        guard let index = project.sequences.firstIndex(where: { $0.id == sequenceId }) else { return }
        project.sequences[index].scenes.append(scene)
        isDirty = true
    }

    /// Add a shot to a specific scene within a sequence
    func addShot(_ shot: Shot, toSceneId sceneId: String, inSequenceId sequenceId: String) {
        guard let seqIndex = project.sequences.firstIndex(where: { $0.id == sequenceId }),
              let scnIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        project.sequences[seqIndex].scenes[scnIndex].shots.append(shot)
        isDirty = true
    }

    /// Remove a shot from a specific scene within a sequence
    func removeShot(_ shot: Shot, fromSceneId sceneId: String, inSequenceId sequenceId: String) {
        guard let seqIndex = project.sequences.firstIndex(where: { $0.id == sequenceId }),
              let scnIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        project.sequences[seqIndex].scenes[scnIndex].shots.removeAll { $0.id == shot.id }
        isDirty = true
    }

    /// Rename a scene within a sequence
    func renameScene(_ sceneId: String, inSequenceId sequenceId: String, newName: String) {
        guard let seqIndex = project.sequences.firstIndex(where: { $0.id == sequenceId }),
              let scnIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        var updated = project
        updated.sequences[seqIndex].scenes[scnIndex].name = newName
        project = updated
        isDirty = true
    }

    // MARK: - Reorder (navigator)
    //
    // All order is array position (Project+Reorder), and every derived view —
    // screenplay, timeline, bubble — reads that order, so a mutation here plus a
    // `.structure` event from the caller propagates the rearrangement app-wide.
    // Copy-and-reassign guarantees @Published fires for nested-struct changes.

    @discardableResult
    func moveSequence(id: String, toIndex index: Int) -> Bool {
        var updated = project
        guard updated.moveSequence(id: id, toIndex: index) else { return false }
        project = updated; isDirty = true; return true
    }

    @discardableResult
    func moveScene(id sceneId: String, toIndex index: Int) -> Bool {
        var updated = project
        guard updated.moveScene(id: sceneId, toIndex: index) else { return false }
        project = updated; isDirty = true; return true
    }

    @discardableResult
    func moveScene(id sceneId: String, toSequenceId sequenceId: String, atIndex index: Int) -> Bool {
        var updated = project
        guard updated.moveScene(id: sceneId, toSequenceId: sequenceId, atIndex: index) else { return false }
        project = updated; isDirty = true; return true
    }

    @discardableResult
    func moveShot(id shotId: String, toIndex index: Int) -> Bool {
        var updated = project
        guard updated.moveShot(id: shotId, toIndex: index) else { return false }
        project = updated; isDirty = true; return true
    }

    @discardableResult
    func moveShot(id shotId: String, toSceneId sceneId: String, atIndex index: Int) -> Bool {
        var updated = project
        guard updated.moveShot(id: shotId, toSceneId: sceneId, atIndex: index) else { return false }
        project = updated; isDirty = true; return true
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

    // MARK: - Storage Size

    func updateStorageSize() {
        guard let path = projectPath else {
            projectStorageSize = 0
            return
        }
        let projectDir = path.deletingLastPathComponent()
        Task.detached {
            let size = StorageSizeCalculator.directorySize(at: projectDir)
            await MainActor.run { self.projectStorageSize = size }
        }
    }

    func startStorageSizeTimer() {
        storageSizeTimer?.invalidate()
        updateStorageSize()
        storageSizeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStorageSize()
            }
        }
    }

    func stopStorageSizeTimer() {
        storageSizeTimer?.invalidate()
        storageSizeTimer = nil
    }

    // MARK: - Video Generation Persistence (WS6.1)
    //
    // App-scoped shot mutations used by VideoJobCoordinator so a video job
    // persists its result even after the generation view is gone. Mutating the
    // @Published project triggers the auto-save sink.

    /// Set (or clear) the in-flight video generation job id on a shot.
    func setShotVideoJobId(shotId: String, jobId: String?) {
        mutateShot(shotId) { $0.videoGenerationJobId = jobId }
    }

    /// Record a completed generated video on a shot and clear its job id.
    func setShotVideoPath(shotId: String, videoRelativePath: String) {
        mutateShot(shotId) {
            $0.videoPath = videoRelativePath
            $0.videoGenerationJobId = nil
        }
    }

    private func mutateShot(_ shotId: String, _ body: (inout Shot) -> Void) {
        for si in project.sequences.indices {
            for sci in project.sequences[si].scenes.indices {
                if let shi = project.sequences[si].scenes[sci].shots.firstIndex(where: { $0.id == shotId }) {
                    body(&project.sequences[si].scenes[sci].shots[shi])
                    return
                }
            }
        }
    }
}

// MARK: - Project Extension

extension Project {
    /// Create an empty project with default structure and sample content
    /// Includes a sample character, sequence, scene, dialogue, and shot
    /// so users understand the app's structure
    static func empty() -> Project {
        // Create a sample character
        let sampleCharacter = Character(
            characterId: "sample_alex",
            name: "Alex",
            role: "Protagonist",
            color: "#3498db",
            textColor: "#FFFFFF",
            about: "The main character of your story. Edit or replace this sample character.",
            gender: "neutral",
            age: 30
        )

        // Create a sample dialogue
        let sampleDialogue = Dialogue(
            uuid: UUID().uuidString,
            character: "Alex",
            text: "This is a sample dialogue line. Click to edit or add new dialogue.",
            tags: ["sample"],
            chronologyNumber: 1,
            globalChronologyNumber: 1
        )

        // Create a sample shot
        let sampleShot = Shot(
            shotId: 1,
            itemChronology: 1,
            description: "Medium shot of Alex speaking. This is a sample shot to demonstrate shot planning.",
            status: "Planning",
            cameraAngle: "Medium",
            lensMm: 50,
            aperture: "f/2.8",
            shotType: "Standard",
            movement: "Static"
        )

        // Create a sample scene with the dialogue and shot
        let sampleScene = DirectorsChairCore.Scene(
            name: "Scene 1 - Introduction",
            description: "This is a sample scene to help you get started. Edit or replace it with your own scenes.",
            dialogues: [sampleDialogue],
            shots: [sampleShot],
            productionStatus: "Planning"
        )

        // Create a sample sequence with the scene
        let sampleSequence = DirectorsChairCore.Sequence(
            name: "Act 1 - Opening",
            description: "This is a sample sequence (act). Organize your scenes into sequences to structure your story.",
            scenes: [sampleScene]
        )

        return Project(
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
            characters: [sampleCharacter],
            props: [],
            costumes: [],
            lighting: [],
            effects: [],
            locations: [],
            sequences: [sampleSequence],
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
