// DirectorsChair-DesktopTests/AssistantGanttActionsTests.swift
//
// AI Assistant program, Phase A3.3: Gantt CRUD with the validator in the
// loop — cycles are hard errors from the app's real detector, dependency
// references resolve by name or id, and removals strip dangling deps.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantGanttActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var registry: ActionRegistry!

    override func setUp() {
        super.setUp()
        var project = Project(name: "Fixture Film")
        // scout ← permits (permits depends on scout)
        project.ganttTasks = [
            GanttTask(id: "task_scout", name: "Location scout",
                      category: .locations, startDate: "2026-08-01",
                      endDate: "2026-08-05"),
            GanttTask(id: "task_permits", name: "Permits",
                      category: .preProduction, startDate: "2026-08-06",
                      dependsOn: ["task_scout"]),
        ]
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

    // MARK: - add_gantt_task

    func testAddTaskResolvesDependencyNamesAndExecutes() async throws {
        let add = action("add_gantt_task")
        let payload = args(#"""
        {"name": "Casting", "category": "cast/talent",
         "start_date": "2026-08-02", "end_date": "2026-08-10",
         "depends_on": ["Location scout"]}
        """#)
        let plan = try add.validate(argumentsData: payload)
        XCTAssertTrue(plan.summary.contains("Cast/Talent"), "category canonicalized")

        _ = try await add.execute(argumentsData: payload)
        let added = projectVM.project.ganttTasks.last
        XCTAssertEqual(added?.name, "Casting")
        XCTAssertEqual(added?.dependsOn, ["task_scout"], "name resolved to id")
        XCTAssertTrue(projectVM.isDirty)
    }

    func testAddTaskRejectsBadInputs() {
        let add = action("add_gantt_task")
        XCTAssertThrowsError(try add.validate(argumentsData: args(
            #"{"name": "X", "category": "Snacks", "start_date": "2026-08-02"}"#)))
        XCTAssertThrowsError(try add.validate(argumentsData: args(
            #"{"name": "X", "category": "Props", "start_date": "next week"}"#)))
        XCTAssertThrowsError(try add.validate(argumentsData: args(
            #"{"name": "X", "category": "Props", "start_date": "2026-08-09", "end_date": "2026-08-02"}"#)))
        XCTAssertThrowsError(try add.validate(argumentsData: args(
            #"{"name": "Permits", "category": "Props", "start_date": "2026-08-02"}"#)),
            "duplicate name must be rejected")
    }

    // MARK: - update_gantt_task

    func testUpdateTaskEditsFieldsWithPreviews() async throws {
        let update = action("update_gantt_task")
        let payload = args(#"{"task": "Location scout", "new_completion": 80, "new_status": "In Progress"}"#)
        let plan = try update.validate(argumentsData: payload)
        XCTAssertEqual(plan.previews.count, 2)
        XCTAssertTrue(plan.previews.contains {
            $0.oldValue == "0%" && $0.newValue == "80%"
        })

        _ = try await update.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.ganttTasks[0].completionPercentage, 80)
        XCTAssertEqual(projectVM.project.ganttTasks[0].status, "In Progress")
    }

    func testUpdateTaskRejectsCycleAndBadCompletion() {
        let update = action("update_gantt_task")
        // scout depending on permits closes the loop (permits → scout)
        XCTAssertThrowsError(try update.validate(argumentsData: args(
            #"{"task": "Location scout", "new_depends_on": ["Permits"]}"#))) { error in
            XCTAssertTrue("\(error)".contains("cycle"))
        }
        XCTAssertThrowsError(try update.validate(argumentsData: args(
            #"{"task": "Location scout", "new_depends_on": ["Location scout"]}"#))) { error in
            XCTAssertTrue("\(error)".contains("itself"))
        }
        XCTAssertThrowsError(try update.validate(argumentsData: args(
            #"{"task": "Location scout", "new_completion": 150}"#)))
        XCTAssertThrowsError(try update.validate(argumentsData: args(
            #"{"task": "Ghost", "new_completion": 10}"#))) { error in
            XCTAssertTrue("\(error)".contains("no plan task"))
        }
    }

    // MARK: - remove_gantt_task

    func testRemoveTaskWarnsAboutDependentsAndStripsTheirDependency() async throws {
        let remove = action("remove_gantt_task")
        let plan = try remove.validate(argumentsData: args(#"{"task": "Location scout"}"#))
        XCTAssertEqual(plan.warnings.count, 1)
        XCTAssertTrue(plan.warnings[0].contains("Permits"))

        _ = try await remove.execute(argumentsData: args(#"{"task": "Location scout"}"#))
        XCTAssertEqual(projectVM.project.ganttTasks.count, 1)
        XCTAssertEqual(projectVM.project.ganttTasks[0].name, "Permits")
        XCTAssertTrue(projectVM.project.ganttTasks[0].dependsOn.isEmpty,
                      "dangling dependency must be stripped")
    }
}
