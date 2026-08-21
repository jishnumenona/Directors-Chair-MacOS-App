// DirectorsChairViewsTests/InsightsViewModelTests.swift
//
// DC-0055: the panel's view model against the scripted engine — the
// download consent flow, the run/result/failed states per family, and
// that the engine receives a BUILT context, never a raw project dump.

import XCTest
import DirectorsChairCore
import DirectorsChairServices
@testable import DirectorsChairViews

@MainActor
final class InsightsViewModelTests: XCTestCase {

    private func project() -> Project {
        var project = Project(name: "Golden Film")
        project.genre = "Noir"
        project.sequences = [Sequence(name: "Act 1", scenes: [
            Scene(name: "Opening", description: "Rain.")])]
        return project
    }

    func testDownloadFlowReachesReady() async throws {
        let engine = ScriptedInsightEngine(
            availability: .needsDownload(expectedBytes: 1_900_000_000))
        let viewModel = InsightsViewModel(engine: engine)

        await viewModel.refreshAvailability()
        XCTAssertEqual(viewModel.availability,
                       .needsDownload(expectedBytes: 1_900_000_000))

        await viewModel.download()
        XCTAssertEqual(viewModel.availability, .ready)
        XCTAssertEqual(engine.preparations, 1)
    }

    func testRunProducesResultPerFamilyAndSendsBuiltContext() async throws {
        let engine = ScriptedInsightEngine(
            responses: [.scriptStory: .success("Strong opening image.")])
        let viewModel = InsightsViewModel(engine: engine)

        await viewModel.run(family: .scriptStory, project: project())
        XCTAssertEqual(viewModel.state(for: .scriptStory),
                       .result("Strong opening image."))
        // Other families stay untouched.
        XCTAssertEqual(viewModel.state(for: .production), .idle)

        // The engine got the compact BUILT context, not a JSON dump.
        let sent = try XCTUnwrap(engine.requests.last)
        XCTAssertTrue(sent.context.contains("PROJECT: Golden Film — Noir"))
        XCTAssertTrue(sent.context.contains("SCENE Opening"))
        XCTAssertFalse(sent.context.contains("{"))
    }

    func testFailureLandsAsReadableMessage() async {
        let engine = ScriptedInsightEngine(
            responses: [.production: .failure(.inferenceFailed("boom"))])
        let viewModel = InsightsViewModel(engine: engine)

        await viewModel.run(family: .production, project: project())
        guard case .failed(let message) = viewModel.state(for: .production) else {
            return XCTFail("expected failed state")
        }
        XCTAssertTrue(message.contains("couldn't finish"), message)
        XCTAssertFalse(message.contains("boom"),
                       "raw engine errors must not leak into the UI")
    }

    func testNotReadyRefusalExplainsItself() async {
        let engine = ScriptedInsightEngine(
            availability: .unavailable(reason: "On-device insights need an Apple Silicon Mac."))
        let viewModel = InsightsViewModel(engine: engine)

        await viewModel.run(family: .overviewDigest, project: project())
        guard case .failed(let message) = viewModel.state(for: .overviewDigest) else {
            return XCTFail("expected failed state")
        }
        XCTAssertEqual(message, "On-device insights need an Apple Silicon Mac.")
    }
}
