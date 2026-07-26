// DirectorsChair-DesktopTests/AssistantReadToolsTests.swift
//
// AI Assistant program, Phase A3.1: the read-only production tools — each
// pulls live project data (or runs the app's own deterministic validators)
// and returns compact JSON. Payloads are asserted by decoding them back.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantReadToolsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var registry: ActionRegistry!

    override func setUp() {
        super.setUp()
        projectVM = ProjectViewModel(project: Self.makeProductionFixture())
        registry = AssistantActionFactory.makeRegistry(
            projectViewModel: projectVM, coordinator: nil)
    }

    override func tearDown() {
        projectVM = nil
        registry = nil
        super.tearDown()
    }

    private static func makeProductionFixture() -> Project {
        var project = Project(name: "Fixture Film")
        let scene = Scene(
            name: "Opening",
            description: "Night. Rain.",
            dialogues: [Dialogue(character: "Mara", text: "First line")],
            shots: [Shot(shotId: 12, description: "Wide establishing")]
        )
        project.sequences = [Sequence(name: "Act 1", scenes: [scene])]

        // Two items, same day + slot + actor → a guaranteed cast conflict.
        project.scheduleItems = [
            ScheduleItem(sceneName: "Opening", shootDate: "2026-08-01",
                         timeSlot: "Morning", status: "Planned",
                         location: "Stage 4", requiredActors: ["Ada Vale"]),
            ScheduleItem(sceneName: "Finale", shootDate: "2026-08-01",
                         timeSlot: "Morning", status: "Planned",
                         location: "Rooftop", requiredActors: ["Ada Vale"]),
        ]
        project.ganttTasks = [
            GanttTask(id: "task_a", name: "Location scout",
                      startDate: "2026-08-01", endDate: "2026-08-05",
                      dependsOn: ["task_missing"], status: "In Progress",
                      completionPercentage: 40),
        ]
        project.projectBudget = ProjectBudget(
            categories: [BudgetCategory(name: "Camera", allocated: 20_000,
                                        spent: 5_000, accountCode: "3300",
                                        categoryGroup: "BTL")],
            totalBudget: 100_000)
        project.castMembers = [CastMember(actorName: "Ada Vale",
                                          characterName: "Mara")]
        project.crewMembers = [CrewMember(name: "Sam Reyes", role: "Gaffer",
                                          department: "Electric")]
        project.equipmentLibrary = [EquipmentItem(name: "Alexa 35",
                                                  category: "Camera")]
        return project
    }

    private func run(_ name: String, _ json: String = "{}") async throws -> String {
        guard let action = registry.action(named: name) else {
            XCTFail("\(name) not registered"); return ""
        }
        return try await action.execute(argumentsData: Data(json.utf8)).resultForModel
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - Catalog

    func testReadToolsAreRegisteredAndReadOnly() {
        for name in ["list_scenes", "get_scene", "get_schedule",
                     "get_schedule_conflicts", "get_gantt",
                     "get_budget_summary", "get_people", "get_equipment"] {
            let action = registry.action(named: name)
            XCTAssertNotNil(action, name)
            XCTAssertEqual(action?.risk, .readOnly, name)
        }
        XCTAssertEqual(registry.count, 38)   // + creative 6 + world 4 (A4)
    }

    // MARK: - Scenes

    func testListScenesAndGetScene() async throws {
        struct Row: Decodable { let name: String, sequence: String, dialogues: Int }
        let rows = try decode([Row].self, try await run("list_scenes"))
        XCTAssertEqual(rows.first?.name, "Opening")
        XCTAssertEqual(rows.first?.dialogues, 1)

        struct Detail: Decodable {
            struct Line: Decodable { let index: Int, character: String, text: String }
            struct ShotRow: Decodable { let number: Int }
            let description: String, dialogues: [Line], shots: [ShotRow]
        }
        let detail = try decode(Detail.self, try await run(
            "get_scene", #"{"scene": "Opening"}"#))
        XCTAssertEqual(detail.description, "Night. Rain.")
        XCTAssertEqual(detail.dialogues.first?.index, 0)
        XCTAssertEqual(detail.shots.first?.number, 12)
    }

    func testGetSceneUnknownThrows() {
        let action = registry.action(named: "get_scene")!
        XCTAssertThrowsError(try action.validate(
            argumentsData: Data(#"{"scene": "Nowhere"}"#.utf8)))
    }

    // MARK: - Schedule

    func testGetScheduleFiltersByDateAndStatus() async throws {
        struct Row: Decodable { let scene: String, date: String, cast: [String] }
        let all = try decode([Row].self, try await run("get_schedule"))
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.first?.cast, ["Ada Vale"])

        let none = try decode([Row].self, try await run(
            "get_schedule", #"{"status": "Shot"}"#))
        XCTAssertTrue(none.isEmpty)
    }

    func testScheduleConflictsRunTheRealChecker() async throws {
        struct Row: Decodable { let description: String, scenes: [String] }
        let rows = try decode([Row].self, try await run("get_schedule_conflicts"))
        XCTAssertFalse(rows.isEmpty, "double-booked actor must be detected")
        XCTAssertTrue(rows.contains { Set($0.scenes) == ["Opening", "Finale"] })
    }

    // MARK: - Gantt

    func testGetGanttIncludesTasksAndDependencyProblems() async throws {
        struct Result: Decodable {
            struct Task: Decodable { let name: String, completion: Int }
            struct Problem: Decodable { let description: String }
            let tasks: [Task], problems: [Problem]
        }
        let result = try decode(Result.self, try await run("get_gantt"))
        XCTAssertEqual(result.tasks.first?.name, "Location scout")
        XCTAssertEqual(result.tasks.first?.completion, 40)
        XCTAssertFalse(result.problems.isEmpty,
                       "dangling dependency must be reported")
    }

    // MARK: - Budget

    func testGetBudgetSummary() async throws {
        struct Result: Decodable {
            struct Category: Decodable { let account: String, spent: Double }
            let totalBudget: Double, categories: [Category]
        }
        let result = try decode(Result.self, try await run("get_budget_summary"))
        XCTAssertEqual(result.totalBudget, 100_000)
        XCTAssertEqual(result.categories.first?.account, "3300")
        XCTAssertEqual(result.categories.first?.spent, 5_000)
    }

    // MARK: - People & equipment

    func testGetPeopleComputesShootDaysAndOmitsSensitiveData() async throws {
        let json = try await run("get_people")
        struct Result: Decodable {
            struct Cast: Decodable { let actor: String, shootDays: Int }
            struct Crew: Decodable { let department: String }
            let cast: [Cast], crew: [Crew]
        }
        let result = try decode(Result.self, json)
        XCTAssertEqual(result.cast.first?.actor, "Ada Vale")
        XCTAssertEqual(result.cast.first?.shootDays, 1,
                       "two bookings on one date = one shoot day")
        XCTAssertEqual(result.crew.first?.department, "Electric")
        XCTAssertFalse(json.lowercased().contains("rate"),
                       "pay data must never reach the model")
    }

    func testGetEquipment() async throws {
        struct Row: Decodable { let name: String, allocation: String }
        let rows = try decode([Row].self, try await run("get_equipment"))
        XCTAssertEqual(rows.first?.name, "Alexa 35")
        XCTAssertEqual(rows.first?.allocation, "unallocated")
    }
}
