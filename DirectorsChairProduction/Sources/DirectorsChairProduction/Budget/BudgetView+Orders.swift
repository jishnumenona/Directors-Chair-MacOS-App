//
// BudgetView+Orders.swift
//
// Extracted from BudgetView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit
import DirectorsChairCore

extension BudgetView {

    // MARK: - Purchase Orders

    var purchaseOrdersView: some View {
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

    var filteredPOs: [PurchaseOrder] {
        viewModel.purchaseOrders(forStatus: poStatusFilter)
    }

    func poDetailView(_ po: PurchaseOrder) -> some View {
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

    var payrollView: some View {
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

    func payrollTable(headers: [String], widths: [CGFloat?], rows: [[String]], totalLabel: String, totalValue: Double) -> some View {
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

    func castShootDays(_ cast: CastMember) -> Int {
        let matchingItems = viewModel.scheduleItems.filter { item in
            item.requiredActors.contains(cast.actorName) || item.requiredActors.contains(cast.characterName)
        }
        let uniqueDates = Set(matchingItems.compactMap { $0.shootDate }.filter { !$0.isEmpty })
        return max(uniqueDates.count, matchingItems.isEmpty ? 0 : 1)
    }

    func crewShootDays(_ crew: CrewMember) -> Int {
        let matchingItems = viewModel.scheduleItems.filter { item in
            item.requiredCrew.contains(crew.name) || item.requiredCrew.contains(crew.role)
        }
        if matchingItems.isEmpty {
            return viewModel.totalShootDays
        }
        let uniqueDates = Set(matchingItems.compactMap { $0.shootDate }.filter { !$0.isEmpty })
        return max(uniqueDates.count, 1)
    }

    func equipmentDays(_ item: EquipmentItem) -> Int {
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

    func detailRow(icon: String, label: String, value: String) -> some View {
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

    func statusBadge(_ status: String, color: Color) -> some View {
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

    func poStatusColor(_ status: String) -> Color {
        switch status {
        case "Draft": return .gray
        case "Approved": return .blue
        case "Committed": return .purple
        case "Paid": return .green
        case "Cancelled": return .red
        default: return .gray
        }
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.budget.currency
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    func formatCompact(_ value: Double) -> String {
        if abs(value) >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if abs(value) >= 1_000 {
            return String(format: "$%.1fK", value / 1_000)
        } else {
            return formatCurrency(value)
        }
    }
}
