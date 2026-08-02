// DirectorsChairServices/Sync/ProjectOverviewBuilder.swift
//
// §12A overview projection, desktop half. The web portal's project
// Overview tab renders a pitch deck the server stores verbatim
// (app.project_overview); the intake endpoint existed but the desktop
// never pushed — every synced project showed "No overview yet". This
// builder projects a Project into the deck shape ProjectView.tsx
// renders, referencing images as same-origin blob URLs
// (/api/v1/projects/{id}/blobs/{sha}) — the sync push has already
// uploaded those exact files as SHA-addressed blobs.

import Foundation
import DirectorsChairCore

public enum ProjectOverviewBuilder {

    /// Builds the deck payload. Images that can't be resolved/hashed are
    /// simply omitted — the portal renders initials/placeholders.
    public static func deck(project: Project, projectDir: URL,
                            projectID: String) -> [String: Any] {
        func blobURL(_ path: String?) -> String? {
            guard let path, !path.isEmpty else { return nil }
            let url = path.hasPrefix("/")
                ? URL(fileURLWithPath: path)
                : projectDir.appendingPathComponent(path)
            // Only files inside the project dir are in the sync manifest;
            // anything outside was never uploaded, so emitting its sha
            // would 404 in the portal. Omit it → placeholder instead.
            let root = projectDir.resolvingSymlinksInPath().path
            guard url.resolvingSymlinksInPath().path
                .hasPrefix(root.hasSuffix("/") ? root : root + "/") else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            // /raw redirects to the presigned object so <img src> works;
            // the bare blob endpoint returns JSON for the sync engine.
            return "/api/v1/projects/\(projectID)/blobs/"
                + SyncHashing.sha256Hex(data) + "/raw"
        }

        var deck: [String: Any] = [:]
        func put(_ key: String, _ value: String?) {
            if let value, !value.isEmpty { deck[key] = value }
        }
        put("title", project.name)
        put("tagline", project.overviewTagline)
        put("logline", project.overviewLogline)
        put("pitch", project.overviewSummary)
        put("genre", project.genre)
        put("status", project.status)
        put("director", project.director)
        put("production_company", project.productionCompany)
        put("project_type", project.projectType)
        put("runtime", project.targetDuration)
        put("poster", blobURL(project.overviewPosterPath))

        deck["characters"] = project.characters.map { character -> [String: Any] in
            var entry: [String: Any] = ["id": character.name,
                                        "name": character.name]
            if let portrait = blobURL(character.avatar ?? character.baseImage
                                      ?? character.imageFront) {
                entry["portrait"] = portrait
            }
            return entry
        }

        deck["locations"] = project.locations.map { location -> [String: Any] in
            var entry: [String: Any] = ["name": location.name]
            if let image = blobURL(location.primaryImage) {
                entry["image"] = image
            }
            return entry
        }

        var sceneCount = 0
        var shotCount = 0
        // The renderer requires BOTH shapes: shots nested per scene AND a
        // flat top-level shot board (ProjectView dereferences deck.shots
        // unconditionally — its absence crashed the page).
        var shotBoard: [[String: Any]] = []
        deck["scenes"] = project.sequences.flatMap { sequence in
            sequence.scenes.map { scene -> [String: Any] in
                sceneCount += 1
                var entry: [String: Any] = ["id": scene.id,
                                            "name": scene.name,
                                            "sequence": sequence.name]
                if !scene.description.isEmpty {
                    entry["summary"] = scene.description
                }
                if let image = blobURL(scene.sceneOverviewImage) {
                    entry["image"] = image
                }
                entry["shots"] = scene.shots.map { shot -> [String: Any] in
                    shotCount += 1
                    var board: [String: Any] = ["id": "\(scene.id)#\(shot.shotId)",
                                                "scene": scene.name,
                                                "shot_type": shot.shotType]
                    // The AI-generated preview is what the desktop's own shot
                    // cards display; reference imagery is the fallback.
                    if let image = blobURL(shot.previewImage)
                        ?? blobURL(shot.referenceMedia.first(
                            where: { $0.type == .image })?.path) {
                        board["image"] = image
                    }
                    shotBoard.append(board)
                    return ["id": shot.shotId, "shot_type": shot.shotType]
                }
                return entry
            }
        }
        deck["shots"] = shotBoard

        deck["stats"] = ["characters": project.characters.count,
                         "locations": project.locations.count,
                         "scenes": sceneCount,
                         "shots": shotCount]
        return deck
    }
}
