// DirectorsChairProduction/Sources/DirectorsChairProduction/Schedule/ScheduleView.swift
//
// Schedule View - Production Schedule Calendar
// Redesigned with ProductionCard containers, chip filters, styled rows.

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
    let sequences: [DirectorsChairCore.Sequence]
    var onSceneStatusUpdate: ((_ sequenceName: String, _ sceneName: String, _ status: String) -> Void)?

    @State private var viewMode: ScheduleViewMode = .monthly
    @State private var filter: ScheduleFilter = .all
    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Date()
    @State private var selectedItem: ScheduleItem?
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var showingOptimizeSheet = false
    @State private var showingConflicts = false
    @State private var activeBadgePopover: String? = nil

    public init(viewModel: ScheduleViewModel, sequences: [DirectorsChairCore.Sequence] = [], onSceneStatusUpdate: ((_ sequenceName: String, _ sceneName: String, _ status: String) -> Void)? = nil) {
        self.viewModel = viewModel
        self.sequences = sequences
        self.onSceneStatusUpdate = onSceneStatusUpdate
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Action bar
            scheduleActionBar

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
                sequences: sequences,
                item: nil,
                defaultDate: selectedDate,
                onSceneStatusUpdate: onSceneStatusUpdate
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            if let item = selectedItem {
                ScheduleItemEditorSheet(
                    viewModel: viewModel,
                    sequences: sequences,
                    item: item,
                    defaultDate: nil,
                    onSceneStatusUpdate: onSceneStatusUpdate
                )
            }
        }
    }

    // MARK: - Action Bar

    private var scheduleActionBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ProductionActionButton(icon: "plus", "Add Item", prominent: true) {
                    showingAddSheet = true
                }

                ProductionActionButton(icon: "trash", "Remove", disabled: selectedItem == nil) {
                    removeSelectedItem()
                }

                ProductionActionButton(icon: "wand.and.stars", "Optimize", disabled: viewModel.scheduleItems.isEmpty) {
                    showingOptimizeSheet = true
                }

                Spacer()

                // View mode chips
                HStack(spacing: 6) {
                    ProductionChip(icon: "calendar", "Month", selected: viewMode == .monthly) {
                        viewMode = .monthly
                    }
                    ProductionChip(icon: "calendar.day.timeline.left", "Week", selected: viewMode == .weekly) {
                        viewMode = .weekly
                    }
                    ProductionChip(icon: "sun.max", "Day", selected: viewMode == .daily) {
                        viewMode = .daily
                    }
                }

                Spacer()

                // Filter chips
                HStack(spacing: 6) {
                    ProductionChip("All", selected: filter == .all) { filter = .all }
                    ProductionChip("This Week", selected: filter == .thisWeek) { filter = .thisWeek }
                    ProductionChip("Planned", selected: filter == .plannedOnly) { filter = .plannedOnly }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Monthly Calendar View

    private var monthlyCalendarView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Full-width custom calendar grid
                ProductionCard(icon: "calendar", title: "PRODUCTION CALENDAR") {
                    VStack(spacing: 0) {
                        // Month navigation header
                        monthNavigationHeader

                        // Weekday header row
                        weekdayHeaderRow

                        // Calendar day grid
                        calendarDayGrid
                    }
                }

                // Selected day detail panel (only shows when a day is selected)
                selectedDayPanel

                // Statistics row
                ProductionCard(icon: "chart.bar", title: "SCHEDULE OVERVIEW") {
                    scheduleStatistics
                }
            }
            .padding(16)
        }
    }

    // MARK: - Month Navigation

    private var monthNavigationHeader: some View {
        HStack(spacing: 12) {
            Button(action: { navigateMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthYearString(for: displayedMonth))
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Spacer()

            Button(action: { goToTodayMonth() }) {
                Text("Today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)

            Button(action: { navigateMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Weekday Header

    private var weekdayHeaderRow: some View {
        let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .background(Color(nsColor: .separatorColor).opacity(0.1))
    }

    // MARK: - Calendar Grid

    private var calendarDayGrid: some View {
        let weeks = calendarWeeks(for: displayedMonth)
        return VStack(spacing: 0) {
            ForEach(weeks.indices, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let dayInfo = weeks[weekIndex][dayIndex]
                        CalendarDayCell(
                            dayInfo: dayInfo,
                            items: itemsForDate(dayInfo.date),
                            isSelected: isSameDay(dayInfo.date, selectedDate),
                            isToday: isSameDay(dayInfo.date, Date()),
                            isCurrentMonth: dayInfo.isCurrentMonth
                        ) {
                            selectedDate = dayInfo.date
                            displayedMonth = dayInfo.date
                            if let firstItem = itemsForDate(dayInfo.date).first {
                                selectedItem = firstItem
                            } else {
                                selectedItem = nil
                            }
                        }
                    }
                }
                if weekIndex < weeks.count - 1 {
                    Divider().opacity(0.3)
                }
            }
        }
    }

    // MARK: - Selected Day Panel

    private var selectedDayPanel: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: Day header + schedule items
            ProductionCard(icon: "calendar.badge.clock", title: selectedDayTitle) {
                VStack(spacing: 12) {
                    // Day resource summary badges
                    dayResourceBadges

                    Divider()

                    // Schedule items list
                    if itemsForSelectedDate.isEmpty {
                        emptyDayPrompt
                    } else {
                        scheduleItemsList
                    }
                }
            }

            // Right: Selected item detail OR resource availability
            ProductionCard(icon: "doc.text", title: selectedItem != nil ? "ITEM DETAILS" : "RESOURCE AVAILABILITY") {
                if let item = selectedItem {
                    scheduleItemDetail(item)
                } else {
                    resourceAvailabilityPanel
                }
            }
            .frame(minWidth: 320)
        }
    }

    private var selectedDayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate).uppercased()
    }

    private var dayResourceBadges: some View {
        let items = itemsForSelectedDate
        let totalHours = items.reduce(0) { $0 + $1.estimatedDurationHours }
        let locationsList = Array(Set(items.compactMap { $0.location.isEmpty ? nil : $0.location })).sorted()
        let castList = Array(Set(items.flatMap { $0.requiredActors })).sorted()
        let propsList = Array(Set(items.flatMap { $0.requiredProps })).sorted()
        let crewList = Array(Set(items.flatMap { $0.requiredCrew })).sorted()
        let equipList = Array(Set(items.flatMap { $0.requiredEquipment })).sorted()

        return HStack(spacing: 8) {
            badgeButton(
                value: "\(items.count)", label: "Scenes", color: .blue, key: "scenes",
                content: items.map { $0.sceneName }
            )
            badgeButton(
                value: String(format: "%.1fh", totalHours), label: "Hours", color: .purple, key: "hours",
                content: items.map { "\($0.sceneName) — \(String(format: "%.1f", $0.estimatedDurationHours))h" }
            )
            badgeButton(
                value: "\(locationsList.count)", label: "Locations", color: .orange, key: "locations",
                content: locationsList
            )
            badgeButton(
                value: "\(castList.count)", label: "Cast", color: .green, key: "cast",
                content: castList
            )
            badgeButton(
                value: "\(propsList.count)", label: "Props", color: .yellow, key: "props",
                content: propsList
            )
            badgeButton(
                value: "\(crewList.count)", label: "Crew", color: .teal, key: "crew",
                content: crewList
            )
            badgeButton(
                value: "\(equipList.count)", label: "Equipment", color: .indigo, key: "equipment",
                content: equipList
            )
        }
    }

    private func badgeButton(value: String, label: String, color: Color, key: String, content: [String]) -> some View {
        Button(action: {
            if activeBadgePopover == key {
                activeBadgePopover = nil
            } else {
                activeBadgePopover = key
            }
        }) {
            ProductionStatBadge(value: value, label: label, color: color)
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(
            get: { activeBadgePopover == key },
            set: { if !$0 { activeBadgePopover = nil } }
        ), arrowEdge: .bottom) {
            BadgePopoverContent(title: label, color: color, items: content)
        }
    }

    private var emptyDayPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No shoots scheduled")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("Click \"Add Item\" to schedule a scene for this day, or use AI Optimize to auto-schedule based on availability.")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            ProductionActionButton(icon: "plus", "Schedule Scene", prominent: true) {
                showingAddSheet = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var resourceAvailabilityPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Date context
            Text(formattedDateFull(selectedDate))
                .font(.system(size: 12, weight: .semibold))

            Divider()

            // Location utilization
            ProductionSectionHeader(icon: "mappin.and.ellipse", title: "LOCATIONS IN USE")
            let locations = Set(itemsForSelectedDate.compactMap { $0.location.isEmpty ? nil : $0.location })
            if locations.isEmpty {
                Text("No locations booked")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(locations), id: \.self) { loc in
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text(loc)
                            .font(.system(size: 11))
                    }
                }
            }

            Divider()

            // Cast committed
            ProductionSectionHeader(icon: "person.2", title: "CAST COMMITTED")
            let cast = Set(itemsForSelectedDate.flatMap { $0.requiredActors })
            if cast.isEmpty {
                Text("No cast assigned")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                    ForEach(Array(cast).sorted(), id: \.self) { actor in
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                            Text(actor)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.1)))
                    }
                }
            }

            Divider()

            // Equipment committed
            ProductionSectionHeader(icon: "video", title: "EQUIPMENT IN USE")
            let equipment = Set(itemsForSelectedDate.flatMap { $0.requiredEquipment })
            if equipment.isEmpty {
                Text("No equipment assigned")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                    ForEach(Array(equipment).sorted(), id: \.self) { equip in
                        HStack(spacing: 4) {
                            Image(systemName: "wrench")
                                .font(.system(size: 8))
                                .foregroundColor(.indigo)
                            Text(equip)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.indigo.opacity(0.1)))
                    }
                }
            }

            Spacer()

            // AI hint
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                Text("AI can auto-schedule based on these constraints")
                    .font(.system(size: 10))
                    .foregroundColor(.purple.opacity(0.8))
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.purple.opacity(0.08)))
        }
    }

    // MARK: - Weekly Schedule View

    private var weeklyScheduleView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Week Navigation
                ProductionCard(icon: "calendar", title: "WEEKLY VIEW") {
                    VStack(spacing: 12) {
                        HStack {
                            ProductionActionButton(icon: "chevron.left", "Prev") {
                                previousWeek()
                            }
                            ProductionActionButton(icon: "calendar", "Today") {
                                goToCurrentWeek()
                            }

                            Text(weekRangeText)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)

                            ProductionActionButton(icon: "chevron.right", "Next") {
                                nextWeek()
                            }
                        }

                        // Weekly Grid
                        WeeklyScheduleGrid(
                            weekStart: startOfWeek(for: selectedDate),
                            items: filteredItems,
                            onItemTap: { item in
                                selectedItem = item
                                showingEditSheet = true
                            }
                        )
                    }
                }

                // Weekly Stats
                HStack(spacing: 12) {
                    ProductionStatBadge(
                        intValue: itemsInCurrentWeek.count,
                        label: "Items This Week",
                        color: .blue
                    )
                    ProductionStatBadge(
                        value: String(format: "%.1fh", itemsInCurrentWeek.reduce(0) { $0 + $1.estimatedDurationHours }),
                        label: "Total Hours",
                        color: .purple
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - Daily Schedule View

    private var dailyScheduleView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Day Navigation
                ProductionCard(icon: "sun.max", title: "DAILY SCHEDULE") {
                    VStack(spacing: 12) {
                        HStack {
                            ProductionActionButton(icon: "chevron.left", "Prev") {
                                previousDay()
                            }
                            ProductionActionButton(icon: "calendar", "Today") {
                                goToToday()
                            }

                            Text(formattedDateFull(selectedDate))
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)

                            ProductionActionButton(icon: "chevron.right", "Next") {
                                nextDay()
                            }
                        }

                        if itemsForSelectedDate.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.minus")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                                Text("No shoots scheduled")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            dailyItemsList
                        }
                    }
                }

                // Daily summary
                ProductionCard(icon: "chart.bar", title: "DAILY SUMMARY") {
                    dailySummaryStats
                }
            }
            .padding(16)
        }
    }

    // MARK: - Supporting Views

    private var scheduleItemsList: some View {
        VStack(spacing: 4) {
            if itemsForSelectedDate.isEmpty {
                Text("No shoots scheduled for \(formattedDate(selectedDate))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(itemsForSelectedDate) { item in
                            ScheduleItemRow(item: item, isSelected: selectedItem?.id == item.id)
                                .onTapGesture {
                                    selectedItem = item
                                }
                                .onTapGesture(count: 2) {
                                    selectedItem = item
                                    showingEditSheet = true
                                }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            HStack {
                ProductionActionButton(icon: "pencil", "Edit", disabled: selectedItem == nil) {
                    showingEditSheet = true
                }
                Spacer()
            }
        }
    }

    private func scheduleItemDetail(_ item: ScheduleItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Scene title + status hero
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "film.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                        Text(item.sceneName)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(2)
                    }

                    if !item.sequenceName.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(item.sequenceName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Status pill
                    HStack(spacing: 8) {
                        Text(item.status.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(statusColor(for: item))
                            )

                        if item.priority <= 2 {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                Text("HIGH PRIORITY")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(0.5)
                            }
                            .foregroundColor(.red)
                        }
                    }
                }

                // Key metrics grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    DetailMetricTile(
                        icon: "calendar",
                        label: "SHOOT DATE",
                        value: item.shootDate != nil ? formattedShootDate(item.shootDate!) : "Not set",
                        color: .blue
                    )
                    DetailMetricTile(
                        icon: "clock.fill",
                        label: "TIME SLOT",
                        value: item.timeSlot,
                        color: .purple
                    )
                    DetailMetricTile(
                        icon: "timer",
                        label: "DURATION",
                        value: "\(String(format: "%.1f", item.estimatedDurationHours))h",
                        color: .orange
                    )
                    DetailMetricTile(
                        icon: "mappin.and.ellipse",
                        label: "LOCATION",
                        value: item.location.isEmpty ? "Not set" : item.location,
                        color: .teal
                    )
                }

                // Call/Wrap times
                if item.callTime != nil || item.wrapTime != nil {
                    HStack(spacing: 12) {
                        if let call = item.callTime, !call.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "sunrise.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.yellow)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("CALL")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(0.8)
                                    Text(call)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                            }
                        }
                        if let wrap = item.wrapTime, !wrap.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "sunset.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("WRAP")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(0.8)
                                    Text(wrap)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow.opacity(0.08))
                    )
                }

                // Required Cast
                if !item.requiredActors.isEmpty {
                    DetailResourceSection(
                        icon: "person.2.fill",
                        title: "CAST",
                        color: .green,
                        items: item.requiredActors,
                        itemIcon: "person.fill"
                    )
                }

                // Required Props
                if !item.requiredProps.isEmpty {
                    DetailResourceSection(
                        icon: "cube.fill",
                        title: "PROPS",
                        color: .orange,
                        items: item.requiredProps,
                        itemIcon: "cube.fill"
                    )
                }

                // Required Equipment
                if !item.requiredEquipment.isEmpty {
                    DetailResourceSection(
                        icon: "video.fill",
                        title: "EQUIPMENT",
                        color: .indigo,
                        items: item.requiredEquipment,
                        itemIcon: "wrench.and.screwdriver.fill"
                    )
                }

                // Shots
                if !item.shotIds.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                        Text("SHOTS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.2)
                        Spacer()
                        Text("\(item.shotIds.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                    }
                }

                // Notes
                if !item.productionNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.system(size: 10))
                                .foregroundColor(.accentColor)
                            Text("NOTES")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(1.2)
                        }
                        Text(item.productionNotes)
                            .font(.system(size: 11))
                            .foregroundColor(.primary.opacity(0.8))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .quaternarySystemFill))
                            )
                    }
                }

                // Edit button
                HStack {
                    ProductionActionButton(icon: "pencil", "Edit Item", prominent: true) {
                        showingEditSheet = true
                    }
                    Spacer()
                }
            }
        }
    }

    private func formattedShootDate(_ dateStr: String) -> String {
        let inFormatter = DateFormatter()
        inFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inFormatter.date(from: dateStr) else { return dateStr }
        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "EEE, MMM d"
        return outFormatter.string(from: date)
    }

    private var scheduleStatistics: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.scheduleItems.isEmpty {
                Text("No schedule items yet")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                let completed = viewModel.scheduleItems.filter { $0.status == "Complete" }.count
                let inProgress = viewModel.scheduleItems.filter { $0.status == "In Progress" }.count
                let scheduled = viewModel.scheduleItems.filter { $0.status == "Scheduled" }.count
                let planned = viewModel.scheduleItems.filter { $0.status == "Planned" }.count
                let uniqueDates = Set(viewModel.scheduleItems.compactMap { $0.shootDate })
                let totalHours = viewModel.scheduleItems.reduce(0) { $0 + $1.estimatedDurationHours }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ProductionStatBadge(intValue: viewModel.scheduleItems.count, label: "Total", color: .blue)
                    ProductionStatBadge(intValue: uniqueDates.count, label: "Shoot Days", color: .purple)
                    ProductionStatBadge(value: String(format: "%.0fh", totalHours), label: "Est. Hours", color: .orange)
                }

                // Status breakdown as chips
                HStack(spacing: 6) {
                    statusChip("Completed", count: completed, color: .green)
                    statusChip("In Progress", count: inProgress, color: .yellow)
                    statusChip("Scheduled", count: scheduled, color: .purple)
                    statusChip("Planned", count: planned, color: .blue)
                }
            }
        }
    }

    private func statusChip(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }

    private var dailyItemsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(itemsForSelectedDate.sorted(by: { ($0.callTime ?? "00:00") < ($1.callTime ?? "00:00") })) { item in
                    Button(action: {
                        selectedItem = item
                        showingEditSheet = true
                    }) {
                        HStack(spacing: 12) {
                            // Time
                            VStack(spacing: 2) {
                                if let callTime = item.callTime {
                                    Text(callTime)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                if let wrapTime = item.wrapTime {
                                    Text(wrapTime)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: 60)

                            // Scene info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.sceneName)
                                    .font(.system(size: 12, weight: .semibold))
                                HStack(spacing: 8) {
                                    Text(item.timeSlot)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.1f", item.estimatedDurationHours))h")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Location
                            if !item.location.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Text(item.location)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Status
                            Text(item.status)
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(statusColor(for: item).opacity(0.2))
                                )
                                .foregroundColor(statusColor(for: item))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(statusColor(for: item).opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dailySummaryStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            let items = itemsForSelectedDate

            if items.isEmpty {
                Text("No schedule items for this day")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                let totalHours = items.reduce(0) { $0 + $1.estimatedDurationHours }
                let locations = Set(items.compactMap { $0.location.isEmpty ? nil : $0.location })
                let allCast = Set(items.flatMap { $0.requiredActors })
                let allCrew = Set(items.flatMap { $0.requiredCrew })
                let completed = items.filter { $0.status == "Complete" }.count

                HStack(spacing: 12) {
                    ProductionStatBadge(intValue: items.count, label: "Scenes", color: .blue)
                    ProductionStatBadge(value: String(format: "%.1fh", totalHours), label: "Hours", color: .purple)
                    ProductionStatBadge(intValue: locations.count, label: "Locations", color: .orange)
                    ProductionStatBadge(intValue: allCast.count, label: "Cast", color: .green)
                    ProductionStatBadge(intValue: allCrew.count, label: "Crew", color: .teal)
                    ProductionStatBadge(intValue: completed, label: "Complete", color: .mint)
                }
            }
        }
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

    private func statusColor(for item: ScheduleItem) -> Color {
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

    // MARK: - Calendar Helpers

    private func navigateMonth(by offset: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func goToTodayMonth() {
        displayedMonth = Date()
        selectedDate = Date()
        selectedItem = nil
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    private func itemsForDate(_ date: Date) -> [ScheduleItem] {
        let dateStr = formatDateForComparison(date)
        return viewModel.scheduleItems.filter { $0.shootDate == dateStr }
    }

    /// Build a 2D array of DayInfo for the calendar grid
    private func calendarWeeks(for month: Date) -> [[DayInfo]] {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let monthRange = calendar.range(of: .day, in: .month, for: monthStart)!

        // Find which weekday the month starts on (0 = Sunday)
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1 // 0-based

        // Build all day slots
        var days: [DayInfo] = []

        // Leading days from previous month
        for offset in (0..<firstWeekday).reversed() {
            let date = calendar.date(byAdding: .day, value: -(offset + 1), to: monthStart)!
            days.append(DayInfo(date: date, dayNumber: calendar.component(.day, from: date), isCurrentMonth: false))
        }

        // Current month days
        for day in monthRange {
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            days.append(DayInfo(date: date, dayNumber: day, isCurrentMonth: true))
        }

        // Trailing days to fill last week
        while days.count % 7 != 0 {
            let lastDate = days.last!.date
            let nextDate = calendar.date(byAdding: .day, value: 1, to: lastDate)!
            days.append(DayInfo(date: nextDate, dayNumber: calendar.component(.day, from: nextDate), isCurrentMonth: false))
        }

        // Chunk into weeks
        var weeks: [[DayInfo]] = []
        for i in stride(from: 0, to: days.count, by: 7) {
            weeks.append(Array(days[i..<min(i + 7, days.count)]))
        }

        return weeks
    }
}

// MARK: - Day Info

struct DayInfo {
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let dayInfo: DayInfo
    let items: [ScheduleItem]
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Day number
                Text("\(dayInfo.dayNumber)")
                    .font(.system(size: 13, weight: isToday ? .bold : (isSelected ? .semibold : .regular), design: .rounded))
                    .foregroundColor(dayNumberColor)

                // Schedule indicators
                if items.isEmpty {
                    Spacer()
                        .frame(height: 36)
                } else if items.count <= 2 {
                    // Show scene labels for 1-2 items
                    VStack(spacing: 2) {
                        ForEach(items.prefix(2)) { item in
                            Text(item.sceneName)
                                .font(.system(size: 8, weight: .medium))
                                .lineLimit(1)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(itemStatusColor(item).opacity(0.3))
                                )
                                .foregroundColor(itemStatusColor(item))
                        }
                        if items.count == 1 {
                            Spacer().frame(height: 14)
                        }
                    }
                } else {
                    // Show first item + dot count for 3+
                    VStack(spacing: 2) {
                        Text(items.first!.sceneName)
                            .font(.system(size: 8, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(itemStatusColor(items.first!).opacity(0.3))
                            )
                            .foregroundColor(itemStatusColor(items.first!))

                        // Colored dots for remaining
                        HStack(spacing: 3) {
                            ForEach(items.dropFirst().prefix(4)) { item in
                                Circle()
                                    .fill(itemStatusColor(item))
                                    .frame(width: 5, height: 5)
                            }
                            if items.count > 5 {
                                Text("+\(items.count - 5)")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Item count badge (bottom)
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.accentColor))
                } else {
                    Spacer()
                        .frame(height: 16)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(cellBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var dayNumberColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.4)
        }
        if isToday {
            return .accentColor
        }
        if isSelected {
            return .accentColor
        }
        return .primary
    }

    private var cellBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        if isToday && !isSelected {
            return Color.accentColor.opacity(0.05)
        }
        if isHovered {
            return Color(nsColor: .quaternarySystemFill)
        }
        if !isCurrentMonth {
            return Color.clear.opacity(0)
        }
        return Color.clear
    }

    private func itemStatusColor(_ item: ScheduleItem) -> Color {
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

// MARK: - Schedule Item Row

struct ScheduleItemRow: View {
    let item: ScheduleItem
    var isSelected: Bool = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.sceneName)
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 6) {
                    Text(item.timeSlot)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", item.estimatedDurationHours))h")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(item.status)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor.opacity(0.2))
                )
                .foregroundColor(statusColor)
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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .frame(width: 80)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                ForEach(0..<7, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)!
                    VStack(spacing: 2) {
                        Text(weekdays[dayOffset])
                            .font(.system(size: 11, weight: .semibold))
                        Text(dayOfMonth(date))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                }
            }

            // Time slot rows
            ForEach(timeSlots, id: \.self) { slot in
                GridRow {
                    Text(slot)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 80)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

                    ForEach(0..<7, id: \.self) { dayOffset in
                        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)!
                        let dayItems = itemsFor(date: date, slot: slot)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(dayItems) { item in
                                Button(action: { onItemTap(item) }) {
                                    Text(item.sceneName)
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(statusColor(for: item).opacity(0.2))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                    }
                }
            }
        }
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

// MARK: - Schedule Item Editor Sheet

struct ScheduleItemEditorSheet: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let sequences: [DirectorsChairCore.Sequence]
    let item: ScheduleItem?
    let defaultDate: Date?
    var onSceneStatusUpdate: ((_ sequenceName: String, _ sceneName: String, _ status: String) -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Scene selection
    @State private var selectedSequenceIndex: Int? = nil
    @State private var selectedSceneIndex: Int? = nil
    @State private var sceneSearchText: String = ""

    // Schedule fields
    @State private var shootDate: Date = Date()
    @State private var timeSlot: String = "Full Day"
    @State private var duration: Double = 4.0
    @State private var status: String = "Planned"
    @State private var location: String = ""
    @State private var callTime: String = ""
    @State private var wrapTime: String = ""
    @State private var useExactTime: Bool = false
    @State private var exactStartTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var exactEndTime: Date = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
    @State private var productionNotes: String = ""

    // Auto-populated resources (editable)
    @State private var requiredActors: [String] = []
    @State private var requiredProps: [String] = []
    @State private var requiredEquipment: [String] = []
    @State private var shotIds: [String] = []

    // For editing existing items without matching sequence/scene
    @State private var manualSceneName: String = ""
    @State private var manualSequenceName: String = ""
    @State private var isManualEntry: Bool = false

    private let timeSlots = ["Morning", "Afternoon", "Evening", "Night", "Full Day"]
    private let statuses = ["Planned", "Scheduled", "In Progress", "Complete", "Cancelled", "Postponed"]

    private var selectedSequence: DirectorsChairCore.Sequence? {
        guard let idx = selectedSequenceIndex, idx < sequences.count else { return nil }
        return sequences[idx]
    }

    private var selectedScene: DirectorsChairCore.Scene? {
        guard let seq = selectedSequence,
              let idx = selectedSceneIndex, idx < seq.scenes.count else { return nil }
        return seq.scenes[idx]
    }

    private var sceneName: String {
        if isManualEntry { return manualSceneName }
        return selectedScene?.name ?? ""
    }

    private var sequenceName: String {
        if isManualEntry { return manualSequenceName }
        return selectedSequence?.name ?? ""
    }

    private var filteredSequences: [DirectorsChairCore.Sequence] {
        if sceneSearchText.isEmpty { return sequences }
        let query = sceneSearchText.lowercased()
        return sequences.filter { seq in
            seq.name.lowercased().contains(query) ||
            seq.scenes.contains(where: { $0.name.lowercased().contains(query) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: item == nil ? "Schedule Scene" : "Edit Schedule Item",
                canSave: !sceneName.isEmpty
            ) {
                dismiss()
            } onSave: {
                save()
            }

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Scene Picker
                    scenePickerCard

                    // Auto-populated scene info (shown after selection)
                    if selectedScene != nil || isManualEntry {
                        // Schedule Details
                        scheduleDetailsCard

                        // Resources (auto-populated, editable)
                        resourcesCard

                        // Location & Time
                        locationTimeCard

                        // Notes
                        notesCard
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 600, height: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { loadExistingItem() }
    }

    // MARK: - Scene Picker Card

    private var scenePickerCard: some View {
        ProductionCard(icon: "film.stack", title: "SELECT SCENE") {
            VStack(spacing: 12) {
                // Toggle between pick and manual
                HStack(spacing: 8) {
                    ProductionChip(icon: "list.bullet", "Pick from Project", selected: !isManualEntry) {
                        isManualEntry = false
                    }
                    ProductionChip(icon: "pencil", "Manual Entry", selected: isManualEntry) {
                        isManualEntry = true
                    }
                    Spacer()
                }

                if isManualEntry {
                    manualEntryFields
                } else {
                    projectScenePicker
                }
            }
        }
    }

    private var manualEntryFields: some View {
        VStack(spacing: 10) {
            StyledTextField("Scene Name", text: $manualSceneName)
            StyledTextField("Sequence Name", text: $manualSequenceName)
        }
    }

    private var projectScenePicker: some View {
        VStack(spacing: 10) {
            // Search
            ProductionSearchField(text: $sceneSearchText)

            if sequences.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No sequences in project")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Add scenes in the Script view first, or use Manual Entry.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                // Sequence chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("SEQUENCE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(filteredSequences.enumerated()), id: \.element.name) { idx, seq in
                                let realIndex = sequences.firstIndex(where: { $0.name == seq.name }) ?? idx
                                SequenceChip(
                                    name: seq.name,
                                    sceneCount: seq.scenes.count,
                                    isSelected: selectedSequenceIndex == realIndex
                                ) {
                                    if selectedSequenceIndex == realIndex {
                                        selectedSequenceIndex = nil
                                        selectedSceneIndex = nil
                                    } else {
                                        selectedSequenceIndex = realIndex
                                        selectedSceneIndex = nil
                                    }
                                }
                            }
                        }
                    }
                }

                // Scene list for selected sequence
                if let seq = selectedSequence {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SCENES IN \(seq.name.uppercased())")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.2)

                        let filteredScenes: [(Int, DirectorsChairCore.Scene)] = {
                            let scenes = Array(seq.scenes.enumerated())
                            if sceneSearchText.isEmpty { return scenes }
                            let query = sceneSearchText.lowercased()
                            return scenes.filter { $0.1.name.lowercased().contains(query) }
                        }()

                        if filteredScenes.isEmpty {
                            Text("No matching scenes")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 4) {
                                    ForEach(filteredScenes, id: \.1.name) { idx, scene in
                                        ScenePickerRow(
                                            scene: scene,
                                            isSelected: selectedSceneIndex == idx,
                                            isAlreadyScheduled: isSceneScheduled(scene.name, in: seq.name)
                                        ) {
                                            selectedSceneIndex = idx
                                            autoPopulateFromScene(scene, sequence: seq)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 180)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Schedule Details Card

    private var scheduleDetailsCard: some View {
        ProductionCard(icon: "calendar", title: "SCHEDULE DETAILS") {
            VStack(spacing: 12) {
                DatePicker("Shoot Date", selection: $shootDate, displayedComponents: [.date])
                    .font(.system(size: 12))

                // Time Slot chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("TIME SLOT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.2)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                        ForEach(timeSlots, id: \.self) { slot in
                            ProductionChip(slot, selected: timeSlot == slot) {
                                timeSlot = slot
                                applyTimeSlotDefaults(slot)
                            }
                        }
                    }
                }

                // Exact Time toggle + pickers
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ProductionChip(icon: "clock.badge", "Set Exact Time", selected: useExactTime) {
                            useExactTime.toggle()
                            if useExactTime && callTime.isEmpty {
                                applyTimeSlotDefaults(timeSlot)
                            }
                        }
                        Spacer()
                        if useExactTime {
                            Text("For Gantt chart & detailed scheduling")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }

                    if useExactTime {
                        HStack(spacing: 16) {
                            // Start time
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sunrise.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.yellow)
                                    Text("START")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(0.8)
                                }
                                DatePicker("", selection: $exactStartTime, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .font(.system(size: 12))
                                    .onChange(of: exactStartTime) { _, newValue in
                                        callTime = formatTime(newValue)
                                        recalcDurationFromTimes()
                                    }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.yellow.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.yellow.opacity(0.15), lineWidth: 1)
                            )

                            // End time
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sunset.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                    Text("END")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .tracking(0.8)
                                }
                                DatePicker("", selection: $exactEndTime, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .font(.system(size: 12))
                                    .onChange(of: exactEndTime) { _, newValue in
                                        wrapTime = formatTime(newValue)
                                        recalcDurationFromTimes()
                                    }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                            )

                            // Computed duration
                            VStack(spacing: 2) {
                                Text(String(format: "%.1fh", computedDurationFromTimes))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.accentColor)
                                Text("DURATION")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .tracking(0.8)
                            }
                            .frame(minWidth: 60)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                }

                // Duration (only show manual slider when NOT using exact time)
                if !useExactTime {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("DURATION")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                                .tracking(1.2)
                            Spacer()
                            Text("\(String(format: "%.1f", duration))h")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.accentColor)
                        }
                        Slider(value: $duration, in: 0.5...16, step: 0.5)
                            .tint(.accentColor)
                    }
                }

                // Status chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("STATUS")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.2)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                        ForEach(statuses, id: \.self) { s in
                            ProductionChip(s, selected: status == s) {
                                status = s
                            }
                        }
                    }
                }
            }
        }
    }

    private func applyTimeSlotDefaults(_ slot: String) {
        guard useExactTime else { return }
        let cal = Calendar.current
        switch slot {
        case "Morning":
            exactStartTime = cal.date(from: DateComponents(hour: 6, minute: 0)) ?? exactStartTime
            exactEndTime = cal.date(from: DateComponents(hour: 12, minute: 0)) ?? exactEndTime
        case "Afternoon":
            exactStartTime = cal.date(from: DateComponents(hour: 12, minute: 0)) ?? exactStartTime
            exactEndTime = cal.date(from: DateComponents(hour: 18, minute: 0)) ?? exactEndTime
        case "Evening":
            exactStartTime = cal.date(from: DateComponents(hour: 18, minute: 0)) ?? exactStartTime
            exactEndTime = cal.date(from: DateComponents(hour: 22, minute: 0)) ?? exactEndTime
        case "Night":
            exactStartTime = cal.date(from: DateComponents(hour: 22, minute: 0)) ?? exactStartTime
            exactEndTime = cal.date(from: DateComponents(hour: 6, minute: 0)) ?? exactEndTime
        case "Full Day":
            exactStartTime = cal.date(from: DateComponents(hour: 6, minute: 0)) ?? exactStartTime
            exactEndTime = cal.date(from: DateComponents(hour: 22, minute: 0)) ?? exactEndTime
        default:
            break
        }
        callTime = formatTime(exactStartTime)
        wrapTime = formatTime(exactEndTime)
        recalcDurationFromTimes()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func parseTime(_ timeStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeStr)
    }

    private var computedDurationFromTimes: Double {
        let cal = Calendar.current
        let startComps = cal.dateComponents([.hour, .minute], from: exactStartTime)
        let endComps = cal.dateComponents([.hour, .minute], from: exactEndTime)
        let startMinutes = (startComps.hour ?? 0) * 60 + (startComps.minute ?? 0)
        let endMinutes = (endComps.hour ?? 0) * 60 + (endComps.minute ?? 0)
        let diff = endMinutes >= startMinutes ? endMinutes - startMinutes : (24 * 60 - startMinutes + endMinutes)
        return max(0.5, Double(diff) / 60.0)
    }

    private func recalcDurationFromTimes() {
        duration = (computedDurationFromTimes * 2).rounded() / 2 // Round to nearest 0.5
    }

    // MARK: - Resources Card

    private var resourcesCard: some View {
        ProductionCard(icon: "person.3", title: "REQUIREMENTS (AUTO-POPULATED)") {
            VStack(alignment: .leading, spacing: 12) {
                // Cast
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("CAST")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.2)
                        Spacer()
                        Text("\(requiredActors.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    if requiredActors.isEmpty {
                        Text("No characters in this scene")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                            ForEach(requiredActors, id: \.self) { actor in
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                    Text(actor)
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.1)))
                            }
                        }
                    }
                }

                Divider().opacity(0.3)

                // Props
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "cube")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("PROPS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.2)
                        Spacer()
                        Text("\(requiredProps.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    if requiredProps.isEmpty {
                        Text("No props listed")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 4) {
                            ForEach(requiredProps, id: \.self) { prop in
                                HStack(spacing: 4) {
                                    Image(systemName: "cube.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.orange)
                                    Text(prop)
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.1)))
                            }
                        }
                    }
                }

                Divider().opacity(0.3)

                // Shots
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                        Text("SHOTS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(1.2)
                        Spacer()
                        Text("\(shotIds.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                    }
                    if shotIds.isEmpty {
                        Text("No shots planned")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    } else {
                        Text("\(shotIds.count) shot(s) linked")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                    }
                }

                // AI hint
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                    Text("AI will use these requirements to optimize scheduling and detect conflicts")
                        .font(.system(size: 10))
                        .foregroundColor(.purple.opacity(0.8))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.purple.opacity(0.08)))
            }
        }
    }

    // MARK: - Location & Time Card

    private var locationTimeCard: some View {
        ProductionCard(icon: "mappin", title: "LOCATION") {
            VStack(spacing: 10) {
                // Location field (auto-populated but editable)
                VStack(alignment: .leading, spacing: 4) {
                    if !location.isEmpty, let scene = selectedScene, scene.location == location {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text("Auto-filled from scene")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                        }
                    }
                    StyledTextField("Location", text: $location)
                }
            }
        }
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        ProductionCard(icon: "note.text", title: "PRODUCTION NOTES") {
            TextEditor(text: $productionNotes)
                .font(.system(size: 12))
                .frame(height: 80)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .quaternarySystemFill))
                )
        }
    }

    // MARK: - Auto-populate

    private func autoPopulateFromScene(_ scene: DirectorsChairCore.Scene, sequence: DirectorsChairCore.Sequence) {
        // Location
        if let sceneLoc = scene.location, !sceneLoc.isEmpty {
            location = sceneLoc
        } else if let seqLoc = sequence.location, !seqLoc.isEmpty {
            location = seqLoc
        }

        // Characters from dialogues
        let characters = Set(scene.dialogues.map { $0.character }).sorted()
        requiredActors = characters

        // Props
        requiredProps = scene.props

        // Shot IDs
        shotIds = scene.shots.map { $0.id }

        // Estimate duration based on content
        let dialogueCount = scene.dialogues.count
        let actionCount = scene.actions.count
        let shotCount = scene.shots.count
        let contentItems = dialogueCount + actionCount
        if contentItems > 0 {
            // Rough estimate: ~15 min per content item, minimum 1h
            let estimated = max(1.0, Double(contentItems) * 0.25)
            duration = min(16.0, (estimated * 2).rounded() / 2) // Round to nearest 0.5
        }
    }

    private func isSceneScheduled(_ sceneName: String, in sequenceName: String) -> Bool {
        viewModel.scheduleItems.contains { $0.sceneName == sceneName && $0.sequenceName == sequenceName }
    }

    // MARK: - Load Existing

    private func loadExistingItem() {
        if let item = item {
            // Try to match to existing sequence/scene
            if let seqIdx = sequences.firstIndex(where: { $0.name == item.sequenceName }),
               let sceneIdx = sequences[seqIdx].scenes.firstIndex(where: { $0.name == item.sceneName }) {
                selectedSequenceIndex = seqIdx
                selectedSceneIndex = sceneIdx
            } else {
                // Fallback to manual entry
                isManualEntry = true
                manualSceneName = item.sceneName
                manualSequenceName = item.sequenceName
            }

            if let dateStr = item.shootDate, let date = parseDate(dateStr) {
                shootDate = date
            }
            timeSlot = item.timeSlot
            duration = item.estimatedDurationHours
            status = item.status
            location = item.location
            callTime = item.callTime ?? ""
            wrapTime = item.wrapTime ?? ""
            productionNotes = item.productionNotes
            requiredActors = item.requiredActors
            requiredProps = item.requiredProps
            requiredEquipment = item.requiredEquipment
            shotIds = item.shotIds

            // Restore exact time state
            if let ct = item.callTime, !ct.isEmpty {
                useExactTime = true
                if let startDate = parseTime(ct) {
                    exactStartTime = startDate
                }
                if let wt = item.wrapTime, !wt.isEmpty, let endDate = parseTime(wt) {
                    exactEndTime = endDate
                }
            }
        } else if let date = defaultDate {
            shootDate = date
        }
    }

    // MARK: - Save

    private func save() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: shootDate)

        let finalSceneName = sceneName
        let finalSequenceName = sequenceName

        let finalCallTime = callTime.isEmpty ? nil : callTime
        let finalWrapTime = wrapTime.isEmpty ? nil : wrapTime

        // Save exactly the status the user chose. (The previous "auto-promote
        // Planned to Scheduled when a date is set" always fired — shootDate is
        // non-optional so dateStr is never empty — which made "Planned"
        // impossible to save.)
        let finalStatus = status

        if var existingItem = item {
            // Store the scene's stable id; preserve the existing link when the
            // picker was left untouched (selectedScene == nil).
            existingItem.sceneId = selectedScene?.id ?? existingItem.sceneId
            existingItem.sceneName = finalSceneName
            existingItem.sequenceName = finalSequenceName
            existingItem.shotIds = shotIds
            existingItem.shootDate = dateStr
            existingItem.timeSlot = timeSlot
            existingItem.estimatedDurationHours = duration
            existingItem.status = finalStatus
            existingItem.location = location
            existingItem.callTime = finalCallTime
            existingItem.wrapTime = finalWrapTime
            existingItem.productionNotes = productionNotes
            existingItem.requiredActors = requiredActors
            existingItem.requiredProps = requiredProps
            existingItem.requiredEquipment = requiredEquipment
            viewModel.updateScheduleItem(existingItem)
        } else {
            let newItem = ScheduleItem(
                sceneId: selectedScene?.id,
                sceneName: finalSceneName,
                sequenceName: finalSequenceName,
                shotIds: shotIds,
                shootDate: dateStr,
                timeSlot: timeSlot,
                estimatedDurationHours: duration,
                status: finalStatus,
                location: location,
                requiredActors: requiredActors,
                requiredEquipment: requiredEquipment,
                requiredProps: requiredProps,
                productionNotes: productionNotes,
                callTime: finalCallTime,
                wrapTime: finalWrapTime
            )
            viewModel.addScheduleItem(newItem)
        }

        // Reflect the chosen status on the scene, not a hardcoded "Scheduled"
        // (which previously overrode Cancelled/Complete/Postponed).
        if !finalSceneName.isEmpty && !finalSequenceName.isEmpty {
            onSceneStatusUpdate?(finalSequenceName, finalSceneName, finalStatus)
        }

        dismiss()
    }

    private func parseDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }
}

// MARK: - Sequence Chip

// MARK: - Detail Metric Tile

// MARK: - Badge Popover Content

private struct BadgePopoverContent: View {
    let title: String
    let color: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
                Spacer()
                Text("\(items.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(0.06))

            Divider().opacity(0.3)

            if items.isEmpty {
                Text("None for this day")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(color.opacity(0.6))
                                    .frame(width: 18)
                                Text(item)
                                    .font(.system(size: 12))
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)

                            if index < items.count - 1 {
                                Divider().opacity(0.15).padding(.leading, 40)
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Detail Metric Tile

private struct DetailMetricTile: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.8)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Detail Resource Section

private struct DetailResourceSection: View {
    let icon: String
    let title: String
    let color: Color
    let items: [String]
    let itemIcon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
                Spacer()
                Text("\(items.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 5) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 4) {
                        Image(systemName: itemIcon)
                            .font(.system(size: 8))
                            .foregroundColor(color)
                        Text(item)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color.opacity(0.08))
                    )
                }
            }
        }
    }
}

// MARK: - Sequence Chip

private struct SequenceChip: View {
    let name: String
    let sceneCount: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text("\(sceneCount)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(isSelected ? Color.white.opacity(0.2) : Color(nsColor: .separatorColor).opacity(0.3))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color(nsColor: .quaternarySystemFill).opacity(0.8) : Color(nsColor: .quaternarySystemFill)))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Scene Picker Row

private struct ScenePickerRow: View {
    let scene: DirectorsChairCore.Scene
    let isSelected: Bool
    let isAlreadyScheduled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Scene icon
                Image(systemName: "film")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 20)

                // Scene info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(scene.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        if isAlreadyScheduled {
                            Text("SCHEDULED")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(isSelected ? Color.white.opacity(0.2) : Color.orange.opacity(0.15))
                                )
                        }
                    }

                    HStack(spacing: 8) {
                        if let loc = scene.location, !loc.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 8))
                                Text(loc)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        }

                        let charCount = Set(scene.dialogues.map { $0.character }).count
                        if charCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 8))
                                Text("\(charCount)")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        }

                        if !scene.shots.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "camera")
                                    .font(.system(size: 8))
                                Text("\(scene.shots.count)")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        }

                        if !scene.props.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "cube")
                                    .font(.system(size: 8))
                                Text("\(scene.props.count)")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        }
                    }
                }

                Spacer()

                // Status badge
                Text(scene.productionStatus)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Color.white.opacity(0.2) : sceneStatusColor.opacity(0.15))
                    )
                    .foregroundColor(isSelected ? .white : sceneStatusColor)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color(nsColor: .quaternarySystemFill) : Color.clear))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }

    private var sceneStatusColor: Color {
        switch scene.productionStatus {
        case "Ready": return .green
        case "Scheduled": return .purple
        case "Shooting", "In Progress": return .yellow
        case "Shot", "Complete": return .green
        default: return .blue
        }
    }
}
