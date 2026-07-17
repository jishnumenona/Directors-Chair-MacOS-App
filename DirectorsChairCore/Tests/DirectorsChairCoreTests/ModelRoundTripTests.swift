// DirectorsChairCore/Tests/DirectorsChairCoreTests/ModelRoundTripTests.swift
//
// Exhaustive JSON encode -> decode round-trip tests for ALL model types.
// Validates: snake_case coding keys, optional property survival, array/collection
// round-trips, UUID stability, Date precision, and backward compatibility
// (decoding JSON that omits optional fields added in later versions).

import XCTest
@testable import DirectorsChairCore

final class ModelRoundTripTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    // MARK: - Helpers

    /// Encode then decode, returning the decoded value.
    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let data = try encoder.encode(value)
        return try decoder.decode(T.self, from: data)
    }

    /// Decode raw JSON string into the given type.
    private func decodeJSON<T: Codable>(_ json: String) throws -> T {
        let data = json.data(using: .utf8)!
        return try decoder.decode(T.self, from: data)
    }

    // =========================================================================
    // MARK: - Dialogue
    // =========================================================================

    func testDialogueRoundTrip() throws {
        let original = Dialogue(
            uuid: "dlg-001",
            character: "HAMLET",
            text: "To be or not to be, that is the question.",
            tags: ["contemplative", "soliloquy"],
            costumes: ["black doublet"],
            effects: ["spotlight"],
            chronologyNumber: 5,
            globalChronologyNumber: 42,
            audioFilePath: "/audio/hamlet_soliloquy.wav",
            manualDuration: 12.5,
            manualStartTime: 30.0
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.uuid, "dlg-001")
        XCTAssertEqual(decoded.id, "dlg-001")
        XCTAssertEqual(decoded.character, "HAMLET")
        XCTAssertEqual(decoded.text, "To be or not to be, that is the question.")
        XCTAssertEqual(decoded.tags, ["contemplative", "soliloquy"])
        XCTAssertEqual(decoded.costumes, ["black doublet"])
        XCTAssertEqual(decoded.effects, ["spotlight"])
        XCTAssertEqual(decoded.chronologyNumber, 5)
        XCTAssertEqual(decoded.globalChronologyNumber, 42)
        XCTAssertEqual(decoded.audioFilePath, "/audio/hamlet_soliloquy.wav")
        XCTAssertEqual(decoded.manualDuration, 12.5)
        XCTAssertEqual(decoded.manualStartTime, 30.0)
    }

    func testDialogueRoundTripNilOptionals() throws {
        let original = Dialogue(character: "OPHELIA", text: "Good my lord.")
        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.character, "OPHELIA")
        XCTAssertEqual(decoded.text, "Good my lord.")
        XCTAssertNil(decoded.audioFilePath)
        XCTAssertNil(decoded.manualDuration)
        XCTAssertNil(decoded.manualStartTime)
        XCTAssertTrue(decoded.tags.isEmpty)
    }

    func testDialogueSnakeCaseCodingKeys() throws {
        let original = Dialogue(
            character: "BOB",
            text: "Hi",
            chronologyNumber: 1,
            globalChronologyNumber: 2,
            audioFilePath: "/a.wav",
            manualDuration: 3.0,
            manualStartTime: 4.0
        )
        let data = try encoder.encode(original)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"chronology_number\""))
        XCTAssertTrue(json.contains("\"global_chronology_number\""))
        XCTAssertTrue(json.contains("\"audio_file_path\""))
        XCTAssertTrue(json.contains("\"manual_duration\""))
        XCTAssertTrue(json.contains("\"manual_start_time\""))
    }

    func testDialogueBackwardCompatibility() throws {
        // Minimal JSON missing all optional fields
        let json = """
        {"uuid":"d1","character":"EVE","text":"Hello"}
        """
        let decoded: Dialogue = try decodeJSON(json)
        XCTAssertEqual(decoded.uuid, "d1")
        XCTAssertEqual(decoded.character, "EVE")
        XCTAssertEqual(decoded.text, "Hello")
        XCTAssertEqual(decoded.chronologyNumber, 0)
        XCTAssertTrue(decoded.tags.isEmpty)
        XCTAssertNil(decoded.audioFilePath)
    }

    // =========================================================================
    // MARK: - Action
    // =========================================================================

    func testActionRoundTrip() throws {
        let original = Action(
            uuid: "act-001",
            description: "John slams the door.",
            tags: ["angry", "loud"],
            costumes: ["leather jacket"],
            effects: ["wind gust"],
            color: "#FF0000",
            textColor: "#FFFFFF",
            chronologyNumber: 3,
            globalChronologyNumber: 10,
            characters: ["JOHN", "MARY"],
            parentDialogueId: "dlg-parent-123",
            manualStartTime: 15.0
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.uuid, "act-001")
        XCTAssertEqual(decoded.id, "act-001")
        XCTAssertEqual(decoded.description, "John slams the door.")
        XCTAssertEqual(decoded.tags, ["angry", "loud"])
        XCTAssertEqual(decoded.costumes, ["leather jacket"])
        XCTAssertEqual(decoded.effects, ["wind gust"])
        XCTAssertEqual(decoded.color, "#FF0000")
        XCTAssertEqual(decoded.textColor, "#FFFFFF")
        XCTAssertEqual(decoded.chronologyNumber, 3)
        XCTAssertEqual(decoded.globalChronologyNumber, 10)
        XCTAssertEqual(decoded.characters, ["JOHN", "MARY"])
        XCTAssertEqual(decoded.parentDialogueId, "dlg-parent-123")
        XCTAssertEqual(decoded.manualStartTime, 15.0)
    }

    func testActionBackwardCompatibility() throws {
        let json = """
        {"description":"He walks away."}
        """
        let decoded: Action = try decodeJSON(json)
        XCTAssertEqual(decoded.description, "He walks away.")
        XCTAssertFalse(decoded.uuid.isEmpty)
        XCTAssertEqual(decoded.chronologyNumber, 0)
        XCTAssertNil(decoded.parentDialogueId)
    }

    // =========================================================================
    // MARK: - Narration
    // =========================================================================

    func testNarrationRoundTrip() throws {
        let original = Narration(
            uuid: "nar-001",
            text: "The sun set over the hills.",
            tags: ["poetic"],
            costumes: [],
            effects: [],
            color: "#333333",
            textColor: "#EEEEEE",
            chronologyNumber: 1,
            globalChronologyNumber: 7,
            characters: ["NARRATOR"],
            parentDialogueId: "dlg-xyz",
            manualStartTime: 5.0
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.uuid, "nar-001")
        XCTAssertEqual(decoded.text, "The sun set over the hills.")
        XCTAssertEqual(decoded.tags, ["poetic"])
        XCTAssertEqual(decoded.color, "#333333")
        XCTAssertEqual(decoded.textColor, "#EEEEEE")
        XCTAssertEqual(decoded.characters, ["NARRATOR"])
        XCTAssertEqual(decoded.parentDialogueId, "dlg-xyz")
        XCTAssertEqual(decoded.manualStartTime, 5.0)
    }

    func testNarrationBackwardCompatibility() throws {
        let json = """
        {"text":"Once upon a time."}
        """
        let decoded: Narration = try decodeJSON(json)
        XCTAssertEqual(decoded.text, "Once upon a time.")
        XCTAssertFalse(decoded.uuid.isEmpty)
        XCTAssertNil(decoded.parentDialogueId)
    }

    // =========================================================================
    // MARK: - Note
    // =========================================================================

    func testNoteRoundTrip() throws {
        let original = Note(
            uuid: "note-001",
            content: "Remember to add fog machine.",
            noteType: "text",
            chronologyNumber: 2,
            title: "FX Reminder",
            metadata: ["priority": "high", "department": "VFX"],
            parentDialogueId: "dlg-parent-456"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.uuid, "note-001")
        XCTAssertEqual(decoded.id, "note-001")
        XCTAssertEqual(decoded.content, "Remember to add fog machine.")
        XCTAssertEqual(decoded.noteType, "text")
        XCTAssertEqual(decoded.chronologyNumber, 2)
        XCTAssertEqual(decoded.title, "FX Reminder")
        XCTAssertEqual(decoded.metadata, ["priority": "high", "department": "VFX"])
        XCTAssertEqual(decoded.parentDialogueId, "dlg-parent-456")
    }

    func testNoteBackwardCompatibility() throws {
        let json = """
        {}
        """
        let decoded: Note = try decodeJSON(json)
        XCTAssertFalse(decoded.uuid.isEmpty)
        XCTAssertEqual(decoded.content, "")
        XCTAssertEqual(decoded.noteType, "text")
        XCTAssertTrue(decoded.metadata.isEmpty)
        XCTAssertNil(decoded.parentDialogueId)
    }

    // =========================================================================
    // MARK: - SoundNote
    // =========================================================================

    func testSoundNoteRoundTrip() throws {
        let original = SoundNote(
            uuid: "snd-001",
            description: "Rain on rooftop",
            soundType: "ambient",
            chronologyNumber: 4,
            audioFilePath: "/sfx/rain.wav",
            volume: 80,
            loop: true,
            fadeInDuration: 2.5,
            fadeOutDuration: 3.0,
            startTime: 10.0,
            endTime: 60.0,
            tags: ["weather", "mood"],
            referenceUrl: "https://example.com/rain",
            timestampStart: "00:10",
            timestampEnd: "01:00",
            parentDialogueId: "dlg-789",
            manualStartTime: 10.0
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.uuid, "snd-001")
        XCTAssertEqual(decoded.description, "Rain on rooftop")
        XCTAssertEqual(decoded.soundType, "ambient")
        XCTAssertEqual(decoded.chronologyNumber, 4)
        XCTAssertEqual(decoded.audioFilePath, "/sfx/rain.wav")
        XCTAssertEqual(decoded.volume, 80)
        XCTAssertTrue(decoded.loop)
        XCTAssertEqual(decoded.fadeInDuration, 2.5)
        XCTAssertEqual(decoded.fadeOutDuration, 3.0)
        XCTAssertEqual(decoded.startTime, 10.0)
        XCTAssertEqual(decoded.endTime, 60.0)
        XCTAssertEqual(decoded.tags, ["weather", "mood"])
        XCTAssertEqual(decoded.referenceUrl, "https://example.com/rain")
        XCTAssertEqual(decoded.timestampStart, "00:10")
        XCTAssertEqual(decoded.timestampEnd, "01:00")
        XCTAssertEqual(decoded.parentDialogueId, "dlg-789")
        XCTAssertEqual(decoded.manualStartTime, 10.0)
    }

    func testSoundNoteBackwardCompatibility() throws {
        let json = """
        {}
        """
        let decoded: SoundNote = try decodeJSON(json)
        XCTAssertFalse(decoded.uuid.isEmpty)
        XCTAssertEqual(decoded.description, "")
        XCTAssertEqual(decoded.soundType, "ambient")
        XCTAssertEqual(decoded.volume, 100)
        XCTAssertFalse(decoded.loop)
        XCTAssertEqual(decoded.fadeInDuration, 0.0)
        XCTAssertEqual(decoded.fadeOutDuration, 0.0)
        XCTAssertNil(decoded.audioFilePath)
        XCTAssertNil(decoded.parentDialogueId)
    }

    // =========================================================================
    // MARK: - TakeRating
    // =========================================================================

    func testTakeRatingRoundTrip() throws {
        for rating in TakeRating.allCases {
            let data = try encoder.encode(rating)
            let decoded = try decoder.decode(TakeRating.self, from: data)
            XCTAssertEqual(decoded, rating)
        }
    }

    // =========================================================================
    // MARK: - Take
    // =========================================================================

    func testTakeRoundTripFullyPopulated() throws {
        let now = Date()
        let original = Take(
            id: "take-001",
            takeNumber: 3,
            notes: "Good performance, slight camera shake",
            rating: .circle,
            tags: ["best", "keeper"],
            startTimestamp: now,
            endTimestamp: now.addingTimeInterval(45),
            capturedVideoPath: "/takes/shot1_take3.mov",
            cameraSourceFileName: "A001C003.mov",
            thumbnailPath: "/thumbs/take3.jpg",
            durationSeconds: 45.0,
            cameraClipName: "C0575",
            cameraResolution: "4K",
            cameraFrameRate: "23.98",
            cameraISO: "800EI",
            cameraAperture: "4.3E/H",
            cameraWhiteBalance: "3500K",
            cameraTimecode: "02:44:52:01",
            cameraLUT: "LUT Off",
            cameraFocusMode: "MF",
            externalAudioFileName: "audio_take3.wav",
            useAudioFromVideo: false,
            isAudioVideoSynced: true,
            actionTimestamp: 2.5,
            cutTimestamp: 40.0,
            detectedActionWord: "action",
            detectedCutWord: "and cut",
            actionConfidence: 0.95,
            cutConfidence: 0.88,
            syncTonePlayedAt: now.addingTimeInterval(-5),
            syncToneRecordingOffset: 1.2,
            syncToneTimestamps: [0.5, 1.0, 1.5],
            syncToneConfidences: [0.9, 0.85, 0.92],
            syncOffset: 0.05
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "take-001")
        XCTAssertEqual(decoded.takeNumber, 3)
        XCTAssertEqual(decoded.notes, "Good performance, slight camera shake")
        XCTAssertEqual(decoded.rating, .circle)
        XCTAssertEqual(decoded.tags, ["best", "keeper"])
        XCTAssertNotNil(decoded.startTimestamp)
        XCTAssertNotNil(decoded.endTimestamp)
        XCTAssertEqual(decoded.capturedVideoPath, "/takes/shot1_take3.mov")
        XCTAssertEqual(decoded.cameraSourceFileName, "A001C003.mov")
        XCTAssertEqual(decoded.thumbnailPath, "/thumbs/take3.jpg")
        XCTAssertEqual(decoded.durationSeconds, 45.0)
        XCTAssertEqual(decoded.cameraClipName, "C0575")
        XCTAssertEqual(decoded.cameraResolution, "4K")
        XCTAssertEqual(decoded.cameraFrameRate, "23.98")
        XCTAssertEqual(decoded.cameraISO, "800EI")
        XCTAssertEqual(decoded.cameraAperture, "4.3E/H")
        XCTAssertEqual(decoded.cameraWhiteBalance, "3500K")
        XCTAssertEqual(decoded.cameraTimecode, "02:44:52:01")
        XCTAssertEqual(decoded.cameraLUT, "LUT Off")
        XCTAssertEqual(decoded.cameraFocusMode, "MF")
        XCTAssertEqual(decoded.externalAudioFileName, "audio_take3.wav")
        XCTAssertFalse(decoded.useAudioFromVideo)
        XCTAssertEqual(decoded.isAudioVideoSynced, true)
        XCTAssertEqual(decoded.actionTimestamp, 2.5)
        XCTAssertEqual(decoded.cutTimestamp, 40.0)
        XCTAssertEqual(decoded.detectedActionWord, "action")
        XCTAssertEqual(decoded.detectedCutWord, "and cut")
        XCTAssertEqual(decoded.actionConfidence, 0.95)
        XCTAssertEqual(decoded.cutConfidence, 0.88)
        XCTAssertNotNil(decoded.syncTonePlayedAt)
        XCTAssertEqual(decoded.syncToneRecordingOffset, 1.2)
        XCTAssertEqual(decoded.syncToneTimestamps, [0.5, 1.0, 1.5])
        XCTAssertEqual(decoded.syncToneConfidences, [0.9, 0.85, 0.92])
        XCTAssertEqual(decoded.syncOffset, 0.05)
    }

    func testTakeSnakeCaseCodingKeys() throws {
        let take = Take(
            id: "t1",
            takeNumber: 1,
            cameraClipName: "C001",
            useAudioFromVideo: true
        )
        let data = try encoder.encode(take)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"take_number\""))
        XCTAssertTrue(json.contains("\"camera_clip_name\""))
        XCTAssertTrue(json.contains("\"use_audio_from_video\""))
    }

    func testTakeBackwardCompatibility() throws {
        let json = """
        {"id":"t1"}
        """
        let decoded: Take = try decodeJSON(json)
        XCTAssertEqual(decoded.id, "t1")
        XCTAssertEqual(decoded.takeNumber, 1)
        XCTAssertEqual(decoded.rating, .none)
        XCTAssertTrue(decoded.tags.isEmpty)
        XCTAssertNil(decoded.startTimestamp)
        XCTAssertNil(decoded.cameraClipName)
        XCTAssertFalse(decoded.useAudioFromVideo)
    }

    // =========================================================================
    // MARK: - Shot (with nested models)
    // =========================================================================

    func testShotRoundTripFullyPopulated() throws {
        let refMedia = ReferenceMedia(
            id: "ref-001",
            type: .image,
            path: "refs/shot_ref.jpg",
            caption: "Mood reference",
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        let annotation = KeyframeAnnotation(
            id: "ann-001",
            normalizedX: 0.3,
            normalizedY: 0.7,
            text: "Move camera left",
            number: 1
        )

        let keyframe = VideoKeyframe(
            id: "kf-001",
            position: 0.0,
            imagePath: "keyframes/start.jpg",
            label: "Start",
            timestamp: 0.0,
            annotations: [annotation],
            customPrompt: "A hand-tuned opening frame prompt"
        )

        let take = Take(id: "take-in-shot", takeNumber: 1, rating: .alt)

        let original = Shot(
            uuid: "shot-001",
            shotId: 42,
            itemChronology: 5,
            description: "Wide establishing shot of the city",
            status: "Ready",
            cameraAngle: "High",
            lensMm: 24,
            aperture: "f/5.6",
            shotType: "EWS",
            movement: "Crane Down",
            duration: 8.0,
            styleOverride: "style-noir",
            referenceMedia: [refMedia],
            previewImage: "previews/shot42.png",
            linkedDialogueIds: ["dlg-001", "dlg-002"],
            linkedActionIds: ["act-001"],
            linkedNarrationIds: ["nar-001"],
            timelinePosition: 120.0,
            takes: [take],
            videoPath: "videos/shot42.mp4",
            videoKeyframes: [keyframe],
            videoGenerationJobId: "job-abc",
            videoPrompt: "Cinematic wide shot of downtown",
            videoDuration: 8.0,
            videoProvider: "runway",
            videoQuality: "High",
            videoResolution: "1080p",
            lightingStyle: "Low-key"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.uuid, "shot-001")
        XCTAssertEqual(decoded.id, "shot-001")
        XCTAssertEqual(decoded.shotId, 42)
        XCTAssertEqual(decoded.itemChronology, 5)
        XCTAssertEqual(decoded.description, "Wide establishing shot of the city")
        XCTAssertEqual(decoded.status, "Ready")
        XCTAssertEqual(decoded.cameraAngle, "High")
        XCTAssertEqual(decoded.lensMm, 24)
        XCTAssertEqual(decoded.aperture, "f/5.6")
        XCTAssertEqual(decoded.shotType, "EWS")
        XCTAssertEqual(decoded.movement, "Crane Down")
        XCTAssertEqual(decoded.duration, 8.0)
        XCTAssertEqual(decoded.styleOverride, "style-noir")
        XCTAssertEqual(decoded.referenceMedia.count, 1)
        XCTAssertEqual(decoded.referenceMedia[0].id, "ref-001")
        XCTAssertEqual(decoded.referenceMedia[0].type, .image)
        XCTAssertEqual(decoded.referenceMedia[0].path, "refs/shot_ref.jpg")
        XCTAssertEqual(decoded.referenceMedia[0].caption, "Mood reference")
        XCTAssertEqual(decoded.previewImage, "previews/shot42.png")
        XCTAssertEqual(decoded.linkedDialogueIds, ["dlg-001", "dlg-002"])
        XCTAssertEqual(decoded.linkedActionIds, ["act-001"])
        XCTAssertEqual(decoded.linkedNarrationIds, ["nar-001"])
        XCTAssertEqual(decoded.timelinePosition, 120.0)
        XCTAssertEqual(decoded.takes.count, 1)
        XCTAssertEqual(decoded.takes[0].id, "take-in-shot")
        XCTAssertEqual(decoded.takes[0].rating, .alt)
        XCTAssertEqual(decoded.videoPath, "videos/shot42.mp4")
        XCTAssertEqual(decoded.videoKeyframes?.count, 1)
        XCTAssertEqual(decoded.videoKeyframes?[0].annotations?.count, 1)
        XCTAssertEqual(decoded.videoKeyframes?[0].annotations?[0].text, "Move camera left")
        XCTAssertEqual(decoded.videoKeyframes?[0].customPrompt, "A hand-tuned opening frame prompt")
        XCTAssertEqual(decoded.videoGenerationJobId, "job-abc")
        XCTAssertEqual(decoded.videoPrompt, "Cinematic wide shot of downtown")
        XCTAssertEqual(decoded.videoDuration, 8.0)
        XCTAssertEqual(decoded.videoProvider, "runway")
        XCTAssertEqual(decoded.videoQuality, "High")
        XCTAssertEqual(decoded.videoResolution, "1080p")
        XCTAssertEqual(decoded.lightingStyle, "Low-key")
    }

    func testShotSnakeCaseCodingKeys() throws {
        // Populate optional fields so they appear in the encoded JSON
        let shot = Shot(
            uuid: "s1",
            shotId: 1,
            styleOverride: "test",
            previewImage: "test.jpg",
            linkedDialogueIds: ["d1"],
            timelinePosition: 1.0,
            videoPath: "test.mp4"
        )
        let data = try encoder.encode(shot)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"shot_id\""))
        XCTAssertTrue(json.contains("\"item_chronology\""))
        XCTAssertTrue(json.contains("\"camera_angle\""))
        XCTAssertTrue(json.contains("\"lens_mm\""))
        XCTAssertTrue(json.contains("\"shot_type\""))
        XCTAssertTrue(json.contains("\"style_override\""))
        XCTAssertTrue(json.contains("\"reference_media\""))
        XCTAssertTrue(json.contains("\"preview_image\""))
        XCTAssertTrue(json.contains("\"linked_dialogue_ids\""))
        XCTAssertTrue(json.contains("\"linked_action_ids\""))
        XCTAssertTrue(json.contains("\"linked_narration_ids\""))
        XCTAssertTrue(json.contains("\"timeline_position\""))
        XCTAssertTrue(json.contains("\"video_path\""))
    }

    // =========================================================================
    // MARK: - VideoKeyframe
    // =========================================================================

    func testVideoKeyframeRoundTrip() throws {
        let original = VideoKeyframe(
            id: "kf-001",
            position: 0.5,
            imagePath: "kf/mid.jpg",
            label: "Midpoint",
            timestamp: 4.0,
            annotations: [
                KeyframeAnnotation(id: "a1", normalizedX: 0.1, normalizedY: 0.9, text: "Pan right", number: 1)
            ]
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "kf-001")
        XCTAssertEqual(decoded.position, 0.5)
        XCTAssertEqual(decoded.imagePath, "kf/mid.jpg")
        XCTAssertEqual(decoded.label, "Midpoint")
        XCTAssertEqual(decoded.timestamp, 4.0)
        XCTAssertEqual(decoded.annotations?.count, 1)
        XCTAssertEqual(decoded.annotations?[0].normalizedX, 0.1)
    }

    // =========================================================================
    // MARK: - ReferenceMedia
    // =========================================================================

    func testReferenceMediaRoundTrip() throws {
        let original = ReferenceMedia(
            id: "rm-001",
            type: .video,
            path: "refs/test.mp4",
            caption: "Stunt reference",
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "rm-001")
        XCTAssertEqual(decoded.type, .video)
        XCTAssertEqual(decoded.path, "refs/test.mp4")
        XCTAssertEqual(decoded.caption, "Stunt reference")
    }

    // =========================================================================
    // MARK: - Scene
    // =========================================================================

    func testSceneRoundTripFullyPopulated() throws {
        let dialogue = Dialogue(uuid: "d1", character: "ALICE", text: "Welcome!", chronologyNumber: 0)
        let action = Action(uuid: "a1", description: "Alice enters.", chronologyNumber: 1)
        let narration = Narration(uuid: "n1", text: "The room was silent.", chronologyNumber: 2)
        let note = Note(uuid: "note1", content: "Add rain SFX", chronologyNumber: 3)
        let soundNote = SoundNote(uuid: "sn1", description: "Thunder", soundType: "effects", chronologyNumber: 4)
        let shot = Shot(uuid: "sh1", shotId: 1, description: "Wide shot")
        let locImage = SceneLocationImage(
            id: "loc-img-1",
            sceneId: "scene-001",
            imagePath: "locations/kitchen.jpg",
            locationName: "Kitchen"
        )

        let original = Scene(
            uuid: "scene-001",
            name: "Scene 1 - INT. KITCHEN - DAY",
            description: "Morning scene in the kitchen",
            notes: "Watch continuity on coffee cup",
            dialogues: [dialogue],
            actions: [action],
            narrations: [narration],
            sceneNotes: [note],
            soundNotes: [soundNote],
            shots: [shot],
            locationImages: [locImage],
            locationContext: ["time_of_day": "morning", "mood": "tense"],
            stage: ["layout": "L-shaped kitchen"],
            props: ["coffee cup", "newspaper"],
            location: "Kitchen Set A",
            primaryCharacter: "ALICE",
            productionStatus: "Ready",
            styleOverride: "style-warm",
            sceneOverviewImage: "overviews/scene1.jpg",
            sceneEmotionalAnalysis: ["tension": 0.8, "warmth": 0.3],
            sceneOverviewPrompt: "A tense morning scene",
            sceneOverviewSummary: "Alice confronts her fears over breakfast.",
            timeOfDay: "Golden Hour",
            weather: "Rain",
            costumeAssignments: ["ALICE": "costume-42"]
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.uuid, "scene-001")
        XCTAssertEqual(decoded.id, "scene-001")
        XCTAssertEqual(decoded.name, "Scene 1 - INT. KITCHEN - DAY")
        XCTAssertEqual(decoded.description, "Morning scene in the kitchen")
        XCTAssertEqual(decoded.notes, "Watch continuity on coffee cup")
        XCTAssertEqual(decoded.dialogues.count, 1)
        XCTAssertEqual(decoded.dialogues[0].character, "ALICE")
        XCTAssertEqual(decoded.actions.count, 1)
        XCTAssertEqual(decoded.narrations.count, 1)
        XCTAssertEqual(decoded.sceneNotes.count, 1)
        XCTAssertEqual(decoded.soundNotes.count, 1)
        XCTAssertEqual(decoded.shots.count, 1)
        XCTAssertEqual(decoded.locationImages.count, 1)
        XCTAssertEqual(decoded.locationContext?["time_of_day"], "morning")
        XCTAssertEqual(decoded.stage["layout"], "L-shaped kitchen")
        XCTAssertEqual(decoded.props, ["coffee cup", "newspaper"])
        XCTAssertEqual(decoded.location, "Kitchen Set A")
        XCTAssertEqual(decoded.primaryCharacter, "ALICE")
        XCTAssertEqual(decoded.productionStatus, "Ready")
        XCTAssertEqual(decoded.styleOverride, "style-warm")
        XCTAssertEqual(decoded.sceneOverviewImage, "overviews/scene1.jpg")
        XCTAssertEqual(decoded.sceneEmotionalAnalysis?["tension"], 0.8)
        XCTAssertEqual(decoded.sceneOverviewPrompt, "A tense morning scene")
        XCTAssertEqual(decoded.sceneOverviewSummary, "Alice confronts her fears over breakfast.")
        XCTAssertEqual(decoded.timeOfDay, "Golden Hour")
        XCTAssertEqual(decoded.weather, "Rain")
        XCTAssertEqual(decoded.costumeAssignments?["ALICE"], "costume-42")
    }

    func testFilmStylePresetsHaveStableUniqueIds() {
        let ids = FilmStyle.presets.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Preset ids must be unique")
        XCTAssertTrue(ids.allSatisfy { $0.hasPrefix("preset-") })
        XCTAssertTrue(FilmStyle.presets.allSatisfy { $0.isPreset })
        XCTAssertTrue(FilmStyle.presets.allSatisfy { !$0.aiStylePrompt.isEmpty },
                      "Every preset must carry a usable style prompt")
    }

    func testFilmStyleResolvePrefersProjectStyleOverPreset() {
        let presetId = FilmStyle.presets[0].id
        let userStyle = FilmStyle(id: presetId, name: "My Override")
        XCTAssertEqual(FilmStyle.resolve(id: presetId, in: [userStyle])?.name, "My Override")
        XCTAssertEqual(FilmStyle.resolve(id: presetId, in: [])?.name, FilmStyle.presets[0].name)
        XCTAssertNil(FilmStyle.resolve(id: "nope", in: [userStyle]))
    }

    func testSceneSnakeCaseCodingKeys() throws {
        let scene = Scene(
            uuid: "s1",
            name: "Test",
            sceneNotes: [Note()],
            soundNotes: [SoundNote()],
            primaryCharacter: "ALICE",
            productionStatus: "Planning"
        )
        let data = try encoder.encode(scene)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"scene_notes\""))
        XCTAssertTrue(json.contains("\"sound_notes\""))
        XCTAssertTrue(json.contains("\"location_images\""))
        XCTAssertTrue(json.contains("\"production_status\""))
        XCTAssertTrue(json.contains("\"primary_character\""))
    }

    func testSceneBackwardCompatibility() throws {
        let json = """
        {"name":"Scene 1"}
        """
        let decoded: Scene = try decodeJSON(json)
        XCTAssertEqual(decoded.name, "Scene 1")
        XCTAssertFalse(decoded.uuid.isEmpty)
        XCTAssertTrue(decoded.dialogues.isEmpty)
        XCTAssertTrue(decoded.actions.isEmpty)
        XCTAssertTrue(decoded.shots.isEmpty)
        XCTAssertEqual(decoded.productionStatus, "Planning")
        XCTAssertNil(decoded.location)
        XCTAssertNil(decoded.locationContext)
        XCTAssertNil(decoded.styleOverride)
    }

    // =========================================================================
    // MARK: - Sequence
    // =========================================================================

    func testSequenceRoundTrip() throws {
        let scene = Scene(uuid: "s1", name: "Opening")
        let original = Sequence(
            uuid: "seq-001",
            name: "Act 1",
            description: "The setup",
            scenes: [scene],
            location: "Studio A"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.uuid, "seq-001")
        XCTAssertEqual(decoded.id, "seq-001")
        XCTAssertEqual(decoded.name, "Act 1")
        XCTAssertEqual(decoded.description, "The setup")
        XCTAssertEqual(decoded.scenes.count, 1)
        XCTAssertEqual(decoded.scenes[0].name, "Opening")
        XCTAssertEqual(decoded.location, "Studio A")
    }

    func testSequenceBackwardCompatibility() throws {
        let json = """
        {"name":"Act 2"}
        """
        let decoded: Sequence = try decodeJSON(json)
        XCTAssertEqual(decoded.name, "Act 2")
        XCTAssertFalse(decoded.uuid.isEmpty)
        XCTAssertNil(decoded.description)
        XCTAssertTrue(decoded.scenes.isEmpty)
        XCTAssertNil(decoded.location)
    }

    // =========================================================================
    // MARK: - Character
    // =========================================================================

    func testCharacterRoundTripCoreFields() throws {
        let original = Character(
            characterId: "char-hamlet",
            name: "Hamlet",
            role: "Protagonist",
            color: "#3498db",
            textColor: "#ffffff",
            avatar: "avatars/hamlet.png",
            about: "Prince of Denmark",
            gender: "male",
            voice: "Puck",
            voiceStyle: "brooding and intense",
            heightCm: 180.0,
            weightKg: 75.0,
            build: "Athletic",
            age: 30,
            hairColor: "#2C1810",
            hairStyle: "Medium, Wavy",
            hairLength: "Medium",
            eyeColor: "#654321",
            eyeColorDescription: "Dark Brown",
            eyeShape: "Deep-set",
            skinTone: "#D4A574",
            ethnicity: "Danish",
            distinguishingFeatures: "Scar on left cheek",
            facialStructure: "Angular"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.characterId, "char-hamlet")
        XCTAssertEqual(decoded.id, "char-hamlet")
        XCTAssertEqual(decoded.name, "Hamlet")
        XCTAssertEqual(decoded.role, "Protagonist")
        XCTAssertEqual(decoded.color, "#3498db")
        XCTAssertEqual(decoded.textColor, "#ffffff")
        XCTAssertEqual(decoded.avatar, "avatars/hamlet.png")
        XCTAssertEqual(decoded.about, "Prince of Denmark")
        XCTAssertEqual(decoded.gender, "male")
        XCTAssertEqual(decoded.voice, "Puck")
        XCTAssertEqual(decoded.voiceStyle, "brooding and intense")
        XCTAssertEqual(decoded.heightCm, 180.0)
        XCTAssertEqual(decoded.weightKg, 75.0)
        XCTAssertEqual(decoded.build, "Athletic")
        XCTAssertEqual(decoded.age, 30)
        XCTAssertEqual(decoded.hairColor, "#2C1810")
        XCTAssertEqual(decoded.hairStyle, "Medium, Wavy")
        XCTAssertEqual(decoded.eyeColor, "#654321")
        XCTAssertEqual(decoded.eyeColorDescription, "Dark Brown")
        XCTAssertEqual(decoded.skinTone, "#D4A574")
        XCTAssertEqual(decoded.ethnicity, "Danish")
        XCTAssertEqual(decoded.distinguishingFeatures, "Scar on left cheek")
        XCTAssertEqual(decoded.facialStructure, "Angular")
    }

    func testCharacterRoundTripBiographyAndRelationships() throws {
        let original = Character(
            name: "Ophelia",
            fullName: "Ophelia of Denmark",
            nickname: "Phelia",
            occupation: "Noblewoman",
            affiliation: "Court of Denmark",
            backgroundStory: "Daughter of Polonius",
            primaryGoal: "Win Hamlet's love",
            secondaryGoal: "Please her father",
            hiddenMotivation: "Independence",
            primaryFear: "Abandonment",
            weakness: "Naivety",
            flaw: "Too trusting",
            characterArcNotes: "From innocent to tragic",
            relationships: ["Hamlet": "Love interest", "Polonius": "Father"]
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.fullName, "Ophelia of Denmark")
        XCTAssertEqual(decoded.nickname, "Phelia")
        XCTAssertEqual(decoded.occupation, "Noblewoman")
        XCTAssertEqual(decoded.relationships?["Hamlet"], "Love interest")
        XCTAssertEqual(decoded.relationships?["Polonius"], "Father")
        XCTAssertEqual(decoded.primaryGoal, "Win Hamlet's love")
        XCTAssertEqual(decoded.primaryFear, "Abandonment")
        XCTAssertEqual(decoded.characterArcNotes, "From innocent to tragic")
    }

    func testCharacterTraitsRoundTrip() throws {
        var customTraits = Character.defaultTraits()
        customTraits["confidence"] = 85.0
        customTraits["empathy"] = 92.0
        let original = Character(name: "Alice", traits: customTraits)

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.traits["confidence"], 85.0)
        XCTAssertEqual(decoded.traits["empathy"], 92.0)
        // All 25 default trait keys should survive
        XCTAssertEqual(decoded.traits.count, 25)
    }

    func testCharacterSnakeCaseCodingKeys() throws {
        let char = Character(name: "Test", voiceStyle: "calm", heightCm: 175.0, weightKg: 70.0)
        let data = try encoder.encode(char)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"character_id\""))
        XCTAssertTrue(json.contains("\"text_color\""))
        XCTAssertTrue(json.contains("\"voice_style\""))
        XCTAssertTrue(json.contains("\"height_cm\""))
        XCTAssertTrue(json.contains("\"weight_kg\""))
        XCTAssertTrue(json.contains("\"hair_color\""))
        XCTAssertTrue(json.contains("\"eye_color\""))
        XCTAssertTrue(json.contains("\"skin_tone\""))
        XCTAssertTrue(json.contains("\"facial_structure\""))
    }

    func testCharacterBackwardCompatibility() throws {
        // Minimal JSON: only name required
        let json = """
        {"name":"Mystery Person"}
        """
        let decoded: Character = try decodeJSON(json)
        XCTAssertEqual(decoded.name, "Mystery Person")
        // characterId should be auto-generated from name
        XCTAssertEqual(decoded.characterId, "mystery_person")
        XCTAssertEqual(decoded.role, "Supporting")
        XCTAssertEqual(decoded.gender, "neutral")
        XCTAssertEqual(decoded.age, 30)
        XCTAssertEqual(decoded.build, "Average")
        XCTAssertNil(decoded.voice)
        XCTAssertNil(decoded.relationships)
        XCTAssertEqual(decoded.traits.count, 25)
    }

    // =========================================================================
    // MARK: - Location
    // =========================================================================

    func testLocationRoundTrip() throws {
        let original = Location(
            name: "Central Park",
            description: "Iconic NYC park",
            notes: "Permit required",
            parentLocation: "Manhattan",
            locationType: "outdoor",
            tags: ["nature", "urban"],
            address: "New York, NY 10024",
            gpsCoordinates: "40.7829,-73.9654",
            images: ["img/park1.jpg", "img/park2.jpg"],
            primaryImage: "img/park1.jpg",
            referenceImages: ["ref/park_autumn.jpg"],
            floorPlanData: nil,
            floorPlanImage: nil,
            dimensions: ["width": 800.0, "length": 4000.0],
            styleAttributes: ["mood": "serene"],
            cinematographyDefaults: ["angle": "wide"],
            attributes: ["weather": "overcast"]
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.name, "Central Park")
        XCTAssertEqual(decoded.description, "Iconic NYC park")
        XCTAssertEqual(decoded.parentLocation, "Manhattan")
        XCTAssertEqual(decoded.locationType, "outdoor")
        XCTAssertEqual(decoded.tags, ["nature", "urban"])
        XCTAssertEqual(decoded.address, "New York, NY 10024")
        XCTAssertEqual(decoded.gpsCoordinates, "40.7829,-73.9654")
        XCTAssertEqual(decoded.images.count, 2)
        XCTAssertEqual(decoded.primaryImage, "img/park1.jpg")
        XCTAssertEqual(decoded.dimensions?["width"], 800.0)
        XCTAssertEqual(decoded.styleAttributes["mood"], "serene")
        XCTAssertEqual(decoded.attributes["weather"], "overcast")
    }

    func testLocationBackwardCompatibility() throws {
        let json = """
        {"name":"Beach"}
        """
        let decoded: Location = try decodeJSON(json)
        XCTAssertEqual(decoded.name, "Beach")
        XCTAssertEqual(decoded.locationType, "mixed")
        XCTAssertTrue(decoded.images.isEmpty)
        XCTAssertNil(decoded.parentLocation)
    }

    // =========================================================================
    // MARK: - Costume
    // =========================================================================

    func testCostumeRoundTrip() throws {
        let original = Costume(
            name: "Royal Robe",
            character: "King",
            image: "costumes/robe.jpg",
            notes: "Velvet, deep red"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.name, "Royal Robe")
        XCTAssertEqual(decoded.id, decoded.uuid)  // identity is the stable uuid, not the name (WS2.5)
        XCTAssertEqual(decoded.character, "King")
        XCTAssertEqual(decoded.image, "costumes/robe.jpg")
        XCTAssertEqual(decoded.notes, "Velvet, deep red")
    }

    func testCostumeBackwardCompatibility() throws {
        let json = """
        {"name":"Simple Dress"}
        """
        let decoded: Costume = try decodeJSON(json)
        XCTAssertEqual(decoded.name, "Simple Dress")
        XCTAssertNil(decoded.character)
        XCTAssertNil(decoded.image)
        XCTAssertEqual(decoded.notes, "")
    }

    // =========================================================================
    // MARK: - Lighting
    // =========================================================================

    func testLightingRoundTrip() throws {
        let original = Lighting(
            name: "Main Key",
            type: "Key",
            color: "#ffe0b2",
            intensity: 0.85,
            position: "Front-Left",
            notes: "Use diffusion panel"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.name, "Main Key")
        XCTAssertEqual(decoded.id, decoded.uuid)  // identity is the stable uuid, not the name (WS2.5)
        XCTAssertEqual(decoded.type, "Key")
        XCTAssertEqual(decoded.color, "#ffe0b2")
        XCTAssertEqual(decoded.intensity, 0.85)
        XCTAssertEqual(decoded.position, "Front-Left")
        XCTAssertEqual(decoded.notes, "Use diffusion panel")
    }

    func testLightingBackwardCompatibility() throws {
        let json = """
        {"name":"Fill Light"}
        """
        let decoded: Lighting = try decodeJSON(json)
        XCTAssertEqual(decoded.name, "Fill Light")
        XCTAssertEqual(decoded.type, "Spot")
        XCTAssertEqual(decoded.intensity, 1.0)
    }

    // =========================================================================
    // MARK: - EffectDef
    // =========================================================================

    func testEffectDefRoundTrip() throws {
        let original = EffectDef(
            name: "Fog Machine",
            category: "Atmospheric",
            params: ["density": "high", "color": "white"],
            notes: "Run for 30 seconds before take"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.name, "Fog Machine")
        XCTAssertEqual(decoded.id, decoded.uuid)  // identity is the stable uuid, not the name (WS2.5)
        XCTAssertEqual(decoded.category, "Atmospheric")
        XCTAssertEqual(decoded.params["density"], "high")
        XCTAssertEqual(decoded.params["color"], "white")
        XCTAssertEqual(decoded.notes, "Run for 30 seconds before take")
    }

    func testEffectDefBackwardCompatibility() throws {
        let json = """
        {"name":"Rain Effect"}
        """
        let decoded: EffectDef = try decodeJSON(json)
        XCTAssertEqual(decoded.name, "Rain Effect")
        XCTAssertEqual(decoded.category, "Atmospheric")
        XCTAssertTrue(decoded.params.isEmpty)
    }

    // =========================================================================
    // MARK: - Prop
    // =========================================================================

    func testPropRoundTrip() throws {
        let original = Prop(
            id: "prop-sword",
            name: "Excalibur",
            thumbnail: "props/sword_thumb.jpg",
            description: "Hero prop sword",
            detailedSpecs: "32 inch blade, foam core",
            category: "Weapon",
            tags: ["hero-prop", "period-piece"],
            acquisitionType: "Build",
            source: "In-house prop shop",
            acquisitionCost: 500.0,
            quantity: 3,
            quantityHero: 1,
            quantityStunt: 2,
            storageLocation: "Prop Room B",
            requiresFabrication: true,
            referencePhotos: ["ref/sword1.jpg"],
            notes: "Handle with care",
            handlingInstructions: "Wear gloves",
            safetyNotes: "Blunt edge only",
            status: "Available"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "prop-sword")
        XCTAssertEqual(decoded.name, "Excalibur")
        XCTAssertEqual(decoded.thumbnail, "props/sword_thumb.jpg")
        XCTAssertEqual(decoded.description, "Hero prop sword")
        XCTAssertEqual(decoded.category, "Weapon")
        XCTAssertEqual(decoded.tags, ["hero-prop", "period-piece"])
        XCTAssertEqual(decoded.acquisitionType, "Build")
        XCTAssertEqual(decoded.acquisitionCost, 500.0)
        XCTAssertEqual(decoded.quantity, 3)
        XCTAssertEqual(decoded.quantityHero, 1)
        XCTAssertEqual(decoded.quantityStunt, 2)
        XCTAssertEqual(decoded.storageLocation, "Prop Room B")
        XCTAssertEqual(decoded.requiresFabrication, true)
        XCTAssertEqual(decoded.status, "Available")
    }

    func testPropBackwardCompatibility() throws {
        // Legacy Python props have only name
        let json = """
        {"name":"Coffee Cup"}
        """
        let decoded: Prop = try decodeJSON(json)
        XCTAssertEqual(decoded.name, "Coffee Cup")
        XCTAssertFalse(decoded.id.isEmpty) // Auto-generated
        XCTAssertEqual(decoded.description, "")
        XCTAssertTrue(decoded.tags.isEmpty)
        XCTAssertNil(decoded.acquisitionType)
    }

    // =========================================================================
    // MARK: - PropFabrication
    // =========================================================================

    func testPropFabricationRoundTrip() throws {
        let original = PropFabrication(
            materialsNeeded: ["foam", "paint", "fiberglass"],
            dimensions: "32\" x 4\" x 2\"",
            weight: "1.5 lbs",
            constructionNotes: "Layer foam, coat in fiberglass",
            referenceImages: ["ref/build1.jpg"],
            blueprintsPath: "blueprints/sword.pdf",
            estimatedBuildTime: "3 days",
            builderAssigned: "Mike Smith",
            completionStatus: "In Progress"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.materialsNeeded, ["foam", "paint", "fiberglass"])
        XCTAssertEqual(decoded.dimensions, "32\" x 4\" x 2\"")
        XCTAssertEqual(decoded.weight, "1.5 lbs")
        XCTAssertEqual(decoded.blueprintsPath, "blueprints/sword.pdf")
        XCTAssertEqual(decoded.estimatedBuildTime, "3 days")
        XCTAssertEqual(decoded.builderAssigned, "Mike Smith")
        XCTAssertEqual(decoded.completionStatus, "In Progress")
    }

    // =========================================================================
    // MARK: - PropContinuityState
    // =========================================================================

    func testPropContinuityStateRoundTrip() throws {
        let original = PropContinuityState(
            id: "cont-001",
            sceneName: "Scene 5",
            condition: "Damaged",
            description: "Sword has a notch in the blade",
            referencePhotos: ["ref/damage.jpg"],
            notes: "Matches scene 4 fight"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "cont-001")
        XCTAssertEqual(decoded.sceneName, "Scene 5")
        XCTAssertEqual(decoded.condition, "Damaged")
        XCTAssertEqual(decoded.description, "Sword has a notch in the blade")
        XCTAssertEqual(decoded.referencePhotos, ["ref/damage.jpg"])
    }

    // =========================================================================
    // MARK: - CharacterCostume
    // =========================================================================

    func testCharacterCostumeRoundTrip() throws {
        let original = CharacterCostume(
            costumeId: "cc-001",
            name: "Battle Armor",
            description: "Full plate armor with royal crest",
            imageFront: "costumes/armor_front.jpg",
            imageBack: "costumes/armor_back.jpg",
            era: "Medieval",
            styleCategory: "Armor",
            colorPalette: ["#8B8B8B", "#C0C0C0"],
            garmentTop: "Breastplate",
            garmentBottom: "Greaves",
            footwear: "Steel boots",
            accessories: ["sword belt", "cape"],
            primaryFabric: "Metal",
            status: "Ready",
            sceneIds: ["scene-001", "scene-005"],
            changeNumber: 2,
            scriptDay: "Day 3",
            directorNotes: "Polish before scene 5"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.costumeId, "cc-001")
        XCTAssertEqual(decoded.id, "cc-001")
        XCTAssertEqual(decoded.name, "Battle Armor")
        XCTAssertEqual(decoded.description, "Full plate armor with royal crest")
        XCTAssertEqual(decoded.imageFront, "costumes/armor_front.jpg")
        XCTAssertEqual(decoded.imageBack, "costumes/armor_back.jpg")
        XCTAssertEqual(decoded.era, "Medieval")
        XCTAssertEqual(decoded.colorPalette, ["#8B8B8B", "#C0C0C0"])
        XCTAssertEqual(decoded.accessories, ["sword belt", "cape"])
        XCTAssertEqual(decoded.sceneIds, ["scene-001", "scene-005"])
        XCTAssertEqual(decoded.changeNumber, 2)
        XCTAssertEqual(decoded.directorNotes, "Polish before scene 5")
    }

    // =========================================================================
    // MARK: - SceneLocationImage
    // =========================================================================

    func testSceneLocationImageRoundTrip() throws {
        let original = SceneLocationImage(
            id: "sli-001",
            sceneId: "scene-001",
            imagePath: "locations/kitchen.jpg",
            locationName: "Kitchen",
            locationType: "Residential",
            indoorOutdoor: "Indoor",
            description: "Modern kitchen with island",
            cameraAngle: "Wide",
            lensMm: 24,
            aperture: "f/4",
            timeOfDay: "Morning",
            weather: "Clear",
            lightingStyle: "Natural",
            colorTemperature: "5600K Daylight",
            aspectRatio: "2.39:1",
            colorGrading: "Warm",
            depthOfField: "Deep",
            fullPrompt: "A modern kitchen with morning light",
            negativePrompt: "No people",
            modelUsed: "imagen-3.0",
            userNotes: "Good reference for scene 1",
            isFavorite: true,
            fileSizeBytes: 2048000,
            imageWidth: 1920,
            imageHeight: 1080
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "sli-001")
        XCTAssertEqual(decoded.sceneId, "scene-001")
        XCTAssertEqual(decoded.locationName, "Kitchen")
        XCTAssertEqual(decoded.locationType, "Residential")
        XCTAssertEqual(decoded.indoorOutdoor, "Indoor")
        XCTAssertEqual(decoded.cameraAngle, "Wide")
        XCTAssertEqual(decoded.lensMm, 24)
        XCTAssertEqual(decoded.aspectRatio, "2.39:1")
        XCTAssertEqual(decoded.colorGrading, "Warm")
        XCTAssertTrue(decoded.isFavorite)
        XCTAssertEqual(decoded.fileSizeBytes, 2048000)
        XCTAssertEqual(decoded.imageWidth, 1920)
        XCTAssertEqual(decoded.imageHeight, 1080)
    }

    // =========================================================================
    // MARK: - VisionCard
    // =========================================================================

    func testVisionCardRoundTrip() throws {
        let original = VisionCard(
            id: "vc-001",
            title: "Mood Reference",
            description: "Dark alley at night",
            character: "VILLAIN",
            text: "This is the feel we want",
            tags: ["dark", "noir"],
            props: ["streetlight"],
            costumes: ["trench coat"],
            effects: ["fog"],
            imagePath: "vision/alley.jpg",
            videoUrl: "https://example.com/ref.mp4",
            sequenceName: "Act 3",
            sceneName: "Scene 12",
            position: 5,
            cardType: "image",
            boardId: "mood_board",
            colorPalette: ["#1a1a2e", "#16213e"],
            sourceUrl: "https://unsplash.com/photo/123",
            credit: "Photographer Name",
            pinned: true,
            size: "large",
            department: "cinematography",
            canvasX: 100.0,
            canvasY: 200.0,
            zOrder: 3.0,
            canvasWidth: 300.0,
            canvasHeight: 200.0,
            textColor: "#FFFFFF"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "vc-001")
        XCTAssertEqual(decoded.title, "Mood Reference")
        XCTAssertEqual(decoded.character, "VILLAIN")
        XCTAssertEqual(decoded.tags, ["dark", "noir"])
        XCTAssertEqual(decoded.imagePath, "vision/alley.jpg")
        XCTAssertEqual(decoded.videoUrl, "https://example.com/ref.mp4")
        XCTAssertEqual(decoded.cardType, "image")
        XCTAssertEqual(decoded.boardId, "mood_board")
        XCTAssertEqual(decoded.colorPalette, ["#1a1a2e", "#16213e"])
        XCTAssertTrue(decoded.pinned)
        XCTAssertEqual(decoded.size, "large")
        XCTAssertEqual(decoded.canvasX, 100.0)
        XCTAssertEqual(decoded.canvasY, 200.0)
        XCTAssertEqual(decoded.zOrder, 3.0)
    }

    func testVisionCardBackwardCompatibility() throws {
        let json = """
        {}
        """
        let decoded: VisionCard = try decodeJSON(json)
        XCTAssertFalse(decoded.id.isEmpty)
        XCTAssertEqual(decoded.title, "")
        XCTAssertEqual(decoded.cardType, "image")
        XCTAssertEqual(decoded.boardId, "master")
        XCTAssertFalse(decoded.pinned)
        XCTAssertEqual(decoded.size, "medium")
        XCTAssertNil(decoded.canvasX)
    }

    // =========================================================================
    // MARK: - BudgetCategory
    // =========================================================================

    func testBudgetCategoryRoundTrip() throws {
        let original = BudgetCategory(
            name: "Camera Department",
            allocated: 50000.0,
            spent: 32000.0,
            description: "All camera equipment and crew",
            isCustom: false,
            accountCode: "3300",
            categoryGroup: "BTL"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.name, "Camera Department")
        XCTAssertEqual(decoded.allocated, 50000.0)
        XCTAssertEqual(decoded.spent, 32000.0)
        XCTAssertEqual(decoded.isCustom, false)
        XCTAssertEqual(decoded.accountCode, "3300")
        XCTAssertEqual(decoded.categoryGroup, "BTL")
        XCTAssertEqual(decoded.remaining, 18000.0)
    }

    // =========================================================================
    // MARK: - Expense
    // =========================================================================

    func testExpenseRoundTrip() throws {
        let original = Expense(
            id: "exp-001",
            date: "2026-03-15",
            category: "Camera",
            amount: 1500.0,
            description: "Lens rental",
            vendor: "LensRentals",
            sceneId: "scene-001",
            shotId: "shot-001",
            receiptPath: "receipts/lens_rental.pdf",
            department: "Camera",
            accountCode: "3300",
            paymentMethod: "Card",
            status: "Approved",
            isQualifyingExpense: true,
            addedBy: "John Producer"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "exp-001")
        XCTAssertEqual(decoded.date, "2026-03-15")
        XCTAssertEqual(decoded.amount, 1500.0)
        XCTAssertEqual(decoded.vendor, "LensRentals")
        XCTAssertEqual(decoded.sceneId, "scene-001")
        XCTAssertEqual(decoded.accountCode, "3300")
        XCTAssertEqual(decoded.paymentMethod, "Card")
        XCTAssertTrue(decoded.isQualifyingExpense)
    }

    // =========================================================================
    // MARK: - PurchaseOrder
    // =========================================================================

    func testPurchaseOrderRoundTrip() throws {
        let original = PurchaseOrder(
            id: "po-001",
            poNumber: "PO-001",
            vendor: "Film Supply Co",
            department: "Art",
            accountCode: "4400",
            description: "Set dressing materials",
            amount: 3500.0,
            status: "Approved",
            dateCreated: "2026-03-01",
            dateApproved: "2026-03-02",
            notes: "Rush delivery",
            sceneId: "scene-003",
            approvedBy: "Producer Jane",
            attachments: ["docs/po001.pdf"]
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "po-001")
        XCTAssertEqual(decoded.poNumber, "PO-001")
        XCTAssertEqual(decoded.vendor, "Film Supply Co")
        XCTAssertEqual(decoded.amount, 3500.0)
        XCTAssertEqual(decoded.status, "Approved")
        XCTAssertEqual(decoded.dateApproved, "2026-03-02")
        XCTAssertEqual(decoded.attachments, ["docs/po001.pdf"])
    }

    // =========================================================================
    // MARK: - ProjectBudget
    // =========================================================================

    func testProjectBudgetRoundTrip() throws {
        let category = BudgetCategory(name: "Camera", allocated: 10000, spent: 5000)
        let expense = Expense(id: "e1", category: "Camera", amount: 500)
        let po = PurchaseOrder(id: "po1", poNumber: "PO-001")

        let original = ProjectBudget(
            categories: [category],
            expenses: [expense],
            totalBudget: 100000.0,
            currency: "EUR",
            aiBudgetLimit: 500.0,
            aiProductionEstimates: ["video": 200.0],
            purchaseOrders: [po],
            contingencyPercentage: 0.15,
            fringeRate: 0.25
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.categories.count, 1)
        XCTAssertEqual(decoded.expenses.count, 1)
        XCTAssertEqual(decoded.totalBudget, 100000.0)
        XCTAssertEqual(decoded.currency, "EUR")
        XCTAssertEqual(decoded.aiBudgetLimit, 500.0)
        XCTAssertEqual(decoded.aiProductionEstimates?["video"], 200.0)
        XCTAssertEqual(decoded.purchaseOrders.count, 1)
        XCTAssertEqual(decoded.contingencyPercentage, 0.15)
        XCTAssertEqual(decoded.fringeRate, 0.25)
    }

    // =========================================================================
    // MARK: - ScheduleItem
    // =========================================================================

    func testScheduleItemRoundTrip() throws {
        let original = ScheduleItem(
            id: "sched-001",
            sceneId: "scene-001",
            sceneName: "Scene 1",
            sequenceName: "Act 1",
            shotIds: ["shot-001", "shot-002"],
            shootDate: "2026-04-15",
            timeSlot: "Morning",
            estimatedDurationHours: 6.0,
            status: "Confirmed",
            location: "Studio A",
            locationAddress: "123 Film St",
            requiredActors: ["Alice", "Bob"],
            requiredCrew: ["DP", "Gaffer"],
            requiredEquipment: ["Camera A"],
            requiredProps: ["Coffee Cup"],
            productionNotes: "Start with wide shot",
            callTime: "06:00",
            estimatedCost: 5000.0,
            priority: 1,
            color: "#FF5733"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "sched-001")
        XCTAssertEqual(decoded.sceneId, "scene-001")
        XCTAssertEqual(decoded.shotIds, ["shot-001", "shot-002"])
        XCTAssertEqual(decoded.shootDate, "2026-04-15")
        XCTAssertEqual(decoded.timeSlot, "Morning")
        XCTAssertEqual(decoded.estimatedDurationHours, 6.0)
        XCTAssertEqual(decoded.status, "Confirmed")
        XCTAssertEqual(decoded.requiredActors, ["Alice", "Bob"])
        XCTAssertEqual(decoded.callTime, "06:00")
        XCTAssertEqual(decoded.priority, 1)
        XCTAssertEqual(decoded.color, "#FF5733")
    }

    // =========================================================================
    // MARK: - FilmStyle
    // =========================================================================

    func testFilmStyleRoundTrip() throws {
        let original = FilmStyle(
            id: "style-noir",
            name: "Film Noir",
            description: "Classic noir look",
            isPreset: true,
            renderingStyle: "realistic",
            textureQuality: "grainy",
            colorPalette: ["#000000", "#333333", "#666666"],
            colorGrading: "desaturated",
            contrastLevel: "dramatic",
            filmGrain: true,
            vignette: true,
            lensDistortion: "subtle",
            chromaticAberration: false,
            aiStylePrompt: "film noir, high contrast, black and white",
            negativePrompt: "color, bright, saturated",
            referenceImages: ["ref/noir1.jpg"],
            author: "Director Jane"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "style-noir")
        XCTAssertEqual(decoded.name, "Film Noir")
        XCTAssertTrue(decoded.isPreset)
        XCTAssertEqual(decoded.textureQuality, "grainy")
        XCTAssertEqual(decoded.colorPalette, ["#000000", "#333333", "#666666"])
        XCTAssertEqual(decoded.contrastLevel, "dramatic")
        XCTAssertTrue(decoded.filmGrain)
        XCTAssertTrue(decoded.vignette)
        XCTAssertEqual(decoded.lensDistortion, "subtle")
        XCTAssertFalse(decoded.chromaticAberration)
        XCTAssertEqual(decoded.author, "Director Jane")
    }

    // =========================================================================
    // MARK: - CastMember
    // =========================================================================

    func testCastMemberRoundTrip() throws {
        let original = CastMember(
            id: "cast-001",
            actorName: "Jane Doe",
            characterName: "Queen Elizabeth",
            characterDescription: "The monarch",
            email: "jane@example.com",
            phone: "555-0100",
            roleType: "Principal",
            unionStatus: "SAG-AFTRA",
            paymentType: "Daily Rate",
            dailyRate: 5000.0,
            contractSigned: true
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "cast-001")
        XCTAssertEqual(decoded.actorName, "Jane Doe")
        XCTAssertEqual(decoded.characterName, "Queen Elizabeth")
        XCTAssertEqual(decoded.email, "jane@example.com")
        XCTAssertEqual(decoded.roleType, "Principal")
        XCTAssertEqual(decoded.unionStatus, "SAG-AFTRA")
        XCTAssertEqual(decoded.dailyRate, 5000.0)
        XCTAssertTrue(decoded.contractSigned)
    }

    // =========================================================================
    // MARK: - CrewMember
    // =========================================================================

    func testCrewMemberRoundTrip() throws {
        let original = CrewMember(
            id: "crew-001",
            name: "Mike DP",
            role: "Director of Photography",
            department: "Camera",
            email: "mike@example.com",
            employmentType: "Freelance",
            dailyRate: 3000.0,
            kitFee: 500.0,
            skills: ["Steadicam", "Drone"],
            equipmentOwned: ["Ronin Gimbal"],
            contractSigned: true,
            w9Received: true
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "crew-001")
        XCTAssertEqual(decoded.name, "Mike DP")
        XCTAssertEqual(decoded.department, "Camera")
        XCTAssertEqual(decoded.dailyRate, 3000.0)
        XCTAssertEqual(decoded.kitFee, 500.0)
        XCTAssertEqual(decoded.skills, ["Steadicam", "Drone"])
        XCTAssertEqual(decoded.equipmentOwned, ["Ronin Gimbal"])
        XCTAssertTrue(decoded.w9Received)
    }

    // =========================================================================
    // MARK: - Team
    // =========================================================================

    func testTeamRoundTrip() throws {
        let original = Team(
            id: "team-001",
            name: "A-Unit",
            description: "Main shooting unit",
            teamType: "Shooting Unit",
            castMemberIds: ["cast-001"],
            crewMemberIds: ["crew-001", "crew-002"],
            teamLeadId: "crew-001",
            notes: "Primary unit for all exterior shoots"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "team-001")
        XCTAssertEqual(decoded.name, "A-Unit")
        XCTAssertEqual(decoded.teamType, "Shooting Unit")
        XCTAssertEqual(decoded.castMemberIds, ["cast-001"])
        XCTAssertEqual(decoded.crewMemberIds, ["crew-001", "crew-002"])
        XCTAssertEqual(decoded.teamLeadId, "crew-001")
    }

    // =========================================================================
    // MARK: - EquipmentItem
    // =========================================================================

    func testEquipmentItemRoundTrip() throws {
        let original = EquipmentItem(
            id: "equip-001",
            name: "ARRI Alexa Mini LF",
            category: "Camera",
            subcategory: "Cinema Camera",
            manufacturer: "ARRI",
            model: "Alexa Mini LF",
            description: "Large format cinema camera",
            quantityOwned: 1,
            quantityAvailable: 1,
            isRental: true,
            rentalCompany: "Panavision",
            rentalDailyRate: 2500.0,
            rentalWeeklyRate: 10000.0,
            specs: ["sensor": "LF Open Gate", "resolution": "4.5K"],
            serialNumber: "K1.0001234",
            condition: "Excellent",
            storageLocation: "Camera Truck"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "equip-001")
        XCTAssertEqual(decoded.name, "ARRI Alexa Mini LF")
        XCTAssertEqual(decoded.manufacturer, "ARRI")
        XCTAssertTrue(decoded.isRental)
        XCTAssertEqual(decoded.rentalDailyRate, 2500.0)
        XCTAssertEqual(decoded.specs["sensor"], "LF Open Gate")
        XCTAssertEqual(decoded.serialNumber, "K1.0001234")
        XCTAssertEqual(decoded.condition, "Excellent")
    }

    // =========================================================================
    // MARK: - EquipmentAllocation
    // =========================================================================

    func testEquipmentAllocationRoundTrip() throws {
        let original = EquipmentAllocation(
            id: "alloc-001",
            equipmentItemId: "equip-001",
            allocationMode: .specificDays,
            allocatedDates: ["2026-04-15", "2026-04-16"],
            quantityAllocated: 1,
            notes: "For exterior shoot"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.id, "alloc-001")
        XCTAssertEqual(decoded.equipmentItemId, "equip-001")
        XCTAssertEqual(decoded.allocationMode, .specificDays)
        XCTAssertEqual(decoded.allocatedDates, ["2026-04-15", "2026-04-16"])
        XCTAssertEqual(decoded.quantityAllocated, 1)
    }

    func testEquipmentAllocationModeRoundTrip() throws {
        for mode in [ProductionAllocationMode.fullProduction, .specificDays] {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(ProductionAllocationMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    // =========================================================================
    // MARK: - ProjectUserManager
    // =========================================================================

    func testProjectUserManagerRoundTrip() throws {
        let original = ProjectUserManager(users: ["alice", "bob", "charlie"])
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded.users, ["alice", "bob", "charlie"])
    }

    func testProjectUserManagerBackwardCompatibility() throws {
        let json = """
        {}
        """
        let decoded: ProjectUserManager = try decodeJSON(json)
        XCTAssertTrue(decoded.users.isEmpty)
    }

    // =========================================================================
    // MARK: - Project (full integration)
    // =========================================================================

    func testProjectMinimalRoundTrip() throws {
        let original = Project(name: "Test Film")
        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.name, "Test Film")
        XCTAssertEqual(decoded.id, decoded.uuid)  // identity is the stable uuid, not the name (WS2.5)
        XCTAssertEqual(decoded.projectType, "Skit")
        XCTAssertEqual(decoded.status, "Pre-production")
        XCTAssertTrue(decoded.sequences.isEmpty)
        XCTAssertTrue(decoded.characters.isEmpty)
        XCTAssertNil(decoded.userManager)
        XCTAssertNil(decoded.projectBudget)
        XCTAssertNil(decoded.defaultFilmStyle)
    }

    func testProjectFullyPopulatedRoundTrip() throws {
        let dialogue = Dialogue(uuid: "d1", character: "ALICE", text: "Hello!", chronologyNumber: 0)
        let action = Action(uuid: "a1", description: "Alice smiles.", chronologyNumber: 1)
        let narration = Narration(uuid: "n1", text: "The room brightened.", chronologyNumber: 2)
        let shot = Shot(uuid: "sh1", shotId: 1, description: "Close up on Alice")
        let scene = Scene(
            uuid: "sc1",
            name: "Opening",
            dialogues: [dialogue],
            actions: [action],
            narrations: [narration],
            shots: [shot],
            location: "Coffee Shop"
        )
        let sequence = Sequence(uuid: "seq1", name: "Act 1", scenes: [scene])
        let character = Character(characterId: "char-alice", name: "Alice", role: "Protagonist")
        let location = Location(name: "Coffee Shop")
        let prop = Prop(name: "Coffee Cup")
        let costume = Costume(name: "Blue Dress")
        let lighting = Lighting(name: "Key Light")
        let effect = EffectDef(name: "Fog")
        let budget = ProjectBudget(totalBudget: 100000)
        let userManager = ProjectUserManager(users: ["director1"])

        let original = Project(
            name: "Alice's Adventure",
            basePath: "/projects/alice",
            description: "A heartwarming tale",
            director: "Jane Director",
            productionCompany: "Indie Films LLC",
            genre: "Drama",
            projectType: "Motion Film",
            targetDuration: "90 minutes",
            budget: "$100,000",
            startDate: "2026-04-01",
            endDate: "2026-06-30",
            status: "Pre-production",
            projectNotes: "Shooting in spring",
            projectIcon: "icons/alice.png",
            languages: ["English", "French"],
            characters: [character],
            props: [prop],
            costumes: [costume],
            lighting: [lighting],
            effects: [effect],
            locations: [location],
            sequences: [sequence],
            userManager: userManager,
            projectBudget: budget,
            defaultExpenseDepartment: "Production",
            defaultExpenseAccountCode: "1000",
            overviewPosterPaths: ["posters/p1.jpg"],
            overviewPosterCurrentIndex: 0,
            overviewPosterCustom: true,
            overviewSummary: "A young woman discovers her purpose.",
            overviewTagline: "Every journey starts with a single step.",
            overviewLogline: "Alice embarks on an adventure that transforms her world.",
            overviewMoodAnalysis: ["hope": 0.8, "adventure": 0.9]
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.name, "Alice's Adventure")
        // basePath is device-local and not part of the wire format (WS2.6):
        // it is populated at load from the file location, never round-tripped.
        XCTAssertEqual(decoded.basePath, "")
        XCTAssertEqual(decoded.director, "Jane Director")
        XCTAssertEqual(decoded.productionCompany, "Indie Films LLC")
        XCTAssertEqual(decoded.genre, "Drama")
        XCTAssertEqual(decoded.projectType, "Motion Film")
        XCTAssertEqual(decoded.targetDuration, "90 minutes")
        XCTAssertEqual(decoded.languages, ["English", "French"])
        XCTAssertEqual(decoded.characters.count, 1)
        XCTAssertEqual(decoded.characters[0].name, "Alice")
        XCTAssertEqual(decoded.props.count, 1)
        XCTAssertEqual(decoded.costumes.count, 1)
        XCTAssertEqual(decoded.lighting.count, 1)
        XCTAssertEqual(decoded.effects.count, 1)
        XCTAssertEqual(decoded.locations.count, 1)
        XCTAssertEqual(decoded.sequences.count, 1)
        XCTAssertEqual(decoded.sequences[0].scenes.count, 1)
        XCTAssertEqual(decoded.sequences[0].scenes[0].dialogues.count, 1)
        XCTAssertEqual(decoded.sequences[0].scenes[0].shots.count, 1)
        XCTAssertEqual(decoded.userManager?.users, ["director1"])
        XCTAssertEqual(decoded.projectBudget?.totalBudget, 100000)
        XCTAssertEqual(decoded.defaultExpenseDepartment, "Production")
        XCTAssertEqual(decoded.overviewPosterPaths, ["posters/p1.jpg"])
        XCTAssertTrue(decoded.overviewPosterCustom)
        XCTAssertEqual(decoded.overviewTagline, "Every journey starts with a single step.")
        XCTAssertEqual(decoded.overviewMoodAnalysis?["hope"], 0.8)
    }

    func testProjectSnakeCaseCodingKeys() throws {
        // Populate optional fields so they appear in JSON
        let project = Project(
            name: "Test",
            productionCompany: "Co",
            projectType: "Skit",
            defaultFilmStyle: "style-1",
            userManager: ProjectUserManager(users: ["u1"]),
            projectBudget: ProjectBudget(totalBudget: 100),
            defaultExpenseDepartment: "Prod"
        )
        let data = try encoder.encode(project)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertFalse(json.contains("\"base_path\""),
                       "base_path is device-local and must not be serialized (WS2.6)")
        XCTAssertTrue(json.contains("\"production_company\""))
        XCTAssertTrue(json.contains("\"project_type\""))
        XCTAssertTrue(json.contains("\"target_duration\""))
        XCTAssertTrue(json.contains("\"start_date\""))
        XCTAssertTrue(json.contains("\"end_date\""))
        XCTAssertTrue(json.contains("\"project_notes\""))
        XCTAssertTrue(json.contains("\"project_icon\""))
        XCTAssertTrue(json.contains("\"schedule_items\""))
        XCTAssertTrue(json.contains("\"film_styles\""))
        XCTAssertTrue(json.contains("\"default_film_style\""))
        XCTAssertTrue(json.contains("\"cast_members\""))
        XCTAssertTrue(json.contains("\"crew_members\""))
        XCTAssertTrue(json.contains("\"equipment_library\""))
        XCTAssertTrue(json.contains("\"equipment_allocations\""))
        XCTAssertTrue(json.contains("\"user_manager\""))
        XCTAssertTrue(json.contains("\"project_budget\""))
        XCTAssertTrue(json.contains("\"default_expense_department\""))
        XCTAssertTrue(json.contains("\"default_expense_account_code\""))
        XCTAssertTrue(json.contains("\"overview_poster_paths\""))
        XCTAssertTrue(json.contains("\"overview_summary\""))
        XCTAssertTrue(json.contains("\"overview_tagline\""))
        XCTAssertTrue(json.contains("\"overview_logline\""))
    }

    func testProjectBackwardCompatibilityMinimalJSON() throws {
        // Simulates a Python-generated project with only the required field
        let json = """
        {"name":"Legacy Project"}
        """
        let decoded: Project = try decodeJSON(json)

        XCTAssertEqual(decoded.name, "Legacy Project")
        XCTAssertEqual(decoded.basePath, "")
        XCTAssertEqual(decoded.projectType, "Skit")
        XCTAssertEqual(decoded.status, "Pre-production")
        XCTAssertEqual(decoded.languages, ["English"])
        XCTAssertTrue(decoded.characters.isEmpty)
        XCTAssertTrue(decoded.sequences.isEmpty)
        XCTAssertTrue(decoded.props.isEmpty)
        XCTAssertNil(decoded.userManager)
        XCTAssertNil(decoded.projectBudget)
        XCTAssertNil(decoded.defaultFilmStyle)
        XCTAssertNil(decoded.overviewMoodAnalysis)
        XCTAssertEqual(decoded.overviewPosterCurrentIndex, 0)
        XCTAssertFalse(decoded.overviewPosterCustom)
    }

    // =========================================================================
    // MARK: - Multiple Round Trips (stability test)
    // =========================================================================

    func testMultipleRoundTripsPreserveAllData() throws {
        let dialogue = Dialogue(uuid: "stable-dlg", character: "A", text: "Test", chronologyNumber: 1)
        let shot = Shot(uuid: "stable-shot", shotId: 1, description: "Test shot")
        let scene = Scene(uuid: "stable-scene", name: "Scene 1", dialogues: [dialogue], shots: [shot])
        let sequence = Sequence(uuid: "stable-seq", name: "Act 1", scenes: [scene])
        let character = Character(characterId: "stable-char", name: "Stable")
        var project = Project(name: "Stability Test", characters: [character], sequences: [sequence])
        project.overviewMoodAnalysis = ["tension": 0.5]

        // Round-trip 5 times
        var current = project
        for _ in 0..<5 {
            current = try roundTrip(current)
        }

        XCTAssertEqual(current.name, "Stability Test")
        XCTAssertEqual(current.sequences[0].uuid, "stable-seq")
        XCTAssertEqual(current.sequences[0].scenes[0].uuid, "stable-scene")
        XCTAssertEqual(current.sequences[0].scenes[0].dialogues[0].uuid, "stable-dlg")
        XCTAssertEqual(current.sequences[0].scenes[0].shots[0].uuid, "stable-shot")
        XCTAssertEqual(current.characters[0].characterId, "stable-char")
        XCTAssertEqual(current.overviewMoodAnalysis?["tension"], 0.5)
    }

    // =========================================================================
    // MARK: - Special Characters in Strings
    // =========================================================================

    func testSpecialCharactersInStringSurviveRoundTrip() throws {
        let dialogue = Dialogue(
            character: "O'BRIAN",
            text: "He said \"stop\" & then ran away.\nNew line here.\tTab here."
        )

        let decoded = try roundTrip(dialogue)

        XCTAssertEqual(decoded.character, "O'BRIAN")
        XCTAssertEqual(decoded.text, "He said \"stop\" & then ran away.\nNew line here.\tTab here.")
    }

    func testUnicodeCharactersSurviveRoundTrip() throws {
        let dialogue = Dialogue(
            character: "SAKURA",
            text: "konnichiwa"
        )

        let decoded = try roundTrip(dialogue)
        XCTAssertEqual(decoded.character, "SAKURA")
        XCTAssertEqual(decoded.text, "konnichiwa")
    }

    // =========================================================================
    // MARK: - Empty Collections
    // =========================================================================

    func testEmptyCollectionsSurviveRoundTrip() throws {
        let scene = Scene(
            name: "Empty",
            dialogues: [],
            actions: [],
            narrations: [],
            sceneNotes: [],
            soundNotes: [],
            shots: [],
            locationImages: [],
            stage: [:],
            props: []
        )

        let decoded = try roundTrip(scene)

        XCTAssertTrue(decoded.dialogues.isEmpty)
        XCTAssertTrue(decoded.actions.isEmpty)
        XCTAssertTrue(decoded.narrations.isEmpty)
        XCTAssertTrue(decoded.sceneNotes.isEmpty)
        XCTAssertTrue(decoded.soundNotes.isEmpty)
        XCTAssertTrue(decoded.shots.isEmpty)
        XCTAssertTrue(decoded.locationImages.isEmpty)
        XCTAssertTrue(decoded.stage.isEmpty)
        XCTAssertTrue(decoded.props.isEmpty)
    }
}
