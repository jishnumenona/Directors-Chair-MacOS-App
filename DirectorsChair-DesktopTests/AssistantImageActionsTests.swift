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
    private var calls: [(prompt: String, aspect: String, reference: String?)] = []

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
            { prompt, aspect, reference in
                await MainActor.run {
                    self?.calls.append((prompt, aspect, reference))
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

    func testVisionBoardImageWritesTimestampedFile() async throws {
        let action = GenerateVisionBoardImageAction(
            projectViewModel: projectVM, coordinator: nil,
            makeGenerate: makeGenerate())
        XCTAssertThrowsError(try action.validate(argumentsData:
            args(#"{"prompt": "  "}"#)))

        _ = try await action.execute(argumentsData:
            args(#"{"prompt": "neon rain reflections"}"#))
        XCTAssertTrue(calls[0].prompt.hasPrefix("Cinematic mood-board reference image:"))
        let boardDir = tempDir.appendingPathComponent("assets/visionboard")
        let files = try FileManager.default.contentsOfDirectory(atPath: boardDir.path)
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].hasPrefix("vision_"))
        XCTAssertTrue(projectVM.isDirty)
    }
}
