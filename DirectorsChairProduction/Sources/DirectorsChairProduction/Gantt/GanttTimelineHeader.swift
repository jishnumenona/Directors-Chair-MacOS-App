// DirectorsChairProduction/Sources/DirectorsChairProduction/Gantt/GanttTimelineHeader.swift
//
// Date ruler header for Gantt timeline

import SwiftUI
import DirectorsChairCore

public struct GanttTimelineHeader: View {
    let startDate: Date
    let totalDays: Int
    let zoomLevel: GanttZoomLevel
    let columnWidth: CGFloat

    private let calendar = Calendar.current

    public init(startDate: Date, totalDays: Int, zoomLevel: GanttZoomLevel, columnWidth: CGFloat) {
        self.startDate = startDate
        self.totalDays = totalDays
        self.zoomLevel = zoomLevel
        self.columnWidth = columnWidth
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top row: months
            if zoomLevel == .day || zoomLevel == .week {
                monthRow
            }
            // Bottom row: individual units
            unitRow
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }

    private var monthRow: some View {
        HStack(spacing: 0) {
            let months = monthRanges()
            ForEach(months, id: \.offset) { month in
                Text(month.label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .frame(width: CGFloat(month.days) * columnWidth, alignment: .leading)
                    .padding(.leading, 4)
            }
        }
        .frame(height: 16)
    }

    private var unitRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalDays, id: \.self) { dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
                let isToday = calendar.isDateInToday(date)
                let isWeekend = calendar.isDateInWeekend(date)

                Group {
                    switch zoomLevel {
                    case .day:
                        dayLabel(date: date, isToday: isToday)
                    case .week:
                        if calendar.component(.weekday, from: date) == calendar.firstWeekday || dayOffset == 0 {
                            weekLabel(date: date, isToday: isToday)
                        } else {
                            Color.clear
                        }
                    case .month:
                        if calendar.component(.day, from: date) == 1 || dayOffset == 0 {
                            monthLabel(date: date)
                        } else {
                            Color.clear
                        }
                    }
                }
                .frame(width: columnWidth)
                .background(
                    isToday ? Color.accentColor.opacity(0.1) :
                    isWeekend ? Color(nsColor: .separatorColor).opacity(0.1) :
                    Color.clear
                )
            }
        }
        .frame(height: 20)
    }

    private func dayLabel(date: Date, isToday: Bool) -> some View {
        let day = calendar.component(.day, from: date)
        let weekday = dayOfWeekLetter(date)
        return VStack(spacing: 0) {
            Text(weekday)
                .font(.system(size: 7, weight: .regular))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            Text("\(day)")
                .font(.system(size: 9, weight: isToday ? .bold : .regular, design: .rounded))
                .foregroundStyle(isToday ? Color.accentColor : Color(nsColor: .labelColor))
        }
    }

    private func weekLabel(date: Date, isToday: Bool) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return Text(formatter.string(from: date))
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(isToday ? Color.accentColor : Color(nsColor: .secondaryLabelColor))
    }

    private func monthLabel(date: Date) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return Text(formatter.string(from: date))
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color(nsColor: .labelColor))
    }

    private func dayOfWeekLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    private struct MonthRange {
        let label: String
        let days: Int
        let offset: Int
    }

    private func monthRanges() -> [MonthRange] {
        var ranges: [MonthRange] = []
        var currentMonth = -1
        var currentLabel = ""
        var dayCount = 0
        var rangeStart = 0

        for i in 0..<totalDays {
            let date = calendar.date(byAdding: .day, value: i, to: startDate) ?? startDate
            let month = calendar.component(.month, from: date)

            if month != currentMonth {
                if dayCount > 0 {
                    ranges.append(MonthRange(label: currentLabel, days: dayCount, offset: rangeStart))
                }
                currentMonth = month
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                currentLabel = formatter.string(from: date)
                dayCount = 1
                rangeStart = i
            } else {
                dayCount += 1
            }
        }
        if dayCount > 0 {
            ranges.append(MonthRange(label: currentLabel, days: dayCount, offset: rangeStart))
        }
        return ranges
    }
}
