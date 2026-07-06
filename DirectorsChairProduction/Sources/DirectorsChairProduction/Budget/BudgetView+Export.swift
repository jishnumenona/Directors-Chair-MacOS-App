//
// BudgetView+Export.swift
//
// Extracted from BudgetView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit
import DirectorsChairCore

extension BudgetView {

    // MARK: - Export View

    var exportView: some View {
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

    var exportFiltersCard: some View {
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

    var exportFilteredSummaryCard: some View {
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

    var exportFormatsCard: some View {
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

    var exportFormatDivider: some View {
        Divider().opacity(0.3).padding(.vertical, 2)
    }

    func exportFilterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
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

    func exportMiniStat(value: String, label: String, detail: String, color: Color) -> some View {
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

    func exportSummaryRow(icon: String, label: String, value: String) -> some View {
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

    func exportFormatRow(
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

    var hasActiveFilters: Bool {
        exportDatePreset != "allTime" ||
        !exportSelectedDepartments.isEmpty ||
        !exportSelectedGroups.isEmpty ||
        !exportSelectedExpenseStatuses.isEmpty ||
        !exportSelectedPOStatuses.isEmpty ||
        !exportSelectedPaymentMethods.isEmpty ||
        !exportMinAmount.isEmpty ||
        !exportMaxAmount.isEmpty
    }

    func resetExportFilters() {
        exportDatePreset = "allTime"
        exportSelectedDepartments.removeAll()
        exportSelectedGroups.removeAll()
        exportSelectedExpenseStatuses.removeAll()
        exportSelectedPOStatuses.removeAll()
        exportSelectedPaymentMethods.removeAll()
        exportMinAmount = ""
        exportMaxAmount = ""
    }

    var exportAvailableDepartments: [String] {
        var depts = Set<String>()
        for exp in viewModel.budget.expenses where !exp.department.isEmpty {
            depts.insert(exp.department)
        }
        for po in viewModel.budget.purchaseOrders where !po.department.isEmpty {
            depts.insert(po.department)
        }
        return depts.sorted()
    }

    var exportDateRange: (from: String, to: String)? {
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

    var exportFilteredExpenses: [Expense] {
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

    var filteredPurchaseOrders: [PurchaseOrder] {
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

    var filteredCategories: [BudgetCategory] {
        if exportSelectedGroups.isEmpty {
            return viewModel.budget.categories
        }
        return viewModel.budget.categories.filter { exportSelectedGroups.contains($0.categoryGroup) }
    }

    var filteredCostReport: [CostReportRow] {
        let allRows = viewModel.costReportData()
        if exportSelectedGroups.isEmpty { return allRows }
        let groupCategories = Set(filteredCategories.map { $0.name })
        return allRows.filter { groupCategories.contains($0.description) }
    }

    // MARK: - Save to File

    func saveToFile(content: String, defaultName: String, title: String, contentType: UTType) {
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

    // MARK: - Exports (format building lives in BudgetExportService — WS8.7)

    func exportCSV() {
        let content = BudgetExportService.csv(
            categories: filteredCategories,
            expenses: exportFilteredExpenses,
            purchaseOrders: filteredPurchaseOrders,
            costReport: filteredCostReport,
            castMembers: viewModel.castMembers,
            crewMembers: viewModel.crewMembers,
            totalShootDays: viewModel.totalShootDays
        )
        saveToFile(
            content: content,
            defaultName: "production_accounting_export.csv",
            title: "Export CSV/Excel",
            contentType: UTType.commaSeparatedText
        )
    }

    func exportXeroCSV() {
        saveToFile(
            content: BudgetExportService.xeroCSV(expenses: exportFilteredExpenses),
            defaultName: "production_xero_import.csv",
            title: "Export Xero CSV",
            contentType: UTType.commaSeparatedText
        )
    }

    func exportTallyXML() {
        saveToFile(
            content: BudgetExportService.tallyXML(expenses: exportFilteredExpenses),
            defaultName: "production_tally_import.xml",
            title: "Export Tally XML",
            contentType: UTType.xml
        )
    }
}
