// DirectorsChairServices/AI/PCMWAVWrapper.swift
//
// Gemini TTS returns raw 16-bit mono 24kHz PCM; the gateway forwards it
// labeled audio/wav without a RIFF container, so AVAudioPlayer (and any
// standard decoder) rejects it. This wraps headerless PCM in a minimal
// 44-byte WAV header; data that already has a RIFF header passes
// through untouched (safe for when the gateway starts wrapping too).

import Foundation

public enum PCMWAVWrapper {

    public static let geminiSampleRate: UInt32 = 24_000

    public static func wrapIfNeeded(_ data: Data,
                                    sampleRate: UInt32 = geminiSampleRate,
                                    channels: UInt16 = 1,
                                    bitsPerSample: UInt16 = 16) -> Data {
        guard !data.isEmpty, !hasRIFFHeader(data) else { return data }
        return wavHeader(dataLength: UInt32(data.count),
                         sampleRate: sampleRate,
                         channels: channels,
                         bitsPerSample: bitsPerSample) + data
    }

    public static func hasRIFFHeader(_ data: Data) -> Bool {
        data.count >= 12
            && data.prefix(4) == Data("RIFF".utf8)
            && data.subdata(in: 8..<12) == Data("WAVE".utf8)
    }

    static func wavHeader(dataLength: UInt32, sampleRate: UInt32,
                          channels: UInt16, bitsPerSample: UInt16) -> Data {
        let bytesPerFrame = UInt32(channels) * UInt32(bitsPerSample / 8)
        var header = Data()
        header.append(Data("RIFF".utf8))
        header.appendLE(36 + dataLength)
        header.append(Data("WAVE".utf8))
        header.append(Data("fmt ".utf8))
        header.appendLE(UInt32(16))                    // PCM chunk size
        header.appendLE(UInt16(1))                     // linear PCM
        header.appendLE(channels)
        header.appendLE(sampleRate)
        header.appendLE(sampleRate * bytesPerFrame)    // byte rate
        header.appendLE(UInt16(bytesPerFrame))         // block align
        header.appendLE(bitsPerSample)
        header.append(Data("data".utf8))
        header.appendLE(dataLength)
        return header
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt32) {
        var little = value.littleEndian
        append(Data(bytes: &little, count: 4))
    }

    mutating func appendLE(_ value: UInt16) {
        var little = value.littleEndian
        append(Data(bytes: &little, count: 2))
    }
}
