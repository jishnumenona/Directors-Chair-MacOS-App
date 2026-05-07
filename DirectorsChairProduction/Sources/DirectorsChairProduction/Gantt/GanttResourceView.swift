// DirectorsChairProduction/Sources/DirectorsChairProduction/Gantt/GanttResourceView.swift
//
// Resource allocation lanes view

import SwiftUI
import DirectorsChairCore

public struct GanttResourceView: View {
    @ObservedObject var viewModel: GanttViewModel

    private let rowHeight: CGFloat = 32
    private let labelWidth: CGFloat = 160

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init(viewModel: GanttViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let range = viewModel.projectDateRange
        let totalDays = viewModel.totalDays
        let columnWidth = viewModel.zoomLevel.columnWidth

        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("RESOURCE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .frame(width: labelWidth, alignment: .leading)
                    .padding(.leading, 8)

                GanttTimelineHeader(
                    startDate: range.start,
                    totalDays: totalDays,
                    zoomLevel: viewModel.zoomLevel,
                    columnWidth: columnWidth
                )
            }

            Divider()

            ScrollView([.vertical]) {
                VStack(spacing: 0) {
                    // Cast lanes
                    if !viewModel.castMembers.isEmpty {
                        sectionHeader("CAST")
                        ForEach(viewModel.castMembers, id: \.id) { member in
                            let memberTasks = viewModel.tasksForCast(member.id)
                            if !memberTasks.isEmpty {
                                resourceLane(
                                    name: member.actorName,
                                    tasks: memberTasks,
                                    rangeStart: range.start,
                                    totalDays: totalDays,
                                    columnWidth: columnWidth
                                )
                            }
                        }
                    }

                    // Crew lanes
                    if !viewModel.crewMembers.isEmpty {
                        sectionHeader("CREW")
                        ForEach(viewModel.crewMembers, id: \.id) { member in
                            let memberTasks = viewModel.tasksForCrew(member.id)
                            if !memberTasks.isEmpty {
                                resourceLane(
                                    name: member.name,
                                    tasks: memberTasks,
                                    rangeStart: range.start,
                                    totalDays: totalDays,
                                    columnWidth: columnWidth
                                )
                            }
                        }
                    }

                    // Equipment lanes
                    if !viewModel.equipment.isEmpty {
                        sectionHeader("EQUIPMENT")
                        ForEach(viewModel.equipment, id: \.id) { item in
                            let itemTasks = viewModel.tasksForEquipment(item.id)
                            if !itemTasks.isEmpty {
                                resourceLane(
                                    name: item.name,
                                    tasks: itemTasks,
                                    rangeStart: range.start,
                                    totalDays: totalDays,
                                    columnWidth: columnWidth
                                )
                            }
                        }
                    }

                    if viewModel.castMembers.isEmpty && viewModel.crewMembers.isEmpty && viewModel.equipment.isEmpty {
                        Text("No resources assigned to tasks")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            .frame(maxWidth: .infinity, minHeight: 100)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            Spacer()
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    private func resourceLane(name: String, tasks: [GanttTask], rangeStart: Date, totalDays: Int, columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Resource name
            HStack(spacing: 6) {
                InitialsAvatar(name: name, size: 18)
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: labelWidth, alignment: .leading)
            .padding(.leading, 8)

            // Timeline bars
            ZStack(alignment: .leading) {
                // Grid background
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(totalDays) * columnWidth, height: rowHeight)

                // Task bars
                ForEach(tasks, id: \.id) { ganttTask in
                    let xOffset = xPosition(for: ganttTask.startDate, rangeStart: rangeStart, columnWidth: columnWidth)
                    let width = CGFloat(max(1, ganttTask.durationDays)) * columnWidth

                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorFromHex(ganttTask.effectiveColor).opacity(0.6))
                        .frame(width: width, height: rowHeight - 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(colorFromHex(ganttTask.effectiveColor), lineWidth: 0.5)
                        )
                        .overlay(
                            Text(ganttTask.name)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 3),
                            alignment: .leading
                        )
                        .offset(x: xOffset)
                        .help(ganttTask.name)
                }

                // Conflict overlay — highlight overlapping areas
                let conflicts = findOverlaps(in: tasks)
                ForEach(conflicts.indices, id: \.self) { idx in
                    let conflict = conflicts[idx]
                    let x1 = xPosition(for: conflict.start, rangeStart: rangeStart, columnWidth: columnWidth)
                    let x2 = xPosition(for: conflict.end, rangeStart: rangeStart, columnWidth: columnWidth) + columnWidth

                    Rectangle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: max(0, x2 - x1), height: rowHeight)
                        .offset(x: x1)
                }
            }
        }
        .frame(height: rowHeight)
        .background(Color(nsColor: .separatorColor).opacity(0.05))
    }

    private struct OverlapRange {
        let start: String
        let end: String
    }

    private func findOverlaps(in tasks: [GanttTask]) -> [OverlapRange] {
        var overlaps: [OverlapRange] = []
        for i in 0..<tasks.count {
            for j in (i+1)..<tasks.count {
                let a = tasks[i]
                let b = tasks[j]
                guard let aStart = Self.dateFormatter.date(from: a.startDate),
                      let aEnd = Self.dateFormatter.date(from: a.computedEndDate),
                      let bStart = Self.dateFormatter.date(from: b.startDate),
                      let bEnd = Self.dateFormatter.date(from: b.computedEndDate) else { continue }

                if aStart <= bEnd && bStart <= aEnd {
                    let overlapStart = max(aStart, bStart)
                    let overlapEnd = min(aEnd, bEnd)
                    overlaps.append(OverlapRange(
                        start: Self.dateFormatter.string(from: overlapStart),
                        end: Self.dateFormatter.string(from: overlapEnd)
                    ))
                }
            }
        }
        return overlaps
    }

    private func xPosition(for dateString: String, rangeStart: Date, columnWidth: CGFloat) -> CGFloat {
        guard let date = Self.dateFormatter.date(from: dateString) else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: rangeStart, to: date).day ?? 0
        return CGFloat(days) * columnWidth
    }

    private func colorFromHex(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let number = UInt64(cleaned, radix: 16) else {
            return .accentColor
        }
        let r = Double((number >> 16) & 0xFF) / 255.0
        let g = Double((number >> 8) & 0xFF) / 255.0
        let b = Double(number & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
