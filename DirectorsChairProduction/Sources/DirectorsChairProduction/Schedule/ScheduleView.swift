// DirectorsChairProduction/Sources/DirectorsChairProduction/Schedule/ScheduleView.swift
//
// Schedule View - Production Schedule Calendar
// Calendar-based view for visualizing and managing the production schedule.
// Supports multiple view modes, calendar highlighting, and schedule management.

import SwiftUI
import DirectorsChairCore

// MARK: - Schedule View Mode

public enum ScheduleViewMode: String, CaseIterable {
    case monthly = "Monthly Calendar"
    case weekly = "Weekly Schedule"
    case daily = "Daily Schedule"
}

// MARK: - Schedule Status

public enum ScheduleStatus: String, CaseIterable {
    case planned = "Planned"
    case scheduled = "Scheduled"
    case inProgress = "In Progress"
    case complete = "Complete"
    case cancelled = "Cancelled"
    case postponed = "Postponed"

    var color: Color {
        switch self {
        case .planned: return .blue.opacity(0.6)
        case .scheduled: return .purple.opacity(0.6)
        case .inProgress: return .yellow.opacity(0.8)
        case .complete: return .green.opacity(0.6)
        case .cancelled: return .red.opacity(0.4)
        case .postponed: return .orange.opacity(0.6)
        }
    }
}

// MARK: - Schedule Filter

public enum ScheduleFilter: String, CaseIterable {
    case all = "All Items"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case plannedOnly = "Planned Only"
    case inProgress = "In Progress"
}

// MARK: - Schedule View

public struct ScheduleView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    @State private var viewMode: ScheduleViewMode = .monthly
    @State private var filter: ScheduleFilter = .all
    @State private var selectedDate: Date = Date()
    @State private var selectedItem: ScheduleItem?
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var showingOptimizeSheet = false
    @State private var showingConflicts = false

    public init(viewModel: ScheduleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            scheduleToolbar

            Divider()

            // Content based on view mode
            switch viewMode {
            case .monthly:
                monthlyCalendarView
            case .weekly:
                weeklyScheduleView
            case .daily:
                dailyScheduleView
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ScheduleItemEditorSheet(
                viewModel: viewModel,
                item: nil,
                defaultDate: selectedDate
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            if let item = selectedItem {
                ScheduleItemEditorSheet(
                    viewModel: viewModel,
                    item: item,
                    defaultDate: nil
                )
            }
        }
    }

    // MARK: - Toolbar

    private var scheduleToolbar: some View {
        VStack(spacing: 8) {
            // Row 1: Main Actions
            HStack(spacing: 12) {
                Button(action: { showingOptimizeSheet = true }) {
                    Label("Auto-Optimize", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.scheduleItems.isEmpty)

                Divider().frame(height: 20)

                Button(action: { showingAddSheet = true }) {
                    Label("Add Item", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button(action: removeSelectedItem) {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(selectedItem == nil)

                Divider().frame(height: 20)

                Button(action: exportCallSheet) {
                    Label("Export Call Sheet", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                .disabled(itemsForSelectedDate.isEmpty)

                Button(action: { showingConflicts = true }) {
                    Label("Check Conflicts", systemImage: "exclamationmark.triangle")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.scheduleItems.isEmpty)

                Spacer()
            }
            .padding(.horizontal)

            // Row 2: View Mode and Filters
            HStack(spacing: 12) {
                Text("View Mode:")
                    .foregroundColor(.secondary)

                Picker("View Mode", selection: $viewMode) {
                    ForEach(ScheduleViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)

                Divider().frame(height: 20)

                Text("Filter:")
                    .foregroundColor(.secondary)

                Picker("Filter", selection: $filter) {
                    ForEach(ScheduleFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .frame(width: 150)

                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Monthly Calendar View

    private var monthlyCalendarView: some View {
        HSplitView {
            // Left: Calendar
            VStack(alignment: .leading, spacing: 12) {
                GroupBox("Production Calendar") {
                    VStack(spacing: 12) {
                        DatePicker(
                            "Select Date",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .onChange(of: selectedDate) { _, newDate in
                            // Update selected item if date changes
                            if let firstItem = itemsForSelectedDate.first {
                                selectedItem = firstItem
                            } else {
                                selectedItem = nil
                            }
                        }

                        // Day Summary
                        daySummaryCard
                    }
                    .padding()
                }
            }
            .frame(minWidth: 350)
            .padding()

            // Right: Schedule Items + Details
            VStack(spacing: 12) {
                // Schedule Items List
                GroupBox("Schedule Items") {
                    VStack(spacing: 8) {
                        if itemsForSelectedDate.isEmpty {
                            Text("No shoots scheduled for \(formattedDate(selectedDate))")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(itemsForSelectedDate, selection: $selectedItem) { item in
                                ScheduleItemRow(item: item)
                                    .tag(item)
                            }
                        }

                        HStack {
                            Button("Edit Selected") {
                                showingEditSheet = true
                            }
                            .disabled(selectedItem == nil)

                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                }

                // Details Panel
                GroupBox("Details") {
                    if let item = selectedItem {
                        ScheduleItemDetailView(item: item)
                    } else {
                        Text("Select a schedule item to view details")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: 150)
                    }
                }

                // Statistics
                scheduleStatisticsCard
            }
            .frame(minWidth: 400)
            .padding()
        }
    }

    // MARK: - Weekly Schedule View

    private var weeklyScheduleView: some View {
        VStack(spacing: 12) {
            // Week Navigation
            HStack {
                Button(action: previousWeek) {
                    Label("Previous Week", systemImage: "chevron.left")
                }

                Button(action: goToCurrentWeek) {
                    Label("Today", systemImage: "calendar")
                }

                DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                    .labelsHidden()
                    .frame(width: 130)

                Text(weekRangeText)
                    .font(.headline)
                    .frame(maxWidth: .infinity)

                Button(action: nextWeek) {
                    Label("Next Week", systemImage: "chevron.right")
                }
            }
            .padding(.horizontal)

            // Weekly Grid
            ScrollView {
                WeeklyScheduleGrid(
                    weekStart: startOfWeek(for: selectedDate),
                    items: filteredItems,
                    onItemTap: { item in
                        selectedItem = item
                        showingEditSheet = true
                    }
                )
            }

            // Weekly Stats
            HStack {
                Text("Week Summary: \(itemsInCurrentWeek.count) schedule item(s)")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    // MARK: - Daily Schedule View

    private var dailyScheduleView: some View {
        VStack(spacing: 12) {
            // Day Navigation
            HStack {
                Button(action: previousDay) {
                    Label("Previous Day", systemImage: "chevron.left")
                }

                Button(action: goToToday) {
                    Label("Today", systemImage: "calendar")
                }

                DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                    .labelsHidden()
                    .frame(width: 130)

                Text(formattedDateFull(selectedDate))
                    .font(.headline)
                    .frame(maxWidth: .infinity)

                Button(action: nextDay) {
                    Label("Next Day", systemImage: "chevron.right")
                }
            }
            .padding(.horizontal)

            // Daily Schedule Table
            if itemsForSelectedDate.isEmpty {
                VStack {
                    Spacer()
                    Text("No shoots scheduled")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                DailyScheduleTable(
                    items: itemsForSelectedDate,
                    onItemTap: { item in
                        selectedItem = item
                        showingEditSheet = true
                    }
                )
            }

            // Daily Summary
            GroupBox("Daily Summary") {
                dailySummaryContent
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Supporting Views

    private var daySummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formattedDateFull(selectedDate))
                .font(.headline)

            if itemsForSelectedDate.isEmpty {
                Text("No shoots scheduled")
                    .foregroundColor(.secondary)
            } else {
                let totalHours = itemsForSelectedDate.reduce(0) { $0 + $1.estimatedDurationHours }
                let locations = Set(itemsForSelectedDate.compactMap { $0.location.isEmpty ? nil : $0.location })
                let castCount = Set(itemsForSelectedDate.flatMap { $0.requiredActors }).count

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(itemsForSelectedDate.count) schedule item(s)")
                    Text("Estimated Hours: \(String(format: "%.1f", totalHours))h")
                    Text("Locations: \(locations.isEmpty ? "None" : locations.joined(separator: ", "))")
                    Text("Cast: \(castCount) actor(s)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var scheduleStatisticsCard: some View {
        GroupBox("Schedule Statistics") {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.scheduleItems.isEmpty {
                    Text("No schedule items yet")
                        .foregroundColor(.secondary)
                } else {
                    let completed = viewModel.scheduleItems.filter { $0.status == "Complete" }.count
                    let inProgress = viewModel.scheduleItems.filter { $0.status == "In Progress" }.count
                    let scheduled = viewModel.scheduleItems.filter { $0.status == "Scheduled" }.count
                    let planned = viewModel.scheduleItems.filter { $0.status == "Planned" }.count
                    let uniqueDates = Set(viewModel.scheduleItems.compactMap { $0.shootDate })
                    let totalHours = viewModel.scheduleItems.reduce(0) { $0 + $1.estimatedDurationHours }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schedule Overview")
                            .font(.headline)

                        Text("Total Schedule Items: \(viewModel.scheduleItems.count)")
                        Text("Shooting Days: \(uniqueDates.count)")
                        Text("Total Estimated Hours: \(String(format: "%.1f", totalHours))h")

                        Divider()

                        Text("Status Breakdown")
                            .font(.headline)

                        HStack {
                            StatusBadge(label: "Completed", count: completed, color: .green)
                            StatusBadge(label: "In Progress", count: inProgress, color: .yellow)
                            StatusBadge(label: "Scheduled", count: scheduled, color: .purple)
                            StatusBadge(label: "Planned", count: planned, color: .blue)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding()
        }
    }

    private var dailySummaryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            let items = itemsForSelectedDate

            if items.isEmpty {
                Text("No schedule items for this day")
                    .foregroundColor(.secondary)
            } else {
                let totalHours = items.reduce(0) { $0 + $1.estimatedDurationHours }
                let locations = Set(items.compactMap { $0.location.isEmpty ? nil : $0.location })
                let allCast = Set(items.flatMap { $0.requiredActors })
                let allCrew = Set(items.flatMap { $0.requiredCrew })
                let allEquipment = Set(items.flatMap { $0.requiredEquipment })
                let completed = items.filter { $0.status == "Complete" }.count
                let inProgress = items.filter { $0.status == "In Progress" }.count

                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Summary").font(.headline)
                        Text("Total Scenes: \(items.count)")
                        Text("Estimated Hours: \(String(format: "%.1f", totalHours))h")
                        Text("Locations: \(locations.isEmpty ? "None" : locations.joined(separator: ", "))")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resources").font(.headline)
                        Text("Cast Members: \(allCast.count)")
                        Text("Crew Members: \(allCrew.count)")
                        Text("Equipment Items: \(allEquipment.count)")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status").font(.headline)
                        Text("\(completed) Complete")
                        Text("\(inProgress) In Progress")
                    }

                    Spacer()

                    Button("Generate Daily Overview") {
                        // TODO: Generate daily production overview
                    }
                    .buttonStyle(.borderedProminent)
                }
                .font(.caption)
            }
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var filteredItems: [ScheduleItem] {
        switch filter {
        case .all:
            return viewModel.scheduleItems
        case .thisWeek:
            let weekStart = startOfWeek(for: Date())
            let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart)!
            return viewModel.scheduleItems.filter { item in
                guard let dateStr = item.shootDate,
                      let date = parseDate(dateStr) else { return false }
                return date >= weekStart && date < weekEnd
            }
        case .thisMonth:
            let now = Date()
            let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))!
            let monthEnd = Calendar.current.date(byAdding: .month, value: 1, to: monthStart)!
            return viewModel.scheduleItems.filter { item in
                guard let dateStr = item.shootDate,
                      let date = parseDate(dateStr) else { return false }
                return date >= monthStart && date < monthEnd
            }
        case .plannedOnly:
            return viewModel.scheduleItems.filter { $0.status == "Planned" }
        case .inProgress:
            return viewModel.scheduleItems.filter { $0.status == "In Progress" }
        }
    }

    private var itemsForSelectedDate: [ScheduleItem] {
        let dateStr = formatDateForComparison(selectedDate)
        return viewModel.scheduleItems.filter { $0.shootDate == dateStr }
    }

    private var itemsInCurrentWeek: [ScheduleItem] {
        let weekStart = startOfWeek(for: selectedDate)
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart)!
        return viewModel.scheduleItems.filter { item in
            guard let dateStr = item.shootDate,
                  let date = parseDate(dateStr) else { return false }
            return date >= weekStart && date < weekEnd
        }
    }

    private var weekRangeText: String {
        let weekStart = startOfWeek(for: selectedDate)
        let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "Week of \(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }

    // MARK: - Actions

    private func removeSelectedItem() {
        guard let item = selectedItem else { return }
        viewModel.removeScheduleItem(item)
        selectedItem = nil
    }

    private func exportCallSheet() {
        // TODO: Export call sheet for selected day
    }

    private func previousWeek() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
    }

    private func nextWeek() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
    }

    private func goToCurrentWeek() {
        selectedDate = Date()
    }

    private func previousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    private func nextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    private func goToToday() {
        selectedDate = Date()
    }

    // MARK: - Date Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formattedDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatDateForComparison(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }

    private func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}

// MARK: - Schedule Item Row

struct ScheduleItemRow: View {
    let item: ScheduleItem

    var body: some View {
        HStack {
            statusIndicator

            VStack(alignment: .leading, spacing: 2) {
                Text(item.sceneName)
                    .font(.headline)

                HStack {
                    Text(item.timeSlot)
                    Text("-")
                    Text("\(String(format: "%.1f", item.estimatedDurationHours))h")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Text(item.status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    private var statusColor: Color {
        switch item.status {
        case "Complete": return .green
        case "In Progress": return .yellow
        case "Scheduled": return .purple
        case "Planned": return .blue
        case "Cancelled": return .red
        case "Postponed": return .orange
        default: return .gray
        }
    }
}

// MARK: - Schedule Item Detail View

struct ScheduleItemDetailView: View {
    let item: ScheduleItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.sceneName)
                    .font(.title2)
                    .fontWeight(.bold)

                Group {
                    InfoRow(label: "Date", value: item.shootDate ?? "Not scheduled")
                    InfoRow(label: "Time Slot", value: item.timeSlot)
                    InfoRow(label: "Status", value: item.status)
                    InfoRow(label: "Location", value: item.location.isEmpty ? "Not specified" : item.location)
                    InfoRow(label: "Duration", value: "\(String(format: "%.1f", item.estimatedDurationHours)) hours")
                }

                Divider()

                Text("Required Cast")
                    .font(.headline)
                Text(item.requiredActors.isEmpty ? "None" : item.requiredActors.joined(separator: ", "))
                    .foregroundColor(.secondary)

                Text("Required Equipment")
                    .font(.headline)
                Text(item.requiredEquipment.isEmpty ? "None" : item.requiredEquipment.joined(separator: ", "))
                    .foregroundColor(.secondary)

                if !item.productionNotes.isEmpty {
                    Divider()
                    Text("Production Notes")
                        .font(.headline)
                    Text(item.productionNotes)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
            Text(label)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .cornerRadius(4)
    }
}

// MARK: - Weekly Schedule Grid

struct WeeklyScheduleGrid: View {
    let weekStart: Date
    let items: [ScheduleItem]
    let onItemTap: (ScheduleItem) -> Void

    private let timeSlots = ["Morning", "Afternoon", "Evening", "Night", "Full Day"]
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 1, verticalSpacing: 1) {
            // Header row
            GridRow {
                Text("Time")
                    .frame(width: 80)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))

                ForEach(0..<7, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)!
                    VStack {
                        Text(weekdays[dayOffset])
                            .font(.headline)
                        Text(dayOfMonth(date))
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }

            // Time slot rows
            ForEach(timeSlots, id: \.self) { slot in
                GridRow {
                    Text(slot)
                        .frame(width: 80)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))

                    ForEach(0..<7, id: \.self) { dayOffset in
                        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)!
                        let dayItems = itemsFor(date: date, slot: slot)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(dayItems) { item in
                                Button(action: { onItemTap(item) }) {
                                    Text(item.sceneName)
                                        .font(.caption)
                                        .padding(4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(statusColor(for: item).opacity(0.3))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                    }
                }
            }
        }
        .padding()
    }

    private func dayOfMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func itemsFor(date: Date, slot: String) -> [ScheduleItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        return items.filter { $0.shootDate == dateStr && $0.timeSlot == slot }
    }

    private func statusColor(for item: ScheduleItem) -> Color {
        switch item.status {
        case "Complete": return .green
        case "In Progress": return .yellow
        case "Scheduled": return .purple
        case "Planned": return .blue
        default: return .gray
        }
    }
}

// MARK: - Daily Schedule Table

struct DailyScheduleTable: View {
    let items: [ScheduleItem]
    let onItemTap: (ScheduleItem) -> Void

    var body: some View {
        List {
            ForEach(items.sorted(by: { ($0.callTime ?? "00:00") < ($1.callTime ?? "00:00") })) { item in
                Button(action: { onItemTap(item) }) {
                    HStack {
                        // Clock Time
                        VStack {
                            if let callTime = item.callTime {
                                Text(callTime)
                                    .font(.headline)
                            }
                            if let wrapTime = item.wrapTime {
                                Text(wrapTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 80)

                        // Time Slot
                        Text(item.timeSlot)
                            .frame(width: 100)

                        // Scene/Activity
                        VStack(alignment: .leading) {
                            Text(item.sceneName)
                                .font(.headline)
                            Text("\(String(format: "%.1f", item.estimatedDurationHours))h")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Location
                        Text(item.location.isEmpty ? "Not specified" : item.location)
                            .frame(width: 150, alignment: .leading)

                        // Cast & Crew
                        VStack(alignment: .leading) {
                            Text("Cast: \(item.requiredActors.count)")
                            Text("Crew: \(item.requiredCrew.count)")
                        }
                        .font(.caption)
                        .frame(width: 100)
                    }
                    .padding(.vertical, 8)
                    .background(statusColor(for: item).opacity(0.1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statusColor(for item: ScheduleItem) -> Color {
        switch item.status {
        case "Complete": return .green
        case "In Progress": return .yellow
        case "Scheduled": return .purple
        case "Planned": return .blue
        default: return .gray
        }
    }
}

// MARK: - Schedule Item Editor Sheet

struct ScheduleItemEditorSheet: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let item: ScheduleItem?
    let defaultDate: Date?

    @Environment(\.dismiss) private var dismiss

    @State private var sceneName: String = ""
    @State private var sequenceName: String = ""
    @State private var shootDate: Date = Date()
    @State private var timeSlot: String = "Full Day"
    @State private var duration: Double = 4.0
    @State private var status: String = "Planned"
    @State private var location: String = ""
    @State private var callTime: String = ""
    @State private var productionNotes: String = ""

    private let timeSlots = ["Morning", "Afternoon", "Evening", "Night", "Full Day"]
    private let statuses = ["Planned", "Scheduled", "In Progress", "Complete", "Cancelled", "Postponed"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(item == nil ? "Add Schedule Item" : "Edit Schedule Item")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Scene Information") {
                    TextField("Scene Name", text: $sceneName)
                    TextField("Sequence Name", text: $sequenceName)
                }

                Section("Schedule Details") {
                    DatePicker("Shoot Date", selection: $shootDate, displayedComponents: [.date])

                    Picker("Time Slot", selection: $timeSlot) {
                        ForEach(timeSlots, id: \.self) { slot in
                            Text(slot).tag(slot)
                        }
                    }

                    HStack {
                        Text("Duration (hours)")
                        Slider(value: $duration, in: 0.5...16, step: 0.5)
                        Text("\(String(format: "%.1f", duration))h")
                    }

                    Picker("Status", selection: $status) {
                        ForEach(statuses, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                }

                Section("Location & Time") {
                    TextField("Location", text: $location)
                    TextField("Call Time (HH:MM)", text: $callTime)
                }

                Section("Production Notes") {
                    TextEditor(text: $productionNotes)
                        .frame(height: 100)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            if let item = item {
                sceneName = item.sceneName
                sequenceName = item.sequenceName
                if let dateStr = item.shootDate,
                   let date = parseDate(dateStr) {
                    shootDate = date
                }
                timeSlot = item.timeSlot
                duration = item.estimatedDurationHours
                status = item.status
                location = item.location
                callTime = item.callTime ?? ""
                productionNotes = item.productionNotes
            } else if let date = defaultDate {
                shootDate = date
            }
        }
    }

    private func save() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: shootDate)

        if var existingItem = item {
            existingItem.sceneName = sceneName
            existingItem.sequenceName = sequenceName
            existingItem.shootDate = dateStr
            existingItem.timeSlot = timeSlot
            existingItem.estimatedDurationHours = duration
            existingItem.status = status
            existingItem.location = location
            existingItem.callTime = callTime.isEmpty ? nil : callTime
            existingItem.productionNotes = productionNotes
            viewModel.updateScheduleItem(existingItem)
        } else {
            let newItem = ScheduleItem(
                sceneName: sceneName,
                sequenceName: sequenceName,
                shootDate: dateStr,
                timeSlot: timeSlot,
                estimatedDurationHours: duration,
                status: status,
                location: location,
                callTime: callTime.isEmpty ? nil : callTime,
                productionNotes: productionNotes
            )
            viewModel.addScheduleItem(newItem)
        }

        dismiss()
    }

    private func parseDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }
}
