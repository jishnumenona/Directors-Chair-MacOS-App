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

        // AI receipt analysis callback
        // Capture category names upfront (on main actor) to avoid actor-isolation issues in the async closure
        let capturedBudgetVM = budgetViewModel
        budgetViewModel.onAnalyzeReceipt = { imageData, mimeType in
            // Logging routes through the global os.Logger-based debugLog, which is
            // not persisted in release. Receipt contents (vendor, amounts, dates)
            // are financial data and are NEVER written to a file on disk.
            let aiClient = AIServiceClient.shared
            debugLog("Starting analysis, data size: \(imageData.count) bytes, mime: \(mimeType)")

            guard await aiClient.testConnection() else {
                debugLog("AI server connection failed")
                return []
            }
            debugLog("Server connection OK")

            let base64 = imageData.base64EncodedString()
            debugLog("Base64 encoded, length: \(base64.count)")

            // Build category names on main actor
            let categoryNames = capturedBudgetVM.budget.categories.map { $0.name }.joined(separator: ", ")
            debugLog("Categories: \(categoryNames)")

            let prompt = """
            Analyze this receipt image. If the receipt contains multiple distinct line items, return ALL items individually.
            Return ONLY valid JSON with this structure:
            {
              "vendor": "store/vendor name",
              "date": "YYYY-MM-DD format",
              "items": [
                {"description": "item 1 description", "amount": 12.99, "category": "best matching category"},
                {"description": "item 2 description", "amount": 45.00, "category": "best matching category"}
              ]
            }

            Rules:
            - "vendor" and "date" are shared across all items.
            - Each item in "items" should have its own description, amount, and category.
            - If the receipt has only one item or a single total, return a single item in the array.
            - Do NOT include tax/tip as separate items unless they are distinct line items on the receipt.
            - Available budget categories: \(categoryNames)
            - Choose the category that best matches each item. If no category matches well, use the most general one.
            - Return ONLY the JSON object, no other text.
            """

            let request = TextGenerationRequest(
                prompt: prompt,
                provider: .google,
                maxTokens: 4000,
                temperature: 0.1,
                imageBase64: base64,
                imageMimeType: mimeType
            )

            do {
                debugLog("Sending request to AI...")
                let response = try await aiClient.generateText(request)
                let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                debugLog("AI response received: \(text.count) chars")  // don't log raw financial content

                // Strip markdown code fences if present
                var jsonString = text
                if jsonString.hasPrefix("```json") {
                    jsonString = String(jsonString.dropFirst(7))
                } else if jsonString.hasPrefix("```") {
                    jsonString = String(jsonString.dropFirst(3))
                }
                if jsonString.hasSuffix("```") {
                    jsonString = String(jsonString.dropLast(3))
                }
                jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
                debugLog("Cleaned JSON: \(jsonString.count) chars")  // don't log raw financial content

                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    debugLog("Failed to parse JSON")
                    return []
                }

                debugLog("Parsed JSON: \(json)")

                let sharedVendor = json["vendor"] as? String ?? ""
                let sharedDate = json["date"] as? String ?? ""

                guard let items = json["items"] as? [[String: Any]], !items.isEmpty else {
                    debugLog("No items array found in response")
                    return []
                }

                var results: [ReceiptAnalysisResult] = []
                for item in items {
                    // Handle amount as either Double or Int from JSON
                    let parsedAmount: Double
                    if let doubleVal = item["amount"] as? Double {
                        parsedAmount = doubleVal
                    } else if let intVal = item["amount"] as? Int {
                        parsedAmount = Double(intVal)
                    } else if let strVal = item["amount"] as? String, let numVal = Double(strVal) {
                        parsedAmount = numVal
                    } else {
                        parsedAmount = 0
                    }

                    let result = ReceiptAnalysisResult(
                        description: item["description"] as? String ?? "",
                        vendor: sharedVendor,
                        date: sharedDate,
                        amount: parsedAmount,
                        category: item["category"] as? String ?? ""
                    )
                    results.append(result)
                }

                debugLog("Returning \(results.count) results")
                return results
            } catch {
                debugLog("Error: \(error)")
                return []
            }
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
