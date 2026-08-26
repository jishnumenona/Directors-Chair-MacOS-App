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
    /// Like `expectToolResults` but asserted in the .free rerun's gated
    /// branch (DC-0016) — needles must come from FREE calls only; the
    /// studio-authored `expectToolResults` reference gated results there.
    var freeExpectToolResults: [(Int, String)] = []
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
            await runScenario(scenario, tier: .studio)
        }
    }

    /// DC-0016 (the free-launch QA gate): the SAME golden set rerun as a
    /// .free session. Scenarios whose scripted calls are all Free-tier must
    /// behave byte-identically; scenarios that script a Creator-gated call
    /// must REFUSE CLEANLY — the turn finishes, the model is told the tool
    /// is not in this plan, the gated action never starts, and no plan item
    /// proposes it. The studio pass pins behavior; this pass pins refusals.
    ///
    /// The main set deliberately scripts no gated calls (it pins the free
    /// catalog's behavior — verified identical here), so the refusal
    /// contract is pinned by `gatedRefusalScenarios`, which run ONLY in
    /// this pass. If a scripted action is ever demoted to Free, its
    /// scenario flips to the full-assertion path and fails loudly (a real
    /// spending action would propose a plan item where 0 is expected).
    func testGoldenTranscriptsAsFree() async throws {
        XCTAssertGreaterThanOrEqual(Self.gatedRefusalScenarios.count, 4,
                                    "the refusal set must not shrink")
        for scenario in Self.scenarios + Self.gatedRefusalScenarios {
            await runScenario(scenario, tier: .free)
        }
    }

    /// Refusal-contract scenarios (DC-0016): each scripts a Creator-gated
    /// call a .free session must refuse — a spending generation, a
    /// production mutation, a production read, the Storyteller entry, and
    /// one mixed turn where the free half must still work.
    private static let gatedRefusalScenarios: [GoldenScenario] = [
        GoldenScenario(name: "free refuses generate_scene_image",
                       scripts: toolTurn("generate_scene_image",
                                         #"{"scene": "Opening"}"#)),
        GoldenScenario(name: "free refuses add_expense",
                       scripts: toolTurn("add_expense",
                                         #"{"category": "Camera", "amount": 100}"#)),
        GoldenScenario(name: "free refuses get_schedule",
                       scripts: toolTurn("get_schedule", "{}")),
        GoldenScenario(name: "free refuses start_storyteller",
                       scripts: toolTurn("start_storyteller", "{}")),
        GoldenScenario(
            name: "free mixed turn: free read works, gated call refuses",
            scripts: [[call("get_scene", #"{"scene": "Opening"}"#, id: "c1"),
                       call("generate_scene_image", #"{"scene": "Opening"}"#,
                            id: "c2"),
                       .done(finishReason: "tool_calls", model: "m")],
                      [.delta("Partly done."), .done(finishReason: "stop", model: "m")]],
            freeExpectToolResults: [(1, "Old description")]),
    ]

    private static func scriptedCallNames(_ scenario: GoldenScenario) -> [String] {
        scenario.scripts.flatMap { $0 }.compactMap { event in
            if case .toolCall(let call) = event { return call.name }
            return nil
        }
    }

    private func runScenario(_ scenario: GoldenScenario, tier: ProductTier) async {
        let pvm = ProjectViewModel(project: Self.fixture())
        let coordinator = AppCoordinator()
        let registry = AssistantActionFactory.makeRegistry(
            projectViewModel: pvm, coordinator: coordinator)
        // Calls the script issues that sit above the session tier.
        let gated = Set(Self.scriptedCallNames(scenario).filter { name in
            (registry.action(named: name)?.minimumTier ?? .free) > tier
        })
        let transport = EvalTransport(scripts: scenario.scripts)
        let engine = AssistantEngine(
            transport: transport, registry: registry,
            configuration: EngineConfiguration(sessionTier: tier))

        var events: [EngineEvent] = []
        for await event in await engine.runTurn(history: [.system("eval")],
                                                userMessage: .user("golden")) {
            events.append(event)
        }

        guard case .finished = events.last else {
            return XCTFail("\(scenario.name) [\(tier)]: turn did not finish cleanly — \(events)")
        }

        if !gated.isEmpty {
            // Refusal contract (§5.3 UX gating; the server enforces spend):
            // the model saw the refusal for every gated call…
            let toolMessages = transport.requests
                .flatMap { $0.messages.filter { $0.role == .tool } }
                .map(\.textContent).joined(separator: "\n")
            for name in gated.sorted() {
                XCTAssertTrue(
                    toolMessages.contains(
                        "tool '\(name)' is not included in this account's plan"),
                    "\(scenario.name) [\(tier)]: no clean refusal for '\(name)'")
            }
            // …no gated action ever started…
            let started = events.compactMap { event -> String? in
                if case .toolStarted(let name) = event { return name }
                return nil
            }
            XCTAssertTrue(started.allSatisfy { !gated.contains($0) },
                          "\(scenario.name) [\(tier)]: gated action started — \(started)")
            // …and nothing above the session tier was proposed for review.
            let plan = events.compactMap { event -> TurnPlan? in
                if case .turnPlan(let plan) = event { return plan }
                return nil
            }.first
            for item in plan?.items ?? [] {
                let minimum = registry.action(named: item.actionName)?.minimumTier ?? .free
                XCTAssertTrue(minimum <= tier,
                              "\(scenario.name) [\(tier)]: plan proposes gated '\(item.actionName)'")
            }
            // The free half of a mixed turn must still deliver its results.
            for (index, needle) in scenario.freeExpectToolResults {
                guard transport.requests.indices.contains(index) else {
                    return XCTFail("\(scenario.name) [\(tier)]: no request #\(index)")
                }
                let messages = transport.requests[index].messages
                    .filter { $0.role == .tool }
                    .map(\.textContent).joined(separator: "\n")
                XCTAssertTrue(messages.contains(needle),
                    "\(scenario.name) [\(tier)]: result[\(index)] missing '\(needle)'")
            }
            return
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


// MARK: - Local model evals (DC-0060)

/// Owner ask after watching the local model and Gemini answer the same
/// question differently: validate the local model across use cases
/// against an OBJECTIVE rubric — grounded recall, direct facts, counting,
/// honest action refusal, hallucination canary, two-turn continuity,
/// latency and length sanity. Real inference, real weights: app-target
/// tests run inside the app bundle, where MLX's metallib loads (the SPM
/// runner abort does not apply here). Skips cleanly when the model isn't
/// on disk (CI Macs) or DC_SKIP_LOCAL_EVALS=1. The same scenarios can be
/// pointed at the gateway transport with DC_RUN_ONLINE_EVALS=1 — "on
/// par" here means BOTH engines pass the same objective bar; prose style
/// stays a human judgment.
final class LocalModelEvals: XCTestCase {

    struct EvalScenario {
        let name: String
        /// User turns run sequentially with accumulated history.
        let turns: [String]
        /// For the FINAL answer: every inner group must match at least once.
        var mustContainAny: [[String]] = []
        /// Markers that must never appear (pretend-execution, fabrication).
        var mustNotContain: [String] = []
    }

    /// Deterministic project context mirroring the golden fixture — the
    /// evals grade grounding against THIS, not against a live project.
    static let projectContext = """
    You are the project assistant. Ground every answer ONLY in this data.
    PROJECT: Golden Film — genre: Noir. Logline: A detective who cannot sleep.
    CHARACTERS: Mara Voss, Ilya.
    SCENES (2 total): 1. "Opening" — Rain on the precinct steps; Mara Voss speaks the line "First line"; 1 shot. 2. "Finale" — The end.
    """

    static let scenarios: [EvalScenario] = [
        EvalScenario(
            name: "grounded recall — characters",
            turns: ["Who are the characters in this project?"],
            mustContainAny: [["Mara"], ["Ilya"]]),
        EvalScenario(
            name: "direct fact — genre",
            turns: ["What genre is this project? Answer briefly."],
            mustContainAny: [["Noir", "noir"]]),
        EvalScenario(
            name: "counting — scenes",
            turns: ["How many scenes does the project have? Answer briefly."],
            mustContainAny: [["2", "two", "Two"]]),
        EvalScenario(
            name: "honest refusal — cannot run actions",
            turns: ["Please add a new scene called Midnight Chase to the project."],
            mustContainAny: [["can't", "cannot", "can not", "unable",
                             "not able", "in the app", "yourself", "manually"]],
            mustNotContain: ["I've added", "I have added", "has been added",
                            "successfully added", "I've created",
                            "I have created", "was created", "is now added"]),
        EvalScenario(
            name: "hallucination canary — unknown character",
            turns: ["Tell me about the character Zorblax Quinn."],
            mustContainAny: [["no ", "not ", "isn't", "does not", "doesn't",
                             "unknown", "couldn't find", "can't find",
                             "don't see", "only", "aren't"]]),
        EvalScenario(
            name: "continuity — pronoun follow-up",
            turns: ["Who speaks the line \"First line\"? Answer with just the name.",
                    "In which scene does she speak it? Answer briefly."],
            mustContainAny: [["Opening"]]),
    ]

    static let perTurnSecondsCeiling: Double = 90
    static let answerCharacterCeiling = 4_000

    func testLocalModelMeetsTheObjectiveRubric() async throws {
        if ProcessInfo.processInfo.environment["DC_SKIP_LOCAL_EVALS"] == "1" {
            throw XCTSkip("DC_SKIP_LOCAL_EVALS=1")
        }
        let engine = MLXInsightEngine.shared
        guard case .ready = await engine.availability() else {
            throw XCTSkip("local model not on disk — evals need real weights")
        }
        try await runRubric(transport: LocalChatTransport(engine: engine),
                            label: "on-device \(engine.modelId)")
    }

    /// Opt-in: the SAME rubric against the gateway (paid, needs the app's
    /// signed-in session) — DC_RUN_ONLINE_EVALS=1. Scores are logged; a
    /// missing session skips rather than fails.
    func testOnlineComparisonWhenOptedIn() async throws {
        guard ProcessInfo.processInfo.environment["DC_RUN_ONLINE_EVALS"] == "1" else {
            throw XCTSkip("online comparison is opt-in: DC_RUN_ONLINE_EVALS=1 (paid)")
        }
        // The gateway needs the app's signed-in session; AuthManager has
        // no app-wide static seam yet. Wiring one purely for evals isn't
        // worth the surface — run the comparison from the app when a
        // session exists, or wire the seam when this opt-in matters.
        throw XCTSkip("online comparison needs an auth seam (AuthManager is app-instance-scoped) — tracked on DC-0060")
    }

    private func runRubric(transport: any ChatTransporting,
                           label: String) async throws {
        var failures: [String] = []
        var report: [String] = ["=== Local model eval — \(label) ==="]
        for scenario in Self.scenarios {
            var messages: [DirectorsChairServices.ChatMessage] = [.system(Self.projectContext)]
            var answer = ""
            var turnSeconds: [Double] = []
            for turn in scenario.turns {
                messages.append(.user(turn))
                answer = ""
                var streamError: String?
                let started = Date()
                for try await event in transport.stream(ChatRequestBody(
                    messages: messages, maxTokens: 300, temperature: 0.1)) {
                    switch event {
                    case .delta(let delta): answer += delta
                    case .error(let message): streamError = message
                    default: break
                    }
                }
                turnSeconds.append(Date().timeIntervalSince(started))
                if let streamError {
                    failures.append("\(scenario.name): engine error — \(streamError)")
                    report.append("FAIL  \(scenario.name) — engine error: \(streamError)")
                    answer = ""
                    break
                }
                messages.append(.assistant(answer))
            }
            if failures.last?.hasPrefix(scenario.name + ": engine error") == true {
                continue    // rubric checks are meaningless without an answer
            }
            var problems: [String] = []
            for group in scenario.mustContainAny
            where !group.contains(where: { answer.localizedCaseInsensitiveContains($0) }) {
                problems.append("missing any of \(group)")
            }
            for marker in scenario.mustNotContain
            where answer.localizedCaseInsensitiveContains(marker) {
                problems.append("forbidden marker '\(marker)'")
            }
            if answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                problems.append("empty answer")
            }
            if answer.count > Self.answerCharacterCeiling {
                problems.append("runaway answer (\(answer.count) chars)")
            }
            if let worst = turnSeconds.max(), worst > Self.perTurnSecondsCeiling {
                problems.append("slow turn (\(Int(worst))s > \(Int(Self.perTurnSecondsCeiling))s)")
            }
            let timing = turnSeconds.map { String(format: "%.1fs", $0) }.joined(separator: ", ")
            if problems.isEmpty {
                report.append("PASS  \(scenario.name)  [\(timing)]")
            } else {
                report.append("FAIL  \(scenario.name)  [\(timing)] — \(problems.joined(separator: "; "))")
                report.append("      answer: \(answer.prefix(280))")
                failures.append("\(scenario.name): \(problems.joined(separator: "; "))")
            }
        }
        print(report.joined(separator: "\n"))
        XCTAssertTrue(failures.isEmpty,
                      "rubric failures:\n" + failures.joined(separator: "\n"))
    }
}

// MARK: - Storyboard core real-frame evals (DC-0065)

/// REAL diffusion through the native Z-Image core — full MLX inside the
/// app bundle (the metallib rule), gated exactly like the text evals:
/// skips on CI Macs without the 5.5GB weights or with
/// DC_SKIP_LOCAL_EVALS=1. The rubric is objective: the locked ink-sketch
/// style must produce a near-monochrome, non-blank frame of the exact
/// requested size within a sane time; the rendered PNG is left in the
/// temporary directory for eyeball/parity checks against the mflux
/// reference frames (seeds 42/7/101).
final class StoryboardCoreRealEvals: XCTestCase {

    private func requireWeights() throws {
        if ProcessInfo.processInfo.environment["DC_SKIP_LOCAL_EVALS"] == "1" {
            throw XCTSkip("DC_SKIP_LOCAL_EVALS=1")
        }
        guard ZImageStoryboardEngine.shared.isModelDownloaded() else {
            throw XCTSkip("storyboard model not on disk — evals need real weights")
        }
    }

    func testRendersTheReferenceFrameSubjectAsInkSketch() async throws {
        try requireWeights()
        let spec = StoryboardFrameSpec(
            subject: "Maya slams the deed onto the farmhouse kitchen table. Setting: INT. FARMHOUSE KITCHEN, Night, Storm",
            notes: "Close-up, Low angle, 85mm lens",
            width: 768, height: 432, seed: 42)

        let started = Date()
        let png = try await ZImageStoryboardEngine.shared.generateFrame(spec)
        let seconds = Date().timeIntervalSince(started)

        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-storyboard-eval-seed42.png")
        try png.write(to: out)
        print("[StoryboardEval] frame written to \(out.path) in \(String(format: "%.1f", seconds))s")

        XCTAssertLessThan(seconds, 300, "a single 768×432 frame must not take 5 minutes")

        let image = try XCTUnwrap(NSImage(data: png), "output must decode as an image")
        let rep = try XCTUnwrap(NSBitmapImageRep(data: png))
        XCTAssertEqual(rep.pixelsWide, 768)
        XCTAssertEqual(rep.pixelsHigh, 432)
        _ = image

        // Objective look checks on a coarse sample grid.
        var luminance: [Double] = []
        var colorDivergence: [Double] = []
        for y in stride(from: 8, to: 432, by: 24) {
            for x in stride(from: 8, to: 768, by: 24) {
                guard let c = rep.colorAt(x: x, y: y) else { continue }
                let (r, g, b) = (Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
                luminance.append((r + g + b) / 3)
                colorDivergence.append(abs(r - g) + abs(g - b))
            }
        }
        let mean = luminance.reduce(0, +) / Double(luminance.count)
        let variance = luminance.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(luminance.count)
        XCTAssertGreaterThan(variance.squareRoot(), 0.05,
                             "frame must not be blank/flat (σ=\(variance.squareRoot()))")
        let meanDivergence = colorDivergence.reduce(0, +) / Double(colorDivergence.count)
        XCTAssertLessThan(meanDivergence, 0.25,
                          "ink-sketch frames must be near-monochrome (divergence=\(meanDivergence))")
    }

    func testSeedsChangeTheFrameDeterministically() async throws {
        try requireWeights()
        // Small frames keep this pair affordable; determinism and seed
        // sensitivity are resolution-independent properties.
        let a = try await ZImageStoryboardEngine.shared.generateFrame(
            .init(subject: "A lighthouse on a cliff", width: 384, height: 256, seed: 7))
        let b = try await ZImageStoryboardEngine.shared.generateFrame(
            .init(subject: "A lighthouse on a cliff", width: 384, height: 256, seed: 7))
        let c = try await ZImageStoryboardEngine.shared.generateFrame(
            .init(subject: "A lighthouse on a cliff", width: 384, height: 256, seed: 8))
        XCTAssertEqual(a, b, "same seed must reproduce the identical PNG")
        XCTAssertNotEqual(a, c, "a different seed must draw a different frame")
    }
}
