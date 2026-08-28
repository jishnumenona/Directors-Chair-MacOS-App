// StoryboardEngineTests.swift
//
// DC-0063: the storyboard model manager's contract — locked style
// composition, disk preflight, marker-driven availability, and the
// core seam — all WITHOUT MLX or network (metallib/SPM rule; the real
// diffusion core is DC-0065's app-target concern).

import XCTest
@testable import DirectorsChairServices

final class StoryboardPromptStylerTests: XCTestCase {

    func testPromptCarriesLockedStyleMarkersAndSubject() {
        let prompt = StoryboardPromptStyler.prompt(
            subject: "Wide establishing shot: MAYA enters the abandoned station at dawn")
        for marker in StoryboardPromptStyler.requiredMarkers {
            XCTAssertTrue(prompt.lowercased().contains(marker),
                          "style marker '\(marker)' missing")
        }
        XCTAssertTrue(prompt.contains("MAYA enters the abandoned station"))
        // Z-Image is CFG-distilled: negatives are ignored and only inject
        // the concept — the monochrome lock must be stated positively.
        XCTAssertTrue(prompt.contains("Monochrome black ink"), "positive monochrome lock missing")
        XCTAssertFalse(prompt.contains("no color"))
        XCTAssertFalse(prompt.contains("no photorealism"))
        XCTAssertTrue(prompt.contains("one frame filling the whole page"),
                      "the single-frame lock keeps 'storyboard' from drawing a grid")
    }

    func testComicLookCarriesItsOwnMarkersAndNoNegatives() {
        let comic = StoryboardPromptStyler.prompt(subject: "Dana at the sale", style: .comic)
        for marker in StoryboardPromptStyler.requiredMarkers(for: .comic) {
            XCTAssertTrue(comic.lowercased().contains(marker), marker)
        }
        XCTAssertTrue(comic.contains("flat printed colors"), "comic is the colour look")
        XCTAssertFalse(comic.contains("ink sketch"), "looks must not bleed into each other")
        XCTAssertFalse(comic.lowercased().contains(" no "), "no negatives anywhere")
        let sketch = StoryboardPromptStyler.prompt(subject: "Dana at the sale", style: .sketch)
        XCTAssertNotEqual(comic, sketch)
    }

    func testPurposeChoosesTheDefaultFraming() {
        let costume = StoryboardPromptStyler.prompt(subject: "Dana, 1950s tweed", purpose: .costume)
        XCTAssertTrue(costume.contains("Costume design sheet for Dana"))
        XCTAssertTrue(costume.contains("Full figure standing in a front view from head to feet"))
        let character = StoryboardPromptStyler.prompt(subject: "Mara: adult woman", purpose: .character)
        XCTAssertTrue(character.contains("Character design study of Mara"))
        XCTAssertTrue(character.contains("head-and-shoulders portrait"))
        let scene = StoryboardPromptStyler.prompt(subject: "The parlor", purpose: .scene)
        XCTAssertTrue(scene.contains("The drawing shows: The parlor"))
        XCTAssertTrue(scene.contains("Wide establishing view"))
        // A location plate says "empty, unoccupied" up front, where the
        // encoder reads best — "nobody in it" at the end drew a chef (DC-0071).
        let location = StoryboardPromptStyler.prompt(subject: "The lighthouse kitchen", purpose: .location)
        XCTAssertTrue(location.contains("An architectural study of an empty, unoccupied place with no people anywhere — the drawing shows only the setting itself: The lighthouse kitchen"), location)
        XCTAssertTrue(location.contains("deserted place at eye level"))
        XCTAssertTrue(location.contains("empty of people and figures"))
    }

    func testPromptIncludesFramingNotesOnlyWhenPresent() {
        let with = StoryboardPromptStyler.prompt(subject: "Close-up on the letter",
                                                 notes: "low angle, 35mm")
        XCTAssertTrue(with.contains("Framing: low angle, 35mm."), with)
        let without = StoryboardPromptStyler.prompt(subject: "Close-up on the letter",
                                                    notes: "   ")
        XCTAssertFalse(without.contains("Framing:"))
        XCTAssertTrue(without.contains(StoryboardPromptStyler.defaultFraming(for: .shot)),
                      "blank notes fall back to the purpose's framing")
    }

    func testOverlongSubjectIsCutFromTheEndNotTheFront() {
        let head = "OPENING FRAME: the important part."
        let long = head + String(repeating: " filler", count: 400)
        let prompt = StoryboardPromptStyler.prompt(subject: long)
        XCTAssertTrue(prompt.contains(head), "front of the subject must survive")
        XCTAssertTrue(prompt.contains("…"))
        XCTAssertLessThan(prompt.count,
                          StoryboardPromptStyler.subjectCharacterBudget + 600)
    }
}

final class StoryboardDiskPreflightTests: XCTestCase {

    func testRefusesWhenFreeSpaceBelowModelPlusHeadroom() {
        let model: Int64 = 4_620_000_000
        let error = LocalImageEngine.validateDiskSpace(
            freeBytes: 6_000_000_000, modelBytes: model)
        guard case .insufficientDisk(let needed, let free)? = error else {
            return XCTFail("expected insufficientDisk, got \(String(describing: error))")
        }
        XCTAssertEqual(needed, model + LocalImageEngine.downloadHeadroomBytes)
        XCTAssertEqual(free, 6_000_000_000)
    }

    func testAllowsWhenFreeSpaceCoversModelPlusHeadroom() {
        XCTAssertNil(LocalImageEngine.validateDiskSpace(
            freeBytes: 20_000_000_000, modelBytes: 4_620_000_000))
    }

    func testFreeDiskBytesReportsARealNumberEvenBeforeStorageExists() {
        let engine = LocalImageEngine(
            storageRoot: FileManager.default.temporaryDirectory
                .appendingPathComponent("dc-storyboard-nonexistent-\(UUID().uuidString)"))
        XCTAssertGreaterThan(engine.freeDiskBytes(), 0)
    }
}

final class LocalImageEngineTests: XCTestCase {

    private func makeEngine() -> (LocalImageEngine, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-storyboard-tests-\(UUID().uuidString)")
        return (LocalImageEngine(storageRoot: root), root)
    }

    private func writeMarker(in root: URL) throws {
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)
        let marker = root.appendingPathComponent(
            ".ready-\(LocalImageEngine.model.id.replacingOccurrences(of: "/", with: "_"))")
        try Data().write(to: marker)
    }

    func testFreshEngineNeedsDownloadWithHonestByteCount() async {
        let (engine, _) = makeEngine()
        let state = await engine.availability()
        #if arch(arm64)
        XCTAssertEqual(state, .needsDownload(
            expectedBytes: LocalImageEngine.model.approxBytes))
        #else
        guard case .unavailable = state else {
            return XCTFail("non-arm64 must be unavailable, got \(state)")
        }
        #endif
    }

    func testMarkerOnDiskReadsAsReady() async throws {
        #if arch(arm64)
        let (engine, root) = makeEngine()
        try writeMarker(in: root)
        let state = await engine.availability()
        XCTAssertEqual(state, .ready)
        XCTAssertTrue(engine.isModelDownloaded())
        #endif
    }

    func testGenerateRefusesBeforeDownloadWithoutTouchingTheCore() async {
        let (engine, _) = makeEngine()
        do {
            _ = try await engine.generateFrame(.init(subject: "test frame"))
            XCTFail("must throw before the model is downloaded")
        } catch let error as StoryboardEngineError {
            guard case .notReady = error else {
                return XCTFail("expected notReady, got \(error)")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testGenerateRoutesStyledPromptAndDimensionsThroughTheCore() async throws {
        #if arch(arm64)
        let (engine, root) = makeEngine()
        try writeMarker(in: root)
        let core = RecordingImageCore()
        let previous = LocalImageEngine.core
        LocalImageEngine.core = core
        defer { LocalImageEngine.core = previous }

        let data = try await engine.generateFrame(
            .init(subject: "Two-shot at the diner window", notes: "over-the-shoulder",
                  width: 640, height: 360, seed: 7))
        XCTAssertEqual(data, RecordingImageCore.pngStub)
        let call = try XCTUnwrap(core.calls.first)
        XCTAssertTrue(call.prompt.contains("ink sketch"))
        XCTAssertTrue(call.prompt.contains("Two-shot at the diner window"))
        XCTAssertTrue(call.prompt.contains("Framing: over-the-shoulder."))
        XCTAssertEqual(call.width, 640)
        XCTAssertEqual(call.height, 360)
        XCTAssertEqual(call.seed, 7)
        XCTAssertEqual(call.weightsDirectory,
                       root.appendingPathComponent("models", isDirectory: true)
                           .appendingPathComponent(LocalImageEngine.model.id,
                                                   isDirectory: true))
        #endif
    }

    func testSpecStyleAndOwnerPreferenceReachTheCorePrompt() async throws {
        #if arch(arm64)
        let (engine, root) = makeEngine()
        try writeMarker(in: root)
        let core = RecordingImageCore()
        let previous = LocalImageEngine.core
        LocalImageEngine.core = core
        defer { LocalImageEngine.core = previous }

        // An explicit spec style wins outright.
        _ = try await engine.generateFrame(.init(subject: "explicit", style: .comic))
        XCTAssertTrue(try XCTUnwrap(core.calls.last).prompt.contains("comic book panel"))

        // nil = the owner's Settings choice at that moment.
        let saved = AIProviderSelection.shared.visualStyle
        defer { AIProviderSelection.shared.visualStyle = saved }
        AIProviderSelection.shared.visualStyle = .comic
        _ = try await engine.generateFrame(.init(subject: "preference"))
        XCTAssertTrue(try XCTUnwrap(core.calls.last).prompt.contains("comic book panel"))
        AIProviderSelection.shared.visualStyle = .sketch
        _ = try await engine.generateFrame(.init(subject: "preference"))
        XCTAssertTrue(try XCTUnwrap(core.calls.last).prompt.contains("ink sketch"))
        #endif
    }

    /// A core that draws a figure first and an empty picture second, so
    /// the redraw-on-person rule (DC-0071) can be watched seed by seed.
    private final class FigureThenEmptyCore: OnDeviceImageGenerating, @unchecked Sendable {
        static let figure = Data("figure".utf8), empty = Data("empty".utf8)
        private let lock = NSLock()
        private(set) var seeds: [UInt64?] = []
        func render(_ request: OnDeviceRenderRequest, weightsDirectory: URL) async throws -> Data {
            lock.withLock {
                seeds.append(request.seed)
                return seeds.count == 1 ? Self.figure : Self.empty
            }
        }
    }

    func testAPlaceOrPropThatGainedAFigureIsRedrawnOnTheNextSeed() async throws {
        #if arch(arm64)
        let (engine, root) = makeEngine()
        try writeMarker(in: root)
        let core = FigureThenEmptyCore()
        let previousCore = LocalImageEngine.core, previousDetector = LocalImageEngine.peopleDetector
        LocalImageEngine.core = core
        LocalImageEngine.peopleDetector = { $0 == FigureThenEmptyCore.figure }
        defer { LocalImageEngine.core = previousCore; LocalImageEngine.peopleDetector = previousDetector }

        let plate = try await engine.generateFrame(.init(subject: "The kitchen", seed: 40, purpose: .location))
        XCTAssertEqual(plate, FigureThenEmptyCore.empty, "the figure drawing is not what comes back")
        XCTAssertEqual(core.seeds, [40, 41], "the redraw moves to the next seed")

        // A shot keeps its people: one render, the figure stays.
        let shotCore = FigureThenEmptyCore()
        LocalImageEngine.core = shotCore
        let shot = try await engine.generateFrame(.init(subject: "Two-shot", seed: 40, purpose: .shot))
        XCTAssertEqual(shot, FigureThenEmptyCore.figure)
        XCTAssertEqual(shotCore.seeds, [40])
        XCTAssertTrue(LocalImageEngine.redrawsOnPeople(.prop))
        XCTAssertFalse(LocalImageEngine.redrawsOnPeople(.character))
        #endif
    }

    func testPropPurposeIsAProductStudyOfOneObject() {
        let prop = StoryboardPromptStyler.prompt(subject: "a dented brass storm lantern", purpose: .prop)
        XCTAssertTrue(prop.contains("A product study of one object on its own, nothing and nobody else in the picture — the drawing shows only a dented brass storm lantern"), prop)
        XCTAssertTrue(prop.contains("The object alone, centred and filling the page"))
        let propShop = "Professional film-production prop concept image: Brass storm lantern. A dented brass storm lantern with a cracked glass chimney. Prop category: Handheld. Studio product photography on a neutral dark background, high detail, realistic materials, no people, no text."
        XCTAssertEqual(StoryboardSubjects.inferredPurpose(fromPrompt: propShop), .prop)
        XCTAssertEqual(StoryboardSubjects.plainSubject(from: propShop),
                       "Brass storm lantern. A dented brass storm lantern with a cracked glass chimney. Prop category: Handheld.")
        let withReference = StoryboardPromptStyler.prompt(subject: "the lantern", purpose: .prop, referenceCount: 1)
        XCTAssertTrue(withReference.contains("The same object as in the reference picture"))
        XCTAssertTrue(withReference.contains("ink"), "a prop study keeps the app's look even with a reference photo")
    }

    /// A reference-led render keeps the reference's medium: ink stays ink,
    /// and a colour drawing stays a drawing (DC-0071: a Comic plate's
    /// golden-hour variation came back as a photograph).
    func testReferenceLedRendersLockTheMediumOfTheReference() {
        let colour = StoryboardPromptStyler.prompt(subject: "The kitchen at golden hour", purpose: .location,
                                                   style: .comic, referenceCount: 1, referenceIsMonochrome: false)
        XCTAssertTrue(colour.contains(StoryboardPromptStyler.mediumLock), colour)
        XCTAssertFalse(colour.contains(StoryboardPromptStyler.monochromeLock))
        let ink = StoryboardPromptStyler.prompt(subject: "The kitchen at night", purpose: .location,
                                                style: .sketch, referenceCount: 1, referenceIsMonochrome: true)
        XCTAssertTrue(ink.contains(StoryboardPromptStyler.monochromeLock))
        XCTAssertFalse(ink.contains(StoryboardPromptStyler.mediumLock))
        // A fresh text-to-image render carries the look's own tail, no lock.
        let fresh = StoryboardPromptStyler.prompt(subject: "The kitchen", purpose: .location, style: .comic)
        XCTAssertFalse(fresh.contains(StoryboardPromptStyler.mediumLock))
    }

    /// A shot that names people draws only those people (DC-0071: an insert
    /// of Noor's hand came back with the whole cast).
    func testAShotThatNamesCharactersOnlyTakesThoseReferences() {
        let png = Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString()
        let refs = [ReferenceImage(base64: png, label: "character:Teo"),
                    ReferenceImage(base64: png, label: "location:Lighthouse Gallery"),
                    ReferenceImage(base64: png, label: "character:Noor Haddad"),
                    ReferenceImage(base64: png, label: "prop:Brass storm lantern"),
                    ReferenceImage(base64: png, label: "character:Idris")]
        let insert = ImageGenerationRequest(
            prompt: "x", provider: .onDevice, referenceImages: refs,
            brief: VisualBrief(purpose: .shot, subject: "Insert: Noor's scarred hand trimming the wick with the pocketknife"))
        XCTAssertEqual(AIServiceClient.onDeviceReferences(for: insert).labels,
                       ["location:Lighthouse Gallery", "character:Noor Haddad", "prop:Brass storm lantern"])
        // Nobody named → every character stays (a "three figures" wide).
        let wide = ImageGenerationRequest(
            prompt: "x", provider: .onDevice, referenceImages: refs,
            brief: VisualBrief(purpose: .shot, subject: "Three figures in single file on the cliff path at dawn"))
        XCTAssertEqual(AIServiceClient.onDeviceReferences(for: wide).labels.filter { $0.hasPrefix("character") }.count, 3)
        // A scene keeps its cast regardless of who the summary names.
        let scene = ImageGenerationRequest(
            prompt: "x", provider: .onDevice, referenceImages: refs,
            brief: VisualBrief(purpose: .scene, subject: "Noor trims the lamp"))
        XCTAssertEqual(AIServiceClient.onDeviceReferences(for: scene).labels.filter { $0.hasPrefix("character") }.count, 3)
        // Whole words only: "Teo" must not match "meteor".
        XCTAssertEqual(AIServiceClient.charactersNamed(in: "a meteor over the sea", among: ["character:Teo"]), [])
        // The subject's own cast list must not count as naming.
        XCTAssertEqual(AIServiceClient.charactersNamed(in: "Insert: Noor's hand. People in the frame: Noor; Teo; Idris",
                                                       among: ["character:Teo", "character:Noor", "character:Idris"]), ["character:Noor"])
    }

    /// A shot's subject lists the people the shot names, not the scene's
    /// whole cast (DC-0071: every shot said all three were in the frame).
    func testAShotSubjectListsOnlyTheCharactersItNames() {
        var scene = Scene(name: "Last Light")
        scene.location = "Lighthouse Gallery"
        scene.dialogues = [Dialogue(character: "Noor", text: "The light doesn't know."),
                           Dialogue(character: "Teo", text: "They said six."),
                           Dialogue(character: "Idris", text: "I counted it.")]
        let cast = [Character(name: "Noor"), Character(name: "Teo"), Character(name: "Idris")]
        var insert = Shot(shotId: 7, description: "Insert: Noor's scarred hand trimming the wick")
        let one = StoryboardSubjects.subject(for: insert, in: scene, characters: cast)
        XCTAssertTrue(one.contains("People in the frame: Noor"), one)
        XCTAssertFalse(one.contains("Teo"), one)
        XCTAssertFalse(one.contains("Idris"), one)
        insert.description = "Two-shot at the ladder: Teo rising into frame, Noor turning from the lamp"
        let two = StoryboardSubjects.subject(for: insert, in: scene, characters: cast)
        XCTAssertTrue(two.contains("Noor") && two.contains("Teo") && !two.contains("Idris"), two)
        insert.description = "Three figures in single file on the cliff path at dawn"
        let wide = StoryboardSubjects.subject(for: insert, in: scene, characters: cast)
        XCTAssertTrue(wide.contains("Noor") && wide.contains("Teo") && wide.contains("Idris"), wide)
        XCTAssertTrue(StoryboardSubjects.mentions("Noor's hand", name: "Noor Haddad"))
        XCTAssertFalse(StoryboardSubjects.mentions("a meteor", name: "Teo"))
    }

    func testGenerateWithoutCoreFailsHonestlyWhenReady() async throws {
        #if arch(arm64)
        let (engine, root) = makeEngine()
        try writeMarker(in: root)
        let previous = LocalImageEngine.core
        LocalImageEngine.core = nil
        defer { LocalImageEngine.core = previous }
        do {
            _ = try await engine.generateFrame(.init(subject: "frame"))
            XCTFail("must throw without a core")
        } catch let error as StoryboardEngineError {
            guard case .generationFailed(let message) = error else {
                return XCTFail("expected generationFailed, got \(error)")
            }
            XCTAssertTrue(message.contains("core"))
        }
        #endif
    }
}

final class ScriptedStoryboardEngineTests: XCTestCase {

    func testScriptedEngineRecordsSpecsAndHonorsAvailability() async throws {
        let engine = ScriptedStoryboardEngine(
            availability: .needsDownload(expectedBytes: 42))
        do {
            _ = try await engine.generateFrame(.init(subject: "s"))
            XCTFail("not ready must throw")
        } catch let error as StoryboardEngineError {
            guard case .notReady(.needsDownload(42)) = error else {
                return XCTFail("wrong state: \(error)")
            }
        }
        try await engine.prepare()
        let data = try await engine.generateFrame(.init(subject: "after prepare"))
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(engine.preparations, 1)
        XCTAssertEqual(engine.requests.map(\.subject), ["s", "after prepare"])
    }
}

// MARK: - Recording core double

private final class RecordingImageCore: OnDeviceImageGenerating, @unchecked Sendable {
    static let pngStub = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    struct Call {
        let request: OnDeviceRenderRequest
        let weightsDirectory: URL
        var prompt: String { request.prompt }
        var width: Int { request.width }
        var height: Int { request.height }
        var seed: UInt64? { request.seed }
        var references: [Data] { request.references }
    }
    private let lock = NSLock()
    private var _calls: [Call] = []
    var calls: [Call] { lock.lock(); defer { lock.unlock() }; return _calls }

    func render(_ request: OnDeviceRenderRequest, weightsDirectory: URL) async throws -> Data {
        lock.lock()
        _calls.append(Call(request: request, weightsDirectory: weightsDirectory))
        lock.unlock()
        return Self.pngStub
    }
}

// MARK: - Subjects & persistence (DC-0064)

final class StoryboardSubjectsTests: XCTestCase {

    private func makeScene() -> Scene {
        var scene = Scene(name: "Kitchen Confrontation")
        scene.location = "INT. FARMHOUSE KITCHEN"
        scene.timeOfDay = "Night"
        scene.weather = "Storm"
        scene.sceneOverviewSummary = "Maya confronts her brother over the deed."
        return scene
    }

    func testShotSubjectLeadsWithDescriptionAndCarriesSetting() {
        var shot = Shot(shotId: 3)
        shot.description = "Maya slams the deed onto the table"
        let subject = StoryboardSubjects.subject(for: shot, in: makeScene())
        XCTAssertTrue(subject.hasPrefix("Maya slams the deed"), subject)
        XCTAssertTrue(subject.contains("inside the Farmhouse Kitchen"), "slug lines become description: \(subject)")
        XCTAssertTrue(subject.contains("Night"), subject)
    }

    func testDescriptionlessShotFallsBackToSceneProse() {
        let shot = Shot(shotId: 4, description: "")
        let subject = StoryboardSubjects.subject(for: shot, in: makeScene())
        XCTAssertTrue(subject.contains("Maya confronts her brother"), subject)
    }

    func testCameraNotesReadAsDirectionAndOmitStatic() {
        var shot = Shot(shotId: 5)
        shot.shotType = "Close-up"
        shot.cameraAngle = "Low"
        shot.movement = "Static"
        shot.lensMm = 85
        let notes = try! XCTUnwrap(StoryboardSubjects.notes(for: shot))
        XCTAssertTrue(notes.contains("close-up shot"), notes)
        XCTAssertTrue(notes.contains("from a low angle"), notes)
        XCTAssertTrue(notes.contains("compressed telephoto perspective"), notes)
        // Object nouns get drawn as objects (a shot once rendered a camera).
        XCTAssertFalse(notes.lowercased().contains("lens"), notes)
        XCTAssertFalse(notes.lowercased().contains("camera"), notes)
        XCTAssertFalse(notes.contains("Static"), "static camera is not direction")
    }

    func testSceneSubjectIsAnEstablishingFrameWithSlugFacts() {
        let subject = StoryboardSubjects.subject(for: makeScene())
        XCTAssertTrue(subject.hasPrefix("Kitchen Confrontation — inside the Farmhouse Kitchen"), subject)
        XCTAssertTrue(subject.contains("Storm"), subject)
        XCTAssertTrue(subject.contains("Maya confronts her brother"), subject)
    }

    func testEngineErrorsExplainThemselvesToUsers() {
        XCTAssertTrue(StoryboardEngineError
            .notReady(.needsDownload(expectedBytes: 1)).userMessage
            .contains("Settings"))
        let disk = StoryboardEngineError
            .insufficientDisk(neededBytes: 7_916_000_000, freeBytes: 8_000_000_000)
            .userMessage
        XCTAssertTrue(disk.contains("7.92 GB"), disk)
        XCTAssertTrue(disk.contains("8 GB"), disk)
    }
}

final class StoryboardFrameStoreTests: XCTestCase {

    func testSaveWritesTimestampedPlusLatestAndReturnsRelativePaths() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-framestore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let stamp = Date(timeIntervalSince1970: 1_756_000_000)

        let saved = try StoryboardFrameStore.save(
            png: png, projectBasePath: base,
            relativeDirectory: "assets/shots/shot_7", timestamp: stamp)

        XCTAssertEqual(saved.relativePath, "assets/shots/shot_7/storyboard_latest.png")
        XCTAssertTrue(saved.timestampedRelativePath.hasPrefix("assets/shots/shot_7/storyboard_2025"))
        for relative in [saved.relativePath, saved.timestampedRelativePath] {
            let url = base.appendingPathComponent(relative)
            XCTAssertEqual(try Data(contentsOf: url), png, relative)
        }
    }

    func testSecondSaveReplacesLatestButKeepsHistory() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-framestore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let first = try StoryboardFrameStore.save(
            png: Data([1]), projectBasePath: base,
            relativeDirectory: "assets/scenes/Kitchen",
            timestamp: Date(timeIntervalSince1970: 1_756_000_000))
        let second = try StoryboardFrameStore.save(
            png: Data([2]), projectBasePath: base,
            relativeDirectory: "assets/scenes/Kitchen",
            timestamp: Date(timeIntervalSince1970: 1_756_000_100))

        XCTAssertEqual(second.relativePath, first.relativePath)
        XCTAssertEqual(
            try Data(contentsOf: base.appendingPathComponent(second.relativePath)),
            Data([2]), "latest must carry the newest frame")
        XCTAssertEqual(
            try Data(contentsOf: base.appendingPathComponent(first.timestampedRelativePath)),
            Data([1]), "history must survive")
    }
}

// MARK: - Drawing-capability gate + image routing (DC-0065 surfaces)

final class StoryboardGenerationGateTests: XCTestCase {

    func testDownloadedModelWithoutCoreIsNotDrawable() async throws {
        #if arch(arm64)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-gate-\(UUID().uuidString)")
        let engine = LocalImageEngine(storageRoot: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent(
            ".ready-\(LocalImageEngine.model.id.replacingOccurrences(of: "/", with: "_"))"))
        let previous = LocalImageEngine.core
        defer { LocalImageEngine.core = previous }

        LocalImageEngine.core = nil
        let gated = await engine.generationAvailability()
        guard case .unavailable(let reason) = gated else {
            return XCTFail("core-less engine must not read as drawable, got \(gated)")
        }
        XCTAssertTrue(reason.contains("downloaded"), reason)

        LocalImageEngine.core = NullImageCore()
        let drawable = await engine.generationAvailability()
        XCTAssertEqual(drawable, .ready)
        #endif
    }

    func testUndownloadedModelGatesOnDownloadNotOnCore() async {
        let engine = LocalImageEngine(
            storageRoot: FileManager.default.temporaryDirectory
                .appendingPathComponent("dc-gate-\(UUID().uuidString)"))
        let state = await engine.generationAvailability()
        #if arch(arm64)
        XCTAssertEqual(state, .needsDownload(
            expectedBytes: LocalImageEngine.model.approxBytes))
        #else
        guard case .unavailable = state else {
            return XCTFail("non-arm64 must be unavailable")
        }
        #endif
    }
}

final class OnDeviceImageRoutingTests: XCTestCase {

    func testOnDeviceImageRequestRoutesToTheEngineNotTheWire() async throws {
        let scripted = ScriptedStoryboardEngine()
        let previous = AIServiceClient.onDeviceImageEngine
        AIServiceClient.onDeviceImageEngine = scripted
        defer { AIServiceClient.onDeviceImageEngine = previous }

        // A dead-end URL proves no network is touched: reaching the wire
        // would fail, the engine route succeeds.
        let client = AIServiceClient(baseURL: "http://127.0.0.1:9", timeout: 1)
        let response = try await client.generateImage(ImageGenerationRequest(
            prompt: "Maya at the window", provider: .onDevice, aspectRatio: "1:1"))

        XCTAssertEqual(response.provider, .onDevice)
        XCTAssertEqual(response.model, LocalImageEngine.model.id)
        XCTAssertFalse(response.images.isEmpty)
        let spec = try XCTUnwrap(scripted.requests.first)
        XCTAssertEqual(spec.subject, "Maya at the window")
        XCTAssertEqual(spec.purpose, .moodboard, "no brief = a generic picture, cleaned")
        XCTAssertEqual(spec.width, 640)
        XCTAssertEqual(spec.height, 640)
    }

    func testUnreadyEngineRefusalPropagatesInsteadOfFallingBack() async {
        let scripted = ScriptedStoryboardEngine(
            availability: .needsDownload(expectedBytes: 5))
        let previous = AIServiceClient.onDeviceImageEngine
        AIServiceClient.onDeviceImageEngine = scripted
        defer { AIServiceClient.onDeviceImageEngine = previous }

        let client = AIServiceClient(baseURL: "http://127.0.0.1:9", timeout: 1)
        do {
            _ = try await client.generateImage(ImageGenerationRequest(
                prompt: "x", provider: .onDevice))
            XCTFail("must refuse, never silently fall back to a paid provider")
        } catch let error as StoryboardEngineError {
            guard case .notReady = error else {
                return XCTFail("expected notReady, got \(error)")
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testAspectRatioMapsToLatentFriendlySizes() {
        XCTAssertEqual(AIServiceClient.onDeviceImageSize(for: "16:9").width, 768)
        XCTAssertEqual(AIServiceClient.onDeviceImageSize(for: "9:16").height, 768)
        let square = AIServiceClient.onDeviceImageSize(for: "1:1")
        XCTAssertEqual(square.width, 640)
        XCTAssertEqual(square.height, 640)
        // Every size must sit on the 16-pixel latent grid.
        for ratio in ["16:9", "9:16", "1:1", "4:3", "3:4", "banana"] {
            let size = AIServiceClient.onDeviceImageSize(for: ratio)
            XCTAssertEqual(size.width % 16, 0, ratio)
            XCTAssertEqual(size.height % 16, 0, ratio)
        }
    }
}

private struct NullImageCore: OnDeviceImageGenerating {
    func render(_ request: OnDeviceRenderRequest, weightsDirectory: URL) async throws -> Data {
        Data()
    }
}


// MARK: - Visual styles, briefs & prompt cleaning (DC-0066)

final class VisualBriefAndCleaningTests: XCTestCase {

    /// The exact scene-overview prompt that drew a photograph-in-a-panel
    /// with a garbage caption on the owner's Mac (2026-08-25).
    private let ownerPrompt = "Cinematic film still, professional cinematography, establishing shot, " +
        "set in INT. BELLHAVEN ESTATE HOUSE - PARLOR - DAY, Mara buys Henry Okafor's 1950s rangefinder " +
        "at his estate sale; his daughter Dana lets it go for almost nothing -- with a warning she " +
        "half-swallows., stillness mood and atmosphere, featuring characters in the scene, dramatic " +
        "lighting, cinematic color grading, movie quality, 16:9 widescreen composition"

    func testPlainSubjectStripsPhotorealBoilerplateAndKeepsTheStory() {
        let plain = StoryboardSubjects.plainSubject(from: ownerPrompt)
        for gone in ["Cinematic film still", "professional cinematography", "dramatic lighting",
                     "cinematic color grading", "movie quality", "16:9", "widescreen"] {
            XCTAssertFalse(plain.lowercased().contains(gone.lowercased()), "'\(gone)' survived: \(plain)")
        }
        XCTAssertTrue(plain.contains("Mara buys Henry Okafor's 1950s rangefinder"), plain)
        XCTAssertTrue(plain.contains("stillness mood"), plain)
        XCTAssertFalse(plain.contains(", ,"), plain)
        XCTAssertFalse(plain.hasSuffix(","), plain)
    }

    func testPlainSubjectDropsQuotedMoodAndCameraWords() {
        let shotPrompt = "Cinematic film still. Close-up shot. Mara at the window. " +
            "mood: \"You never asked me.\"... Dramatic lighting, film grain, 35mm film aesthetic, " +
            "photorealistic. front facing view, looking directly at camera. " +
            "IMPORTANT: Generate the EXACT SAME person as shown in the reference image. Match the face, " +
            "skin tone, hair, clothing, and art style precisely. This is a different angle of the same " +
            "character, not a new character., character turnaround sheet"
        let plain = StoryboardSubjects.plainSubject(from: shotPrompt)
        XCTAssertFalse(plain.contains("You never asked me"), "quoted dialogue becomes lettering: \(plain)")
        XCTAssertFalse(plain.lowercased().contains("camera"), plain)
        XCTAssertTrue(plain.contains("looking straight ahead"), plain)
        XCTAssertFalse(plain.contains("reference image"), plain)
        XCTAssertFalse(plain.contains("turnaround"), plain)
        XCTAssertTrue(plain.contains("Mara at the window"), plain)
    }

    func testPlainSubjectIsIdempotentOnCleanText() {
        let clean = "Mara holds the rangefinder; Dana hesitates. Setting: parlor, day"
        XCTAssertEqual(StoryboardSubjects.plainSubject(from: clean), clean)
        XCTAssertEqual(StoryboardSubjects.plainSubject(from: StoryboardSubjects.plainSubject(from: ownerPrompt)),
                       StoryboardSubjects.plainSubject(from: ownerPrompt))
    }

    func testBriefRoutesPurposeSubjectAndFramingToTheEngine() async throws {
        let scripted = ScriptedStoryboardEngine()
        let previous = AIServiceClient.onDeviceImageEngine
        AIServiceClient.onDeviceImageEngine = scripted
        defer { AIServiceClient.onDeviceImageEngine = previous }
        let client = AIServiceClient(baseURL: "http://127.0.0.1:9", timeout: 1)
        _ = try await client.generateImage(ImageGenerationRequest(
            prompt: ownerPrompt, provider: .onDevice, aspectRatio: "1:1",
            brief: VisualBrief(purpose: .costume, subject: "Dana in 1950s tweed",
                               framing: StoryboardSubjects.costumeFraming(angle: "back"))))
        let spec = try XCTUnwrap(scripted.requests.first)
        XCTAssertEqual(spec.purpose, .costume)
        XCTAssertEqual(spec.subject, "Dana in 1950s tweed", "the brief wins over the photoreal prompt")
        XCTAssertTrue(try XCTUnwrap(spec.notes).contains("back view"))
    }

    func testEditWithAPictureRoutesAsAnEditWithTheInstructionAndReference() async throws {
        let scripted = ScriptedStoryboardEngine()
        let previous = AIServiceClient.onDeviceImageEngine
        AIServiceClient.onDeviceImageEngine = scripted
        defer { AIServiceClient.onDeviceImageEngine = previous }
        let client = AIServiceClient(baseURL: "http://127.0.0.1:9", timeout: 1)
        let picture = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
        _ = try await client.generateImage(ImageGenerationRequest(
            prompt: "Edit this image by making the following changes while keeping everything else identical:\n1. red scarf at position (40%, 55%)\n2. remove the hat at position (50%, 10%)",
            provider: .onDevice, referenceImageBase64: picture.base64EncodedString(),
            referenceMimeType: "image/png"))
        let spec = try XCTUnwrap(scripted.requests.first)
        XCTAssertEqual(spec.purpose, .edit)
        XCTAssertEqual(spec.subject, "1. red scarf\n2. remove the hat")
        XCTAssertEqual(spec.references, [picture], "the picture being edited is the first reference")
    }

    func testEditWithoutAPictureIsRefusedHonestly() async {
        let scripted = ScriptedStoryboardEngine()
        let previous = AIServiceClient.onDeviceImageEngine
        AIServiceClient.onDeviceImageEngine = scripted
        defer { AIServiceClient.onDeviceImageEngine = previous }
        let client = AIServiceClient(baseURL: "http://127.0.0.1:9", timeout: 1)
        do {
            _ = try await client.generateImage(ImageGenerationRequest(
                prompt: "Edit this image by making the following changes while keeping everything else identical:\n1. red scarf",
                provider: .onDevice))
            XCTFail("nothing to edit must refuse")
        } catch let error as StoryboardEngineError {
            guard case .generationFailed(let message) = error else { return XCTFail("\(error)") }
            XCTAssertTrue(message.contains("no picture"), message)
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertTrue(scripted.requests.isEmpty)
    }

    func testEveryReferenceRidesAlongInOrderCappedAtFour() async throws {
        let scripted = ScriptedStoryboardEngine()
        let previous = AIServiceClient.onDeviceImageEngine
        AIServiceClient.onDeviceImageEngine = scripted
        defer { AIServiceClient.onDeviceImageEngine = previous }
        let client = AIServiceClient(baseURL: "http://127.0.0.1:9", timeout: 1)
        let pictures = (0 ..< 6).map { Data([UInt8($0), 9, 9]) }
        _ = try await client.generateImage(ImageGenerationRequest(
            prompt: "Costume", provider: .onDevice, aspectRatio: "1:1",
            referenceImageBase64: pictures[0].base64EncodedString(), referenceMimeType: "image/png",
            referenceImages: pictures[1...].map {
                ReferenceImage(base64: $0.base64EncodedString(), mimeType: "image/png", label: "g")
            },
            brief: VisualBrief(purpose: .costume, subject: "Dana in tweed")))
        let spec = try XCTUnwrap(scripted.requests.first)
        XCTAssertEqual(spec.references, Array(pictures.prefix(4)), "single first, then labelled, max four")
        XCTAssertEqual(spec.purpose, .costume)
    }

    func testEditInstructionKeepsTheNumberedChangesOnly() {
        let prompt = "Edit this image by making the following changes while keeping everything else identical:\n1. red scarf at position (40%, 55%)\n2. no hat at position (50%, 10%)"
        XCTAssertEqual(StoryboardSubjects.editInstruction(from: prompt),
                       "1. red scarf\n2. no hat", "positions become regions, never lettering")
        XCTAssertEqual(StoryboardSubjects.editInstruction(from: "Edit this image by making the following changes while keeping everything else identical: make it night"),
                       "make it night")
        // The scene/shot preview annotation form (ImageAnnotationEditor).
        let preview = "Edit this scene preview with the following changes:\n1. At (43%, 15%): remove the speech bubble that says KEEP\nKeep all other areas unchanged.\n\nOriginal prompt: Cinematic film still, porch at dusk"
        XCTAssertEqual(StoryboardSubjects.editInstruction(from: preview), "1. remove the speech bubble that says KEEP")
        XCTAssertTrue(ImageGenerationRequest(prompt: preview).isEditOfExistingImage)
        XCTAssertTrue(ImageGenerationRequest(prompt: "Edit this shot preview with the following changes:\n1. At (1%, 2%): x").isEditOfExistingImage)
        XCTAssertFalse(ImageGenerationRequest(prompt: "Editorial photo of a door").isEditOfExistingImage)
    }

    func testReferencePromptsFollowTheReferenceLookForContinuityPurposes() {
        let turnaround = StoryboardPromptStyler.prompt(subject: "Mara", purpose: .character,
                                                        style: .comic, referenceCount: 1)
        XCTAssertTrue(turnaround.contains("same person as in the reference picture"), turnaround)
        XCTAssertTrue(turnaround.contains("same style as the reference"), turnaround)
        XCTAssertFalse(turnaround.contains("comic book panel"), "a photo character must stay a photo")

        let costume = StoryboardPromptStyler.prompt(subject: "Dana", purpose: .costume, referenceCount: 3)
        XCTAssertTrue(costume.contains("wearing the garments shown in the other reference pictures"), costume)

        let shot = StoryboardPromptStyler.prompt(subject: "Dana hands over the camera", purpose: .shot,
                                                  style: .sketch, referenceCount: 2)
        XCTAssertTrue(shot.contains("ink sketch"), "storytelling purposes keep the owner's look")
        XCTAssertTrue(shot.contains("match the reference pictures"), shot)

        let edit = StoryboardPromptStyler.prompt(subject: "1. red scarf", purpose: .edit, style: .comic, referenceCount: 1)
        XCTAssertTrue(edit.hasPrefix("1. red scarf\n"), edit)
        XCTAssertTrue(edit.contains("Keep everything not mentioned"), edit)
        XCTAssertFalse(edit.contains("comic"), edit)
    }

    func testEditRegionsRideFromTheRequestToTheSpec() async throws {
        let scripted = ScriptedStoryboardEngine()
        let previous = AIServiceClient.onDeviceImageEngine
        AIServiceClient.onDeviceImageEngine = scripted
        defer { AIServiceClient.onDeviceImageEngine = previous }
        let client = AIServiceClient(baseURL: "http://127.0.0.1:9", timeout: 1)
        let regions = [EditRegion(x: 0.4, y: 0.55), EditRegion(x: 0.5, y: 0.1, radius: 0.1)]
        _ = try await client.generateImage(ImageGenerationRequest(
            prompt: "Edit this image by making the following changes while keeping everything else identical:\n1. red scarf at position (40%, 55%)",
            provider: .onDevice, referenceImageBase64: Data([1, 2, 3]).base64EncodedString(),
            referenceMimeType: "image/png", editRegions: regions))
        let spec = try XCTUnwrap(scripted.requests.first)
        XCTAssertEqual(spec.editRegions, regions)
        XCTAssertEqual(EditRegion.defaultRadius, 0.18, accuracy: 1e-9)
    }

    #if arch(arm64)
    func testRegionMaskIsOneInsideZeroFarAndSoftBetween() {
        // 16-token grid over a 256×256 picture, one region at the centre.
        let mask = KleinCore.regionMask(regions: [EditRegion(x: 0.5, y: 0.5, radius: 0.2)],
                                        width: 256, height: 256, gridWidth: 16, gridHeight: 16, feather: 0.06)
        XCTAssertEqual(mask.count, 256)
        XCTAssertEqual(mask[8 * 16 + 8], 1, "centre token is fully repainted")
        XCTAssertEqual(mask[0], 0, "a far corner is kept")
        let ring = mask[8 * 16 + 11]   // ~0.22 from the centre: inside the feather band
        XCTAssertGreaterThan(ring, 0); XCTAssertLessThan(ring, 1)
        // Two regions: the max wins, never a sum above 1.
        let two = KleinCore.regionMask(regions: [EditRegion(x: 0.5, y: 0.5, radius: 0.2), EditRegion(x: 0.5, y: 0.5, radius: 0.3)],
                                       width: 256, height: 256, gridWidth: 16, gridHeight: 16, feather: 0.06)
        XCTAssertEqual(two.max(), 1)
        // A landscape picture measures distances against the shorter side.
        let wide = KleinCore.regionMask(regions: [EditRegion(x: 0.5, y: 0.5, radius: 0.2)],
                                        width: 512, height: 256, gridWidth: 32, gridHeight: 16, feather: 0)
        XCTAssertEqual(wide[8 * 32 + 16], 1)
        XCTAssertEqual(wide[8 * 32 + 31], 0)
    }
    #endif

    func testLabelledReferencesAreNamedPictureByPictureInTheOrderSent() {
        let clause = try! XCTUnwrap(StoryboardPromptStyler.labelledReferenceClause(
            ["location:Voss House", "character:Mara Voss", "prop:Okafor Rangefinder", "costume:Mara Voss:Estate Grays"]))
        XCTAssertTrue(clause.contains("The first picture is the location Voss House"), clause)
        XCTAssertTrue(clause.contains("The second picture is Mara Voss: keep this person's face"), clause)
        XCTAssertTrue(clause.contains("The third picture is the prop Okafor Rangefinder"), clause)
        XCTAssertTrue(clause.contains("The fourth picture is the costume Estate Grays worn by Mara Voss"), clause)
        XCTAssertNil(StoryboardPromptStyler.labelledReferenceClause([]))
        XCTAssertNil(StoryboardPromptStyler.labelledReferenceClause([""]), "an unlabelled single reference says nothing")
        let prompt = StoryboardPromptStyler.prompt(subject: "Mara on the porch", purpose: .shot, style: .comic,
                                                   referenceCount: 2, referenceLabels: ["location:Voss House", "character:Mara Voss"])
        XCTAssertTrue(prompt.contains("comic book panel"), "a shot keeps the owner's look")
        XCTAssertTrue(prompt.contains("The first picture is the location Voss House"), prompt)
        XCTAssertFalse(prompt.contains("match the reference pictures"), "the named clause replaces the generic one")
    }

    func testSceneReferencesAreOrderedLocationCharactersPropsCostumesAndCapped() async throws {
        let scripted = ScriptedStoryboardEngine()
        let previous = AIServiceClient.onDeviceImageEngine
        AIServiceClient.onDeviceImageEngine = scripted
        defer { AIServiceClient.onDeviceImageEngine = previous }
        let client = AIServiceClient(baseURL: "http://127.0.0.1:9", timeout: 1)
        func ref(_ label: String, _ byte: UInt8) -> ReferenceImage {
            ReferenceImage(base64: Data([byte]).base64EncodedString(), mimeType: "image/png", label: label)
        }
        // The app's collect order: location, then character/costume pairs.
        let refs = [ref("location:Voss House", 1), ref("character:Mara Voss", 2), ref("costume:Mara Voss:Estate Grays", 3),
                    ref("character:Rez", 4), ref("costume:Rez:Coat", 5), ref("prop:Okafor Rangefinder", 6)]
        _ = try await client.generateImage(ImageGenerationRequest(
            prompt: "shot", provider: .onDevice, aspectRatio: "16:9", referenceImages: refs,
            brief: VisualBrief(purpose: .shot, subject: "Mara hands Rez the camera")))
        let spec = try XCTUnwrap(scripted.requests.first)
        XCTAssertEqual(spec.referenceLabels, ["location:Voss House", "character:Mara Voss", "character:Rez", "prop:Okafor Rangefinder"],
                       "people and the prop; costume sheets never join a shot composition")
        XCTAssertEqual(spec.references.map { $0.first! }, [1, 2, 4, 6])

        // A costume sheet IS the reference when the purpose is the costume itself.
        scripted.clearRequests()
        _ = try await client.generateImage(ImageGenerationRequest(
            prompt: "costume", provider: .onDevice, aspectRatio: "1:1",
            referenceImages: [ref("character:Mara Voss", 2), ref("costume:Mara Voss:Estate Grays", 3)],
            brief: VisualBrief(purpose: .costume, subject: "Mara in Estate Grays")))
        XCTAssertEqual(try XCTUnwrap(scripted.requests.first).referenceLabels, ["character:Mara Voss", "costume:Mara Voss:Estate Grays"])
    }

    func testContinuityEditsOfInkDrawingsKeepTheInkLock() {
        let inked = StoryboardPromptStyler.prompt(subject: "Noor", purpose: .character, style: .sketch,
                                                  referenceCount: 1, referenceIsMonochrome: true)
        XCTAssertTrue(inked.contains("stays monochrome"), inked)
        XCTAssertFalse(inked.contains("ink sketch on white paper, one frame"), "the look lead still yields to the reference")
        let photo = StoryboardPromptStyler.prompt(subject: "Noor", purpose: .character, style: .sketch,
                                                  referenceCount: 1, referenceIsMonochrome: false)
        XCTAssertFalse(photo.contains("stays monochrome"), "a photo reference must stay a photo")
        let fresh = StoryboardPromptStyler.prompt(subject: "Noor", purpose: .character, style: .sketch, referenceIsMonochrome: true)
        XCTAssertFalse(fresh.contains("stays monochrome"), "no reference, no continuity lock — the look tail already says it")
    }

    func testBriefLessPromptsGetTheirSurfacePurpose() {
        XCTAssertEqual(StoryboardSubjects.inferredPurpose(fromPrompt: "Cinematic film still, professional cinematography, establishing shot, set in the kitchen"), .scene)
        XCTAssertEqual(StoryboardSubjects.inferredPurpose(fromPrompt: "Cinematic film still, professional cinematography. Close-up shot. Low angle"), .shot)
        XCTAssertEqual(StoryboardSubjects.inferredPurpose(fromPrompt: "Lighthouse kitchen, warm lamplight, professional film production design, photorealistic"), .location)
        XCTAssertEqual(StoryboardSubjects.inferredPurpose(fromPrompt: "photorealistic, female character, age 58\n\nFront-facing neutral studio reference portrait, head and shoulders, even lighting."), .character)
        XCTAssertEqual(StoryboardSubjects.inferredPurpose(fromPrompt: "female character, wearing Watch Oilskins, costume design reference, full body shot"), .costume)
        XCTAssertEqual(StoryboardSubjects.inferredPurpose(fromPrompt: "Edit this scene preview with the following changes:\n1. x"), .edit)
        XCTAssertEqual(StoryboardSubjects.inferredPurpose(fromPrompt: "Cinematic mood-board reference image: rain on glass"), .moodboard)
    }

    func testSlugLinesAndNarrativeCapsBecomePlainDescription() {
        XCTAssertEqual(StoryboardSubjects.humanizeSlugLines("INT. BELLHAVEN ESTATE HOUSE - PARLOR - DAY"),
                       "inside the Bellhaven Estate House, Parlor, Day")
        XCTAssertEqual(StoryboardSubjects.humanizeSlugLines("EXT. VOSS HOUSE PORCH - DUSK"),
                       "outside the Voss House Porch, Dusk")
        XCTAssertEqual(StoryboardSubjects.humanizeSlugLines("Mara buys the camera"), "Mara buys the camera",
                       "ordinary prose is untouched")
        XCTAssertTrue(StoryboardSubjects.plainSubject(from: "Cinematic film still, set in INT. BELLHAVEN ESTATE HOUSE - PARLOR - DAY, Mara buys the camera")
                        .contains("inside the Bellhaven Estate House, Parlor, Day"))
        let clause = try! XCTUnwrap(StoryboardPromptStyler.labelledReferenceClause(["location:Voss House", "character:Mara Voss"]))
        XCTAssertTrue(clause.hasPrefix("These pictures are only for likeness. Draw one new picture"), clause)
        XCTAssertTrue(clause.contains("single wordless frame"), clause)
    }

    func testRetiringTheReplacedModelRemovesOnlyItsWeightsAndMarker() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dc-retire-\(UUID().uuidString)")
        let engine = LocalImageEngine(storageRoot: root)
        let retired = root.appendingPathComponent("models/filipstrand/Z-Image-Turbo-mflux-4bit", isDirectory: true)
        let current = root.appendingPathComponent("models/Runpod/FLUX.2-klein-4B-mflux-4bit", isDirectory: true)
        try FileManager.default.createDirectory(at: retired, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        try Data([1]).write(to: retired.appendingPathComponent("w.safetensors"))
        try Data().write(to: root.appendingPathComponent(".ready-filipstrand_Z-Image-Turbo-mflux-4bit"))
        engine.retireReplacedModels()
        XCTAssertFalse(FileManager.default.fileExists(atPath: retired.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".ready-filipstrand_Z-Image-Turbo-mflux-4bit").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("models/filipstrand").path), "empty org folder goes too")
        XCTAssertTrue(FileManager.default.fileExists(atPath: current.path), "the current model is untouched")
    }

    #if arch(arm64)
    func testKleinScheduleMatchesTheReferenceFor512Square() {
        // mflux FlowMatchEulerDiscrete, empirical μ, 1,024 image tokens, 4 steps.
        let sigmas = KleinCore.schedule(imageTokens: 1024, steps: 4)
        let reference: [Float] = [1.0, 0.9580853581428528, 0.8839818239212036, 0.7174965739250183, 0.0]
        XCTAssertEqual(sigmas.count, reference.count)
        for (a, b) in zip(sigmas, reference) { XCTAssertEqual(a, b, accuracy: 1e-5) }
    }

    #endif

    func testVisualStylePreferenceDefaultsToSketchAndDegradesUnknownValues() {
        let suite = "dc-visual-style-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let selection = AIProviderSelection(defaults: defaults)
        XCTAssertEqual(selection.visualStyle, .sketch)
        selection.visualStyle = .comic
        XCTAssertEqual(selection.visualStyle, .comic)
        XCTAssertEqual(defaults.string(forKey: AIProviderSelection.visualStyleKey), "comic")
        defaults.set("neon-hologram", forKey: AIProviderSelection.visualStyleKey)
        XCTAssertEqual(selection.visualStyle, .sketch, "unknown stored looks degrade to Sketch")
    }

    func testCharacterSubjectStatesAgeOrAdultAndWhatTheyWear() {
        var mara = Character(name: "Mara", about: "A photojournalist, guarded and quick.", gender: "female")
        mara.age = 34
        mara.build = "Slim"
        mara.hairColor = "Dark"
        mara.hairLength = "Medium"
        mara.distinguishingFeatures = "small scar through her left eyebrow"
        mara.costume = "worn leather jacket over a grey sweater"
        mara.occupation = "Photojournalist"
        let subject = StoryboardSubjects.subject(for: mara)
        XCTAssertTrue(subject.hasPrefix("Mara: 34-year-old female"), subject)
        XCTAssertTrue(subject.contains("slim build"), subject)
        XCTAssertTrue(subject.contains("dark medium straight hair"), subject)
        XCTAssertTrue(subject.contains("wearing worn leather jacket"), subject)
        XCTAssertTrue(subject.contains("a photojournalist"), subject)
        XCTAssertTrue(subject.contains("guarded and quick"), subject)

        var unknown = Character(name: "Stranger")
        unknown.age = 0
        XCTAssertTrue(StoryboardSubjects.subject(for: unknown).hasPrefix("Stranger: adult"),
                      "unspecified people are drawn as adults, not mannequins")
    }

    func testCostumeSubjectCarriesGarmentsPaletteEraAndFabric() {
        var dana = Character(name: "Dana", gender: "female")
        dana.age = 28
        let tweed = CharacterCostume(name: "Estate-sale tweed", description: "Her mother's suit, taken in.",
                                     era: "1950s", styleCategory: "Vintage tailored",
                                     colorPalette: ["olive", "cream", "oxblood"],
                                     garmentTop: "cream blouse", garmentBottom: "oxblood A-line wool skirt",
                                     footwear: "low heels", outerwear: "fitted olive tweed jacket",
                                     primaryFabric: "wool")
        let subject = StoryboardSubjects.subject(for: tweed, wornBy: dana)
        XCTAssertTrue(subject.hasPrefix("Dana, 28-year-old female"), subject)
        for fact in ["wearing Estate-sale tweed", "cream blouse", "oxblood A-line wool skirt",
                     "fitted olive tweed jacket", "low heels", "Her mother's suit", "1950s period",
                     "Vintage tailored style", "colours olive, cream, oxblood", "wool fabric"] {
            XCTAssertTrue(subject.contains(fact), "missing '\(fact)' in \(subject)")
        }
    }

    func testAngleFramingsSpeakDrawingLanguage() {
        XCTAssertTrue(StoryboardSubjects.characterFraming(angle: "profile_left").contains("Exact left profile"))
        XCTAssertTrue(StoryboardSubjects.characterFraming(angle: "back").contains("Back view"))
        XCTAssertEqual(StoryboardSubjects.characterFraming(angle: "base"),
                       StoryboardPromptStyler.defaultFraming(for: .character))
        XCTAssertTrue(StoryboardSubjects.costumeFraming(angle: "back").contains("back view from head to feet"))
        XCTAssertTrue(StoryboardSubjects.costumeFraming(angle: "front").contains("front view"))
        for framing in [StoryboardSubjects.characterFraming(angle: "front"),
                        StoryboardSubjects.costumeFraming(angle: "three_quarter_left")] {
            XCTAssertFalse(framing.lowercased().contains("camera"), framing)
        }
    }

    func testShotSubjectAddsPlaceAndPeopleFromProjectRecords() {
        var scene = Scene(name: "Estate Sale")
        scene.location = "Bellhaven parlor"
        scene.dialogues = [Dialogue(character: "Dana", text: "Take it.")]
        var dana = Character(name: "Dana", gender: "female")
        dana.age = 28
        dana.hairColor = "Black"
        let parlor = Location(name: "Bellhaven parlor",
                              description: "A grand old parlor, belongings tagged for sale.")
        var shot = Shot(shotId: 9)
        shot.description = "Dana hands over the rangefinder"
        let subject = StoryboardSubjects.subject(for: shot, in: scene,
                                                 locations: [parlor], characters: [dana])
        XCTAssertTrue(subject.hasPrefix("Dana hands over the rangefinder"), subject)
        XCTAssertTrue(subject.contains("The place: A grand old parlor"), subject)
        XCTAssertTrue(subject.contains("People in the frame: Dana: 28-year-old female"), subject)
        XCTAssertTrue(subject.contains("black medium straight hair"), subject)
        XCTAssertFalse(subject.contains(".."), subject)
    }
}


// MARK: - Cloud providers are untouched by the on-device work (owner rule)

/// The Gemini/Imagen path must receive exactly what it received before
/// the local engine existed: the same prompt (positions and all), the
/// same references, the same fields — no matter which on-device-only
/// hints (brief, edit regions) ride on the request.
final class CloudImageRequestUnchangedTests: XCTestCase {

    private func canonical(_ body: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    func testOnDeviceHintsNeverReachTheCloudBody() throws {
        let annotationPrompt = "Edit this scene preview with the following changes:\n1. At (43%, 15%): remove the speech bubble that says KEEP\nKeep all other areas unchanged.\n\nOriginal prompt: Cinematic film still, porch at dusk"
        let plain = ImageGenerationRequest(
            prompt: annotationPrompt, provider: .google, aspectRatio: "16:9",
            referenceImageBase64: "QUJD", referenceMimeType: "image/png")
        let hinted = ImageGenerationRequest(
            prompt: annotationPrompt, provider: .google, aspectRatio: "16:9",
            referenceImageBase64: "QUJD", referenceMimeType: "image/png",
            brief: VisualBrief(purpose: .edit, subject: "1. remove the speech bubble"),
            editRegions: [EditRegion(x: 0.43, y: 0.15)])
        let a = try canonical(AIServiceClient.cloudImageBody(for: plain, preferredModel: nil))
        let b = try canonical(AIServiceClient.cloudImageBody(for: hinted, preferredModel: nil))
        XCTAssertEqual(a, b, "brief/editRegions are on-device hints only")
        XCTAssertTrue(a.contains("At (43%, 15%)"), "cloud keeps the positions in the prompt text")
        XCTAssertFalse(a.contains("brief")); XCTAssertFalse(a.contains("edit_regions")); XCTAssertFalse(a.contains("editRegions"))
        let body = AIServiceClient.cloudImageBody(for: hinted, preferredModel: nil)
        XCTAssertEqual(Set(body.keys), ["prompt", "provider", "aspect_ratio", "n", "reference_image_base64", "reference_mime_type"])
        XCTAssertEqual(body["provider"] as? String, "google")
        XCTAssertEqual(body["n"] as? Int, 1)
    }

    func testLabelledReferencesAndModelStillSerialiseAsBefore() {
        let request = ImageGenerationRequest(
            prompt: "p", provider: .googleImagen, model: "imagen-4", aspectRatio: "1:1", numberOfImages: 2,
            referenceImages: [ReferenceImage(base64: "QQ==", mimeType: "image/jpeg", label: "character")],
            brief: VisualBrief(purpose: .character, subject: "x"))
        let body = AIServiceClient.cloudImageBody(for: request, preferredModel: "ignored-when-call-site-sets-model")
        XCTAssertEqual(body["model"] as? String, "imagen-4")
        XCTAssertEqual(body["n"] as? Int, 2)
        let refs = body["reference_images"] as? [[String: String]]
        XCTAssertEqual(refs, [["base64": "QQ==", "mime_type": "image/jpeg", "label": "character"]])
        XCTAssertNil(body["reference_image_base64"], "labelled set wins over the single field, as before")
        let preferred = AIServiceClient.cloudImageBody(for: ImageGenerationRequest(prompt: "p", provider: .google), preferredModel: "gemini-pref")
        XCTAssertEqual(preferred["model"] as? String, "gemini-pref")
        let none = AIServiceClient.cloudImageBody(for: ImageGenerationRequest(prompt: "p", provider: .google), preferredModel: nil)
        XCTAssertNil(none["model"], "server default = field omitted")
    }
}


// MARK: - Visual brief writer (prose → what the camera sees)

final class VisualBriefWriterTests: XCTestCase {

    private let actionLine = "Mara buys Henry Okafor's 1950s rangefinder at his estate sale; his daughter Dana lets it go for almost nothing, with a warning she half-swallows. Setting: Estate of Henry Okafor, inside the Bellhaven Estate House, Parlor, Day"

    override func tearDown() {
        VisualBriefWriter.rewrite = { _ in throw StoryboardEngineError.generationFailed("no writer in tests") }
        super.tearDown()
    }

    func testShortSubjectsAreAlreadyVisualAndNeverSentOut() async {
        VisualBriefWriter.rewrite = { _ in XCTFail("must not be called"); return "" }
        let out = await VisualBriefWriter.visualDescription(of: "A lighthouse on a cliff at dusk")
        XCTAssertEqual(out, "A lighthouse on a cliff at dusk")
    }

    func testUsableReplyReplacesTheActionLine() async {
        VisualBriefWriter.rewrite = { _ in
            "What the frame shows: Mara, in a grey coat, holds a 1950s rangefinder camera over a table of tagged belongings in a sunlit parlor; Dana stands close, arms crossed, her mouth tight and eyes hesitant."
        }
        let out = await VisualBriefWriter.visualDescription(of: actionLine)
        XCTAssertTrue(out.hasPrefix("Mara, in a grey coat, holds"), out)
        XCTAssertFalse(out.contains("half-swallows"))
        XCTAssertTrue(out.hasSuffix("Setting: Estate of Henry Okafor, inside the Bellhaven Estate House, Parlor, Day."),
                      "factual lines survive the rewrite: \(out)")
        let withPeople = actionLine + ". People in the frame: Mara Voss: adult female, wearing Estate Grays (grey wool coat)"
        VisualBriefWriter.rewrite = { _ in "Mara holds the camera." }
        let out2 = await VisualBriefWriter.visualDescription(of: withPeople)
        XCTAssertTrue(out2.contains("People in the frame: Mara Voss: adult female, wearing Estate Grays"), out2)
    }

    func testJunkOrFailureFallsBackToTheOriginal() async {
        VisualBriefWriter.rewrite = { _ in "I'm sorry, I can't help with that." }
        var out = await VisualBriefWriter.visualDescription(of: actionLine)
        XCTAssertEqual(out, actionLine)
        VisualBriefWriter.rewrite = { _ in "\"Take it,\" Dana says." }
        out = await VisualBriefWriter.visualDescription(of: actionLine)
        XCTAssertEqual(out, actionLine, "quoted speech is exactly what we are removing")
        VisualBriefWriter.rewrite = { _ in throw StoryboardEngineError.generationFailed("offline") }
        out = await VisualBriefWriter.visualDescription(of: actionLine)
        XCTAssertEqual(out, actionLine)
        XCTAssertNil(VisualBriefWriter.accepted("- a list\n- of things"))
        XCTAssertNil(VisualBriefWriter.accepted("too short"))
    }

    func testEngineRewritesStoryPurposesOnlyBeforeStyling() async throws {
        #if arch(arm64)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dc-writer-\(UUID().uuidString)")
        let engine = LocalImageEngine(storageRoot: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent(".ready-\(LocalImageEngine.model.id.replacingOccurrences(of: "/", with: "_"))"))
        let core = RecordingImageCore()
        let previous = LocalImageEngine.core
        LocalImageEngine.core = core
        defer { LocalImageEngine.core = previous }
        VisualBriefWriter.rewrite = { _ in "Mara holds the camera in the parlor while Dana watches with a guarded face." }

        _ = try await engine.generateFrame(.init(subject: actionLine, purpose: .shot))
        XCTAssertTrue(try XCTUnwrap(core.calls.last).prompt.contains("Mara holds the camera in the parlor"))
        XCTAssertFalse(try XCTUnwrap(core.calls.last).prompt.contains("half-swallows"))

        _ = try await engine.generateFrame(.init(subject: actionLine, purpose: .costume))
        XCTAssertTrue(try XCTUnwrap(core.calls.last).prompt.contains("half-swallows"),
                      "continuity purposes keep the caller's exact words")
        #endif
    }
}

/// Annotation-edit plumbing on-device (DC-0071 architecture review): the
/// picture being edited must be the FIRST reference the core sees — the
/// core inpaints `sources[0]` — no matter how the surface labelled it or
/// what else it sent along.
final class AnnotationEditReferenceOrderTests: XCTestCase {
    func testThePictureBeingEditedStaysFirstAheadOfSceneReferences() {
        let edited = Data("edited-picture".utf8).base64EncodedString()
        let plate = Data("plate".utf8).base64EncodedString()
        let face = Data("face".utf8).base64EncodedString()
        // The shot-preview surface: current picture first, then the scene set.
        let request = ImageGenerationRequest(
            prompt: "Edit this shot preview with the following changes:\n1. At (40%, 55%): remove the bubble\nKeep all other areas unchanged.",
            provider: .onDevice,
            referenceImages: [ReferenceImage(base64: edited, label: "Current shot preview to edit"),
                              ReferenceImage(base64: plate, label: "location:Lighthouse Gallery"),
                              ReferenceImage(base64: face, label: "character:Noor")],
            brief: VisualBrief(purpose: .edit, subject: "1. remove the bubble"),
            editRegions: [EditRegion(x: 0.4, y: 0.55)])
        let (pictures, _) = AIServiceClient.onDeviceReferences(for: request)
        XCTAssertEqual(pictures.first, Data("edited-picture".utf8),
                       "an edit repaints the picture being edited, not the location plate")
    }
}
