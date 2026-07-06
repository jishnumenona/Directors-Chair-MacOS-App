//
// ContentView+Production.swift
//
// Extracted from ContentView.swift (WS9.1 god-file decomposition).
// Behaviour unchanged; these were already internal helper views.
//

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import DirectorsChairCore
import DirectorsChairViews
import DirectorsChairProduction
import DirectorsChairServices

struct ProductionContainer: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var projectViewModel: ProjectViewModel
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @ObservedObject var castCrewViewModel: CastCrewViewModel
    @ObservedObject var budgetViewModel: BudgetViewModel
    @ObservedObject var equipmentViewModel: EquipmentViewModel
    @ObservedObject var ganttViewModel: GanttViewModel

    var body: some View {
        ProductionViewWrapper(
            project: projectViewModel.project,
            projectPath: projectViewModel.projectPath,
            subtitle: "Production"
        ) {
            VStack(spacing: 0) {
                // Custom icon+label tab bar
                HStack(spacing: 0) {
                    ProductionTabButton(
                        icon: "calendar",
                        title: "Schedule",
                        isSelected: coordinator.selectedProductionTab == "Schedule"
                    ) {
                        coordinator.selectedProductionTab = "Schedule"
                    }
                    ProductionTabButton(
                        icon: "chart.bar.xaxis",
                        title: "Gantt",
                        isSelected: coordinator.selectedProductionTab == "Gantt"
                    ) {
                        coordinator.selectedProductionTab = "Gantt"
                    }
                    ProductionTabButton(
                        icon: "person.3",
                        title: "Cast & Crew",
                        isSelected: coordinator.selectedProductionTab == "Cast & Crew"
                    ) {
                        coordinator.selectedProductionTab = "Cast & Crew"
                    }
                    ProductionTabButton(
                        icon: "banknote",
                        title: "Accounting",
                        isSelected: coordinator.selectedProductionTab == "Accounting"
                    ) {
                        coordinator.selectedProductionTab = "Accounting"
                    }
                    ProductionTabButton(
                        icon: "camera.metering.matrix",
                        title: "Equipment",
                        isSelected: coordinator.selectedProductionTab == "Equipment"
                    ) {
                        coordinator.selectedProductionTab = "Equipment"
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                Divider()

                // Tab content
                switch coordinator.selectedProductionTab {
                case "Schedule":
                    ScheduleView(viewModel: scheduleViewModel, sequences: projectViewModel.project.sequences, onSceneStatusUpdate: updateSceneStatus)
                case "Gantt":
                    GanttChartView(viewModel: ganttViewModel)
                case "Cast & Crew":
                    CastCrewView(viewModel: castCrewViewModel)
                case "Accounting":
                    BudgetView(viewModel: budgetViewModel)
                case "Equipment":
                    EquipmentView(viewModel: equipmentViewModel)
                default:
                    ScheduleView(viewModel: scheduleViewModel, sequences: projectViewModel.project.sequences, onSceneStatusUpdate: updateSceneStatus)
                }
            }
        }
        .onAppear {
            wireUpCallbacks()
            loadProductionData()
        }
        .onChange(of: coordinator.selectedProductionTab) { _, _ in loadProductionData() }
        // WS5.3: keep the OPEN production tab consistent with external changes
        // (sync pulls, rename cascades, script/structure edits) without
        // requiring a tab switch. Production tabs' own write-backs don't emit
        // events, so this cannot loop.
        .onReceive(coordinator.projectEvents) { event in
            if event == .general || event == .production || event == .structure {
                loadProductionData()
            }
        }
    }

    private func wireUpCallbacks() {
        // Sync schedule changes back to project (triggers auto-save)
        scheduleViewModel.onScheduleChanged = { items in
            projectViewModel.project.scheduleItems = items
        }

        // Sync cast & crew changes back to project
        castCrewViewModel.onCastChanged = { members in
            projectViewModel.project.castMembers = members
        }
        castCrewViewModel.onCrewChanged = { members in
            projectViewModel.project.crewMembers = members
        }
        castCrewViewModel.onTeamsChanged = { teams in
            projectViewModel.project.teams = teams
        }
        castCrewViewModel.onEquipmentChanged = { equipment in
            projectViewModel.project.equipmentLibrary = equipment
        }

        // Sync budget changes back to project
        budgetViewModel.onBudgetChanged = { budget in
            projectViewModel.project.projectBudget = budget
        }

        // AI receipt analysis — extracted to ReceiptAnalysisService (WS6.4);
        // the view only supplies the category names.
        let capturedBudgetVM = budgetViewModel
        budgetViewModel.onAnalyzeReceipt = { imageData, mimeType in
            let categoryNames = capturedBudgetVM.budget.categories.map { $0.name }.joined(separator: ", ")
            return await ReceiptAnalysisService.analyze(imageData: imageData,
                                                        mimeType: mimeType,
                                                        categoryNames: categoryNames)
        }


        // Sync equipment changes back to project
        equipmentViewModel.onEquipmentChanged = { equipment in
            projectViewModel.project.equipmentLibrary = equipment
        }
        equipmentViewModel.onAllocationsChanged = { allocations in
            projectViewModel.project.equipmentAllocations = allocations
        }

        // Sync Gantt task changes back to project
        ganttViewModel.onTasksChanged = { tasks in
            projectViewModel.project.ganttTasks = tasks
        }
    }

    private func loadProductionData() {
        switch coordinator.selectedProductionTab {
        case "Schedule":
            // Load schedule items as-is. (Previously this force-promoted every
            // "Planned" item with a date to "Scheduled" on each tab open, so a
            // user's explicit "Planned" status was reverted and could never
            // stick — the load half of the WS8.2 bug.)
            scheduleViewModel.setScheduleItems(projectViewModel.project.scheduleItems)
        case "Cast & Crew":
            castCrewViewModel.setCastMembers(projectViewModel.project.castMembers)
            castCrewViewModel.setCrewMembers(projectViewModel.project.crewMembers)
            castCrewViewModel.setTeams(projectViewModel.project.teams)
            castCrewViewModel.setEquipment(projectViewModel.project.equipmentLibrary)
            castCrewViewModel.characterNames = projectViewModel.project.characters.map { $0.name }
            castCrewViewModel.scheduleItems = projectViewModel.project.scheduleItems
            if let projectPath = projectViewModel.projectPath {
                castCrewViewModel.projectBasePath = projectPath.deletingLastPathComponent()
            }
        case "Accounting":
            budgetViewModel.setBudget(projectViewModel.project.projectBudget ?? ProjectBudget())
            budgetViewModel.castMembers = projectViewModel.project.castMembers
            budgetViewModel.crewMembers = projectViewModel.project.crewMembers
            budgetViewModel.equipment = projectViewModel.project.equipmentLibrary
            budgetViewModel.equipmentAllocations = projectViewModel.project.equipmentAllocations
            budgetViewModel.scheduleItems = projectViewModel.project.scheduleItems
            budgetViewModel.props = projectViewModel.project.props
            budgetViewModel.sequences = projectViewModel.project.sequences
            // Pass accounting defaults and project base path
            budgetViewModel.defaultDepartment = projectViewModel.project.defaultExpenseDepartment
            budgetViewModel.defaultAccountCode = projectViewModel.project.defaultExpenseAccountCode
            if let projectPath = projectViewModel.projectPath {
                budgetViewModel.projectBasePath = projectPath.deletingLastPathComponent()
            }
        case "Gantt":
            ganttViewModel.setTasks(projectViewModel.project.ganttTasks)
            ganttViewModel.scheduleItems = projectViewModel.project.scheduleItems
            ganttViewModel.castMembers = projectViewModel.project.castMembers
            ganttViewModel.crewMembers = projectViewModel.project.crewMembers
            ganttViewModel.characters = projectViewModel.project.characters
            ganttViewModel.props = projectViewModel.project.props
            ganttViewModel.equipment = projectViewModel.project.equipmentLibrary
            ganttViewModel.locations = projectViewModel.project.locations
            ganttViewModel.sequences = projectViewModel.project.sequences
        case "Equipment":
            equipmentViewModel.setEquipment(projectViewModel.project.equipmentLibrary)
            equipmentViewModel.setAllocations(projectViewModel.project.equipmentAllocations)
        default: break
        }
    }

    private func updateSceneStatus(sequenceName: String, sceneName: String, status: String) {
        if let seqIdx = projectViewModel.project.sequences.firstIndex(where: { $0.name == sequenceName }),
           let sceneIdx = projectViewModel.project.sequences[seqIdx].scenes.firstIndex(where: { $0.name == sceneName }) {
            projectViewModel.project.sequences[seqIdx].scenes[sceneIdx].productionStatus = status
        }
    }
}
struct ProductionViewWrapper<Content: View>: View {
    let project: Project
    let projectPath: URL?
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderBanner(
                project: project,
                projectPath: projectPath,
                subtitle: subtitle
            )

            Divider()

            content()
        }
    }
}

// MARK: - Cinematography View Adapter

/// Adapter view that integrates CinematographyView with scene-based shot storage
