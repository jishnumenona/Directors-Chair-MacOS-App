// DirectorsChairCore/Sources/DirectorsChairCore/Models/PropFabrication.swift
//
// Fabrication details for props that need to be built

import Foundation

/// Fabrication details for props that need to be built
public struct PropFabrication: Codable, Hashable {
    public var materialsNeeded: [String]  // List of materials
    public var dimensions: String  // Physical dimensions (e.g., "12\" x 8\" x 4\"")
    public var weight: String  // Weight if relevant
    public var constructionNotes: String  // Build instructions
    public var referenceImages: [String]  // Reference photo paths
    public var blueprintsPath: String?  // Path to technical drawings
    public var estimatedBuildTime: String  // e.g., "3 days", "1 week"
    public var builderAssigned: String  // Crew member name
    public var completionStatus: String  // "Not Started", "In Progress", "Complete"

    public init(
        materialsNeeded: [String] = [],
        dimensions: String = "",
        weight: String = "",
        constructionNotes: String = "",
        referenceImages: [String] = [],
        blueprintsPath: String? = nil,
        estimatedBuildTime: String = "",
        builderAssigned: String = "",
        completionStatus: String = "Not Started"
    ) {
        self.materialsNeeded = materialsNeeded
        self.dimensions = dimensions
        self.weight = weight
        self.constructionNotes = constructionNotes
        self.referenceImages = referenceImages
        self.blueprintsPath = blueprintsPath
        self.estimatedBuildTime = estimatedBuildTime
        self.builderAssigned = builderAssigned
        self.completionStatus = completionStatus
    }

    enum CodingKeys: String, CodingKey {
        case materialsNeeded = "materials_needed"
        case dimensions
        case weight
        case constructionNotes = "construction_notes"
        case referenceImages = "reference_images"
        case blueprintsPath = "blueprints_path"
        case estimatedBuildTime = "estimated_build_time"
        case builderAssigned = "builder_assigned"
        case completionStatus = "completion_status"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for fields missing in Python JSON
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        materialsNeeded = try container.decodeIfPresent([String].self, forKey: .materialsNeeded) ?? []
        dimensions = try container.decodeIfPresent(String.self, forKey: .dimensions) ?? ""
        weight = try container.decodeIfPresent(String.self, forKey: .weight) ?? ""
        constructionNotes = try container.decodeIfPresent(String.self, forKey: .constructionNotes) ?? ""
        referenceImages = try container.decodeIfPresent([String].self, forKey: .referenceImages) ?? []
        blueprintsPath = try container.decodeIfPresent(String.self, forKey: .blueprintsPath)
        estimatedBuildTime = try container.decodeIfPresent(String.self, forKey: .estimatedBuildTime) ?? ""
        builderAssigned = try container.decodeIfPresent(String.self, forKey: .builderAssigned) ?? ""
        completionStatus = try container.decodeIfPresent(String.self, forKey: .completionStatus) ?? "Not Started"
    }
}
