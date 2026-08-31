// DirectorsChairViews/Cinematography/ContinuityReferences.swift
//
// DC-0091: other shots' finished previews as reference pictures for the
// shot being generated, so a scene keeps its place, light, cast and
// wardrobe from one frame to the next (owner request 2026-08-29). Pure
// rules here — the shot page presents them, the generation call uses them.

import DirectorsChairCore
import DirectorsChairServices
import Foundation

enum ContinuityReferences {
    /// Reference pictures the on-device engine accepts (klein's practical
    /// limit); the cloud path takes a few more.
    static let onDeviceBudget = 4
    static let cloudBudget = 8

    /// The shots a user can pick as continuity references for `shot`: every
    /// other shot with a preview, the same scene's shots first (in shot
    /// order), then the rest.
    static func candidates(for shot: Shot, sceneShotIds: [String], allShots: [Shot]) -> [Shot] {
        let withPreview = allShots.filter { $0.id != shot.id && !($0.previewImage ?? "").isEmpty }
        let sameScene = withPreview.filter { sceneShotIds.contains($0.id) }.sorted { $0.shotId < $1.shotId }
        let others = withPreview.filter { !sceneShotIds.contains($0.id) }.sorted { $0.shotId < $1.shotId }
        return sameScene + others
    }

    /// The label a reference shot's picture travels under ("shot:Shot #3").
    static func label(for shot: Shot) -> String { "shot:Shot #\(shot.shotId)" }

    /// The shot's chosen references as pictures, in the order they were
    /// added, skipping any whose preview is gone from disk.
    static func referenceImages(for shot: Shot, allShots: [Shot], projectDirectory: URL) -> [ReferenceImage] {
        shot.referenceShotIds.compactMap { id -> ReferenceImage? in
            guard let other = allShots.first(where: { $0.id == id }),
                  let path = other.previewImage, !path.isEmpty,
                  let data = try? Data(contentsOf: projectDirectory.appendingPathComponent(path))
            else { return nil }
            return ReferenceImage(base64: data.base64EncodedString(), mimeType: "image/png", label: label(for: other))
        }
    }

    /// Continuity pictures first — they carry the most of the scene — then
    /// the location/character/costume/prop set, within the provider's budget.
    static func merged(continuity: [ReferenceImage], others: [ReferenceImage], onDevice: Bool) -> [ReferenceImage] {
        Array((continuity + others).prefix(onDevice ? onDeviceBudget : cloudBudget))
    }
}
