// DirectorsChairCoreTests/ProjectInsightsTests.swift
//
// DC-0055: the pure half of on-device insights. The context builders are
// what the local model actually reads — these tests pin that the right
// facts survive compression, that budgets truncate honestly (whole lines
// + an explicit omission marker), and that output is deterministic.

import XCTest
@testable import DirectorsChairCore

final class ProjectInsightsTests: XCTestCase {

    private func fixture() -> Project {
        var project = Project(name: "Golden Film")
        project.genre = "Noir"
        project.description = "A detective who cannot sleep."
        project.status = "Pre-production"
        project.characters = [Character(name: "Mara"), Character(name: "Ilya")]
        let opening = Scene(
            name: "Opening", description: "Rain on the precinct steps.",
            dialogues: [Dialogue(character: "Mara", text: "First line"),
                        Dialogue(character: "Ilya", text: "Second line"),
                        Dialogue(character: "Mara", text: "Third line")],
            shots: [Shot(shotId: 1, description: "Wide establishing")])
        let finale = Scene(name: "Finale", description: "The end")
        project.sequences = [Sequence(name: "Act 1", scenes: [opening, finale])]
        return project
    }

    // MARK: - Script & story

    func testScriptStoryContextCarriesTheStoryFacts() {
        let context = InsightContextBuilder.context(for: .scriptStory,
                                                    project: fixture())
        XCTAssertTrue(context.contains("Golden Film"))
        XCTAssertTrue(context.contains("Noir"))
        XCTAssertTrue(context.contains("LOGLINE: A detective who cannot sleep."))
        XCTAssertTrue(context.contains("CHARACTERS: Mara, Ilya"))
        XCTAssertTrue(context.contains("SCENE Opening"))
        XCTAssertTrue(context.contains("Rain on the precinct steps."))
        // Speakers deduped in first-appearance order, counts accurate.
        XCTAssertTrue(context.contains("speakers: Mara, Ilya"))
        XCTAssertTrue(context.contains("3 lines, 0 actions, 1 shots"))
    }

    // MARK: - Production

    func testProductionContextFlagsCoverageScheduleAndBudget() {
        var project = fixture()
        project.scheduleItems = [ScheduleItem(
            sceneId: project.sequences[0].scenes[0].uuid,
            sceneName: "Opening",
            shootDate: "2026-09-01",
            estimatedDurationHours: 13)]
        project.projectBudget = ProjectBudget(
            categories: [BudgetCategory(name: "Camera",
                                        allocated: 100, spent: 250)],
            totalBudget: 5000, currency: "USD")

        let context = InsightContextBuilder.context(for: .production,
                                                    project: project)
        XCTAssertTrue(context.contains("SCALE: 2 scenes, 1 shots"))
        // Finale has no shots — must be named as uncovered.
        XCTAssertTrue(context.contains("SCENES WITHOUT SHOTS (1): Finale"))
        XCTAssertTrue(context.contains("1 scenes not on the schedule"))
        XCTAssertTrue(context.contains("DAY 2026-09-01: 13h planned — OVERLOADED"))
        XCTAssertTrue(context.contains("Camera: 250 spent of 100 — OVER"))
    }

    // MARK: - Digest

    func testDigestJoinsBothWorlds() {
        let context = InsightContextBuilder.context(for: .overviewDigest,
                                                    project: fixture())
        XCTAssertTrue(context.contains("LOGLINE"))
        XCTAssertTrue(context.contains("SCALE:"))
        XCTAssertTrue(context.contains("\n---\n"))
    }

    // MARK: - Budgeting

    func testBudgetTruncatesWholeLinesAndSaysSo() {
        var project = fixture()
        // 200 scenes of detail — far past any small budget.
        let scenes = (1...200).map {
            Scene(name: "Scene \($0)", description: String(repeating: "x", count: 80))
        }
        project.sequences = [Sequence(name: "Act 1", scenes: scenes)]
        let context = InsightContextBuilder.context(for: .scriptStory,
                                                    project: project,
                                                    budget: 1_000)
        XCTAssertLessThanOrEqual(context.count, 1_100)
        XCTAssertTrue(context.hasSuffix("(further detail omitted for length)"))
        // The head (identity) always survives; no line is cut mid-way.
        XCTAssertTrue(context.hasPrefix("PROJECT: Golden Film"))
        XCTAssertFalse(context.contains("xxx\n"), "lines must never be split")
    }

    func testContextIsDeterministic() {
        let project = fixture()
        for family in InsightFamily.allCases {
            let a = InsightContextBuilder.context(for: family, project: project)
            let b = InsightContextBuilder.context(for: family, project: project)
            XCTAssertEqual(a, b, "\(family.rawValue) must be deterministic")
        }
    }

    // MARK: - Families

    func testFamilyIdentifiersAreStable() {
        // Raw values persist in caches/telemetry — renames are breaking.
        XCTAssertEqual(InsightFamily.scriptStory.rawValue, "script_story")
        XCTAssertEqual(InsightFamily.production.rawValue, "production")
        XCTAssertEqual(InsightFamily.overviewDigest.rawValue, "overview_digest")
        for family in InsightFamily.allCases {
            XCTAssertFalse(family.instructions.isEmpty)
            XCTAssertFalse(family.title.isEmpty)
        }
    }
}
