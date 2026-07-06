// DirectorsChairViews/Sources/DirectorsChairViews/StoryDesign/StoryDesignPromptBuilder.swift
//
// WS6.2 — story-design image prompts as pure functions. The art-style
// directive mapping was TRIPLICATED across costume/appearance builders and
// had already started drifting; one canonical copy lives here.

import Foundation
import DirectorsChairCore

public enum StoryDesignPromptBuilder {

    /// Map the character's chosen art style to generation directives.
    public static func styleDirective(for imageStyle: String) -> String {
        switch imageStyle {
        case "Photorealistic":
            return "photorealistic, ultra-realistic photograph, natural lighting"
        case "Cinematic":
            return "cinematic still frame, dramatic movie lighting, film grain, shallow depth of field"
        case "Illustration":
            return "digital illustration, hand-drawn style, detailed line art with color"
        case "Anime":
            return "anime style, Japanese animation, cel-shaded, large expressive eyes"
        case "Comic Book":
            return "comic book art, bold ink outlines, halftone dots, vibrant colors"
        case "Watercolor":
            return "watercolor painting, soft washes, visible brush strokes, paper texture"
        case "Oil Painting":
            return "classical oil painting, rich textures, museum quality, fine brush work"
        case "3D Render":
            return "3D rendered character, CGI, Pixar-quality, subsurface scattering"
        default:
            return "photorealistic"
        }
    }

    /// Full costume-generation prompt for a character wearing a costume.
    public static func costumePrompt(character: Character, costume: CharacterCostume) -> String {
        var parts: [String] = []
        parts.append(styleDirective(for: character.imageStyle))

        parts.append("\(character.gender) character")
        if character.age > 0 { parts.append("age \(character.age)") }
        if !character.build.isEmpty { parts.append("\(character.build.lowercased()) build") }
        if !character.hairColor.isEmpty { parts.append("\(character.hairColor) hair") }
        if !character.ethnicity.isEmpty { parts.append("\(character.ethnicity) ethnicity") }

        parts.append("wearing \(costume.name)")
        if !costume.description.isEmpty { parts.append(costume.description) }

        var garments: [String] = []
        if let top = costume.garmentTop, !top.isEmpty { garments.append("top: \(top)") }
        if let bottom = costume.garmentBottom, !bottom.isEmpty { garments.append("bottom: \(bottom)") }
        if let foot = costume.footwear, !foot.isEmpty { garments.append("footwear: \(foot)") }
        if let outer = costume.outerwear, !outer.isEmpty { garments.append("outerwear: \(outer)") }
        if let head = costume.headwear, !head.isEmpty { garments.append("headwear: \(head)") }
        if !garments.isEmpty { parts.append(garments.joined(separator: ", ")) }

        if let era = costume.era { parts.append("\(era) period") }
        if let style = costume.styleCategory { parts.append("\(style) style") }
        if let palette = costume.colorPalette, !palette.isEmpty {
            parts.append("color palette: \(palette.joined(separator: ", "))")
        }
        if let fabric = costume.primaryFabric, !fabric.isEmpty {
            parts.append("\(fabric) fabric")
        }
        return parts.joined(separator: ", ")
    }
    /// Full physical-appearance prompt derived purely from the character model.
    public static func characterAppearancePrompt(character: Character) -> String {
        var parts: [String] = []

        // Art style — prepend for strongest influence on generation
        // Style mapping lives in StoryDesignPromptBuilder (WS6.2 — was triplicated).
        let styleDirective = StoryDesignPromptBuilder.styleDirective(for: character.imageStyle)
        parts.append(styleDirective)

        // Basic identity
        parts.append("\(character.gender) character")
        if character.age > 0 {
            parts.append("age \(character.age)")
        }

        // Physical build & body
        if !character.build.isEmpty {
            parts.append("\(character.build.lowercased()) build")
        }
        if let h = character.heightCm, h > 0 {
            let ft = Int(h / 30.48)
            let inches = Int((h / 2.54).truncatingRemainder(dividingBy: 12))
            parts.append("\(ft)'\(inches)\" tall")
        }

        // Facial structure
        if !character.facialStructure.isEmpty {
            parts.append("\(character.facialStructure.lowercased()) face shape")
        }

        // Skin
        if !character.skinTone.isEmpty {
            parts.append("\(character.skinTone) skin tone")
        }
        if !character.ethnicity.isEmpty {
            parts.append("\(character.ethnicity) ethnicity")
        }

        // Hair
        if !character.hairColor.isEmpty || !character.hairStyle.isEmpty || !character.hairLength.isEmpty {
            var hairParts: [String] = []
            if !character.hairColor.isEmpty { hairParts.append(character.hairColor) }
            if !character.hairLength.isEmpty { hairParts.append(character.hairLength.lowercased()) }
            if !character.hairStyle.isEmpty { hairParts.append(character.hairStyle.lowercased()) }
            parts.append(hairParts.joined(separator: " ") + " hair")
        }

        // Eyes
        if !character.eyeColorDescription.isEmpty || !character.eyeShape.isEmpty {
            var eyeParts: [String] = []
            if !character.eyeColorDescription.isEmpty { eyeParts.append(character.eyeColorDescription) }
            if !character.eyeShape.isEmpty { eyeParts.append(character.eyeShape.lowercased()) }
            parts.append(eyeParts.joined(separator: " ") + " eyes")
        }

        // Distinguishing features
        if !character.distinguishingFeatures.isEmpty {
            parts.append(character.distinguishingFeatures)
        }

        // Costume/attire — use active costume or general costume description
        if let costumes = character.costumes,
           let activeIdx = character.activeCostumeIndex,
           activeIdx < costumes.count {
            let c = costumes[activeIdx]
            var attire: [String] = []
            if let top = c.garmentTop, !top.isEmpty { attire.append(top) }
            if let bottom = c.garmentBottom, !bottom.isEmpty { attire.append(bottom) }
            if let outer = c.outerwear, !outer.isEmpty { attire.append(outer) }
            if let head = c.headwear, !head.isEmpty { attire.append(head) }
            if let foot = c.footwear, !foot.isEmpty { attire.append(foot) }
            if !attire.isEmpty {
                parts.append("wearing " + attire.joined(separator: ", "))
            }
        } else if let costume = character.costume, !costume.isEmpty {
            parts.append("wearing \(costume)")
        }

        // Occupation — influences visual portrayal
        if let occupation = character.occupation, !occupation.isEmpty {
            parts.append("occupation: \(occupation)")
        }

        // Personality — top distinctive traits influence expression/demeanor
        let dominantTraits = character.traits
            .filter { abs($0.value - 50.0) > 15 }
            .sorted { abs($0.value - 50.0) > abs($1.value - 50.0) }
            .prefix(3)
        if !dominantTraits.isEmpty {
            let traitDescs = dominantTraits.map { trait -> String in
                let level = trait.value > 50 ? "high" : "low"
                return "\(level) \(trait.key.lowercased())"
            }
            parts.append("personality: \(traitDescs.joined(separator: ", "))")
        }

        // Character role context
        if !character.role.isEmpty {
            parts.append("\(character.role.lowercased()) character")
        }

        // Brief description if available
        if !character.about.isEmpty {
            parts.append(character.about)
        }

        return parts.joined(separator: ", ")
    }

    /// Prompt for a specific turnaround angle; when a base reference image
    /// exists the model is instructed to keep the exact same person.
    public static func anglePrompt(base: String, angle: String, hasBaseImage: Bool) -> String {
        var prompt = base + ", \(angle)"
        if hasBaseImage {
            prompt += ". IMPORTANT: Generate the EXACT SAME person as shown in the reference image. Match the face, skin tone, hair, clothing, and art style precisely. This is a different angle of the same character, not a new character."
        }
        prompt += ", character turnaround sheet, consistent character appearance across all angles"
        return prompt
    }

}
