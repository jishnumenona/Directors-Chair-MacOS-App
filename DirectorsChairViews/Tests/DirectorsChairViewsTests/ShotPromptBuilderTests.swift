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

    // MARK: - videoPrompt (every shot-view attribute must be stated)

    /// A scene exercising every context source the video prompt draws from.
    private func makeVideoScene() -> (DCScene, [Character], [Location]) {
        var scene = DCScene(name: "S1")
        scene.location = "Warehouse"
        scene.description = "Dust hangs in the light of a single sodium lamp."
        scene.props = ["crowbar", "shipping crate"]
        scene.dialogues = [Dialogue(uuid: "dlg-1", character: "Alex", text: "We're too late.", chronologyNumber: 1)]
        scene.actions = [Action(uuid: "act-1", description: "Maya forces the door", characters: ["Maya"])]
        scene.soundNotes = [SoundNote(uuid: "snd-1", description: "distant harbor horn", chronologyNumber: 2)]

        var location = Location(name: "Warehouse")
        location.locationType = "indoor"
        location.description = "Abandoned dockside warehouse"

        var alex = Character(name: "Alex")
        alex.about = "Weathered detective in his fifties"
        alex.costumes = [CharacterCostume(name: "Detective Coat")]

        var maya = Character(name: "Maya")
        maya.age = 28
        maya.gender = "female"
        maya.hairColor = "black"

        return (scene, [alex, maya], [location])
    }

    func testVideoPromptStatesEveryCameraAttribute() {
        let (scene, characters, locations) = makeVideoScene()
        let prompt = ShotPromptBuilder.videoPrompt(shot: makeShot(), scene: scene,
                                                   characters: characters, locations: locations,
                                                   cameraMotion: "Dolly", duration: 6.0)
        XCTAssertTrue(prompt.contains("Close-up shot"), "shotType missing")
        XCTAssertTrue(prompt.contains("Low angle"), "cameraAngle missing")
        XCTAssertTrue(prompt.contains("85mm lens"), "lensMm missing")
        XCTAssertTrue(prompt.contains("f/1.8"), "aperture missing")
        XCTAssertTrue(prompt.contains("Hero walks in"), "shot description missing")
        XCTAssertTrue(prompt.contains("Camera motion: Dolly"), "camera motion missing")
        XCTAssertTrue(prompt.contains("Duration: 6.0s"), "duration missing")
    }

    func testVideoPromptIncludesApertureEvenWithoutLens() {
        let prompt = ShotPromptBuilder.videoPrompt(shot: makeShot(lens: nil, aperture: "f/8"),
                                                   scene: nil, characters: [], locations: [],
                                                   cameraMotion: "Static", duration: 5.0)
        XCTAssertTrue(prompt.contains("f/8 aperture"))
    }

    func testVideoPromptStatesFullSceneContext() {
        let (scene, characters, locations) = makeVideoScene()
        var shot = makeShot()
        shot.linkedDialogueIds = ["dlg-1"]
        shot.linkedActionIds = ["act-1"]
        let prompt = ShotPromptBuilder.videoPrompt(shot: shot, scene: scene,
                                                   characters: characters, locations: locations,
                                                   cameraMotion: "Static", duration: 5.0)
        XCTAssertTrue(prompt.contains("Location: Warehouse (indoor)"), "location record missing")
        XCTAssertTrue(prompt.contains("Abandoned dockside warehouse"), "location description missing")
        XCTAssertTrue(prompt.contains("Scene: Dust hangs in the light"), "scene description missing")
        XCTAssertTrue(prompt.contains("Props: crowbar, shipping crate"), "props missing")
        XCTAssertTrue(prompt.contains("Alex (Weathered detective"), "character appearance missing")
        XCTAssertTrue(prompt.contains("Maya"), "action-only character missing")
        XCTAssertTrue(prompt.contains("black hair"), "character physical attributes missing")
        XCTAssertTrue(prompt.contains("Costumes: Alex wears Detective Coat"), "costumes missing")
        XCTAssertTrue(prompt.contains("Alex: \"We're too late.\""), "linked dialogue missing")
        XCTAssertTrue(prompt.contains("Action: Maya forces the door"), "linked action missing")
        XCTAssertTrue(prompt.contains("Sound atmosphere: distant harbor horn"), "sound notes missing")
    }

    func testVideoPromptOmitsDurationWhenInterpolating() {
        // Start→end interpolation ignores duration; stating one would conflict
        // with what the provider actually renders.
        let prompt = ShotPromptBuilder.videoPrompt(shot: makeShot(), scene: nil,
                                                   characters: [], locations: [],
                                                   cameraMotion: "Static", duration: nil)
        XCTAssertFalse(prompt.contains("Duration:"))
        XCTAssertTrue(prompt.contains("Camera motion: Static."))
    }

    func testCharacterNamesUnionsDialoguesAndActions() {
        let (scene, _, _) = makeVideoScene()
        XCTAssertEqual(ShotPromptBuilder.characterNames(in: scene), ["Alex", "Maya"])
    }

    // MARK: - Film style resolution & clause

    func testResolveFilmStylePrecedence() {
        let projectStyle = FilmStyle(id: "proj-1", name: "House Look")
        var shot = makeShot()
        var scene = DCScene(name: "S1")

        // Shot override wins
        shot.styleOverride = "proj-1"
        scene.styleOverride = "preset-film-noir"
        XCTAssertEqual(ShotPromptBuilder.resolveFilmStyle(shot: shot, scene: scene,
                                                          projectStyles: [projectStyle],
                                                          defaultStyleId: "preset-anime")?.id, "proj-1")
        // Scene override next
        shot.styleOverride = nil
        XCTAssertEqual(ShotPromptBuilder.resolveFilmStyle(shot: shot, scene: scene,
                                                          projectStyles: [projectStyle],
                                                          defaultStyleId: "preset-anime")?.id, "preset-film-noir")
        // Project default last
        scene.styleOverride = nil
        XCTAssertEqual(ShotPromptBuilder.resolveFilmStyle(shot: shot, scene: scene,
                                                          projectStyles: [projectStyle],
                                                          defaultStyleId: "preset-anime")?.id, "preset-anime")
        // Nothing set → nil
        XCTAssertNil(ShotPromptBuilder.resolveFilmStyle(shot: shot, scene: scene,
                                                        projectStyles: [projectStyle],
                                                        defaultStyleId: nil))
        // Dangling id falls through to the next candidate
        shot.styleOverride = "missing-style"
        XCTAssertEqual(ShotPromptBuilder.resolveFilmStyle(shot: shot, scene: scene,
                                                          projectStyles: [projectStyle],
                                                          defaultStyleId: "preset-anime")?.id, "preset-anime")
    }

    func testStyleClausePrefersHandWrittenPrompt() {
        let style = FilmStyle(name: "Noir", colorGrading: "warm", filmGrain: true,
                              aiStylePrompt: "hard single-source noir lighting")
        let clause = ShotPromptBuilder.styleClause(for: style)
        XCTAssertTrue(clause.contains("hard single-source noir lighting"))
        XCTAssertFalse(clause.contains("warm color grading"), "structured fields yield to aiStylePrompt")
    }

    func testStyleClauseDerivesFromStructuredFields() {
        let style = FilmStyle(name: "Custom", colorPalette: ["#112233"],
                              colorGrading: "vintage", contrastLevel: "dramatic",
                              filmGrain: true, vignette: true)
        let clause = ShotPromptBuilder.styleClause(for: style)
        XCTAssertTrue(clause.contains("vintage color grading"))
        XCTAssertTrue(clause.contains("dramatic contrast"))
        XCTAssertTrue(clause.contains("film grain"))
        XCTAssertTrue(clause.contains("subtle vignette"))
        XCTAssertTrue(clause.contains("#112233"))
    }

    func testVideoPromptUsesFilmStyleInsteadOfHardcodedTail() {
        let style = FilmStyle.presets.first { $0.id == "preset-film-noir" }!
        let prompt = ShotPromptBuilder.videoPrompt(shot: makeShot(), scene: nil,
                                                   characters: [], locations: [],
                                                   cameraMotion: "Static", duration: 5.0,
                                                   filmStyle: style)
        XCTAssertTrue(prompt.contains("film noir"))
        XCTAssertFalse(prompt.contains("Dramatic lighting, cinematic quality, professional filmmaking."),
                       "hardcoded tail must yield to the film style")
    }

    // MARK: - Atmosphere & lighting

    func testVideoPromptIncludesSceneAtmosphereAndLighting() {
        var scene = DCScene(name: "S1")
        scene.timeOfDay = "Golden Hour"
        scene.weather = "Rain"
        let prompt = ShotPromptBuilder.videoPrompt(shot: makeShot(), scene: scene,
                                                   characters: [], locations: [],
                                                   cameraMotion: "Static", duration: 5.0,
                                                   lightingStyle: "Low-key")
        XCTAssertTrue(prompt.contains("golden hour light"))
        XCTAssertTrue(prompt.contains("rain"))
        XCTAssertTrue(prompt.contains("low-key lighting"))
    }

    func testAtmosphereClauseNilWhenNothingSet() {
        XCTAssertNil(ShotPromptBuilder.atmosphereClause(scene: DCScene(name: "S1"), lightingStyle: nil))
    }

    // MARK: - Wardrobe continuity

    private func makeCostumedCharacter() -> Character {
        var char = Character(name: "Alex")
        var coat = CharacterCostume(name: "Detective Coat")
        coat.costumeId = "c-coat"
        var gala = CharacterCostume(name: "Gala Suit")
        gala.costumeId = "c-gala"
        char.costumes = [coat, gala]
        return char
    }

    func testAssignedCostumeHonorsSceneAssignment() {
        let char = makeCostumedCharacter()
        var scene = DCScene(name: "S1")
        scene.costumeAssignments = ["Alex": "c-gala"]
        XCTAssertEqual(ShotPromptBuilder.assignedCostume(for: char, in: scene)?.name, "Gala Suit")
    }

    func testAssignedCostumeFallsBackToActiveThenFirst() {
        var char = makeCostumedCharacter()
        let scene = DCScene(name: "S1")  // no assignments
        char.activeCostumeIndex = 1
        XCTAssertEqual(ShotPromptBuilder.assignedCostume(for: char, in: scene)?.name, "Gala Suit")
        char.activeCostumeIndex = nil
        XCTAssertEqual(ShotPromptBuilder.assignedCostume(for: char, in: scene)?.name, "Detective Coat")
    }

    func testVideoPromptCostumeLineFollowsAssignment() {
        let char = makeCostumedCharacter()
        var scene = DCScene(name: "S1")
        scene.dialogues = [Dialogue(character: "Alex", text: "Hello.", chronologyNumber: 1)]
        scene.costumeAssignments = ["Alex": "c-gala"]
        let prompt = ShotPromptBuilder.videoPrompt(shot: makeShot(), scene: scene,
                                                   characters: [char], locations: [],
                                                   cameraMotion: "Static", duration: 5.0)
        XCTAssertTrue(prompt.contains("Alex wears Gala Suit"))
        XCTAssertFalse(prompt.contains("Detective Coat"), "only the scene's assigned costume is stated")
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
