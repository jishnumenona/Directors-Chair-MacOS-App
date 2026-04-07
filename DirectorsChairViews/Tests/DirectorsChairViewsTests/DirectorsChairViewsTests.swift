// DirectorsChairViewsTests/DirectorsChairViewsTests.swift
//
// Tests for DirectorsChairViews module

import XCTest
import SwiftUI
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class DirectorsChairViewsTests: XCTestCase {

    // MARK: - Module Version Tests

    func testModuleVersion() {
        XCTAssertFalse(DirectorsChairViewsVersion.version.isEmpty)
        XCTAssertFalse(DirectorsChairViewsVersion.build.isEmpty)
    }

    // MARK: - Color Extension Tests

    func testColorFromHex6() {
        let color = Color(hex: "#FF0000")
        // Color should be created without crashing
        XCTAssertNotNil(color)
    }

    func testColorFromHex3() {
        let color = Color(hex: "#F00")
        XCTAssertNotNil(color)
    }

    func testColorFromHex8() {
        let color = Color(hex: "#FF0000FF")
        XCTAssertNotNil(color)
    }

    // MARK: - BubbleItem Tests

    func testBubbleItemDialogueId() {
        let dialogue = Dialogue(
            character: "John",
            text: "Hello",
            chronologyNumber: 1
        )

        // BubbleItem should be creatable with dialogue
        // Note: BubbleItem is internal to BubbleView, so this tests the model
        XCTAssertEqual(dialogue.character, "John")
        XCTAssertEqual(dialogue.text, "Hello")
        XCTAssertEqual(dialogue.chronologyNumber, 1)
    }

    func testBubbleItemActionId() {
        let action = Action(
            description: "Walks across room",
            chronologyNumber: 2,
            characters: ["John"]
        )

        XCTAssertEqual(action.description, "Walks across room")
        XCTAssertEqual(action.characters, ["John"])
        XCTAssertEqual(action.chronologyNumber, 2)
    }

    // MARK: - Trait Category Tests

    func testTraitCategoryOpenness() {
        let category = TraitCategory.openness
        XCTAssertEqual(category.displayName, "Openness")
        XCTAssertEqual(category.traits.count, 5)
        XCTAssertTrue(category.traits.contains("Creativity"))
    }

    func testTraitCategoryConscientiousness() {
        let category = TraitCategory.conscientiousness
        XCTAssertEqual(category.displayName, "Conscientiousness")
        XCTAssertEqual(category.traits.count, 5)
        XCTAssertTrue(category.traits.contains("Organization"))
    }

    func testTraitCategoryExtraversion() {
        let category = TraitCategory.extraversion
        XCTAssertEqual(category.displayName, "Extraversion")
        XCTAssertEqual(category.traits.count, 5)
        XCTAssertTrue(category.traits.contains("Sociability"))
    }

    func testTraitCategoryAgreeableness() {
        let category = TraitCategory.agreeableness
        XCTAssertEqual(category.displayName, "Agreeableness")
        XCTAssertEqual(category.traits.count, 5)
        XCTAssertTrue(category.traits.contains("Empathy"))
    }

    func testTraitCategoryNeuroticism() {
        let category = TraitCategory.neuroticism
        XCTAssertEqual(category.displayName, "Neuroticism")
        XCTAssertEqual(category.traits.count, 5)
        XCTAssertTrue(category.traits.contains("Anxiety"))
    }

    func testAllTraitCategories() {
        let allCategories = TraitCategory.allCases
        XCTAssertEqual(allCategories.count, 5)

        // Total traits should be 25 (5 categories x 5 traits)
        let totalTraits = allCategories.reduce(0) { $0 + $1.traits.count }
        XCTAssertEqual(totalTraits, 25)
    }

    // MARK: - Design Tab Tests

    func testDesignTabCases() {
        let allTabs = DesignTab.allCases
        XCTAssertEqual(allTabs.count, 7)
        XCTAssertTrue(allTabs.contains(.physical))
        XCTAssertTrue(allTabs.contains(.costume))
        XCTAssertTrue(allTabs.contains(.traits))
        XCTAssertTrue(allTabs.contains(.biography))
        XCTAssertTrue(allTabs.contains(.relationships))
        XCTAssertTrue(allTabs.contains(.voice))
        XCTAssertTrue(allTabs.contains(.scenes))
    }

    func testDesignTabDisplayNames() {
        XCTAssertEqual(DesignTab.physical.displayName, "Physical")
        XCTAssertEqual(DesignTab.traits.displayName, "Traits")
        XCTAssertEqual(DesignTab.biography.displayName, "Biography")
        XCTAssertEqual(DesignTab.relationships.displayName, "Relationships")
        XCTAssertEqual(DesignTab.scenes.displayName, "Scenes")
    }

    func testDesignTabIcons() {
        XCTAssertFalse(DesignTab.physical.icon.isEmpty)
        XCTAssertFalse(DesignTab.traits.icon.isEmpty)
        XCTAssertFalse(DesignTab.biography.icon.isEmpty)
        XCTAssertFalse(DesignTab.relationships.icon.isEmpty)
        XCTAssertFalse(DesignTab.scenes.icon.isEmpty)
    }
}

// MARK: - View Instantiation Tests

@available(macOS 14.0, *)
final class ViewInstantiationTests: XCTestCase {

    func testDialogueBubbleCardInstantiation() {
        let dialogue = Dialogue(
            character: "Test",
            text: "Test dialogue",
            chronologyNumber: 1
        )

        let view = DialogueBubbleCard(
            dialogue: dialogue,
            character: nil,
            isSelected: false,
            isPrimaryCharacter: true
        )

        XCTAssertNotNil(view)
    }

    func testActionBubbleCardInstantiation() {
        let action = Action(
            description: "Test action",
            chronologyNumber: 1,
            characters: []
        )

        let view = ActionBubbleCard(action: action, isSelected: false)
        XCTAssertNotNil(view)
    }

    func testNarrationBubbleCardInstantiation() {
        let narration = Narration(
            text: "Test narration",
            chronologyNumber: 1,
            characters: []
        )

        let view = NarrationBubbleCard(narration: narration, isSelected: false)
        XCTAssertNotNil(view)
    }

    func testNoteBubbleCardInstantiation() {
        let note = Note(
            content: "Test content",
            noteType: "text",
            chronologyNumber: 1,
            title: "Test note"
        )

        let view = NoteBubbleCard(note: note, isSelected: false)
        XCTAssertNotNil(view)
    }

    func testSoundNoteBubbleCardInstantiation() {
        let soundNote = SoundNote(
            description: "Test sound",
            soundType: "music",
            chronologyNumber: 1,
            volume: 80,
            loop: false
        )

        let view = SoundNoteBubbleCard(soundNote: soundNote, isSelected: false)
        XCTAssertNotNil(view)
    }

    func testCharacterAvatarViewInstantiation() {
        let view = CharacterAvatarView(
            character: nil,
            characterName: "John Doe",
            size: 40
        )
        XCTAssertNotNil(view)
    }

    func testTagPillViewInstantiation() {
        let view = TagPillView(text: "test")
        XCTAssertNotNil(view)
    }

    func testTagsStackViewInstantiation() {
        let view = TagsStackView(tags: ["tag1", "tag2", "tag3"])
        XCTAssertNotNil(view)
    }

    func testTraitsRadarChartInstantiation() {
        let traits = ["Creativity": 75.0, "Empathy": 80.0]
        let view = TraitsRadarChart(traits: traits)
        XCTAssertNotNil(view)
    }
}
