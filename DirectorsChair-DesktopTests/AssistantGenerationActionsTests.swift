// DirectorsChair-DesktopTests/AssistantGenerationActionsTests.swift
//
// AI Assistant program, Phase A5 slice 1: generate_character_images —
// spending risk with explicit cost previews, base-portrait-first ordering,
// skip-existing semantics, and file + field persistence through a stubbed
// (offline) generator.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantGenerationActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var tempDir: URL!
    private var promptsSeen: [String] = []
    private var referencesSeen: [String?] = []
    private var briefsSeen: [VisualBrief?] = []

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-genactions-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir,
                                                 withIntermediateDirectories: true)
        var project = Project(name: "Fixture Film")
        project.characters = [Character(name: "Alexander")]
        projectVM = ProjectViewModel(project: project)
        projectVM.projectPath = tempDir.appendingPathComponent("project.json")
        promptsSeen = []
        referencesSeen = []
        briefsSeen = []
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        projectVM = nil
        super.tearDown()
    }

    /// The action under test, with an offline stub generator that records
    /// its inputs and returns fake PNG bytes.
    private func makeAction() -> GenerateCharacterImagesAction {
        GenerateCharacterImagesAction(
            projectViewModel: projectVM, coordinator: nil,
            makeGenerate: { [weak self] in
                { prompt, reference, brief in
                    await MainActor.run {
                        self?.promptsSeen.append(prompt)
                        self?.referencesSeen.append(reference)
                        self?.briefsSeen.append(brief)
                    }
                    return Data("fake-png".utf8)
                }
            })
    }

    private func args(_ json: String) -> Data { Data(json.utf8) }

    /// The on-device engine draws the framing, not the prompt's prose: a
    /// profile request must carry the profile as framing or it comes back
    /// as the default front portrait (DC-0071 populate pass).
    func testEveryAngleCarriesTheStoryDesignBriefWithItsFraming() async throws {
        projectVM.project.characters[0].baseImage = "assets/characters/Alexander/face/front.png"
        let base = tempDir.appendingPathComponent(projectVM.project.characters[0].baseImage!)
        try FileManager.default.createDirectory(at: base.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("png".utf8).write(to: base)
        let action = makeAction()
        _ = try await action.execute(argumentsData: args(
            #"{"character": "Alexander", "angles": ["profile_left", "back"]}"#))
        XCTAssertEqual(briefsSeen.count, 2)
        let profile = try XCTUnwrap(briefsSeen[0])
        XCTAssertEqual(profile.purpose, .character)
        XCTAssertEqual(profile.subject, StoryboardSubjects.subject(for: projectVM.project.characters[0]))
        XCTAssertTrue(profile.framing?.contains("Exact left profile") == true, profile.framing ?? "nil")
        XCTAssertTrue(briefsSeen[1]?.framing?.contains("Back view") == true)
    }

    func testValidatePreviewsCostAndCountsOnlyMissingImages() throws {
        let action = makeAction()
        XCTAssertEqual(action.risk, .spending)

        let plan = try action.validate(argumentsData:
            args(#"{"character": "Alexander"}"#))
        XCTAssertEqual(plan.previews.count, 3, "default set = base + two ¾ views")
        XCTAssertTrue(plan.summary.contains("$0.12"), plan.summary)

        // With the base already present, only the missing angles remain.
        projectVM.project.characters[0].baseImage = "assets/existing.png"
        let partial = try action.validate(argumentsData:
            args(#"{"character": "Alexander"}"#))
        XCTAssertEqual(partial.previews.count, 2)
        XCTAssertTrue(partial.summary.contains("$0.08"), partial.summary)
    }

    func testValidateRejectsUnknownInputsAndFullyGeneratedSets() {
        let action = makeAction()
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"character": "Nobody"}"#)))
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"character": "Alexander", "angles": ["hero_shot"]}"#)))

        projectVM.project.characters[0].baseImage = "a.png"
        projectVM.project.characters[0].imageThreeQuarterLeft = "b.png"
        projectVM.project.characters[0].imageThreeQuarterRight = "c.png"
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"character": "Alexander"}"#))) { error in
            XCTAssertTrue("\(error)".contains("regenerate"))
        }
    }

    func testExecuteGeneratesBaseFirstSavesFilesAndSetsFields() async throws {
        let action = makeAction()
        _ = try await action.execute(argumentsData:
            args(#"{"character": "Alexander"}"#))

        let character = projectVM.project.characters[0]
        XCTAssertEqual(character.baseImage,
                       "assets/characters/Alexander/face/front.png")
        XCTAssertEqual(character.imageThreeQuarterLeft,
                       "assets/characters/Alexander/face/three_quarter_left.png")
        XCTAssertEqual(character.imageThreeQuarterRight,
                       "assets/characters/Alexander/face/three_quarter_right.png")
        XCTAssertTrue(projectVM.isDirty)

        // Files really exist on disk next to the project file.
        for path in [character.baseImage!, character.imageThreeQuarterLeft!] {
            let url = tempDir.appendingPathComponent(path)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), path)
        }

        // Base first (no reference), then angle views referencing the base.
        XCTAssertEqual(promptsSeen.count, 3)
        XCTAssertNil(referencesSeen[0], "base generates without a reference")
        XCTAssertNotNil(referencesSeen[1], "angle views reference the base")
        XCTAssertTrue(promptsSeen[0].contains("reference portrait"))
        XCTAssertTrue(promptsSeen[1].contains("Same person"))
    }

    func testExecuteUsesCustomBasePromptWhenSet() async throws {
        projectVM.project.characters[0].baseImagePrompt = "A weathered arctic explorer"
        let action = makeAction()
        _ = try await action.execute(argumentsData:
            args(#"{"character": "Alexander", "angles": ["base"]}"#))
        XCTAssertTrue(promptsSeen[0].contains("weathered arctic explorer"))
    }
}
