// DirectorsChair-DesktopTests/AssistantBatchActionsTests.swift
//
// AI Assistant program, Phase A5.5: generate_missing_images — the batch
// sweep. Targets only entities missing images, sums per-entity costs into
// the plan's estimatedCost (the review card's batch-guideline input),
// delegates execution to the real per-entity actions, and survives
// individual failures.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantBatchActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var tempDir: URL!
    private var generatedPrompts: [String] = []
    private var failFor: Set<String> = []

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-batch-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir,
                                                 withIntermediateDirectories: true)
        var complete = Character(name: "Mara")
        complete.baseImage = "a.png"
        complete.imageThreeQuarterLeft = "b.png"
        complete.imageThreeQuarterRight = "c.png"
        var doneLocation = Location(name: "Rooftop")
        doneLocation.primaryImage = "assets/locations/Rooftop/primary.png"

        var project = Project(name: "Fixture Film")
        project.characters = [complete, Character(name: "Alexander")]
        project.locations = [doneLocation, Location(name: "Metro Station")]
        projectVM = ProjectViewModel(project: project)
        projectVM.projectPath = tempDir.appendingPathComponent("project.json")
        generatedPrompts = []
        failFor = []
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        projectVM = nil
        super.tearDown()
    }

    private func makeBatchAction() -> GenerateMissingImagesAction {
        let stub: @MainActor () -> CharacterImagePipeline.Generate = { [weak self] in
            { prompt, _, _ in
                let shouldFail = await MainActor.run { () -> Bool in
                    self?.generatedPrompts.append(prompt)
                    return self?.failFor.contains(where: { prompt.contains($0) }) ?? false
                }
                if shouldFail { throw ActionError("provider down") }
                return Data("fake-png".utf8)
            }
        }
        let imageStub: @MainActor () -> AssistantImageGenerate = { [weak self] in
            { prompt, _, _, _ in
                let shouldFail = await MainActor.run { () -> Bool in
                    self?.generatedPrompts.append(prompt)
                    return self?.failFor.contains(where: { prompt.contains($0) }) ?? false
                }
                if shouldFail { throw ActionError("provider down") }
                return Data("fake-png".utf8)
            }
        }
        return GenerateMissingImagesAction(
            projectViewModel: projectVM, coordinator: nil,
            characterAction: GenerateCharacterImagesAction(
                projectViewModel: projectVM, coordinator: nil, makeGenerate: stub),
            locationAction: GenerateLocationImagesAction(
                projectViewModel: projectVM, coordinator: nil, makeGenerate: imageStub))
    }

    private func args(_ json: String = "{}") -> Data { Data(json.utf8) }

    func testValidateTargetsOnlyMissingEntitiesWithBatchTotal() throws {
        let action = makeBatchAction()
        XCTAssertEqual(action.risk, .spending)

        let plan = try action.validate(argumentsData: args())
        // Alexander (3 missing angles) + Metro Station (1 primary) = 4 images.
        XCTAssertEqual(plan.previews.count, 2)
        XCTAssertTrue(plan.previews.contains { $0.title == "character · Alexander" })
        XCTAssertTrue(plan.previews.contains { $0.title == "location · Metro Station" })
        XCTAssertEqual(plan.estimatedCost, 0.16, accuracy: 0.001,
                       "4 images × $0.04 → the card's batch total")
        XCTAssertTrue(plan.summary.contains("$0.16"), plan.summary)

        let limited = try action.validate(argumentsData: args(#"{"limit": 1}"#))
        XCTAssertEqual(limited.previews.count, 1)
    }

    func testValidateErrorsWhenNothingIsMissing() throws {
        projectVM.project.characters[1].baseImage = "x.png"
        projectVM.project.characters[1].imageThreeQuarterLeft = "y.png"
        projectVM.project.characters[1].imageThreeQuarterRight = "z.png"
        projectVM.project.locations[1].primaryImage = "p.png"
        XCTAssertThrowsError(try makeBatchAction().validate(argumentsData: args())) {
            XCTAssertTrue("\($0)".contains("nothing to generate"))
        }
    }

    func testExecuteDelegatesToPerEntityActionsAndPersists() async throws {
        let action = makeBatchAction()
        _ = try await action.execute(argumentsData: args())

        // 3 character angles + 1 location primary through the real pipelines.
        XCTAssertEqual(generatedPrompts.count, 4)
        let alexander = projectVM.project.characters[1]
        XCTAssertNotNil(alexander.baseImage)
        XCTAssertNotNil(alexander.imageThreeQuarterLeft)
        XCTAssertNotNil(alexander.imageThreeQuarterRight)
        XCTAssertEqual(projectVM.project.locations[1].primaryImage,
                       "assets/locations/Metro_Station/primary.png")
        XCTAssertTrue(projectVM.isDirty)
    }

    func testExecuteSurvivesSingleEntityFailure() async throws {
        failFor = ["Metro Station"]   // location prompt contains the name
        let action = makeBatchAction()
        let outcome = try await action.execute(argumentsData: args())

        XCTAssertTrue(outcome.userSummary.contains("1 of 2"),
                      outcome.userSummary)
        XCTAssertNotNil(projectVM.project.characters[1].baseImage,
                        "the character sweep still completed")
        XCTAssertNil(projectVM.project.locations[1].primaryImage)
    }
}
