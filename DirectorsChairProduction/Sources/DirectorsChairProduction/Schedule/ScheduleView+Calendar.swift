//
// ScheduleView+Calendar.swift
//
// Extracted from ScheduleView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore

extension ScheduleView {

    // MARK: - Action Bar

    var scheduleActionBar: some View {
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

    var monthlyCalendarView: some View {
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

    var monthNavigationHeader: some View {
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

    var weekdayHeaderRow: some View {
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

    var calendarDayGrid: some View {
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

    var selectedDayPanel: some View {
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

    var selectedDayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate).uppercased()
    }

    var dayResourceBadges: some View {
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

    func badgeButton(value: String, label: String, color: Color, key: String, content: [String]) -> some View {
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

    var emptyDayPrompt: some View {
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

    var resourceAvailabilityPanel: some View {
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

    var weeklyScheduleView: some View {
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
}
