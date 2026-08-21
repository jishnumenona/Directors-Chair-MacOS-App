// DirectorsChairServicesTests/InsightEngineTests.swift
//
// DC-0055: the engine seam. The scripted double is what UI tests lean on,
// so its contract is pinned here; the MLX engine's AVAILABILITY logic is
// pure filesystem + arch and tests without network — inference itself is
// exercised manually (a 2GB download has no place in a unit suite).

import XCTest
import DirectorsChairCore
@testable import DirectorsChairServices

final class InsightEngineTests: XCTestCase {

    // MARK: - Scripted double

    func testScriptedEngineHonorsAvailabilityAndScripts() async throws {
        let engine = ScriptedInsightEngine(
            availability: .needsDownload(expectedBytes: 42),
            responses: [.scriptStory: .success("Tight second act.")])

        // Not ready → refuses with the state it is in.
        do {
            _ = try await engine.insight(for: .scriptStory, context: "ctx")
            XCTFail("must refuse before prepare()")
        } catch let error as InsightEngineError {
            XCTAssertEqual(error, .notReady(.needsDownload(expectedBytes: 42)))
        }

        try await engine.prepare()
        let availability = await engine.availability()
        XCTAssertEqual(availability, .ready)
        XCTAssertEqual(engine.preparations, 1)

        let text = try await engine.insight(for: .scriptStory, context: "ctx")
        XCTAssertEqual(text, "Tight second act.")
        XCTAssertEqual(engine.requests.count, 2)
        XCTAssertEqual(engine.requests.last?.context, "ctx")

        // Unscripted family still answers deterministically.
        let fallback = try await engine.insight(for: .production, context: "p")
        XCTAssertEqual(fallback, "scripted insight for production")
    }

    // MARK: - MLX availability (no network, no model)

    func testMLXEngineAvailabilityLifecycle() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("insight-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = MLXInsightEngine(storageRoot: root)

        #if arch(arm64)
        // Fresh root → the one-time download is asked for, with its size.
        var state = await engine.availability()
        XCTAssertEqual(state,
                       .needsDownload(expectedBytes: engine.expectedDownloadBytes))

        // A completed download leaves the marker; presence = ready.
        try FileManager.default.createDirectory(at: root,
                                                withIntermediateDirectories: true)
        let marker = root.appendingPathComponent(
            ".ready-" + engine.modelId.replacingOccurrences(of: "/", with: "_"))
        try Data().write(to: marker)
        state = await engine.availability()
        XCTAssertEqual(state, .ready)
        #else
        let state = await engine.availability()
        guard case .unavailable = state else {
            return XCTFail("Intel must report unavailable, got \(state)")
        }
        #endif
    }

    func testMLXEngineRefusesInsightBeforeDownload() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("insight-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = MLXInsightEngine(storageRoot: root)
        do {
            _ = try await engine.insight(for: .overviewDigest, context: "ctx")
            XCTFail("must refuse without weights on disk")
        } catch let error as InsightEngineError {
            guard case .notReady = error else {
                return XCTFail("wrong error: \(error)")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}
