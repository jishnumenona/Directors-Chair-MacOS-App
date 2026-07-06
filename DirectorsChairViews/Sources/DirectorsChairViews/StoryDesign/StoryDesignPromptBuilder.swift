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
}
