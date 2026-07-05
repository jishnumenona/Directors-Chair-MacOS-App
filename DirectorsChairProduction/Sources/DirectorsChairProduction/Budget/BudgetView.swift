// DirectorsChairProduction/Sources/DirectorsChairProduction/Budget/BudgetView.swift
//
// Accounting View - Comprehensive Production Accounting
// 6 sub-tabs: Overview, Top Sheet, Cost Report, Expenses, Purchase Orders, Payroll

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit
import DirectorsChairCore

// MARK: - Accounting Display Mode

public enum AccountingDisplayMode: String, CaseIterable {
    case overview = "Overview"
    case topSheet = "Top Sheet"
    case costReport = "Cost Report"
    case expenses = "Expenses"
    case purchaseOrders = "Purchase Orders"
    case payroll = "Payroll"
    case export = "Export"
}

// MARK: - Budget View (Accounting)

public struct BudgetView: View {
    @ObservedObject var viewModel: BudgetViewModel

    @State private var displayMode: AccountingDisplayMode = .overview
    @State private var selectedCategory: BudgetCategory?
    @State private var selectedExpense: Expense?
    @State private var selectedPO: PurchaseOrder?
    @State private var showingAddCategorySheet = false
    @State private var showingEditCategorySheet = false
    @State private var showingAddExpenseSheet = false
    @State private var showingEditExpenseSheet = false
    @State private var showingAddPOSheet = false
    @State private var showingEditPOSheet = false
    @State private var expenseDeptFilter = "All"
    @State private var poStatusFilter = "All"
    @State private var exportStatus: String? = nil
    @State private var isExporting = false
    @State private var exportDatePreset = "allTime"
    @State private var exportCustomDateFrom = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var exportCustomDateTo = Date()
    @State private var exportSelectedDepartments: Set<String> = []
    @State private var exportSelectedGroups: Set<String> = []
    @State private var exportSelectedExpenseStatuses: Set<String> = []
    @State private var exportSelectedPOStatuses: Set<String> = []
    @State private var exportSelectedPaymentMethods: Set<String> = []
    @State private var exportMinAmount = ""
    @State private var exportMaxAmount = ""

    public init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            accountingActionBar

            switch displayMode {
            case .overview:
                accountingOverviewView
            case .topSheet:
                topSheetView
            case .costReport:
                costReportView
            case .expenses:
                expensesView
            case .purchaseOrders:
                purchaseOrdersView
            case .payroll:
                payrollView
            case .export:
                exportView
            }
        }
        .onAppear {
            viewModel.ensureDefaultCategories()
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
        .sheet(isPresented: $showingAddPOSheet) {
            POEditorSheet(viewModel: viewModel, po: nil)
        }
        .sheet(isPresented: $showingEditPOSheet) {
            if let po = selectedPO {
                POEditorSheet(viewModel: viewModel, po: po)
            }
        }
    }

    // MARK: - Action Bar

    private var accountingActionBar: some View {
        HStack(spacing: 8) {
            ProductionChip(icon: "chart.pie", "Overview", selected: displayMode == .overview) {
                displayMode = .overview
            }
            ProductionChip(icon: "doc.text", "Top Sheet", selected: displayMode == .topSheet) {
                displayMode = .topSheet
            }
            ProductionChip(icon: "tablecells", "Cost Report", selected: displayMode == .costReport) {
                displayMode = .costReport
            }
            ProductionChip(icon: "receipt", "Expenses", selected: displayMode == .expenses) {
                displayMode = .expenses
            }
            ProductionChip(icon: "doc.plaintext", "Purchase Orders", selected: displayMode == .purchaseOrders) {
                displayMode = .purchaseOrders
            }
            ProductionChip(icon: "person.2", "Payroll", selected: displayMode == .payroll) {
                displayMode = .payroll
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            ProductionChip(icon: "square.and.arrow.up", "Export", selected: displayMode == .export) {
                displayMode = .export
            }

            Spacer()

            switch displayMode {
            case .topSheet:
                ProductionActionButton(icon: "plus", "Add Category", prominent: true) {
                    showingAddCategorySheet = true
                }
            case .expenses:
                ProductionActionButton(icon: "plus", "Add Expense", prominent: true) {
                    showingAddExpenseSheet = true
                }
            case .purchaseOrders:
                ProductionActionButton(icon: "plus", "New PO", prominent: true) {
                    showingAddPOSheet = true
                }
            default:
                EmptyView()
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Overview

    private var accountingOverviewView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top stat badges row 1
                HStack(spacing: 12) {
                    ProductionStatBadge(
                        currencyValue: viewModel.budget.totalBudget,
                        label: "Total Budget",
                        color: .blue
                    )
                    ProductionStatBadge(
                        currencyValue: viewModel.totalExpenses,
                        label: "Total Spent",
                        color: .orange
                    )
                    ProductionStatBadge(
                        currencyValue: viewModel.totalCommitted,
                        label: "Committed",
                        color: .purple
                    )
                    ProductionStatBadge(
                        currencyValue: viewModel.budget.totalBudget - viewModel.totalExpenses - viewModel.totalCommitted,
                        label: "Remaining",
                        color: (viewModel.budget.totalBudget - viewModel.totalExpenses - viewModel.totalCommitted) >= 0 ? .green : .red
                    )
                }

                // Row 2
                HStack(spacing: 12) {
                    ProductionStatBadge(
                        currencyValue: viewModel.dailyBurnRate,
                        label: "Daily Burn",
                        color: .orange
                    )
                    ProductionStatBadge(
                        currencyValue: viewModel.totalProjectedCost,
                        label: "Projected",
                        color: .blue
                    )
                    let variance = viewModel.budget.totalBudget - viewModel.totalProjectedCost
                    ProductionStatBadge(
                        currencyValue: variance,
                        label: "Variance",
                        color: variance >= 0 ? .green : .red
                    )
                    ProductionStatBadge(
                        currencyValue: viewModel.contingencyAmount,
                        label: "Contingency",
                        color: .gray
                    )
                }

                // Budget Progress
                ProductionCard(icon: "chart.bar", title: "BUDGET PROGRESS") {
                    VStack(spacing: 10) {
                        let percentage = viewModel.spendingPercentage

                        ProductionProgressBar(
                            value: min(percentage / 100, 1.0),
                            color: percentage > 100 ? .red : (percentage > 80 ? .orange : .green)
                        )

                        HStack {
                            Text("\(String(format: "%.1f", percentage))% of budget used")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatCurrency(viewModel.totalExpenses))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(percentage > 100 ? .red : .primary)
                            Text("of \(formatCurrency(viewModel.budget.totalBudget))")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 2-column: Department + Recent Activity
                HStack(alignment: .top, spacing: 16) {
                    ProductionCard(icon: "chart.bar.xaxis", title: "SPENDING BY DEPARTMENT") {
                        departmentBreakdownSection
                    }

                    ProductionCard(icon: "clock", title: "RECENT ACTIVITY") {
                        recentActivitySection
                    }
                }

                // Cost by Scene
                ProductionCard(icon: "film", title: "COST BY SCENE") {
                    costBySceneSection
                }
            }
            .padding(16)
        }
    }

    private var departmentBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            let departments = viewModel.spendingByDepartment().prefix(10)
            if departments.isEmpty {
                Text("No spending data yet")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                let maxSpent = departments.map { $0.spent + $0.committed }.max() ?? 1
                ForEach(Array(departments), id: \.department) { item in
                    HStack(spacing: 8) {
                        Text(item.department)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 100, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { geo in
                            let total = item.spent + item.committed
                            let width = maxSpent > 0 ? CGFloat(total / maxSpent) * geo.size.width : 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor.opacity(0.7))
                                .frame(width: min(width, geo.size.width), height: 14)
                        }
                        .frame(height: 14)

                        Text(formatCurrency(item.spent + item.committed))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            let recentExpenses = viewModel.budget.expenses.sorted { $0.date > $1.date }.prefix(3)
            let recentPOs = viewModel.budget.purchaseOrders.sorted { $0.dateCreated > $1.dateCreated }.prefix(3)

            if recentExpenses.isEmpty && recentPOs.isEmpty {
                Text("No recent activity")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(Array(recentPOs), id: \.id) { po in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.plaintext")
                            .font(.system(size: 9))
                            .foregroundColor(.purple)
                        Text("\(po.poNumber) \(po.status.lowercased())")
                            .font(.system(size: 10))
                            .lineLimit(1)
                        Spacer()
                        Text(formatCurrency(po.amount))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .padding(.vertical, 2)
                }
                ForEach(Array(recentExpenses), id: \.id) { expense in
                    HStack(spacing: 6) {
                        Image(systemName: "receipt")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text(expense.description)
                            .font(.system(size: 10))
                            .lineLimit(1)
                        Spacer()
                        Text(formatCurrency(expense.amount))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var costBySceneSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            let scenes = viewModel.costByScene().prefix(10)
            if scenes.isEmpty {
                Text("No scene cost data — add schedule items with costs")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(Array(scenes), id: \.sceneName) { scene in
                    HStack(spacing: 8) {
                        Text(scene.sceneName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .frame(minWidth: 120, alignment: .leading)

                        HStack(spacing: 4) {
                            Text("est:")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(scene.estimated))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }

                        HStack(spacing: 4) {
                            Text("actual:")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(scene.actual))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(scene.actual > scene.estimated && scene.estimated > 0 ? .red : .primary)
                        }

                        Spacer()

                        if scene.estimated > 0 {
                            let isOver = scene.actual > scene.estimated
                            Image(systemName: isOver ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(isOver ? .orange : .green)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    // MARK: - Top Sheet

    private var topSheetView: some View {
        ScrollView {
            VStack(spacing: 20) {
                topSheetGroup(title: "ABOVE THE LINE", group: "ATL", icon: "star")
                topSheetGroup(title: "BELOW THE LINE — PRODUCTION", group: "BTL", icon: "hammer")
                topSheetGroup(title: "POST-PRODUCTION", group: "Post", icon: "film.stack")
                topSheetGroup(title: "OTHER", group: "Other", icon: "ellipsis.circle")

                // Grand Total
                ProductionCard(icon: "sum", title: "GRAND TOTAL") {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatCurrency(viewModel.totalAllocated))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.accentColor)
                            Text("Total Allocated")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.8)
                        }
                        Spacer()
                        Divider().frame(height: 30)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatCurrency(viewModel.totalExpenses))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                            Text("Total Spent")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.8)
                        }
                        Spacer()
                        Divider().frame(height: 30)
                        Spacer()
                        let totalVariance = viewModel.totalAllocated - viewModel.totalExpenses
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatCurrency(totalVariance))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(totalVariance >= 0 ? .green : .red)
                            Text("Variance")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.8)
                        }
                        Spacer()
                    }
                }
            }
            .padding(16)
        }
    }

    private func topSheetGroup(title: String, group: String, icon: String) -> some View {
        ProductionCard(icon: icon, title: title) {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("Account")
                        .frame(width: 60, alignment: .leading)
                    Text("Description")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Allocated")
                        .frame(width: 100, alignment: .trailing)
                    Text("Spent")
                        .frame(width: 100, alignment: .trailing)
                    Text("Variance")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.vertical, 6)

                Divider()

                let categories = viewModel.categoriesForGroup(group)
                if categories.isEmpty {
                    Text("No categories in this group")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(categories, id: \.name) { category in
                        topSheetRow(category: category)
                            .onTapGesture {
                                selectedCategory = category
                            }
                            .onTapGesture(count: 2) {
                                selectedCategory = category
                                showingEditCategorySheet = true
                            }
                    }
                }

                Divider()

                // Group total
                let allocatedTotal = viewModel.groupTotal(allocated: true, for: group)
                let spentTotal = viewModel.groupTotal(allocated: false, for: group)
                let groupVariance = allocatedTotal - spentTotal
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 60, alignment: .leading)
                    Text("\(group) TOTAL")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatCurrency(allocatedTotal))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .frame(width: 100, alignment: .trailing)
                    Text(formatCurrency(spentTotal))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .frame(width: 100, alignment: .trailing)
                    Text(formatCurrency(groupVariance))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(groupVariance >= 0 ? .green : .red)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func topSheetRow(category: BudgetCategory) -> some View {
        let variance = category.allocated - category.spent
        return HStack(spacing: 0) {
            Text(category.accountCode)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(category.name)
                .font(.system(size: 11))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatCurrency(category.allocated))
                .font(.system(size: 11, design: .rounded))
                .frame(width: 100, alignment: .trailing)
            Text(formatCurrency(category.spent))
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(category.spent > category.allocated ? .red : .primary)
                .frame(width: 100, alignment: .trailing)
            Text(formatCurrency(variance))
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(variance >= 0 ? .green : .red)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(selectedCategory?.name == category.name ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }

    // MARK: - Cost Report

    private var costReportView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProductionCard(icon: "tablecells", title: "COST REPORT") {
                    VStack(spacing: 0) {
                        // Header
                        HStack(spacing: 0) {
                            Text("Account")
                                .frame(width: 55, alignment: .leading)
                            Text("Description")
                                .frame(width: 110, alignment: .leading)
                            Text("This Week")
                                .frame(width: 80, alignment: .trailing)
                            Text("To Date")
                                .frame(width: 80, alignment: .trailing)
                            Text("Committed")
                                .frame(width: 80, alignment: .trailing)
                            Text("Total")
                                .frame(width: 80, alignment: .trailing)
                            Text("ETC")
                                .frame(width: 80, alignment: .trailing)
                            Text("EFC")
                                .frame(width: 80, alignment: .trailing)
                            Text("Budget")
                                .frame(width: 80, alignment: .trailing)
                            Text("Variance")
                                .frame(width: 80, alignment: .trailing)
                        }
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)

                        Divider()

                        let rows = viewModel.costReportData()
                        if rows.isEmpty {
                            Text("No cost data — add budget categories and expenses")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(rows) { row in
                                costReportRow(row)
                            }

                            Divider()

                            // Totals row
                            let totalThisWeek = rows.reduce(0) { $0 + $1.thisWeek }
                            let totalToDate = rows.reduce(0) { $0 + $1.toDate }
                            let totalCommitted = rows.reduce(0) { $0 + $1.committed }
                            let totalTotal = rows.reduce(0) { $0 + $1.total }
                            let totalETC = rows.reduce(0) { $0 + $1.etc }
                            let totalEFC = rows.reduce(0) { $0 + $1.efc }
                            let totalBudget = rows.reduce(0) { $0 + $1.budget }
                            let totalVariance = rows.reduce(0) { $0 + $1.variance }

                            HStack(spacing: 0) {
                                Text("")
                                    .frame(width: 55, alignment: .leading)
                                Text("TOTAL")
                                    .font(.system(size: 10, weight: .bold))
                                    .frame(width: 110, alignment: .leading)
                                costCell(totalThisWeek, width: 80, bold: true)
                                costCell(totalToDate, width: 80, bold: true)
                                costCell(totalCommitted, width: 80, bold: true)
                                costCell(totalTotal, width: 80, bold: true)
                                costCell(totalETC, width: 80, bold: true)
                                costCell(totalEFC, width: 80, bold: true)
                                costCell(totalBudget, width: 80, bold: true)
                                costCell(totalVariance, width: 80, bold: true, colored: true)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func costReportRow(_ row: CostReportRow) -> some View {
        HStack(spacing: 0) {
            Text(row.accountCode)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 55, alignment: .leading)
            Text(row.description)
                .font(.system(size: 10))
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
            costCell(row.thisWeek, width: 80)
            costCell(row.toDate, width: 80)
            costCell(row.committed, width: 80)
            costCell(row.total, width: 80)
            costCell(row.etc, width: 80)
            costCell(row.efc, width: 80)
            costCell(row.budget, width: 80)
            costCell(row.variance, width: 80, colored: true)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
    }

    private func costCell(_ value: Double, width: CGFloat, bold: Bool = false, colored: Bool = false) -> some View {
        Text(value == 0 ? "-" : formatCompact(value))
            .font(.system(size: 9, weight: bold ? .bold : .regular, design: .rounded))
            .foregroundColor(colored ? (value >= 0 ? .green : .red) : .primary)
            .frame(width: width, alignment: .trailing)
    }

    // MARK: - Expenses

    private var expensesView: some View {
        VStack(spacing: 0) {
            // Department filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ProductionChip("All", selected: expenseDeptFilter == "All") {
                        expenseDeptFilter = "All"
                    }
                    let departments = Set(viewModel.budget.expenses.map { $0.department }.filter { !$0.isEmpty })
                    ForEach(Array(departments).sorted(), id: \.self) { dept in
                        ProductionChip(dept, selected: expenseDeptFilter == dept) {
                            expenseDeptFilter = dept
                        }
                    }
                    // Also show category-based filter
                    let categories = Set(viewModel.budget.expenses.map { $0.category }.filter { !$0.isEmpty })
                    ForEach(Array(categories).sorted(), id: \.self) { cat in
                        if !departments.contains(cat) {
                            ProductionChip(cat, selected: expenseDeptFilter == cat) {
                                expenseDeptFilter = cat
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            HStack(spacing: 16) {
                ProductionCard(icon: "receipt", title: "EXPENSES") {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            ProductionStatBadge(
                                intValue: filteredExpenses.count,
                                label: "Total",
                                color: .blue
                            )
                            ProductionStatBadge(
                                currencyValue: filteredExpenses.reduce(0) { $0 + $1.amount },
                                label: "Total Amount",
                                color: .orange
                            )
                        }

                        HStack(spacing: 6) {
                            ProductionActionButton(icon: "plus", "Add", prominent: true) {
                                showingAddExpenseSheet = true
                            }
                            ProductionActionButton(icon: "pencil", "Edit", disabled: selectedExpense == nil) {
                                showingEditExpenseSheet = true
                            }
                            ProductionActionButton(icon: "trash", "Delete", disabled: selectedExpense == nil) {
                                if let expense = selectedExpense {
                                    viewModel.removeExpense(expense)
                                    selectedExpense = nil
                                }
                            }
                            Spacer()
                        }

                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredExpenses.sorted { $0.date > $1.date }) { expense in
                                    ExpenseListRow(expense: expense, isSelected: selectedExpense?.id == expense.id)
                                        .onTapGesture {
                                            selectedExpense = expense
                                        }
                                        .onTapGesture(count: 2) {
                                            selectedExpense = expense
                                            showingEditExpenseSheet = true
                                        }
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 450)

                ProductionCard(icon: "info.circle", title: "EXPENSE DETAILS") {
                    if let expense = selectedExpense {
                        expenseDetailView(expense)
                    } else {
                        Text("Select an expense to view details")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .padding(16)
        }
    }

    private var filteredExpenses: [Expense] {
        if expenseDeptFilter == "All" {
            return viewModel.budget.expenses
        }
        return viewModel.budget.expenses.filter {
            $0.department == expenseDeptFilter || $0.category == expenseDeptFilter
        }
    }

    private func expenseDetailView(_ expense: Expense) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(expense.description)
                .font(.system(size: 14, weight: .bold))

            Divider()

            detailRow(icon: "calendar", label: "Date", value: expense.date)
            detailRow(icon: "folder", label: "Category", value: expense.category)
            detailRow(icon: "dollarsign.circle", label: "Amount", value: formatCurrency(expense.amount))

            if !expense.vendor.isEmpty {
                detailRow(icon: "building.2", label: "Vendor", value: expense.vendor)
            }
            if !expense.department.isEmpty {
                detailRow(icon: "person.3", label: "Department", value: expense.department)
            }
            if !expense.accountCode.isEmpty {
                detailRow(icon: "number", label: "Account", value: expense.accountCode)
            }
            if !expense.paymentMethod.isEmpty {
                detailRow(icon: "creditcard", label: "Payment", value: expense.paymentMethod)
            }

            // Status badge
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                    .frame(width: 14)
                Text("Status:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                statusBadge(expense.status, color: expense.status == "Paid" ? .green : (expense.status == "Approved" ? .blue : .orange))
            }

            if expense.isQualifyingExpense {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("Tax Qualifying Expense")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
            }

            if let poId = expense.purchaseOrderId,
               let po = viewModel.budget.purchaseOrders.first(where: { $0.id == poId }) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                    Text("PO: \(po.poNumber)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.purple)
                }
            }

            // Receipt preview
            if let receiptPath = expense.receiptPath, !receiptPath.isEmpty {
                Divider()
                receiptPreviewSection(receiptPath: receiptPath)
            }
        }
    }

    private func receiptPreviewSection(receiptPath: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text("Receipt")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            if let basePath = viewModel.projectBasePath {
                let fullPath = basePath.appendingPathComponent(receiptPath)
                if let image = NSImage(contentsOf: fullPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 150)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                        )
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        Text(URL(fileURLWithPath: receiptPath).lastPathComponent)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    NSWorkspace.shared.open(fullPath)
                } label: {
                    Label("Open in Preview", systemImage: "eye")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text(URL(fileURLWithPath: receiptPath).lastPathComponent)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Purchase Orders

    private var purchaseOrdersView: some View {
        VStack(spacing: 0) {
            // Status filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["All", "Draft", "Approved", "Committed", "Paid", "Cancelled"], id: \.self) { status in
                        ProductionChip(status, selected: poStatusFilter == status) {
                            poStatusFilter = status
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            HStack(spacing: 16) {
                ProductionCard(icon: "doc.plaintext", title: "PURCHASE ORDERS") {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            ProductionStatBadge(
                                intValue: filteredPOs.count,
                                label: "Total POs",
                                color: .blue
                            )
                            ProductionStatBadge(
                                currencyValue: filteredPOs.reduce(0) { $0 + $1.amount },
                                label: "Total Amount",
                                color: .purple
                            )
                        }

                        HStack(spacing: 6) {
                            ProductionActionButton(icon: "plus", "New PO", prominent: true) {
                                showingAddPOSheet = true
                            }
                            ProductionActionButton(icon: "pencil", "Edit", disabled: selectedPO == nil) {
                                showingEditPOSheet = true
                            }
                            ProductionActionButton(icon: "trash", "Delete", disabled: selectedPO == nil) {
                                if let po = selectedPO {
                                    viewModel.removePurchaseOrder(po)
                                    selectedPO = nil
                                }
                            }
                            Spacer()
                        }

                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredPOs.sorted { $0.dateCreated > $1.dateCreated }) { po in
                                    POListRow(po: po, isSelected: selectedPO?.id == po.id)
                                        .onTapGesture {
                                            selectedPO = po
                                        }
                                        .onTapGesture(count: 2) {
                                            selectedPO = po
                                            showingEditPOSheet = true
                                        }
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 450)

                ProductionCard(icon: "info.circle", title: "PO DETAILS") {
                    if let po = selectedPO {
                        poDetailView(po)
                    } else {
                        Text("Select a purchase order to view details")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .padding(16)
        }
    }

    private var filteredPOs: [PurchaseOrder] {
        viewModel.purchaseOrders(forStatus: poStatusFilter)
    }

    private func poDetailView(_ po: PurchaseOrder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(po.poNumber)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                statusBadge(po.status, color: poStatusColor(po.status))
            }

            Text(po.description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            detailRow(icon: "building.2", label: "Vendor", value: po.vendor)
            detailRow(icon: "person.3", label: "Department", value: po.department)
            detailRow(icon: "number", label: "Account", value: po.accountCode)
            detailRow(icon: "dollarsign.circle", label: "Amount", value: formatCurrency(po.amount))
            detailRow(icon: "calendar", label: "Created", value: po.dateCreated)

            if let approved = po.dateApproved {
                detailRow(icon: "checkmark.circle", label: "Approved", value: approved)
            }
            if let paid = po.datePaid {
                detailRow(icon: "banknote", label: "Paid", value: paid)
            }
            if !po.approvedBy.isEmpty {
                detailRow(icon: "person", label: "Approved By", value: po.approvedBy)
            }
            if !po.notes.isEmpty {
                detailRow(icon: "note.text", label: "Notes", value: po.notes)
            }

            Spacer()

            // Status change buttons
            HStack(spacing: 6) {
                if po.status == "Draft" {
                    ProductionActionButton(icon: "checkmark", "Approve", prominent: true) {
                        var updated = po
                        updated.status = "Approved"
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        updated.dateApproved = formatter.string(from: Date())
                        viewModel.updatePurchaseOrder(updated)
                        selectedPO = updated
                    }
                }
                if po.status == "Approved" {
                    ProductionActionButton(icon: "arrow.right", "Commit") {
                        var updated = po
                        updated.status = "Committed"
                        viewModel.updatePurchaseOrder(updated)
                        selectedPO = updated
                    }
                }
                if po.status == "Approved" || po.status == "Committed" {
                    ProductionActionButton(icon: "banknote", "Mark Paid", prominent: true) {
                        var updated = po
                        updated.status = "Paid"
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        updated.datePaid = formatter.string(from: Date())
                        viewModel.updatePurchaseOrder(updated)
                        selectedPO = updated
                    }
                }
                if po.status != "Cancelled" && po.status != "Paid" {
                    ProductionActionButton(icon: "xmark", "Cancel") {
                        var updated = po
                        updated.status = "Cancelled"
                        viewModel.updatePurchaseOrder(updated)
                        selectedPO = updated
                    }
                }
            }
        }
    }

    // MARK: - Payroll

    private var payrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary stats
                HStack(spacing: 12) {
                    ProductionStatBadge(
                        currencyValue: viewModel.projectedCastPayroll + viewModel.projectedCastFringes,
                        label: "Cast Total",
                        color: .blue
                    )
                    ProductionStatBadge(
                        currencyValue: viewModel.projectedCrewPayroll + viewModel.projectedCrewFringes,
                        label: "Crew Total",
                        color: .purple
                    )
                    ProductionStatBadge(
                        currencyValue: viewModel.projectedEquipmentRental,
                        label: "Equipment",
                        color: .orange
                    )
                    let grandTotal = viewModel.projectedCastPayroll + viewModel.projectedCastFringes +
                        viewModel.projectedCrewPayroll + viewModel.projectedCrewFringes +
                        viewModel.projectedEquipmentRental
                    ProductionStatBadge(
                        currencyValue: grandTotal,
                        label: "Grand Total",
                        color: .green
                    )
                }

                // Cast Payroll
                ProductionCard(icon: "theatermasks", title: "CAST PAYROLL PROJECTION") {
                    payrollTable(
                        headers: ["Actor", "Character", "Rate/Payment", "Days", "Fringes", "Total"],
                        widths: [nil, nil, 90, 50, 80, 90],
                        rows: viewModel.castMembers.map { cast in
                            if cast.paymentType == "One Time" {
                                let fringes = cast.oneTimePayment * viewModel.budget.fringeRate
                                return [
                                    cast.actorName,
                                    cast.characterName,
                                    formatCurrency(cast.oneTimePayment) + " (flat)",
                                    "—",
                                    formatCurrency(fringes),
                                    formatCurrency(cast.oneTimePayment + fringes)
                                ]
                            } else {
                                let days = castShootDays(cast)
                                let subtotal = cast.dailyRate * Double(days)
                                let fringes = subtotal * viewModel.budget.fringeRate
                                return [
                                    cast.actorName,
                                    cast.characterName,
                                    formatCurrency(cast.dailyRate) + "/day",
                                    "\(days)",
                                    formatCurrency(fringes),
                                    formatCurrency(subtotal + fringes)
                                ]
                            }
                        },
                        totalLabel: "CAST TOTAL",
                        totalValue: viewModel.projectedCastPayroll + viewModel.projectedCastFringes
                    )
                }

                // Crew Payroll
                ProductionCard(icon: "person.3", title: "CREW PAYROLL PROJECTION") {
                    payrollTable(
                        headers: ["Name", "Role", "Dept", "Rate/Payment", "Kit Fee", "Days", "Fringes", "Total"],
                        widths: [nil, nil, 70, 90, 60, 40, 70, 90],
                        rows: viewModel.crewMembers.map { crew in
                            if crew.paymentType == "One Time" {
                                let fringes = crew.oneTimePayment * viewModel.budget.fringeRate
                                return [
                                    crew.name,
                                    crew.role,
                                    crew.department,
                                    formatCurrency(crew.oneTimePayment) + " (flat)",
                                    "—",
                                    "—",
                                    formatCurrency(fringes),
                                    formatCurrency(crew.oneTimePayment + fringes)
                                ]
                            } else {
                                let days = crewShootDays(crew)
                                let subtotal = (crew.dailyRate + crew.kitFee) * Double(days)
                                let fringes = subtotal * viewModel.budget.fringeRate
                                return [
                                    crew.name,
                                    crew.role,
                                    crew.department,
                                    formatCurrency(crew.dailyRate) + "/day",
                                    formatCurrency(crew.kitFee),
                                    "\(days)",
                                    formatCurrency(fringes),
                                    formatCurrency(subtotal + fringes)
                                ]
                            }
                        },
                        totalLabel: "CREW TOTAL",
                        totalValue: viewModel.projectedCrewPayroll + viewModel.projectedCrewFringes
                    )
                }

                // Equipment Rental
                ProductionCard(icon: "camera", title: "EQUIPMENT RENTAL PROJECTION") {
                    payrollTable(
                        headers: ["Item", "Category", "Daily Rate", "Days", "Total"],
                        widths: [nil, nil, 80, 60, 90],
                        rows: viewModel.equipment.filter { $0.rentalDailyRate > 0 }.map { item in
                            let days = equipmentDays(item)
                            return [
                                item.name,
                                item.category,
                                formatCurrency(item.rentalDailyRate),
                                "\(days)",
                                formatCurrency(item.rentalDailyRate * Double(days))
                            ]
                        },
                        totalLabel: "EQUIPMENT TOTAL",
                        totalValue: viewModel.projectedEquipmentRental
                    )
                }

                // Fringe rate note
                ProductionCard(icon: "percent", title: "FRINGE RATE") {
                    HStack {
                        Text("Current fringe rate: \(String(format: "%.0f", viewModel.budget.fringeRate * 100))%")
                            .font(.system(size: 12))
                        Text("(includes employer taxes, benefits, P&W)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(16)
        }
    }

    private func payrollTable(headers: [String], widths: [CGFloat?], rows: [[String]], totalLabel: String, totalValue: Double) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                ForEach(Array(zip(headers.indices, headers)), id: \.0) { idx, header in
                    if let w = widths[idx] {
                        Text(header)
                            .frame(width: w, alignment: idx >= 2 ? .trailing : .leading)
                    } else {
                        Text(header)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.vertical, 6)

            Divider()

            if rows.isEmpty {
                Text("No data available")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(rows.indices), id: \.self) { rowIdx in
                    let row = rows[rowIdx]
                    HStack(spacing: 0) {
                        ForEach(Array(zip(row.indices, row)), id: \.0) { colIdx, cell in
                            if let w = widths[colIdx] {
                                Text(cell)
                                    .frame(width: w, alignment: colIdx >= 2 ? .trailing : .leading)
                            } else {
                                Text(cell)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .font(.system(size: 10))
                    .padding(.vertical, 3)
                }
            }

            Divider()

            // Total
            HStack {
                Spacer()
                Text(totalLabel)
                    .font(.system(size: 11, weight: .bold))
                Text(formatCurrency(totalValue))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Helpers

    private func castShootDays(_ cast: CastMember) -> Int {
        let matchingItems = viewModel.scheduleItems.filter { item in
            item.requiredActors.contains(cast.actorName) || item.requiredActors.contains(cast.characterName)
        }
        let uniqueDates = Set(matchingItems.compactMap { $0.shootDate }.filter { !$0.isEmpty })
        return max(uniqueDates.count, matchingItems.isEmpty ? 0 : 1)
    }

    private func crewShootDays(_ crew: CrewMember) -> Int {
        let matchingItems = viewModel.scheduleItems.filter { item in
            item.requiredCrew.contains(crew.name) || item.requiredCrew.contains(crew.role)
        }
        if matchingItems.isEmpty {
            return viewModel.totalShootDays
        }
        let uniqueDates = Set(matchingItems.compactMap { $0.shootDate }.filter { !$0.isEmpty })
        return max(uniqueDates.count, 1)
    }

    private func equipmentDays(_ item: EquipmentItem) -> Int {
        let allocs = viewModel.equipmentAllocations.filter { $0.equipmentItemId == item.id }
        if allocs.isEmpty { return 0 }
        var totalDays = 0
        for alloc in allocs {
            if alloc.allocationMode == .fullProduction {
                totalDays += viewModel.totalShootDays * alloc.quantityAllocated
            } else {
                totalDays += alloc.allocatedDates.count * alloc.quantityAllocated
            }
        }
        return totalDays
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
                .frame(width: 14)
            Text(label + ":")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11))
        }
    }

    private func statusBadge(_ status: String, color: Color) -> some View {
        Text(status)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
            )
            .foregroundColor(color)
    }

    private func poStatusColor(_ status: String) -> Color {
        switch status {
        case "Draft": return .gray
        case "Approved": return .blue
        case "Committed": return .purple
        case "Paid": return .green
        case "Cancelled": return .red
        default: return .gray
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.budget.currency
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func formatCompact(_ value: Double) -> String {
        if abs(value) >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if abs(value) >= 1_000 {
            return String(format: "$%.1fK", value / 1_000)
        } else {
            return formatCurrency(value)
        }
    }

    // MARK: - Export View

    private var exportView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status banner
                if let status = exportStatus {
                    HStack(spacing: 8) {
                        Image(systemName: status.hasPrefix("Error") ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text(status)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Button(action: { exportStatus = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(status.hasPrefix("Error") ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                    )
                    .foregroundColor(status.hasPrefix("Error") ? .red : .green)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation { exportStatus = nil }
                        }
                    }
                }

                // Two-column layout: Filters left, Export right
                HStack(alignment: .top, spacing: 16) {
                    // LEFT COLUMN: Filters
                    VStack(spacing: 12) {
                        exportFiltersCard
                    }
                    .frame(minWidth: 280, maxWidth: 360)

                    // RIGHT COLUMN: Summary + Formats
                    VStack(spacing: 12) {
                        exportFilteredSummaryCard
                        exportFormatsCard
                    }
                }
            }
            .padding(16)
        }
        .animation(.easeInOut(duration: 0.3), value: exportStatus)
    }

    // MARK: - Export Filters Card

    private var exportFiltersCard: some View {
        ProductionCard(icon: "line.3.horizontal.decrease.circle", title: "FILTERS") {
            VStack(alignment: .leading, spacing: 16) {
                // Date Range
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                        Text("DATE RANGE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.0)
                    }

                    // Preset chips
                    let datePresets: [(id: String, label: String)] = [
                        ("allTime", "All Time"),
                        ("thisWeek", "This Week"),
                        ("thisMonth", "This Month"),
                        ("thisQuarter", "This Quarter"),
                        ("custom", "Custom")
                    ]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 4)], spacing: 4) {
                        ForEach(datePresets, id: \.id) { preset in
                            exportFilterChip(preset.label, selected: exportDatePreset == preset.id) {
                                exportDatePreset = preset.id
                            }
                        }
                    }

                    if exportDatePreset == "custom" {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("From")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $exportCustomDateFrom, displayedComponents: .date)
                                    .datePickerStyle(.field)
                                    .labelsHidden()
                                    .font(.system(size: 11))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("To")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $exportCustomDateTo, displayedComponents: .date)
                                    .datePickerStyle(.field)
                                    .labelsHidden()
                                    .font(.system(size: 11))
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Department filter
                if !exportAvailableDepartments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2")
                                .font(.system(size: 10))
                                .foregroundColor(.accentColor)
                            Text("DEPARTMENT")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(1.0)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 4)], spacing: 4) {
                            exportFilterChip("All", selected: exportSelectedDepartments.isEmpty) {
                                exportSelectedDepartments.removeAll()
                            }
                            ForEach(exportAvailableDepartments, id: \.self) { dept in
                                exportFilterChip(dept, selected: exportSelectedDepartments.contains(dept)) {
                                    if exportSelectedDepartments.contains(dept) {
                                        exportSelectedDepartments.remove(dept)
                                    } else {
                                        exportSelectedDepartments.insert(dept)
                                    }
                                }
                            }
                        }
                    }

                    Divider().opacity(0.5)
                }

                // Category Group filter
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                        Text("CATEGORY GROUP")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.0)
                    }
                    HStack(spacing: 4) {
                        exportFilterChip("All", selected: exportSelectedGroups.isEmpty) {
                            exportSelectedGroups.removeAll()
                        }
                        ForEach(["ATL", "BTL", "Post", "Other"], id: \.self) { group in
                            exportFilterChip(group, selected: exportSelectedGroups.contains(group)) {
                                if exportSelectedGroups.contains(group) {
                                    exportSelectedGroups.remove(group)
                                } else {
                                    exportSelectedGroups.insert(group)
                                }
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Expense Status filter
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                        Text("EXPENSE STATUS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.0)
                    }
                    HStack(spacing: 4) {
                        exportFilterChip("All", selected: exportSelectedExpenseStatuses.isEmpty) {
                            exportSelectedExpenseStatuses.removeAll()
                        }
                        ForEach(["Pending", "Approved", "Paid"], id: \.self) { s in
                            exportFilterChip(s, selected: exportSelectedExpenseStatuses.contains(s)) {
                                if exportSelectedExpenseStatuses.contains(s) {
                                    exportSelectedExpenseStatuses.remove(s)
                                } else {
                                    exportSelectedExpenseStatuses.insert(s)
                                }
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // PO Status filter
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.plaintext")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                        Text("PO STATUS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.0)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 65), spacing: 4)], spacing: 4) {
                        exportFilterChip("All", selected: exportSelectedPOStatuses.isEmpty) {
                            exportSelectedPOStatuses.removeAll()
                        }
                        ForEach(["Draft", "Approved", "Committed", "Paid", "Cancelled"], id: \.self) { s in
                            exportFilterChip(s, selected: exportSelectedPOStatuses.contains(s)) {
                                if exportSelectedPOStatuses.contains(s) {
                                    exportSelectedPOStatuses.remove(s)
                                } else {
                                    exportSelectedPOStatuses.insert(s)
                                }
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Payment Method filter
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                        Text("PAYMENT METHOD")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.0)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 65), spacing: 4)], spacing: 4) {
                        exportFilterChip("All", selected: exportSelectedPaymentMethods.isEmpty) {
                            exportSelectedPaymentMethods.removeAll()
                        }
                        ForEach(["Card", "Check", "PettyCash", "Wire", "PO"], id: \.self) { m in
                            exportFilterChip(m, selected: exportSelectedPaymentMethods.contains(m)) {
                                if exportSelectedPaymentMethods.contains(m) {
                                    exportSelectedPaymentMethods.remove(m)
                                } else {
                                    exportSelectedPaymentMethods.insert(m)
                                }
                            }
                        }
                    }
                }

                Divider().opacity(0.5)

                // Amount Range
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                        Text("AMOUNT RANGE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.0)
                    }
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("Min")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            TextField("$0", text: $exportMinAmount)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(nsColor: .quaternarySystemFill))
                                )
                                .frame(width: 70)
                        }
                        HStack(spacing: 4) {
                            Text("Max")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            TextField("No limit", text: $exportMaxAmount)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(nsColor: .quaternarySystemFill))
                                )
                                .frame(width: 70)
                        }
                    }
                }

                // Reset filters button
                if hasActiveFilters {
                    HStack {
                        Spacer()
                        Button(action: resetExportFilters) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10))
                                Text("Reset All Filters")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Export Filtered Summary

    private var exportFilteredSummaryCard: some View {
        ProductionCard(icon: "chart.bar.doc.horizontal", title: "FILTERED DATA SUMMARY") {
            VStack(spacing: 10) {
                // Stat badges row
                HStack(spacing: 8) {
                    exportMiniStat(
                        value: "\(exportFilteredExpenses.count)",
                        label: "Expenses",
                        detail: formatCompact(exportFilteredExpenses.reduce(0) { $0 + $1.amount }),
                        color: .orange
                    )
                    exportMiniStat(
                        value: "\(filteredPurchaseOrders.count)",
                        label: "POs",
                        detail: formatCompact(filteredPurchaseOrders.reduce(0) { $0 + $1.amount }),
                        color: .purple
                    )
                    exportMiniStat(
                        value: "\(filteredCategories.count)",
                        label: "Categories",
                        detail: "\(Set(filteredCategories.map { $0.categoryGroup }).count) groups",
                        color: .blue
                    )
                    exportMiniStat(
                        value: "\(viewModel.castMembers.count + viewModel.crewMembers.count)",
                        label: "Cast & Crew",
                        detail: formatCompact(viewModel.projectedCastPayroll + viewModel.projectedCrewPayroll),
                        color: .green
                    )
                }

                if hasActiveFilters {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("Filters active")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                        Text("—")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(exportFilteredExpenses.count) of \(viewModel.budget.expenses.count) expenses, \(filteredPurchaseOrders.count) of \(viewModel.budget.purchaseOrders.count) POs")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                Divider().opacity(0.5)

                // Detailed breakdown rows
                exportSummaryRow(icon: "folder", label: "Budget Categories", value: "\(filteredCategories.count) categories across \(Set(filteredCategories.map { $0.categoryGroup }).count) groups")
                exportSummaryRow(icon: "receipt", label: "Expenses", value: "\(exportFilteredExpenses.count) entries totaling \(formatCurrency(exportFilteredExpenses.reduce(0) { $0 + $1.amount }))")
                exportSummaryRow(icon: "doc.plaintext", label: "Purchase Orders", value: "\(filteredPurchaseOrders.count) POs totaling \(formatCurrency(filteredPurchaseOrders.reduce(0) { $0 + $1.amount }))")
                exportSummaryRow(icon: "person.fill", label: "Cast Payroll", value: "\(viewModel.castMembers.count) members, projected \(formatCurrency(viewModel.projectedCastPayroll))")
                exportSummaryRow(icon: "person.2.fill", label: "Crew Payroll", value: "\(viewModel.crewMembers.count) members, projected \(formatCurrency(viewModel.projectedCrewPayroll))")
                exportSummaryRow(icon: "tablecells", label: "Cost Report", value: "\(filteredCostReport.count) line items")
            }
        }
    }

    // MARK: - Export Formats Card

    private var exportFormatsCard: some View {
        ProductionCard(icon: "square.and.arrow.up", title: "EXPORT FORMATS") {
            VStack(spacing: 0) {
                exportFormatRow(
                    icon: "tablecells",
                    iconColor: .green,
                    name: "CSV / Excel",
                    fileExt: ".csv",
                    badgeColor: .green,
                    description: "Universal spreadsheet — all sections in one file",
                    recordCount: "\(exportFilteredExpenses.count + filteredPurchaseOrders.count + filteredCategories.count) records",
                    action: exportCSV
                )

                exportFormatDivider

                exportFormatRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .cyan,
                    name: "Xero CSV",
                    fileExt: ".csv",
                    badgeColor: .cyan,
                    description: "Xero accounting import with invoice numbers",
                    recordCount: "\(exportFilteredExpenses.count) invoices",
                    action: exportXeroCSV
                )

                exportFormatDivider

                exportFormatRow(
                    icon: "doc.text.below.ecg",
                    iconColor: .orange,
                    name: "Tally XML",
                    fileExt: ".xml",
                    badgeColor: .orange,
                    description: "Payment vouchers with ledger entries",
                    recordCount: "\(exportFilteredExpenses.count) vouchers",
                    action: exportTallyXML
                )

            }
        }
    }

    // MARK: - Export Helpers

    private var exportFormatDivider: some View {
        Divider().opacity(0.3).padding(.vertical, 2)
    }

    private func exportFilterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                )
                .foregroundColor(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func exportMiniStat(value: String, label: String, detail: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(detail)
                .font(.system(size: 9))
                .foregroundColor(color.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.08))
        )
    }

    private func exportSummaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private func exportFormatRow(
        icon: String,
        iconColor: Color,
        name: String,
        fileExt: String,
        badgeColor: Color,
        description: String,
        recordCount: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            // Icon in colored circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
            }

            // Name + description
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(fileExt)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(badgeColor)
                        )
                }
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Record count
            Text(recordCount)
                .font(.system(size: 9))
                .foregroundColor(.secondary)

            // Export button
            Button(action: action) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(isExporting ? 0.4 : 0.8))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Filter Logic

    private var hasActiveFilters: Bool {
        exportDatePreset != "allTime" ||
        !exportSelectedDepartments.isEmpty ||
        !exportSelectedGroups.isEmpty ||
        !exportSelectedExpenseStatuses.isEmpty ||
        !exportSelectedPOStatuses.isEmpty ||
        !exportSelectedPaymentMethods.isEmpty ||
        !exportMinAmount.isEmpty ||
        !exportMaxAmount.isEmpty
    }

    private func resetExportFilters() {
        exportDatePreset = "allTime"
        exportSelectedDepartments.removeAll()
        exportSelectedGroups.removeAll()
        exportSelectedExpenseStatuses.removeAll()
        exportSelectedPOStatuses.removeAll()
        exportSelectedPaymentMethods.removeAll()
        exportMinAmount = ""
        exportMaxAmount = ""
    }

    private var exportAvailableDepartments: [String] {
        var depts = Set<String>()
        for exp in viewModel.budget.expenses where !exp.department.isEmpty {
            depts.insert(exp.department)
        }
        for po in viewModel.budget.purchaseOrders where !po.department.isEmpty {
            depts.insert(po.department)
        }
        return depts.sorted()
    }

    private var exportDateRange: (from: String, to: String)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let now = Date()

        switch exportDatePreset {
        case "thisWeek":
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            return (formatter.string(from: weekStart), formatter.string(from: now))
        case "thisMonth":
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (formatter.string(from: monthStart), formatter.string(from: now))
        case "thisQuarter":
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var comps = calendar.dateComponents([.year], from: now)
            comps.month = quarterStartMonth
            comps.day = 1
            let quarterStart = calendar.date(from: comps) ?? now
            return (formatter.string(from: quarterStart), formatter.string(from: now))
        case "custom":
            return (formatter.string(from: exportCustomDateFrom), formatter.string(from: exportCustomDateTo))
        default:
            return nil
        }
    }

    private var exportFilteredExpenses: [Expense] {
        var result = viewModel.budget.expenses

        if let range = exportDateRange {
            result = result.filter { $0.date >= range.from && $0.date <= range.to }
        }
        if !exportSelectedDepartments.isEmpty {
            result = result.filter { exportSelectedDepartments.contains($0.department) }
        }
        if !exportSelectedGroups.isEmpty {
            let groupCategories = Set(viewModel.budget.categories.filter { exportSelectedGroups.contains($0.categoryGroup) }.map { $0.name })
            result = result.filter { groupCategories.contains($0.category) }
        }
        if !exportSelectedExpenseStatuses.isEmpty {
            result = result.filter { exportSelectedExpenseStatuses.contains($0.status) }
        }
        if !exportSelectedPaymentMethods.isEmpty {
            result = result.filter { exportSelectedPaymentMethods.contains($0.paymentMethod) }
        }
        if let min = Double(exportMinAmount), min > 0 {
            result = result.filter { $0.amount >= min }
        }
        if let max = Double(exportMaxAmount), max > 0 {
            result = result.filter { $0.amount <= max }
        }
        return result
    }

    private var filteredPurchaseOrders: [PurchaseOrder] {
        var result = viewModel.budget.purchaseOrders

        if let range = exportDateRange {
            result = result.filter { $0.dateCreated >= range.from && $0.dateCreated <= range.to }
        }
        if !exportSelectedDepartments.isEmpty {
            result = result.filter { exportSelectedDepartments.contains($0.department) }
        }
        if !exportSelectedPOStatuses.isEmpty {
            result = result.filter { exportSelectedPOStatuses.contains($0.status) }
        }
        if let min = Double(exportMinAmount), min > 0 {
            result = result.filter { $0.amount >= min }
        }
        if let max = Double(exportMaxAmount), max > 0 {
            result = result.filter { $0.amount <= max }
        }
        return result
    }

    private var filteredCategories: [BudgetCategory] {
        if exportSelectedGroups.isEmpty {
            return viewModel.budget.categories
        }
        return viewModel.budget.categories.filter { exportSelectedGroups.contains($0.categoryGroup) }
    }

    private var filteredCostReport: [CostReportRow] {
        let allRows = viewModel.costReportData()
        if exportSelectedGroups.isEmpty { return allRows }
        let groupCategories = Set(filteredCategories.map { $0.name })
        return allRows.filter { groupCategories.contains($0.description) }
    }

    // MARK: - Save to File

    private func saveToFile(content: String, defaultName: String, title: String, contentType: UTType) {
        isExporting = true
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true

        panel.begin { response in
            DispatchQueue.main.async {
                isExporting = false
                guard response == .OK, let url = panel.url else { return }
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    withAnimation { exportStatus = "Exported successfully to \(url.lastPathComponent)" }
                } catch {
                    withAnimation { exportStatus = "Error: \(error.localizedDescription)" }
                }
            }
        }
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - Export: CSV/Excel

    private func exportCSV() {
        var lines: [String] = []

        // Section 1: Budget Summary
        lines.append("=== BUDGET SUMMARY ===")
        lines.append("AccountCode,Category,Group,Allocated,Spent,Remaining,Variance%")
        for cat in filteredCategories {
            let variancePct = cat.allocated > 0 ? String(format: "%.1f", ((cat.spent - cat.allocated) / cat.allocated) * 100) : "0.0"
            lines.append("\(escapeCSV(cat.accountCode)),\(escapeCSV(cat.name)),\(escapeCSV(cat.categoryGroup)),\(String(format: "%.2f", cat.allocated)),\(String(format: "%.2f", cat.spent)),\(String(format: "%.2f", cat.remaining)),\(variancePct)")
        }
        lines.append("")

        // Section 2: Expenses
        lines.append("=== EXPENSES ===")
        lines.append("Date,Description,Category,Amount,Vendor,Department,AccountCode,PaymentMethod,Status")
        for exp in exportFilteredExpenses {
            lines.append("\(escapeCSV(exp.date)),\(escapeCSV(exp.description)),\(escapeCSV(exp.category)),\(String(format: "%.2f", exp.amount)),\(escapeCSV(exp.vendor)),\(escapeCSV(exp.department)),\(escapeCSV(exp.accountCode)),\(escapeCSV(exp.paymentMethod)),\(escapeCSV(exp.status))")
        }
        lines.append("")

        // Section 3: Purchase Orders
        lines.append("=== PURCHASE ORDERS ===")
        lines.append("PONumber,Vendor,Department,AccountCode,Description,Amount,Status,DateCreated,ApprovedBy")
        for po in filteredPurchaseOrders {
            lines.append("\(escapeCSV(po.poNumber)),\(escapeCSV(po.vendor)),\(escapeCSV(po.department)),\(escapeCSV(po.accountCode)),\(escapeCSV(po.description)),\(String(format: "%.2f", po.amount)),\(escapeCSV(po.status)),\(escapeCSV(po.dateCreated)),\(escapeCSV(po.approvedBy))")
        }
        lines.append("")

        // Section 4: Payroll
        lines.append("=== PAYROLL ===")
        lines.append("Name,Role,Type,DailyRate,PaymentType,ProjectedTotal")
        for cast in viewModel.castMembers {
            let projected = cast.paymentType == "One Time" ? cast.oneTimePayment : cast.dailyRate * Double(max(viewModel.totalShootDays, 1))
            lines.append("\(escapeCSV(cast.actorName)),\(escapeCSV(cast.characterName)),Cast,\(String(format: "%.2f", cast.dailyRate)),\(escapeCSV(cast.paymentType)),\(String(format: "%.2f", projected))")
        }
        for crew in viewModel.crewMembers {
            let projected = crew.paymentType == "One Time" ? crew.oneTimePayment : (crew.dailyRate + crew.kitFee) * Double(max(viewModel.totalShootDays, 1))
            lines.append("\(escapeCSV(crew.name)),\(escapeCSV(crew.role)),Crew,\(String(format: "%.2f", crew.dailyRate)),\(escapeCSV(crew.paymentType)),\(String(format: "%.2f", projected))")
        }
        lines.append("")

        // Section 5: Cost Report
        lines.append("=== COST REPORT ===")
        lines.append("AccountCode,Description,ThisWeek,ToDate,Committed,Total,ETC,EFC,Budget,Variance")
        for row in filteredCostReport {
            lines.append("\(escapeCSV(row.accountCode)),\(escapeCSV(row.description)),\(String(format: "%.2f", row.thisWeek)),\(String(format: "%.2f", row.toDate)),\(String(format: "%.2f", row.committed)),\(String(format: "%.2f", row.total)),\(String(format: "%.2f", row.etc)),\(String(format: "%.2f", row.efc)),\(String(format: "%.2f", row.budget)),\(String(format: "%.2f", row.variance))")
        }

        let content = lines.joined(separator: "\n")
        saveToFile(
            content: content,
            defaultName: "production_accounting_export.csv",
            title: "Export CSV/Excel",
            contentType: UTType.commaSeparatedText
        )
    }

    // MARK: - Export: Xero CSV

    private func exportXeroCSV() {
        var lines: [String] = []

        lines.append("ContactName,InvoiceNumber,InvoiceDate,DueDate,Description,Quantity,UnitAmount,AccountCode,TaxType")

        for (index, exp) in exportFilteredExpenses.enumerated() {
            let invoiceNumber = String(format: "DC-EXP-%04d", index + 1)
            let contactName = exp.vendor.isEmpty ? "Production" : exp.vendor
            let acctCode = exp.accountCode.isEmpty ? "400" : exp.accountCode
            lines.append("\(escapeCSV(contactName)),\(escapeCSV(invoiceNumber)),\(escapeCSV(exp.date)),\(escapeCSV(exp.date)),\(escapeCSV(exp.description)),1,\(String(format: "%.2f", exp.amount)),\(escapeCSV(acctCode)),Tax Exempt")
        }

        let content = lines.joined(separator: "\n")
        saveToFile(
            content: content,
            defaultName: "production_xero_import.csv",
            title: "Export Xero CSV",
            contentType: UTType.commaSeparatedText
        )
    }

    // MARK: - Export: Tally XML

    private func exportTallyXML() {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ENVELOPE>
            <HEADER>
                <TALLYREQUEST>Import Data</TALLYREQUEST>
            </HEADER>
            <BODY>
                <IMPORTDATA>
                    <REQUESTDESC>
                        <REPORTNAME>Vouchers</REPORTNAME>
                    </REQUESTDESC>
                    <REQUESTDATA>

        """

        for (index, exp) in exportFilteredExpenses.enumerated() {
            let tallyDate = exp.date.replacingOccurrences(of: "-", with: "")
            let category = exp.category.isEmpty ? "Production Expenses" : exp.category
            let voucherNum = String(format: "DC-PAY-%04d", index + 1)

            xml += """
                        <TALLYMESSAGE xmlns:UDF="TallyUDF">
                            <VOUCHER VCHTYPE="Payment" ACTION="Create">
                                <DATE>\(tallyDate)</DATE>
                                <VOUCHERTYPENAME>Payment</VOUCHERTYPENAME>
                                <VOUCHERNUMBER>\(voucherNum)</VOUCHERNUMBER>
                                <NARRATION>\(xmlEscape(exp.description))</NARRATION>
                                <ALLLEDGERENTRIES.LIST>
                                    <LEDGERNAME>\(xmlEscape(category))</LEDGERNAME>
                                    <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
                                    <AMOUNT>-\(String(format: "%.2f", exp.amount))</AMOUNT>
                                </ALLLEDGERENTRIES.LIST>
                                <ALLLEDGERENTRIES.LIST>
                                    <LEDGERNAME>Cash</LEDGERNAME>
                                    <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
                                    <AMOUNT>\(String(format: "%.2f", exp.amount))</AMOUNT>
                                </ALLLEDGERENTRIES.LIST>
                            </VOUCHER>
                        </TALLYMESSAGE>

            """
        }

        xml += """
                    </REQUESTDATA>
                </IMPORTDATA>
            </BODY>
        </ENVELOPE>
        """

        saveToFile(
            content: xml,
            defaultName: "production_tally_import.xml",
            title: "Export Tally XML",
            contentType: UTType.xml
        )
    }

}

// MARK: - Expense List Row

struct ExpenseListRow: View {
    let expense: Expense
    var isSelected: Bool = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(expense.date)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(expense.category)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.15))
                )
                .foregroundColor(.blue)

            if !expense.department.isEmpty {
                Text(expense.department)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple.opacity(0.15))
                    )
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(expense.description)
                    .font(.system(size: 11))
                    .lineLimit(1)
                if !expense.vendor.isEmpty {
                    Text(expense.vendor)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Receipt indicator
            if let receiptPath = expense.receiptPath, !receiptPath.isEmpty {
                Image(systemName: "paperclip")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Payment method badge
            if !expense.paymentMethod.isEmpty && expense.paymentMethod != "Card" {
                Text(expense.paymentMethod)
                    .font(.system(size: 8, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                    )
                    .foregroundColor(.secondary)
            }

            Text(formatCurrency(expense.amount))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - PO List Row

struct POListRow: View {
    let po: PurchaseOrder
    var isSelected: Bool = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(po.poNumber)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.accentColor)

            Text(po.vendor)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            Text(po.status)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor(po.status).opacity(0.2))
                )
                .foregroundColor(statusColor(po.status))

            Text(formatCurrency(po.amount))
                .font(.system(size: 12, weight: .bold, design: .rounded))

            Text(po.dateCreated)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(width: 70)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Draft": return .gray
        case "Approved": return .blue
        case "Committed": return .purple
        case "Paid": return .green
        case "Cancelled": return .red
        default: return .gray
        }
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
    @State private var accountCode = ""
    @State private var categoryGroup = "BTL"

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: category == nil ? "Add Category" : "Edit Category",
                canSave: !name.isEmpty
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    ProductionCard(icon: "folder", title: "CATEGORY INFORMATION") {
                        VStack(spacing: 10) {
                            StyledTextField("Category Name", text: $name)
                            StyledTextField("Description", text: $description)
                            StyledTextField("Account Code (e.g. 3300)", text: $accountCode)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("CATEGORY GROUP")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.2)
                                HStack(spacing: 6) {
                                    ForEach(["ATL", "BTL", "Post", "Other"], id: \.self) { group in
                                        ProductionChip(group, selected: categoryGroup == group) {
                                            categoryGroup = group
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ProductionCard(icon: "dollarsign.circle", title: "BUDGET") {
                        VStack(spacing: 10) {
                            StyledNumberField("Allocated Amount", value: $allocated)
                            StyledNumberField("Spent Amount", value: $spent)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let category = category {
                name = category.name
                allocated = category.allocated
                spent = category.spent
                description = category.description
                accountCode = category.accountCode
                categoryGroup = category.categoryGroup.isEmpty ? "BTL" : category.categoryGroup
            }
        }
    }

    private func save() {
        // Preserve the edited category's stable id so updateCategory can find it
        // even when the name changed (a new id here would make the rename a no-op).
        let newCategory = BudgetCategory(
            id: category?.id ?? UUID().uuidString,
            name: name,
            allocated: allocated,
            spent: spent,
            description: description,
            isCustom: category?.isCustom ?? true,
            accountCode: accountCode,
            categoryGroup: categoryGroup
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
    @State private var department = ""
    @State private var accountCode = ""
    @State private var paymentMethod = "Card"
    @State private var status = "Pending"
    @State private var isQualifyingExpense = false
    @State private var receiptPath: String = ""
    @State private var receiptPreviewImage: NSImage? = nil
    @State private var addedBy = ""
    @State private var isAnalyzing: Bool = false
    @State private var analysisError: String? = nil
    @State private var analysisSuccess: String? = nil

    // Multi-item receipt state
    @State private var multiItemResults: [ReceiptAnalysisResult] = []
    @State private var showingMultiItemAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: expense == nil ? "Add Expense" : "Edit Expense",
                canSave: !category.isEmpty && !description.isEmpty
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    // MARK: Left Column — Receipt + Category
                    VStack(spacing: 16) {
                        // Receipt card
                        ProductionCard(icon: "doc.richtext", title: "RECEIPT") {
                            VStack(spacing: 10) {
                                if receiptPath.isEmpty {
                                    Button {
                                        attachReceipt()
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: "doc.badge.plus")
                                                .font(.system(size: 28))
                                                .foregroundColor(.secondary)
                                            Text("Attach Receipt")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 100)
                                        .background(Color(nsColor: .quaternarySystemFill))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    // Thumbnail
                                    if let preview = receiptPreviewImage {
                                        Image(nsImage: preview)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: .infinity)
                                            .frame(maxHeight: 140)
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                                            )
                                    } else {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(nsColor: .quaternarySystemFill))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 100)
                                            .overlay(
                                                Image(systemName: "doc.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.secondary)
                                            )
                                    }

                                    Text(URL(fileURLWithPath: receiptPath).lastPathComponent)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)

                                    HStack(spacing: 6) {
                                        Button {
                                            analysisError = nil
                                            analysisSuccess = nil
                                            analyzeReceipt()
                                        } label: {
                                            HStack(spacing: 4) {
                                                if isAnalyzing {
                                                    ProgressView()
                                                        .controlSize(.mini)
                                                        .scaleEffect(0.7)
                                                }
                                                Label("Analyze", systemImage: "sparkles")
                                                    .font(.system(size: 10))
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.mini)
                                        .disabled(isAnalyzing || viewModel.onAnalyzeReceipt == nil)

                                        Button {
                                            receiptPath = ""
                                            receiptPreviewImage = nil
                                            analysisError = nil
                                            analysisSuccess = nil
                                        } label: {
                                            Label("Remove", systemImage: "xmark")
                                                .font(.system(size: 10))
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }

                                    if let error = analysisError {
                                        Text(error)
                                            .font(.system(size: 10))
                                            .foregroundColor(.red)
                                            .lineLimit(2)
                                    }

                                    if let success = analysisSuccess {
                                        Text(success)
                                            .font(.system(size: 10))
                                            .foregroundColor(.green)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }

                        // Category card
                        ProductionCard(icon: "tag", title: "CATEGORY") {
                            VStack(alignment: .leading, spacing: 6) {
                                if viewModel.budget.categories.isEmpty {
                                    Text("No categories — add one first")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                } else {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                                        ForEach(viewModel.budget.categories, id: \.name) { cat in
                                            ProductionChip(cat.name, selected: category == cat.name) {
                                                category = cat.name
                                                if accountCode.isEmpty {
                                                    accountCode = cat.accountCode
                                                }
                                                if department.isEmpty {
                                                    department = cat.name
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 240)

                    // MARK: Right Column — Details + Amount & Payment
                    VStack(spacing: 16) {
                        ProductionCard(icon: "receipt", title: "EXPENSE DETAILS") {
                            VStack(spacing: 12) {
                                DatePicker("Date", selection: $date, displayedComponents: [.date])
                                    .font(.system(size: 12))

                                StyledTextField("Description", text: $description)
                                StyledTextField("Vendor", text: $vendor)
                                StyledTextField("Added By", text: $addedBy)

                                HStack(spacing: 10) {
                                    StyledTextField("Department", text: $department)
                                    StyledTextField("Account Code", text: $accountCode)
                                }
                            }
                        }

                        ProductionCard(icon: "dollarsign.circle", title: "AMOUNT & PAYMENT") {
                            VStack(spacing: 10) {
                                StyledNumberField("Amount", value: $amount)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("PAYMENT METHOD")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.2)
                                    HStack(spacing: 6) {
                                        ForEach(["Card", "Check", "PettyCash", "Wire", "PO"], id: \.self) { method in
                                            ProductionChip(method, selected: paymentMethod == method) {
                                                paymentMethod = method
                                            }
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("STATUS")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.2)
                                    HStack(spacing: 6) {
                                        ForEach(["Pending", "Approved", "Paid"], id: \.self) { s in
                                            ProductionChip(s, selected: status == s) {
                                                status = s
                                            }
                                        }
                                    }
                                }

                                Toggle("Tax Qualifying Expense", isOn: $isQualifyingExpense)
                                    .font(.system(size: 11))
                                    .toggleStyle(.checkbox)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 680, height: 700)
        .background(Color(nsColor: .windowBackgroundColor))
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
                department = expense.department
                accountCode = expense.accountCode
                paymentMethod = expense.paymentMethod
                status = expense.status
                isQualifyingExpense = expense.isQualifyingExpense
                addedBy = expense.addedBy
                receiptPath = expense.receiptPath ?? ""
                loadReceiptPreview()
            } else {
                // Pre-fill defaults for new expense
                department = viewModel.defaultDepartment
                accountCode = viewModel.defaultAccountCode
            }
        }
        .alert("Multiple Items Detected", isPresented: $showingMultiItemAlert) {
            Button("Create \(multiItemResults.count) Expenses") {
                createMultipleExpenses()
            }
            Button("Single Expense") {
                fillFormWithCombinedResults()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            let total = multiItemResults.reduce(0) { $0 + $1.amount }
            Text("This receipt contains \(multiItemResults.count) items totaling $\(String(format: "%.2f", total)). Create a separate expense entry for each item?")
        }
    }

    // MARK: - Multi-Item Helpers

    private func createMultipleExpenses() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for item in multiItemResults {
            let itemDate: String
            if !item.date.isEmpty {
                itemDate = item.date
            } else {
                itemDate = formatter.string(from: date)
            }

            // Match category
            let matchedCategoryName: String
            if !item.category.isEmpty {
                let matched = viewModel.budget.categories.first {
                    $0.name.localizedCaseInsensitiveContains(item.category) ||
                    item.category.localizedCaseInsensitiveContains($0.name)
                }
                matchedCategoryName = matched?.name ?? (viewModel.budget.categories.first?.name ?? "")
            } else {
                matchedCategoryName = category.isEmpty ? (viewModel.budget.categories.first?.name ?? "") : category
            }

            let itemDept = department.isEmpty ? viewModel.defaultDepartment : department
            let itemAcctCode = accountCode.isEmpty ? viewModel.defaultAccountCode : accountCode

            let newExpense = Expense(
                date: itemDate,
                category: matchedCategoryName,
                amount: item.amount,
                description: item.description,
                vendor: item.vendor.isEmpty ? vendor : item.vendor,
                receiptPath: receiptPath.isEmpty ? nil : receiptPath,
                department: itemDept,
                accountCode: itemAcctCode,
                paymentMethod: paymentMethod,
                status: status,
                isQualifyingExpense: isQualifyingExpense,
                addedBy: addedBy
            )
            viewModel.addExpense(newExpense)
        }
        dismiss()
    }

    private func fillFormWithCombinedResults() {
        guard let first = multiItemResults.first else { return }

        // Use first item's details, but sum all amounts
        let totalAmount = multiItemResults.reduce(0) { $0 + $1.amount }
        let combinedDesc = multiItemResults.map { $0.description }.joined(separator: "; ")

        description = combinedDesc
        amount = totalAmount
        if !first.vendor.isEmpty { vendor = first.vendor }
        if !first.date.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let parsedDate = formatter.date(from: first.date) {
                date = parsedDate
            }
        }
        if !first.category.isEmpty {
            let matchedCategory = viewModel.budget.categories.first {
                $0.name.localizedCaseInsensitiveContains(first.category) ||
                first.category.localizedCaseInsensitiveContains($0.name)
            }
            if let matched = matchedCategory {
                category = matched.name
            }
        }
        analysisSuccess = "Combined \(multiItemResults.count) items into single expense"
    }

    private func attachReceipt() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a receipt image or PDF"

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        // Copy file into project assets/receipts/
        guard let basePath = viewModel.projectBasePath else {
            // No project path — store absolute path as fallback
            receiptPath = sourceURL.path
            loadReceiptPreview()
            return
        }

        let receiptsDir = basePath.appendingPathComponent("assets/receipts")
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: receiptsDir, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension
        let destFilename = "\(UUID().uuidString).\(ext)"
        let destURL = receiptsDir.appendingPathComponent(destFilename)

        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            receiptPath = "assets/receipts/\(destFilename)"
            loadReceiptPreview()
        } catch {
            print("Failed to copy receipt: \(error)")
            // Fallback to absolute path
            receiptPath = sourceURL.path
            loadReceiptPreview()
        }
    }

    private func loadReceiptPreview() {
        guard !receiptPath.isEmpty else {
            receiptPreviewImage = nil
            return
        }

        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(receiptPath)
        } else {
            fullURL = URL(fileURLWithPath: receiptPath)
        }

        receiptPreviewImage = NSImage(contentsOf: fullURL)
    }

    private func analyzeReceipt() {
        guard !receiptPath.isEmpty, let analyzeCallback = viewModel.onAnalyzeReceipt else {
            analysisError = viewModel.onAnalyzeReceipt == nil ? "AI analysis not available" : "No receipt attached"
            return
        }

        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(receiptPath)
        } else {
            fullURL = URL(fileURLWithPath: receiptPath)
        }

        let ext = fullURL.pathExtension.lowercased()

        // For PDFs, render first page as PNG image for AI vision
        let imageData: Data
        let mimeType: String

        if ext == "pdf" {
            guard let pdfDoc = PDFDocument(url: fullURL),
                  let pdfPage = pdfDoc.page(at: 0) else {
                analysisError = "Could not read PDF file"
                return
            }
            let pageRect = pdfPage.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0 // Render at 2x for readability
            let renderSize = NSSize(width: pageRect.width * scale, height: pageRect.height * scale)
            let pdfImage = pdfPage.thumbnail(of: renderSize, for: .mediaBox)
            guard let tiffData = pdfImage.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                analysisError = "Could not render PDF page as image"
                return
            }
            imageData = pngData
            mimeType = "image/png"
        } else {
            guard let data = try? Data(contentsOf: fullURL) else {
                analysisError = "Could not read receipt file"
                return
            }
            imageData = data
            switch ext {
            case "png": mimeType = "image/png"
            case "jpg", "jpeg": mimeType = "image/jpeg"
            default: mimeType = "image/png"
            }
        }

        isAnalyzing = true
        Task {
            let results = await analyzeCallback(imageData, mimeType)
            if results.isEmpty {
                analysisError = "AI could not analyze this receipt. Check server connection."
            } else if results.count == 1 {
                // Single item — fill form directly
                let result = results[0]
                if !result.description.isEmpty { description = result.description }
                if !result.vendor.isEmpty { vendor = result.vendor }
                if result.amount > 0 { amount = result.amount }
                if !result.date.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let parsedDate = formatter.date(from: result.date) {
                        date = parsedDate
                    }
                }
                if !result.category.isEmpty {
                    let matchedCategory = viewModel.budget.categories.first {
                        $0.name.localizedCaseInsensitiveContains(result.category) ||
                        result.category.localizedCaseInsensitiveContains($0.name)
                    }
                    if let matched = matchedCategory {
                        category = matched.name
                    }
                }
                analysisSuccess = "Receipt analyzed successfully"
            } else {
                // Multiple items detected — show alert
                multiItemResults = results
                showingMultiItemAlert = true
            }
            isAnalyzing = false
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
            existing.department = department
            existing.accountCode = accountCode
            existing.paymentMethod = paymentMethod
            existing.status = status
            existing.isQualifyingExpense = isQualifyingExpense
            existing.addedBy = addedBy
            existing.receiptPath = receiptPath.isEmpty ? nil : receiptPath
            viewModel.updateExpense(existing)
        } else {
            let newExpense = Expense(
                date: dateStr,
                category: category,
                amount: amount,
                description: description,
                vendor: vendor,
                receiptPath: receiptPath.isEmpty ? nil : receiptPath,
                department: department,
                accountCode: accountCode,
                paymentMethod: paymentMethod,
                status: status,
                isQualifyingExpense: isQualifyingExpense,
                addedBy: addedBy
            )
            viewModel.addExpense(newExpense)
        }
        dismiss()
    }
}

// MARK: - PO Editor Sheet

struct POEditorSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let po: PurchaseOrder?

    @Environment(\.dismiss) private var dismiss

    @State private var poNumber = ""
    @State private var vendor = ""
    @State private var department = ""
    @State private var accountCode = ""
    @State private var description = ""
    @State private var amount: Double = 0
    @State private var status = "Draft"
    @State private var notes = ""
    @State private var approvedBy = ""
    @State private var attachments: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: po == nil ? "New Purchase Order" : "Edit Purchase Order",
                canSave: !vendor.isEmpty && amount > 0
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    // MARK: Left Column — Attachments + Status
                    VStack(spacing: 16) {
                        // Attachments card
                        ProductionCard(icon: "paperclip", title: "ATTACHMENTS") {
                            VStack(spacing: 8) {
                                if attachments.isEmpty {
                                    Button {
                                        attachFile()
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: "doc.badge.plus")
                                                .font(.system(size: 28))
                                                .foregroundColor(.secondary)
                                            Text("Attach Files")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 100)
                                        .background(Color(nsColor: .quaternarySystemFill))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    ForEach(Array(attachments.enumerated()), id: \.offset) { index, path in
                                        HStack(spacing: 6) {
                                            Image(systemName: iconForFile(path))
                                                .font(.system(size: 11))
                                                .foregroundColor(.accentColor)
                                                .frame(width: 14)

                                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                                .font(.system(size: 10))
                                                .lineLimit(1)
                                                .truncationMode(.middle)

                                            Spacer()

                                            Button {
                                                openAttachment(path)
                                            } label: {
                                                Image(systemName: "eye")
                                                    .font(.system(size: 9))
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Open file")

                                            Button {
                                                attachments.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Remove attachment")
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 6)
                                        .background(Color(nsColor: .quaternarySystemFill))
                                        .cornerRadius(6)
                                    }

                                    Button {
                                        attachFile()
                                    } label: {
                                        Label("Add More", systemImage: "plus.circle")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }
                        }

                        // Status card
                        ProductionCard(icon: "flag", title: "STATUS") {
                            VStack(alignment: .leading, spacing: 8) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                                    ForEach(["Draft", "Approved", "Committed", "Paid", "Cancelled"], id: \.self) { s in
                                        ProductionChip(s, selected: status == s) {
                                            status = s
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 240)

                    // MARK: Right Column — PO Details + Amount
                    VStack(spacing: 16) {
                        ProductionCard(icon: "doc.plaintext", title: "PO DETAILS") {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("PO NUMBER")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.2)
                                    Spacer()
                                    Text(poNumber)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.accentColor)
                                }

                                StyledTextField("Vendor", text: $vendor)
                                StyledTextField("Description", text: $description)
                                StyledTextField("Approved By", text: $approvedBy)

                                HStack(spacing: 10) {
                                    StyledTextField("Department", text: $department)
                                    StyledTextField("Account Code", text: $accountCode)
                                }
                            }
                        }

                        ProductionCard(icon: "dollarsign.circle", title: "AMOUNT & NOTES") {
                            VStack(spacing: 10) {
                                StyledNumberField("Amount", value: $amount)
                                StyledTextField("Notes", text: $notes)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 680, height: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let po = po {
                poNumber = po.poNumber
                vendor = po.vendor
                department = po.department
                accountCode = po.accountCode
                description = po.description
                amount = po.amount
                status = po.status
                notes = po.notes
                approvedBy = po.approvedBy
                attachments = po.attachments
            } else {
                poNumber = viewModel.nextPONumber()
            }
        }
    }

    private func attachFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Select files to attach to this purchase order"

        guard panel.runModal() == .OK else { return }

        for sourceURL in panel.urls {
            guard let basePath = viewModel.projectBasePath else {
                // No project path — store absolute path as fallback
                attachments.append(sourceURL.path)
                continue
            }

            let attachmentsDir = basePath.appendingPathComponent("assets/po_attachments")
            let fileManager = FileManager.default
            try? fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

            let ext = sourceURL.pathExtension
            let destFilename = "\(UUID().uuidString).\(ext)"
            let destURL = attachmentsDir.appendingPathComponent(destFilename)

            do {
                try fileManager.copyItem(at: sourceURL, to: destURL)
                attachments.append("assets/po_attachments/\(destFilename)")
            } catch {
                print("Failed to copy attachment: \(error)")
                attachments.append(sourceURL.path)
            }
        }
    }

    private func openAttachment(_ path: String) {
        let fullURL: URL
        if let basePath = viewModel.projectBasePath {
            fullURL = basePath.appendingPathComponent(path)
        } else {
            fullURL = URL(fileURLWithPath: path)
        }
        NSWorkspace.shared.open(fullURL)
    }

    private func iconForFile(_ path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "heic", "tiff": return "photo"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx", "csv": return "tablecells"
        case "zip", "gz", "tar": return "archivebox"
        default: return "doc"
        }
    }

    private func save() {
        if var existing = po {
            existing.vendor = vendor
            existing.department = department
            existing.accountCode = accountCode
            existing.description = description
            existing.amount = amount
            existing.status = status
            existing.notes = notes
            existing.approvedBy = approvedBy
            existing.attachments = attachments
            viewModel.updatePurchaseOrder(existing)
        } else {
            let newPO = PurchaseOrder(
                poNumber: poNumber,
                vendor: vendor,
                department: department,
                accountCode: accountCode,
                description: description,
                amount: amount,
                status: status,
                notes: notes,
                approvedBy: approvedBy,
                attachments: attachments
            )
            viewModel.addPurchaseOrder(newPO)
        }
        dismiss()
    }
}
