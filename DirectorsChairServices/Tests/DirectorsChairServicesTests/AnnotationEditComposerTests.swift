import XCTest
@testable import DirectorsChairCore
@testable import DirectorsChairServices

/// DC-0073: one description of an annotation edit, one composition of it
/// into a request — pinned so seven surfaces can stop assembling their own.
final class AnnotationEditComposerTests: XCTestCase {
    private let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    private var pins: [AnnotationPin] {
        [AnnotationPin(x: 0.43, y: 0.15, text: "remove the speech bubble that says KEEP", number: 1),
         AnnotationPin(x: 0.7, y: 0.6, text: "a brass lantern on the table", number: 2, radius: 0.3)]
    }

    private func canonical(_ body: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]), as: UTF8.self)
    }

    // MARK: Wording

    func testInstructionsAreTheProvenWordingNumberedAndPositioned() {
        let text = AnnotationEditComposer.instructions(pins: pins.reversed(), context: "scene preview")
        XCTAssertEqual(text, """
        Edit this scene preview with the following changes:
        1. At (43%, 15%): remove the speech bubble that says KEEP
        2. At (70%, 60%): a brass lantern on the table
        Keep all other areas unchanged.
        """)
        XCTAssertEqual(AnnotationEditComposer.instructions(pins: [], context: "image"), "")
    }

    // Owner 2026-08-29: an edit is the change plus the edit guard — the original
    // generation prompt is never appended (it made the model start over).
    func testPromptIsTheChangeAndTheEditGuardNeverTheOriginalPrompt() {
        let withOriginal = AnnotationEdit(source: png, pins: pins, context: "shot preview",
                                          originalPrompt: "Cinematic film still, porch at dusk")
        let prompt = AnnotationEditComposer.prompt(for: withOriginal)
        XCTAssertFalse(prompt.contains("Original prompt"))
        XCTAssertFalse(prompt.contains("porch at dusk"))
        XCTAssertTrue(prompt.hasPrefix("Edit this shot preview with the following changes:"))
        XCTAssertTrue(prompt.contains("Keep all other areas unchanged.\n\nThis is an edit of the attached picture. Change only what is listed above"), prompt)
        let face = ReferenceImage(base64: "RkFDRQ==", mimeType: "image/png", label: "character:Alex")
        let withFace = AnnotationEdit(source: png, pins: pins, context: "shot preview", contextPictures: [face])
        XCTAssertTrue(AnnotationEditComposer.prompt(for: withFace)
            .hasSuffix("The reference labelled \"character:Alex\" shows Alex; use it only for the change that mentions it."))
        let whole = AnnotationPin(x: 0.5, y: 0.5, text: "make it dusk", number: 1, radius: KeyframeAnnotation.wholePictureRadius)
        let wholeEdit = AnnotationEdit(source: png, pins: [whole], context: "shot preview")
        XCTAssertTrue(AnnotationEditComposer.prompt(for: wholeEdit).contains("re-imagine it as instructed"))
        XCTAssertEqual(AnnotationEditComposer.prompt(for: AnnotationEdit(source: png, pins: [], context: "shot preview")), "")
    }

    // MARK: Regions and pins

    func testPinsBecomeRegionsWithTheirOwnOrTheDefaultReach() {
        let regions = AnnotationEditComposer.regions(for: AnnotationEdit(source: png, pins: pins, context: "image"))
        XCTAssertEqual(regions.count, 2)
        XCTAssertEqual(regions[0].radius, EditRegion.defaultRadius)
        XCTAssertEqual(regions[1].radius, 0.3)
        XCTAssertEqual(regions[1].x, 0.7); XCTAssertEqual(regions[1].y, 0.6)
    }

    func testAKeyframeAnnotationCarriesItsReachIntoThePin() {
        let annotation = KeyframeAnnotation(normalizedX: 0.2, normalizedY: 0.8, text: "wider hat", number: 3, radius: 0.25)
        let pin = AnnotationPin(annotation)
        XCTAssertEqual(pin.x, 0.2); XCTAssertEqual(pin.y, 0.8); XCTAssertEqual(pin.number, 3); XCTAssertEqual(pin.radius, 0.25)
        let edit = AnnotationEdit(source: png, annotations: [annotation], context: "keyframe")
        XCTAssertEqual(edit.pins, [pin])
        XCTAssertEqual(edit.sourceLabel, "Current keyframe to edit")
    }

    // MARK: The request

    func testCloudRequestWithoutContextTravelsAsTheSingleReference() throws {
        let edit = AnnotationEdit(source: png, pins: pins, context: "character image", aspectRatio: "1:1")
        let request = AnnotationEditComposer.request(for: edit, provider: .google)
        XCTAssertTrue(request.isEdit); XCTAssertTrue(request.isEditOfExistingImage)
        XCTAssertEqual(request.aspectRatio, "1:1")
        XCTAssertEqual(request.referenceImageBase64, png.base64EncodedString())
        XCTAssertEqual(request.referenceMimeType, "image/png")
        XCTAssertNil(request.referenceImages)
        XCTAssertEqual(request.brief?.purpose, .edit)
        XCTAssertEqual(request.brief?.subject, "1. remove the speech bubble that says KEEP\n2. a brass lantern on the table")
        XCTAssertEqual(request.editRegions.count, 2)
        let body = AIServiceClient.cloudImageBody(for: request, preferredModel: nil)
        XCTAssertEqual(Set(body.keys), ["prompt", "provider", "aspect_ratio", "n", "reference_image_base64", "reference_mime_type"])
    }

    func testCloudRequestWithContextTravelsAsTheLabelledSetSourceFirst() {
        let plate = ReferenceImage(base64: "UExBVEU=", mimeType: "image/png", label: "location:Lighthouse Gallery")
        let edit = AnnotationEdit(source: png, pins: pins, context: "shot preview",
                                  originalPrompt: "Wide: Noor alone", contextPictures: [plate])
        let request = AnnotationEditComposer.request(for: edit, provider: .google)
        XCTAssertNil(request.referenceImageBase64)
        let refs = try! XCTUnwrap(request.referenceImages)
        XCTAssertEqual(refs.map(\.label), ["Current shot preview to edit", "location:Lighthouse Gallery"])
        XCTAssertEqual(refs.first?.base64, png.base64EncodedString())
    }

    /// The shot surface's request today, hand-built the way it always was,
    /// against the composed one: the cloud body must be byte-identical.
    func testComposedShotEditMatchesTheHandBuiltCloudBodyByteForByte() throws {
        let plate = ReferenceImage(base64: "UExBVEU=", mimeType: "image/png", label: "location:Lighthouse Gallery")
        let face = ReferenceImage(base64: "RkFDRQ==", mimeType: "image/png", label: "character:Noor")
        let annotations = [KeyframeAnnotation(normalizedX: 0.43, normalizedY: 0.15, text: "remove the speech bubble that says KEEP", number: 1)]
        // The old surface code, verbatim.
        var handPrompt = "Edit this shot preview with the following changes:\n"
        for ann in annotations.sorted(by: { $0.number < $1.number }) {
            handPrompt += "\(ann.number). At (\(Int(ann.normalizedX * 100))%, \(Int(ann.normalizedY * 100))%): \(ann.text)\n"
        }
        handPrompt += "Keep all other areas unchanged."
        let combined = handPrompt + "\n\n" + AnnotationEditComposer.editGuard(for: AnnotationEdit(
            source: png, annotations: annotations, context: "shot preview", contextPictures: [plate, face]))
        let hand = ImageGenerationRequest(
            prompt: combined, provider: .google, aspectRatio: "16:9", numberOfImages: 1,
            referenceImages: [ReferenceImage(base64: png.base64EncodedString(), mimeType: "image/png", label: "Current shot preview to edit"), plate, face],
            brief: VisualBrief(purpose: .edit, subject: StoryboardSubjects.editInstruction(from: handPrompt)),
            editRegions: annotations.map { EditRegion(x: $0.normalizedX, y: $0.normalizedY) })
        let composed = AnnotationEditComposer.request(
            for: AnnotationEdit(source: png, annotations: annotations, context: "shot preview",
                                originalPrompt: "Cinematic film still, porch at dusk", contextPictures: [plate, face]),
            provider: .google)
        XCTAssertEqual(try canonical(AIServiceClient.cloudImageBody(for: hand, preferredModel: nil)),
                       try canonical(AIServiceClient.cloudImageBody(for: composed, preferredModel: nil)))
        XCTAssertEqual(composed.brief, hand.brief)
        XCTAssertEqual(composed.editRegions, hand.editRegions)
    }

    func testOnDeviceRequestSendsTheSourceAloneWithRegionsAndTheEditBrief() {
        let plate = ReferenceImage(base64: "UExBVEU=", mimeType: "image/png", label: "location:Lighthouse Gallery")
        let edit = AnnotationEdit(source: png, pins: pins, context: "shot preview",
                                  originalPrompt: "Wide: Noor alone", contextPictures: [plate])
        let request = AnnotationEditComposer.request(for: edit, provider: .onDevice)
        XCTAssertEqual(request.referenceImageBase64, png.base64EncodedString(), "the repaint needs only the picture it repaints")
        XCTAssertNil(request.referenceImages)
        let (pictures, _) = AIServiceClient.onDeviceReferences(for: request)
        XCTAssertEqual(pictures, [png])
        XCTAssertEqual(request.brief?.purpose, .edit)
        XCTAssertFalse(request.brief?.subject.contains("Original prompt") ?? true)
        XCTAssertFalse(request.brief?.subject.contains("%") ?? true, "positions never reach the drawing as text")
        XCTAssertEqual(request.editRegions.map(\.x), [0.43, 0.7])
    }

    // MARK: The entry point's guards

    func testEditImageRefusesAnEmptyEditBeforeTouchingAnyService() async {
        do {
            _ = try await AIServiceClient.shared.editImage(AnnotationEdit(source: png, pins: [], context: "image"), provider: .onDevice)
            XCTFail("no pins must be refused")
        } catch let error as AIClientError {
            if case .invalidConfiguration(let message) = error { XCTAssertTrue(message.contains("Add a mark")) } else { XCTFail("\(error)") }
        } catch { XCTFail("\(error)") }
        do {
            _ = try await AIServiceClient.shared.editImage(AnnotationEdit(source: Data(), pins: pins, context: "image"), provider: .onDevice)
            XCTFail("no picture must be refused")
        } catch let error as AIClientError {
            if case .invalidConfiguration(let message) = error { XCTAssertTrue(message.contains("no picture")) } else { XCTFail("\(error)") }
        } catch { XCTFail("\(error)") }
    }

    // MARK: Provenance

    func testTheRecordIsWrittenBesideTheResult() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dc-edit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = dir.appendingPathComponent("preview_20260828.png")
        let edit = AnnotationEdit(source: png, pins: pins, context: "shot preview", originalPrompt: "Wide")
        let record = AnnotationEditRecord(edit: edit, provider: .onDevice)
        XCTAssertTrue(record.write(besides: result))
        let sidecar = AnnotationEditRecord.sidecarURL(for: result)
        XCTAssertEqual(sidecar.lastPathComponent, "preview_20260828.edit.json")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(AnnotationEditRecord.self, from: Data(contentsOf: sidecar))
        XCTAssertEqual(back.pins.count, 2); XCTAssertEqual(back.provider, AIProvider.onDevice.rawValue)
        XCTAssertTrue(back.prompt.hasSuffix("Original prompt: Wide"))
    }

    /// An older project's pins (no radius) still decode.
    func testKeyframeAnnotationDecodesWithoutARadius() throws {
        let json = #"{"id":"a","normalizedX":0.5,"normalizedY":0.5,"text":"x","number":1}"#
        let annotation = try JSONDecoder().decode(KeyframeAnnotation.self, from: Data(json.utf8))
        XCTAssertNil(annotation.radius)
    }

    // Owner 2026-08-29: one instruction can re-imagine the whole picture.
    func testWholePicturePinBecomesAWholeEditWithNoMask() {
        let whole = AnnotationPin(x: 0.5, y: 0.5, text: "make it dusk", number: 1, radius: KeyframeAnnotation.wholePictureRadius)
        let spot = AnnotationPin(x: 0.2, y: 0.3, text: "remove the car", number: 2, radius: 0.15)
        let edit = AnnotationEdit(source: Data([1, 2, 3]), pins: [whole, spot], context: "location picture")
        let text = AnnotationEditComposer.instructions(pins: edit.pins, context: edit.context)
        XCTAssertTrue(text.hasPrefix("Edit this location picture as a whole: make it dusk."), text)
        XCTAssertTrue(text.contains("Also, at these spots:\n2. At (20%, 30%): remove the car"), text)
        XCTAssertEqual(AnnotationEditComposer.regions(for: edit).count, 1, "the whole-picture pin has no mask")
        let onlyWhole = AnnotationEdit(source: Data([1]), pins: [whole], context: "shot preview")
        XCTAssertTrue(AnnotationEditComposer.regions(for: onlyWhole).isEmpty)
        XCTAssertFalse(AnnotationEditComposer.instructions(pins: onlyWhole.pins, context: "shot preview").contains("Keep all other areas"))
    }
}
