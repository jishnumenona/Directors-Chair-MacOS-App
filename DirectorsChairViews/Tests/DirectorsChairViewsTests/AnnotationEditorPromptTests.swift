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
        XCTAssertEqual(edit.prompt, "Edit this image with the following changes:\n1. At (30%, 60%): brighter window\nKeep all other areas unchanged.\n\nOriginal prompt: a rain-soaked neon street")
        XCTAssertEqual(AnnotationEditComposer.regions(for: edit.edit).count, 1, "the marks reach the on-device engine")
    }
}
