// DirectorsChair-DesktopTests/AssistantGoldenEvals.swift
//
// AI Assistant program, Phase A3.6: the eval harness — golden transcripts
// that drive the REAL AssistantEngine + REAL action registry + a rich
// fixture project with a scripted model (the only fake). Each scenario is
// one turn: the "model" calls tools; the harness asserts the tool results
// fed back, the TurnPlan (items + warnings), and the project state after
// applying proposals. Runs inside verify.sh, so catalog/prompt changes
// cannot silently regress the action surface. (web_search execution is
// excluded — it needs the network; its validation path is covered.)

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

// MARK: - Scripted transport (the only fake in the stack)

private final class EvalTransport: ChatTransporting, @unchecked Sendable {
    private let lock = NSLock()
    private var scripts: [[ChatStreamEvent]]
    private(set) var requests: [ChatRequestBody] = []

    init(scripts: [[ChatStreamEvent]]) { self.scripts = scripts }

    func stream(_ request: ChatRequestBody) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        lock.lock()
        requests.append(request)
        let script = scripts.isEmpty ? [] : scripts.removeFirst()
        lock.unlock()
        return AsyncThrowingStream { continuation in
            for event in script { continuation.yield(event) }
            continuation.finish()
        }
    }
}

// MARK: - Scenario DSL

private func j(_ json: String) -> JSONValue {
    try! JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
}

private func call(_ name: String, _ argsJSON: String,
                  id: String = "c1") -> ChatStreamEvent {
    .toolCall(AssistantToolCall(id: id, name: name, arguments: j(argsJSON)))
}

/// One tool call, then a closing text reply — the standard two-request turn.
private func toolTurn(_ name: String, _ argsJSON: String) -> [[ChatStreamEvent]] {
    [[call(name, argsJSON), .done(finishReason: "tool_calls", model: "m")],
     [.delta("Done."), .done(finishReason: "stop", model: "m")]]
}

private struct GoldenScenario {
    let name: String
    var scripts: [[ChatStreamEvent]]
    /// (request index, substring) — the tool result the model saw.
    var expectToolResults: [(Int, String)] = []
    var expectPlanItems: Int = 0
    var expectWarnings: Bool? = nil
    /// Runs after proposals (if any) are applied.
    var verify: (@MainActor (ProjectViewModel, AppCoordinator) -> Void)? = nil
}

// MARK: - The golden set

@MainActor
final class AssistantGoldenEvals: XCTestCase {

    private static func fixture() -> Project {
        var project = Project(name: "Golden Film")
        project.genre = "Drama"
        let opening = Scene(
            name: "Opening", description: "Old description",
            dialogues: [Dialogue(character: "Mara", text: "First line"),
                        Dialogue(character: "Ilya", text: "Second line")],
            shots: [Shot(shotId: 12, description: "Wide establishing")])
        let finale = Scene(name: "Finale", description: "The end")
        project.sequences = [Sequence(name: "Act 1", scenes: [opening, finale])]
        project.characters = [Character(name: "Mara"), Character(name: "Ilya")]
        project.scheduleItems = [
            ScheduleItem(sceneName: "Finale", shootDate: "2026-08-01",
                         timeSlot: "Morning", status: "Planned",
                         location: "Rooftop", requiredActors: ["Ada Vale"])]
        project.ganttTasks = [
            GanttTask(id: "task_scout", name: "Location scout",
                      category: .locations, startDate: "2026-08-01",
                      endDate: "2026-08-05"),
            GanttTask(id: "task_permits", name: "Permits",
                      category: .preProduction, startDate: "2026-08-06",
                      dependsOn: ["task_scout"])]
        project.projectBudget = ProjectBudget(
            categories: [BudgetCategory(name: "Camera", allocated: 10_000,
                                        spent: 9_500, accountCode: "3300",
                                        categoryGroup: "BTL")],
            totalBudget: 50_000)
        project.castMembers = [CastMember(actorName: "Ada Vale",
                                          characterName: "Mara")]
        project.crewMembers = [CrewMember(name: "Sam Reyes", role: "Gaffer",
                                          department: "Electric")]
        project.equipmentLibrary = [EquipmentItem(name: "Alexa 35",
                                                  category: "Camera")]
        return project
    }

    private static let scenarios: [GoldenScenario] = [
        // ---- Read-tools: the model pulls live data -------------------
        GoldenScenario(
            name: "read.list_scenes",
            scripts: toolTurn("list_scenes", "{}"),
            expectToolResults: [(1, #""name":"Opening""#), (1, #""name":"Finale""#)]),
        GoldenScenario(
            name: "read.get_scene detail with dialogue indices",
            scripts: toolTurn("get_scene", #"{"scene": "Opening"}"#),
            expectToolResults: [(1, "Old description"), (1, #""index":1"#),
                                (1, #""number":12"#)]),
        GoldenScenario(
            name: "read.get_schedule",
            scripts: toolTurn("get_schedule", "{}"),
            expectToolResults: [(1, #""scene":"Finale""#), (1, "Rooftop")]),
        GoldenScenario(
            name: "read.get_schedule_conflicts clean schedule",
            scripts: toolTurn("get_schedule_conflicts", "{}"),
            expectToolResults: [(1, #""conflicts": []"#)]),
        GoldenScenario(
            name: "read.get_gantt tasks + dependencies",
            scripts: toolTurn("get_gantt", "{}"),
            expectToolResults: [(1, "Location scout"), (1, "task_scout")]),
        GoldenScenario(
            name: "read.get_budget_summary exact figures",
            scripts: toolTurn("get_budget_summary", "{}"),
            expectToolResults: [(1, #""totalBudget":50000"#), (1, #""account":"3300""#)]),
        GoldenScenario(
            name: "read.get_people shoot days, no pay data",
            scripts: toolTurn("get_people", "{}"),
            expectToolResults: [(1, #""shootDays":1"#), (1, "Electric")]),
        GoldenScenario(
            name: "read.get_equipment",
            scripts: toolTurn("get_equipment", "{}"),
            expectToolResults: [(1, "Alexa 35"), (1, "unallocated")]),

        // ---- Creative edits: propose → apply -------------------------
        GoldenScenario(
            name: "edit.update_character_trait",
            scripts: toolTurn("update_character_trait",
                #"{"character": "Mara", "trait": "Creativity", "value": 88}"#),
            expectToolResults: [(1, "proposed")], expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.characters[0].traits["Creativity"], 88)
            }),
        GoldenScenario(
            name: "edit.update_character_bio",
            scripts: toolTurn("update_character_bio",
                #"{"character": "Ilya", "field": "occupation", "value": "Pilot"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.characters[1].occupation, "Pilot")
            }),
        GoldenScenario(
            name: "edit.update_scene_description",
            scripts: toolTurn("update_scene_description",
                #"{"scene": "Opening", "text": "Night. Rain."}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences[0].scenes[0].description,
                               "Night. Rain.")
            }),
        GoldenScenario(
            name: "edit.update_dialogue by [n] index",
            scripts: toolTurn("update_dialogue",
                #"{"scene": "Opening", "index": 1, "text": "Rewritten"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences[0].scenes[0].dialogues[1].text,
                               "Rewritten")
                XCTAssertEqual(pvm.project.sequences[0].scenes[0].dialogues[0].text,
                               "First line")
            }),
        GoldenScenario(
            name: "edit.update_project_metadata",
            scripts: toolTurn("update_project_metadata",
                #"{"field": "genre", "value": "Noir"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in XCTAssertEqual(pvm.project.genre, "Noir") }),
        GoldenScenario(
            name: "edit.add_relationship",
            scripts: toolTurn("add_relationship",
                #"{"character": "Mara", "target": "Ilya", "relationship": "Rivals"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.characters[0].relationships?["Ilya"],
                               "Rivals")
            }),

        // ---- Schedule: validator in the loop -------------------------
        GoldenScenario(
            name: "schedule.schedule_scene double-booking warns",
            scripts: toolTurn("schedule_scene", #"""
                {"scene": "Opening", "date": "2026-08-01", "time_slot": "Morning",
                 "cast": ["Ada Vale"]}
                """#),
            expectToolResults: [(1, "warnings")],
            expectPlanItems: 1, expectWarnings: true,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.scheduleItems.count, 2)
            }),
        GoldenScenario(
            name: "schedule.schedule_scene clean day no warnings",
            scripts: toolTurn("schedule_scene",
                #"{"scene": "Opening", "date": "2026-08-02", "time_slot": "Night"}"#),
            expectPlanItems: 1, expectWarnings: false),
        GoldenScenario(
            name: "schedule.update moves the shoot",
            scripts: toolTurn("update_schedule_item",
                #"{"scene": "Finale", "new_date": "2026-08-03"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.scheduleItems[0].shootDate, "2026-08-03")
            }),
        GoldenScenario(
            name: "schedule.remove unschedules",
            scripts: toolTurn("remove_schedule_item", #"{"scene": "Finale"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertTrue(pvm.project.scheduleItems.isEmpty)
            }),

        // ---- Gantt: cycles are hard errors ---------------------------
        GoldenScenario(
            name: "gantt.add task resolves dependency names",
            scripts: toolTurn("add_gantt_task", #"""
                {"name": "Casting", "category": "Cast/Talent",
                 "start_date": "2026-08-02", "depends_on": ["Location scout"]}
                """#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.ganttTasks.last?.dependsOn, ["task_scout"])
            }),
        GoldenScenario(
            name: "gantt.cycle rejected, model told why",
            scripts: toolTurn("update_gantt_task",
                #"{"task": "Location scout", "new_depends_on": ["Permits"]}"#),
            expectToolResults: [(1, "cycle")], expectPlanItems: 0),
        GoldenScenario(
            name: "gantt.update completion",
            scripts: toolTurn("update_gantt_task",
                #"{"task": "Location scout", "new_completion": 60}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.ganttTasks[0].completionPercentage, 60)
            }),
        GoldenScenario(
            name: "gantt.remove warns about dependents and strips refs",
            scripts: toolTurn("remove_gantt_task", #"{"task": "Location scout"}"#),
            expectToolResults: [(1, "Permits")],
            expectPlanItems: 1, expectWarnings: true,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.ganttTasks.count, 1)
                XCTAssertTrue(pvm.project.ganttTasks[0].dependsOn.isEmpty)
            }),

        // ---- Budget: exact figures, overruns surfaced ----------------
        GoldenScenario(
            name: "budget.add_expense overrun warning + spent maintained",
            scripts: toolTurn("add_expense", #"""
                {"description": "Lens rental", "amount": 900, "category": "3300"}
                """#),
            expectToolResults: [(1, "overruns")],
            expectPlanItems: 1, expectWarnings: true,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.projectBudget?.categories[0].spent, 10_400)
                XCTAssertEqual(pvm.project.projectBudget?.expenses.count, 1)
            }),
        GoldenScenario(
            name: "budget.add_category over-allocation warning",
            scripts: toolTurn("add_budget_category",
                #"{"name": "Stunts", "allocated": 45000, "group": "BTL"}"#),
            expectPlanItems: 1, expectWarnings: true,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.projectBudget?.categories.count, 2)
            }),
        GoldenScenario(
            name: "budget.update_category below spent warns",
            scripts: toolTurn("update_budget_category",
                #"{"category": "Camera", "new_allocated": 9000}"#),
            expectPlanItems: 1, expectWarnings: true,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.projectBudget?.categories[0].allocated, 9_000)
            }),

        // ---- People & equipment --------------------------------------
        GoldenScenario(
            name: "people.add_cast_member uncast character warns",
            scripts: toolTurn("add_cast_member",
                #"{"actor": "Sam Ito", "character": "Bartender"}"#),
            expectPlanItems: 1, expectWarnings: true,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.castMembers.count, 2)
                XCTAssertEqual(pvm.project.castMembers.last?.dailyRate, 0)
            }),
        GoldenScenario(
            name: "people.add_crew_member",
            scripts: toolTurn("add_crew_member",
                #"{"name": "Lee Park", "role": "1st AC", "department": "Camera"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.crewMembers.last?.role, "1st AC")
            }),
        GoldenScenario(
            name: "people.add_equipment_item",
            scripts: toolTurn("add_equipment_item",
                #"{"name": "Tripod", "category": "Grip", "quantity": 3}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.equipmentLibrary.last?.quantityOwned, 3)
            }),

        // ---- Creative structure (A4) ---------------------------------
        GoldenScenario(
            name: "create.add_scene after an existing one",
            scripts: toolTurn("add_scene", #"""
                {"name": "Chase", "sequence": "Act 1", "after": "Opening",
                 "time_of_day": "Night"}
                """#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences[0].scenes.map(\.name),
                               ["Opening", "Chase", "Finale"])
            }),
        GoldenScenario(
            name: "create.add_sequence",
            scripts: toolTurn("add_sequence", #"{"name": "Act 2"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences.count, 2)
            }),
        GoldenScenario(
            name: "create.update_scene_fields canonical status",
            scripts: toolTurn("update_scene_fields",
                #"{"scene": "Opening", "status": "ready"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences[0].scenes[0].productionStatus,
                               "Ready")
            }),
        GoldenScenario(
            name: "create.add_dialogue unknown character warns",
            scripts: toolTurn("add_dialogue",
                #"{"scene": "Opening", "character": "Stranger", "text": "Hello."}"#),
            expectPlanItems: 1, expectWarnings: true,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences[0].scenes[0].dialogues.last?.character,
                               "Stranger")
            }),
        GoldenScenario(
            name: "create.add_shot auto-numbers",
            scripts: toolTurn("add_shot",
                #"{"scene": "Finale", "description": "Crane down"}"#),
            expectToolResults: [(1, "proposed")],
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences[0].scenes[1].shots.first?.shotId, 13)
            }),
        GoldenScenario(
            name: "create.add_character duplicate rejected",
            scripts: toolTurn("add_character", #"{"name": "Mara"}"#),
            expectToolResults: [(1, "already exists")], expectPlanItems: 0),

        // ---- World-building (A4 slice 2) -----------------------------
        GoldenScenario(
            name: "world.add_location",
            scripts: toolTurn("add_location", #"{"name": "Metro Station"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.locations.last?.name, "Metro Station")
            }),
        GoldenScenario(
            name: "world.add_prop",
            scripts: toolTurn("add_prop",
                #"{"name": "Brass key", "category": "Document"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.props.last?.category, "Document")
            }),
        GoldenScenario(
            name: "world.add_costume wardrobe warning",
            scripts: toolTurn("add_costume",
                #"{"name": "Disguise", "character": "Stranger"}"#),
            expectPlanItems: 1, expectWarnings: true,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.costumes.last?.character, "Stranger")
            }),
        GoldenScenario(
            name: "world.update_shot canonical status by number",
            scripts: toolTurn("update_shot",
                #"{"shot": 12, "new_status": "approved"}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences[0].scenes[0].shots[0].status,
                               "Approved")
            }),

        // ---- Script items + whole-scene drafting (A4.2) --------------
        GoldenScenario(
            name: "script.move_dialogue reorders by [n]",
            scripts: toolTurn("move_dialogue",
                #"{"scene": "Opening", "from_index": 1, "to_index": 0}"#),
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences[0].scenes[0].dialogues.map(\.text),
                               ["Second line", "First line"])
            }),
        GoldenScenario(
            name: "script.whole-scene draft is one composed TurnPlan",
            scripts: [[call("add_scene",
                            #"{"name": "Chase", "sequence": "Act 1", "time_of_day": "Night"}"#,
                            id: "c1"),
                       call("add_scene_action",
                            #"{"scene": "Opening", "text": "Rain hammers the skylight."}"#,
                            id: "c2"),
                       call("add_narration",
                            #"{"scene": "Opening", "text": "It began with rain."}"#,
                            id: "c3"),
                       call("add_dialogue",
                            #"{"scene": "Opening", "character": "Mara", "text": "Run."}"#,
                            id: "c4"),
                       .done(finishReason: "tool_calls", model: "m")],
                      [.delta("Drafted the scene."),
                       .done(finishReason: "stop", model: "m")]],
            expectPlanItems: 4,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences[0].scenes.count, 3)
                let opening = pvm.project.sequences[0].scenes[0]
                XCTAssertEqual(opening.actions.last?.description,
                               "Rain hammers the skylight.")
                XCTAssertEqual(opening.narrations.last?.text, "It began with rain.")
                XCTAssertEqual(opening.dialogues.last?.text, "Run.")
            }),

        // ---- Navigation, recovery, and composition -------------------
        GoldenScenario(
            name: "navigate.executes immediately (read-only)",
            scripts: toolTurn("navigate",
                #"{"view": "shotList", "shot": 12}"#),
            expectToolResults: [(1, "navigated")],
            verify: { _, coordinator in
                XCTAssertEqual(coordinator.selectedView, .shotList)
                XCTAssertEqual(coordinator.selectedShot?.shotId, 12)
            }),
        GoldenScenario(
            name: "navigate.start_storyteller opens playback + flags the mode",
            scripts: toolTurn("start_storyteller", "{}"),
            expectToolResults: [(1, "storyteller opened")],
            verify: { _, coordinator in
                XCTAssertEqual(coordinator.selectedView, .playback)
                XCTAssertTrue(coordinator.shouldOpenStoryteller)
            }),
        GoldenScenario(
            name: "recovery.unknown tool → engine tells the model",
            scripts: toolTurn("not_a_tool", "{}"),
            expectToolResults: [(1, "unknown tool")]),
        GoldenScenario(
            name: "recovery.unknown character → known names listed",
            scripts: toolTurn("update_character_trait",
                #"{"character": "Nobody", "trait": "Wit", "value": 5}"#),
            expectToolResults: [(1, "not found"), (1, "Mara")], expectPlanItems: 0),
        GoldenScenario(
            name: "recovery.web_search empty query rejected",
            scripts: toolTurn("web_search", #"{"query": "  "}"#),
            expectToolResults: [(1, "empty")]),
        GoldenScenario(
            name: "compose.two proposals in one reply = one TurnPlan",
            scripts: [[call("update_project_metadata",
                            #"{"field": "genre", "value": "Noir"}"#, id: "c1"),
                       call("update_scene_description",
                            #"{"scene": "Finale", "text": "Dawn."}"#, id: "c2"),
                       .done(finishReason: "tool_calls", model: "m")],
                      [.delta("Proposed both."), .done(finishReason: "stop", model: "m")]],
            expectPlanItems: 2,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.genre, "Noir")
                XCTAssertEqual(pvm.project.sequences[0].scenes[1].description, "Dawn.")
            }),
        GoldenScenario(
            name: "compose.read then propose in the same turn",
            scripts: [[call("get_scene", #"{"scene": "Opening"}"#, id: "c1"),
                       .done(finishReason: "tool_calls", model: "m")],
                      [call("update_scene_description",
                            #"{"scene": "Opening", "text": "Refined."}"#, id: "c2"),
                       .done(finishReason: "tool_calls", model: "m")],
                      [.delta("Refined it."), .done(finishReason: "stop", model: "m")]],
            expectToolResults: [(1, "Old description"), (2, "proposed")],
            expectPlanItems: 1,
            verify: { pvm, _ in
                XCTAssertEqual(pvm.project.sequences[0].scenes[0].description,
                               "Refined.")
            }),
    ]

    // MARK: - Runner

    func testGoldenTranscripts() async throws {
        XCTAssertGreaterThanOrEqual(Self.scenarios.count, 30,
                                    "the golden set must not shrink")
        for scenario in Self.scenarios {
            await runScenario(scenario)
        }
    }

    private func runScenario(_ scenario: GoldenScenario) async {
        let pvm = ProjectViewModel(project: Self.fixture())
        let coordinator = AppCoordinator()
        let registry = AssistantActionFactory.makeRegistry(
            projectViewModel: pvm, coordinator: coordinator)
        let transport = EvalTransport(scripts: scenario.scripts)
        // The golden set pins ACTION behavior, not gating, so it runs as
        // .studio (full catalog); the free-session QA pass (DC-0016)
        // reruns it under .free to pin the refusals instead.
        let engine = AssistantEngine(
            transport: transport, registry: registry,
            configuration: EngineConfiguration(sessionTier: .studio))

        var events: [EngineEvent] = []
        for await event in await engine.runTurn(history: [.system("eval")],
                                                userMessage: .user("golden")) {
            events.append(event)
        }

        guard case .finished = events.last else {
            return XCTFail("\(scenario.name): turn did not finish cleanly — \(events)")
        }

        let plan = events.compactMap { event -> TurnPlan? in
            if case .turnPlan(let plan) = event { return plan } else { return nil }
        }.first
        XCTAssertEqual(plan?.items.count ?? 0, scenario.expectPlanItems,
                       "\(scenario.name): plan items")
        if let expectWarnings = scenario.expectWarnings {
            let warnings = plan?.items.flatMap(\.plan.warnings) ?? []
            XCTAssertEqual(!warnings.isEmpty, expectWarnings,
                           "\(scenario.name): warnings — got \(warnings)")
        }

        // Apply the proposals the way the review card does.
        if let plan {
            for item in plan.items {
                do {
                    _ = try await registry.action(named: item.actionName)!
                        .execute(argumentsData: item.argumentsData)
                } catch {
                    XCTFail("\(scenario.name): applying \(item.actionName) failed — \(error)")
                }
            }
        }

        for (index, needle) in scenario.expectToolResults {
            guard transport.requests.indices.contains(index) else {
                return XCTFail("\(scenario.name): no request #\(index)")
            }
            let toolMessages = transport.requests[index].messages
                .filter { $0.role == .tool }
                .map(\.textContent).joined(separator: "\n")
            XCTAssertTrue(toolMessages.contains(needle),
                "\(scenario.name): result[\(index)] missing '\(needle)' — got: \(toolMessages.prefix(200))")
        }

        scenario.verify?(pvm, coordinator)
    }
}
