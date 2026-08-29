// DirectorsChairServices/AI/ImageTargetSize.swift
//
// DC-0090: one delivered size for generated previews. The project's
// PreviewResolution becomes an ImageTargetSize; the request carries it;
// the cloud body sends the shape and size class the model understands;
// the on-device engine draws the same shape at a RAM-safe scale; and every
// picture is resampled to EXACTLY the target before it leaves the client —
// so a shot, a scene and a location preview are the same size whatever
// provider drew them.

import CoreGraphics
import DirectorsChairCore
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ImageTargetSize: Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
    }

    public init(_ resolution: PreviewResolution) {
        self.init(width: resolution.width, height: resolution.height)
    }

    /// The project-wide preview size — what every shot/scene/location
    /// generation asks for. Set from the open project by the app.
    public static var projectPreview: ImageTargetSize { ProjectImageDefaults.shared.previewSize }

    /// The aspect string the wire and the on-device engine speak, chosen as
    /// the closest of the shapes the app supports.
    public var aspectRatio: String {
        let ratio = Double(width) / Double(height)
        let known: [(String, Double)] = [("16:9", 16.0 / 9.0), ("9:16", 9.0 / 16.0), ("1:1", 1),
                                         ("4:3", 4.0 / 3.0), ("3:4", 3.0 / 4.0)]
        return known.min { abs($0.1 - ratio) < abs($1.1 - ratio) }!.0
    }

    /// Gemini's size classes ("1K" | "2K" | "4K"), by the longer side.
    /// Full HD asks for 2K and is scaled down — sharper than 1K scaled up.
    public var cloudSizeClass: String {
        let longest = max(width, height)
        if longest <= 1400 { return "1K" }
        if longest <= 2800 { return "2K" }
        return "4K"
    }

    /// The frame the on-device engine draws for this target: the same shape,
    /// its area capped (a 4B diffusion model at 1920×1080 is a memory bill,
    /// not a picture), sides multiples of 16 for the latent grid, never
    /// below 256. The resampler then takes it to the exact target.
    public func onDeviceFrame(maxArea: Int) -> (width: Int, height: Int) {
        let area = Double(width * height)
        let scale = min(1, (Double(maxArea) / area).squareRoot())
        func snap(_ side: Int) -> Int { max(256, 16 * Int((Double(side) * scale / 16).rounded())) }
        return (snap(width), snap(height))
    }

    /// Mirrors KleinCore.maxReferenceArea — the RAM-scaled pixel budget the
    /// engine already applies to reference pictures (DC-0070).
    public static var onDeviceMaxArea: Int {
        let gib = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        if gib >= 30 { return 1024 * 1024 }
        if gib >= 20 { return 832 * 832 }
        return 640 * 640
    }
}

/// The open project's generation defaults, readable from package code that
/// never sees the Project (the same pattern as AIProviderSelection): the
/// app sets it whenever the project changes.
public final class ProjectImageDefaults: @unchecked Sendable {
    public static let shared = ProjectImageDefaults()
    private let lock = NSLock()
    private var _previewSize = ImageTargetSize(PreviewResolution.default)

    public var previewSize: ImageTargetSize {
        get { lock.lock(); defer { lock.unlock() }; return _previewSize }
        set { lock.lock(); _previewSize = newValue; lock.unlock() }
    }
}

/// Exact-size delivery of generated pictures (PNG out, sRGB).
public enum ImageResampler {
    /// Pixel dimensions of an encoded picture, nil if it doesn't decode.
    public static func dimensions(of data: Data) -> (width: Int, height: Int)? {
        guard let image = decode(data) else { return nil }
        return (image.width, image.height)
    }

    /// The picture at exactly `size`: scaled to cover, centred, the overflow
    /// cropped (a 1344×768 answer to a 1920×1080 ask loses 1.5% at the
    /// sides, a square loses its top and bottom). Same size in = same bytes
    /// out. nil only when the data isn't a picture.
    public static func resample(_ data: Data, to size: ImageTargetSize) -> Data? {
        guard let image = decode(data) else { return nil }
        if image.width == size.width && image.height == size.height { return data }
        guard let context = canvas(size) else { return nil }
        context.draw(image, in: coverRect(source: image, in: size))
        return encodePNG(context)
    }

    /// An on-device repaint of `source` (DC-0069 keeps every pixel outside
    /// the marked spots): the edited picture is scaled onto the source's
    /// own grid INSIDE the regions only, so the untouched pixels stay the
    /// source's exact pixels at the source's exact size.
    public static func merge(edited: Data, ontoSource source: Data, regions: [EditRegion]) -> Data? {
        guard let base = decode(source), let paint = decode(edited) else { return nil }
        guard !regions.isEmpty else { return edited }
        let size = ImageTargetSize(width: base.width, height: base.height)
        guard let context = canvas(size) else { return nil }
        let full = CGRect(x: 0, y: 0, width: base.width, height: base.height)
        context.draw(base, in: full)
        context.saveGState()
        let shorter = Double(min(base.width, base.height))
        let path = CGMutablePath()
        for region in regions {
            let radius = region.radius * shorter
            // Regions are top-left normalised; CoreGraphics is bottom-left.
            let centre = CGPoint(x: region.x * Double(base.width), y: (1 - region.y) * Double(base.height))
            path.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                       width: radius * 2, height: radius * 2))
        }
        context.addPath(path)
        context.clip()
        context.draw(paint, in: full)
        context.restoreGState()
        return encodePNG(context)
    }

    // MARK: - Helpers

    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func canvas(_ size: ImageTargetSize) -> CGContext? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: size.width, height: size.height,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        return context
    }

    private static func coverRect(source: CGImage, in size: ImageTargetSize) -> CGRect {
        let scale = max(Double(size.width) / Double(source.width), Double(size.height) / Double(source.height))
        let width = Double(source.width) * scale
        let height = Double(source.height) * scale
        return CGRect(x: (Double(size.width) - width) / 2, y: (Double(size.height) - height) / 2,
                      width: width, height: height)
    }

    private static func encodePNG(_ context: CGContext) -> Data? {
        guard let image = context.makeImage() else { return nil }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }
}
