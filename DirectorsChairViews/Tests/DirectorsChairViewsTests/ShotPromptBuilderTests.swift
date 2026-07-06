// ShotPromptBuilderTests.swift
//
// WS6.2: shot-preview prompt construction is pure and unit-tested (it was
// an untested private view method).

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class ShotPromptBuilderTests: XCTestCase {

    private func makeShot(lens: Int? = 85, aperture: String = "f/1.8") -> Shot {
        var shot = Shot(shotId: 1, description: "Hero walks in")
        shot.shotType = "Close-up"
        shot.cameraAngle = "Low"
        shot.lensMm = lens
        shot.aperture = aperture
        shot.movement = "Dolly"
        return shot
    }

    func testPreviewPromptReflectsCameraSettings() {
        let prompt = ShotPromptBuilder.previewPrompt(shot: makeShot(), scene: nil, locations: [], characters: [])
        XCTAssertTrue(prompt.contains("Close-up shot"))
        XCTAssertTrue(prompt.contains("Low angle"))
        XCTAssertTrue(prompt.contains("telephoto lens"), "85mm maps to telephoto language")
        XCTAssertTrue(prompt.contains("shallow depth of field"), "f/1.8 maps to shallow DOF")
        XCTAssertTrue(prompt.contains("sense of dolly movement"))
        XCTAssertTrue(prompt.contains("Hero walks in"))
        XCTAssertTrue(prompt.contains("photorealistic"))
    }

    func testWideLensAndDeepFocusLanguage() {
        let prompt = ShotPromptBuilder.previewPrompt(shot: makeShot(lens: 18, aperture: "f/11"),
                                                     scene: nil, locations: [], characters: [])
        XCTAssertTrue(prompt.contains("wide angle lens"))
        XCTAssertTrue(prompt.contains("deep focus"))
    }

    func testSceneContextIncludesLocationAndCharacters() {
        var scene = DCScene(name: "S1")
        scene.location = "Warehouse"
        scene.description = "Dust hangs in the light."
        scene.dialogues = [Dialogue(character: "Alex", text: "We're too late.", chronologyNumber: 1)]

        var location = Location(name: "Warehouse")
        location.locationType = "indoor"
        location.description = "Abandoned dockside warehouse"

        var alex = Character(name: "Alex")
        alex.about = "Weathered detective in his fifties"

        let prompt = ShotPromptBuilder.previewPrompt(shot: makeShot(), scene: scene,
                                                     locations: [location], characters: [alex])
        XCTAssertTrue(prompt.contains("Location: Warehouse (indoor)"))
        XCTAssertTrue(prompt.contains("Abandoned dockside warehouse"))
        XCTAssertTrue(prompt.contains("Alex (Weathered detective"), "character described from about field")
        XCTAssertTrue(prompt.contains("We're too late."), "first dialogue sets mood")
    }

    func testUnknownLocationFallsBack() {
        var scene = DCScene(name: "S1")
        scene.location = "Moon Base"
        let prompt = ShotPromptBuilder.previewPrompt(shot: makeShot(), scene: scene,
                                                     locations: [], characters: [])
        XCTAssertTrue(prompt.contains("set in Moon Base"))
    }

    func testCharacterDescriptionFromAttributes() {
        var c = Character(name: "Sam")
        c.age = 30
        c.gender = "female"
        c.hairColor = "red"
        let desc = ShotPromptBuilder.characterDescription(c)
        XCTAssertTrue(desc.contains("30 year old"))
        XCTAssertTrue(desc.contains("female"))
        XCTAssertTrue(desc.contains("red hair"))
    }

    func testPromptSummary() {
        let summary = ShotPromptBuilder.promptSummary(shot: makeShot(), scene: DCScene(name: "S1"))
        XCTAssertEqual(summary, "Close-up • Low • S1")
    }
    // MARK: - StoryDesignPromptBuilder (WS6.2)

    func testStyleDirectiveMapping() {
        XCTAssertTrue(StoryDesignPromptBuilder.styleDirective(for: "Anime").contains("cel-shaded"))
        XCTAssertTrue(StoryDesignPromptBuilder.styleDirective(for: "3D Render").contains("CGI"))
        XCTAssertEqual(StoryDesignPromptBuilder.styleDirective(for: "unknown"), "photorealistic")
    }

    func testCostumePromptIncludesGarmentsAndPalette() {
        var c = Character(name: "Alex")
        c.imageStyle = "Cinematic"
        c.gender = "male"
        c.age = 40
        var costume = CharacterCostume(name: "Detective Coat")
        costume.garmentTop = "grey shirt"
        costume.outerwear = "long trench coat"
        costume.colorPalette = ["charcoal", "rust"]
        costume.primaryFabric = "wool"

        let prompt = StoryDesignPromptBuilder.costumePrompt(character: c, costume: costume)
        XCTAssertTrue(prompt.contains("cinematic still frame"))
        XCTAssertTrue(prompt.contains("male character"))
        XCTAssertTrue(prompt.contains("age 40"))
        XCTAssertTrue(prompt.contains("wearing Detective Coat"))
        XCTAssertTrue(prompt.contains("top: grey shirt"))
        XCTAssertTrue(prompt.contains("outerwear: long trench coat"))
        XCTAssertTrue(prompt.contains("color palette: charcoal, rust"))
        XCTAssertTrue(prompt.contains("wool fabric"))
    }

    func testAppearancePromptCoversPhysicalAttributes() {
        var c = Character(name: "Maya")
        c.imageStyle = "Watercolor"
        c.gender = "female"
        c.age = 28
        c.skinTone = "olive"
        c.hairColor = "black"
        c.hairLength = "Long"
        c.eyeShape = "Almond"
        c.eyeColorDescription = "dark brown"
        c.role = "Antagonist"

        let prompt = StoryDesignPromptBuilder.characterAppearancePrompt(character: c)
        XCTAssertTrue(prompt.contains("watercolor painting"))
        XCTAssertTrue(prompt.contains("female character"))
        XCTAssertTrue(prompt.contains("age 28"))
        XCTAssertTrue(prompt.contains("olive skin tone"))
        XCTAssertTrue(prompt.contains("black long"), "hair color+length present")
        XCTAssertTrue(prompt.contains("hair"))
        XCTAssertTrue(prompt.contains("dark brown almond eyes"))
        XCTAssertTrue(prompt.contains("antagonist character"))
    }

    func testAnglePromptConsistencyInstruction() {
        let with = StoryDesignPromptBuilder.anglePrompt(base: "base", angle: "profile view", hasBaseImage: true)
        XCTAssertTrue(with.contains("EXACT SAME person"))
        XCTAssertTrue(with.contains("profile view"))
        let without = StoryDesignPromptBuilder.anglePrompt(base: "base", angle: "profile view", hasBaseImage: false)
        XCTAssertFalse(without.contains("EXACT SAME person"))
        XCTAssertTrue(without.contains("turnaround sheet"))
    }

}
