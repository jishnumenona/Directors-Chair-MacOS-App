// DirectorsChairProduction/Sources/DirectorsChairProduction/Budget/BudgetView.swift
//
// Budget View - Project Budget Management
// View for managing project budget, categories, and expense tracking.
// Provides visual representations of budget allocation and spending.

import SwiftUI
import DirectorsChairCore

// MARK: - Budget Display Mode

public enum BudgetDisplayMode: String, CaseIterable {
    case overview = "Overview"
    case categories = "Categories"
    case expenses = "Expenses"
    case aiEstimates = "AI Estimates"
}

// MARK: - Budget View

public struct BudgetView: View {
    @ObservedObject var viewModel: BudgetViewModel

    @State private var displayMode: BudgetDisplayMode = .overview
    @State private var selectedCategory: BudgetCategory?
    @State private var selectedExpense: Expense?
    @State private var showingAddCategorySheet = false
    @State private var showingEditCategorySheet = false
    @State private var showingAddExpenseSheet = false
    @State private var showingEditExpenseSheet = false

    public init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            budgetToolbar

            Divider()

            // Content based on display mode
            switch displayMode {
            case .overview:
                budgetOverviewView
            case .categories:
                categoriesView
            case .expenses:
                expensesView
            case .aiEstimates:
                aiEstimatesView
            }
        }
        .sheet(isPresented: $showingAddCategorySheet) {
            CategoryEditorSheet(viewModel: viewModel, category: nil)
        }
        .sheet(isPresented: $showingEditCategorySheet) {
            if let category = selectedCategory {
                CategoryEditorSheet(viewModel: viewModel, category: category)
            }
        }
        .sheet(isPresented: $showingAddExpenseSheet) {
            ExpenseEditorSheet(viewModel: viewModel, expense: nil)
        }
        .sheet(isPresented: $showingEditExpenseSheet) {
            if let expense = selectedExpense {
                ExpenseEditorSheet(viewModel: viewModel, expense: expense)
            }
        }
    }

    // MARK: - Toolbar

    private var budgetToolbar: some View {
        HStack(spacing: 12) {
            Picker("Display Mode", selection: $displayMode) {
                ForEach(BudgetDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)

            Spacer()

            // Context-sensitive buttons
            switch displayMode {
            case .categories:
                Button(action: { showingAddCategorySheet = true }) {
                    Label("Add Category", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

            case .expenses:
                Button(action: { showingAddExpenseSheet = true }) {
                    Label("Add Expense", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

            default:
                EmptyView()
            }

            Button(action: exportBudgetReport) {
                Label("Export Report", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Budget Overview

    private var budgetOverviewView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Budget Summary Cards
                HStack(spacing: 20) {
                    BudgetSummaryCard(
                        title: "Total Budget",
                        value: viewModel.budget.totalBudget,
                        subtitle: viewModel.budget.currency,
                        color: .blue
                    )

                    BudgetSummaryCard(
                        title: "Total Spent",
                        value: viewModel.budget.totalSpent,
                        subtitle: "Actual",
                        color: .orange
                    )

                    BudgetSummaryCard(
                        title: "Remaining",
                        value: viewModel.budget.totalRemaining,
                        subtitle: viewModel.budget.totalRemaining >= 0 ? "Under Budget" : "Over Budget",
                        color: viewModel.budget.totalRemaining >= 0 ? .green : .red
                    )

                    BudgetSummaryCard(
                        title: "AI Budget",
                        value: viewModel.budget.aiBudgetLimit,
                        subtitle: "Limit",
                        color: .purple
                    )
                }
                .padding(.horizontal)

                // Budget Progress
                GroupBox("Budget Progress") {
                    VStack(spacing: 12) {
                        let percentage = viewModel.spendingPercentage

                        ProgressView(value: min(percentage / 100, 1.0))
                            .progressViewStyle(.linear)
                            .tint(percentage > 100 ? .red : (percentage > 80 ? .orange : .green))

                        HStack {
                            Text("\(String(format: "%.1f", percentage))% of budget used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)

                // Category Breakdown Chart
                GroupBox("Budget Allocation by Category") {
                    categoryBreakdownChart
                }
                .padding(.horizontal)

                // Recent Expenses
                GroupBox("Recent Expenses") {
                    recentExpensesSection
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private var categoryBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.budget.categories.isEmpty {
                Text("No categories defined")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.budget.categories, id: \.name) { category in
                    HStack {
                        Text(category.name)
                            .frame(width: 150, alignment: .leading)

                        GeometryReader { geometry in
                            let allocatedWidth = category.allocated > 0 ?
                                CGFloat(category.allocated / max(viewModel.budget.totalBudget, 1)) * geometry.size.width : 0
                            let spentWidth = category.spent > 0 ?
                                CGFloat(category.spent / max(viewModel.budget.totalBudget, 1)) * geometry.size.width : 0

                            ZStack(alignment: .leading) {
                                // Allocated (background)
                                Rectangle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: allocatedWidth, height: 20)

                                // Spent (foreground)
                                Rectangle()
                                    .fill(spentColor(for: category))
                                    .frame(width: min(spentWidth, geometry.size.width), height: 20)
                            }
                        }
                        .frame(height: 20)

                        Text(formatCurrency(category.spent))
                            .font(.caption)
                            .frame(width: 80, alignment: .trailing)

                        Text("/ \(formatCurrency(category.allocated))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }

            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Rectangle().fill(Color.blue.opacity(0.3)).frame(width: 12, height: 12)
                    Text("Allocated").font(.caption).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Rectangle().fill(Color.green).frame(width: 12, height: 12)
                    Text("Spent (under)").font(.caption).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Rectangle().fill(Color.red).frame(width: 12, height: 12)
                    Text("Spent (over)").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.top)
        }
        .padding()
    }

    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let recentExpenses = viewModel.budget.expenses.sorted {
                $0.date > $1.date
            }.prefix(5)

            if recentExpenses.isEmpty {
                Text("No expenses recorded")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(recentExpenses), id: \.id) { expense in
                    HStack {
                        Text(expense.date)
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)

                        Text(expense.category)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)

                        Text(expense.description)
                            .lineLimit(1)

                        Spacer()

                        Text(formatCurrency(expense.amount))
                            .font(.headline)
                    }
                    .padding(.vertical, 4)

                    if expense.id != recentExpenses.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Categories View

    private var categoriesView: some View {
        VStack(spacing: 0) {
            // Stats
            HStack {
                Text("Total Categories: \(viewModel.budget.categories.count)")
                Spacer()
                Text("Total Allocated: \(formatCurrency(viewModel.totalAllocated))")
            }
            .font(.caption)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Categories List
            List(viewModel.budget.categories, id: \.name, selection: $selectedCategory) { category in
                CategoryRow(category: category)
                    .tag(category)
                    .onTapGesture(count: 2) {
                        selectedCategory = category
                        showingEditCategorySheet = true
                    }
            }

            // Actions
            HStack {
                Button("Add Category") {
                    showingAddCategorySheet = true
                }

                Button("Edit Selected") {
                    showingEditCategorySheet = true
                }
                .disabled(selectedCategory == nil)

                Button("Delete Selected") {
                    if let category = selectedCategory {
                        viewModel.removeCategory(category)
                        selectedCategory = nil
                    }
                }
                .disabled(selectedCategory == nil)

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Expenses View

    private var expensesView: some View {
        VStack(spacing: 0) {
            // Stats
            HStack {
                Text("Total Expenses: \(viewModel.budget.expenses.count)")
                Spacer()
                Text("Total Amount: \(formatCurrency(viewModel.totalExpenses))")
            }
            .font(.caption)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Expenses List
            List(viewModel.budget.expenses.sorted { $0.date > $1.date }, selection: $selectedExpense) { expense in
                ExpenseRow(expense: expense)
                    .tag(expense)
                    .onTapGesture(count: 2) {
                        selectedExpense = expense
                        showingEditExpenseSheet = true
                    }
            }

            // Actions
            HStack {
                Button("Add Expense") {
                    showingAddExpenseSheet = true
                }

                Button("Edit Selected") {
                    showingEditExpenseSheet = true
                }
                .disabled(selectedExpense == nil)

                Button("Delete Selected") {
                    if let expense = selectedExpense {
                        viewModel.removeExpense(expense)
                        selectedExpense = nil
                    }
                }
                .disabled(selectedExpense == nil)

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - AI Estimates View

    private var aiEstimatesView: some View {
        ScrollView {
            VStack(spacing: 20) {
                GroupBox("AI Production Cost Estimates") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Estimated costs for AI-generated content")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let estimates = viewModel.budget.aiProductionEstimates, !estimates.isEmpty {
                            ForEach(estimates.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack {
                                    Text(key)
                                    Spacer()
                                    Text(formatCurrency(value))
                                        .font(.headline)
                                }
                                .padding(.vertical, 4)

                                Divider()
                            }

                            HStack {
                                Text("Total AI Estimates")
                                    .font(.headline)
                                Spacer()
                                Text(formatCurrency(estimates.values.reduce(0, +)))
                                    .font(.headline)
                                    .foregroundColor(.purple)
                            }
                            .padding(.top)
                        } else {
                            Text("No AI production estimates available")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)

                GroupBox("AI Budget Limit") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current Limit")
                            Spacer()
                            Text(formatCurrency(viewModel.budget.aiBudgetLimit))
                                .font(.headline)
                        }

                        if let estimates = viewModel.budget.aiProductionEstimates {
                            let totalEstimates = estimates.values.reduce(0, +)
                            let remaining = viewModel.budget.aiBudgetLimit - totalEstimates

                            HStack {
                                Text("Remaining")
                                Spacer()
                                Text(formatCurrency(remaining))
                                    .font(.headline)
                                    .foregroundColor(remaining >= 0 ? .green : .red)
                            }

                            ProgressView(value: min(totalEstimates / max(viewModel.budget.aiBudgetLimit, 1), 1.0))
                                .progressViewStyle(.linear)
                                .tint(remaining >= 0 ? .green : .red)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Helpers

    private func spentColor(for category: BudgetCategory) -> Color {
        if category.spent > category.allocated {
            return .red
        } else if category.spent > category.allocated * 0.8 {
            return .orange
        } else {
            return .green
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.budget.currency
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func exportBudgetReport() {
        // TODO: Export budget report to PDF
    }
}

// MARK: - Budget Summary Card

struct BudgetSummaryCard: View {
    let title: String
    let value: Double
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(formatCurrency(value))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: BudgetCategory

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.headline)
                if !category.description.isEmpty {
                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Allocated: \(formatCurrency(category.allocated))")
                    .font(.caption)
                Text("Spent: \(formatCurrency(category.spent))")
                    .font(.caption)
                    .foregroundColor(category.spent > category.allocated ? .red : .secondary)
            }

            // Variance indicator
            let variance = category.variancePercentage
            Text(variance >= 0 ? "+\(String(format: "%.1f", variance))%" : "\(String(format: "%.1f", variance))%")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(variance > 0 ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Expense Row

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack {
            Text(expense.date)
                .font(.caption)
                .frame(width: 80, alignment: .leading)

            Text(expense.category)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)
                .frame(width: 120)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description)
                    .lineLimit(1)
                if !expense.vendor.isEmpty {
                    Text(expense.vendor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(formatCurrency(expense.amount))
                .font(.headline)
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Category Editor Sheet

struct CategoryEditorSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let category: BudgetCategory?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var allocated: Double = 0
    @State private var spent: Double = 0
    @State private var description = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(category == nil ? "Add Category" : "Edit Category")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Category Information") {
                    TextField("Category Name", text: $name)
                    TextField("Description", text: $description)
                }

                Section("Budget") {
                    HStack {
                        Text("Allocated Amount")
                        Spacer()
                        TextField("Amount", value: $allocated, format: .currency(code: "USD"))
                            .frame(width: 150)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Spent Amount")
                        Spacer()
                        TextField("Amount", value: $spent, format: .currency(code: "USD"))
                            .frame(width: 150)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding()
        }
        .frame(width: 450, height: 350)
        .onAppear {
            if let category = category {
                name = category.name
                allocated = category.allocated
                spent = category.spent
                description = category.description
            }
        }
    }

    private func save() {
        let newCategory = BudgetCategory(
            name: name,
            allocated: allocated,
            spent: spent,
            description: description,
            isCustom: category?.isCustom ?? true
        )

        if category != nil {
            viewModel.updateCategory(newCategory)
        } else {
            viewModel.addCategory(newCategory)
        }
        dismiss()
    }
}

// MARK: - Expense Editor Sheet

struct ExpenseEditorSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let expense: Expense?

    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var category = ""
    @State private var amount: Double = 0
    @State private var description = ""
    @State private var vendor = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(expense == nil ? "Add Expense" : "Edit Expense")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(category.isEmpty || description.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Expense Details") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])

                    Picker("Category", selection: $category) {
                        Text("Select Category").tag("")
                        ForEach(viewModel.budget.categories, id: \.name) { cat in
                            Text(cat.name).tag(cat.name)
                        }
                    }

                    TextField("Description", text: $description)
                    TextField("Vendor", text: $vendor)
                }

                Section("Amount") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("Amount", value: $amount, format: .currency(code: "USD"))
                            .frame(width: 150)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding()
        }
        .frame(width: 450, height: 400)
        .onAppear {
            if let expense = expense {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let parsedDate = formatter.date(from: expense.date) {
                    date = parsedDate
                }
                category = expense.category
                amount = expense.amount
                description = expense.description
                vendor = expense.vendor
            }
        }
    }

    private func save() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        if var existing = expense {
            existing.date = dateStr
            existing.category = category
            existing.amount = amount
            existing.description = description
            existing.vendor = vendor
            viewModel.updateExpense(existing)
        } else {
            let newExpense = Expense(
                date: dateStr,
                category: category,
                amount: amount,
                description: description,
                vendor: vendor
            )
            viewModel.addExpense(newExpense)
        }
        dismiss()
    }
}
