// TimelineDataModelTests.swift
// Tests for TimelineSegment, TimelineMarker, TimelineBoundary, TimelineLayoutConstants, TimelineDefaultColors

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairServices

final class TimelineDataModelTests: XCTestCase {

    // MARK: - TimelineSegment Tests

    func testSegmentCreation() {
        let segment = TimelineSegment(
            start: 5.0, duration: 3.0, character: "Alice", color: "#FF0000",
            text: "Hello there!", sceneName: "Scene 1", contentType: .dialogue,
            chronologyNumber: 1
        )

        XCTAssertEqual(segment.start, 5.0)
        XCTAssertEqual(segment.duration, 3.0)
        XCTAssertEqual(segment.character, "Alice")
        XCTAssertEqual(segment.color, "#FF0000")
        XCTAssertEqual(segment.text, "Hello there!")
        XCTAssertEqual(segment.sceneName, "Scene 1")
        XCTAssertEqual(segment.contentType, .dialogue)
        XCTAssertEqual(segment.chronologyNumber, 1)
    }

    func testSegmentEndTime() {
        let segment = TimelineSegment(
            start: 10.0, duration: 5.0, character: "Bob", color: "#0000FF",
            text: "Test", sceneName: "S1", contentType: .dialogue
        )
        XCTAssertEqual(segment.end, 15.0)
    }

    func testSegmentEndTimeZeroDuration() {
        let segment = TimelineSegment(
            start: 10.0, duration: 0.0, character: "C", color: "#FFF",
            text: "", sceneName: "S1", contentType: .note
        )
        XCTAssertEqual(segment.end, 10.0)
    }

    func testSegmentContentTypes() {
        XCTAssertEqual(TimelineSegment.ContentType.dialogue.rawValue, "dialogue")
        XCTAssertEqual(TimelineSegment.ContentType.action.rawValue, "action")
        XCTAssertEqual(TimelineSegment.ContentType.narration.rawValue, "narration")
        XCTAssertEqual(TimelineSegment.ContentType.note.rawValue, "note")
        XCTAssertEqual(TimelineSegment.ContentType.soundNote.rawValue, "soundNote")
    }

    func testSegmentDefaultValues() {
        let segment = TimelineSegment(
            start: 0, duration: 1, character: "A", color: "#FFF",
            text: "", sceneName: "S", contentType: .dialogue
        )
        XCTAssertEqual(segment.textColor, "#FFFFFF")
        XCTAssertNil(segment.avatarPath)
        XCTAssertEqual(segment.propsCount, 0)
        XCTAssertFalse(segment.hasAudio)
        XCTAssertNil(segment.sourceItemId)
        XCTAssertNil(segment.parentCharacterName)
    }

    func testSegmentEquality() {
        let id = UUID()
        let a = TimelineSegment(
            id: id, start: 0, duration: 1, character: "A", color: "#FFF",
            text: "Hi", sceneName: "S", contentType: .dialogue
        )
        let b = TimelineSegment(
            id: id, start: 0, duration: 1, character: "A", color: "#FFF",
            text: "Hi", sceneName: "S", contentType: .dialogue
        )
        XCTAssertEqual(a, b)
    }

    func testSegmentUniqueIds() {
        let a = TimelineSegment(
            start: 0, duration: 1, character: "A", color: "#FFF",
            text: "", sceneName: "S", contentType: .dialogue
        )
        let b = TimelineSegment(
            start: 0, duration: 1, character: "A", color: "#FFF",
            text: "", sceneName: "S", contentType: .dialogue
        )
        XCTAssertNotEqual(a.id, b.id)
    }

    func testSegmentOptionalFields() {
        let segment = TimelineSegment(
            start: 0, duration: 2, character: "Alice", color: "#FFF",
            text: "Test", sceneName: "S1", contentType: .action,
            avatarPath: "avatars/alice.png",
            propsCount: 3,
            hasAudio: true,
            sourceItemId: "dialogue-123",
            parentCharacterName: "Alice"
        )

        XCTAssertEqual(segment.avatarPath, "avatars/alice.png")
        XCTAssertEqual(segment.propsCount, 3)
        XCTAssertTrue(segment.hasAudio)
        XCTAssertEqual(segment.sourceItemId, "dialogue-123")
        XCTAssertEqual(segment.parentCharacterName, "Alice")
    }

    // MARK: - TimelineMarker Tests

    func testMarkerCreation() {
        let marker = TimelineMarker(
            time: 30.0, label: "Act Break",
            kind: .sequence, color: "#FFB34D",
            icon: "flag.fill"
        )

        XCTAssertEqual(marker.time, 30.0)
        XCTAssertEqual(marker.label, "Act Break")
        XCTAssertEqual(marker.kind, .sequence)
        XCTAssertEqual(marker.color, "#FFB34D")
        XCTAssertEqual(marker.icon, "flag.fill")
    }

    func testMarkerDefaultValues() {
        let marker = TimelineMarker(time: 10.0, label: "Note")

        XCTAssertEqual(marker.kind, .user)
        XCTAssertEqual(marker.color, "#FF5F5F")
        XCTAssertEqual(marker.icon, "flag.fill")
        XCTAssertEqual(marker.markerType, .general)
        XCTAssertEqual(marker.notes, "")
    }

    func testMarkerKinds() {
        XCTAssertEqual(TimelineMarker.MarkerKind.user.rawValue, "user")
        XCTAssertEqual(TimelineMarker.MarkerKind.scene.rawValue, "scene")
        XCTAssertEqual(TimelineMarker.MarkerKind.sequence.rawValue, "sequence")
        XCTAssertEqual(TimelineMarker.MarkerKind.note.rawValue, "note")
        XCTAssertEqual(TimelineMarker.MarkerKind.shot.rawValue, "shot")
    }

    func testMarkerTypes() {
        XCTAssertEqual(TimelineMarker.MarkerType.general.rawValue, "general")
        XCTAssertEqual(TimelineMarker.MarkerType.lighting.rawValue, "lighting")
        XCTAssertEqual(TimelineMarker.MarkerType.effect.rawValue, "effect")
    }

    func testMarkerEquality() {
        let id = UUID()
        let a = TimelineMarker(id: id, time: 5, label: "Test")
        let b = TimelineMarker(id: id, time: 5, label: "Test")
        XCTAssertEqual(a, b)
    }

    func testMarkerCodable() throws {
        let marker = TimelineMarker(
            time: 15.0, label: "Important",
            kind: .user, color: "#FF0000",
            markerType: .lighting, notes: "Watch the light"
        )

        let data = try JSONEncoder().encode(marker)
        let decoded = try JSONDecoder().decode(TimelineMarker.self, from: data)

        XCTAssertEqual(decoded.time, marker.time)
        XCTAssertEqual(decoded.label, marker.label)
        XCTAssertEqual(decoded.kind, marker.kind)
        XCTAssertEqual(decoded.color, marker.color)
        XCTAssertEqual(decoded.markerType, marker.markerType)
        XCTAssertEqual(decoded.notes, marker.notes)
    }

    // MARK: - TimelineBoundary Tests

    func testBoundaryCreation() {
        let boundary = TimelineBoundary(time: 45.0, name: "Scene 3")
        XCTAssertEqual(boundary.time, 45.0)
        XCTAssertEqual(boundary.name, "Scene 3")
    }

    func testBoundaryEquality() {
        let id = UUID()
        let a = TimelineBoundary(id: id, time: 10, name: "X")
        let b = TimelineBoundary(id: id, time: 10, name: "X")
        XCTAssertEqual(a, b)
    }

    // MARK: - TimelineLayoutConstants Tests

    func testLayoutConstantsPositive() {
        XCTAssertGreaterThan(TimelineLayoutConstants.topMargin, 0)
        XCTAssertGreaterThan(TimelineLayoutConstants.leftMargin, 0)
        XCTAssertGreaterThan(TimelineLayoutConstants.rulerHeight, 0)
        XCTAssertGreaterThan(TimelineLayoutConstants.baseRowHeight, 0)
        XCTAssertGreaterThan(TimelineLayoutConstants.rowGap, 0)
    }

    func testZoomLimitsValid() {
        XCTAssertGreaterThan(TimelineLayoutConstants.minPxPerSec, 0)
        XCTAssertGreaterThan(TimelineLayoutConstants.maxPxPerSec, TimelineLayoutConstants.minPxPerSec)
        XCTAssertGreaterThanOrEqual(TimelineLayoutConstants.defaultPxPerSec, TimelineLayoutConstants.minPxPerSec)
        XCTAssertLessThanOrEqual(TimelineLayoutConstants.defaultPxPerSec, TimelineLayoutConstants.maxPxPerSec)
    }

    func testBubbleConstantsValid() {
        XCTAssertGreaterThan(TimelineLayoutConstants.minBubbleWidth, 0)
        XCTAssertGreaterThan(TimelineLayoutConstants.maxTextBasedBubbleWidth, TimelineLayoutConstants.minBubbleWidth)
        XCTAssertGreaterThan(TimelineLayoutConstants.minWidthPerCharacter, 0)
    }

    func testTickHeightsAscending() {
        XCTAssertLessThan(TimelineLayoutConstants.minorTickHeight, TimelineLayoutConstants.mediumTickHeight)
        XCTAssertLessThan(TimelineLayoutConstants.mediumTickHeight, TimelineLayoutConstants.majorTickHeight)
        XCTAssertLessThan(TimelineLayoutConstants.majorTickHeight, TimelineLayoutConstants.minuteTickHeight)
    }

    func testCanvasMinimums() {
        XCTAssertGreaterThan(TimelineLayoutConstants.minCanvasWidth, 0)
        XCTAssertGreaterThan(TimelineLayoutConstants.minCanvasHeight, 0)
    }

    func testShotLaneConstants() {
        XCTAssertGreaterThan(TimelineLayoutConstants.shotLaneHeight, 0)
        XCTAssertGreaterThan(TimelineLayoutConstants.minShotCardWidth, 0)
    }

    func testPlayheadConstants() {
        XCTAssertGreaterThan(TimelineLayoutConstants.playheadHandleWidth, 0)
        XCTAssertGreaterThan(TimelineLayoutConstants.playheadHandleHeight, 0)
        XCTAssertGreaterThan(TimelineLayoutConstants.playheadHitRadius, 0)
    }

    // MARK: - TimelineDefaultColors Tests

    func testDefaultColorsNotEmpty() {
        XCTAssertFalse(TimelineDefaultColors.bubbleDefault.isEmpty)
        XCTAssertFalse(TimelineDefaultColors.actionBubble.isEmpty)
        XCTAssertFalse(TimelineDefaultColors.narrationBubble.isEmpty)
        XCTAssertFalse(TimelineDefaultColors.soundNoteBubble.isEmpty)
        XCTAssertFalse(TimelineDefaultColors.playheadColor.isEmpty)
    }

    func testDefaultColorsAreValidHex() {
        let colors = [
            TimelineDefaultColors.bubbleDefault,
            TimelineDefaultColors.actionBubble,
            TimelineDefaultColors.narrationBubble,
            TimelineDefaultColors.soundNoteBubble,
            TimelineDefaultColors.playheadColor,
            TimelineDefaultColors.userMarker,
            TimelineDefaultColors.sceneBoundary,
            TimelineDefaultColors.sequenceBoundary,
        ]
        for color in colors {
            XCTAssertTrue(color.hasPrefix("#"), "\(color) should start with #")
        }
    }

    func testColorForShotType() {
        let wideColor = TimelineDefaultColors.colorForShotType("wide")
        let closeUpColor = TimelineDefaultColors.colorForShotType("close-up")
        let defaultColor = TimelineDefaultColors.colorForShotType("unknown-type")

        XCTAssertFalse(wideColor.isEmpty)
        XCTAssertFalse(closeUpColor.isEmpty)
        XCTAssertNotEqual(wideColor, closeUpColor)
        XCTAssertFalse(defaultColor.isEmpty)
    }

    func testColorForShotTypeCaseInsensitive() {
        let lower = TimelineDefaultColors.colorForShotType("close-up")
        let mixed = TimelineDefaultColors.colorForShotType("Close-Up")
        XCTAssertEqual(lower, mixed)
    }

    func testIconForMovement() {
        XCTAssertNil(TimelineDefaultColors.iconForMovement("static"))
        XCTAssertNotNil(TimelineDefaultColors.iconForMovement("pan"))
        XCTAssertNotNil(TimelineDefaultColors.iconForMovement("tilt"))
        XCTAssertNotNil(TimelineDefaultColors.iconForMovement("dolly"))
        XCTAssertNotNil(TimelineDefaultColors.iconForMovement("crane"))
        XCTAssertNotNil(TimelineDefaultColors.iconForMovement("steadicam"))
        XCTAssertNotNil(TimelineDefaultColors.iconForMovement("zoom"))
        XCTAssertNotNil(TimelineDefaultColors.iconForMovement("tracking"))
    }

    func testIconForUnknownMovement() {
        let icon = TimelineDefaultColors.iconForMovement("flying-rig")
        XCTAssertNotNil(icon) // Falls through to default "arrow.right"
    }

    // MARK: - CharacterReferenceHelper Tests

    func testSanitizeLocationName() {
        XCTAssertEqual(
            CharacterReferenceHelper.sanitizeLocationName("INT. KITCHEN - DAY"),
            "INT._KITCHEN_-_DAY"
        )
    }

    func testSanitizeLocationNameSpecialChars() {
        let result = CharacterReferenceHelper.sanitizeLocationName("Bob's (Kitchen)/Area")
        XCTAssertFalse(result.contains("'"))
        XCTAssertFalse(result.contains("("))
        XCTAssertFalse(result.contains(")"))
        XCTAssertFalse(result.contains("/"))
    }

    func testSanitizeLocationNameCollapsesUnderscores() {
        let result = CharacterReferenceHelper.sanitizeLocationName("A   B")
        XCTAssertFalse(result.contains("__"))
    }

    func testSanitizeLocationNameTrimsUnderscores() {
        let result = CharacterReferenceHelper.sanitizeLocationName(" test ")
        XCTAssertFalse(result.hasPrefix("_"))
        XCTAssertFalse(result.hasSuffix("_"))
    }

    func testBuildReferenceImagePromptPrefixEmpty() {
        let result = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testBuildReferenceImagePromptPrefixLocation() {
        let ref = ReferenceImage(base64: "abc", mimeType: "image/png", label: "location:Kitchen")
        let result = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: [ref])
        XCTAssertTrue(result.contains("LOCATION"))
        XCTAssertTrue(result.contains("Kitchen"))
    }

    func testBuildReferenceImagePromptPrefixCharacter() {
        let ref = ReferenceImage(base64: "abc", mimeType: "image/png", label: "character:Alice")
        let result = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: [ref])
        XCTAssertTrue(result.contains("character Alice"))
    }

    func testBuildReferenceImagePromptPrefixCostume() {
        let ref = ReferenceImage(base64: "abc", mimeType: "image/png", label: "costume:Alice:Red Dress")
        let result = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: [ref])
        XCTAssertTrue(result.contains("costume"))
        XCTAssertTrue(result.contains("Red Dress"))
    }

    func testBuildReferenceImagePromptPrefixMultiple() {
        let refs = [
            ReferenceImage(base64: "a", mimeType: "image/png", label: "location:Park"),
            ReferenceImage(base64: "b", mimeType: "image/png", label: "character:Bob"),
        ]
        let result = CharacterReferenceHelper.buildReferenceImagePromptPrefix(for: refs)
        XCTAssertTrue(result.contains("Image 1"))
        XCTAssertTrue(result.contains("Image 2"))
        XCTAssertTrue(result.contains("2 reference image"))
    }
}
