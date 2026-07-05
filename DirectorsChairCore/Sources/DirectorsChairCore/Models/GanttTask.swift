// DirectorsChairCore/Sources/DirectorsChairCore/Models/GanttTask.swift
//
// Production Gantt chart task model

import Foundation

// MARK: - GanttTaskCategory

public enum GanttTaskCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case shooting = "Shooting"
    case preProduction = "Pre-Production"
    case postProduction = "Post-Production"
    case props = "Props"
    case wardrobe = "Wardrobe"
    case locations = "Locations"
    case castTalent = "Cast/Talent"
    case crew = "Crew"
    case equipment = "Equipment"
    case vfx = "VFX"
    case sound = "Sound"
    case custom = "Custom"

    public var defaultColor: String {
        switch self {
        case .shooting: return "#E74C3C"
        case .preProduction: return "#3498DB"
        case .postProduction: return "#9B59B6"
        case .props: return "#E67E22"
        case .wardrobe: return "#E91E63"
        case .locations: return "#2ECC71"
        case .castTalent: return "#F39C12"
        case .crew: return "#1ABC9C"
        case .equipment: return "#607D8B"
        case .vfx: return "#8E44AD"
        case .sound: return "#00BCD4"
        case .custom: return "#95A5A6"
        }
    }

    public var icon: String {
        switch self {
        case .shooting: return "film"
        case .preProduction: return "doc.text.magnifyingglass"
        case .postProduction: return "scissors"
        case .props: return "cube"
        case .wardrobe: return "tshirt"
        case .locations: return "map"
        case .castTalent: return "person.2"
        case .crew: return "person.3"
        case .equipment: return "camera"
        case .vfx: return "sparkles"
        case .sound: return "waveform"
        case .custom: return "tag"
        }
    }
}

// MARK: - GanttTask

public struct GanttTask: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var taskDescription: String
    public var category: GanttTaskCategory
    public var isMilestone: Bool

    // Schedule Item Link (nil if standalone custom task)
    public var scheduleItemId: String?

    // Timing (ISO YYYY-MM-DD strings)
    public var startDate: String
    public var endDate: String?
    public var durationDays: Int

    // Dependencies
    public var dependsOn: [String]
    public var dependencyType: String

    // Status & Progress
    public var status: String
    public var completionPercentage: Int
    public var priority: Int

    // Resource Tags
    public var assignedCastIds: [String]
    public var assignedCrewIds: [String]
    public var assignedCharacterNames: [String]
    public var requiredPropIds: [String]
    public var requiredEquipmentIds: [String]
    public var locationNames: [String]
    public var costumeNames: [String]
    public var customTags: [String]

    // Visual
    public var color: String?

    // Budget
    public var estimatedCost: Double
    public var actualCost: Double?

    // Notes & Grouping
    public var notes: String
    public var parentTaskId: String?
    public var sortOrder: Int

    // Metadata
    public var createdDate: String
    public var modifiedDate: String

    public init(
        id: String = "gantt_\(UUID().uuidString.prefix(12))",
        name: String = "",
        taskDescription: String = "",
        category: GanttTaskCategory = .custom,
        isMilestone: Bool = false,
        scheduleItemId: String? = nil,
        startDate: String = "",
        endDate: String? = nil,
        durationDays: Int = 1,
        dependsOn: [String] = [],
        dependencyType: String = "FS",
        status: String = "Not Started",
        completionPercentage: Int = 0,
        priority: Int = 3,
        assignedCastIds: [String] = [],
        assignedCrewIds: [String] = [],
        assignedCharacterNames: [String] = [],
        requiredPropIds: [String] = [],
        requiredEquipmentIds: [String] = [],
        locationNames: [String] = [],
        costumeNames: [String] = [],
        customTags: [String] = [],
        color: String? = nil,
        estimatedCost: Double = 0,
        actualCost: Double? = nil,
        notes: String = "",
        parentTaskId: String? = nil,
        sortOrder: Int = 0,
        createdDate: String = "",
        modifiedDate: String = ""
    ) {
        self.id = id
        self.name = name
        self.taskDescription = taskDescription
        self.category = category
        self.isMilestone = isMilestone
        self.scheduleItemId = scheduleItemId
        self.startDate = startDate
        self.endDate = endDate
        self.durationDays = durationDays
        self.dependsOn = dependsOn
        self.dependencyType = dependencyType
        self.status = status
        self.completionPercentage = completionPercentage
        self.priority = priority
        self.assignedCastIds = assignedCastIds
        self.assignedCrewIds = assignedCrewIds
        self.assignedCharacterNames = assignedCharacterNames
        self.requiredPropIds = requiredPropIds
        self.requiredEquipmentIds = requiredEquipmentIds
        self.locationNames = locationNames
        self.costumeNames = costumeNames
        self.customTags = customTags
        self.color = color
        self.estimatedCost = estimatedCost
        self.actualCost = actualCost
        self.notes = notes
        self.parentTaskId = parentTaskId
        self.sortOrder = sortOrder

        let now = Self.isoDateString()
        self.createdDate = createdDate.isEmpty ? now : createdDate
        self.modifiedDate = modifiedDate.isEmpty ? now : modifiedDate
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case taskDescription = "task_description"
        case category
        case isMilestone = "is_milestone"
        case scheduleItemId = "schedule_item_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case durationDays = "duration_days"
        case dependsOn = "depends_on"
        case dependencyType = "dependency_type"
        case status
        case completionPercentage = "completion_percentage"
        case priority
        case assignedCastIds = "assigned_cast_ids"
        case assignedCrewIds = "assigned_crew_ids"
        case assignedCharacterNames = "assigned_character_names"
        case requiredPropIds = "required_prop_ids"
        case requiredEquipmentIds = "required_equipment_ids"
        case locationNames = "location_names"
        case costumeNames = "costume_names"
        case customTags = "custom_tags"
        case color
        case estimatedCost = "estimated_cost"
        case actualCost = "actual_cost"
        case notes
        case parentTaskId = "parent_task_id"
        case sortOrder = "sort_order"
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
    }

    // MARK: - Custom Decoder

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "gantt_\(UUID().uuidString.prefix(12))"
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        taskDescription = try container.decodeIfPresent(String.self, forKey: .taskDescription) ?? ""
        category = try container.decodeIfPresent(GanttTaskCategory.self, forKey: .category) ?? .custom
        isMilestone = try container.decodeIfPresent(Bool.self, forKey: .isMilestone) ?? false
        scheduleItemId = try container.decodeIfPresent(String.self, forKey: .scheduleItemId)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate) ?? ""
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        durationDays = try container.decodeIfPresent(Int.self, forKey: .durationDays) ?? 1
        dependsOn = try container.decodeIfPresent([String].self, forKey: .dependsOn) ?? []
        dependencyType = try container.decodeIfPresent(String.self, forKey: .dependencyType) ?? "FS"
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "Not Started"
        completionPercentage = try container.decodeIfPresent(Int.self, forKey: .completionPercentage) ?? 0
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 3
        assignedCastIds = try container.decodeIfPresent([String].self, forKey: .assignedCastIds) ?? []
        assignedCrewIds = try container.decodeIfPresent([String].self, forKey: .assignedCrewIds) ?? []
        assignedCharacterNames = try container.decodeIfPresent([String].self, forKey: .assignedCharacterNames) ?? []
        requiredPropIds = try container.decodeIfPresent([String].self, forKey: .requiredPropIds) ?? []
        requiredEquipmentIds = try container.decodeIfPresent([String].self, forKey: .requiredEquipmentIds) ?? []
        locationNames = try container.decodeIfPresent([String].self, forKey: .locationNames) ?? []
        costumeNames = try container.decodeIfPresent([String].self, forKey: .costumeNames) ?? []
        customTags = try container.decodeIfPresent([String].self, forKey: .customTags) ?? []
        color = try container.decodeIfPresent(String.self, forKey: .color)
        estimatedCost = try container.decodeIfPresent(Double.self, forKey: .estimatedCost) ?? 0
        actualCost = try container.decodeIfPresent(Double.self, forKey: .actualCost)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        parentTaskId = try container.decodeIfPresent(String.self, forKey: .parentTaskId)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdDate = try container.decodeIfPresent(String.self, forKey: .createdDate) ?? Self.isoDateString()
        modifiedDate = try container.decodeIfPresent(String.self, forKey: .modifiedDate) ?? Self.isoDateString()
    }

    // MARK: - Helpers

    public static func isoDateString(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public var computedEndDate: String {
        if let end = endDate, !end.isEmpty { return end }
        guard !startDate.isEmpty else { return startDate }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: startDate) else { return startDate }
        let end = Calendar.current.date(byAdding: .day, value: max(durationDays - 1, 0), to: start) ?? start
        return formatter.string(from: end)
    }

    public var effectiveColor: String {
        color ?? category.defaultColor
    }
}
