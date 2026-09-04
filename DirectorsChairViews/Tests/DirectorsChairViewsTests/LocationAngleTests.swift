// LocationAngleTests.swift
//
// DC-0125: a location's named camera angles — mentioned as
// "#Place / Angle", chosen by a shot, and standing in for the location's
// picture in the shot's reference bundle and prompt.

import XCTest
import AppKit
import DirectorsChairCore
import DirectorsChairServices
@testable import DirectorsChairViews

final class LocationAngleTests: XCTestCase {

    private var projectDir: URL!

    override func setUpWithError() throws {
        projectDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("angle-refs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: projectDir.appendingPathComponent("assets/locations/pier_9/angles/a-wide"),
            withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: projectDir)
    }

    private static func pngBytes() -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.representation(using: .png, properties: [:])!
    }

    /// Pier 9 with two angles; only the wide one has a kept picture.
    private func pier(withPictures: Bool = true) throws -> Location {
        var pier = Location(name: "Pier 9")
        pier.description = "A working harbour pier."
        let anglePath = "assets/locations/pier_9/angles/a-wide/preview_1.png"
        if withPictures {
            try Self.pngBytes().write(to: projectDir.appendingPathComponent("assets/locations/pier_9/primary.png"))
            pier.primaryImage = "assets/locations/pier_9/primary.png"
            try Self.pngBytes().write(to: projectDir.appendingPathComponent(anglePath))
        }
        pier.angles = [
            LocationAngle(id: "a-wide", name: "Wide from the gate", description: "Cranes behind, water left.",
                          image: withPictures ? anglePath : nil),
            LocationAngle(id: "a-rev", name: "Reverse toward the bar"),
        ]
        return pier
    }

    func testAngleMentionResolvesToTheAngleNotTheBareLocation() throws {
        let pier = try pier()
        let mentions = MentionParser.mentions(in: "Dawn at #Pier 9 / Wide from the gate, gulls.",
                                              characters: [], locations: [pier], props: [], shots: [])
        XCTAssertEqual(mentions.map(\.kind), [.angle])
        XCTAssertEqual(mentions.first?.id, "a-wide")
        XCTAssertEqual(mentions.first?.name, "Pier 9 / Wide from the gate")
        XCTAssertEqual(mentions.first?.imagePath, "assets/locations/pier_9/angles/a-wide/preview_1.png")
        let bare = MentionParser.mentions(in: "Dawn at #Pier 9.", characters: [], locations: [pier],
                                          props: [], shots: [])
        XCTAssertEqual(bare.map(\.kind), [.location], "the bare place still resolves as before")
    }

    func testShotResolvesItsAngleThroughTheScenesLocation() throws {
        let pier = try pier()
        var scene = DirectorsChairCore.Scene(name: "Arrival")
        scene.location = "pier 9"
        var shot = Shot(shotId: 1, description: "The boat comes in")
        shot.locationAngleId = "a-wide"
        XCTAssertEqual(LocationAngles.resolve(shot: shot, scene: scene, locations: [pier])?.angle.name,
                       "Wide from the gate", "the scene names its location; the match is case-blind")
        XCTAssertEqual(LocationAngles.reference(for: shot, scene: scene, locations: [pier])?.label,
                       "angle:Pier 9 / Wide from the gate")
        shot.locationAngleId = "a-rev"
        XCTAssertNil(LocationAngles.reference(for: shot, scene: scene, locations: [pier]),
                     "an angle without a kept picture contributes no reference")
        shot.locationAngleId = "gone"
        XCTAssertNil(LocationAngles.resolve(shot: shot, scene: scene, locations: [pier]))
        XCTAssertEqual(LocationAngles.promptClause(for: shot, location: pier), "")
    }

    func testChosenAnglePictureStandsInForTheLocationPicture() throws {
        let pier = try pier()
        var scene = DirectorsChairCore.Scene(name: "Arrival")
        scene.location = "Pier 9"
        var shot = Shot(shotId: 1, description: "The boat comes in")
        let plain = CharacterReferenceHelper.collectReferenceImages(
            forShot: shot, in: scene, characters: [], locations: [pier], projectDirectory: projectDir)
        XCTAssertEqual(plain.map(\.label), ["location:Pier 9"])
        shot.locationAngleId = "a-wide"
        let angled = CharacterReferenceHelper.collectReferenceImages(
            forShot: shot, in: scene, characters: [], locations: [pier], projectDirectory: projectDir)
        XCTAssertEqual(angled.map(\.label), ["angle:Pier 9 / Wide from the gate"],
                       "the angle takes the location's slot — never both")
        XCTAssertFalse(angled[0].base64.isEmpty)
        let prefix = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: angled)
        XCTAssertTrue(prefix.contains("Image 1 is the LOCATION seen from its camera angle \"Pier 9 / Wide from the gate\""), prefix)
        XCTAssertTrue(prefix.contains("same vantage"))
    }

    func testPromptsNameTheChosenAngleNextToTheLocation() throws {
        let pier = try pier(withPictures: false)
        var scene = DCScene(name: "Arrival")
        scene.location = "Pier 9"
        var shot = Shot(shotId: 1, description: "The boat comes in")
        shot.locationAngleId = "a-wide"
        let preview = ShotPromptBuilder.previewPrompt(shot: shot, scene: scene, locations: [pier], characters: [])
        XCTAssertTrue(preview.contains("Location: Pier 9"), preview)
        XCTAssertTrue(preview.contains("Framed from the location's angle \"Wide from the gate\": Cranes behind, water left."), preview)
        let video = ShotPromptBuilder.videoPrompt(shot: shot, scene: scene, characters: [], locations: [pier],
                                                  cameraMotion: "Static", duration: 4)
        XCTAssertTrue(video.contains("Framed from the location's angle \"Wide from the gate\""), video)
        shot.locationAngleId = nil
        XCTAssertFalse(ShotPromptBuilder.previewPrompt(shot: shot, scene: scene, locations: [pier], characters: [])
                        .contains("Framed from"))
    }

    func testNamingAnAngleInTheDescriptionPicksItForTheShot() throws {
        let pier = try pier(withPictures: false)
        let shot = Shot(shotId: 1, description: "The boat comes in, #Pier 9 / Wide from the gate")
        let synced = MentionSync.apply(description: shot.description, shot: shot, scene: DCScene(name: "Arrival"),
                                       characters: [], locations: [pier], props: [])
        XCTAssertEqual(synced.shot.locationAngleId, "a-wide")
        XCTAssertTrue(synced.shotChanged)
        XCTAssertEqual(synced.scene?.location, "Pier 9", "a scene without a place takes the angle's")
        XCTAssertTrue(synced.sceneChanged)
        let again = MentionSync.apply(description: shot.description, shot: synced.shot, scene: synced.scene,
                                      characters: [], locations: [pier], props: [])
        XCTAssertFalse(again.shotChanged, "already picked — nothing to change")
    }
}
