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

    @State var viewMode: ScheduleViewMode = .monthly
    @State var filter: ScheduleFilter = .all
    @State var selectedDate: Date = Date()
    @State var displayedMonth: Date = Date()
    @State var selectedItem: ScheduleItem?
    @State var showingAddSheet = false
    @State var showingEditSheet = false
    @State var showingOptimizeSheet = false
    @State var showingConflicts = false
    @State var activeBadgePopover: String? = nil

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
}
