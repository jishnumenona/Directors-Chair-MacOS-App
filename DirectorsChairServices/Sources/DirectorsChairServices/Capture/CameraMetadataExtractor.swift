// DirectorsChairServices/Sources/DirectorsChairServices/Capture/CameraMetadataExtractor.swift
//
// OCR-based metadata extraction from camera viewfinder overlays.
// Reads clip name, resolution, frame rate, ISO, aperture, white balance,
// timecode, LUT, and focus mode from HDMI capture frames using Vision framework.

import Foundation
import AVFoundation
import Vision
import CoreImage
import DirectorsChairCore

// MARK: - Extracted Camera Metadata

/// Holds all metadata fields parsed from a camera viewfinder overlay via OCR
public struct ExtractedCameraMetadata {
    public var clipName: String?
    public var resolution: String?
    public var frameRate: String?
    public var iso: String?
    public var aperture: String?
    public var whiteBalance: String?
    public var timecode: String?
    public var lut: String?
    public var focusMode: String?
    public var isRecording: Bool = false

    /// All raw text strings recognized by OCR
    public var rawTexts: [String] = []

    /// Overall confidence of the extraction (0.0–1.0)
    public var confidence: Double = 0.0

    /// Whether any meaningful metadata was extracted
    public var hasData: Bool {
        clipName != nil || resolution != nil || frameRate != nil ||
        iso != nil || aperture != nil || whiteBalance != nil ||
        timecode != nil || lut != nil || focusMode != nil
    }

    /// Applies extracted metadata to a Take, only setting non-nil fields
    public func apply(to take: inout Take) {
        if let v = clipName { take.cameraClipName = v }
        if let v = resolution { take.cameraResolution = v }
        if let v = frameRate { take.cameraFrameRate = v }
        if let v = iso { take.cameraISO = v }
        if let v = aperture { take.cameraAperture = v }
        if let v = whiteBalance { take.cameraWhiteBalance = v }
        if let v = timecode { take.cameraTimecode = v }
        if let v = lut { take.cameraLUT = v }
        if let v = focusMode { take.cameraFocusMode = v }
    }
}

// MARK: - Camera Metadata Extractor

public final class CameraMetadataExtractor: @unchecked Sendable {
    public static let shared = CameraMetadataExtractor()

    private init() {}

    // MARK: - Public API

    /// Extract camera metadata from a video file by reading a frame near the start
    public func extractMetadata(fromVideoAt url: URL) async throws -> ExtractedCameraMetadata {
        let image = try await extractFrame(from: url, atTime: 0.5)
        return try await extractMetadata(fromImage: image)
    }

    /// Extract camera metadata from a CGImage (e.g. a captured frame)
    public func extractMetadata(fromImage image: CGImage) async throws -> ExtractedCameraMetadata {
        let texts = try await recognizeText(in: image)
        return parseMetadata(from: texts)
    }

    // MARK: - Frame Extraction

    private func extractFrame(from url: URL, atTime seconds: Double) async throws -> CGImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1920, height: 1080)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)

        let time = CMTime(seconds: seconds, preferredTimescale: 600)

        // Use the modern async API if available, else fallback
        if #available(macOS 13.0, *) {
            let (cgImage, _) = try await generator.image(at: time)
            return cgImage
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                var actualTime = CMTime.zero
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: &actualTime)
                    continuation.resume(returning: cgImage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - OCR Text Recognition

    private func recognizeText(in image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let texts = observations.compactMap { observation -> String? in
                    observation.topCandidates(1).first?.string
                }
                continuation.resume(returning: texts)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.01

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Metadata Parsing

    private func parseMetadata(from texts: [String]) -> ExtractedCameraMetadata {
        var metadata = ExtractedCameraMetadata()
        metadata.rawTexts = texts

        var matchCount = 0
        let totalFields = 9 // max possible fields

        let joined = texts.joined(separator: " ")

        // Clip name: Sony-style C0575, A001C005, etc.
        if let match = joined.range(of: #"[A-Z]{1,4}\d{3,5}"#, options: .regularExpression) {
            metadata.clipName = String(joined[match])
            matchCount += 1
        }

        // Resolution: 4K, UHD, HD, 1080, 2160
        for text in texts {
            if let match = text.range(of: #"\b(4K|UHD|HD|FHD|1080[pi]?|2160[pi]?|6K|8K)\b"#, options: .regularExpression) {
                metadata.resolution = String(text[match])
                matchCount += 1
                break
            }
        }

        // Frame rate: 23.98, 29.97, 59.94, or integer with p/i suffix
        for text in texts {
            if let match = text.range(of: #"\b(\d{2}\.\d{2})[pi]?\b"#, options: .regularExpression) {
                let value = String(text[match]).replacingOccurrences(of: "p", with: "").replacingOccurrences(of: "i", with: "")
                if let fps = Double(value), fps >= 10 && fps <= 250 {
                    metadata.frameRate = value
                    matchCount += 1
                    break
                }
            }
            // Integer frame rates like "24p", "30p", "60p"
            if let match = text.range(of: #"\b(\d{2,3})[pi]\b"#, options: .regularExpression) {
                let raw = String(text[match])
                let numStr = raw.replacingOccurrences(of: "p", with: "").replacingOccurrences(of: "i", with: "")
                if let fps = Int(numStr), fps >= 10 && fps <= 250 {
                    metadata.frameRate = raw
                    matchCount += 1
                    break
                }
            }
        }

        // ISO: "800EI", "ISO 800", "ISO800"
        for text in texts {
            if let match = text.range(of: #"\b\d{2,6}EI\b"#, options: .regularExpression) {
                metadata.iso = String(text[match])
                matchCount += 1
                break
            }
            if let match = text.range(of: #"\bISO\s?\d{2,6}\b"#, options: .regularExpression) {
                metadata.iso = String(text[match])
                matchCount += 1
                break
            }
        }

        // Aperture: "f/2.8", "T2.1", "F4.0", "4.3E", "4.3E/H"
        for text in texts {
            if let match = text.range(of: #"\b[fFT]/?\d+\.?\d*[EH/]*\b"#, options: .regularExpression) {
                metadata.aperture = String(text[match])
                matchCount += 1
                break
            }
            if let match = text.range(of: #"\b\d+\.\d+[EH][/H]?\b"#, options: .regularExpression) {
                metadata.aperture = String(text[match])
                matchCount += 1
                break
            }
        }

        // White balance: "3500K", "5600K", "56000K" (with K suffix, 3-5 digits)
        for text in texts {
            if let match = text.range(of: #"\b\d{3,5}K\b"#, options: .regularExpression) {
                metadata.whiteBalance = String(text[match])
                matchCount += 1
                break
            }
        }

        // Timecode: "02:44:52:01" or "02:44:52.01"
        for text in texts {
            if let match = text.range(of: #"\d{2}:\d{2}:\d{2}[:.]\d{2}"#, options: .regularExpression) {
                metadata.timecode = String(text[match])
                matchCount += 1
                break
            }
        }

        // LUT / Gamma: "LUT Off", "LUT On", "S-Log3", "s709", "S-Gamut3.Cine"
        for text in texts {
            let upper = text.uppercased()
            if upper.contains("LUT") {
                metadata.lut = text.trimmingCharacters(in: .whitespaces)
                matchCount += 1
                break
            }
            if let match = text.range(of: #"\b[Ss]-?(?:Log\d?|Gamut\d?|709|Cinetone)\b"#, options: .regularExpression) {
                metadata.lut = String(text[match])
                matchCount += 1
                break
            }
        }

        // Focus mode: MF, AF, AF-C, AF-S, DMF
        for text in texts {
            if let match = text.range(of: #"\b(MF|AF|AF-C|AF-S|DMF)\b"#, options: .regularExpression) {
                metadata.focusMode = String(text[match])
                matchCount += 1
                break
            }
        }

        // Recording status: REC or STBY
        for text in texts {
            if let _ = text.range(of: #"\b(REC|STBY)\b"#, options: .regularExpression) {
                metadata.isRecording = text.contains("REC")
                break
            }
        }

        metadata.confidence = totalFields > 0 ? Double(matchCount) / Double(totalFields) : 0.0
        return metadata
    }
}
