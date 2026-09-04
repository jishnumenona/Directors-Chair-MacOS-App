// DirectorsChairViews/Cinematography/MentionSync.swift
//
// Owner 2026-08-29: what a description mentions must show up in the shot's
// lists — "#Outside the mini van" in the text, "No location set" in the
// context card was wrong. On every description save: @ characters join the
// shot's cast, $ props join the scene's props, and a # location becomes
// the scene's location when it has none (an existing, different location
// is never overwritten silently — change it from the list).

import DirectorsChairCore
import Foundation

enum MentionSync {
    struct Result {
        var shot: Shot
        var scene: DCScene?
        var shotChanged = false
        var sceneChanged = false
    }

    static func apply(description: String, shot: Shot, scene: DCScene?,
                      characters: [Character], locations: [Location], props: [Prop]) -> Result {
        var result = Result(shot: shot, scene: scene)
        let tokens = MentionTokenizer.tokens(in: description, characters: characters, locations: locations,
                                             props: props, shots: [])
        for token in tokens {
            switch token.mention.kind {
            case .character:
                if !result.shot.characters.contains(where: { $0.caseInsensitiveCompare(token.mention.name) == .orderedSame }) {
                    result.shot.characters.append(token.mention.name)
                    result.shotChanged = true
                }
            case .location:
                guard var updated = result.scene else { continue }
                if (updated.location ?? "").isEmpty {
                    updated.location = token.mention.name
                    result.scene = updated
                    result.sceneChanged = true
                }
            case .prop:
                guard var updated = result.scene else { continue }
                if !updated.props.contains(where: { $0.caseInsensitiveCompare(token.mention.name) == .orderedSame }) {
                    updated.props.append(token.mention.name)
                    result.scene = updated
                    result.sceneChanged = true
                }
            case .angle:
                // DC-0125: naming "#Place / Angle" picks that angle for the shot
                // — and the place for a scene that has none yet.
                guard let location = locations.first(where: { $0.angles.contains { $0.id == token.mention.id } })
                else { continue }
                if result.shot.locationAngleId != token.mention.id {
                    result.shot.locationAngleId = token.mention.id
                    result.shotChanged = true
                }
                if var updated = result.scene, (updated.location ?? "").isEmpty {
                    updated.location = location.name
                    result.scene = updated
                    result.sceneChanged = true
                }
            case .shot:
                continue
            }
        }
        return result
    }
}
