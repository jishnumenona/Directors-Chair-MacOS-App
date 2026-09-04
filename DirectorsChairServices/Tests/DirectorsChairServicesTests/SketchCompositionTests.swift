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
        let clean = Data([7, 7])
        let input = SketchStudioInput(
            mode: .create, sceneText: "A dawn highway, 35mm film look.",
            taggedSketchPNG: png, cleanSketchPNG: clean,
            placements: [SketchPlacement(element: alex, x: 0.3, y: 0.6),
                         SketchPlacement(element: van, x: 0.7, y: 0.5)],
            notes: [SketchNote(text: "rain streaks across @Alex's shoulder", x: 0.32, y: 0.4)],
            generalReferences: [desert])
        let prompt = SketchStudioComposer.prompt(for: input)
        XCTAssertTrue(prompt.hasPrefix("A dawn highway, 35mm film look.\n\nImage 1 is a rough hand-drawn PLANNING sketch"), prompt)
        XCTAssertTrue(prompt.contains("A tag's number is the number of the attached image that shows the real thing."), prompt)
        XCTAssertTrue(prompt.contains("Image 2 is the same sketch with red numbered tags"), prompt)
        XCTAssertTrue(prompt.contains("never as new free-standing objects"), prompt)
        XCTAssertTrue(prompt.contains("- The figure at tag 3 is the character Alex: render the person from Image 3 there — same identity: face, features, hair"), prompt)
        XCTAssertTrue(prompt.contains("- The shape at tag 4 is the prop \"Mini van\": render the object from Image 4 there"), prompt)
        // Notes continue the tag numbering after placements (3, 4 → note 5),
        // and their mentions read as plain names.
        XCTAssertTrue(prompt.contains("- Tag 5 marks a spot instruction: rain streaks across Alex's shoulder"), prompt)
        XCTAssertTrue(prompt.contains("- Image 6 is the LOCATION (Desert road): the whole shot takes place in this exact environment"), prompt)
        XCTAssertTrue(prompt.contains("NO black pencil lines, NO red circles and NO numbers anywhere"), prompt)
        // The ink ban is the LAST constraint before the render line (dark-
        // scene probe: earlier placement leaked ink and badges).
        XCTAssertTrue(prompt.hasSuffix("Where a line or tag sat, paint only what belongs in the scene.\nRender one photorealistic cinematic frame."), prompt)
        // The relighting contract (owner 2026-08-31: pasted-in look) — one
        // exposure, no reference lighting carried over.
        XCTAssertTrue(prompt.contains("as if photographed together in one exposure and graded as one frame"), prompt)
        XCTAssertTrue(prompt.contains("Re-light and RE-GRADE them entirely to this shot"), prompt)
        // Owner 2026-08-31 (screenshot: suit kept its fresh neutral whites in
        // a teal night): identity comes from the reference, colour-as-seen
        // comes from the scene — pinned for costumes and the frame line.
        XCTAssertTrue(prompt.contains("Anything whose colours or cleanliness look untouched by the scene is wrong"), prompt)
        let refs = SketchStudioComposer.referenceImages(for: input)
        XCTAssertEqual(refs.map(\.label), ["sketch:plan", "sketch:tagged copy", "character:Alex", "prop:Mini van", "location:Desert road"])
        XCTAssertEqual(refs[0].base64, clean.base64EncodedString())
        XCTAssertEqual(refs[1].base64, png.base64EncodedString())
        // Image N in the prompt == refs[N-1] — the invariant everything rides on.
        XCTAssertEqual(refs.count, 5)
        XCTAssertEqual(SketchStudioComposer.firstTagNumber(for: .create), 3)
    }

    func testEditModeLeadsWithTheBaseAndGuardsTheRest() {
        let base = Data([9, 9])
        let input = SketchStudioInput(
            mode: .edit, sceneText: "Make it night.",
            taggedSketchPNG: png, basePNG: base,
            placements: [SketchPlacement(element: alex, x: 0.4, y: 0.4)],
            notes: [SketchNote(text: "make the hood down", x: 0.41, y: 0.3)])
        let prompt = SketchStudioComposer.prompt(for: input)
        XCTAssertTrue(prompt.hasPrefix("Edit the FIRST attached picture. This is an EDIT of an existing photograph, not a new picture"), prompt)
        XCTAssertTrue(prompt.contains("Image 2 is the same picture with rough hand-drawn pencil marks"), prompt)
        // Bare strokes are a complete instruction on their own (owner 2026-09-04).
        XCTAssertTrue(prompt.contains("- Where a pencil shape carries no tag and no note, it shows what to add or reshape at that exact spot"), prompt)
        XCTAssertTrue(prompt.contains("Make exactly these changes and nothing else:\n- Make it night.\n- The figure at tag 3 is the character Alex: render the person from Image 3 there"), prompt)
        XCTAssertTrue(prompt.contains("must stay exactly as in the first picture"), prompt)
        XCTAssertTrue(prompt.hasSuffix("The pencil marks and tags are instructions, never content: the result must contain NO pencil lines, NO red circles and NO numbers anywhere."), prompt)
        XCTAssertTrue(prompt.contains("- At tag 4: make the hood down"), prompt)
        XCTAssertTrue(prompt.contains("lit AND colour-graded by the FIRST picture's existing light and grade"), prompt)
        XCTAssertEqual(SketchStudioComposer.stripMentions("put $Lantern by #Pier near @Alex"),
                       "put Lantern by Pier near Alex")
        XCTAssertTrue(prompt.contains("photographed in place, never pasted in"), prompt)
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

    /// Annotating a picture never inherits words: with no scene text the
    /// edit prompt is built from the base, the marks and the references only.
    func testEditModeWithNoWordsIsStillACompleteInstruction() {
        let input = SketchStudioInput(mode: .edit, sceneText: "", taggedSketchPNG: png, basePNG: Data([9]))
        let prompt = SketchStudioComposer.prompt(for: input)
        XCTAssertTrue(prompt.contains("Make exactly these changes and nothing else:\n- Where a pencil shape carries no tag and no note"), prompt)
        XCTAssertFalse(prompt.contains("- \n"), "an empty change bullet must never be emitted")
        XCTAssertEqual(SketchStudioComposer.referenceImages(for: input).map(\.label),
                       ["base:picture to edit", "sketch:marked plan"])
    }

    func testEveryKindHasAPlacedAndAGeneralClause() {
        for kind in ["character", "costume", "prop", "location", "shot"] {
            let element = SketchElement(kind: kind, name: "X", imageData: Data([1]))
            XCTAssertTrue(SketchStudioComposer.placedClause(element, tag: 5).contains("5"), kind)
            if ["character", "costume", "prop"].contains(kind) {
                XCTAssertTrue(SketchStudioComposer.placedClause(element, tag: 5).lowercased().contains("grade"),
                              "\(kind) must re-grade to the scene")
            }
            XCTAssertTrue(SketchStudioComposer.generalClause(element, image: 6).contains("Image 6"), kind)
        }
    }
}
