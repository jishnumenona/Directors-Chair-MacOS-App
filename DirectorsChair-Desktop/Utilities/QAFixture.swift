//
//  QAFixture.swift
//  DirectorsChair-Desktop
//
//  Deterministic fixture project for automated UI (E2E) testing.
//  Launching with `--qa-fixture` regenerates and opens a small, byte-stable
//  project so every UI test run asserts against identical content.
//  See qa/README.md for the QA framework this serves.
//

import Foundation
import DirectorsChairCore

@MainActor
enum QAFixture {

    static let projectName = "QA Fixture"

    nonisolated static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("--qa-fixture")
    }

    /// Regenerate the fixture on disk (small: 3 scenes × ~30 items, 2 shots
    /// each — big enough to exercise flows, small enough to stay fast) and
    /// open it. Deterministic: same seed, same content, every run.
    static func prepareAndOpen(projectViewModel: ProjectViewModel,
                               coordinator: AppCoordinator) async {
        var project = StressProjectGenerator.makeProject(
            scenes: 3, shotsPerScene: 2, seed: 0x0AF1_57AB)
        project.name = projectName

        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Directors Chair")
            .appendingPathComponent("local")
            .appendingPathComponent(projectName)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("project.json")

        let persistence = ProjectPersistence(enableBackups: false)
        do {
            try await persistence.save(project, to: url)
            NSLog("[QAFixture] fixture saved to %@", url.path)
        } catch {
            NSLog("[QAFixture] SAVE FAILED: %@", String(describing: error))
        }
        do {
            try await projectViewModel.load(from: url)
            NSLog("[QAFixture] fixture loaded, hasProject=%d", projectViewModel.hasProject ? 1 : 0)
        } catch {
            NSLog("[QAFixture] LOAD FAILED: %@", String(describing: error))
        }
        // Win the race against the auth .onChange handler, which also
        // navigates on launch. Re-assert overview after the current run
        // loop turn so the fixture view is what the tests see.
        coordinator.navigateTo(.overview)
        try? await Task.sleep(nanoseconds: 200_000_000)
        coordinator.navigateTo(.overview)
        NSLog("[QAFixture] ready on overview, selectedView=%@", coordinator.selectedView.rawValue)
    }
}
