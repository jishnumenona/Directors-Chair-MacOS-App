// DirectorsChairProduction/Sources/DirectorsChairProduction/Gantt/GanttChartView.swift
//
// Main container for the Production Gantt Chart

import SwiftUI
import DirectorsChairCore

public struct GanttChartView: View {
    @ObservedObject var viewModel: GanttViewModel

    @State private var showAddSheet = false
    @State private var editingTask: GanttTask?
    @State private var showFilterPopover = false
    @State private var taskListWidth: CGFloat = 280
    @State private var timelineScrollOffset: CGFloat = 0

    private let rowHeight: CGFloat = 28

    public init(viewModel: GanttViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if viewModel.showResourceView {
                GanttResourceView(viewModel: viewModel)
            } else {
                chartContent
            }

            Divider()
            statsBar
        }
        .background(Color(nsColor: .textBackgroundColor))
        .sheet(isPresented: $showAddSheet) {
            GanttTaskEditorSheet(
                viewModel: viewModel,
                editingTask: nil,
                onSave: { newTask in
                    viewModel.addTask(newTask)
                    showAddSheet = false
                },
                onCancel: { showAddSheet = false }
            )
        }
        .sheet(item: $editingTask) { ganttTask in
            GanttTaskEditorSheet(
                viewModel: viewModel,
                editingTask: ganttTask,
                onSave: { updated in
                    viewModel.updateTask(updated)
                    editingTask = nil
                },
                onCancel: { editingTask = nil }
            )
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // Zoom level chips
                ForEach(GanttZoomLevel.allCases, id: \.self) { level in
                    ProductionChip(icon: zoomIcon(level), level.rawValue, selected: viewModel.zoomLevel == level) {
                        viewModel.zoomLevel = level
                    }
                }

                Divider().frame(height: 16)

                // Category quick filters
                ForEach(activeFilterCategories, id: \.self) { cat in
                    ProductionChip(icon: cat.icon, cat.rawValue, selected: viewModel.categoryFilter.contains(cat)) {
                        if viewModel.categoryFilter.contains(cat) {
                            viewModel.categoryFilter.remove(cat)
                        } else {
                            viewModel.categoryFilter.insert(cat)
                        }
                    }
                }

                Spacer()

                // Search
                ProductionSearchField(text: $viewModel.searchText)
                    .frame(width: 160)

                // Filter button
                Button {
                    showFilterPopover.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(hasActiveFilters ? Color.accentColor : Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showFilterPopover) {
                    GanttFilterPanel(viewModel: viewModel)
                }

                Divider().frame(height: 16)

                // Actions
                ProductionActionButton(icon: "arrow.triangle.2.circlepath", "Sync") {
                    viewModel.syncFromScheduleItems()
                }

                ProductionActionButton(icon: "plus", "Add Task", prominent: true) {
                    showAddSheet = true
                }

                // Resource view toggle
                Button {
                    viewModel.showResourceView.toggle()
                } label: {
                    Image(systemName: viewModel.showResourceView ? "chart.bar.xaxis" : "person.3.sequence")
                        .font(.system(size: 13))
                        .foregroundStyle(viewModel.showResourceView ? Color.accentColor : Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
                .help(viewModel.showResourceView ? "Show Gantt Chart" : "Show Resource View")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var activeFilterCategories: [GanttTaskCategory] {
        // Show categories that have tasks
        let used = Set(viewModel.tasks.map { $0.category })
        return GanttTaskCategory.allCases.filter { used.contains($0) }
    }

    private var hasActiveFilters: Bool {
        !viewModel.categoryFilter.isEmpty || !viewModel.statusFilter.isEmpty || !viewModel.tagFilter.isEmpty
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        let range = viewModel.projectDateRange
        let totalDays = viewModel.totalDays
        let columnWidth = viewModel.zoomLevel.columnWidth
        let grouped = viewModel.groupedTasks
        let criticalPath = viewModel.criticalPath

        return HSplitView {
            // Left panel: Task list
            taskListPanel(grouped: grouped)
                .frame(minWidth: 200, idealWidth: taskListWidth, maxWidth: 400)

            // Right panel: Timeline
            timelinePanel(
                grouped: grouped,
                range: range,
                totalDays: totalDays,
                columnWidth: columnWidth,
                criticalPath: criticalPath
            )
        }
    }

    // MARK: - Task List Panel

    private func taskListPanel(grouped: [(String, [GanttTask])]) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TASKS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                Spacer()
                Text("\(viewModel.filteredTasks.count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

            Divider()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(grouped, id: \.0) { group in
                        if viewModel.groupBy != .none {
                            HStack {
                                Text(group.0)
                                    .font(.system(size: 9, weight: .semibold))
                                    .tracking(1.0)
                                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                                Spacer()
                                Text("\(group.1.count)")
                                    .font(.system(size: 8, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.2))
                        }

                        ForEach(group.1, id: \.id) { ganttTask in
                            GanttTaskRow(
                                ganttTask: ganttTask,
                                isSelected: viewModel.selectedTaskId == ganttTask.id,
                                castMembers: viewModel.castMembers,
                                crewMembers: viewModel.crewMembers,
                                onSelect: {
                                    viewModel.selectedTaskId = ganttTask.id
                                }
                            )
                            .contextMenu {
                                Button("Edit Task") {
                                    editingTask = ganttTask
                                }
                                Button("Duplicate") {
                                    var dup = ganttTask
                                    dup.id = "gantt_\(UUID().uuidString.prefix(12))"
                                    dup.name += " (Copy)"
                                    dup.createdDate = GanttTask.isoDateString()
                                    dup.modifiedDate = GanttTask.isoDateString()
                                    viewModel.addTask(dup)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    viewModel.removeTask(ganttTask.id)
                                }
                            }
                            .onTapGesture(count: 2) {
                                editingTask = ganttTask
                            }
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Timeline Panel

    private func timelinePanel(
        grouped: [(String, [GanttTask])],
        range: (start: Date, end: Date),
        totalDays: Int,
        columnWidth: CGFloat,
        criticalPath: Set<String>
    ) -> some View {
        VStack(spacing: 0) {
            // Timeline header
            ScrollView(.horizontal, showsIndicators: false) {
                GanttTimelineHeader(
                    startDate: range.start,
                    totalDays: totalDays,
                    zoomLevel: viewModel.zoomLevel,
                    columnWidth: columnWidth
                )
            }

            Divider()

            // Timeline bars
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Grid background with today marker + weekends
                    gridBackground(totalDays: totalDays, columnWidth: columnWidth, startDate: range.start)

                    // Task bars
                    VStack(spacing: 0) {
                        ForEach(grouped, id: \.0) { group in
                            if viewModel.groupBy != .none {
                                Color.clear.frame(height: 24) // group header spacing
                            }

                            ForEach(group.1, id: \.id) { ganttTask in
                                GanttTimelineBar(
                                    ganttTask: ganttTask,
                                    startDate: range.start,
                                    columnWidth: columnWidth,
                                    rowHeight: rowHeight,
                                    isSelected: viewModel.selectedTaskId == ganttTask.id,
                                    isCritical: criticalPath.contains(ganttTask.id),
                                    onSelect: {
                                        viewModel.selectedTaskId = ganttTask.id
                                    },
                                    onMove: { newDate in
                                        viewModel.moveTask(id: ganttTask.id, newStartDate: newDate)
                                    },
                                    onResize: { newEnd in
                                        viewModel.resizeTask(id: ganttTask.id, newEndDate: newEnd)
                                    }
                                )
                                .frame(height: rowHeight)
                            }
                        }
                    }

                    // Dependency arrows overlay
                    let allFiltered = grouped.flatMap { $0.1 }
                    GanttDependencyArrows(
                        tasks: allFiltered,
                        startDate: range.start,
                        columnWidth: columnWidth,
                        rowHeight: rowHeight,
                        criticalPath: criticalPath
                    )
                    .frame(
                        width: CGFloat(totalDays) * columnWidth,
                        height: CGFloat(allFiltered.count) * rowHeight + (viewModel.groupBy != .none ? CGFloat(grouped.count) * 24 : 0)
                    )
                }
                .frame(width: CGFloat(totalDays) * columnWidth)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Grid Background

    private func gridBackground(totalDays: Int, columnWidth: CGFloat, startDate: Date) -> some View {
        let calendar = Calendar.current

        return HStack(spacing: 0) {
            ForEach(0..<totalDays, id: \.self) { dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
                let isToday = calendar.isDateInToday(date)
                let isWeekend = calendar.isDateInWeekend(date)

                Rectangle()
                    .fill(
                        isToday ? Color.accentColor.opacity(0.08) :
                        isWeekend ? Color(nsColor: .separatorColor).opacity(0.06) :
                        Color.clear
                    )
                    .frame(width: columnWidth)
                    .overlay(alignment: .leading) {
                        if isToday {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 1.5)
                        }
                    }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 20) {
            statItem(label: "Tasks", value: "\(viewModel.totalTasks)")
            statItem(label: "Complete", value: "\(viewModel.completedTasks)/\(viewModel.totalTasks)")
            statItem(label: "Progress", value: "\(viewModel.progressPercentage)%")

            if !viewModel.criticalPath.isEmpty {
                statItem(label: "Critical Path", value: "\(viewModel.criticalPathDays) days")
            }

            if viewModel.totalEstimatedCost > 0 {
                statItem(label: "Est. Cost", value: String(format: "$%.0f", viewModel.totalEstimatedCost))
            }

            Spacer()

            if !viewModel.filteredTasks.isEmpty {
                Text("Showing \(viewModel.filteredTasks.count) of \(viewModel.totalTasks)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    private func statItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(nsColor: .labelColor))
        }
    }

    // MARK: - Helpers

    private func zoomIcon(_ level: GanttZoomLevel) -> String {
        switch level {
        case .day: return "calendar.day.timeline.left"
        case .week: return "calendar"
        case .month: return "calendar.badge.clock"
        }
    }
}

