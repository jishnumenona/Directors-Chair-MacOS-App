// DirectorsChairCore/Sources/DirectorsChairCore/Models/EffectDef.swift
//
// Visual/atmospheric effect definition

import Foundation

/// Represents a visual or atmospheric effect definition
public struct EffectDef: Codable, Identifiable, Hashable {
    public var id: String { name }

    public var name: String
    public var category: String  // e.g., "Atmospheric", "Smoke", "Rain", "Fog", "Particle"
    public var params: [String: String]  // Flexible parameters for effect configuration
    public var notes: String

    public init(
        name: String,
        category: String = "Atmospheric",
        params: [String: String] = [:],
        notes: String = ""
    ) {
        self.name = name
        self.category = category
        self.params = params
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case name
        case category
        case params
        case notes
    }
}
