//
//  ChatVisionContext.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A0.3: lets the chat assistant SEE what the
//  user is looking at. Resolves the image of the currently selected entity
//  and re-encodes it small for the gateway's vision input, so questions like
//  "critique this frame" are answered about the actual image.
//

import AppKit
import DirectorsChairCore

enum ChatVisionContext {

    /// The relative image path for the most specific selected entity, if any.
    /// Priority mirrors selection specificity: shot → scene → character →
    /// location. Empty paths are treated as absent.
    static func imagePath(for context: AIChatContext?) -> String? {
        guard let context else { return nil }
        if let path = context.selectedShot?.previewImage, !path.isEmpty { return path }
        if let path = context.selectedScene?.sceneOverviewImage, !path.isEmpty { return path }
        if let character = context.selectedCharacter {
            if let path = character.baseImage, !path.isEmpty { return path }
            if let path = character.imageFront, !path.isEmpty { return path }
        }
        if let path = context.selectedLocation?.primaryImage, !path.isEmpty { return path }
        return nil
    }

    /// Loads the image at `url` and re-encodes it as a JPEG no larger than
    /// `maxDimension` on its longest side, base64-encoded. Deliberately small:
    /// the context image is advisory and rides every chat request that has a
    /// selection, so payload size (and vision token cost) stays bounded.
    static func downscaledJPEGBase64(at url: URL, maxDimension: CGFloat = 512) -> String? {
        guard let image = NSImage(contentsOf: url),
              image.size.width > 0, image.size.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let target = NSSize(width: max(1, (image.size.width * scale).rounded(.down)),
                            height: max(1, (image.size.height * scale).rounded(.down)))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(target.width), pixelsHigh: Int(target.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        guard let jpeg = bitmap.representation(
            using: .jpeg, properties: [.compressionFactor: 0.6]) else { return nil }
        return jpeg.base64EncodedString()
    }
}
