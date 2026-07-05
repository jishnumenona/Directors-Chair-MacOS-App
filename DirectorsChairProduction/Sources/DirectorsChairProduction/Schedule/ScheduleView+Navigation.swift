//
// ScheduleView+Navigation.swift
//
// Extracted from ScheduleView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore

extension ScheduleView {

    // MARK: - Actions

    func removeSelectedItem() {
        guard let item = selectedItem else { return }
        viewModel.removeScheduleItem(item)
        selectedItem = nil
    }

    func previousWeek() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
    }

    func nextWeek() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
    }

    func goToCurrentWeek() {
        selectedDate = Date()
    }

    func previousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    func nextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    func goToToday() {
        selectedDate = Date()
    }

    // MARK: - Date Helpers

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func formattedDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    func formatDateForComparison(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func parseDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }

    func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    func statusColor(for item: ScheduleItem) -> Color {
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

    func navigateMonth(by offset: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    func goToTodayMonth() {
        displayedMonth = Date()
        selectedDate = Date()
        selectedItem = nil
    }

    func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    func itemsForDate(_ date: Date) -> [ScheduleItem] {
        let dateStr = formatDateForComparison(date)
        return viewModel.scheduleItems.filter { $0.shootDate == dateStr }
    }

    /// Build a 2D array of DayInfo for the calendar grid
    func calendarWeeks(for month: Date) -> [[DayInfo]] {
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
