// StoryDesignModelTests.swift
// Tests for StoryDesignMode, DesignTab, TraitCategory, GeminiVoice enums and structs

import XCTest
@testable import DirectorsChairViews

final class StoryDesignModelTests: XCTestCase {

    // MARK: - StoryDesignMode

    func testStoryDesignModeAllCases() {
        // Lighting design belongs to the Theater edition — the cinema build
        // has exactly Characters and Locations.
        XCTAssertEqual(StoryDesignMode.allCases.count, 2)
        XCTAssertTrue(StoryDesignMode.allCases.contains(.characters))
        XCTAssertTrue(StoryDesignMode.allCases.contains(.locations))
    }

    func testStoryDesignModeRawValues() {
        XCTAssertEqual(StoryDesignMode.characters.rawValue, "characters")
        XCTAssertEqual(StoryDesignMode.locations.rawValue, "locations")
    }

    func testStoryDesignModeDisplayNames() {
        XCTAssertEqual(StoryDesignMode.characters.displayName, "Characters")
        XCTAssertEqual(StoryDesignMode.locations.displayName, "Locations")
    }

    func testStoryDesignModeIcons() {
        XCTAssertEqual(StoryDesignMode.characters.icon, "person.fill")
        XCTAssertEqual(StoryDesignMode.locations.icon, "map.fill")
    }

    func testStoryDesignModeIconsNotEmpty() {
        for mode in StoryDesignMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty)
            XCTAssertFalse(mode.displayName.isEmpty)
        }
    }

    // MARK: - DesignTab

    func testDesignTabAllCases() {
        XCTAssertEqual(DesignTab.allCases.count, 7)
    }

    func testDesignTabContainsExpected() {
        let cases = DesignTab.allCases
        XCTAssertTrue(cases.contains(.physical))
        XCTAssertTrue(cases.contains(.costume))
        XCTAssertTrue(cases.contains(.traits))
        XCTAssertTrue(cases.contains(.biography))
        XCTAssertTrue(cases.contains(.relationships))
        XCTAssertTrue(cases.contains(.voice))
        XCTAssertTrue(cases.contains(.scenes))
    }

    func testDesignTabRawValues() {
        XCTAssertEqual(DesignTab.physical.rawValue, "physical")
        XCTAssertEqual(DesignTab.costume.rawValue, "costume")
        XCTAssertEqual(DesignTab.traits.rawValue, "traits")
        XCTAssertEqual(DesignTab.biography.rawValue, "biography")
        XCTAssertEqual(DesignTab.relationships.rawValue, "relationships")
        XCTAssertEqual(DesignTab.voice.rawValue, "voice")
        XCTAssertEqual(DesignTab.scenes.rawValue, "scenes")
    }

    func testDesignTabDisplayNames() {
        XCTAssertEqual(DesignTab.physical.displayName, "Physical")
        XCTAssertEqual(DesignTab.costume.displayName, "Costume")
        XCTAssertEqual(DesignTab.traits.displayName, "Traits")
        XCTAssertEqual(DesignTab.biography.displayName, "Biography")
        XCTAssertEqual(DesignTab.relationships.displayName, "Relationships")
        XCTAssertEqual(DesignTab.voice.displayName, "Voice")
        XCTAssertEqual(DesignTab.scenes.displayName, "Scenes")
    }

    func testDesignTabIcons() {
        XCTAssertEqual(DesignTab.physical.icon, "person.fill")
        XCTAssertEqual(DesignTab.costume.icon, "tshirt")
        XCTAssertEqual(DesignTab.traits.icon, "chart.pie.fill")
        XCTAssertEqual(DesignTab.biography.icon, "book.fill")
        XCTAssertEqual(DesignTab.relationships.icon, "person.2.fill")
        XCTAssertEqual(DesignTab.voice.icon, "waveform")
        XCTAssertEqual(DesignTab.scenes.icon, "film")
    }

    func testDesignTabIconsUnique() {
        let icons = DesignTab.allCases.map { $0.icon }
        XCTAssertEqual(Set(icons).count, icons.count, "All DesignTab icons should be unique")
    }

    func testDesignTabInitFromRawValue() {
        XCTAssertEqual(DesignTab(rawValue: "physical"), .physical)
        XCTAssertEqual(DesignTab(rawValue: "voice"), .voice)
        XCTAssertNil(DesignTab(rawValue: "unknown"))
    }

    // MARK: - TraitCategory (OCEAN)

    func testTraitCategoryAllCases() {
        XCTAssertEqual(TraitCategory.allCases.count, 5)
    }

    func testTraitCategoryOCEAN() {
        // Verify the 5 OCEAN categories
        let cases = TraitCategory.allCases
        XCTAssertTrue(cases.contains(.openness))
        XCTAssertTrue(cases.contains(.conscientiousness))
        XCTAssertTrue(cases.contains(.extraversion))
        XCTAssertTrue(cases.contains(.agreeableness))
        XCTAssertTrue(cases.contains(.neuroticism))
    }

    func testTraitCategoryDisplayNames() {
        XCTAssertEqual(TraitCategory.openness.displayName, "Openness")
        XCTAssertEqual(TraitCategory.conscientiousness.displayName, "Conscientiousness")
        XCTAssertEqual(TraitCategory.extraversion.displayName, "Extraversion")
        XCTAssertEqual(TraitCategory.agreeableness.displayName, "Agreeableness")
        XCTAssertEqual(TraitCategory.neuroticism.displayName, "Neuroticism")
    }

    func testTraitCategoryDisplayNameIsCapitalizedRawValue() {
        for category in TraitCategory.allCases {
            XCTAssertEqual(category.displayName, category.rawValue.capitalized)
        }
    }

    func testTraitCategoryIcons() {
        XCTAssertEqual(TraitCategory.openness.icon, "lightbulb")
        XCTAssertEqual(TraitCategory.conscientiousness.icon, "checkmark.seal")
        XCTAssertEqual(TraitCategory.extraversion.icon, "person.wave.2")
        XCTAssertEqual(TraitCategory.agreeableness.icon, "heart")
        XCTAssertEqual(TraitCategory.neuroticism.icon, "bolt.heart")
    }

    func testTraitCategoryIconsNotEmpty() {
        for category in TraitCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category) icon should not be empty")
        }
    }

    func testTraitCategoryTraitCount() {
        // Each OCEAN category has exactly 5 traits
        for category in TraitCategory.allCases {
            XCTAssertEqual(category.traits.count, 5,
                "\(category) should have exactly 5 traits, got \(category.traits.count)")
        }
    }

    func testTraitCategoryTraitsNotEmpty() {
        for category in TraitCategory.allCases {
            for trait in category.traits {
                XCTAssertFalse(trait.isEmpty, "Trait in \(category) should not be empty")
            }
        }
    }

    func testTraitCategoryTotal25Traits() {
        let totalTraits = TraitCategory.allCases.flatMap { $0.traits }
        XCTAssertEqual(totalTraits.count, 25, "Should have 25 total traits (5 categories × 5)")
    }

    func testTraitCategoryTraitsUnique() {
        let allTraits = TraitCategory.allCases.flatMap { $0.traits }
        XCTAssertEqual(Set(allTraits).count, allTraits.count, "All 25 traits should be unique")
    }

    func testOpennessTraits() {
        let expected = ["Creativity", "Curiosity", "Imagination", "Open-mindedness", "Artistic Interest"]
        XCTAssertEqual(TraitCategory.openness.traits, expected)
    }

    func testConscientiousnessTraits() {
        let expected = ["Organization", "Diligence", "Reliability", "Self-discipline", "Ambition"]
        XCTAssertEqual(TraitCategory.conscientiousness.traits, expected)
    }

    func testExtraversionTraits() {
        let expected = ["Sociability", "Energy", "Assertiveness", "Enthusiasm", "Talkativeness"]
        XCTAssertEqual(TraitCategory.extraversion.traits, expected)
    }

    func testAgreeablenessTraits() {
        let expected = ["Empathy", "Cooperation", "Trust", "Kindness", "Politeness"]
        XCTAssertEqual(TraitCategory.agreeableness.traits, expected)
    }

    func testNeuroticismTraits() {
        let expected = ["Anxiety", "Moodiness", "Sensitivity", "Irritability", "Self-consciousness"]
        XCTAssertEqual(TraitCategory.neuroticism.traits, expected)
    }

    // MARK: - GeminiVoice

    func testGeminiVoiceCount() {
        XCTAssertEqual(GeminiVoice.allVoices.count, 30, "Should have exactly 30 Gemini voices")
    }

    func testGeminiVoiceFemaleCount() {
        let females = GeminiVoice.allVoices.filter { $0.gender == .female }
        XCTAssertEqual(females.count, 14, "Should have 14 female voices")
    }

    func testGeminiVoiceMaleCount() {
        let males = GeminiVoice.allVoices.filter { $0.gender == .male }
        XCTAssertEqual(males.count, 16, "Should have 16 male voices")
    }

    func testGeminiVoiceUniqueIds() {
        let ids = GeminiVoice.allVoices.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "All voice IDs should be unique")
    }

    func testGeminiVoiceUniqueNames() {
        let names = GeminiVoice.allVoices.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count, "All voice names should be unique")
    }

    func testGeminiVoiceDescriptionFormat() {
        for voice in GeminiVoice.allVoices {
            let desc = voice.description
            XCTAssertTrue(desc.contains(" — "), "Description '\(desc)' should contain em dash separator")
            XCTAssertTrue(desc.hasPrefix(voice.name), "Description should start with name")
            XCTAssertTrue(desc.hasSuffix(voice.descriptor), "Description should end with descriptor")
        }
    }

    func testGeminiVoiceSpecificVoice() {
        let zephyr = GeminiVoice.allVoices.first { $0.id == "zephyr" }
        XCTAssertNotNil(zephyr)
        XCTAssertEqual(zephyr?.name, "Zephyr")
        XCTAssertEqual(zephyr?.descriptor, "Bright")
        XCTAssertEqual(zephyr?.gender, .female)
        XCTAssertEqual(zephyr?.icon, "wind")
    }

    func testGeminiVoiceSpecificMaleVoice() {
        let puck = GeminiVoice.allVoices.first { $0.id == "puck" }
        XCTAssertNotNil(puck)
        XCTAssertEqual(puck?.name, "Puck")
        XCTAssertEqual(puck?.descriptor, "Upbeat")
        XCTAssertEqual(puck?.gender, .male)
        XCTAssertEqual(puck?.icon, "theatermasks")
    }

    func testGeminiVoiceFieldsNotEmpty() {
        for voice in GeminiVoice.allVoices {
            XCTAssertFalse(voice.id.isEmpty, "Voice id should not be empty")
            XCTAssertFalse(voice.name.isEmpty, "Voice name should not be empty")
            XCTAssertFalse(voice.descriptor.isEmpty, "Voice descriptor should not be empty")
            XCTAssertFalse(voice.icon.isEmpty, "Voice icon should not be empty")
        }
    }

    func testGeminiVoiceEquality() {
        let a = GeminiVoice(id: "test", name: "Test", descriptor: "Warm", gender: .male, icon: "sun.max")
        let b = GeminiVoice(id: "test", name: "Test", descriptor: "Warm", gender: .male, icon: "sun.max")
        XCTAssertEqual(a, b)
    }

    func testGeminiVoiceInequality() {
        let a = GeminiVoice(id: "test1", name: "Test1", descriptor: "Warm", gender: .male, icon: "sun.max")
        let b = GeminiVoice(id: "test2", name: "Test2", descriptor: "Cold", gender: .female, icon: "moon")
        XCTAssertNotEqual(a, b)
    }

    func testGeminiVoiceIdMatchesName() {
        // All voices should have id == lowercased name
        for voice in GeminiVoice.allVoices {
            XCTAssertEqual(voice.id, voice.name.lowercased(),
                "Voice '\(voice.name)' id should be lowercased name")
        }
    }
}
