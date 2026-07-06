//
// BudgetView+Reports.swift
//
// Extracted from BudgetView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit
import DirectorsChairCore

extension BudgetView {

    // MARK: - Cost Report

    var costReportView: some View {
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

    func costReportRow(_ row: CostReportRow) -> some View {
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

    func costCell(_ value: Double, width: CGFloat, bold: Bool = false, colored: Bool = false) -> some View {
        Text(value == 0 ? "-" : formatCompact(value))
            .font(.system(size: 9, weight: bold ? .bold : .regular, design: .rounded))
            .foregroundColor(colored ? (value >= 0 ? .green : .red) : .primary)
            .frame(width: width, alignment: .trailing)
    }

    // MARK: - Expenses

    var expensesView: some View {
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
                                    ExpenseListRow(expense: expense, currencyCode: viewModel.budget.currency, isSelected: selectedExpense?.id == expense.id)
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

    var filteredExpenses: [Expense] {
        if expenseDeptFilter == "All" {
            return viewModel.budget.expenses
        }
        return viewModel.budget.expenses.filter {
            $0.department == expenseDeptFilter || $0.category == expenseDeptFilter
        }
    }

    func expenseDetailView(_ expense: Expense) -> some View {
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

    func receiptPreviewSection(receiptPath: String) -> some View {
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
}
