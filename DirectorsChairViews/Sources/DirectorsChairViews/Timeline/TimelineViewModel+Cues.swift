//
// TimelineViewModel+Cues.swift
//
// Extracted from TimelineViewModel.swift (WS9.1 god-file decomposition).
//

import Foundation
import SwiftUI
import Combine
import DirectorsChairCore

extension TimelineViewModel {

    // MARK: - User Marker CRUD

    /// Add a user marker at the given time
    public func addUserMarker(at time: CGFloat, label: String = "Marker", icon: String = "flag.fill", color: String = "#FF5F5F") {
        let marker = TimelineMarker(
            time: time,
            label: label,
            kind: .user,
            color: color,
            icon: icon
        )
        userMarkers.append(marker)
        saveMarkers()
    }

    /// Update an existing user marker
    public func updateUserMarker(id: UUID, label: String, icon: String, color: String) {
        if let index = userMarkers.firstIndex(where: { $0.id == id }) {
            userMarkers[index].label = label
            userMarkers[index].icon = icon
            userMarkers[index].color = color
            saveMarkers()
        }
    }

    /// Delete a user marker
    public func deleteUserMarker(id: UUID) {
        userMarkers.removeAll { $0.id == id }
        saveMarkers()
    }

    // MARK: - Marker Persistence

    /// URL for the markers JSON file (sibling to project file)
    var markersFileURL: URL? {
        guard let projectPath = projectFilePath else { return nil }
        return projectPath.deletingLastPathComponent().appendingPathComponent("markers.json")
    }

    /// Save user markers to disk
    public func saveMarkers() {
        guard let url = markersFileURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(userMarkers)
            try data.write(to: url, options: .atomic)
        } catch {
            debugLog("[TimelineViewModel] Failed to save markers: \(error.localizedDescription)")
        }
    }

    /// Load user markers from disk
    public func loadMarkers() {
        guard let url = markersFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            userMarkers = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            userMarkers = try decoder.decode([TimelineMarker].self, from: data)
        } catch {
            debugLog("[TimelineViewModel] Failed to load markers: \(error.localizedDescription)")
            userMarkers = []
        }
    }

    /// Get the time for placing a marker: playhead time or viewport center
    public func getMarkerPlacementTime() -> CGFloat {
        if let t = playheadTime { return t }
        return getCurrentTimeFromViewport()
    }

    // MARK: - Light Cue CRUD

    /// Add a new light cue at the given time
    public func addLightCue(at time: CGFloat, name: String = "New Light Cue", color: String = "#FFD60A", intensity: Double = 1.0, duration: Double = 5.0) {
        let nextNumber = lightCues.count + 1
        let cue = LightCue(
            name: name,
            cueNumber: "Q\(nextNumber)",
            startTime: Double(time),
            duration: duration,
            intensity: intensity,
            color: color,
            markerColor: color
        )
        lightCues.append(cue)
        onLightCuesChanged?(lightCues)
        extendDurationIfNeeded()
    }

    /// Update an existing light cue
    public func updateLightCue(_ cue: LightCue) {
        if let index = lightCues.firstIndex(where: { $0.id == cue.id }) {
            lightCues[index] = cue
            onLightCuesChanged?(lightCues)
            extendDurationIfNeeded()
        }
    }

    /// Remove a light cue by ID
    public func removeLightCue(id: String) {
        lightCues.removeAll { $0.id == id }
        onLightCuesChanged?(lightCues)
    }

    // MARK: - SFX Cue CRUD

    /// Add a new SFX cue at the given time
    public func addSFXCue(at time: CGFloat, name: String = "New SFX Cue", effectType: SFXEffectType = .smoke, intensity: Double = 0.8, duration: Double = 5.0, color: String = "#FF6B35") {
        let nextNumber = sfxCues.count + 1
        let cue = SFXCue(
            name: name,
            cueNumber: "FX\(nextNumber)",
            effectType: effectType,
            startTime: Double(time),
            duration: duration,
            intensity: intensity,
            color: color,
            markerColor: color
        )
        sfxCues.append(cue)
        onSFXCuesChanged?(sfxCues)
        extendDurationIfNeeded()
    }

    /// Update an existing SFX cue
    public func updateSFXCue(_ cue: SFXCue) {
        if let index = sfxCues.firstIndex(where: { $0.id == cue.id }) {
            sfxCues[index] = cue
            onSFXCuesChanged?(sfxCues)
            extendDurationIfNeeded()
        }
    }

    /// Remove an SFX cue by ID
    public func removeSFXCue(id: String) {
        sfxCues.removeAll { $0.id == id }
        onSFXCuesChanged?(sfxCues)
    }

    // MARK: - Support Cue CRUD

    /// Add a new support cue at the given time
    public func addSupportCue(at time: CGFloat, name: String = "New Support Cue", actionType: SupportActionType = .propMove, duration: Double = 5.0, color: String = "#2DD4BF") {
        let nextNumber = supportCues.count + 1
        let cue = SupportCue(
            name: name,
            cueNumber: "S\(nextNumber)",
            actionType: actionType,
            startTime: Double(time),
            duration: duration,
            markerColor: color
        )
        supportCues.append(cue)
        onSupportCuesChanged?(supportCues)
        extendDurationIfNeeded()
    }

    /// Update an existing support cue
    public func updateSupportCue(_ cue: SupportCue) {
        if let index = supportCues.firstIndex(where: { $0.id == cue.id }) {
            supportCues[index] = cue
            onSupportCuesChanged?(supportCues)
            extendDurationIfNeeded()
        }
    }

    /// Remove a support cue by ID
    public func removeSupportCue(id: String) {
        supportCues.removeAll { $0.id == id }
        onSupportCuesChanged?(supportCues)
    }
}
