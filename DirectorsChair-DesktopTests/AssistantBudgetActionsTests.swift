// DirectorsChair-DesktopTests/AssistantBudgetActionsTests.swift
//
// AI Assistant program, Phase A3.4: budget actions — exact before→after
// money previews, category resolution by name or account code, overrun
// warnings, and stored category.spent kept consistent on apply.

import XCTest
@testable import DirectorsChair_Desktop
@testable import DirectorsChairCore
@testable import DirectorsChairServices

@MainActor
final class AssistantBudgetActionsTests: XCTestCase {

    private var projectVM: ProjectViewModel!
    private var registry: ActionRegistry!

    override func setUp() {
        super.setUp()
        var project = Project(name: "Fixture Film")
        project.projectBudget = ProjectBudget(
            categories: [BudgetCategory(name: "Camera", allocated: 10_000,
                                        spent: 9_500, accountCode: "3300",
                                        categoryGroup: "BTL")],
            totalBudget: 50_000)
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

    // MARK: - add_expense

    func testAddExpenseWarnsOnOverrunAndMaintainsSpent() async throws {
        let expense = action("add_expense")
        XCTAssertEqual(expense.risk, .spending)
        // resolves by account code; 900 pushes Camera past its 10k allocation
        let payload = args(#"""
        {"description": "Lens rental", "amount": 900, "category": "3300",
         "vendor": "LensCo", "date": "2026-08-01"}
        """#)

        let plan = try expense.validate(argumentsData: payload)
        XCTAssertEqual(plan.previews.first?.oldValue, "USD 9500.00")
        XCTAssertEqual(plan.previews.first?.newValue, "USD 10400.00")
        XCTAssertEqual(plan.warnings.count, 1)
        XCTAssertTrue(plan.warnings[0].contains("400.00"))

        _ = try await expense.execute(argumentsData: payload)
        let budget = projectVM.project.projectBudget!
        XCTAssertEqual(budget.expenses.count, 1)
        XCTAssertEqual(budget.expenses[0].vendor, "LensCo")
        XCTAssertEqual(budget.expenses[0].accountCode, "3300")
        XCTAssertEqual(budget.categories[0].spent, 10_400)
        XCTAssertTrue(projectVM.isDirty)
    }

    func testAddExpenseRejectsBadInputs() {
        let expense = action("add_expense")
        XCTAssertThrowsError(try expense.validate(argumentsData: args(
            #"{"description": "x", "amount": -5, "category": "Camera"}"#)))
        XCTAssertThrowsError(try expense.validate(argumentsData: args(
            #"{"description": "x", "amount": 5, "category": "Catering"}"#))) { error in
            XCTAssertTrue("\(error)".contains("Camera"), "error lists known categories")
        }
        XCTAssertThrowsError(try expense.validate(argumentsData: args(
            #"{"description": "x", "amount": 5, "category": "Camera", "date": "yesterday"}"#)))
    }

    // MARK: - categories

    func testAddBudgetCategoryWarnsWhenAllocationsExceedTotal() async throws {
        let add = action("add_budget_category")
        let payload = args(#"{"name": "Stunts", "allocated": 45000, "group": "BTL"}"#)
        let plan = try add.validate(argumentsData: payload)
        XCTAssertEqual(plan.warnings.count, 1, "10k + 45k > 50k total")

        _ = try await add.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.projectBudget?.categories.count, 2)
        XCTAssertEqual(projectVM.project.projectBudget?.categories.last?.categoryGroup, "BTL")

        XCTAssertThrowsError(try add.validate(argumentsData: args(
            #"{"name": "Camera", "allocated": 1}"#)), "duplicate name rejected")
        XCTAssertThrowsError(try add.validate(argumentsData: args(
            #"{"name": "X", "allocated": 1, "group": "Middle"}"#)), "bad group rejected")
    }

    func testUpdateBudgetCategoryReallocatesAndWarnsBelowSpent() async throws {
        let update = action("update_budget_category")
        let payload = args(#"{"category": "Camera", "new_allocated": 9000}"#)
        let plan = try update.validate(argumentsData: payload)
        XCTAssertEqual(plan.previews.first?.oldValue, "USD 10000.00")
        XCTAssertEqual(plan.warnings.count, 1, "9k below the 9.5k already spent")

        _ = try await update.execute(argumentsData: payload)
        XCTAssertEqual(projectVM.project.projectBudget?.categories[0].allocated, 9_000)
    }

    func testBudgetActionsRequireABudget() {
        projectVM.project.projectBudget = nil
        XCTAssertThrowsError(try action("add_expense").validate(argumentsData: args(
            #"{"description": "x", "amount": 5, "category": "Camera"}"#))) { error in
            XCTAssertTrue("\(error)".contains("no budget"))
        }
    }
}
