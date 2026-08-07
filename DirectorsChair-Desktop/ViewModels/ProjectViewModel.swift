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

                // App-wide undo (P0 §2.16c): every durable edit in the app
                // — shots, production tables, curation picks, boards,
                // characters — commits through THIS property, so one
                // snapshot here is undo for all of them. Project is a
                // value type: the captured snapshot shares storage with
                // the live one until either mutates, so a deep history is
                // cheap. Registered synchronously so NSUndoManager's
                // per-event grouping coalesces bursts the way the user
                // perceives them: one gesture, one undo.
                let previous = self.undoBaseline
                self.undoBaseline = project
                if !self.isRestoringUndo, !self.isLoading,
                   let previous,
                   self.shouldRecordUndo?() ?? true,
                   let manager = self.windowUndoManager {
                    // Commits can land OUTSIDE any event — an assistant
                    // action finishing on a background task, a sync
                    // applying — where the per-event group isn't open and
                    // registering would hit "invalid state". Such a
                    // commit gets its own group: one async commit, one
                    // undo step.
                    let needsOwnGroup = manager.groupingLevel == 0
                    if needsOwnGroup { manager.beginUndoGrouping() }
                    manager.registerUndo(withTarget: self) { target in
                        target.applyUndoSnapshot(previous)
                    }
                    if !manager.isUndoing, !manager.isRedoing {
                        manager.setActionName(
                            self.undoActionNameProvider?() ?? "Edit")
                    }
                    if needsOwnGroup { manager.endUndoGrouping() }
                }

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

        // An autosave that LANDED clears the dirty flag — before this the
        // indicator claimed unsaved changes forever, even though every
        // edit had been on disk within ~500ms (P0 audit: truthful state).
        autoSaveManager.$lastSaveDate
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] date in
                guard let self else { return }
                // Success is the ONLY thing that ends a failure streak —
                // each new save request clears lastError, and treating
                // that as recovery kept the streak at 1 forever.
                self.autosaveFailureStreak = 0
                guard !self.autoSaveManager.hasUnsavedChanges else { return }
                self.isDirty = false
                self.lastSaved = date
            }
            .store(in: &cancellables)

        // An autosave that keeps FAILING must say so — a user can edit for
        // an hour believing the 500ms autosave has them covered while a
        // full disk fails every write in silence (P0 audit: no silent
        // failure loops). One alert per failure streak, not one per tick.
        autoSaveManager.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                guard let error else { return }
                self?.registerAutosaveFailure(error)
            }
            .store(in: &cancellables)
    }

    // MARK: - App-wide undo (P0 §2.16c)

    /// The focused window's undo manager, pushed in by ContentView from
    /// the SwiftUI environment. Using the WINDOW's manager — not a
    /// private stack — is what makes the system Edit menu, ⌘Z/⇧⌘Z, and
    /// text-field-local undo all behave: a focused text field's own
    /// manager still wins while it has focus, exactly as in every
    /// professional Mac app.
    weak var windowUndoManager: UndoManager? {
        didSet { windowUndoManager?.levelsOfUndo = 100 }
    }

    /// The script editor has its own deep, typing-grained undo; while it
    /// is frontmost, project snapshots stay out of the way. Wired by
    /// ContentView from the coordinator.
    var shouldRecordUndo: (() -> Bool)?

    /// "Undo Shot List Edit" beats "Undo Edit" — wired to the frontmost
    /// surface's name.
    var undoActionNameProvider: (() -> String)?

    /// The last committed project value — what an undo returns to.
    private var undoBaseline: Project?
    private var isRestoringUndo = false

    /// Applies a snapshot as the current project, registering the inverse
    /// so redo works. Restores are themselves edits: they mark the
    /// project dirty and ride the same autosave as any other change.
    func applyUndoSnapshot(_ snapshot: Project) {
        let current = project
        if let manager = windowUndoManager {
            let needsOwnGroup = manager.groupingLevel == 0
            if needsOwnGroup { manager.beginUndoGrouping() }
            manager.registerUndo(withTarget: self) { target in
                target.applyUndoSnapshot(current)
            }
            if needsOwnGroup { manager.endUndoGrouping() }
        }
        isRestoringUndo = true
        project = snapshot
        isRestoringUndo = false
    }

    /// Opening or closing a project is not an edit: undo must never carry
    /// a document across into a different document's history.
    func resetUndoHistory() {
        windowUndoManager?.removeAllActions(withTarget: self)
        undoBaseline = hasProject ? project : nil
    }

    /// Consecutive autosave failures; reset by any success. Internal so
    /// the streak contract is testable without simulating a dying disk.
    private(set) var autosaveFailureStreak = 0

    func registerAutosaveFailure(_ error: Error) {
        autosaveFailureStreak += 1
        // One alert per streak: silence was the audit finding, but an
        // alert per failed tick would be worse than the disease.
        if autosaveFailureStreak == 3 {
            errorAlert = ErrorAlert(
                title: "Autosave Is Failing",
                message: "Your last few changes could not be saved "
                    + "automatically (\(error.localizedDescription)). "
                    + "Save manually with \u{2318}S, or check disk space "
                    + "and permissions."
            )
        }
    }

    // MARK: - Lifecycle flushes (P0: no lost work)

    /// Everything pending, on disk, NOW. Called on app deactivation and
    /// quit — the two moments a crash-adjacent exit is most likely (force
    /// quit from the Dock, logout, update installers killing apps).
    func flushPendingSaves() async {
        guard hasProject, let path = projectPath, isWritable(url: path) else {
            return
        }
        guard isDirty || autoSaveManager.hasUnsavedChanges else { return }
        do {
            try await autoSaveManager.saveImmediately(project: project, to: path)
            isDirty = false
            lastSaved = Date()
        } catch {
            // Deactivation is not the moment for a modal; the failure-streak
            // observer above will surface persistent trouble.
            debugLog("[ProjectViewModel] Lifecycle flush failed: \(error.localizedDescription)")
        }
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
            // A fresh document starts a fresh history — never undo across
            // documents.
            resetUndoHistory()
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
        isRestoringUndo = true       // closing is not an undoable edit
        project = Project.empty()
        isRestoringUndo = false
        projectPath = nil
        isDirty = false
        lastSaved = nil
        hasProject = false
        projectStorageSize = 0
        resetUndoHistory()
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
