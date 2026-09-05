// CameraVantageTests.swift
//
// DC-0129: a camera placed on a location picture and aimed — the marked copy
// the model sees, the describe question, and the render words built from
// its answer (the two-step contract the 2026-09-05 probes settled on).

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

    func testDescribeAnswerParsesAndToleratesNoise() {
        let words = CameraMarkerWords.parse("C: the tiled floor beside the entrance\nT: the beverage cooler on the far wall\nBEHIND: the glass doors and a display rack")
        XCTAssertEqual(words, CameraMarkerWords(atCamera: "the tiled floor beside the entrance",
                                                atTarget: "the beverage cooler on the far wall",
                                                behindCamera: "the glass doors and a display rack"))
        XCTAssertEqual(CameraMarkerWords.parse("Sure!\n**C:** the counter.\nt: the window \n")?.atTarget, "the window",
                       "case, markdown and stray punctuation are tolerated")
        XCTAssertEqual(CameraMarkerWords.parse("C: the counter")?.atCamera, nil, "no T → no words (the caller falls back)")
        XCTAssertNil(CameraMarkerWords.parse("camera's standing position"))
    }

    func testDescribePromptNamesTheMarkersAndTheSurface() {
        let photo = SketchStudioComposer.vantageDescribePrompt(for: CameraPlacement(basePicture: "p", x: 0.1, y: 0.9, targetX: 0.7, targetY: 0.4))
        XCTAssertTrue(photo.contains("photograph of a store"), photo)
        XCTAssertTrue(photo.contains("BEHIND a camera standing at C facing T"), photo)
        XCTAssertTrue(photo.hasSuffix("BEHIND: <what is behind the camera>"))
        let plan = SketchStudioComposer.vantageDescribePrompt(for: CameraPlacement(basePicture: "p", isFloorPlan: true, x: 0.1, y: 0.9, targetX: 0.7, targetY: 0.4), placeKind: "harbour pier")
        XCTAssertTrue(plan.contains("floor plan of a harbour pier"), plan)
        XCTAssertEqual(SketchStudioComposer.vantageDescribeMaxTokens, 1024)
    }

    private func input(floorPlan: Bool, words: CameraMarkerWords?, references: [SketchElement] = []) -> CameraVantageInput {
        CameraVantageInput(
            locationName: "Pier 9", locationDescription: "A working harbour pier.",
            angleName: "Wide from the gate", angleDescription: "Cranes behind, #Pier 9 water left.",
            camera: CameraPlacement(basePicture: "p.png", isFloorPlan: floorPlan, x: 0.1, y: 0.9, targetX: 0.7, targetY: 0.4),
            markedPNG: Data([2]), words: words, references: references)
    }

    func testRenderPromptLeadsWithTheWordsAndSendsOnlyTheMarkedCopy() {
        let words = CameraMarkerWords(atCamera: "the tiled floor beside the entrance",
                                      atTarget: "the beverage cooler", behindCamera: "the glass doors and a display rack")
        let refs = [SketchElement(kind: "angle", name: "Pier 9 / Reverse toward the bar", imageData: Data([4]))]
        let prompt = SketchStudioComposer.vantagePrompt(for: input(floorPlan: false, words: words, references: refs))
        let lines = prompt.components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "A new photograph of Pier 9, taken from the tiled floor beside the entrance, facing the beverage cooler. The glass doors and a display rack — behind the camera — must not appear.")
        XCTAssertTrue(prompt.contains("Image 1 is the same place seen from a different spot"), prompt)
        XCTAssertTrue(prompt.contains("must be a DIFFERENT photograph"), prompt)
        XCTAssertTrue(prompt.contains("the beverage cooler at the centre of the frame"), prompt)
        XCTAssertTrue(prompt.contains("Image 2 is another picture of the same place (Pier 9 / Reverse toward the bar)"), prompt)
        XCTAssertTrue(prompt.contains("This angle is called \"Wide from the gate\": Cranes behind, Pier 9 water left."),
                      "mention sigils are stripped from the angle's words")
        XCTAssertTrue(lines.last!.contains("annotations only"), "the ink ban goes last")
        XCTAssertFalse(prompt.contains("FLOOR PLAN"))

        let refsOut = SketchStudioComposer.vantageReferenceImages(for: input(floorPlan: false, words: words, references: refs))
        XCTAssertEqual(refsOut.map(\.label), ["camera:marked copy", "angle:Pier 9 / Reverse toward the bar"],
                       "the clean picture is never sent — the model copies it (probe 2026-09-05)")
    }

    func testRenderPromptFallsBackToGeometryWordsWithoutTheDescribeStep() {
        let prompt = SketchStudioComposer.vantagePrompt(for: input(floorPlan: false, words: nil))
        XCTAssertTrue(prompt.hasPrefix("A new photograph of Pier 9, taken from the spot marked C — the left side of the picture, close to where the picture was taken, facing the spot marked T — the right side of the picture, the middle distance."), prompt)
        XCTAssertFalse(prompt.contains("must not appear"), "nothing is known to be behind the camera")
    }

    func testFloorPlanRenderDescribesThePlan() {
        let words = CameraMarkerWords(atCamera: "the loading bay", atTarget: "the harbour master's hut", behindCamera: "the car park")
        let prompt = SketchStudioComposer.vantagePrompt(for: input(floorPlan: true, words: words))
        XCTAssertTrue(prompt.contains("Image 1 is the FLOOR PLAN of the place, drawn from above"), prompt)
        XCTAssertTrue(prompt.contains("standing at C and facing T"), prompt)
        XCTAssertTrue(prompt.contains("The harbour master's hut at the centre of the frame"), prompt)
        XCTAssertEqual(SketchStudioComposer.vantageReferenceImages(for: input(floorPlan: true, words: words)).first?.label, "plan:marked floor plan")
        XCTAssertTrue(SketchStudioComposer.geometryWords(CameraPlacement(basePicture: "p", isFloorPlan: true, x: 0.1, y: 0.1, targetX: 0.9, targetY: 0.9)).at.contains("the top of the plan"))
    }

    func testVantageRequestIsACreateWithTheLocationPurpose() {
        let request = SketchStudioComposer.vantageRequest(for: input(floorPlan: false, words: nil))
        XCTAssertFalse(request.isEdit)
        XCTAssertEqual(request.aspectRatio, "16:9")
        XCTAssertEqual(request.referenceImages?.count, 1)
        XCTAssertEqual(request.brief?.purpose, .location)
        XCTAssertTrue(request.prompt.hasPrefix("A new photograph of Pier 9"))
    }
}
