// DirectorsChairProduction/Tests/DirectorsChairProductionTests/BudgetModelTests.swift
//
// Tests for budget models and BudgetViewModel logic:
// budget item creation, expense management, category calculations, and totals.

import XCTest
@testable import DirectorsChairProduction
@testable import DirectorsChairCore

@MainActor
final class BudgetModelTests: XCTestCase {

    var viewModel: BudgetViewModel!

    override func setUp() {
        super.setUp()
        viewModel = BudgetViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - ProjectBudget Model

    func testProjectBudgetDefaults() {
        let budget = ProjectBudget()

        XCTAssertTrue(budget.categories.isEmpty)
        XCTAssertTrue(budget.expenses.isEmpty)
        XCTAssertEqual(budget.totalBudget, 0.0)
        XCTAssertEqual(budget.currency, "USD")
        XCTAssertEqual(budget.aiBudgetLimit, 0.0)
        XCTAssertNil(budget.aiProductionEstimates)
        XCTAssertTrue(budget.purchaseOrders.isEmpty)
        XCTAssertEqual(budget.contingencyPercentage, 0.10)
        XCTAssertEqual(budget.fringeRate, 0.30)
    }

    func testProjectBudgetTotalSpent() {
        var budget = ProjectBudget()
        budget.categories = [
            BudgetCategory(name: "Camera", allocated: 5000, spent: 2000),
            BudgetCategory(name: "Lighting", allocated: 3000, spent: 1500),
        ]

        XCTAssertEqual(budget.totalSpent, 3500)
    }

    func testProjectBudgetTotalRemaining() {
        var budget = ProjectBudget()
        budget.totalBudget = 10000
        budget.categories = [
            BudgetCategory(name: "Camera", allocated: 5000, spent: 2000),
            BudgetCategory(name: "Lighting", allocated: 3000, spent: 1500),
        ]

        XCTAssertEqual(budget.totalRemaining, 6500) // 10000 - 3500
    }

    // MARK: - BudgetCategory Model

    func testBudgetCategoryCreation() {
        let category = BudgetCategory(
            name: "Camera",
            allocated: 5000,
            spent: 2000,
            description: "Camera equipment rental",
            isCustom: false,
            accountCode: "3300",
            categoryGroup: "BTL"
        )

        XCTAssertEqual(category.name, "Camera")
        XCTAssertEqual(category.allocated, 5000)
        XCTAssertEqual(category.spent, 2000)
        XCTAssertEqual(category.description, "Camera equipment rental")
        XCTAssertFalse(category.isCustom)
        XCTAssertEqual(category.accountCode, "3300")
        XCTAssertEqual(category.categoryGroup, "BTL")
    }

    func testBudgetCategoryRemaining() {
        let category = BudgetCategory(name: "Sound", allocated: 3000, spent: 1200)
        XCTAssertEqual(category.remaining, 1800)
    }

    func testBudgetCategoryVariancePercentage() {
        let overBudget = BudgetCategory(name: "Props", allocated: 1000, spent: 1200)
        XCTAssertEqual(overBudget.variancePercentage, 20.0, accuracy: 0.01)

        let underBudget = BudgetCategory(name: "Sound", allocated: 1000, spent: 800)
        XCTAssertEqual(underBudget.variancePercentage, -20.0, accuracy: 0.01)
    }

    func testBudgetCategoryVariancePercentageZeroAllocated() {
        let zeroBudget = BudgetCategory(name: "None", allocated: 0, spent: 100)
        XCTAssertEqual(zeroBudget.variancePercentage, 0.0)
    }

    // MARK: - Expense Model

    func testExpenseCreation() {
        let expense = Expense(
            date: "2026-03-28",
            category: "Camera",
            amount: 500.0,
            description: "Lens rental",
            vendor: "Camera House",
            department: "Camera Dept",
            accountCode: "3300"
        )

        XCTAssertEqual(expense.date, "2026-03-28")
        XCTAssertEqual(expense.category, "Camera")
        XCTAssertEqual(expense.amount, 500.0)
        XCTAssertEqual(expense.description, "Lens rental")
        XCTAssertEqual(expense.vendor, "Camera House")
        XCTAssertFalse(expense.id.isEmpty)
        XCTAssertEqual(expense.status, "Pending")
        XCTAssertEqual(expense.paymentMethod, "Card")
        XCTAssertFalse(expense.isQualifyingExpense)
    }

    // MARK: - PurchaseOrder Model

    func testPurchaseOrderCreation() {
        let po = PurchaseOrder(
            poNumber: "PO-001",
            vendor: "Equipment Co",
            department: "Camera",
            accountCode: "3300",
            description: "Camera package rental",
            amount: 2500.0,
            status: "Approved"
        )

        XCTAssertEqual(po.poNumber, "PO-001")
        XCTAssertEqual(po.vendor, "Equipment Co")
        XCTAssertEqual(po.amount, 2500.0)
        XCTAssertEqual(po.status, "Approved")
        XCTAssertFalse(po.id.isEmpty)
        XCTAssertNil(po.dateApproved)
        XCTAssertNil(po.datePaid)
    }

    // MARK: - BudgetViewModel Settings

    func testSetTotalBudget() {
        viewModel.setTotalBudget(50000)
        XCTAssertEqual(viewModel.budget.totalBudget, 50000)
    }

    func testSetCurrency() {
        viewModel.setCurrency("EUR")
        XCTAssertEqual(viewModel.budget.currency, "EUR")
    }

    func testSetAIBudgetLimit() {
        viewModel.setAIBudgetLimit(500)
        XCTAssertEqual(viewModel.budget.aiBudgetLimit, 500)
    }

    func testSetContingencyPercentage() {
        viewModel.setContingencyPercentage(0.15)
        XCTAssertEqual(viewModel.budget.contingencyPercentage, 0.15)
    }

    func testSetFringeRate() {
        viewModel.setFringeRate(0.25)
        XCTAssertEqual(viewModel.budget.fringeRate, 0.25)
    }

    // MARK: - Category CRUD

    func testAddCategory() {
        let category = BudgetCategory(name: "VFX", allocated: 10000, accountCode: "5000", categoryGroup: "Post")
        viewModel.addCategory(category)

        XCTAssertEqual(viewModel.budget.categories.count, 1)
        XCTAssertEqual(viewModel.budget.categories.first?.name, "VFX")
    }

    func testUpdateCategory() {
        let category = BudgetCategory(name: "VFX", allocated: 10000)
        viewModel.addCategory(category)

        var updated = category
        updated.allocated = 15000
        viewModel.updateCategory(updated)

        XCTAssertEqual(viewModel.budget.categories.first?.allocated, 15000)
    }

    func testRenameCategoryPersistsAndCascadesToExpenses() {
        // Previously renaming a category was a silent no-op (lookup by name found
        // nothing) and would have orphaned expenses joined by name. WS8.1.
        var category = BudgetCategory(name: "VFX", allocated: 10000)
        viewModel.addCategory(category)
        viewModel.addExpense(Expense(category: "VFX", amount: 500))

        category.name = "Visual Effects"   // same id, new name
        viewModel.updateCategory(category)

        XCTAssertEqual(viewModel.budget.categories.count, 1, "No duplicate created")
        XCTAssertEqual(viewModel.budget.categories.first?.name, "Visual Effects",
                       "Rename must persist")
        XCTAssertEqual(viewModel.budget.categories.first?.allocated, 10000)
        XCTAssertEqual(viewModel.budget.expenses.first?.category, "Visual Effects",
                       "Expenses must follow the renamed category")
    }

    func testRemoveCategory() {
        let category = BudgetCategory(name: "VFX", allocated: 10000)
        viewModel.addCategory(category)

        // Also add an expense in this category
        let expense = Expense(category: "VFX", amount: 500)
        viewModel.addExpense(expense)

        viewModel.removeCategory(category)

        XCTAssertTrue(viewModel.budget.categories.isEmpty)
        XCTAssertTrue(viewModel.budget.expenses.isEmpty,
                     "Related expenses should be removed when category is removed")
    }

    // MARK: - Expense CRUD

    func testAddExpense() {
        let category = BudgetCategory(name: "Camera", allocated: 5000)
        viewModel.addCategory(category)

        let expense = Expense(category: "Camera", amount: 1000)
        viewModel.addExpense(expense)

        XCTAssertEqual(viewModel.budget.expenses.count, 1)
        XCTAssertEqual(viewModel.budget.categories.first?.spent, 1000,
                      "Category spent should be updated when expense is added")
    }

    func testRemoveExpense() {
        let category = BudgetCategory(name: "Camera", allocated: 5000)
        viewModel.addCategory(category)

        let expense = Expense(category: "Camera", amount: 1000)
        viewModel.addExpense(expense)
        viewModel.removeExpense(expense)

        XCTAssertTrue(viewModel.budget.expenses.isEmpty)
        XCTAssertEqual(viewModel.budget.categories.first?.spent, 0,
                      "Category spent should be reduced when expense is removed")
    }

    func testUpdateExpense() {
        let cat1 = BudgetCategory(name: "Camera", allocated: 5000)
        let cat2 = BudgetCategory(name: "Sound", allocated: 3000)
        viewModel.addCategory(cat1)
        viewModel.addCategory(cat2)

        var expense = Expense(category: "Camera", amount: 1000)
        viewModel.addExpense(expense)

        XCTAssertEqual(viewModel.budget.categories[0].spent, 1000)

        // Move expense to different category with different amount
        expense.category = "Sound"
        expense.amount = 500
        viewModel.updateExpense(expense)

        XCTAssertEqual(viewModel.budget.categories[0].spent, 0,
                      "Old category spent should be decremented")
        XCTAssertEqual(viewModel.budget.categories[1].spent, 500,
                      "New category spent should be incremented")
    }

    // MARK: - Statistics

    func testTotalAllocated() {
        viewModel.addCategory(BudgetCategory(name: "A", allocated: 5000))
        viewModel.addCategory(BudgetCategory(name: "B", allocated: 3000))
        viewModel.addCategory(BudgetCategory(name: "C", allocated: 2000))

        XCTAssertEqual(viewModel.totalAllocated, 10000)
    }

    func testTotalExpenses() {
        viewModel.addCategory(BudgetCategory(name: "A", allocated: 10000))
        viewModel.addExpense(Expense(category: "A", amount: 500))
        viewModel.addExpense(Expense(category: "A", amount: 300))
        viewModel.addExpense(Expense(category: "A", amount: 200))

        XCTAssertEqual(viewModel.totalExpenses, 1000)
    }

    func testSpendingPercentage() {
        viewModel.setTotalBudget(10000)
        viewModel.addCategory(BudgetCategory(name: "A", allocated: 5000, spent: 2500))

        XCTAssertEqual(viewModel.spendingPercentage, 25.0, accuracy: 0.01)
    }

    func testSpendingPercentageZeroBudget() {
        viewModel.setTotalBudget(0)
        XCTAssertEqual(viewModel.spendingPercentage, 0)
    }

    func testAllocationPercentage() {
        viewModel.setTotalBudget(10000)
        viewModel.addCategory(BudgetCategory(name: "A", allocated: 3000))
        viewModel.addCategory(BudgetCategory(name: "B", allocated: 2000))

        XCTAssertEqual(viewModel.allocationPercentage, 50.0, accuracy: 0.01)
    }

    // MARK: - Category Health

    func testCategoryHealthHealthy() {
        let category = BudgetCategory(name: "A", allocated: 1000, spent: 500)
        let health = viewModel.categoryHealth(for: category)
        XCTAssertEqual(health, .healthy)
    }

    func testCategoryHealthWarning() {
        let category = BudgetCategory(name: "A", allocated: 1000, spent: 850)
        let health = viewModel.categoryHealth(for: category)
        XCTAssertEqual(health, .warning)
    }

    func testCategoryHealthOverBudget() {
        let category = BudgetCategory(name: "A", allocated: 1000, spent: 1200)
        let health = viewModel.categoryHealth(for: category)
        XCTAssertEqual(health, .overBudget)
    }

    func testCategoryHealthExactlyAtBudget() {
        let category = BudgetCategory(name: "A", allocated: 1000, spent: 1000)
        let health = viewModel.categoryHealth(for: category)
        XCTAssertEqual(health, .overBudget, "Exactly at 100% should count as over budget")
    }

    // MARK: - Purchase Order CRUD

    func testAddPurchaseOrder() {
        let po = PurchaseOrder(poNumber: "PO-001", vendor: "Test", amount: 1000, status: "Approved")
        viewModel.addPurchaseOrder(po)

        XCTAssertEqual(viewModel.budget.purchaseOrders.count, 1)
    }

    func testRemovePurchaseOrder() {
        let po = PurchaseOrder(poNumber: "PO-001", vendor: "Test", amount: 1000)
        viewModel.addPurchaseOrder(po)
        viewModel.removePurchaseOrder(po)

        XCTAssertTrue(viewModel.budget.purchaseOrders.isEmpty)
    }

    func testTotalCommitted() {
        viewModel.addPurchaseOrder(PurchaseOrder(poNumber: "PO-001", amount: 1000, status: "Approved"))
        viewModel.addPurchaseOrder(PurchaseOrder(poNumber: "PO-002", amount: 2000, status: "Committed"))
        viewModel.addPurchaseOrder(PurchaseOrder(poNumber: "PO-003", amount: 500, status: "Draft"))

        XCTAssertEqual(viewModel.totalCommitted, 3000,
                      "Only Approved and Committed POs should count")
    }

    func testTotalPaid() {
        viewModel.addPurchaseOrder(PurchaseOrder(poNumber: "PO-001", amount: 1000, status: "Paid"))
        viewModel.addPurchaseOrder(PurchaseOrder(poNumber: "PO-002", amount: 2000, status: "Approved"))

        XCTAssertEqual(viewModel.totalPaid, 1000, "Only Paid POs should count")
    }

    // MARK: - Next PO Number

    func testNextPONumber() {
        XCTAssertEqual(viewModel.nextPONumber(), "PO-001")

        viewModel.addPurchaseOrder(PurchaseOrder(poNumber: "PO-001", vendor: "A", amount: 100))
        XCTAssertEqual(viewModel.nextPONumber(), "PO-002")

        viewModel.addPurchaseOrder(PurchaseOrder(poNumber: "PO-005", vendor: "B", amount: 200))
        XCTAssertEqual(viewModel.nextPONumber(), "PO-006")
    }

    // MARK: - Default Categories

    func testDefaultCategories() {
        let defaults = BudgetViewModel.defaultCategories

        XCTAssertFalse(defaults.isEmpty)
        XCTAssertTrue(defaults.contains(where: { $0.name == "Camera" }))
        XCTAssertTrue(defaults.contains(where: { $0.name == "Sound" }))
        XCTAssertTrue(defaults.contains(where: { $0.name == "Visual Effects" }))
        XCTAssertTrue(defaults.contains(where: { $0.name == "Contingency" }))

        // Verify category groups
        let atlCategories = defaults.filter { $0.categoryGroup == "ATL" }
        let btlCategories = defaults.filter { $0.categoryGroup == "BTL" }
        let postCategories = defaults.filter { $0.categoryGroup == "Post" }
        let otherCategories = defaults.filter { $0.categoryGroup == "Other" }

        XCTAssertFalse(atlCategories.isEmpty)
        XCTAssertFalse(btlCategories.isEmpty)
        XCTAssertFalse(postCategories.isEmpty)
        XCTAssertFalse(otherCategories.isEmpty)
    }

    func testEnsureDefaultCategories() {
        XCTAssertTrue(viewModel.budget.categories.isEmpty)

        viewModel.ensureDefaultCategories()
        XCTAssertEqual(viewModel.budget.categories.count, BudgetViewModel.defaultCategories.count)
    }

    func testEnsureDefaultCategoriesDoesNotOverwrite() {
        let custom = BudgetCategory(name: "Custom", allocated: 999, isCustom: true)
        viewModel.addCategory(custom)

        viewModel.ensureDefaultCategories()
        XCTAssertEqual(viewModel.budget.categories.count, 1,
                      "Should not add defaults when categories already exist")
        XCTAssertEqual(viewModel.budget.categories.first?.name, "Custom")
    }

    // MARK: - Filtering

    func testExpensesForCategory() {
        viewModel.addExpense(Expense(category: "Camera", amount: 100))
        viewModel.addExpense(Expense(category: "Sound", amount: 200))
        viewModel.addExpense(Expense(category: "Camera", amount: 300))

        let cameraExpenses = viewModel.expenses(forCategory: "Camera")
        XCTAssertEqual(cameraExpenses.count, 2)
    }

    func testExpensesForVendor() {
        viewModel.addExpense(Expense(amount: 100, vendor: "Camera House"))
        viewModel.addExpense(Expense(amount: 200, vendor: "Sound Shop"))
        viewModel.addExpense(Expense(amount: 300, vendor: "Camera House Pro"))

        let results = viewModel.expenses(forVendor: "Camera House")
        XCTAssertEqual(results.count, 2, "Should match case-insensitively with contains")
    }

    // MARK: - Clear All

    func testClearAll() {
        viewModel.setTotalBudget(50000)
        viewModel.addCategory(BudgetCategory(name: "A", allocated: 5000))
        viewModel.addExpense(Expense(category: "A", amount: 500))

        viewModel.clearAll()

        XCTAssertEqual(viewModel.budget.totalBudget, 0)
        XCTAssertTrue(viewModel.budget.categories.isEmpty)
        XCTAssertTrue(viewModel.budget.expenses.isEmpty)
    }

    // MARK: - Codable Round Trip

    func testProjectBudgetCodableRoundTrip() throws {
        var budget = ProjectBudget()
        budget.totalBudget = 100000
        budget.currency = "GBP"
        budget.categories = [
            BudgetCategory(name: "Camera", allocated: 5000, spent: 1000, accountCode: "3300", categoryGroup: "BTL"),
        ]
        budget.expenses = [
            Expense(date: "2026-03-28", category: "Camera", amount: 1000),
        ]
        budget.contingencyPercentage = 0.15
        budget.fringeRate = 0.25

        let data = try JSONEncoder().encode(budget)
        let decoded = try JSONDecoder().decode(ProjectBudget.self, from: data)

        XCTAssertEqual(decoded.totalBudget, 100000)
        XCTAssertEqual(decoded.currency, "GBP")
        XCTAssertEqual(decoded.categories.count, 1)
        XCTAssertEqual(decoded.expenses.count, 1)
        XCTAssertEqual(decoded.contingencyPercentage, 0.15)
        XCTAssertEqual(decoded.fringeRate, 0.25)
    }
}
