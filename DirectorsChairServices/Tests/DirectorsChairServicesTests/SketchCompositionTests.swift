import XCTest
@testable import DirectorsChairCore
@testable import DirectorsChairServices

/// DC-0110: the sketch studio's composer — tag number == attached image
/// number is the whole mechanism, so the numbering is pinned hard.
final class SketchCompositionTests: XCTestCase {
    private let png = Data([0x89, 0x50, 0x4E, 0x47])
    private var alex: SketchElement { SketchElement(kind: "character", name: "Alex", imageData: Data([1])) }
    private var van: SketchElement { SketchElement(kind: "prop", name: "Mini van", imageData: Data([2])) }
    private var desert: SketchElement { SketchElement(kind: "location", name: "Desert road", imageData: Data([3])) }

    func testCreateModeNumbersTagsFromTwoAndOrdersPictures() {
        let input = SketchStudioInput(
            mode: .create, sceneText: "A dawn highway, 35mm film look.",
            taggedSketchPNG: png,
            placements: [SketchPlacement(element: alex, x: 0.3, y: 0.6),
                         SketchPlacement(element: van, x: 0.7, y: 0.5)],
            generalReferences: [desert])
        let prompt = SketchStudioComposer.prompt(for: input)
        XCTAssertTrue(prompt.hasPrefix("A dawn highway, 35mm film look.\n\nImage 1 is a rough hand-drawn PLANNING sketch"), prompt)
        XCTAssertTrue(prompt.contains("A tag's number is the number of the attached image that shows the real thing."), prompt)
        XCTAssertTrue(prompt.contains("- The figure at tag 2 is the character Alex: render the person from Image 2 there — same face, hair and skin"), prompt)
        XCTAssertTrue(prompt.contains("- The shape at tag 3 is the prop \"Mini van\": render the object from Image 3 there"), prompt)
        XCTAssertTrue(prompt.contains("- Image 4 is the LOCATION (Desert road): the whole shot takes place in this exact environment"), prompt)
        XCTAssertTrue(prompt.contains("none of them may appear in the photograph"), prompt)
        let refs = SketchStudioComposer.referenceImages(for: input)
        XCTAssertEqual(refs.map(\.label), ["sketch:plan", "character:Alex", "prop:Mini van", "location:Desert road"])
        XCTAssertEqual(refs[0].base64, png.base64EncodedString())
        // Image N in the prompt == refs[N-1] — the invariant everything rides on.
        XCTAssertEqual(refs.count, 4)
        XCTAssertEqual(SketchStudioComposer.firstTagNumber(for: .create), 2)
    }

    func testEditModeLeadsWithTheBaseAndGuardsTheRest() {
        let base = Data([9, 9])
        let input = SketchStudioInput(
            mode: .edit, sceneText: "Make it night.",
            taggedSketchPNG: png, basePNG: base,
            placements: [SketchPlacement(element: alex, x: 0.4, y: 0.4)])
        let prompt = SketchStudioComposer.prompt(for: input)
        XCTAssertTrue(prompt.hasPrefix("Edit the FIRST attached picture. Image 2 is the same picture with rough hand-drawn pencil marks"), prompt)
        XCTAssertTrue(prompt.contains("Make exactly these changes and nothing else:\n- Make it night.\n- The figure at tag 3 is the character Alex: render the person from Image 3 there"), prompt)
        XCTAssertTrue(prompt.contains("must stay exactly as in the first picture"), prompt)
        XCTAssertTrue(prompt.contains("without any pencil marks or tags"), prompt)
        let refs = SketchStudioComposer.referenceImages(for: input)
        XCTAssertEqual(refs.map(\.label), ["base:picture to edit", "sketch:marked plan", "character:Alex"])
        XCTAssertEqual(refs[0].base64, base.base64EncodedString())
        XCTAssertEqual(SketchStudioComposer.firstTagNumber(for: .edit), 3)
        let request = SketchStudioComposer.request(for: input)
        XCTAssertTrue(request.isEdit)
        XCTAssertEqual(request.brief?.purpose, .edit)
        XCTAssertEqual(request.referenceImages?.count, 3)
        XCTAssertEqual(request.prompt, prompt)
    }

    func testEveryKindHasAPlacedAndAGeneralClause() {
        for kind in ["character", "costume", "prop", "location", "shot"] {
            let element = SketchElement(kind: kind, name: "X", imageData: Data([1]))
            XCTAssertTrue(SketchStudioComposer.placedClause(element, tag: 5).contains("5"), kind)
            XCTAssertTrue(SketchStudioComposer.generalClause(element, image: 6).contains("Image 6"), kind)
        }
    }
}
