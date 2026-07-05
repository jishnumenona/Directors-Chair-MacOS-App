//
// ScheduleView+Sheets.swift
//
// Extracted from ScheduleView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore


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

    @State var isHovered = false

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

    var dayNumberColor: Color {
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

    var cellBackground: Color {
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

    func itemStatusColor(_ item: ScheduleItem) -> Color {
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
    @State var isHovered = false

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

    var statusColor: Color {
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

    let timeSlots = ["Morning", "Afternoon", "Evening", "Night", "Full Day"]
    let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

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

    func dayOfMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    func itemsFor(date: Date, slot: String) -> [ScheduleItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        return items.filter { $0.shootDate == dateStr && $0.timeSlot == slot }
    }

    func statusColor(for item: ScheduleItem) -> Color {
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
    @State var selectedSequenceIndex: Int? = nil
    @State var selectedSceneIndex: Int? = nil
    @State var sceneSearchText: String = ""

    // Schedule fields
    @State var shootDate: Date = Date()
    @State var timeSlot: String = "Full Day"
    @State var duration: Double = 4.0
    @State var status: String = "Planned"
    @State var location: String = ""
    @State var callTime: String = ""
    @State var wrapTime: String = ""
    @State var useExactTime: Bool = false
    @State var exactStartTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State var exactEndTime: Date = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
    @State var productionNotes: String = ""

    // Auto-populated resources (editable)
    @State var requiredActors: [String] = []
    @State var requiredProps: [String] = []
    @State var requiredEquipment: [String] = []
    @State var shotIds: [String] = []

    // For editing existing items without matching sequence/scene
    @State var manualSceneName: String = ""
    @State var manualSequenceName: String = ""
    @State var isManualEntry: Bool = false

    let timeSlots = ["Morning", "Afternoon", "Evening", "Night", "Full Day"]
    let statuses = ["Planned", "Scheduled", "In Progress", "Complete", "Cancelled", "Postponed"]

    var selectedSequence: DirectorsChairCore.Sequence? {
        guard let idx = selectedSequenceIndex, idx < sequences.count else { return nil }
        return sequences[idx]
    }

    var selectedScene: DirectorsChairCore.Scene? {
        guard let seq = selectedSequence,
              let idx = selectedSceneIndex, idx < seq.scenes.count else { return nil }
        return seq.scenes[idx]
    }

    var sceneName: String {
        if isManualEntry { return manualSceneName }
        return selectedScene?.name ?? ""
    }

    var sequenceName: String {
        if isManualEntry { return manualSequenceName }
        return selectedSequence?.name ?? ""
    }

    var filteredSequences: [DirectorsChairCore.Sequence] {
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

    var scenePickerCard: some View {
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

    var manualEntryFields: some View {
        VStack(spacing: 10) {
            StyledTextField("Scene Name", text: $manualSceneName)
            StyledTextField("Sequence Name", text: $manualSequenceName)
        }
    }

    var projectScenePicker: some View {
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

    var scheduleDetailsCard: some View {
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

    func applyTimeSlotDefaults(_ slot: String) {
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

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    func parseTime(_ timeStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeStr)
    }

    var computedDurationFromTimes: Double {
        let cal = Calendar.current
        let startComps = cal.dateComponents([.hour, .minute], from: exactStartTime)
        let endComps = cal.dateComponents([.hour, .minute], from: exactEndTime)
        let startMinutes = (startComps.hour ?? 0) * 60 + (startComps.minute ?? 0)
        let endMinutes = (endComps.hour ?? 0) * 60 + (endComps.minute ?? 0)
        let diff = endMinutes >= startMinutes ? endMinutes - startMinutes : (24 * 60 - startMinutes + endMinutes)
        return max(0.5, Double(diff) / 60.0)
    }

    func recalcDurationFromTimes() {
        duration = (computedDurationFromTimes * 2).rounded() / 2 // Round to nearest 0.5
    }

    // MARK: - Resources Card

    var resourcesCard: some View {
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

    var locationTimeCard: some View {
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

    var notesCard: some View {
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

    func autoPopulateFromScene(_ scene: DirectorsChairCore.Scene, sequence: DirectorsChairCore.Sequence) {
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

    func isSceneScheduled(_ sceneName: String, in sequenceName: String) -> Bool {
        viewModel.scheduleItems.contains { $0.sceneName == sceneName && $0.sequenceName == sequenceName }
    }

    // MARK: - Load Existing

    func loadExistingItem() {
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

    func save() {
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

    func parseDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }
}

// MARK: - Sequence Chip

// MARK: - Detail Metric Tile

// MARK: - Badge Popover Content

struct BadgePopoverContent: View {
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

struct DetailMetricTile: View {
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

struct DetailResourceSection: View {
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

struct SequenceChip: View {
    let name: String
    let sceneCount: Int
    let isSelected: Bool
    let action: () -> Void

    @State var isHovered = false

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

struct ScenePickerRow: View {
    let scene: DirectorsChairCore.Scene
    let isSelected: Bool
    let isAlreadyScheduled: Bool
    let action: () -> Void

    @State var isHovered = false

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

    var sceneStatusColor: Color {
        switch scene.productionStatus {
        case "Ready": return .green
        case "Scheduled": return .purple
        case "Shooting", "In Progress": return .yellow
        case "Shot", "Complete": return .green
        default: return .blue
        }
    }
}
