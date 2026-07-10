// DebouncedSaveManagerTests.swift
//
// Regression tests for the auto-save race conditions fixed in WS2.2:
//  (1) saveImmediately must not silently no-op while a save is in flight.
//  (2) a snapshot queued while an older save is being written must still land.

import XCTest
@testable import DirectorsChairCore

/// Controllable persistence double: records every saved project and can gate a
/// save on a signal so tests can drive the "newer edit arrives mid-write" race.
private actor SpyPersistence: ProjectPersisting {
    private(set) var saved: [(name: String, url: URL)] = []
    private var gate: CheckedContinuation<Void, Never>?
    private var gateArmed = false

    /// Arms a one-shot gate: the next save() suspends until `releaseGate()`.
    func armGate() { gateArmed = true }

    func releaseGate() {
        gate?.resume()
        gate = nil
        gateArmed = false
    }

    func save(_ project: Project, to url: URL) async throws {
        if gateArmed {
            gateArmed = false
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                gate = c
            }
        }
        saved.append((project.name, url))
    }

    func load(from url: URL) async throws -> Project {
        Project(name: "unused")
    }

    var savedNames: [String] { saved.map(\.name) }
}

@MainActor
final class DebouncedSaveManagerTests: XCTestCase {

    private func makeURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("dcm-\(UUID().uuidString).json")
    }

    /// Poll until `condition` holds. Fixed sleeps flaked on loaded CI
    /// runners (debounce timers fire late under contention); a generous
    /// deadline with tight polling is deterministic on any machine while
    /// staying fast on a quiet one.
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 5,
                           _ condition: () async -> Bool) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return true }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        return false
    }

    // (2) The newest snapshot must reach disk even if it is queued while an
    //     older snapshot is mid-write. Previously the post-await `pendingSave = nil`
    //     discarded it and cleared hasUnsavedChanges.
    func testNewerSnapshotQueuedDuringSaveIsNotLost() async throws {
        let spy = SpyPersistence()
        let manager = DebouncedSaveManager(persistence: spy, debounceInterval: 0.05)
        let url = makeURL()

        await spy.armGate()                                  // first save will suspend
        manager.requestSave(project: Project(name: "v1"), to: url)

        // Wait until the first save is actually in flight (gate suspended it).
        let inFlight = try await waitUntil { manager.isSaving }
        XCTAssertTrue(inFlight, "First save should be in flight")

        // Queue a newer snapshot while v1 is blocked mid-write.
        manager.requestSave(project: Project(name: "v2"), to: url)

        await spy.releaseGate()                              // let v1 finish
        // Wait for the drain loop to flush v2.
        let drained = try await waitUntil {
            await spy.savedNames == ["v1", "v2"] && !manager.hasUnsavedChanges
        }
        let names = await spy.savedNames
        XCTAssertEqual(names, ["v1", "v2"], "Both snapshots must be written, newest last")
        XCTAssertTrue(drained, "No unsaved changes once v2 is flushed")
    }

    // (1) saveImmediately must actually persist even when it coincides with an
    //     in-flight debounced save — never report success while writing nothing.
    func testSaveImmediatelyPersistsWhileSaveInFlight() async throws {
        let spy = SpyPersistence()
        let manager = DebouncedSaveManager(persistence: spy, debounceInterval: 0.05)
        let url = makeURL()

        await spy.armGate()
        manager.requestSave(project: Project(name: "a"), to: url)
        let inFlight = try await waitUntil { manager.isSaving }
        XCTAssertTrue(inFlight, "Debounced save should be in flight")

        // Kick off an immediate save of a newer snapshot; it should await the
        // in-flight save rather than silently returning.
        async let immediate: Void = manager.saveImmediately(project: Project(name: "b"), to: url)
        try await Task.sleep(nanoseconds: 50_000_000)
        await spy.releaseGate()
        try await immediate

        let names = await spy.savedNames
        XCTAssertTrue(names.contains("b"), "saveImmediately must persist its snapshot")
        XCTAssertEqual(names.last, "b", "Immediate save's snapshot should be the final write")
    }

    func testSuccessfulSaveClearsUnsavedFlag() async throws {
        let spy = SpyPersistence()
        let manager = DebouncedSaveManager(persistence: spy, debounceInterval: 0.05)
        try await manager.saveImmediately(project: Project(name: "solo"), to: makeURL())
        XCTAssertFalse(manager.hasUnsavedChanges)
        XCTAssertNil(manager.lastError)
        let names = await spy.savedNames
        XCTAssertEqual(names, ["solo"])
    }
}
