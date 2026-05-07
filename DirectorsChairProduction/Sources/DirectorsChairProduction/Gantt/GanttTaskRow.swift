// DirectorsChairProduction/Sources/DirectorsChairProduction/Gantt/GanttTaskRow.swift
//
// Left panel task list row for Gantt chart

import SwiftUI
import DirectorsChairCore

public struct GanttTaskRow: View {
    let ganttTask: GanttTask
    let isSelected: Bool
    let castMembers: [CastMember]
    let crewMembers: [CrewMember]
    let onSelect: () -> Void

    @State private var isHovering = false

    public init(
        ganttTask: GanttTask,
        isSelected: Bool,
        castMembers: [CastMember] = [],
        crewMembers: [CrewMember] = [],
        onSelect: @escaping () -> Void
    ) {
        self.ganttTask = ganttTask
        self.isSelected = isSelected
        self.castMembers = castMembers
        self.crewMembers = crewMembers
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Category icon
            Image(systemName: ganttTask.category.icon)
                .font(.system(size: 10))
                .foregroundStyle(colorFromHex(ganttTask.effectiveColor))
                .frame(width: 16)

            // Milestone diamond or task name
            if ganttTask.isMilestone {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(colorFromHex(ganttTask.effectiveColor))
            }

            Text(ganttTask.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(Color(nsColor: .labelColor))

            Spacer(minLength: 4)

            // Mini progress bar
            if !ganttTask.isMilestone && ganttTask.completionPercentage > 0 {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(nsColor: .quaternarySystemFill))
                        .frame(width: 30, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor)
                        .frame(width: 30 * CGFloat(ganttTask.completionPercentage) / 100, height: 4)
                }
            }

            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            // Priority badge
            if ganttTask.priority >= 4 {
                Text("P\(ganttTask.priority)")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(priorityColor.cornerRadius(3))
            }

            // Assignee avatar
            if let assigneeName = firstAssigneeName {
                InitialsAvatar(name: assigneeName, size: 16)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.15) :
                      isHovering ? Color(nsColor: .quaternarySystemFill) : Color.clear)
        )
        .onHover { isHovering = $0 }
        .onTapGesture { onSelect() }
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        switch ganttTask.status {
        case "In Progress": return .orange
        case "Complete": return .green
        case "On Hold": return .yellow
        case "Cancelled": return Color(nsColor: .tertiaryLabelColor)
        default: return Color(nsColor: .secondaryLabelColor)
        }
    }

    private var progressColor: Color {
        if ganttTask.completionPercentage >= 100 { return .green }
        if ganttTask.completionPercentage >= 50 { return .orange }
        return Color.accentColor
    }

    private var priorityColor: Color {
        ganttTask.priority >= 5 ? .red : .orange
    }

    private var firstAssigneeName: String? {
        if let castId = ganttTask.assignedCastIds.first,
           let member = castMembers.first(where: { $0.id == castId }) {
            return member.actorName
        }
        if let crewId = ganttTask.assignedCrewIds.first,
           let member = crewMembers.first(where: { $0.id == crewId }) {
            return member.name
        }
        return nil
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
