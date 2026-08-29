//
// Project+Reorder.swift
//
// Ordering is implicit in the model: `Project.sequences`, `Sequence.scenes`,
// and `Scene.shots` are ordered by array position, and every derived view
// (screenplay via ProjectToScriptConverter, timeline boundaries, bubble view,
// shot list) reads that order. So reordering the arrays here — plus firing the
// `.structure` project event — is what propagates a rearrangement across the
// whole app.
//
// Scene numbers are regenerated position-based by the screenplay converter, so
// scenes need no display-number fix-up. Shot display numbers (`shotId`) are
// stored, so any shot move renumbers the affected scene(s) to keep them 1…n.
//
// These are pure value mutations on `Project`, unit-tested independently of any
// view or view model.
//

import Foundation

public extension Project {

    // MARK: - Sequences

    /// Move the sequence with `id` to `targetIndex` (0-based, clamped).
    @discardableResult
    mutating func moveSequence(id: String, toIndex targetIndex: Int) -> Bool {
        guard let from = sequences.firstIndex(where: { $0.id == id }) else { return false }
        sequences = Self.moved(sequences, from: from, to: targetIndex)
        return true
    }

    /// SwiftUI `.onMove`-style reorder of sequences (used by drag-and-drop).
    mutating func moveSequences(fromOffsets: IndexSet, toOffset: Int) {
        sequences = Self.movedByOffsets(sequences, fromOffsets: fromOffsets, toOffset: toOffset)
    }

    // MARK: - Scenes

    /// Move a scene to `targetIndex` within its own sequence.
    @discardableResult
    mutating func moveScene(id sceneId: String, toIndex targetIndex: Int) -> Bool {
        guard let loc = sceneLocation(sceneId) else { return false }
        sequences[loc.seq].scenes = Self.moved(sequences[loc.seq].scenes, from: loc.scene, to: targetIndex)
        return true
    }

    /// SwiftUI `.onMove`-style reorder of scenes within a sequence.
    mutating func moveScenes(inSequenceId sequenceId: String, fromOffsets: IndexSet, toOffset: Int) {
        guard let s = sequences.firstIndex(where: { $0.id == sequenceId }) else { return }
        sequences[s].scenes = Self.movedByOffsets(sequences[s].scenes, fromOffsets: fromOffsets, toOffset: toOffset)
    }

    /// Move a scene into another sequence at `targetIndex` (cross-parent). If the
    /// destination is its current sequence, this is an in-sequence reorder.
    @discardableResult
    mutating func moveScene(id sceneId: String, toSequenceId targetSequenceId: String, atIndex targetIndex: Int) -> Bool {
        guard let loc = sceneLocation(sceneId),
              let dest = sequences.firstIndex(where: { $0.id == targetSequenceId }) else { return false }
        if loc.seq == dest { return moveScene(id: sceneId, toIndex: targetIndex) }
        let scene = sequences[loc.seq].scenes.remove(at: loc.scene)
        let clamped = max(0, min(targetIndex, sequences[dest].scenes.count))
        sequences[dest].scenes.insert(scene, at: clamped)
        return true
    }

    // MARK: - Shots

    /// Move a shot to `targetIndex` within its own scene, then renumber that
    /// scene's shot display numbers to match the new order.
    @discardableResult
    mutating func moveShot(id shotUUID: String, toIndex targetIndex: Int) -> Bool {
        guard let loc = shotLocation(shotUUID) else { return false }
        sequences[loc.seq].scenes[loc.scene].shots =
            Self.moved(sequences[loc.seq].scenes[loc.scene].shots, from: loc.shot, to: targetIndex)
        renumberShots(seq: loc.seq, scene: loc.scene)
        return true
    }

    /// SwiftUI `.onMove`-style reorder of a scene's shots (renumbers after).
    mutating func moveShots(inSceneId sceneId: String, fromOffsets: IndexSet, toOffset: Int) {
        guard let loc = sceneLocation(sceneId) else { return }
        sequences[loc.seq].scenes[loc.scene].shots =
            Self.movedByOffsets(sequences[loc.seq].scenes[loc.scene].shots, fromOffsets: fromOffsets, toOffset: toOffset)
        renumberShots(seq: loc.seq, scene: loc.scene)
    }

    /// Move a shot into another scene at `targetIndex` (cross-parent); renumbers
    /// both the source and destination scenes.
    @discardableResult
    mutating func moveShot(id shotUUID: String, toSceneId targetSceneId: String, atIndex targetIndex: Int) -> Bool {
        guard let loc = shotLocation(shotUUID),
              let dest = sceneLocation(targetSceneId) else { return false }
        if loc.seq == dest.seq && loc.scene == dest.scene { return moveShot(id: shotUUID, toIndex: targetIndex) }
        let shot = sequences[loc.seq].scenes[loc.scene].shots.remove(at: loc.shot)
        let clamped = max(0, min(targetIndex, sequences[dest.seq].scenes[dest.scene].shots.count))
        sequences[dest.seq].scenes[dest.scene].shots.insert(shot, at: clamped)
        renumberShots(seq: loc.seq, scene: loc.scene)
        renumberShots(seq: dest.seq, scene: dest.scene)
        return true
    }

    /// Resequence a scene's shot display numbers (`shotId`) to 1…n by order.
    @discardableResult
    mutating func renumberShots(inSceneId sceneId: String) -> Bool {
        guard let loc = sceneLocation(sceneId) else { return false }
        renumberShots(seq: loc.seq, scene: loc.scene)
        return true
    }

    // MARK: - Private

    private mutating func renumberShots(seq: Int, scene: Int) {
        for i in sequences[seq].scenes[scene].shots.indices {
            sequences[seq].scenes[scene].shots[i].shotId = i + 1
        }
    }

    private func sceneLocation(_ sceneId: String) -> (seq: Int, scene: Int)? {
        for (s, sequence) in sequences.enumerated() {
            if let sc = sequence.scenes.firstIndex(where: { $0.id == sceneId }) { return (s, sc) }
        }
        return nil
    }

    private func shotLocation(_ shotUUID: String) -> (seq: Int, scene: Int, shot: Int)? {
        for (s, sequence) in sequences.enumerated() {
            for (sc, scene) in sequence.scenes.enumerated() {
                if let sh = scene.shots.firstIndex(where: { $0.id == shotUUID }) { return (s, sc, sh) }
            }
        }
        return nil
    }

    /// Remove the element at `from` and reinsert it at `to` (clamped to the
    /// post-removal bounds), treating `to` as the desired final index.
    private static func moved<T>(_ array: [T], from: Int, to: Int) -> [T] {
        guard from >= 0, from < array.count else { return array }
        var a = array
        let item = a.remove(at: from)
        a.insert(item, at: max(0, min(to, a.count)))
        return a
    }

    /// SwiftUI `move(fromOffsets:toOffset:)` semantics, implemented without a
    /// SwiftUI dependency (this package stays UI-free): the elements at `source`
    /// are lifted out in order and reinserted at `destination`, where
    /// `destination` is expressed in the *original* index space.
    private static func movedByOffsets<T>(_ array: [T], fromOffsets source: IndexSet, toOffset destination: Int) -> [T] {
        let valid = source.filter { $0 >= 0 && $0 < array.count }
        guard !valid.isEmpty else { return array }
        var a = array
        let moving = valid.sorted().map { array[$0] }
        for idx in valid.sorted(by: >) { a.remove(at: idx) }
        let removedBefore = valid.filter { $0 < destination }.count
        let insertAt = max(0, min(destination - removedBefore, a.count))
        a.insert(contentsOf: moving, at: insertAt)
        return a
    }
}
