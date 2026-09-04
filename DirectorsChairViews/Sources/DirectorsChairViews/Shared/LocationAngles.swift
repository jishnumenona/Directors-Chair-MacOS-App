// DirectorsChairViews/Shared/LocationAngles.swift
//
// DC-0125 (owner 2026-09-04): a location's named camera angles — "Wide
// from the gate", "Reverse toward the bar" — resolved for a shot and
// spelled the one way every surface uses: "#Pier 9 / Wide from the gate"
// is the mention, the Studio library name and the reference label.

import DirectorsChairCore
import Foundation

enum LocationAngles {
    /// The mention text and library name of an angle.
    static func mention(location: Location, angle: LocationAngle) -> String {
        "\(location.name) / \(angle.name)"
    }

    /// The angle a shot chose, resolved through its scene's location (a
    /// scene names its location; the name is matched like everywhere else).
    static func resolve(shot: Shot, scene: DirectorsChairCore.Scene?,
                        locations: [Location]) -> (location: Location, angle: LocationAngle)? {
        guard let id = shot.locationAngleId, !id.isEmpty,
              let name = scene?.location, !name.isEmpty,
              let location = locations.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }),
              let angle = location.angle(withId: id) else { return nil }
        return (location, angle)
    }

    /// The angle's kept picture as a reference for the shot's generation —
    /// it stands in for the location's own picture (same place, the asked-for
    /// vantage), so it takes the location's slot rather than a second one.
    static func reference(for shot: Shot, scene: DirectorsChairCore.Scene?,
                          locations: [Location]) -> (path: String, label: String)? {
        guard let hit = resolve(shot: shot, scene: scene, locations: locations),
              let path = hit.angle.image, !path.isEmpty else { return nil }
        return (path, "angle:" + mention(location: hit.location, angle: hit.angle))
    }

    /// What the prompt says next to the location when the shot chose an angle.
    static func promptClause(for shot: Shot, location: Location) -> String {
        guard let angle = location.angle(withId: shot.locationAngleId) else { return "" }
        let detail = angle.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return ". Framed from the location's angle \"\(angle.name)\""
            + (detail.isEmpty ? "" : ": \(detail.prefix(200))")
    }
}

public extension Project {
    /// Every scene in order, for the Studio library's scene previews.
    var studioScenes: [DirectorsChairCore.Scene] { sequences.flatMap { $0.scenes } }
}
