//
// ScheduleView+Daily.swift
//
// Extracted from ScheduleView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore

extension ScheduleView {

    // MARK: - Daily Schedule View

    var dailyScheduleView: some View {
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

    var scheduleItemsList: some View {
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

    func scheduleItemDetail(_ item: ScheduleItem) -> some View {
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

    func formattedShootDate(_ dateStr: String) -> String {
        let inFormatter = DateFormatter()
        inFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inFormatter.date(from: dateStr) else { return dateStr }
        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "EEE, MMM d"
        return outFormatter.string(from: date)
    }

    var scheduleStatistics: some View {
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

    func statusChip(_ label: String, count: Int, color: Color) -> some View {
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

    var dailyItemsList: some View {
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

    var dailySummaryStats: some View {
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

    var filteredItems: [ScheduleItem] {
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

    var itemsForSelectedDate: [ScheduleItem] {
        let dateStr = formatDateForComparison(selectedDate)
        return viewModel.scheduleItems.filter { $0.shootDate == dateStr }
    }

    var itemsInCurrentWeek: [ScheduleItem] {
        let weekStart = startOfWeek(for: selectedDate)
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart)!
        return viewModel.scheduleItems.filter { item in
            guard let dateStr = item.shootDate,
                  let date = parseDate(dateStr) else { return false }
            return date >= weekStart && date < weekEnd
        }
    }

    var weekRangeText: String {
        let weekStart = startOfWeek(for: selectedDate)
        let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "Week of \(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }
}
