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

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to handle Python's mixed-type params (numbers, strings, bools)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Atmospheric"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""

        // Handle params with flexible types - convert everything to String
        if let paramsContainer = try? container.nestedContainer(keyedBy: DynamicKey.self, forKey: .params) {
            var paramsDict: [String: String] = [:]
            for key in paramsContainer.allKeys {
                // Try to decode as different types and convert to String
                if let stringValue = try? paramsContainer.decode(String.self, forKey: key) {
                    paramsDict[key.stringValue] = stringValue
                } else if let intValue = try? paramsContainer.decode(Int.self, forKey: key) {
                    paramsDict[key.stringValue] = String(intValue)
                } else if let doubleValue = try? paramsContainer.decode(Double.self, forKey: key) {
                    paramsDict[key.stringValue] = String(doubleValue)
                } else if let boolValue = try? paramsContainer.decode(Bool.self, forKey: key) {
                    paramsDict[key.stringValue] = String(boolValue)
                }
            }
            params = paramsDict
        } else {
            params = [:]
        }
    }

    // MARK: - Dynamic CodingKey for params dictionary

    /// Dynamic key for decoding arbitrary dictionary keys
    struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}
