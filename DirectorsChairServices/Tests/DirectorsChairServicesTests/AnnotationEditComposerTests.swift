import XCTest
import CoreGraphics
import ImageIO
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

    /// A real (decodable) PNG, since the 8-byte stand-in can't be marked.
    private func realPNG(width: Int = 64, height: Int = 36) -> Data? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    private func size(of png: Data) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return (image.width, image.height)
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
        // The 8-byte stand-in can't be marked: the wording falls back to positions in words.
        let prompt = AnnotationEditComposer.prompt(for: withOriginal)
        XCTAssertFalse(prompt.contains("Original prompt"))
        XCTAssertFalse(prompt.contains("porch at dusk"))
        XCTAssertEqual(prompt, """
        Edit the FIRST attached picture. Make exactly these changes and nothing else:
        1. At about 43% across and 15% down from the top-left corner: remove the speech bubble that says KEEP
        2. At about 70% across and 60% down from the top-left corner: a brass lantern on the table
        Everything else — the other people, the place, the composition and framing, the lighting and the film look — must stay exactly as in the picture. Return the edited picture with the same framing.
        """)
        let face = ReferenceImage(base64: "RkFDRQ==", mimeType: "image/png", label: "character:Alex")
        let withFace = AnnotationEdit(source: png, pins: pins, context: "shot preview", contextPictures: [face])
        XCTAssertTrue(AnnotationEditComposer.prompt(for: withFace)
            .hasSuffix("The SECOND attached picture shows Alex (character); use it only for the change that names it."))
        XCTAssertEqual(AnnotationEditComposer.rewriteMentions("@Alex waves at #Nowhere, holding $Lantern", for: withFace),
                       "the person in the SECOND attached picture (Alex — same face, hair and skin as in that picture) waves at Nowhere, holding Lantern")
        let whole = AnnotationPin(x: 0.5, y: 0.5, text: "make it dusk", number: 1, radius: KeyframeAnnotation.wholePictureRadius)
        let wholeEdit = AnnotationEdit(source: png, pins: [whole], context: "shot preview")
        XCTAssertEqual(AnnotationEditComposer.prompt(for: wholeEdit),
                       "Edit the FIRST attached picture. Re-imagine it as follows: make it dusk.\nKeep its subject, place and framing unless the instruction says otherwise.")
        XCTAssertEqual(AnnotationEditComposer.prompt(for: AnnotationEdit(source: png, pins: [], context: "shot preview")), "")
    }

    /// Owner regression 2026-08-29 (edits came back unchanged): a cloud edit
    /// travels as a marked copy — numbered red circles at the pins — and the
    /// wording names each change by its circle and each reference by its
    /// position. The on-device repaint never sees the markers.
    func testCloudEditLocatesChangesByCirclesOnAMarkedCopy() throws {
        let real = try XCTUnwrap(realPNG())
        let face = ReferenceImage(base64: "RkFDRQ==", mimeType: "image/png", label: "character:Alex")
        let mention = AnnotationPin(x: 0.3, y: 0.42, text: "make her look like @Alex", number: 1, radius: 0.18)
        let edit = AnnotationEdit(source: real, pins: [mention], context: "shot preview",
                                  originalPrompt: "Cinematic film still, porch at dusk", contextPictures: [face])
        let payload = AnnotationEditComposer.cloudPayload(for: edit)
        XCTAssertNotEqual(payload.source, real, "the cloud copy carries the circle")
        XCTAssertEqual(size(of: payload.source)?.0, 64); XCTAssertEqual(size(of: payload.source)?.1, 36)
        XCTAssertEqual(payload.prompt, """
        Edit the FIRST attached picture. A red circle numbered 1 has been drawn on it to mark where the change goes; the output must not contain the circles or the numbers.
        Make exactly these changes and nothing else:
        1. Inside circle 1: make her look like the person in the SECOND attached picture (Alex — same face, hair and skin as in that picture)
        Everything else — the other people, the place, the composition and framing, the lighting and the film look — must stay exactly as in the picture. Return the edited picture with the same framing, without the markers.
        The SECOND attached picture shows Alex (character); use it only for the change that names it.
        """)
        let request = AnnotationEditComposer.request(for: edit, provider: .google)
        XCTAssertEqual(request.prompt, payload.prompt)
        XCTAssertEqual(request.referenceImages?.map(\.label), ["Current shot preview to edit", "character:Alex"])
        XCTAssertEqual(request.referenceImages?.first?.base64, payload.source.base64EncodedString())
        XCTAssertEqual(AnnotationEditRecord(edit: edit, provider: .google).prompt, payload.prompt, "the record keeps what was sent")
        let local = AnnotationEditComposer.request(for: edit, provider: .onDevice)
        XCTAssertEqual(local.referenceImageBase64, real.base64EncodedString(), "the repaint inpaints the clean picture")
        XCTAssertEqual(local.editRegions.count, 1)
        // Two spots and a whole-picture instruction: circles for the spots only.
        let dusk = AnnotationPin(x: 0.5, y: 0.5, text: "make it dusk", number: 2, radius: KeyframeAnnotation.wholePictureRadius)
        let car = AnnotationPin(x: 0.8, y: 0.7, text: "remove the car", number: 3)
        let mixed = AnnotationEditComposer.cloudPayload(for: AnnotationEdit(source: real, pins: [mention, dusk, car], context: "shot preview"))
        XCTAssertTrue(mixed.prompt.hasPrefix("Edit the FIRST attached picture. Re-imagine it as follows: make it dusk.\nKeep its subject, place and framing unless the instruction says otherwise.\nRed circles numbered 1, 3 have been drawn on it"), mixed.prompt)
        XCTAssertTrue(mixed.prompt.contains("Also make exactly these changes at the marked spots:\n1. Inside circle 1: make her look like Alex\n3. Inside circle 3: remove the car"), mixed.prompt)
        // Whole-picture only: nothing to mark, the clean picture travels.
        let wholeOnly = AnnotationEditComposer.cloudPayload(for: AnnotationEdit(source: real, pins: [dusk], context: "shot preview"))
        XCTAssertEqual(wholeOnly.source, real)
        // Ad-hoc look at the markup on a real picture: DC_MARKUP_SOURCE=/path/to.png writes <path>.marked.png beside it.
        if let path = ProcessInfo.processInfo.environment["DC_MARKUP_SOURCE"], let data = FileManager.default.contents(atPath: path),
           let marked = AnnotationMarkup.marked(source: data, pins: [mention, car]) {
            try marked.write(to: URL(fileURLWithPath: path + ".marked.png"))
        }
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
        let combined = AnnotationEditComposer.prompt(for: AnnotationEdit(
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
        XCTAssertTrue(back.prompt.contains("must stay exactly as in the picture"), back.prompt)
        XCTAssertFalse(back.prompt.contains("Original prompt"), "the record keeps what was sent — the change and the guard, never the old prompt")
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
