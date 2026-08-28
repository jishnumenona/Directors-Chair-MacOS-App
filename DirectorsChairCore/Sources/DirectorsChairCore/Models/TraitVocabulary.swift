//
//  TraitVocabulary.swift
//  DirectorsChairCore
//
//  The ONE personality-trait vocabulary (DC-0078). Before this, Character
//  seeded 25 lowercase record keys ("confidence", "aggression", …) while the
//  Personality tab, the character-sheet HTML, the analyzer and the portal
//  deck all spoke the 25 Big-Five facet names ("Creativity", "Open-mindedness",
//  …) — a populated character carried 50 keys and the tab read only its own.
//  Every surface now reads this list; stored records are normalised on
//  decode (see `normalise`).
//

import Foundation

public enum TraitVocabulary {

    public struct Category: Equatable, Sendable {
        public let name: String
        public let facets: [String]
        public init(name: String, facets: [String]) {
            self.name = name
            self.facets = facets
        }
    }

    /// The Big-Five (OCEAN) categories in display order, five facets each.
    public static let categories: [Category] = [
        Category(name: "Openness",
                 facets: ["Creativity", "Curiosity", "Imagination", "Open-mindedness", "Artistic Interest"]),
        Category(name: "Conscientiousness",
                 facets: ["Organization", "Diligence", "Reliability", "Self-discipline", "Ambition"]),
        Category(name: "Extraversion",
                 facets: ["Sociability", "Energy", "Assertiveness", "Enthusiasm", "Talkativeness"]),
        Category(name: "Agreeableness",
                 facets: ["Empathy", "Cooperation", "Trust", "Kindness", "Politeness"]),
        Category(name: "Neuroticism",
                 facets: ["Anxiety", "Moodiness", "Sensitivity", "Irritability", "Self-consciousness"]),
    ]

    /// All 25 facet names in category order — the canonical keys of
    /// `Character.traits`.
    public static let facets: [String] = categories.flatMap(\.facets)

    /// The score a facet has when nobody has said otherwise.
    public static let neutral: Double = 50

    /// Facets by category name ("Openness" → its five).
    public static func facets(in category: String) -> [String] {
        categories.first { $0.name.caseInsensitiveCompare(category) == .orderedSame }?.facets ?? []
    }

    /// Every facet at the neutral score.
    public static func defaults() -> [String: Double] {
        Dictionary(uniqueKeysWithValues: facets.map { ($0, neutral) })
    }

    /// The canonical spelling for any reasonable spelling of a facet —
    /// case-insensitive, tolerant of spaces, hyphens and underscores
    /// ("open mindedness", "SELF_DISCIPLINE", "empathy"). nil = not a facet.
    public static func canonicalName(_ name: String) -> String? {
        let key = fold(name)
        guard !key.isEmpty else { return nil }
        return facets.first { fold($0) == key }
    }

    static func fold(_ name: String) -> String {
        String(name.lowercased().filter { $0.isLetter })
    }

    /// A stored trait dictionary brought onto the vocabulary.
    public struct Normalised: Equatable, Sendable {
        /// Exactly the 25 facets.
        public var traits: [String: Double]
        /// Keys that are not facets and were not at the neutral score — a
        /// user-set value is never thrown away, it just stops pretending
        /// to be a facet. Empty for records already on the vocabulary.
        public var legacy: [String: Double]
    }

    /// Normalise a stored dictionary: every facet present (missing ones at
    /// neutral), aliases folded onto their facet ("empathy" → "Empathy";
    /// an exact canonical key wins over an alias when both exist), and
    /// everything else either dropped (still at neutral — the seeded
    /// default carried no information) or kept under `legacy`.
    public static func normalise(_ stored: [String: Double]) -> Normalised {
        var traits = defaults()
        var legacy: [String: Double] = [:]
        var setExactly: Set<String> = []
        for (key, value) in stored where facets.contains(key) {
            traits[key] = value
            setExactly.insert(key)
        }
        for (key, value) in stored where !facets.contains(key) {
            if let canonical = canonicalName(key) {
                if !setExactly.contains(canonical) { traits[canonical] = value }
            } else if value != neutral {
                legacy[key] = value
            }
        }
        return Normalised(traits: traits, legacy: legacy)
    }
}
