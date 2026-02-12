//
//  CharacterReferenceHelper.swift
//  DirectorsChairViews
//
//  Loads character base images and converts to base64 for use as
//  reference images in AI image generation, enabling visual consistency.
//

import AppKit
import DirectorsChairCore

public enum CharacterReferenceHelper {

    /// Get base64 reference image for the primary character in a scene.
    /// The primary character is determined by dialogue line count (most lines first).
    /// Falls back through baseImage → imageFront for each character.
    public static func referenceImage(
        forScene scene: DirectorsChairCore.Scene,
        characters: [Character],
        projectDirectory: URL?
    ) -> (base64: String, mimeType: String)? {
        guard let projectDir = projectDirectory else { return nil }

        // Count dialogue lines per character, sort descending
        var dialogueCounts: [String: Int] = [:]
        for dialogue in scene.dialogues {
            let name = dialogue.character
            if !name.isEmpty {
                dialogueCounts[name, default: 0] += 1
            }
        }

        let sortedNames = dialogueCounts.sorted { $0.value > $1.value }.map(\.key)

        // Try each character in order of prominence
        for name in sortedNames {
            guard let character = characters.first(where: {
                $0.name.lowercased() == name.lowercased()
            }) else { continue }

            if let result = referenceImage(forCharacter: character, projectDirectory: projectDir) {
                return result
            }
        }

        return nil
    }

    /// Get base64 reference image for a specific character.
    /// Checks baseImage first, then imageFront as fallback.
    public static func referenceImage(
        forCharacter character: Character,
        projectDirectory: URL
    ) -> (base64: String, mimeType: String)? {
        // Try baseImage first, then imageFront
        let candidates = [character.baseImage, character.imageFront]

        for imagePath in candidates {
            guard let path = imagePath, !path.isEmpty else { continue }

            let imageURL = projectDirectory.appendingPathComponent(path)
            guard let image = NSImage(contentsOf: imageURL) else { continue }

            if let base64 = resizeAndEncodeImage(image, maxDimension: 512) {
                return (base64: base64, mimeType: "image/png")
            }
        }

        return nil
    }

    // MARK: - Private

    /// Resize image to fit within maxDimension and encode as base64 PNG.
    private static func resizeAndEncodeImage(_ image: NSImage, maxDimension: CGFloat) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        let originalWidth = CGFloat(bitmap.pixelsWide)
        let originalHeight = CGFloat(bitmap.pixelsHigh)

        guard originalWidth > 0, originalHeight > 0 else { return nil }

        // Calculate scaled size
        let scale: CGFloat
        if originalWidth > maxDimension || originalHeight > maxDimension {
            scale = maxDimension / max(originalWidth, originalHeight)
        } else {
            scale = 1.0
        }

        let newWidth = Int(originalWidth * scale)
        let newHeight = Int(originalHeight * scale)

        // Create resized bitmap
        guard let resized = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: newWidth,
            pixelsHigh: newHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: resized) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high

        bitmap.draw(in: NSRect(x: 0, y: 0, width: newWidth, height: newHeight))
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = resized.representation(using: .png, properties: [:]) else { return nil }
        return pngData.base64EncodedString()
    }
}
