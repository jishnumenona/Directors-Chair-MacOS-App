// DirectorsChairProduction/Tests/DirectorsChairProductionTests/CastCrewModelTests.swift
//
// Tests for CastMember, CrewMember, Team models and CastCrewViewModel logic.

import XCTest
@testable import DirectorsChairProduction
@testable import DirectorsChairCore

@MainActor
final class CastCrewModelTests: XCTestCase {

    var viewModel: CastCrewViewModel!

    override func setUp() {
        super.setUp()
        viewModel = CastCrewViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - CastMember Model

    func testCastMemberCreation() {
        let cast = CastMember(
            actorName: "John Smith",
            characterName: "Hero",
            roleType: "Principal",
            dailyRate: 500.0
        )

        XCTAssertEqual(cast.actorName, "John Smith")
        XCTAssertEqual(cast.characterName, "Hero")
        XCTAssertEqual(cast.roleType, "Principal")
        XCTAssertEqual(cast.dailyRate, 500.0)
        XCTAssertFalse(cast.id.isEmpty)
        XCTAssertTrue(cast.id.hasPrefix("cast_"))
        XCTAssertEqual(cast.unionStatus, "Non-Union")
        XCTAssertEqual(cast.paymentType, "Daily Rate")
        XCTAssertFalse(cast.contractSigned)
    }

    func testCastMemberDefaults() {
        let cast = CastMember()

        XCTAssertTrue(cast.actorName.isEmpty)
        XCTAssertTrue(cast.characterName.isEmpty)
        XCTAssertEqual(cast.roleType, "Principal")
        XCTAssertEqual(cast.dailyRate, 0.0)
        XCTAssertEqual(cast.oneTimePayment, 0.0)
        XCTAssertEqual(cast.overtimeRate, 0.0)
        XCTAssertFalse(cast.contractSigned)
        XCTAssertFalse(cast.contractManagedExternally)
    }

    // MARK: - CrewMember Model

    func testCrewMemberCreation() {
        let crew = CrewMember(
            name: "Jane Doe",
            role: "Director of Photography",
            department: "Camera",
            dailyRate: 800.0,
            kitFee: 150.0
        )

        XCTAssertEqual(crew.name, "Jane Doe")
        XCTAssertEqual(crew.role, "Director of Photography")
        XCTAssertEqual(crew.department, "Camera")
        XCTAssertEqual(crew.dailyRate, 800.0)
        XCTAssertEqual(crew.kitFee, 150.0)
        XCTAssertFalse(crew.id.isEmpty)
        XCTAssertTrue(crew.id.hasPrefix("crew_"))
        XCTAssertEqual(crew.employmentType, "Freelance")
    }

    func testCrewMemberDefaults() {
        let crew = CrewMember()

        XCTAssertTrue(crew.name.isEmpty)
        XCTAssertEqual(crew.department, "Production")
        XCTAssertEqual(crew.employmentType, "Freelance")
        XCTAssertEqual(crew.paymentType, "Daily Rate")
        XCTAssertEqual(crew.dailyRate, 0.0)
        XCTAssertEqual(crew.kitFee, 0.0)
        XCTAssertTrue(crew.skills.isEmpty)
        XCTAssertFalse(crew.contractSigned)
        XCTAssertFalse(crew.w9Received)
    }

    // MARK: - Team Model

    func testTeamCreation() {
        let team = Team(
            name: "A Unit",
            description: "Main shooting unit",
            teamType: "Shooting Unit",
            castMemberIds: ["cast_1", "cast_2"],
            crewMemberIds: ["crew_1", "crew_2", "crew_3"],
            teamLeadId: "crew_1"
        )

        XCTAssertEqual(team.name, "A Unit")
        XCTAssertEqual(team.description, "Main shooting unit")
        XCTAssertEqual(team.teamType, "Shooting Unit")
        XCTAssertEqual(team.castMemberIds.count, 2)
        XCTAssertEqual(team.crewMemberIds.count, 3)
        XCTAssertEqual(team.teamLeadId, "crew_1")
        XCTAssertFalse(team.id.isEmpty)
        XCTAssertTrue(team.id.hasPrefix("team_"))
    }

    // MARK: - Cast CRUD

    func testAddCastMember() {
        let cast = CastMember(actorName: "Alice", characterName: "Protagonist")
        viewModel.addCastMember(cast)

        XCTAssertEqual(viewModel.castMembers.count, 1)
        XCTAssertEqual(viewModel.castMembers.first?.actorName, "Alice")
    }

    func testUpdateCastMember() {
        var cast = CastMember(actorName: "Alice")
        viewModel.addCastMember(cast)

        cast.actorName = "Alice Updated"
        viewModel.updateCastMember(cast)

        XCTAssertEqual(viewModel.castMembers.first?.actorName, "Alice Updated")
    }

    func testRemoveCastMember() {
        let cast = CastMember(actorName: "Alice")
        viewModel.addCastMember(cast)

        // Also add to a team
        let team = Team(name: "Test Team", castMemberIds: [cast.id])
        viewModel.addTeam(team)

        viewModel.removeCastMember(cast)

        XCTAssertTrue(viewModel.castMembers.isEmpty)
        // Cast member should be removed from team too
        XCTAssertTrue(viewModel.teams.first?.castMemberIds.isEmpty ?? true)
    }

    // MARK: - Crew CRUD

    func testAddCrewMember() {
        let crew = CrewMember(name: "Bob", role: "Gaffer", department: "Lighting")
        viewModel.addCrewMember(crew)

        XCTAssertEqual(viewModel.crewMembers.count, 1)
        XCTAssertEqual(viewModel.crewMembers.first?.name, "Bob")
    }

    func testUpdateCrewMember() {
        var crew = CrewMember(name: "Bob")
        viewModel.addCrewMember(crew)

        crew.department = "Sound"
        viewModel.updateCrewMember(crew)

        XCTAssertEqual(viewModel.crewMembers.first?.department, "Sound")
    }

    func testRemoveCrewMember() {
        let crew = CrewMember(name: "Bob")
        viewModel.addCrewMember(crew)

        // Add as team lead
        let team = Team(name: "Test Team", crewMemberIds: [crew.id], teamLeadId: crew.id)
        viewModel.addTeam(team)

        viewModel.removeCrewMember(crew)

        XCTAssertTrue(viewModel.crewMembers.isEmpty)
        // Crew member should be removed from team and team lead cleared
        XCTAssertTrue(viewModel.teams.first?.crewMemberIds.isEmpty ?? true)
        XCTAssertNil(viewModel.teams.first?.teamLeadId)
    }

    // MARK: - Team CRUD

    func testAddTeam() {
        let team = Team(name: "B Unit")
        viewModel.addTeam(team)

        XCTAssertEqual(viewModel.teams.count, 1)
        XCTAssertEqual(viewModel.teams.first?.name, "B Unit")
    }

    func testUpdateTeam() {
        var team = Team(name: "B Unit")
        viewModel.addTeam(team)

        team.name = "A Unit"
        viewModel.updateTeam(team)

        XCTAssertEqual(viewModel.teams.first?.name, "A Unit")
    }

    func testRemoveTeam() {
        let team = Team(name: "Remove Me")
        viewModel.addTeam(team)

        viewModel.removeTeam(team)
        XCTAssertTrue(viewModel.teams.isEmpty)
    }

    // MARK: - Statistics

    func testTotalCastCount() {
        viewModel.addCastMember(CastMember(actorName: "A"))
        viewModel.addCastMember(CastMember(actorName: "B"))
        viewModel.addCastMember(CastMember(actorName: "C"))

        XCTAssertEqual(viewModel.totalCastCount, 3)
    }

    func testPrincipalCastCount() {
        viewModel.addCastMember(CastMember(actorName: "A", roleType: "Principal"))
        viewModel.addCastMember(CastMember(actorName: "B", roleType: "Supporting"))
        viewModel.addCastMember(CastMember(actorName: "C", roleType: "Principal"))

        XCTAssertEqual(viewModel.principalCastCount, 2)
    }

    func testSupportingCastCount() {
        viewModel.addCastMember(CastMember(actorName: "A", roleType: "Principal"))
        viewModel.addCastMember(CastMember(actorName: "B", roleType: "Supporting"))
        viewModel.addCastMember(CastMember(actorName: "C", roleType: "Supporting"))

        XCTAssertEqual(viewModel.supportingCastCount, 2)
    }

    func testTotalCrewCount() {
        viewModel.addCrewMember(CrewMember(name: "A"))
        viewModel.addCrewMember(CrewMember(name: "B"))

        XCTAssertEqual(viewModel.totalCrewCount, 2)
    }

    func testCrewByDepartment() {
        viewModel.addCrewMember(CrewMember(name: "A", department: "Camera"))
        viewModel.addCrewMember(CrewMember(name: "B", department: "Camera"))
        viewModel.addCrewMember(CrewMember(name: "C", department: "Sound"))

        let departments = viewModel.crewByDepartment
        XCTAssertEqual(departments["Camera"], 2)
        XCTAssertEqual(departments["Sound"], 1)
    }

    // MARK: - Daily Cost Calculation

    func testDailyCastCost() {
        viewModel.addCastMember(CastMember(actorName: "A", dailyRate: 500))
        viewModel.addCastMember(CastMember(actorName: "B", dailyRate: 300))

        XCTAssertEqual(viewModel.dailyCastCost, 800)
    }

    func testDailyCrewCost() {
        viewModel.addCrewMember(CrewMember(name: "A", dailyRate: 600))
        viewModel.addCrewMember(CrewMember(name: "B", dailyRate: 400))

        XCTAssertEqual(viewModel.dailyCrewCost, 1000)
    }

    func testTotalDailyCost() {
        viewModel.addCastMember(CastMember(actorName: "A", dailyRate: 500))
        viewModel.addCrewMember(CrewMember(name: "B", dailyRate: 600))
        viewModel.addEquipment(EquipmentItem(name: "Camera", isRental: true, rentalDailyRate: 200))

        XCTAssertEqual(viewModel.totalDailyCost, 1300)
    }

    // MARK: - Filtering

    func testCastMembersForRole() {
        viewModel.addCastMember(CastMember(actorName: "A", roleType: "Principal"))
        viewModel.addCastMember(CastMember(actorName: "B", roleType: "Extra"))
        viewModel.addCastMember(CastMember(actorName: "C", roleType: "Principal"))

        let principals = viewModel.castMembers(forRole: "Principal")
        XCTAssertEqual(principals.count, 2)
    }

    func testCrewMembersInDepartment() {
        viewModel.addCrewMember(CrewMember(name: "A", department: "Camera"))
        viewModel.addCrewMember(CrewMember(name: "B", department: "Sound"))
        viewModel.addCrewMember(CrewMember(name: "C", department: "Camera"))

        let cameraCrew = viewModel.crewMembers(inDepartment: "Camera")
        XCTAssertEqual(cameraCrew.count, 2)
    }

    // MARK: - Team Member Resolution

    func testCastMembersForTeam() {
        let cast1 = CastMember(actorName: "Alice")
        let cast2 = CastMember(actorName: "Bob")
        viewModel.addCastMember(cast1)
        viewModel.addCastMember(cast2)

        let team = Team(name: "Unit", castMemberIds: [cast1.id])
        viewModel.addTeam(team)

        let teamCast = viewModel.castMembers(forTeam: team)
        XCTAssertEqual(teamCast.count, 1)
        XCTAssertEqual(teamCast.first?.actorName, "Alice")
    }

    func testCrewMembersForTeam() {
        let crew1 = CrewMember(name: "DP")
        let crew2 = CrewMember(name: "Gaffer")
        viewModel.addCrewMember(crew1)
        viewModel.addCrewMember(crew2)

        let team = Team(name: "Camera Unit", crewMemberIds: [crew1.id, crew2.id])
        viewModel.addTeam(team)

        let teamCrew = viewModel.crewMembers(forTeam: team)
        XCTAssertEqual(teamCrew.count, 2)
    }

    func testTeamLead() {
        let crew = CrewMember(name: "Lead DP")
        viewModel.addCrewMember(crew)

        let team = Team(name: "Camera Unit", crewMemberIds: [crew.id], teamLeadId: crew.id)
        viewModel.addTeam(team)

        let lead = viewModel.teamLead(forTeam: team)
        XCTAssertNotNil(lead)
        XCTAssertEqual(lead?.name, "Lead DP")
    }

    func testTeamLeadNilWhenNotSet() {
        let team = Team(name: "No Lead", teamLeadId: nil)
        viewModel.addTeam(team)

        let lead = viewModel.teamLead(forTeam: team)
        XCTAssertNil(lead)
    }

    // MARK: - Lookup By ID

    func testCastMemberWithId() {
        let cast = CastMember(actorName: "FindMe")
        viewModel.addCastMember(cast)

        let found = viewModel.castMember(withId: cast.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.actorName, "FindMe")
    }

    func testCrewMemberWithId() {
        let crew = CrewMember(name: "FindMe")
        viewModel.addCrewMember(crew)

        let found = viewModel.crewMember(withId: crew.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "FindMe")
    }

    func testLookupByIdReturnsNilWhenNotFound() {
        XCTAssertNil(viewModel.castMember(withId: "nonexistent"))
        XCTAssertNil(viewModel.crewMember(withId: "nonexistent"))
        XCTAssertNil(viewModel.team(withId: "nonexistent"))
    }

    // MARK: - Codable Round Trip

    func testCastMemberCodableRoundTrip() throws {
        let cast = CastMember(
            actorName: "John Smith",
            characterName: "Hero",
            roleType: "Principal",
            dailyRate: 500.0,
            contractSigned: true
        )

        let data = try JSONEncoder().encode(cast)
        let decoded = try JSONDecoder().decode(CastMember.self, from: data)

        XCTAssertEqual(decoded.actorName, "John Smith")
        XCTAssertEqual(decoded.characterName, "Hero")
        XCTAssertEqual(decoded.roleType, "Principal")
        XCTAssertEqual(decoded.dailyRate, 500.0)
        XCTAssertTrue(decoded.contractSigned)
    }

    func testCrewMemberCodableRoundTrip() throws {
        let crew = CrewMember(
            name: "Jane Doe",
            role: "DP",
            department: "Camera",
            dailyRate: 800.0,
            kitFee: 150.0,
            skills: ["Steadicam", "Drone"]
        )

        let data = try JSONEncoder().encode(crew)
        let decoded = try JSONDecoder().decode(CrewMember.self, from: data)

        XCTAssertEqual(decoded.name, "Jane Doe")
        XCTAssertEqual(decoded.role, "DP")
        XCTAssertEqual(decoded.department, "Camera")
        XCTAssertEqual(decoded.dailyRate, 800.0)
        XCTAssertEqual(decoded.kitFee, 150.0)
        XCTAssertEqual(decoded.skills.count, 2)
    }

    func testTeamCodableRoundTrip() throws {
        let team = Team(
            name: "A Unit",
            teamType: "Shooting Unit",
            castMemberIds: ["cast_1"],
            crewMemberIds: ["crew_1", "crew_2"],
            teamLeadId: "crew_1"
        )

        let data = try JSONEncoder().encode(team)
        let decoded = try JSONDecoder().decode(Team.self, from: data)

        XCTAssertEqual(decoded.name, "A Unit")
        XCTAssertEqual(decoded.teamType, "Shooting Unit")
        XCTAssertEqual(decoded.castMemberIds.count, 1)
        XCTAssertEqual(decoded.crewMemberIds.count, 2)
        XCTAssertEqual(decoded.teamLeadId, "crew_1")
    }

    // MARK: - Callbacks

    func testOnCastChangedCallback() {
        let expectation = XCTestExpectation(description: "Cast changed callback")

        viewModel.onCastChanged = { members in
            XCTAssertEqual(members.count, 1)
            expectation.fulfill()
        }

        viewModel.addCastMember(CastMember(actorName: "Test"))

        wait(for: [expectation], timeout: 1.0)
    }

    func testOnCrewChangedCallback() {
        let expectation = XCTestExpectation(description: "Crew changed callback")

        viewModel.onCrewChanged = { members in
            XCTAssertEqual(members.count, 1)
            expectation.fulfill()
        }

        viewModel.addCrewMember(CrewMember(name: "Test"))

        wait(for: [expectation], timeout: 1.0)
    }
}
