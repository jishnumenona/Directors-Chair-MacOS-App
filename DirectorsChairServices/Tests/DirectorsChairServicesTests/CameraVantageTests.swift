// CameraVantageTests.swift
//
// DC-0129: a camera placed on a location picture and aimed — the marked copy
// the describe step sees, the words it writes, and the words-only render
// (the contract the 2026-09-05 probes settled on).

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import DirectorsChairCore
@testable import DirectorsChairServices

final class CameraVantageTests: XCTestCase {

    /// A flat grey PNG of the given size.
    private func png(width: Int, height: Int) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = context.makeImage()!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    /// (r, g, b) of the pixel at a fraction of the picture, top-left origin.
    private func pixel(_ data: Data, x: Double, y: Double) -> (r: UInt8, g: UInt8, b: UInt8) {
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let px = Int(Double(image.width) * x), py = Int(Double(image.height) * y)
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        let offset = py * image.width * 4 + px * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2])
    }

    func testMarkedCopyDrawsTheCameraTheTargetAndTheArrow() throws {
        let base = png(width: 640, height: 360)
        let camera = CameraPlacement(basePicture: "assets/locations/pier/primary.png",
                                     x: 0.2, y: 0.8, targetX: 0.8, targetY: 0.3)
        let marked = try XCTUnwrap(CameraMarkup.marked(source: base, camera: camera))
        let source = CGImageSourceCreateWithData(marked as CFData, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        XCTAssertEqual(image.width, 640); XCTAssertEqual(image.height, 360, "the picture keeps its size")
        let atCamera = pixel(marked, x: 0.2, y: 0.8)
        XCTAssertGreaterThan(atCamera.r, 200); XCTAssertLessThan(atCamera.g, 90, "C is a red disc")
        let onArrow = pixel(marked, x: 0.5, y: 0.55)
        XCTAssertGreaterThan(onArrow.r, 200); XCTAssertLessThan(onArrow.g, 90, "the arrow runs from C to T")
        let grey = Int(pixel(base, x: 0.9, y: 0.9).r)
        XCTAssertEqual(Int(pixel(marked, x: 0.9, y: 0.9).r), grey, accuracy: 3, "the rest of the picture is unchanged")
        XCTAssertEqual(Int(pixel(marked, x: 0.8, y: 0.3).r), grey, accuracy: 3, "T is a ring — the spot it marks stays visible")
    }

    func testMarkedCopyRejectsWhatIsNotAPicture() {
        XCTAssertNil(CameraMarkup.marked(source: Data("nope".utf8),
                                         camera: CameraPlacement(basePicture: "x", x: 0.5, y: 0.5, targetX: 0.5, targetY: 0.5)))
        XCTAssertNil(CameraMarkup.pngCopy(of: Data("nope".utf8)))
        XCTAssertNotNil(CameraMarkup.pngCopy(of: png(width: 8, height: 8)))
    }

    private let vanWords = "The camera is inside a beige minivan, brightly lit by the afternoon sun. The centre of the frame is filled by the beige passenger seat headrest, with the dashboard and windshield beyond it. On the left edge is the driver's headrest and steering wheel; the right edge shows the passenger window and distant red rocks. The back seats, the child seat and the straw hat are now behind the camera."

    func testDescribeAnswerBecomesOneParagraphOrNothing() {
        let words = CameraVantageWords.parse("**The camera** is inside a beige minivan.\n\nThe centre of the frame is filled by the passenger headrest; the back seats are behind the camera and out of frame.")
        XCTAssertEqual(words?.text, "The camera is inside a beige minivan. The centre of the frame is filled by the passenger headrest; the back seats are behind the camera and out of frame.")
        XCTAssertNil(CameraVantageWords.parse("C: floor\nT: cooler"), "three terse lines cannot carry a composition")
        XCTAssertNil(CameraVantageWords.parse("   "))
    }

    func testDescribePromptAsksForTheViewNotTheMarkers() {
        let photo = SketchStudioComposer.vantageDescribePrompt(for: CameraPlacement(basePicture: "p", x: 0.1, y: 0.9, targetX: 0.7, targetY: 0.4), placeKind: "store")
        XCTAssertTrue(photo.contains("This photograph shows a store"), photo)
        XCTAssertTrue(photo.contains("WITHOUT seeing this photograph"), photo)
        XCTAssertTrue(photo.contains("what is now behind the camera"), photo)
        XCTAssertTrue(photo.contains("no mention of C, T, markers"), photo)
        let plan = SketchStudioComposer.vantageDescribePrompt(for: CameraPlacement(basePicture: "p", isFloorPlan: true, x: 0.1, y: 0.9, targetX: 0.7, targetY: 0.4))
        XCTAssertTrue(plan.contains("This floor plan (drawn from above) shows a place"), plan)
        XCTAssertEqual(SketchStudioComposer.vantageDescribeMaxTokens, 1024)
    }

    private func input(floorPlan: Bool, words: CameraVantageWords?, references: [SketchElement] = []) -> CameraVantageInput {
        CameraVantageInput(
            locationName: "Pier 9", locationDescription: "A working harbour pier.",
            angleName: "Wide from the gate", angleDescription: "Cranes behind, #Pier 9 water left.",
            camera: CameraPlacement(basePicture: "p.png", isFloorPlan: floorPlan, x: 0.1, y: 0.9, targetX: 0.7, targetY: 0.4),
            markedPNG: Data([2]), words: words, references: references)
    }

    func testWordsOnlyRenderAttachesNoPicture() {
        let refs = [SketchElement(kind: "angle", name: "Pier 9 / Reverse toward the bar", imageData: Data([4]))]
        let input = input(floorPlan: false, words: CameraVantageWords(text: vanWords), references: refs)
        let prompt = SketchStudioComposer.vantagePrompt(for: input)
        let lines = prompt.components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "Photograph the following view of Pier 9 exactly as described. Nothing else is known about the place.")
        XCTAssertEqual(lines[1], vanWords)
        XCTAssertTrue(prompt.contains("About the place: A working harbour pier."), prompt)
        XCTAssertTrue(prompt.contains("The director's note for this angle: Cranes behind, Pier 9 water left."), "mention sigils stripped")
        XCTAssertTrue(prompt.contains("what is described as behind the camera does not appear at all"), prompt)
        XCTAssertFalse(prompt.contains("Image 1"), "no picture is referenced")
        XCTAssertFalse(prompt.contains("markers"), "no marker talk in a words-only render")
        XCTAssertTrue(SketchStudioComposer.vantageReferenceImages(for: input).isEmpty,
                      "any picture of the place anchors the framing — probe 2026-09-05")
        let request = SketchStudioComposer.vantageRequest(for: input)
        XCTAssertNil(request.referenceImages)
        XCTAssertFalse(request.isEdit)
        XCTAssertEqual(request.brief?.purpose, .location)
    }

    func testFallbackRenderUsesTheMarkedCopyAndGeometryWords() {
        let refs = [SketchElement(kind: "location", name: "Pier 9 — night", imageData: Data([3]))]
        let input = input(floorPlan: false, words: nil, references: refs)
        let prompt = SketchStudioComposer.vantagePrompt(for: input)
        XCTAssertTrue(prompt.hasPrefix("A new photograph of Pier 9, taken from the spot marked C — the left side of the picture, close to where the picture was taken, facing the spot marked T — the right side of the picture, the middle distance."), prompt)
        XCTAssertTrue(prompt.contains("must be a DIFFERENT photograph"), prompt)
        XCTAssertTrue(prompt.contains("Image 2 is another picture of the same place (Pier 9 — night)"), prompt)
        XCTAssertTrue(prompt.components(separatedBy: "\n").last!.contains("annotations only"), "the ink ban goes last")
        XCTAssertEqual(SketchStudioComposer.vantageReferenceImages(for: input).map(\.label),
                       ["camera:marked copy", "location:Pier 9 — night"])
        let plan = SketchStudioComposer.vantagePrompt(for: self.input(floorPlan: true, words: nil))
        XCTAssertTrue(plan.contains("Image 1 is the FLOOR PLAN of the place"), plan)
        XCTAssertTrue(SketchStudioComposer.geometryWords(CameraPlacement(basePicture: "p", isFloorPlan: true, x: 0.1, y: 0.1, targetX: 0.9, targetY: 0.9)).at.contains("the top of the plan"))
    }
}
