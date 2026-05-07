// DirectorsChairProduction/Sources/DirectorsChairProduction/Gantt/GanttFilterPanel.swift
//
// Advanced filter popover for Gantt chart

import SwiftUI
import DirectorsChairCore

public struct GanttFilterPanel: View {
    @ObservedObject var viewModel: GanttViewModel

    private let statuses = ["Not Started", "In Progress", "Complete", "On Hold", "Cancelled"]

    public init(viewModel: GanttViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category Filter
            VStack(alignment: .leading, spacing: 6) {
                ProductionSectionHeader(icon: "tag", title: "CATEGORY")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 4) {
                    ForEach(GanttTaskCategory.allCases, id: \.self) { cat in
                        ProductionChip(icon: cat.icon, cat.rawValue, selected: viewModel.categoryFilter.contains(cat)
                        ) {
                            if viewModel.categoryFilter.contains(cat) {
                                viewModel.categoryFilter.remove(cat)
                            } else {
                                viewModel.categoryFilter.insert(cat)
                            }
                        }
                    }
                }
            }

            Divider()

            // Status Filter
            VStack(alignment: .leading, spacing: 6) {
                ProductionSectionHeader(icon: "circle.lefthalf.filled", title: "STATUS")
                HStack(spacing: 4) {
                    ForEach(statuses, id: \.self) { s in
                        ProductionChip(icon: statusIcon(s), s, selected: viewModel.statusFilter.contains(s)
                        ) {
                            if viewModel.statusFilter.contains(s) {
                                viewModel.statusFilter.remove(s)
                            } else {
                                viewModel.statusFilter.insert(s)
                            }
                        }
                    }
                }
            }

            Divider()

            // Group By
            VStack(alignment: .leading, spacing: 6) {
                ProductionSectionHeader(icon: "rectangle.3.group", title: "GROUP BY")
                HStack(spacing: 4) {
                    ForEach(GanttGroupMode.allCases, id: \.self) { mode in
                        ProductionChip(icon: groupIcon(mode), mode.rawValue, selected: viewModel.groupBy == mode
                        ) {
                            viewModel.groupBy = mode
                        }
                    }
                }
            }

            Divider()

            // Sort By
            VStack(alignment: .leading, spacing: 6) {
                ProductionSectionHeader(icon: "arrow.up.arrow.down", title: "SORT BY")
                HStack(spacing: 4) {
                    ForEach(GanttSortMode.allCases, id: \.self) { mode in
                        ProductionChip(icon: sortIcon(mode), mode.rawValue, selected: viewModel.sortBy == mode
                        ) {
                            viewModel.sortBy = mode
                        }
                    }
                }
            }

            Divider()

            // Clear all filters
            HStack {
                Spacer()
                ProductionActionButton(icon: "xmark.circle", "Clear All Filters") {
                    viewModel.categoryFilter.removeAll()
                    viewModel.statusFilter.removeAll()
                    viewModel.tagFilter.removeAll()
                    viewModel.groupBy = .none
                    viewModel.sortBy = .startDate
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func statusIcon(_ s: String) -> String {
        switch s {
        case "Not Started": return "circle"
        case "In Progress": return "circle.lefthalf.filled"
        case "Complete": return "checkmark.circle.fill"
        case "On Hold": return "pause.circle"
        case "Cancelled": return "xmark.circle"
        default: return "circle"
        }
    }

    private func groupIcon(_ mode: GanttGroupMode) -> String {
        switch mode {
        case .none: return "line.3.horizontal"
        case .category: return "tag"
        case .location: return "map"
        case .status: return "circle.lefthalf.filled"
        case .assignee: return "person"
        }
    }

    private func sortIcon(_ mode: GanttSortMode) -> String {
        switch mode {
        case .startDate: return "calendar"
        case .priority: return "exclamationmark.triangle"
        case .category: return "tag"
        case .status: return "circle.lefthalf.filled"
        case .name: return "textformat"
        }
    }
}
