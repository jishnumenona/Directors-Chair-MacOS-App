// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionWallTexture.swift
//
// The Wall — what the wall is made of.
//
// Owner ask: "I want to be able to change the texture of the board too."
// A wall is a material (the pass-2 rule: it does not follow system
// appearance), so a texture is the whole material — surface tones, the
// grain that scrolls with the pan, the tones of the marks left by use,
// and the viewer's light. Picking them together is what stops cork
// looking like plaster painted orange.
//
// PER BOARD, stored on VisionBoardMeta.texture. nil = plaster, which is
// what every existing wall already was; unknown stored values fall back
// rather than failing the load (same rule the thread palette follows).

import SwiftUI
import AppKit

public enum VisionWallTexture: String, CaseIterable, Identifiable, Sendable {
    case plaster
    case cork
    case linen
    case felt

    public var id: String { rawValue }

    public var displayName: String { rawValue.capitalized }

    /// nil (legacy boards) and unknown values are plaster — a project
    /// from the future must open, not fail.
    public static func resolve(_ stored: String?) -> VisionWallTexture {
        stored.flatMap(VisionWallTexture.init(rawValue:)) ?? .plaster
    }

    // MARK: - Surface

    /// The wall itself, lit from the top left.
    var surface: [Color] {
        switch self {
        case .plaster: return [Color(hex: "#EDE7DA"), Color(hex: "#D8CEBA")]
        case .cork:    return [Color(hex: "#C9A167"), Color(hex: "#AD7F45")]
        case .linen:   return [Color(hex: "#E6E3DA"), Color(hex: "#D6D2C4")]
        case .felt:    return [Color(hex: "#55684F"), Color(hex: "#41523D")]
        }
    }

    /// The viewer's light. Warm shadow on the light materials; felt is
    /// dark already, so its vignette is deep green-black — a brown glow
    /// on green reads as a stain, not light.
    var vignette: Color {
        switch self {
        case .plaster, .cork, .linen: return Color(hex: "#4A3B26").opacity(0.18)
        case .felt:                   return Color(hex: "#16211A").opacity(0.30)
        }
    }

    /// How strongly the grain sits on the surface. Multiply-dark works
    /// on the light materials; on dark felt a multiplied dark speckle
    /// vanishes, so felt bakes its own light-and-dark fuzz and blends
    /// normally.
    var grainOpacity: Double {
        switch self {
        case .plaster: return 0.17
        case .cork:    return 0.34
        case .linen:   return 0.34
        case .felt:    return 0.55
        }
    }

    var grainBlend: BlendMode {
        switch self {
        case .plaster, .cork, .linen: return .multiply
        case .felt:                   return .normal
        }
    }

    // MARK: - Marks (the wall's history)

    /// Old tack holes.
    var holeTone: Color {
        switch self {
        case .plaster: return Color(hex: "#6B573A").opacity(0.30)
        case .cork:    return Color(hex: "#3E2A14").opacity(0.45)
        case .linen:   return Color(hex: "#8A7B5E").opacity(0.25)
        case .felt:    return Color(hex: "#202B20").opacity(0.45)
        }
    }

    /// Scuffs. Dark on the light materials, pale on felt — use marks a
    /// dark board the way chalk does.
    var scuffTone: Color {
        switch self {
        case .plaster: return Color(hex: "#8A7350").opacity(0.10)
        case .cork:    return Color(hex: "#7A5C33").opacity(0.12)
        case .linen:   return Color(hex: "#A99878").opacity(0.10)
        case .felt:    return Color(hex: "#DDE3D6").opacity(0.07)
        }
    }

    /// Patches where the material aged differently.
    var patchTone: Color {
        switch self {
        case .plaster: return Color(hex: "#B7A181").opacity(0.055)
        case .cork:    return Color(hex: "#8F6B3A").opacity(0.080)
        case .linen:   return Color(hex: "#CBBE9F").opacity(0.060)
        case .felt:    return Color(hex: "#C9D2C2").opacity(0.050)
        }
    }

    // MARK: - Grain

    /// One tileable grain swatch per material, generated once each.
    /// Deterministic (fixed FNV walks, never `random`) so every launch
    /// and every export looks identical.
    static func grain(for texture: VisionWallTexture) -> NSImage {
        grains[texture]!
    }

    private static let grains: [VisionWallTexture: NSImage] = {
        var built: [VisionWallTexture: NSImage] = [:]
        for texture in VisionWallTexture.allCases {
            built[texture] = makeGrain(texture)
        }
        return built
    }()

    /// Tile size in screen points — shared with VisionWallSurface's
    /// scroll phase, so the tile and its travel stay in step.
    static let tile: CGFloat = 96

    private static func makeGrain(_ texture: VisionWallTexture) -> NSImage {
        let side = Int(tile)
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()

        // Each material seeds its own walk so no two share a pattern —
        // EXCEPT plaster, whose walk must remain the pre-texture original
        // bit for bit: the existing snapshot baselines are the proof that
        // every board that existed before textures renders unchanged.
        var hash: UInt64 = 1469598103934665603
        if texture != .plaster {
            for byte in texture.rawValue.utf8 {
                hash = (hash ^ UInt64(byte)) &* 1099511628211
            }
        }

        func step(_ x: Int, _ y: Int) {
            hash = (hash ^ UInt64(truncatingIfNeeded: x &* 31 &+ y)) &* 1099511628211
        }

        switch texture {
        case .plaster:
            // The original speckle, byte-identical in spirit: sparse,
            // faint, grey.
            for y in 0..<side {
                for x in 0..<side {
                    step(x, y)
                    guard hash % 7 == 0 else { continue }
                    let alpha = Double((hash >> 8) % 40) / 400.0
                    NSColor(white: 0.35, alpha: alpha).setFill()
                    NSRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1).fill()
                }
            }
        case .cork:
            // Granules: denser dark flecks, with the occasional larger
            // crumb — cork is an aggregate, not a wash.
            for y in 0..<side {
                for x in 0..<side {
                    step(x, y)
                    if hash % 3 == 0 {
                        let alpha = Double((hash >> 8) % 50) / 340.0
                        NSColor(calibratedRed: 0.30, green: 0.19, blue: 0.08,
                                alpha: alpha).setFill()
                        NSRect(x: CGFloat(x), y: CGFloat(y),
                               width: 1, height: 1).fill()
                    }
                    if hash % 43 == 0 {
                        let alpha = Double((hash >> 9) % 30) / 260.0
                        NSColor(calibratedRed: 0.55, green: 0.40, blue: 0.20,
                                alpha: alpha).setFill()
                        NSRect(x: CGFloat(x), y: CGFloat(y),
                               width: 2, height: 2).fill()
                    }
                }
            }
        case .linen:
            // A weave: fine vertical and horizontal threads whose weight
            // varies thread to thread, plus sparse slubs.
            for x in 0..<side where x % 3 == 0 {
                step(x, 0)
                let alpha = 0.02 + Double(hash % 22) / 300.0
                NSColor(calibratedRed: 0.42, green: 0.38, blue: 0.30,
                        alpha: alpha).setFill()
                NSRect(x: CGFloat(x), y: 0, width: 1,
                       height: CGFloat(side)).fill()
            }
            for y in 0..<side where y % 3 == 0 {
                step(0, y)
                let alpha = 0.02 + Double(hash % 22) / 300.0
                NSColor(calibratedRed: 0.42, green: 0.38, blue: 0.30,
                        alpha: alpha).setFill()
                NSRect(x: 0, y: CGFloat(y), width: CGFloat(side),
                       height: 1).fill()
            }
            for y in 0..<side {
                for x in 0..<side {
                    step(x, y)
                    guard hash % 89 == 0 else { continue }
                    let alpha = Double((hash >> 8) % 26) / 300.0
                    NSColor(calibratedRed: 0.36, green: 0.33, blue: 0.26,
                            alpha: alpha).setFill()
                    NSRect(x: CGFloat(x), y: CGFloat(y),
                           width: 3, height: 1).fill()
                }
            }
        case .felt:
            // Fuzz: soft light-and-dark mottling baked into the tile
            // (blended .normal — multiplied dark speckle disappears on a
            // dark board).
            for y in 0..<side {
                for x in 0..<side {
                    step(x, y)
                    if hash % 5 == 0 {
                        let alpha = Double((hash >> 8) % 22) / 440.0
                        NSColor(calibratedRed: 0.85, green: 0.89, blue: 0.82,
                                alpha: alpha).setFill()
                        NSRect(x: CGFloat(x), y: CGFloat(y),
                               width: 1, height: 1).fill()
                    } else if hash % 11 == 0 {
                        let alpha = Double((hash >> 8) % 20) / 460.0
                        NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.10,
                                alpha: alpha).setFill()
                        NSRect(x: CGFloat(x), y: CGFloat(y),
                               width: 1, height: 1).fill()
                    }
                }
            }
        }
        image.unlockFocus()
        return image
    }
}
