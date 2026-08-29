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

    func testShotBundleCarriesOnlyThePropsTheShotNames() throws {
        let scene = DirectorsChairCore.Scene(name: "Cottage wall", props: ["Storm Lantern", "Logbook"])
        let props = [try prop("Storm Lantern"), try prop("Logbook")]
        let lantern = Shot(shotId: 1, description: "Teo lifts the brass storm lantern")
        let wall = Shot(shotId: 2, description: "Teo at the cottage wall")
        XCTAssertEqual(CharacterReferenceHelper.collectReferenceImages(
            forShot: lantern, in: scene, characters: [], locations: [], props: props,
            projectDirectory: projectDir).map(\.label), ["prop:Storm Lantern"])
        XCTAssertEqual(CharacterReferenceHelper.collectReferenceImages(
            forShot: wall, in: scene, characters: [], locations: [], props: props,
            projectDirectory: projectDir).map(\.label), [], "a shot that names no prop gets no prop picture")
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
}
