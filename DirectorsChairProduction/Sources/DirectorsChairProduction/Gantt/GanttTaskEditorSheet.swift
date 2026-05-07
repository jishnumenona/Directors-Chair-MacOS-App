// DirectorsChairProduction/Sources/DirectorsChairProduction/Gantt/GanttTaskEditorSheet.swift
//
// Add/Edit form for Gantt tasks

import SwiftUI
import DirectorsChairCore

public struct GanttTaskEditorSheet: View {
    @ObservedObject var viewModel: GanttViewModel
    let editingTask: GanttTask?
    let onSave: (GanttTask) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var taskDescription: String = ""
    @State private var category: GanttTaskCategory = .custom
    @State private var isMilestone: Bool = false
    @State private var startDate: Date = Date()
    @State private var durationDays: Int = 1
    @State private var status: String = "Not Started"
    @State private var priority: Int = 3
    @State private var completionPercentage: Int = 0
    @State private var selectedDependencies: Set<String> = []
    @State private var selectedCastIds: Set<String> = []
    @State private var selectedCrewIds: Set<String> = []
    @State private var selectedCharacterNames: Set<String> = []
    @State private var selectedPropIds: Set<String> = []
    @State private var selectedEquipmentIds: Set<String> = []
    @State private var selectedLocationNames: Set<String> = []
    @State private var selectedCostumeNames: Set<String> = []
    @State private var customTagsText: String = ""
    @State private var estimatedCost: Double = 0
    @State private var actualCost: Double = 0
    @State private var notes: String = ""
    @State private var customColor: String = ""

    private var durationDaysDouble: Binding<Double> {
        Binding(get: { Double(durationDays) }, set: { durationDays = max(1, Int($0)) })
    }
    private var priorityDouble: Binding<Double> {
        Binding(get: { Double(priority) }, set: { priority = max(1, min(5, Int($0))) })
    }
    private var completionDouble: Binding<Double> {
        Binding(get: { Double(completionPercentage) }, set: { completionPercentage = max(0, min(100, Int($0))) })
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let statuses = ["Not Started", "In Progress", "Complete", "On Hold", "Cancelled"]

    public init(
        viewModel: GanttViewModel,
        editingTask: GanttTask?,
        onSave: @escaping (GanttTask) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.editingTask = editingTask
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: editingTask != nil ? "Edit Task" : "New Task",
                canSave: !name.isEmpty,
                onCancel: onCancel,
                onSave: saveTask
            )

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    taskInfoSection
                    scheduleSection
                    dependenciesSection
                    resourcesSection
                    tagsSection
                    budgetSection
                    notesSection
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { loadTask() }
    }

    // MARK: - Task Info

    private var taskInfoSection: some View {
        ProductionCard(icon: "doc.text", title: "TASK INFO") {
            VStack(spacing: 12) {
                StyledTextField("Task Name", text: $name)

                VStack(alignment: .leading, spacing: 4) {
                    Text("DESCRIPTION")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    TextEditor(text: $taskDescription)
                        .font(.system(size: 11))
                        .frame(height: 50)
                        .padding(4)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("CATEGORY")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 4) {
                        ForEach(GanttTaskCategory.allCases, id: \.self) { cat in
                            ProductionChip(icon: cat.icon, cat.rawValue, selected: category == cat
                            ) {
                                category = cat
                            }
                        }
                    }
                }

                Toggle("Milestone (zero duration)", isOn: $isMilestone)
                    .font(.system(size: 11))
            }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        ProductionCard(icon: "calendar", title: "SCHEDULE") {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("START DATE")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.2)
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                    }

                    if !isMilestone {
                        StyledNumberField("Duration (days)", value: durationDaysDouble)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("STATUS")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    HStack(spacing: 4) {
                        ForEach(statuses, id: \.self) { s in
                            ProductionChip(icon: statusIcon(s), s, selected: status == s
                            ) {
                                status = s
                            }
                        }
                    }
                }

                HStack(spacing: 16) {
                    StyledNumberField("Priority (1-5)", value: priorityDouble)
                    StyledNumberField("Completion %", value: completionDouble)
                }
            }
        }
    }

    // MARK: - Dependencies

    private var dependenciesSection: some View {
        ProductionCard(icon: "arrow.triangle.branch", title: "DEPENDENCIES") {
            VStack(alignment: .leading, spacing: 6) {
                if viewModel.tasks.isEmpty || (viewModel.tasks.count == 1 && editingTask != nil) {
                    Text("No other tasks available")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                } else {
                    Text("Depends on (finish-to-start):")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 4) {
                        ForEach(viewModel.tasks.filter { $0.id != editingTask?.id }, id: \.id) { t in
                            ProductionChip(icon: t.category.icon, t.name, selected: selectedDependencies.contains(t.id)
                            ) {
                                if selectedDependencies.contains(t.id) {
                                    selectedDependencies.remove(t.id)
                                } else {
                                    selectedDependencies.insert(t.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Resources

    private var resourcesSection: some View {
        ProductionCard(icon: "person.2", title: "RESOURCES") {
            VStack(alignment: .leading, spacing: 12) {
                if !viewModel.castMembers.isEmpty {
                    resourceChipGrid(title: "CAST", items: viewModel.castMembers.map { ($0.id, $0.actorName, "person") }, selection: $selectedCastIds)
                }
                if !viewModel.crewMembers.isEmpty {
                    resourceChipGrid(title: "CREW", items: viewModel.crewMembers.map { ($0.id, $0.name, "person.3") }, selection: $selectedCrewIds)
                }
                if !viewModel.characters.isEmpty {
                    resourceChipGrid(title: "CHARACTERS", items: viewModel.characters.map { ($0.name, $0.name, "theatermasks") }, selection: $selectedCharacterNames)
                }
                if !viewModel.props.isEmpty {
                    resourceChipGrid(title: "PROPS", items: viewModel.props.map { ($0.id, $0.name, "cube") }, selection: $selectedPropIds)
                }
                if !viewModel.equipment.isEmpty {
                    resourceChipGrid(title: "EQUIPMENT", items: viewModel.equipment.map { ($0.id, $0.name, "camera") }, selection: $selectedEquipmentIds)
                }
                if !viewModel.locations.isEmpty {
                    resourceChipGrid(title: "LOCATIONS", items: viewModel.locations.map { ($0.name, $0.name, "map") }, selection: $selectedLocationNames)
                }
            }
        }
    }

    private func resourceChipGrid(title: String, items: [(String, String, String)], selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                ForEach(items, id: \.0) { item in
                    ProductionChip(icon: item.2, item.1, selected: selection.wrappedValue.contains(item.0)
                    ) {
                        if selection.wrappedValue.contains(item.0) {
                            selection.wrappedValue.remove(item.0)
                        } else {
                            selection.wrappedValue.insert(item.0)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        ProductionCard(icon: "tag", title: "CUSTOM TAGS") {
            VStack(alignment: .leading, spacing: 6) {
                StyledTextField("Tags (comma separated)", text: $customTagsText)
                if !viewModel.allCustomTags.isEmpty {
                    Text("Existing tags:")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 4) {
                        ForEach(viewModel.allCustomTags, id: \.self) { tag in
                            let isInText = customTagsText.lowercased().contains(tag.lowercased())
                            ProductionChip(icon: "tag", tag, selected: isInText) {
                                if isInText {
                                    // remove
                                    let tags = customTagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                                    customTagsText = tags.filter { $0.lowercased() != tag.lowercased() }.joined(separator: ", ")
                                } else {
                                    if customTagsText.isEmpty {
                                        customTagsText = tag
                                    } else {
                                        customTagsText += ", \(tag)"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Budget

    private var budgetSection: some View {
        ProductionCard(icon: "dollarsign.circle", title: "BUDGET") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTIMATED COST")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    TextField("0.00", value: $estimatedCost, format: .currency(code: "USD"))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTUAL COST")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    TextField("0.00", value: $actualCost, format: .currency(code: "USD"))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(6)
                        .background(Color(nsColor: .quaternarySystemFill))
                        .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        ProductionCard(icon: "note.text", title: "NOTES") {
            TextEditor(text: $notes)
                .font(.system(size: 11))
                .frame(height: 60)
                .padding(4)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(6)
        }
    }

    // MARK: - Helpers

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

    private func loadTask() {
        guard let t = editingTask else { return }
        name = t.name
        taskDescription = t.taskDescription
        category = t.category
        isMilestone = t.isMilestone
        if let d = Self.dateFormatter.date(from: t.startDate) {
            startDate = d
        }
        durationDays = t.durationDays
        status = t.status
        priority = t.priority
        completionPercentage = t.completionPercentage
        selectedDependencies = Set(t.dependsOn)
        selectedCastIds = Set(t.assignedCastIds)
        selectedCrewIds = Set(t.assignedCrewIds)
        selectedCharacterNames = Set(t.assignedCharacterNames)
        selectedPropIds = Set(t.requiredPropIds)
        selectedEquipmentIds = Set(t.requiredEquipmentIds)
        selectedLocationNames = Set(t.locationNames)
        selectedCostumeNames = Set(t.costumeNames)
        customTagsText = t.customTags.joined(separator: ", ")
        estimatedCost = t.estimatedCost
        actualCost = t.actualCost ?? 0
        notes = t.notes
        customColor = t.color ?? ""
    }

    private func saveTask() {
        var t = editingTask ?? GanttTask()
        t.name = name
        t.taskDescription = taskDescription
        t.category = category
        t.isMilestone = isMilestone
        t.startDate = Self.dateFormatter.string(from: startDate)
        t.durationDays = isMilestone ? 0 : durationDays
        t.status = status
        t.priority = priority
        t.completionPercentage = completionPercentage
        t.dependsOn = Array(selectedDependencies)
        t.assignedCastIds = Array(selectedCastIds)
        t.assignedCrewIds = Array(selectedCrewIds)
        t.assignedCharacterNames = Array(selectedCharacterNames)
        t.requiredPropIds = Array(selectedPropIds)
        t.requiredEquipmentIds = Array(selectedEquipmentIds)
        t.locationNames = Array(selectedLocationNames)
        t.costumeNames = Array(selectedCostumeNames)
        t.customTags = customTagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        t.estimatedCost = estimatedCost
        t.actualCost = actualCost > 0 ? actualCost : nil
        t.notes = notes
        t.color = customColor.isEmpty ? nil : customColor
        t.modifiedDate = GanttTask.isoDateString()
        onSave(t)
    }
}
