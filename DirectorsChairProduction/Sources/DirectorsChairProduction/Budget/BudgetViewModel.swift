// DirectorsChairProduction/Sources/DirectorsChairProduction/Budget/BudgetViewModel.swift
//
// Budget ViewModel - Budget Data Management
// Manages project budget, categories, and expenses.

import SwiftUI
import DirectorsChairCore

// MARK: - Budget ViewModel

@MainActor
public class BudgetViewModel: ObservableObject {
    @Published public var budget: ProjectBudget

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

    public func expensesByCategory() -> [String: Double] {
        Dictionary(grouping: budget.expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    public func expensesByDate() -> [String: Double] {
        Dictionary(grouping: budget.expenses, by: { $0.date })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
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

    // MARK: - Private Helpers

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
