// VideoGenerationRequestTests.swift
//
// Wire-contract tests for POST /generate/video (server spec §5.5): the exact
// JSON body the client sends, including the reference_frames and resolution
// fields the gateway forwards to the video provider.

import XCTest
@testable import DirectorsChairServices

final class VideoGenerationRequestTests: XCTestCase {

    private func makeRequest(
        negativePrompt: String? = nil,
        startFrameBase64: String? = nil,
        endFrameBase64: String? = nil,
        referenceFrames: [ReferenceImage]? = nil,
        resolution: String? = nil
    ) -> VideoGenerationRequest {
        VideoGenerationRequest(
            prompt: "A slow dolly through a rain-slicked alley",
            provider: .google,
            durationSeconds: 6.0,
            quality: "High",
            aspectRatio: "16:9",
            fps: 24,
            cameraMotion: "Dolly",
            subjectMotion: "Walking",
            negativePrompt: negativePrompt,
            startFrameBase64: startFrameBase64,
            endFrameBase64: endFrameBase64,
            referenceFrames: referenceFrames,
            resolution: resolution,
            shotId: "shot-uuid-1",
            projectId: nil
        )
    }

    // MARK: - Base contract

    func testBodyContainsRequiredWireKeys() {
        let body = AIServiceClient.videoSubmissionBody(for: makeRequest())

        XCTAssertEqual(body["prompt"] as? String, "A slow dolly through a rain-slicked alley")
        XCTAssertEqual(body["provider"] as? String, "google")
        XCTAssertEqual(body["duration_seconds"] as? Double, 6.0)
        XCTAssertEqual(body["quality"] as? String, "High")
        XCTAssertEqual(body["aspect_ratio"] as? String, "16:9")
        XCTAssertEqual(body["fps"] as? Int, 24)
        XCTAssertEqual(body["camera_motion"] as? String, "Dolly")
        XCTAssertEqual(body["subject_motion"] as? String, "Walking")
        XCTAssertEqual(body["shot_id"] as? String, "shot-uuid-1")
    }

    func testOptionalKeysOmittedWhenAbsent() {
        let body = AIServiceClient.videoSubmissionBody(for: makeRequest())

        XCTAssertNil(body["negative_prompt"])
        XCTAssertNil(body["start_frame_base64"])
        XCTAssertNil(body["end_frame_base64"])
        XCTAssertNil(body["reference_frames"])
        XCTAssertNil(body["resolution"])
        XCTAssertNil(body["project_id"])
    }

    // MARK: - Frames

    func testStartAndEndFramesEncoded() {
        let body = AIServiceClient.videoSubmissionBody(
            for: makeRequest(startFrameBase64: "U1RBUlQ=", endFrameBase64: "RU5E"))

        XCTAssertEqual(body["start_frame_base64"] as? String, "U1RBUlQ=")
        XCTAssertEqual(body["end_frame_base64"] as? String, "RU5E")
    }

    func testReferenceFramesEncodedWithBase64MimeTypeAndLabel() throws {
        let refs = [
            ReferenceImage(base64: "QUFB", mimeType: "image/png", label: "2.5s"),
            ReferenceImage(base64: "QkJC", mimeType: "image/jpeg", label: "Mid"),
        ]
        let body = AIServiceClient.videoSubmissionBody(for: makeRequest(referenceFrames: refs))

        let encoded = try XCTUnwrap(body["reference_frames"] as? [[String: String]])
        XCTAssertEqual(encoded.count, 2)
        XCTAssertEqual(encoded[0]["base64"], "QUFB")
        XCTAssertEqual(encoded[0]["mime_type"], "image/png")
        XCTAssertEqual(encoded[0]["label"], "2.5s")
        XCTAssertEqual(encoded[1]["base64"], "QkJC")
        XCTAssertEqual(encoded[1]["mime_type"], "image/jpeg")
    }

    func testReferenceFramesCappedAtThree() throws {
        // The gateway forwards at most 3 reference images to the provider;
        // the client must not send more.
        let refs = (1...5).map { ReferenceImage(base64: "REF\($0)", label: "kf\($0)") }
        let body = AIServiceClient.videoSubmissionBody(for: makeRequest(referenceFrames: refs))

        let encoded = try XCTUnwrap(body["reference_frames"] as? [[String: String]])
        XCTAssertEqual(encoded.count, 3)
        XCTAssertEqual(encoded.map { $0["base64"] }, ["REF1", "REF2", "REF3"])
    }

    func testEmptyReferenceFramesOmitted() {
        let body = AIServiceClient.videoSubmissionBody(for: makeRequest(referenceFrames: []))
        XCTAssertNil(body["reference_frames"])
    }

    // MARK: - Resolution / negative prompt

    func testResolutionEncoded() {
        let body = AIServiceClient.videoSubmissionBody(for: makeRequest(resolution: "1080p"))
        XCTAssertEqual(body["resolution"] as? String, "1080p")
    }

    func testNegativePromptEncoded() {
        let body = AIServiceClient.videoSubmissionBody(for: makeRequest(negativePrompt: "text overlays"))
        XCTAssertEqual(body["negative_prompt"] as? String, "text overlays")
    }

    // MARK: - JSON serializability (the body must survive JSONSerialization)

    func testBodySerializesToJSON() throws {
        let refs = [ReferenceImage(base64: "QUFB", label: "Mid")]
        let body = AIServiceClient.videoSubmissionBody(
            for: makeRequest(startFrameBase64: "U1RBUlQ=", endFrameBase64: "RU5E",
                             referenceFrames: refs, resolution: "720p"))

        let data = try JSONSerialization.data(withJSONObject: body)
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(decoded["resolution"] as? String, "720p")
        XCTAssertEqual((decoded["reference_frames"] as? [[String: String]])?.first?["base64"], "QUFB")
    }
}
