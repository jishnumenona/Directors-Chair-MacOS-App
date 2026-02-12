// DirectorsChairProduction/Sources/DirectorsChairProduction/Budget/BudgetViewModel.swift
//
// Budget ViewModel - Production Accounting Data Management
// Manages project budget, categories, expenses, purchase orders, and projections.

import SwiftUI
import DirectorsChairCore

// MARK: - Cost Report Row

public struct CostReportRow: Identifiable {
    public var id: String { accountCode }
    public var accountCode: String
    public var description: String
    public var thisWeek: Double
    public var toDate: Double
    public var committed: Double
    public var total: Double
    public var etc: Double  // Estimate to Complete
    public var efc: Double  // Estimated Final Cost
    public var budget: Double
    public var variance: Double
}

// MARK: - Receipt Analysis Result

public struct ReceiptAnalysisResult {
    public var description: String
    public var vendor: String
    public var date: String       // YYYY-MM-DD
    public var amount: Double
    public var category: String   // Best-guess category

    public init(description: String, vendor: String, date: String, amount: Double, category: String) {
        self.description = description
        self.vendor = vendor
        self.date = date
        self.amount = amount
        self.category = category
    }
}

// MARK: - Budget ViewModel

@MainActor
public class BudgetViewModel: ObservableObject {
    @Published public var budget: ProjectBudget

    // Connected data from project
    @Published public var castMembers: [CastMember] = []
    @Published public var crewMembers: [CrewMember] = []
    @Published public var equipment: [EquipmentItem] = []
    @Published public var equipmentAllocations: [EquipmentAllocation] = []
    @Published public var scheduleItems: [ScheduleItem] = []
    @Published public var props: [Prop] = []
    @Published public var sequences: [Sequence] = []

    // Accounting defaults from project settings
    public var defaultDepartment: String = ""
    public var defaultAccountCode: String = ""

    // Project base path for resolving receipt file paths
    public var projectBasePath: URL?

    // AI receipt analysis callback (implemented in main app target)
    // Returns array: empty = failure, 1 item = single receipt, 2+ = multi-item receipt
    public var onAnalyzeReceipt: ((Data, String) async -> [ReceiptAnalysisResult])?

    // Callback for data persistence
    public var onBudgetChanged: ((ProjectBudget) -> Void)?

    public init(budget: ProjectBudget = ProjectBudget()) {
        self.budget = budget
    }

    // MARK: - Budget Settings

    public func setTotalBudget(_ amount: Double) {
        budget.totalBudget = amount
        notifyChange()
    }

    public func setCurrency(_ currency: String) {
        budget.currency = currency
        notifyChange()
    }

    public func setAIBudgetLimit(_ limit: Double) {
        budget.aiBudgetLimit = limit
        notifyChange()
    }

    public func setContingencyPercentage(_ pct: Double) {
        budget.contingencyPercentage = pct
        notifyChange()
    }

    public func setFringeRate(_ rate: Double) {
        budget.fringeRate = rate
        notifyChange()
    }

    // MARK: - Category CRUD

    public func addCategory(_ category: BudgetCategory) {
        budget.categories.append(category)
        notifyChange()
    }

    public func updateCategory(_ category: BudgetCategory) {
        if let index = budget.categories.firstIndex(where: { $0.name == category.name }) {
            budget.categories[index] = category
            notifyChange()
        }
    }

    public func removeCategory(_ category: BudgetCategory) {
        budget.categories.removeAll { $0.name == category.name }
        // Also remove related expenses
        budget.expenses.removeAll { $0.category == category.name }
        notifyChange()
    }

    public func setCategories(_ categories: [BudgetCategory]) {
        budget.categories = categories
        notifyChange()
    }

    // MARK: - Expense CRUD

    public func addExpense(_ expense: Expense) {
        budget.expenses.append(expense)
        // Update category spent amount
        if let index = budget.categories.firstIndex(where: { $0.name == expense.category }) {
            budget.categories[index].spent += expense.amount
        }
        notifyChange()
    }

    public func updateExpense(_ expense: Expense) {
        if let index = budget.expenses.firstIndex(where: { $0.id == expense.id }) {
            let oldExpense = budget.expenses[index]

            // Update old category spent (subtract old amount)
            if let categoryIndex = budget.categories.firstIndex(where: { $0.name == oldExpense.category }) {
                budget.categories[categoryIndex].spent -= oldExpense.amount
            }

            // Update new category spent (add new amount)
            if let categoryIndex = budget.categories.firstIndex(where: { $0.name == expense.category }) {
                budget.categories[categoryIndex].spent += expense.amount
            }

            budget.expenses[index] = expense
            notifyChange()
        }
    }

    public func removeExpense(_ expense: Expense) {
        // Update category spent amount
        if let categoryIndex = budget.categories.firstIndex(where: { $0.name == expense.category }) {
            budget.categories[categoryIndex].spent -= expense.amount
        }
        budget.expenses.removeAll { $0.id == expense.id }
        notifyChange()
    }

    public func setExpenses(_ expenses: [Expense]) {
        budget.expenses = expenses
        recalculateCategorySpending()
        notifyChange()
    }

    // MARK: - Purchase Order CRUD

    public func addPurchaseOrder(_ po: PurchaseOrder) {
        budget.purchaseOrders.append(po)
        notifyChange()
    }

    public func updatePurchaseOrder(_ po: PurchaseOrder) {
        if let index = budget.purchaseOrders.firstIndex(where: { $0.id == po.id }) {
            budget.purchaseOrders[index] = po
            notifyChange()
        }
    }

    public func removePurchaseOrder(_ po: PurchaseOrder) {
        budget.purchaseOrders.removeAll { $0.id == po.id }
        notifyChange()
    }

    // MARK: - AI Estimates

    public func setAIProductionEstimates(_ estimates: [String: Double]) {
        budget.aiProductionEstimates = estimates
        notifyChange()
    }

    public func updateAIEstimate(key: String, value: Double) {
        if budget.aiProductionEstimates == nil {
            budget.aiProductionEstimates = [:]
        }
        budget.aiProductionEstimates?[key] = value
        notifyChange()
    }

    public func removeAIEstimate(key: String) {
        budget.aiProductionEstimates?.removeValue(forKey: key)
        notifyChange()
    }

    // MARK: - Statistics

    public var totalAllocated: Double {
        budget.categories.reduce(0) { $0 + $1.allocated }
    }

    public var totalExpenses: Double {
        budget.expenses.reduce(0) { $0 + $1.amount }
    }

    public var spendingPercentage: Double {
        guard budget.totalBudget > 0 else { return 0 }
        return (budget.totalSpent / budget.totalBudget) * 100
    }

    public var allocationPercentage: Double {
        guard budget.totalBudget > 0 else { return 0 }
        return (totalAllocated / budget.totalBudget) * 100
    }

    public var aiSpendingPercentage: Double {
        guard budget.aiBudgetLimit > 0, let estimates = budget.aiProductionEstimates else { return 0 }
        let totalEstimates = estimates.values.reduce(0, +)
        return (totalEstimates / budget.aiBudgetLimit) * 100
    }

    // MARK: - Connected Data Projections

    public var totalShootDays: Int {
        let uniqueDates = Set(scheduleItems.compactMap { $0.shootDate }.filter { !$0.isEmpty })
        return max(uniqueDates.count, 1)
    }

    public var projectedCastPayroll: Double {
        castMembers.reduce(0) { total, cast in
            if cast.paymentType == "One Time" {
                return total + cast.oneTimePayment
            } else {
                let days = Double(shootDaysForCast(cast))
                return total + (cast.dailyRate * days)
            }
        }
    }

    public var projectedCastFringes: Double {
        projectedCastPayroll * budget.fringeRate
    }

    public var projectedCrewPayroll: Double {
        crewMembers.reduce(0) { total, crew in
            if crew.paymentType == "One Time" {
                return total + crew.oneTimePayment
            } else {
                let days = Double(shootDaysForCrew(crew))
                return total + ((crew.dailyRate + crew.kitFee) * days)
            }
        }
    }

    public var projectedCrewFringes: Double {
        projectedCrewPayroll * budget.fringeRate
    }

    public var projectedEquipmentRental: Double {
        equipment.reduce(0) { total, item in
            let days = allocationDaysForEquipment(item)
            return total + (item.rentalDailyRate * Double(days))
        }
    }

    public var projectedPropsCost: Double {
        props.reduce(0) { total, prop in
            let acquisition = prop.acquisitionCost ?? 0
            let rental = prop.rentalDailyRate ?? 0
            let rentalDays = rentalDaysForProp(prop)
            return total + acquisition + (rental * Double(rentalDays))
        }
    }

    public var totalCommitted: Double {
        budget.purchaseOrders
            .filter { $0.status == "Approved" || $0.status == "Committed" }
            .reduce(0) { $0 + $1.amount }
    }

    public var totalPaid: Double {
        budget.purchaseOrders
            .filter { $0.status == "Paid" }
            .reduce(0) { $0 + $1.amount }
    }

    public var totalProjectedCost: Double {
        totalAllocated + totalCommitted + projectedCastPayroll + projectedCastFringes +
        projectedCrewPayroll + projectedCrewFringes + projectedEquipmentRental + projectedPropsCost
    }

    public var dailyBurnRate: Double {
        let days = Double(totalShootDays)
        guard days > 0 else { return 0 }
        return totalExpenses / days
    }

    public var contingencyAmount: Double {
        let btlPostTotal = budget.categories
            .filter { $0.categoryGroup == "BTL" || $0.categoryGroup == "Post" }
            .reduce(0) { $0 + $1.allocated }
        return btlPostTotal * budget.contingencyPercentage
    }

    // MARK: - Department Breakdown

    public func spendingByDepartment() -> [(department: String, allocated: Double, spent: Double, committed: Double)] {
        var departments: [String: (allocated: Double, spent: Double, committed: Double)] = [:]

        // Accumulate from expenses
        for expense in budget.expenses {
            let dept = expense.department.isEmpty ? expense.category : expense.department
            guard !dept.isEmpty else { continue }
            var entry = departments[dept, default: (0, 0, 0)]
            entry.spent += expense.amount
            departments[dept] = entry
        }

        // Accumulate from categories
        for category in budget.categories {
            // Use category name as department if no explicit department mapping
            let dept = category.name
            var entry = departments[dept, default: (0, 0, 0)]
            entry.allocated += category.allocated
            departments[dept] = entry
        }

        // Accumulate from POs
        for po in budget.purchaseOrders where (po.status == "Approved" || po.status == "Committed") {
            let dept = po.department.isEmpty ? "General" : po.department
            var entry = departments[dept, default: (0, 0, 0)]
            entry.committed += po.amount
            departments[dept] = entry
        }

        return departments
            .map { (department: $0.key, allocated: $0.value.allocated, spent: $0.value.spent, committed: $0.value.committed) }
            .sorted { $0.spent + $0.committed > $1.spent + $1.committed }
    }

    // MARK: - Per-Scene Cost Breakdown

    public func costByScene() -> [(sceneName: String, estimated: Double, actual: Double)] {
        scheduleItems.map { item in
            (
                sceneName: item.sceneName,
                estimated: item.estimatedCost,
                actual: item.actualCost ?? 0
            )
        }
        .sorted { $0.estimated > $1.estimated }
    }

    // MARK: - Cost Report Data

    public func costReportData() -> [CostReportRow] {
        let now = Date()
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let weekAgoStr = formatter.string(from: weekAgo)

        return budget.categories.map { category in
            let categoryExpenses = budget.expenses.filter { $0.category == category.name }
            let thisWeek = categoryExpenses
                .filter { $0.date >= weekAgoStr }
                .reduce(0) { $0 + $1.amount }
            let toDate = categoryExpenses.reduce(0) { $0 + $1.amount }
            let committed = budget.purchaseOrders
                .filter { ($0.status == "Approved" || $0.status == "Committed") }
                .filter { $0.accountCode == category.accountCode || $0.department == category.name }
                .reduce(0) { $0 + $1.amount }
            let total = toDate + committed
            let etc = max(category.allocated - total, 0)
            let efc = total + etc
            let variance = category.allocated - efc

            return CostReportRow(
                accountCode: category.accountCode,
                description: category.name,
                thisWeek: thisWeek,
                toDate: toDate,
                committed: committed,
                total: total,
                etc: etc,
                efc: efc,
                budget: category.allocated,
                variance: variance
            )
        }
    }

    // MARK: - Category Groups

    public func categoriesForGroup(_ group: String) -> [BudgetCategory] {
        budget.categories.filter { $0.categoryGroup == group }
    }

    public func groupTotal(allocated: Bool, for group: String) -> Double {
        let cats = categoriesForGroup(group)
        return allocated ? cats.reduce(0) { $0 + $1.allocated } : cats.reduce(0) { $0 + $1.spent }
    }

    // MARK: - Filtering & Queries

    public func expenses(forCategory categoryName: String) -> [Expense] {
        budget.expenses.filter { $0.category == categoryName }
    }

    public func expenses(forDate date: String) -> [Expense] {
        budget.expenses.filter { $0.date == date }
    }

    public func expenses(forVendor vendor: String) -> [Expense] {
        budget.expenses.filter { $0.vendor.localizedCaseInsensitiveContains(vendor) }
    }

    public func expenses(forDepartment department: String) -> [Expense] {
        budget.expenses.filter { $0.department == department }
    }

    public func expensesByCategory() -> [String: Double] {
        Dictionary(grouping: budget.expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    public func expensesByDate() -> [String: Double] {
        Dictionary(grouping: budget.expenses, by: { $0.date })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    public func purchaseOrders(forStatus status: String) -> [PurchaseOrder] {
        if status == "All" { return budget.purchaseOrders }
        return budget.purchaseOrders.filter { $0.status == status }
    }

    // MARK: - Category Health

    public func categoryHealth(for category: BudgetCategory) -> CategoryHealth {
        let percentage = category.allocated > 0 ? (category.spent / category.allocated) * 100 : 0

        if percentage >= 100 {
            return .overBudget
        } else if percentage >= 80 {
            return .warning
        } else {
            return .healthy
        }
    }

    public enum CategoryHealth {
        case healthy
        case warning
        case overBudget
    }

    // MARK: - Budget Projections

    public func projectMonthlySpending() -> Double {
        guard !budget.expenses.isEmpty else { return 0 }

        let sortedExpenses = budget.expenses.sorted { $0.date < $1.date }
        guard let firstDate = sortedExpenses.first?.date,
              let lastDate = sortedExpenses.last?.date else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let start = formatter.date(from: firstDate),
              let end = formatter.date(from: lastDate) else { return 0 }

        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1
        guard days > 0 else { return totalExpenses }

        let dailyRate = totalExpenses / Double(days)
        return dailyRate * 30 // Monthly projection
    }

    // MARK: - Default Categories

    public static let defaultCategories: [BudgetCategory] = [
        // ATL
        BudgetCategory(name: "Story & Rights", accountCode: "1100", categoryGroup: "ATL"),
        BudgetCategory(name: "Producers", accountCode: "1200", categoryGroup: "ATL"),
        BudgetCategory(name: "Directors", accountCode: "1300", categoryGroup: "ATL"),
        BudgetCategory(name: "Cast", accountCode: "1400", categoryGroup: "ATL"),
        // BTL
        BudgetCategory(name: "Production Staff", accountCode: "2000", categoryGroup: "BTL"),
        BudgetCategory(name: "Set Design", accountCode: "2200", categoryGroup: "BTL"),
        BudgetCategory(name: "Set Construction", accountCode: "2300", categoryGroup: "BTL"),
        BudgetCategory(name: "Set Operations", accountCode: "2500", categoryGroup: "BTL"),
        BudgetCategory(name: "Props", accountCode: "2800", categoryGroup: "BTL"),
        BudgetCategory(name: "Wardrobe", accountCode: "2900", categoryGroup: "BTL"),
        BudgetCategory(name: "Makeup & Hair", accountCode: "3100", categoryGroup: "BTL"),
        BudgetCategory(name: "Lighting", accountCode: "3200", categoryGroup: "BTL"),
        BudgetCategory(name: "Camera", accountCode: "3300", categoryGroup: "BTL"),
        BudgetCategory(name: "Sound", accountCode: "3400", categoryGroup: "BTL"),
        BudgetCategory(name: "Transportation", accountCode: "3500", categoryGroup: "BTL"),
        BudgetCategory(name: "Locations", accountCode: "3600", categoryGroup: "BTL"),
        // Post
        BudgetCategory(name: "Post Supervision", accountCode: "4500", categoryGroup: "Post"),
        BudgetCategory(name: "Music", accountCode: "4600", categoryGroup: "Post"),
        BudgetCategory(name: "Visual Effects", accountCode: "5000", categoryGroup: "Post"),
        BudgetCategory(name: "Editing & Finishing", accountCode: "5100", categoryGroup: "Post"),
        // Other
        BudgetCategory(name: "Insurance", accountCode: "6700", categoryGroup: "Other"),
        BudgetCategory(name: "General & Admin", accountCode: "6800", categoryGroup: "Other"),
        BudgetCategory(name: "Contingency", accountCode: "7000", categoryGroup: "Other"),
    ]

    public func ensureDefaultCategories() {
        guard budget.categories.isEmpty else { return }
        budget.categories = Self.defaultCategories
        notifyChange()
    }

    public func nextPONumber() -> String {
        let maxNum = budget.purchaseOrders
            .compactMap { po -> Int? in
                let num = po.poNumber.replacingOccurrences(of: "PO-", with: "")
                return Int(num)
            }
            .max() ?? 0
        return String(format: "PO-%03d", maxNum + 1)
    }

    // MARK: - Private Helpers

    private func shootDaysForCast(_ cast: CastMember) -> Int {
        let matchingItems = scheduleItems.filter { item in
            item.requiredActors.contains(cast.actorName) || item.requiredActors.contains(cast.characterName)
        }
        let uniqueDates = Set(matchingItems.compactMap { $0.shootDate }.filter { !$0.isEmpty })
        return max(uniqueDates.count, matchingItems.isEmpty ? 0 : 1)
    }

    private func shootDaysForCrew(_ crew: CrewMember) -> Int {
        let matchingItems = scheduleItems.filter { item in
            item.requiredCrew.contains(crew.name) || item.requiredCrew.contains(crew.role)
        }
        if matchingItems.isEmpty {
            // Crew typically works all shoot days
            return totalShootDays
        }
        let uniqueDates = Set(matchingItems.compactMap { $0.shootDate }.filter { !$0.isEmpty })
        return max(uniqueDates.count, 1)
    }

    private func allocationDaysForEquipment(_ item: EquipmentItem) -> Int {
        let allocs = equipmentAllocations.filter { $0.equipmentItemId == item.id }
        if allocs.isEmpty { return 0 }

        var totalDays = 0
        for alloc in allocs {
            if alloc.allocationMode == .fullProduction {
                totalDays += totalShootDays * alloc.quantityAllocated
            } else {
                totalDays += alloc.allocatedDates.count * alloc.quantityAllocated
            }
        }
        return totalDays
    }

    private func rentalDaysForProp(_ prop: Prop) -> Int {
        guard prop.rentalDailyRate != nil else { return 0 }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let startStr = prop.rentalStartDate, let endStr = prop.rentalEndDate,
           let start = formatter.date(from: startStr), let end = formatter.date(from: endStr) {
            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            return max(days, 1)
        }
        // Default to total shoot days if no rental dates specified
        return totalShootDays
    }

    private func recalculateCategorySpending() {
        // Reset all category spent amounts
        for i in budget.categories.indices {
            budget.categories[i].spent = 0
        }

        // Recalculate from expenses
        for expense in budget.expenses {
            if let index = budget.categories.firstIndex(where: { $0.name == expense.category }) {
                budget.categories[index].spent += expense.amount
            }
        }
    }

    private func notifyChange() {
        onBudgetChanged?(budget)
    }

    // MARK: - Bulk Operations

    public func setBudget(_ newBudget: ProjectBudget) {
        budget = newBudget
    }

    public func clearAll() {
        budget = ProjectBudget()
        notifyChange()
    }
}
