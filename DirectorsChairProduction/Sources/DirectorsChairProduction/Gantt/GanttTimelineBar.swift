// DirectorsChairProduction/Sources/DirectorsChairProduction/Gantt/GanttTimelineBar.swift
//
// Task bar and milestone marker for Gantt timeline

import SwiftUI
import DirectorsChairCore

public struct GanttTimelineBar: View {
    let ganttTask: GanttTask
    let startDate: Date
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let isSelected: Bool
    let isCritical: Bool
    let onSelect: () -> Void
    let onMove: (Date) -> Void
    let onResize: (Date) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var resizeOffset: CGFloat = 0
    @State private var isHovering = false

    private let calendar = Calendar.current
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init(
        ganttTask: GanttTask,
        startDate: Date,
        columnWidth: CGFloat,
        rowHeight: CGFloat = 28,
        isSelected: Bool,
        isCritical: Bool,
        onSelect: @escaping () -> Void,
        onMove: @escaping (Date) -> Void,
        onResize: @escaping (Date) -> Void
    ) {
        self.ganttTask = ganttTask
        self.startDate = startDate
        self.columnWidth = columnWidth
        self.rowHeight = rowHeight
        self.isSelected = isSelected
        self.isCritical = isCritical
        self.onSelect = onSelect
        self.onMove = onMove
        self.onResize = onResize
    }

    private var taskColor: Color {
        colorFromHex(ganttTask.effectiveColor)
    }

    private var barXOffset: CGFloat {
        guard let taskStart = Self.dateFormatter.date(from: ganttTask.startDate) else { return 0 }
        let days = calendar.dateComponents([.day], from: startDate, to: taskStart).day ?? 0
        return CGFloat(days) * columnWidth
    }

    private var barWidth: CGFloat {
        CGFloat(max(1, ganttTask.durationDays)) * columnWidth
    }

    public var body: some View {
        if ganttTask.isMilestone {
            milestoneMarker
                .offset(x: barXOffset + dragOffset + columnWidth / 2 - 8)
        } else {
            taskBar
                .offset(x: barXOffset + dragOffset)
        }
    }

    private var taskBar: some View {
        ZStack(alignment: .leading) {
            // Background bar
            RoundedRectangle(cornerRadius: 4)
                .fill(taskColor.opacity(0.25))
                .frame(width: barWidth + resizeOffset, height: rowHeight - 6)

            // Completion fill
            if ganttTask.completionPercentage > 0 {
                RoundedRectangle(cornerRadius: 4)
                    .fill(taskColor.opacity(0.6))
                    .frame(
                        width: (barWidth + resizeOffset) * CGFloat(ganttTask.completionPercentage) / 100.0,
                        height: rowHeight - 6
                    )
            }

            // Border
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    isSelected ? Color.accentColor :
                    isCritical ? taskColor :
                    taskColor.opacity(0.5),
                    lineWidth: isSelected ? 2 : (isCritical ? 1.5 : 1)
                )
                .frame(width: barWidth + resizeOffset, height: rowHeight - 6)

            // Task name label
            if barWidth > 50 {
                Text(ganttTask.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .frame(width: barWidth + resizeOffset, alignment: .leading)
            }

            // Resize handle on right edge
            Rectangle()
                .fill(Color.clear)
                .frame(width: 6, height: rowHeight - 6)
                .contentShape(Rectangle())
                .offset(x: barWidth + resizeOffset - 6)
                .cursor(.resizeLeftRight)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            resizeOffset = value.translation.width
                        }
                        .onEnded { value in
                            let newWidth = barWidth + value.translation.width
                            let newDays = max(1, Int(round(newWidth / columnWidth)))
                            if let taskStart = Self.dateFormatter.date(from: ganttTask.startDate),
                               let newEnd = calendar.date(byAdding: .day, value: newDays - 1, to: taskStart) {
                                onResize(newEnd)
                            }
                            resizeOffset = 0
                        }
                )
        }
        .frame(height: rowHeight)
        .onHover { isHovering = $0 }
        .onTapGesture { onSelect() }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let daysMoved = Int(round(value.translation.width / columnWidth))
                    if let taskStart = Self.dateFormatter.date(from: ganttTask.startDate),
                       let newStart = calendar.date(byAdding: .day, value: daysMoved, to: taskStart) {
                        onMove(newStart)
                    }
                    dragOffset = 0
                }
        )
        .help(taskTooltip)
    }

    private var milestoneMarker: some View {
        ZStack {
            Rectangle()
                .fill(taskColor)
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(45))

            if isSelected {
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(45))
            }
        }
        .frame(height: rowHeight)
        .onTapGesture { onSelect() }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let daysMoved = Int(round(value.translation.width / columnWidth))
                    if let taskStart = Self.dateFormatter.date(from: ganttTask.startDate),
                       let newStart = calendar.date(byAdding: .day, value: daysMoved, to: taskStart) {
                        onMove(newStart)
                    }
                    dragOffset = 0
                }
        )
        .help(ganttTask.name)
    }

    private var taskTooltip: String {
        var tip = ganttTask.name
        if !ganttTask.startDate.isEmpty {
            tip += "\n\(ganttTask.startDate)"
            if ganttTask.durationDays > 0 {
                tip += " → \(ganttTask.computedEndDate) (\(ganttTask.durationDays)d)"
            }
        }
        if ganttTask.completionPercentage > 0 {
            tip += "\n\(ganttTask.completionPercentage)% complete"
        }
        return tip
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

// MARK: - Cursor Helper

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
