// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionImagine.swift
//
// The Imagine panel's request (DC-0034) — what a generation actually asks
// for, instead of a bare string.
//
// The service layer has supported aspect ratio, variation count, and
// labeled reference images all along (ImageGenerationRequest); no UI ever
// passed them. This type is the wall's side of that contract: validated
// here so the panel can't send the gateway a ratio it doesn't speak or a
// count that bills absurdly.

import Foundation

public struct ImagineRequest: Equatable, Sendable {
    /// The ratios the image gateway speaks (Gemini image API set).
    public static let aspectRatios = ["16:9", "1:1", "9:16", "4:3", "3:4"]
    public static let maxVariations = 4

    public var prompt: String
    public private(set) var aspectRatio: String
    public private(set) var variationCount: Int
    /// Pictures riding along as references — the model steers toward
    /// them instead of inventing from nothing.
    public var referenceURLs: [URL]

    public init(prompt: String,
                aspectRatio: String = "16:9",
                variationCount: Int = 1,
                referenceURLs: [URL] = []) {
        self.prompt = prompt
        // Unknown ratio = the default, never a gateway error downstream.
        self.aspectRatio = Self.aspectRatios.contains(aspectRatio)
            ? aspectRatio : "16:9"
        self.variationCount = min(max(variationCount, 1), Self.maxVariations)
        self.referenceURLs = referenceURLs
    }

    /// The held-space placeholder's shape while the picture is imagined —
    /// matching the ratio that was asked for, so the wall doesn't jump
    /// when the real picture lands.
    public var placeholderSize: CGSize {
        let width: CGFloat = 260
        let parts = aspectRatio.split(separator: ":").compactMap {
            Double($0)
        }
        guard parts.count == 2, parts[0] > 0 else {
            return CGSize(width: width, height: 146)
        }
        return CGSize(width: width,
                      height: width * parts[1] / parts[0])
    }
}
