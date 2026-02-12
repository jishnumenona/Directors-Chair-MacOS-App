// DirectorsChairProduction/Sources/DirectorsChairProduction/Equipment/EquipmentView.swift
//
// Equipment Management View with Production Allocation

import SwiftUI
import DirectorsChairCore

// MARK: - Allocation Filter

enum AllocationFilter: String, CaseIterable {
    case all = "All"
    case fullProduction = "Full Production"
    case specificDays = "Specific Days"
    case unallocated = "Unallocated"

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .fullProduction: return "film"
        case .specificDays: return "calendar.badge.clock"
        case .unallocated: return "tray"
        }
    }
}

// MARK: - Equipment View

public struct EquipmentView: View {
    @ObservedObject var viewModel: EquipmentViewModel

    @State private var searchText = ""
    @State private var categoryFilter: String = "All"
    @State private var allocationFilter: AllocationFilter = .all
    @State private var selectedEquipment: EquipmentItem?
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false

    public init(viewModel: EquipmentViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Action bar with filters
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ProductionActionButton(icon: "plus", "Add Equipment", prominent: true) {
                        showingAddSheet = true
                    }

                    Spacer()

                    // Allocation filter chips
                    HStack(spacing: 6) {
                        ForEach(AllocationFilter.allCases, id: \.self) { filter in
                            ProductionChip(icon: filter.icon, filter.rawValue, selected: allocationFilter == filter) {
                                allocationFilter = filter
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Spacer()

                    // Category filter chips
                    HStack(spacing: 6) {
                        ProductionChip("All", selected: categoryFilter == "All") {
                            categoryFilter = "All"
                        }
                        ForEach(EquipmentCategory.allCases, id: \.self) { cat in
                            ProductionChip(icon: categoryIcon(cat.rawValue), cat.rawValue, selected: categoryFilter == cat.rawValue) {
                                categoryFilter = cat.rawValue
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

            // Main content: 2-column layout
            HStack(spacing: 16) {
                // Left: Equipment list
                ProductionCard(icon: "camera.metering.matrix", title: "EQUIPMENT LIBRARY") {
                    VStack(spacing: 10) {
                        // Stats row
                        HStack(spacing: 8) {
                            ProductionStatBadge(intValue: viewModel.totalItems, label: "Items", color: .orange)
                            ProductionStatBadge(intValue: viewModel.totalUnits, label: "Units", color: .blue)
                            ProductionStatBadge(intValue: viewModel.allocatedCount, label: "Allocated", color: .green)
                            ProductionStatBadge(currencyValue: viewModel.rentalCostPerDay, label: "Daily Rental", color: .purple)
                        }

                        // Search
                        ProductionSearchField(text: $searchText)

                        // Equipment list
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredEquipment) { item in
                                    EquipmentListRow(
                                        item: item,
                                        allocation: viewModel.allocation(for: item.id),
                                        isSelected: selectedEquipment?.id == item.id
                                    )
                                    .onTapGesture {
                                        selectedEquipment = item
                                    }
                                    .onTapGesture(count: 2) {
                                        selectedEquipment = item
                                        showingEditSheet = true
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 400)

                // Right: Detail + allocation
                if let selected = selectedEquipment {
                    VStack(spacing: 16) {
                        // Equipment detail card
                        ProductionCard(icon: "info.circle", title: "EQUIPMENT DETAILS") {
                            equipmentDetailContent(selected)
                        }

                        // Allocation card
                        ProductionCard(icon: "calendar.badge.plus", title: "PRODUCTION ALLOCATION") {
                            allocationContent(selected)
                        }

                        // Usage summary
                        ProductionCard(icon: "chart.bar", title: "USAGE SUMMARY") {
                            usageSummaryContent(selected)
                        }
                    }
                } else {
                    ProductionCard(icon: "camera.metering.matrix", title: "EQUIPMENT DETAILS") {
                        Text("Select equipment to view details")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showingAddSheet) {
            EquipmentEditorView(viewModel: viewModel, equipment: nil)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let equipment = selectedEquipment {
                EquipmentEditorView(viewModel: viewModel, equipment: equipment)
            }
        }
    }

    // MARK: - Detail Content

    private func equipmentDetailContent(_ item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero
            HStack(spacing: 12) {
                Image(systemName: categoryIcon(item.category))
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .bold))
                    if !item.manufacturer.isEmpty || !item.model.isEmpty {
                        Text([item.manufacturer, item.model].filter { !$0.isEmpty }.joined(separator: " "))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Edit button
                ProductionActionButton(icon: "pencil", "Edit") {
                    showingEditSheet = true
                }
            }

            Divider()

            // Category & condition chips
            HStack(spacing: 6) {
                chipBadge(icon: categoryIcon(item.category), label: item.category, color: .orange)
                if !item.condition.isEmpty {
                    chipBadge(icon: conditionIcon(item.condition), label: item.condition, color: conditionColor(item.condition))
                }
            }

            // Quantity
            HStack(spacing: 16) {
                detailRow(icon: "number", label: "Owned", value: "\(item.quantityOwned)")
                detailRow(icon: "checkmark.circle", label: "Available", value: "\(item.quantityAvailable)")
            }

            // Rental info
            if item.isRental {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("Rental")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                    Spacer()
                    Text("$\(String(format: "%.0f", item.rentalDailyRate))/day")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                }
            }

            // Notes
            if !item.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOTES")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.2)
                    Text(item.notes)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // Delete button
            HStack {
                Spacer()
                ProductionActionButton(icon: "trash", "Delete") {
                    viewModel.removeEquipment(item)
                    selectedEquipment = nil
                }
            }
        }
    }

    // MARK: - Allocation Content

    private func allocationContent(_ item: EquipmentItem) -> some View {
        let currentAlloc = viewModel.allocation(for: item.id)
        let currentMode = currentAlloc?.allocationMode
        let currentQty = currentAlloc?.quantityAllocated ?? 1
        let currentDates = currentAlloc?.allocatedDates ?? []
        let currentNotes = currentAlloc?.notes ?? ""

        return VStack(alignment: .leading, spacing: 12) {
            // Mode chips
            HStack(spacing: 8) {
                ProductionChip(icon: "film", "Full Production", selected: currentMode == .fullProduction) {
                    viewModel.setAllocation(
                        for: item.id,
                        mode: .fullProduction,
                        dates: currentDates,
                        quantity: currentQty,
                        notes: currentNotes
                    )
                }
                ProductionChip(icon: "calendar.badge.clock", "Specific Days", selected: currentMode == .specificDays) {
                    viewModel.setAllocation(
                        for: item.id,
                        mode: .specificDays,
                        dates: currentDates,
                        quantity: currentQty,
                        notes: currentNotes
                    )
                }
                if currentMode != nil {
                    ProductionChip(icon: "xmark", "Clear", selected: false) {
                        viewModel.removeAllocation(for: item.id)
                    }
                }
            }

            if let alloc = currentAlloc {
                // Quantity stepper
                HStack {
                    Text("Quantity Allocated")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(alloc.quantityAllocated)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                    Stepper("", value: Binding(
                        get: { alloc.quantityAllocated },
                        set: { newVal in
                            viewModel.setAllocation(
                                for: item.id,
                                mode: alloc.allocationMode,
                                dates: alloc.allocatedDates,
                                quantity: newVal,
                                notes: alloc.notes
                            )
                        }
                    ), in: 1...max(1, item.quantityOwned))
                    .labelsHidden()
                }

                // Specific days: date management
                if alloc.allocationMode == .specificDays {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ALLOCATED DATES")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.2)

                        AllocationDatePicker(
                            dates: alloc.allocatedDates,
                            onDatesChanged: { newDates in
                                viewModel.setAllocation(
                                    for: item.id,
                                    mode: .specificDays,
                                    dates: newDates,
                                    quantity: alloc.quantityAllocated,
                                    notes: alloc.notes
                                )
                            }
                        )
                    }
                }

                if alloc.allocationMode == .fullProduction {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("Available for all shoot days")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            } else {
                Text("No allocation set. Choose Full Production or Specific Days above.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Usage Summary

    private func usageSummaryContent(_ item: EquipmentItem) -> some View {
        let alloc = viewModel.allocation(for: item.id)

        return VStack(alignment: .leading, spacing: 8) {
            if let alloc = alloc {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(alloc.allocationMode == .fullProduction ? "All Days" : "\(alloc.allocatedDates.count)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        Text("Days Allocated")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }

                    if item.isRental {
                        VStack(spacing: 4) {
                            let days = alloc.allocationMode == .fullProduction ? 1 : alloc.allocatedDates.count
                            Text("$\(String(format: "%.0f", item.rentalDailyRate * Double(max(1, days))))")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                            Text(alloc.allocationMode == .fullProduction ? "Per Day Rental" : "Est. Rental")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                    }

                    VStack(spacing: 4) {
                        Text("\(alloc.quantityAllocated)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text("Units")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("Not yet allocated to production")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Filtered Equipment

    private var filteredEquipment: [EquipmentItem] {
        var items = viewModel.equipment

        // Allocation filter
        switch allocationFilter {
        case .all: break
        case .fullProduction: items = viewModel.fullProductionEquipment()
        case .specificDays: items = viewModel.specificDaysEquipment()
        case .unallocated: items = viewModel.unallocatedEquipment()
        }

        // Category filter
        if categoryFilter != "All" {
            items = items.filter { $0.category == categoryFilter }
        }

        // Search
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.manufacturer.localizedCaseInsensitiveContains(searchText) ||
                $0.model.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    // MARK: - Helpers

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "Camera": return "camera"
        case "Lighting": return "light.max"
        case "Sound": return "mic"
        case "Grip": return "wrench"
        case "Electric": return "bolt"
        case "Post": return "desktopcomputer"
        default: return "shippingbox"
        }
    }

    private func conditionIcon(_ condition: String) -> String {
        switch condition {
        case "Excellent": return "star.fill"
        case "Good": return "checkmark.circle"
        case "Fair": return "exclamationmark.triangle"
        case "Needs Repair": return "wrench.and.screwdriver"
        default: return "questionmark.circle"
        }
    }

    private func conditionColor(_ condition: String) -> Color {
        switch condition {
        case "Excellent": return .green
        case "Good": return .blue
        case "Fair": return .yellow
        case "Needs Repair": return .red
        default: return .gray
        }
    }

    private func chipBadge(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.2))
        )
        .foregroundColor(color)
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
}

// MARK: - Equipment List Row

struct EquipmentListRow: View {
    let item: EquipmentItem
    let allocation: EquipmentAllocation?
    var isSelected: Bool = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: categoryIcon)
                .font(.system(size: 14))
                .foregroundColor(.orange)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12, weight: .semibold))
                if !item.manufacturer.isEmpty {
                    Text(item.manufacturer)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Allocation badge
            if let alloc = allocation {
                allocationBadge(alloc)
            } else {
                Text("Unallocated")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                    )
                    .foregroundColor(.gray)
            }

            // Category chip
            Text(item.category)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.2))
                )
                .foregroundColor(.orange)

            // Quantity
            Text("x\(item.quantityOwned)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            if item.isRental {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9))
                    .foregroundColor(.yellow)
            }
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

    private func allocationBadge(_ alloc: EquipmentAllocation) -> some View {
        Group {
            if alloc.allocationMode == .fullProduction {
                Text("Full")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.2))
                    )
                    .foregroundColor(.green)
            } else {
                Text("\(alloc.allocatedDates.count) Days")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.2))
                    )
                    .foregroundColor(.blue)
            }
        }
    }

    private var categoryIcon: String {
        switch item.category {
        case "Camera": return "camera"
        case "Lighting": return "light.max"
        case "Sound": return "mic"
        case "Grip": return "wrench"
        case "Electric": return "bolt"
        case "Post": return "desktopcomputer"
        default: return "shippingbox"
        }
    }
}

// MARK: - Allocation Date Picker

struct AllocationDatePicker: View {
    let dates: [String]
    let onDatesChanged: ([String]) -> Void

    @State private var newDate = Date()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Add date
            HStack(spacing: 8) {
                DatePicker("", selection: $newDate, displayedComponents: .date)
                    .labelsHidden()
                    .frame(width: 140)

                ProductionActionButton(icon: "plus", "Add Date", prominent: true) {
                    let dateStr = Self.dateFormatter.string(from: newDate)
                    if !dates.contains(dateStr) {
                        var updated = dates
                        updated.append(dateStr)
                        updated.sort()
                        onDatesChanged(updated)
                    }
                }
            }

            // Listed dates
            if !dates.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(dates, id: \.self) { dateStr in
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text(formattedDate(dateStr))
                                    .font(.system(size: 11))
                                Spacer()
                                Button(action: {
                                    var updated = dates
                                    updated.removeAll { $0 == dateStr }
                                    onDatesChanged(updated)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .quaternarySystemFill))
                            )
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
    }

    private func formattedDate(_ dateStr: String) -> String {
        guard let date = Self.dateFormatter.date(from: dateStr) else { return dateStr }
        let display = DateFormatter()
        display.dateStyle = .medium
        return display.string(from: date)
    }
}

// MARK: - Equipment Editor View (Sheet)

struct EquipmentEditorView: View {
    @ObservedObject var viewModel: EquipmentViewModel
    let equipment: EquipmentItem?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category = "Camera"
    @State private var subcategory = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var itemDescription = ""
    @State private var quantityOwned = 1
    @State private var quantityAvailable = 1
    @State private var isRental = false
    @State private var rentalCompany = ""
    @State private var rentalDailyRate: Double = 0
    @State private var rentalWeeklyRate: Double = 0
    @State private var condition = "Good"
    @State private var serialNumber = ""
    @State private var storageLocation = ""
    @State private var responsibleCrewMemberName = ""
    @State private var notes = ""

    private let conditions = ["Excellent", "Good", "Fair", "Needs Repair"]

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: equipment == nil ? "Add Equipment" : "Edit Equipment",
                canSave: !name.isEmpty
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    ProductionCard(icon: "camera", title: "BASIC INFORMATION") {
                        VStack(spacing: 10) {
                            StyledTextField("Name", text: $name)
                            StyledTextField("Manufacturer", text: $manufacturer)
                            StyledTextField("Model", text: $model)
                            StyledTextField("Description", text: $itemDescription)
                            StyledTextField("Serial Number", text: $serialNumber)
                        }
                    }

                    ProductionCard(icon: "tag", title: "CATEGORY") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                            ForEach(EquipmentCategory.allCases, id: \.self) { cat in
                                ProductionChip(cat.rawValue, selected: category == cat.rawValue) {
                                    category = cat.rawValue
                                }
                            }
                        }
                    }

                    ProductionCard(icon: "number", title: "QUANTITY") {
                        VStack(spacing: 10) {
                            HStack {
                                Text("Owned")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(quantityOwned)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.accentColor)
                                Stepper("", value: $quantityOwned, in: 0...100)
                                    .labelsHidden()
                            }
                            HStack {
                                Text("Available")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(quantityAvailable)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                Stepper("", value: $quantityAvailable, in: 0...quantityOwned)
                                    .labelsHidden()
                            }
                        }
                    }

                    ProductionCard(icon: "arrow.triangle.2.circlepath", title: "RENTAL") {
                        VStack(spacing: 10) {
                            HStack {
                                ProductionChip(icon: "checkmark", "Rental", selected: isRental) {
                                    isRental = true
                                }
                                ProductionChip(icon: "xmark", "Not Rental", selected: !isRental) {
                                    isRental = false
                                }
                                Spacer()
                            }

                            if isRental {
                                StyledTextField("Rental Company", text: $rentalCompany)
                                StyledNumberField("Daily Rate", value: $rentalDailyRate)
                                StyledNumberField("Weekly Rate", value: $rentalWeeklyRate)
                            }
                        }
                    }

                    ProductionCard(icon: "wrench.and.screwdriver", title: "CONDITION") {
                        HStack(spacing: 6) {
                            ForEach(conditions, id: \.self) { cond in
                                ProductionChip(cond, selected: condition == cond) {
                                    condition = cond
                                }
                            }
                        }
                    }

                    ProductionCard(icon: "mappin", title: "STORAGE & RESPONSIBILITY") {
                        VStack(spacing: 10) {
                            StyledTextField("Storage Location", text: $storageLocation)
                            StyledTextField("Responsible Person", text: $responsibleCrewMemberName)
                        }
                    }

                    ProductionCard(icon: "note.text", title: "NOTES") {
                        StyledTextField("Notes", text: $notes)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 560, height: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let e = equipment {
                name = e.name
                category = e.category
                subcategory = e.subcategory
                manufacturer = e.manufacturer
                model = e.model
                itemDescription = e.description
                quantityOwned = e.quantityOwned
                quantityAvailable = e.quantityAvailable
                isRental = e.isRental
                rentalCompany = e.rentalCompany
                rentalDailyRate = e.rentalDailyRate
                rentalWeeklyRate = e.rentalWeeklyRate
                condition = e.condition
                serialNumber = e.serialNumber
                storageLocation = e.storageLocation
                responsibleCrewMemberName = e.responsibleCrewMemberName
                notes = e.notes
            }
        }
    }

    private func save() {
        if var existing = equipment {
            existing.name = name
            existing.category = category
            existing.subcategory = subcategory
            existing.manufacturer = manufacturer
            existing.model = model
            existing.description = itemDescription
            existing.quantityOwned = quantityOwned
            existing.quantityAvailable = quantityAvailable
            existing.isRental = isRental
            existing.rentalCompany = rentalCompany
            existing.rentalDailyRate = rentalDailyRate
            existing.rentalWeeklyRate = rentalWeeklyRate
            existing.condition = condition
            existing.serialNumber = serialNumber
            existing.storageLocation = storageLocation
            existing.responsibleCrewMemberName = responsibleCrewMemberName
            existing.notes = notes
            existing.modifiedDate = ISO8601DateFormatter().string(from: Date())
            viewModel.updateEquipment(existing)
        } else {
            let newItem = EquipmentItem(
                name: name,
                category: category,
                subcategory: subcategory,
                manufacturer: manufacturer,
                model: model,
                description: itemDescription,
                quantityOwned: quantityOwned,
                quantityAvailable: quantityAvailable,
                isRental: isRental,
                rentalCompany: rentalCompany,
                rentalDailyRate: rentalDailyRate,
                rentalWeeklyRate: rentalWeeklyRate,
                serialNumber: serialNumber,
                condition: condition,
                notes: notes,
                storageLocation: storageLocation,
                responsibleCrewMemberName: responsibleCrewMemberName
            )
            viewModel.addEquipment(newItem)
        }
        dismiss()
    }
}
