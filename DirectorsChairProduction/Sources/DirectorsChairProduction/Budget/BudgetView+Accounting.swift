//
// BudgetView+Accounting.swift
//
// Extracted from BudgetView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit
import DirectorsChairCore

extension BudgetView {

    // MARK: - Action Bar

    var accountingActionBar: some View {
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

    var accountingOverviewView: some View {
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

    var departmentBreakdownSection: some View {
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

    var recentActivitySection: some View {
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

    var costBySceneSection: some View {
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

    var topSheetView: some View {
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

    func topSheetGroup(title: String, group: String, icon: String) -> some View {
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

    func topSheetRow(category: BudgetCategory) -> some View {
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
}
