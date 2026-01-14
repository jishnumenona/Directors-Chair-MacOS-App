// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/CinematographyViewModel.swift
//
// Cinematography ViewModel - State Management for Shot Planning
// Manages shots, camera settings, and cinematography configuration.

import SwiftUI
import DirectorsChairCore
import Combine

// MARK: - Cinematography ViewModel

@MainActor
public class CinematographyViewModel: ObservableObject {
    // MARK: - Published Properties

    /// All shots in the scene
    @Published public var shots: [Shot] = []

    /// Currently selected shot ID
    @Published public var selectedShotId: String?

    /// Current view mode
    @Published public var viewMode: CinematographyViewMode = .shotList

    /// Filter by shot status
    @Published public var filterByStatus: ShotStatus?

    /// Filter by shot type
    @Published public var filterByShotType: String?

    /// Search query
    @Published public var searchQuery: String = ""

    /// Show shot editor
    @Published public var showingShotEditor: Bool = false

    /// Shot being edited
    @Published public var editingShot: Shot?

    /// Current scene context
    @Published public var currentSceneId: String?

    // MARK: - Camera Presets

    @Published public var cameraPresets: [CameraPreset] = CameraPreset.defaultPresets

    /// Currently selected camera preset
    @Published public var selectedPresetId: String?

    // MARK: - Callbacks

    /// Callback when shots change (for persistence)
    public var onShotsChanged: (([Shot]) -> Void)?

    // MARK: - Computed Properties

    /// Filtered shots based on current criteria
    public var filteredShots: [Shot] {
        var result = shots

        if let status = filterByStatus {
            result = result.filter { $0.status == status.rawValue }
        }

        if let shotType = filterByShotType, !shotType.isEmpty {
            result = result.filter { $0.shotType == shotType }
        }

        if !searchQuery.isEmpty {
            result = result.filter {
                $0.description.localizedCaseInsensitiveContains(searchQuery) ||
                $0.cameraAngle.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        return result.sorted { $0.shotId < $1.shotId }
    }

    /// Currently selected shot
    public var selectedShot: Shot? {
        guard let id = selectedShotId else { return nil }
        return shots.first { $0.id == id }
    }

    /// Shot count by status
    public var shotCountByStatus: [ShotStatus: Int] {
        Dictionary(grouping: shots, by: { ShotStatus(rawValue: $0.status) ?? .planning })
            .mapValues { $0.count }
    }

    /// Total estimated duration of all shots
    public var totalDuration: Double {
        shots.compactMap { $0.duration }.reduce(0, +)
    }

    /// Available shot types used
    public var usedShotTypes: [String] {
        let types = Set(shots.map { $0.shotType })
        return Array(types).sorted()
    }

    /// Next available shot ID
    public var nextShotId: Int {
        (shots.map { $0.shotId }.max() ?? 0) + 1
    }

    // MARK: - Initialization

    public init(shots: [Shot] = []) {
        self.shots = shots
    }

    // MARK: - Shot CRUD Operations

    /// Add a new shot
    public func addShot(_ shot: Shot) {
        shots.append(shot)
        notifyChange()
    }

    /// Update an existing shot
    public func updateShot(_ shot: Shot) {
        if let index = shots.firstIndex(where: { $0.id == shot.id }) {
            shots[index] = shot
            notifyChange()
        }
    }

    /// Remove a shot by ID
    public func removeShot(_ shotId: String) {
        shots.removeAll { $0.id == shotId }
        if selectedShotId == shotId {
            selectedShotId = nil
        }
        notifyChange()
    }

    /// Duplicate a shot
    public func duplicateShot(_ shotId: String) {
        guard let shot = shots.first(where: { $0.id == shotId }) else { return }

        var newShot = shot
        newShot.shotId = nextShotId
        newShot.description = shot.description + " (copy)"

        shots.append(newShot)
        selectedShotId = newShot.id
        notifyChange()
    }

    // MARK: - Shot Editor

    /// Create a new shot for editing
    public func createNewShot() {
        var shot = Shot(shotId: nextShotId)

        // Apply preset if selected
        if let presetId = selectedPresetId,
           let preset = cameraPresets.first(where: { $0.id == presetId }) {
            shot = applyPreset(preset, to: shot)
        }

        editingShot = shot
        showingShotEditor = true
    }

    /// Edit an existing shot
    public func editShot(_ shot: Shot) {
        editingShot = shot
        showingShotEditor = true
    }

    /// Save the shot being edited
    public func saveEditedShot() {
        guard let shot = editingShot else { return }

        if shots.contains(where: { $0.id == shot.id }) {
            updateShot(shot)
        } else {
            addShot(shot)
        }

        editingShot = nil
        showingShotEditor = false
    }

    /// Cancel editing
    public func cancelEditing() {
        editingShot = nil
        showingShotEditor = false
    }

    // MARK: - Selection

    /// Select a shot
    public func selectShot(_ shotId: String?) {
        selectedShotId = shotId
    }

    /// Clear selection
    public func clearSelection() {
        selectedShotId = nil
    }

    // MARK: - Shot Status Management

    /// Update shot status
    public func updateShotStatus(_ shotId: String, status: ShotStatus) {
        if let index = shots.firstIndex(where: { $0.id == shotId }) {
            shots[index].status = status.rawValue
            notifyChange()
        }
    }

    /// Mark shot as ready
    public func markAsReady(_ shotId: String) {
        updateShotStatus(shotId, status: .ready)
    }

    /// Mark shot as shot (completed)
    public func markAsShot(_ shotId: String) {
        updateShotStatus(shotId, status: .shot)
    }

    /// Mark shot as approved
    public func markAsApproved(_ shotId: String) {
        updateShotStatus(shotId, status: .approved)
    }

    // MARK: - Camera Presets

    /// Apply a camera preset to a shot
    public func applyPreset(_ preset: CameraPreset, to shot: Shot) -> Shot {
        var newShot = shot
        newShot.cameraAngle = preset.cameraAngle
        newShot.lensMm = preset.lensMm
        newShot.aperture = preset.aperture
        newShot.shotType = preset.shotType
        newShot.movement = preset.movement
        return newShot
    }

    /// Add a custom preset
    public func addPreset(_ preset: CameraPreset) {
        cameraPresets.append(preset)
    }

    /// Remove a preset
    public func removePreset(_ presetId: String) {
        cameraPresets.removeAll { $0.id == presetId }
        if selectedPresetId == presetId {
            selectedPresetId = nil
        }
    }

    // MARK: - Bulk Operations

    /// Set all shots
    public func setShots(_ newShots: [Shot]) {
        shots = newShots
    }

    /// Clear all shots
    public func clearAllShots() {
        shots.removeAll()
        selectedShotId = nil
        notifyChange()
    }

    /// Reorder shots
    public func moveShot(from source: IndexSet, to destination: Int) {
        shots.move(fromOffsets: source, toOffset: destination)
        // Renumber shot IDs
        for (index, _) in shots.enumerated() {
            shots[index].shotId = index + 1
        }
        notifyChange()
    }

    // MARK: - Statistics

    /// Calculate completion percentage
    public var completionPercentage: Double {
        guard !shots.isEmpty else { return 0 }
        let completed = shots.filter { $0.status == ShotStatus.shot.rawValue || $0.status == ShotStatus.approved.rawValue }
        return Double(completed.count) / Double(shots.count) * 100
    }

    // MARK: - Private Helpers

    private func notifyChange() {
        onShotsChanged?(shots)
    }
}

// MARK: - Shot Status Enum

public enum ShotStatus: String, CaseIterable, Identifiable {
    case planning = "Planning"
    case ready = "Ready"
    case shooting = "Shooting"
    case shot = "Shot"
    case approved = "Approved"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .planning: return .gray
        case .ready: return .orange
        case .shooting: return .yellow
        case .shot: return .blue
        case .approved: return .green
        }
    }

    public var systemImage: String {
        switch self {
        case .planning: return "pencil"
        case .ready: return "checkmark.circle"
        case .shooting: return "video.fill"
        case .shot: return "film"
        case .approved: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Cinematography View Mode

public enum CinematographyViewMode: String, CaseIterable, Identifiable {
    case shotList = "Shot List"
    case storyboard = "Storyboard"
    case overhead = "Overhead View"
    case settings = "Camera Settings"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .shotList: return "list.bullet"
        case .storyboard: return "rectangle.split.3x3"
        case .overhead: return "arrow.up.left.and.arrow.down.right"
        case .settings: return "camera.aperture"
        }
    }
}

// MARK: - Camera Preset

public struct CameraPreset: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var cameraAngle: String
    public var lensMm: Int
    public var aperture: String
    public var shotType: String
    public var movement: String
    public var description: String
    public var isDefault: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        cameraAngle: String = "Medium",
        lensMm: Int = 50,
        aperture: String = "f/2.8",
        shotType: String = "Standard",
        movement: String = "Static",
        description: String = "",
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.cameraAngle = cameraAngle
        self.lensMm = lensMm
        self.aperture = aperture
        self.shotType = shotType
        self.movement = movement
        self.description = description
        self.isDefault = isDefault
    }

    // MARK: - Default Presets

    public static let defaultPresets: [CameraPreset] = [
        CameraPreset(
            id: "extreme_close_up",
            name: "Extreme Close-Up",
            cameraAngle: "Eye Level",
            lensMm: 85,
            aperture: "f/1.8",
            shotType: "ECU",
            movement: "Static",
            description: "Tight shot on eyes or detail",
            isDefault: true
        ),
        CameraPreset(
            id: "close_up",
            name: "Close-Up",
            cameraAngle: "Eye Level",
            lensMm: 85,
            aperture: "f/2.8",
            shotType: "CU",
            movement: "Static",
            description: "Face fills the frame",
            isDefault: true
        ),
        CameraPreset(
            id: "medium_close_up",
            name: "Medium Close-Up",
            cameraAngle: "Eye Level",
            lensMm: 50,
            aperture: "f/2.8",
            shotType: "MCU",
            movement: "Static",
            description: "Head and shoulders",
            isDefault: true
        ),
        CameraPreset(
            id: "medium_shot",
            name: "Medium Shot",
            cameraAngle: "Eye Level",
            lensMm: 35,
            aperture: "f/4",
            shotType: "MS",
            movement: "Static",
            description: "Waist up, conversation framing",
            isDefault: true
        ),
        CameraPreset(
            id: "medium_wide",
            name: "Medium Wide",
            cameraAngle: "Eye Level",
            lensMm: 28,
            aperture: "f/4",
            shotType: "MWS",
            movement: "Static",
            description: "Full body with some environment",
            isDefault: true
        ),
        CameraPreset(
            id: "wide_shot",
            name: "Wide Shot",
            cameraAngle: "Eye Level",
            lensMm: 24,
            aperture: "f/5.6",
            shotType: "WS",
            movement: "Static",
            description: "Full body, establishing environment",
            isDefault: true
        ),
        CameraPreset(
            id: "extreme_wide",
            name: "Extreme Wide Shot",
            cameraAngle: "High",
            lensMm: 16,
            aperture: "f/8",
            shotType: "EWS",
            movement: "Static",
            description: "Landscape, tiny subject",
            isDefault: true
        ),
        CameraPreset(
            id: "over_shoulder",
            name: "Over The Shoulder",
            cameraAngle: "Eye Level",
            lensMm: 50,
            aperture: "f/2.8",
            shotType: "OTS",
            movement: "Static",
            description: "Dialogue shot over one character's shoulder",
            isDefault: true
        ),
        CameraPreset(
            id: "two_shot",
            name: "Two Shot",
            cameraAngle: "Eye Level",
            lensMm: 35,
            aperture: "f/4",
            shotType: "2S",
            movement: "Static",
            description: "Two characters in frame",
            isDefault: true
        ),
        CameraPreset(
            id: "dolly_in",
            name: "Dolly In",
            cameraAngle: "Eye Level",
            lensMm: 35,
            aperture: "f/4",
            shotType: "MS",
            movement: "Dolly In",
            description: "Moving closer to subject",
            isDefault: true
        ),
        CameraPreset(
            id: "tracking",
            name: "Tracking Shot",
            cameraAngle: "Eye Level",
            lensMm: 28,
            aperture: "f/4",
            shotType: "MWS",
            movement: "Tracking",
            description: "Following subject movement",
            isDefault: true
        ),
        CameraPreset(
            id: "crane_down",
            name: "Crane Down",
            cameraAngle: "High",
            lensMm: 24,
            aperture: "f/5.6",
            shotType: "WS",
            movement: "Crane Down",
            description: "Descending crane reveal",
            isDefault: true
        ),
        CameraPreset(
            id: "dutch_angle",
            name: "Dutch Angle",
            cameraAngle: "Dutch",
            lensMm: 28,
            aperture: "f/4",
            shotType: "MS",
            movement: "Static",
            description: "Tilted frame for tension",
            isDefault: true
        ),
        CameraPreset(
            id: "low_angle",
            name: "Low Angle Hero",
            cameraAngle: "Low",
            lensMm: 24,
            aperture: "f/4",
            shotType: "MWS",
            movement: "Static",
            description: "Looking up at subject for power",
            isDefault: true
        ),
        CameraPreset(
            id: "high_angle",
            name: "High Angle",
            cameraAngle: "High",
            lensMm: 35,
            aperture: "f/4",
            shotType: "MS",
            movement: "Static",
            description: "Looking down at subject",
            isDefault: true
        )
    ]
}

// MARK: - Camera Angle Options

public struct CameraAngleOptions {
    public static let angles = [
        "Eye Level",
        "Low",
        "High",
        "Dutch",
        "Bird's Eye",
        "Worm's Eye",
        "POV"
    ]

    public static let movements = [
        "Static",
        "Pan Left",
        "Pan Right",
        "Tilt Up",
        "Tilt Down",
        "Dolly In",
        "Dolly Out",
        "Dolly Left",
        "Dolly Right",
        "Tracking",
        "Crane Up",
        "Crane Down",
        "Handheld",
        "Steadicam",
        "Zoom In",
        "Zoom Out",
        "Push In",
        "Pull Out",
        "Arc Left",
        "Arc Right",
        "Whip Pan"
    ]

    public static let shotTypes = [
        "ECU",  // Extreme Close-Up
        "CU",   // Close-Up
        "MCU",  // Medium Close-Up
        "MS",   // Medium Shot
        "MWS",  // Medium Wide Shot
        "WS",   // Wide Shot
        "EWS",  // Extreme Wide Shot
        "OTS",  // Over The Shoulder
        "2S",   // Two Shot
        "3S",   // Three Shot
        "Group",
        "Insert",
        "Cutaway",
        "POV",
        "Reaction"
    ]

    public static let commonLenses = [16, 24, 28, 35, 50, 85, 100, 135, 200]

    public static let commonApertures = [
        "f/1.2", "f/1.4", "f/1.8", "f/2", "f/2.8",
        "f/4", "f/5.6", "f/8", "f/11", "f/16"
    ]
}
