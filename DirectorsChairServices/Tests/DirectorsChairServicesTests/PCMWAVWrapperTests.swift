// DirectorsChairServicesTests/PCMWAVWrapperTests.swift
//
// Gemini TTS headerless-PCM fix: the wrapper must produce a decodable
// WAV and never double-wrap.

import XCTest
import AVFoundation
@testable import DirectorsChairServices

final class PCMWAVWrapperTests: XCTestCase {

    func testWrapsHeaderlessPCMIntoDecodableWAV() throws {
        // 0.1s of silence: 24kHz * 0.1 * 2 bytes.
        let pcm = Data(count: 4_800)
        let wav = PCMWAVWrapper.wrapIfNeeded(pcm)

        XCTAssertEqual(wav.count, pcm.count + 44)
        XCTAssertTrue(PCMWAVWrapper.hasRIFFHeader(wav))

        // The proof: AVAudioPlayer decodes it (it rejected the raw PCM).
        XCTAssertThrowsError(try AVAudioPlayer(data: pcm))
        let player = try AVAudioPlayer(data: wav)
        XCTAssertEqual(player.duration, 0.1, accuracy: 0.01)
    }

    func testRIFFDataPassesThroughUntouched() {
        let pcm = Data(count: 480)
        let wav = PCMWAVWrapper.wrapIfNeeded(pcm)
        XCTAssertEqual(PCMWAVWrapper.wrapIfNeeded(wav), wav,
                       "no double-wrap when the gateway starts wrapping")
        XCTAssertEqual(PCMWAVWrapper.wrapIfNeeded(Data()), Data())
    }
}
