import XCTest
import DirectorsChairCore
import DirectorsChairServices
@testable import DirectorsChairViews

/// DC-0073: the pin editor's instruction wording IS the composer's — one
/// wording for every surface, and the editor's radius reaches the pins.
final class AnnotationEditorPromptTests: XCTestCase {
    func testTheEditorsPromptIsTheComposersWording() {
        let pins = [KeyframeAnnotation(normalizedX: 0.43, normalizedY: 0.15, text: "remove the bubble", number: 2),
                    KeyframeAnnotation(normalizedX: 0.1, normalizedY: 0.9, text: "a lantern", number: 1, radius: 0.3)]
        XCTAssertEqual(ImageAnnotationEditor.buildEditPrompt(from: pins, context: "scene preview"),
                       AnnotationEditComposer.instructions(pins: pins.map(AnnotationPin.init), context: "scene preview"))
        XCTAssertEqual(ImageAnnotationEditor.buildEditPrompt(from: pins, context: "scene preview"), """
        Edit this scene preview with the following changes:
        1. At (10%, 90%): a lantern
        2. At (43%, 15%): remove the bubble
        Keep all other areas unchanged.
        """)
        XCTAssertEqual(ImageAnnotationEditor.buildEditPrompt(from: [], context: "image"), "")
    }

    func testAVisionImageEditCarriesTheMarksAndComposesTheSamePromptAsBefore() {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let edit = VisionImageEdit(edit: AnnotationEdit(
            source: png, annotations: [KeyframeAnnotation(normalizedX: 0.3, normalizedY: 0.6, text: "brighter window", number: 1)],
            context: "image", originalPrompt: "a rain-soaked neon street"))
        XCTAssertEqual(edit.baseImage, png)
        // A 4-byte stand-in can't be marked, so the wording falls back to positions in words; never the original prompt.
        XCTAssertEqual(edit.prompt, "Edit the FIRST attached picture. Make exactly these changes and nothing else:\n1. At about 30% across and 60% down from the top-left corner: brighter window\nEverything else — the other people, the place, the composition and framing, the lighting and the film look — must stay exactly as in the picture. Return the edited picture with the same framing.")
        XCTAssertTrue(PromptSections.isEditPrompt(edit.prompt), "the next generation must not build on an edit prompt")
        XCTAssertEqual(AnnotationEditComposer.regions(for: edit.edit).count, 1, "the marks reach the on-device engine")
    }
}
