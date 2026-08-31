// PropReferenceTests.swift
//
// DC-0079: the props a scene lists or a shot names ride along as
// "prop:<name>" reference pictures — after the place and the people,
// capped, and only when the Prop Shop has a picture.

import XCTest
import AppKit
import DirectorsChairCore
import DirectorsChairServices
@testable import DirectorsChairViews

final class PropReferenceTests: XCTestCase {

    private var projectDir: URL!

    override func setUpWithError() throws {
        projectDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("prop-refs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectDir.appendingPathComponent("assets/props"),
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

    /// A prop with (or without) a picture on disk.
    private func prop(_ name: String, pictured: Bool = true) throws -> Prop {
        guard pictured else { return Prop(name: name) }
        let path = "assets/props/\(name.lowercased().replacingOccurrences(of: " ", with: "_")).png"
        try Self.pngBytes().write(to: projectDir.appendingPathComponent(path))
        return Prop(name: name, thumbnail: path)
    }

    func testSceneBundleCarriesTheScenesListedProps() throws {
        let scene = DirectorsChairCore.Scene(name: "Cottage wall", props: ["Storm Lantern"])
        let props = [try prop("Storm Lantern"), try prop("Logbook")]
        let refs = CharacterReferenceHelper.collectReferenceImages(
            forScene: scene, characters: [], locations: [], props: props, projectDirectory: projectDir)
        XCTAssertEqual(refs.map(\.label), ["prop:Storm Lantern"], "only the props the scene lists")
        XCTAssertFalse(refs[0].base64.isEmpty)
    }

    // Owner 2026-08-29: the props chosen for the scene (Prop Shop picker on the
    // shot page) ride along with every shot of it, then any prop the shot names.
    func testShotBundleCarriesTheScenesChosenPropsThenThePropsTheShotNames() throws {
        let scene = DirectorsChairCore.Scene(name: "Cottage wall", props: ["Storm Lantern"])
        let props = [try prop("Storm Lantern"), try prop("Logbook"), try prop("Compass")]
        let compass = Shot(shotId: 1, description: "Teo checks the compass")
        let wall = Shot(shotId: 2, description: "Teo at the cottage wall")
        XCTAssertEqual(CharacterReferenceHelper.collectReferenceImages(
            forShot: compass, in: scene, characters: [], locations: [], props: props,
            projectDirectory: projectDir).map(\.label), ["prop:Storm Lantern", "prop:Compass"])
        XCTAssertEqual(CharacterReferenceHelper.collectReferenceImages(
            forShot: wall, in: scene, characters: [], locations: [], props: props,
            projectDirectory: projectDir).map(\.label), ["prop:Storm Lantern"],
            "a shot that names no prop still carries the scene's chosen props")
    }

    func testPropPicturesAreCappedAndOnlyPicturedPropsTakeASlot() throws {
        let names = ["Chart", "Rangefinder", "Logbook", "Kettle"]
        let scene = DirectorsChairCore.Scene(name: "Lamp room", props: names)
        let props = [try prop("Chart", pictured: false), try prop("Rangefinder"),
                     try prop("Logbook"), try prop("Kettle")]
        let refs = CharacterReferenceHelper.collectReferenceImages(
            forScene: scene, characters: [], locations: [], props: props, projectDirectory: projectDir)
        XCTAssertEqual(refs.map(\.label), ["prop:Rangefinder", "prop:Logbook"])
        XCTAssertEqual(CharacterReferenceHelper.maxPropReferences, 2)
    }

    func testAPropWithoutAThumbnailFallsBackToItsReferencePhoto() throws {
        var kettle = Prop(name: "Kettle")
        try Self.pngBytes().write(to: projectDir.appendingPathComponent("assets/props/kettle-photo.png"))
        kettle.referencePhotos = ["assets/props/kettle-photo.png"]
        let scene = DirectorsChairCore.Scene(name: "Kitchen", props: ["Kettle"])
        let refs = CharacterReferenceHelper.collectReferenceImages(
            forScene: scene, characters: [], locations: [], props: [kettle], projectDirectory: projectDir)
        XCTAssertEqual(refs.map(\.label), ["prop:Kettle"])
    }

    func testBundlesWithoutPropsAreUnchanged() throws {
        let scene = DirectorsChairCore.Scene(name: "Cottage wall", props: ["Storm Lantern"])
        let refs = CharacterReferenceHelper.collectReferenceImages(
            forScene: scene, characters: [], locations: [], projectDirectory: projectDir)
        XCTAssertTrue(refs.isEmpty, "callers that pass no props see exactly the old bundle")
    }

    func testPromptPrefixDescribesAProp() {
        let ref = ReferenceImage(base64: "abc", mimeType: "image/png", label: "prop:Storm Lantern")
        let prefix = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: [ref])
        XCTAssertTrue(prefix.contains("Image 1 is the prop \"Storm Lantern\""), prefix)
    }

    // DC-0096: "Where it's used" — placed scenes' shots plus shots that name the prop.
    func testShotsUsingPropCoverPlacedScenesAndMentions() {
        var placed = Scene(name: "Van"); placed.props = ["Mini van"]
        placed.shots = [Shot(shotId: 1, description: "Driving"), Shot(shotId: 2, description: "Reverse")]
        var other = Scene(name: "Diner")
        other.shots = [Shot(shotId: 3, description: "The $Mini van waits outside"), Shot(shotId: 4, description: "Coffee")]
        let rows = PropShopView.shotsUsing("Mini van", in: [placed, other])
        XCTAssertEqual(rows.map(\.shot.shotId), [1, 2, 3])
        XCTAssertEqual(rows.map(\.scene.name), ["Van", "Van", "Diner"])
    }
}
