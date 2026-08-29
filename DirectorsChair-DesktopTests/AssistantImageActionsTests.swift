// DirectorsChair-DesktopTests/AssistantImageActionsTests.swift
//
// AI Assistant program, Phase A5.2: scene/location/vision-board image
// actions — spending-risk cost previews, primary-first reference chaining
// for location variations, exact file/field conventions, offline stubs.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantImageActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var tempDir: URL!
    private var calls: [(prompt: String, aspect: String, reference: String?, brief: VisualBrief?)] = []

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-imgactions-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir,
                                                 withIntermediateDirectories: true)
        var project = Project(name: "Fixture Film")
        project.sequences = [Sequence(name: "Act 1", scenes: [
            Scene(name: "Opening", description: "Night. Rain."),
        ])]
        project.locations = [Location(name: "Rooftop",
                                      description: "Wind-swept concrete rooftop")]
        projectVM = ProjectViewModel(project: project)
        projectVM.projectPath = tempDir.appendingPathComponent("project.json")
        calls = []
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        projectVM = nil
        super.tearDown()
    }

    private func makeGenerate() -> @MainActor () -> AssistantImageGenerate {
        { [weak self] in
            { prompt, aspect, reference, brief in
                await MainActor.run {
                    self?.calls.append((prompt, aspect, reference, brief))
                }
                return Data("fake-png".utf8)
            }
        }
    }

    private func args(_ json: String) -> Data { Data(json.utf8) }

    // MARK: - Scene overview

    func testSceneImageValidatesExecutesAndSetsField() async throws {
        let action = GenerateSceneImageAction(
            projectViewModel: projectVM, coordinator: nil,
            makeGenerate: makeGenerate())
        XCTAssertEqual(action.risk, .spending)

        let plan = try action.validate(argumentsData: args(#"{"scene": "Opening"}"#))
        XCTAssertTrue(plan.summary.contains("$0.04"))
        XCTAssertEqual(plan.previews[0].oldValue, "none")
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"scene": "Nowhere"}"#)))

        _ = try await action.execute(argumentsData:
            args(#"{"scene": "Opening", "custom_prompt": "storm over the city"}"#))
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].aspect, "16:9")
        XCTAssertTrue(calls[0].prompt.contains("storm over the city"))
        let scene = projectVM.project.sequences[0].scenes[0]
        XCTAssertEqual(scene.sceneOverviewImage,
                       "assets/scenes/Opening/overview_latest.png")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent(scene.sceneOverviewImage!).path))
        XCTAssertTrue(projectVM.isDirty)
    }

    // MARK: - Location variations

    func testLocationImagesPrimaryFirstWithReferenceChaining() async throws {
        let action = GenerateLocationImagesAction(
            projectViewModel: projectVM, coordinator: nil,
            makeGenerate: makeGenerate())

        let plan = try action.validate(argumentsData: args(
            #"{"location": "Rooftop", "variations": ["night", "primary"]}"#))
        XCTAssertEqual(plan.previews.count, 2)
        XCTAssertTrue(plan.summary.contains("$0.08"))
        XCTAssertTrue(plan.warnings.isEmpty, "primary included → no warning")

        _ = try await action.execute(argumentsData: args(
            #"{"location": "Rooftop", "variations": ["night", "primary"]}"#))
        // primary sorted first, then night referencing it
        XCTAssertEqual(calls.count, 2)
        XCTAssertNil(calls[0].reference)
        XCTAssertTrue(calls[0].prompt.contains("establishing shot"))
        XCTAssertNotNil(calls[1].reference, "variation references the primary")
        XCTAssertTrue(calls[1].prompt.contains("night"))
        // The on-device engine draws from the brief: a location purpose (empty
        // place, Vision redraw) with the variation as a property of the place.
        XCTAssertEqual(calls[0].brief?.purpose, .location)
        XCTAssertTrue(calls[0].brief?.subject.hasPrefix("Rooftop") == true, calls[0].brief?.subject ?? "nil")
        XCTAssertEqual(calls[1].brief?.purpose, .location)
        XCTAssertTrue(calls[1].brief?.subject.contains("at night") == true, calls[1].brief?.subject ?? "nil")

        let location = projectVM.project.locations[0]
        XCTAssertEqual(location.primaryImage, "assets/locations/Rooftop/primary.png")
        XCTAssertEqual(Set(location.images),
                       ["assets/locations/Rooftop/primary.png",
                        "assets/locations/Rooftop/night.png"])
    }

    func testLocationImagesWarnsWithoutPrimaryAndRejectsBadNames() throws {
        let action = GenerateLocationImagesAction(
            projectViewModel: projectVM, coordinator: nil,
            makeGenerate: makeGenerate())
        let plan = try action.validate(argumentsData: args(
            #"{"location": "Rooftop", "variations": ["night"]}"#))
        XCTAssertEqual(plan.warnings.count, 1, "no primary to reference")

        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"location": "Rooftop", "variations": ["night!!"]}"#)))
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"location": "Moonbase"}"#))) { error in
            XCTAssertTrue("\(error)".contains("Rooftop"), "lists known locations")
        }
    }

    // MARK: - Vision board

    func testVisionBoardImageAppendsCardAtFreeSlot() async throws {
        let action = GenerateVisionBoardImageAction(
            projectViewModel: projectVM, coordinator: nil,
            makeGenerate: makeGenerate())
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"prompt": "  "}"#)))

        let outcome = try await action.execute(argumentsData:
            args(#"{"prompt": "neon rain reflections"}"#))
        XCTAssertTrue(calls[0].prompt.hasPrefix("Cinematic mood-board reference image:"))
        XCTAssertTrue(outcome.userSummary.contains("card"),
                      "summary reports a visible card, not just a file")

        // The Slice-3 point: a real card on the board, not an orphaned file.
        XCTAssertEqual(projectVM.project.beats.count, 1)
        let card = projectVM.project.beats[0]
        XCTAssertEqual(card.boardId, "master")
        XCTAssertEqual(card.title, "neon rain reflections")
        XCTAssertEqual(card.canvasX, 0, "first free grid slot on an empty board")
        XCTAssertEqual(card.canvasY, 0)
        XCTAssertEqual(card.canvasWidth, 200)
        XCTAssertEqual(card.imagePath?.hasPrefix("assets/visionboard/vision_"),
                       true, "relative path, portable project")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent(card.imagePath!).path))
        XCTAssertTrue(projectVM.isDirty)
    }

    func testConsecutiveVisionBoardCardsLandAdjacentWithDistinctFiles() async throws {
        let action = GenerateVisionBoardImageAction(
            projectViewModel: projectVM, coordinator: nil,
            makeGenerate: makeGenerate())
        _ = try await action.execute(argumentsData: args(#"{"prompt": "first"}"#))
        _ = try await action.execute(argumentsData: args(#"{"prompt": "second"}"#))

        let cards = projectVM.project.beats
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[1].canvasX, 220, "next free grid slot — adjacent")
        XCTAssertEqual(cards[1].canvasY, 0)
        XCTAssertGreaterThan(cards[1].zOrder, cards[0].zOrder)
        XCTAssertNotEqual(cards[0].imagePath, cards[1].imagePath,
                          "same-second epoch names get collision suffixes")
        let files = try FileManager.default.contentsOfDirectory(
            atPath: tempDir.appendingPathComponent("assets/visionboard").path)
        XCTAssertEqual(files.count, 2)
    }
}
