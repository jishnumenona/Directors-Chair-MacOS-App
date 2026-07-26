// DirectorsChair-DesktopTests/AssistantWorldActionsTests.swift
//
// AI Assistant program, Phase A4 slice 2: locations, props, costumes
// (wardrobe assignment + unknown-character warning), and shot editing
// with canonical statuses.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantWorldActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var registry: ActionRegistry!

    override func setUp() {
        super.setUp()
        var project = Project(name: "Fixture Film")
        project.sequences = [Sequence(name: "Act 1", scenes: [
            Scene(name: "Opening", description: "d",
                  shots: [Shot(shotId: 7, description: "Wide")]),
        ])]
        project.characters = [Character(name: "Mara")]
        project.locations = [Location(name: "Rooftop")]
        projectVM = ProjectViewModel(project: project)
        registry = AssistantActionFactory.makeRegistry(
            projectViewModel: projectVM, coordinator: nil)
    }

    override func tearDown() {
        projectVM = nil
        registry = nil
        super.tearDown()
    }

    private func action(_ name: String) -> any AssistantAction {
        registry.action(named: name)!
    }

    private func args(_ json: String) -> Data { Data(json.utf8) }

    func testAddLocationAndPropRejectDuplicates() async throws {
        _ = try await action("add_location").execute(argumentsData: args(
            #"{"name": "Metro Station", "description": "Tiled, echoing."}"#))
        XCTAssertEqual(projectVM.project.locations.count, 2)
        XCTAssertThrowsError(try action("add_location").validate(argumentsData:
            args(#"{"name": "rooftop"}"#)))

        _ = try await action("add_prop").execute(argumentsData: args(
            #"{"name": "Brass key", "category": "Document"}"#))
        XCTAssertEqual(projectVM.project.props[0].category, "Document")
        XCTAssertThrowsError(try action("add_prop").validate(argumentsData:
            args(#"{"name": "Brass Key"}"#)))
    }

    func testAddCostumeAssignsWardrobeAndWarnsOnUnknownCharacter() async throws {
        let costume = action("add_costume")
        let known = args(#"{"name": "Rain coat", "character": "Mara"}"#)
        XCTAssertTrue(try costume.validate(argumentsData: known).warnings.isEmpty)
        _ = try await costume.execute(argumentsData: known)
        XCTAssertEqual(projectVM.project.costumes[0].character, "Mara")

        let unknown = try costume.validate(argumentsData: args(
            #"{"name": "Disguise", "character": "Stranger"}"#))
        XCTAssertEqual(unknown.warnings.count, 1)
    }

    func testUpdateShotCanonicalizesStatusAndFindsByNumber() async throws {
        let update = action("update_shot")
        let payload = args(#"{"shot": 7, "new_status": "approved", "new_camera_angle": "Low"}"#)
        let plan = try update.validate(argumentsData: payload)
        XCTAssertEqual(plan.previews.count, 2)

        _ = try await update.execute(argumentsData: payload)
        let shot = projectVM.project.sequences[0].scenes[0].shots[0]
        XCTAssertEqual(shot.status, "Approved")
        XCTAssertEqual(shot.cameraAngle, "Low")

        XCTAssertThrowsError(try update.validate(argumentsData: args(
            #"{"shot": 99, "new_status": "Ready"}"#)))
        XCTAssertThrowsError(try update.validate(argumentsData: args(
            #"{"shot": 7, "new_status": "Deleted"}"#)))
        XCTAssertThrowsError(try update.validate(argumentsData: args(#"{"shot": 7}"#)))
    }
}
