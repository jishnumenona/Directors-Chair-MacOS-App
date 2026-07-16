//
//  CharacterReferenceHelper.swift
//  DirectorsChairViews
//
//  Collects all visual reference images (location, characters, costumes) for
//  a scene and returns them as labeled ReferenceImage objects. Each image is
//  sent as a separate inline_data part to Gemini so the AI can see the exact
//  location, character faces, and costumes when generating shot previews.
//

import AppKit
import DirectorsChairCore
import DirectorsChairServices

public enum CharacterReferenceHelper {

    // MARK: - Multi-Image Reference Collection

    /// Collect all relevant reference images for a scene: location, characters,
    /// and their active costumes. Each image is labeled so the prompt can
    /// reference it (e.g. "Image 1 is the location", "Image 2 is character X").
    /// Returns an empty array if no images are found.
    public static func collectReferenceImages(
        forScene scene: DirectorsChairCore.Scene,
        characters: [Character],
        locations: [Location],
        projectDirectory: URL?
    ) -> [ReferenceImage] {
        guard let projectDir = projectDirectory else { return [] }
        var refs: [ReferenceImage] = []

        // 1. Location image
        if let locationImage = loadLocationImage(
            forScene: scene,
            locations: locations,
            projectDirectory: projectDir
        ) {
            if let base64 = resizeAndEncodeImage(locationImage, maxDimension: 768) {
                let locationName = scene.location ?? "location"
                refs.append(ReferenceImage(
                    base64: base64,
                    mimeType: "image/png",
                    label: "location:\(locationName)"
                ))
            }
        }

        // 2. Character face images + active costume images (up to 3 characters)
        let prominentCharacters = prominentCharactersInScene(scene, allCharacters: characters, max: 3)
        for character in prominentCharacters {
            // Character face/base image
            if let charImage = loadCharacterImage(character, projectDirectory: projectDir) {
                if let base64 = resizeAndEncodeImage(charImage, maxDimension: 512) {
                    refs.append(ReferenceImage(
                        base64: base64,
                        mimeType: "image/png",
                        label: "character:\(character.name)"
                    ))
                }
            }

            // Costume the character wears in THIS scene (assignment-aware)
            if let costumeImage = loadCostumeImage(character, scene: scene, projectDirectory: projectDir) {
                if let base64 = resizeAndEncodeImage(costumeImage, maxDimension: 512) {
                    let costumeName = ShotPromptBuilder.assignedCostume(for: character, in: scene)?.name ?? "default"
                    refs.append(ReferenceImage(
                        base64: base64,
                        mimeType: "image/png",
                        label: "costume:\(character.name):\(costumeName)"
                    ))
                }
            }
        }

        return refs
    }

    /// Build the prompt prefix that tells the AI what each reference image is.
    /// Call this and prepend it to your shot prompt when referenceImages is non-empty.
    public static func buildReferenceImagePromptPrefix(for refs: [ReferenceImage]) -> String {
        guard !refs.isEmpty else { return "" }

        var lines: [String] = []
        lines.append("You are given \(refs.count) reference image(s) that define the visual identity of this shot. You MUST faithfully reproduce the appearance of each element shown:")

        for (i, ref) in refs.enumerated() {
            let parts = ref.label.split(separator: ":", maxSplits: 1)
            let type = parts.first.map(String.init) ?? "reference"
            let name = parts.count > 1 ? String(parts[1]) : ""

            switch type {
            case "location":
                lines.append("- Image \(i + 1) is the LOCATION (\(name)). The generated shot MUST take place inside this exact environment. Match the room layout, architecture, furniture, decor, props, lighting, and atmosphere precisely. Do NOT change the setting.")
            case "character":
                lines.append("- Image \(i + 1) is character \(name). Match their face, skin tone, hair color/style, and overall appearance exactly.")
            case "costume":
                let costumeParts = name.split(separator: ":", maxSplits: 1)
                let charName = costumeParts.first.map(String.init) ?? ""
                let costName = costumeParts.count > 1 ? String(costumeParts[1]) : "costume"
                lines.append("- Image \(i + 1) is the costume \"\(costName)\" worn by \(charName). Match the clothing, colors, textures, and style exactly.")
            default:
                lines.append("- Image \(i + 1) is a reference for \(name). Match it faithfully.")
            }
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Legacy Single-Image API (backward compat)

    /// Get base64 reference image for the primary character in a scene.
    public static func referenceImage(
        forScene scene: DirectorsChairCore.Scene,
        characters: [Character],
        projectDirectory: URL?
    ) -> (base64: String, mimeType: String)? {
        guard let projectDir = projectDirectory else { return nil }

        let sorted = prominentCharactersInScene(scene, allCharacters: characters, max: 1)
        for character in sorted {
            if let result = referenceImage(forCharacter: character, projectDirectory: projectDir) {
                return result
            }
        }
        return nil
    }

    /// Get base64 reference image for a specific character.
    public static func referenceImage(
        forCharacter character: Character,
        projectDirectory: URL
    ) -> (base64: String, mimeType: String)? {
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

    // MARK: - Image Loading

    /// Load the primary location image for a scene.
    /// Filename patterns to search for in a location's asset folder, ordered by
    /// preference. When the scene declares a time of day, its matching AI
    /// variation (e.g. "golden_hour", "night") is preferred over the generic
    /// hero image so the reference matches the scene's light. Pure — tested.
    static func locationImagePatterns(timeOfDay: String?) -> [String] {
        var patterns = ["primary", "main", "hero", "day", "wide", "establishing"]
        if let tod = timeOfDay?.trimmingCharacters(in: .whitespaces), !tod.isEmpty {
            let key = tod.lowercased().replacingOccurrences(of: " ", with: "_")
            patterns.removeAll { $0 == key }
            patterns.insert(key, at: 0)
        }
        return patterns
    }

    private static func loadLocationImage(
        forScene scene: DirectorsChairCore.Scene,
        locations: [Location],
        projectDirectory: URL
    ) -> NSImage? {
        guard let locationName = scene.location, !locationName.isEmpty else { return nil }

        let sanitized = sanitizeLocationName(locationName)
        let locationFolder = projectDirectory
            .appendingPathComponent("assets")
            .appendingPathComponent("locations")
            .appendingPathComponent(sanitized)
        let patterns = locationImagePatterns(timeOfDay: scene.timeOfDay)

        // 1. A scene with an explicit time of day prefers the matching
        //    variation image over the location's generic primary image.
        if let tod = scene.timeOfDay, !tod.isEmpty,
           let variation = findImageInFolder(locationFolder, patterns: [patterns[0]]) {
            return variation
        }

        // 2. Try the Location model's primaryImage / images array
        if let location = locations.first(where: {
            $0.name.lowercased() == locationName.lowercased()
        }) {
            if let primaryPath = location.primaryImage, !primaryPath.isEmpty {
                let url = projectDirectory.appendingPathComponent(primaryPath)
                if let image = NSImage(contentsOf: url) { return image }
            }
            for imgPath in location.images {
                let url = projectDirectory.appendingPathComponent(imgPath)
                if let image = NSImage(contentsOf: url) { return image }
            }
        }

        // 3. Discover from assets/locations/{sanitized_name}/
        if let found = findImageInFolder(locationFolder, patterns: patterns) {
            return found
        }
        if let found = findFirstImageInFolder(locationFolder) {
            return found
        }
        return nil
    }

    /// Load a character's face/base image.
    private static func loadCharacterImage(_ character: Character, projectDirectory: URL) -> NSImage? {
        let candidates = [character.baseImage, character.imageFront]
        for imagePath in candidates {
            guard let path = imagePath, !path.isEmpty else { continue }
            let url = projectDirectory.appendingPathComponent(path)
            if let image = NSImage(contentsOf: url) { return image }
        }
        return nil
    }

    /// Load the front image of the costume the character wears in this scene
    /// (scene assignment → active costume → first costume).
    private static func loadCostumeImage(_ character: Character,
                                         scene: DirectorsChairCore.Scene?,
                                         projectDirectory: URL) -> NSImage? {
        guard let costume = ShotPromptBuilder.assignedCostume(for: character, in: scene) else {
            // No costume records — fall back to costume-transformed character images
            let charCostumeCandidates = [character.costumeImageFront, character.costumeImageThreeQuarterLeft]
            for imagePath in charCostumeCandidates {
                guard let path = imagePath, !path.isEmpty else { continue }
                let url = projectDirectory.appendingPathComponent(path)
                if let image = NSImage(contentsOf: url) { return image }
            }
            return nil
        }

        // Try costume image paths
        let candidates = [costume.imageFront, costume.imageFullBody, costume.imageThreeQuarterLeft]
        for imagePath in candidates {
            guard let path = imagePath, !path.isEmpty else { continue }
            let url = projectDirectory.appendingPathComponent(path)
            if let image = NSImage(contentsOf: url) { return image }
        }

        // Fall back to character's costume-transformed images
        let charCostumeCandidates = [character.costumeImageFront, character.costumeImageThreeQuarterLeft]
        for imagePath in charCostumeCandidates {
            guard let path = imagePath, !path.isEmpty else { continue }
            let url = projectDirectory.appendingPathComponent(path)
            if let image = NSImage(contentsOf: url) { return image }
        }

        return nil
    }

    /// Return the most prominent characters in a scene by dialogue count.
    private static func prominentCharactersInScene(
        _ scene: DirectorsChairCore.Scene,
        allCharacters: [Character],
        max limit: Int
    ) -> [Character] {
        var dialogueCounts: [String: Int] = [:]
        for dialogue in scene.dialogues {
            let name = dialogue.character
            if !name.isEmpty {
                dialogueCounts[name, default: 0] += 1
            }
        }

        let sortedNames = dialogueCounts.sorted { $0.value > $1.value }.map(\.key)
        var result: [Character] = []

        for name in sortedNames {
            if result.count >= limit { break }
            if let character = allCharacters.first(where: { $0.name.lowercased() == name.lowercased() }) {
                result.append(character)
            }
        }
        return result
    }

    // MARK: - File Discovery Helpers

    public static func sanitizeLocationName(_ name: String) -> String {
        var sanitized = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")

        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        return sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private static func findImageInFolder(_ folder: URL, patterns: [String]) -> NSImage? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path),
              let contents = try? fm.contentsOfDirectory(atPath: folder.path) else { return nil }

        for filename in contents {
            let lower = filename.lowercased()
            guard lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") else { continue }
            for pattern in patterns {
                if lower.contains(pattern) {
                    let url = folder.appendingPathComponent(filename)
                    if let image = NSImage(contentsOf: url) { return image }
                }
            }
        }
        return nil
    }

    private static func findFirstImageInFolder(_ folder: URL) -> NSImage? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path),
              let contents = try? fm.contentsOfDirectory(atPath: folder.path) else { return nil }

        for filename in contents {
            let lower = filename.lowercased()
            guard lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") else { continue }
            let url = folder.appendingPathComponent(filename)
            if let image = NSImage(contentsOf: url) { return image }
        }
        return nil
    }

    // MARK: - Image Encoding

    private static func resizeAndEncodeImage(_ image: NSImage, maxDimension: CGFloat) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        let originalWidth = CGFloat(bitmap.pixelsWide)
        let originalHeight = CGFloat(bitmap.pixelsHigh)
        guard originalWidth > 0, originalHeight > 0 else { return nil }

        let scale: CGFloat
        if originalWidth > maxDimension || originalHeight > maxDimension {
            scale = maxDimension / max(originalWidth, originalHeight)
        } else {
            scale = 1.0
        }

        let newWidth = Int(originalWidth * scale)
        let newHeight = Int(originalHeight * scale)

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
