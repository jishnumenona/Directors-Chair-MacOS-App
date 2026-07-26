// DirectorsChair-DesktopTests/AssistantPeopleActionsTests.swift
//
// AI Assistant program, Phase A3.5: cast/crew/equipment-library actions —
// roster entries only (no pay/contact surface), duplicate rejection, and
// the uncast-character warning.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantPeopleActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var registry: ActionRegistry!

    override func setUp() {
        super.setUp()
        var project = Project(name: "Fixture Film")
        project.characters = [Character(name: "Mara")]
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

    func testAddCastMemberCanonicalizesRoleAndWarnsOnUnknownCharacter() async throws {
        let cast = action("add_cast_member")
        let known = args(#"{"actor": "Ada Vale", "character": "Mara", "role_type": "principal"}"#)
        let plan = try cast.validate(argumentsData: known)
        XCTAssertTrue(plan.warnings.isEmpty)
        XCTAssertTrue(plan.previews[0].title.contains("Principal"), "role canonicalized")

        _ = try await cast.execute(argumentsData: known)
        XCTAssertEqual(projectVM.project.castMembers.count, 1)
        XCTAssertEqual(projectVM.project.castMembers[0].dailyRate, 0,
                       "no pay surface — defaults only")

        // unknown character → warning, not error
        let unknown = try cast.validate(argumentsData:
            args(#"{"actor": "Sam Ito", "character": "Bartender"}"#))
        XCTAssertEqual(unknown.warnings.count, 1)

        // duplicate + bad role → errors
        XCTAssertThrowsError(try cast.validate(argumentsData: known))
        XCTAssertThrowsError(try cast.validate(argumentsData:
            args(#"{"actor": "X", "character": "Y", "role_type": "Cameo"}"#)))
    }

    func testAddCrewMemberDefaultsDepartmentAndRejectsDuplicates() async throws {
        let crew = action("add_crew_member")
        let payload = args(#"{"name": "Sam Reyes", "role": "Gaffer"}"#)
        _ = try crew.validate(argumentsData: payload)
        _ = try await crew.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.crewMembers[0].department, "Production")
        XCTAssertThrowsError(try crew.validate(argumentsData: payload))
    }

    func testAddEquipmentItemSetsQuantitiesAndRejectsDuplicates() async throws {
        let equipment = action("add_equipment_item")
        let payload = args(#"{"name": "Alexa 35", "category": "Camera", "quantity": 2, "rental": true}"#)
        _ = try await equipment.execute(argumentsData: payload)
        let item = projectVM.project.equipmentLibrary[0]
        XCTAssertEqual(item.quantityOwned, 2)
        XCTAssertEqual(item.quantityAvailable, 2)
        XCTAssertTrue(item.isRental)
        XCTAssertThrowsError(try equipment.validate(argumentsData: payload))
        XCTAssertThrowsError(try equipment.validate(argumentsData:
            args(#"{"name": "Tripod", "category": "Grip", "quantity": 0}"#)))
    }
}
