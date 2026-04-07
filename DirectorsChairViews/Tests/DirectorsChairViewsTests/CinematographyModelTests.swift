// CinematographyModelTests.swift
// Tests for CinematographyViewMode, CameraPreset, ImageAnnotationEditor.buildEditPrompt

import XCTest
@testable import DirectorsChairViews
@testable import DirectorsChairCore

final class CinematographyModelTests: XCTestCase {

    // MARK: - CinematographyViewMode

    func testViewModeAllCases() {
        XCTAssertEqual(CinematographyViewMode.allCases.count, 4)
    }

    func testViewModeContainsExpected() {
        let cases = CinematographyViewMode.allCases
        XCTAssertTrue(cases.contains(.shotList))
        XCTAssertTrue(cases.contains(.storyboard))
        XCTAssertTrue(cases.contains(.overhead))
        XCTAssertTrue(cases.contains(.settings))
    }

    func testViewModeRawValues() {
        XCTAssertEqual(CinematographyViewMode.shotList.rawValue, "Shot List")
        XCTAssertEqual(CinematographyViewMode.storyboard.rawValue, "Storyboard")
        XCTAssertEqual(CinematographyViewMode.overhead.rawValue, "Overhead View")
        XCTAssertEqual(CinematographyViewMode.settings.rawValue, "Camera Settings")
    }

    func testViewModeId() {
        // id should be rawValue for Identifiable
        for mode in CinematographyViewMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testViewModeSystemImages() {
        XCTAssertEqual(CinematographyViewMode.shotList.systemImage, "list.bullet")
        XCTAssertEqual(CinematographyViewMode.storyboard.systemImage, "rectangle.split.3x3")
        XCTAssertEqual(CinematographyViewMode.overhead.systemImage, "arrow.up.left.and.arrow.down.right")
        XCTAssertEqual(CinematographyViewMode.settings.systemImage, "camera.aperture")
    }

    func testViewModeSystemImagesNotEmpty() {
        for mode in CinematographyViewMode.allCases {
            XCTAssertFalse(mode.systemImage.isEmpty)
        }
    }

    func testViewModeSystemImagesUnique() {
        let images = CinematographyViewMode.allCases.map { $0.systemImage }
        XCTAssertEqual(Set(images).count, images.count, "System images should be unique")
    }

    func testViewModeInitFromRawValue() {
        XCTAssertEqual(CinematographyViewMode(rawValue: "Shot List"), .shotList)
        XCTAssertEqual(CinematographyViewMode(rawValue: "Storyboard"), .storyboard)
        XCTAssertNil(CinematographyViewMode(rawValue: "unknown"))
    }

    // MARK: - CameraPreset

    func testCameraPresetInit() {
        let preset = CameraPreset(
            name: "Test Shot",
            cameraAngle: "High",
            lensMm: 35,
            aperture: "f/2.8",
            shotType: "MS",
            movement: "Dolly",
            description: "Test description"
        )

        XCTAssertEqual(preset.name, "Test Shot")
        XCTAssertEqual(preset.cameraAngle, "High")
        XCTAssertEqual(preset.lensMm, 35)
        XCTAssertEqual(preset.aperture, "f/2.8")
        XCTAssertEqual(preset.shotType, "MS")
        XCTAssertEqual(preset.movement, "Dolly")
        XCTAssertEqual(preset.description, "Test description")
        XCTAssertFalse(preset.isDefault)
    }

    func testCameraPresetDefaults() {
        let preset = CameraPreset(name: "Minimal")

        XCTAssertEqual(preset.cameraAngle, "Medium")
        XCTAssertEqual(preset.lensMm, 50)
        XCTAssertEqual(preset.aperture, "f/2.8")
        XCTAssertEqual(preset.shotType, "Standard")
        XCTAssertEqual(preset.movement, "Static")
        XCTAssertEqual(preset.description, "")
        XCTAssertFalse(preset.isDefault)
    }

    func testCameraPresetIdGenerated() {
        let a = CameraPreset(name: "A")
        let b = CameraPreset(name: "B")
        XCTAssertNotEqual(a.id, b.id, "IDs should be unique")
    }

    func testDefaultPresetsExist() {
        XCTAssertGreaterThan(CameraPreset.defaultPresets.count, 0)
    }

    func testDefaultPresetsContainExtremeCloseUp() {
        let ecu = CameraPreset.defaultPresets.first { $0.id == "extreme_close_up" }
        XCTAssertNotNil(ecu)
        XCTAssertEqual(ecu?.name, "Extreme Close-Up")
        XCTAssertEqual(ecu?.shotType, "ECU")
        XCTAssertTrue(ecu?.isDefault ?? false)
    }

    func testDefaultPresetsContainCloseUp() {
        let cu = CameraPreset.defaultPresets.first { $0.id == "close_up" }
        XCTAssertNotNil(cu)
        XCTAssertEqual(cu?.name, "Close-Up")
        XCTAssertEqual(cu?.shotType, "CU")
        XCTAssertEqual(cu?.lensMm, 85)
    }

    func testDefaultPresetsContainMediumShot() {
        let ms = CameraPreset.defaultPresets.first { $0.id == "medium_shot" }
        XCTAssertNotNil(ms)
        XCTAssertEqual(ms?.name, "Medium Shot")
        XCTAssertEqual(ms?.shotType, "MS")
        XCTAssertEqual(ms?.lensMm, 35)
    }

    func testDefaultPresetsContainWideShot() {
        let ws = CameraPreset.defaultPresets.first { $0.id == "wide_shot" }
        XCTAssertNotNil(ws)
        XCTAssertEqual(ws?.name, "Wide Shot")
        XCTAssertEqual(ws?.shotType, "WS")
    }

    func testDefaultPresetsAllMarkedDefault() {
        for preset in CameraPreset.defaultPresets {
            XCTAssertTrue(preset.isDefault, "\(preset.name) should be marked as default")
        }
    }

    func testDefaultPresetsUniqueIds() {
        let ids = CameraPreset.defaultPresets.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "Default preset IDs should be unique")
    }

    func testDefaultPresetsFieldsNotEmpty() {
        for preset in CameraPreset.defaultPresets {
            XCTAssertFalse(preset.name.isEmpty, "Preset name should not be empty")
            XCTAssertFalse(preset.cameraAngle.isEmpty)
            XCTAssertGreaterThan(preset.lensMm, 0)
            XCTAssertFalse(preset.aperture.isEmpty)
            XCTAssertFalse(preset.shotType.isEmpty)
            XCTAssertFalse(preset.movement.isEmpty)
        }
    }

    func testCameraPresetCodable() throws {
        let preset = CameraPreset(
            id: "test_preset",
            name: "Test",
            cameraAngle: "Low",
            lensMm: 24,
            aperture: "f/8",
            shotType: "WS",
            movement: "Crane",
            description: "Crane shot",
            isDefault: false
        )

        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(CameraPreset.self, from: data)

        XCTAssertEqual(decoded.id, preset.id)
        XCTAssertEqual(decoded.name, preset.name)
        XCTAssertEqual(decoded.cameraAngle, preset.cameraAngle)
        XCTAssertEqual(decoded.lensMm, preset.lensMm)
        XCTAssertEqual(decoded.aperture, preset.aperture)
        XCTAssertEqual(decoded.shotType, preset.shotType)
        XCTAssertEqual(decoded.movement, preset.movement)
        XCTAssertEqual(decoded.description, preset.description)
        XCTAssertEqual(decoded.isDefault, preset.isDefault)
    }

    func testCameraPresetHashable() {
        let a = CameraPreset(id: "same", name: "Same")
        let b = CameraPreset(id: "same", name: "Same")
        let set: Set<CameraPreset> = [a, b]
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - ImageAnnotationEditor.buildEditPrompt

    func testBuildEditPromptEmpty() {
        let result = ImageAnnotationEditor.buildEditPrompt(from: [])
        XCTAssertEqual(result, "")
    }

    func testBuildEditPromptSingleAnnotation() {
        let annotation = KeyframeAnnotation(
            normalizedX: 0.5,
            normalizedY: 0.3,
            text: "Change color to blue",
            number: 1
        )
        let result = ImageAnnotationEditor.buildEditPrompt(from: [annotation])

        XCTAssertTrue(result.contains("Edit this image"))
        XCTAssertTrue(result.contains("1."))
        XCTAssertTrue(result.contains("(50%, 30%)"))
        XCTAssertTrue(result.contains("Change color to blue"))
        XCTAssertTrue(result.contains("Keep all other areas unchanged"))
    }

    func testBuildEditPromptMultipleAnnotations() {
        let annotations = [
            KeyframeAnnotation(normalizedX: 0.1, normalizedY: 0.2, text: "Add tree", number: 1),
            KeyframeAnnotation(normalizedX: 0.8, normalizedY: 0.9, text: "Remove car", number: 2),
        ]
        let result = ImageAnnotationEditor.buildEditPrompt(from: annotations)

        XCTAssertTrue(result.contains("1."))
        XCTAssertTrue(result.contains("2."))
        XCTAssertTrue(result.contains("Add tree"))
        XCTAssertTrue(result.contains("Remove car"))
        XCTAssertTrue(result.contains("(10%, 20%)"))
        XCTAssertTrue(result.contains("(80%, 90%)"))
    }

    func testBuildEditPromptSortsByNumber() {
        let annotations = [
            KeyframeAnnotation(normalizedX: 0.5, normalizedY: 0.5, text: "Second", number: 2),
            KeyframeAnnotation(normalizedX: 0.1, normalizedY: 0.1, text: "First", number: 1),
        ]
        let result = ImageAnnotationEditor.buildEditPrompt(from: annotations)

        // "First" should appear before "Second" since sorted by number
        if let firstIdx = result.range(of: "First")?.lowerBound,
           let secondIdx = result.range(of: "Second")?.lowerBound {
            XCTAssertLessThan(firstIdx, secondIdx, "Annotations should be sorted by number")
        } else {
            XCTFail("Both annotations should appear in prompt")
        }
    }

    func testBuildEditPromptCustomContext() {
        let annotation = KeyframeAnnotation(
            normalizedX: 0.5, normalizedY: 0.5, text: "Fix lighting", number: 1
        )
        let result = ImageAnnotationEditor.buildEditPrompt(from: [annotation], context: "keyframe")

        XCTAssertTrue(result.contains("Edit this keyframe"))
        XCTAssertFalse(result.contains("Edit this image"))
    }

    func testBuildEditPromptRegionPercentages() {
        // Test edge values
        let annotation = KeyframeAnnotation(
            normalizedX: 0.0, normalizedY: 1.0, text: "Edge test", number: 1
        )
        let result = ImageAnnotationEditor.buildEditPrompt(from: [annotation])
        XCTAssertTrue(result.contains("(0%, 100%)"))
    }

    // MARK: - KeyframeAnnotation

    func testKeyframeAnnotationDefaults() {
        let annotation = KeyframeAnnotation()
        XCTAssertFalse(annotation.id.isEmpty)
        XCTAssertEqual(annotation.normalizedX, 0.5)
        XCTAssertEqual(annotation.normalizedY, 0.5)
        XCTAssertEqual(annotation.text, "")
        XCTAssertEqual(annotation.number, 1)
    }

    func testKeyframeAnnotationCustomValues() {
        let annotation = KeyframeAnnotation(
            id: "custom-id",
            normalizedX: 0.25,
            normalizedY: 0.75,
            text: "Add shadow",
            number: 3
        )
        XCTAssertEqual(annotation.id, "custom-id")
        XCTAssertEqual(annotation.normalizedX, 0.25)
        XCTAssertEqual(annotation.normalizedY, 0.75)
        XCTAssertEqual(annotation.text, "Add shadow")
        XCTAssertEqual(annotation.number, 3)
    }

    func testKeyframeAnnotationCodable() throws {
        let annotation = KeyframeAnnotation(
            normalizedX: 0.33, normalizedY: 0.67, text: "Test", number: 2
        )
        let data = try JSONEncoder().encode(annotation)
        let decoded = try JSONDecoder().decode(KeyframeAnnotation.self, from: data)

        XCTAssertEqual(decoded.id, annotation.id)
        XCTAssertEqual(decoded.normalizedX, annotation.normalizedX)
        XCTAssertEqual(decoded.normalizedY, annotation.normalizedY)
        XCTAssertEqual(decoded.text, annotation.text)
        XCTAssertEqual(decoded.number, annotation.number)
    }

    func testKeyframeAnnotationHashable() {
        let a = KeyframeAnnotation(id: "same", normalizedX: 0.5, normalizedY: 0.5, text: "A", number: 1)
        let b = KeyframeAnnotation(id: "same", normalizedX: 0.5, normalizedY: 0.5, text: "A", number: 1)
        let set: Set<KeyframeAnnotation> = [a, b]
        XCTAssertEqual(set.count, 1)
    }
}
