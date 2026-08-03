// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionWallPalette.swift
//
// The Wall, pass 2 — the surface you pin things to.
//
// The board used to be a #1A1A1A CAD canvas with a dot grid and a
// world-origin crosshair. A vision board is a wall.
//
// The wall does NOT follow the system appearance. It is a physical object
// with its own material — plaster, lit from the top left — the way a
// lightbox is always white and a corkboard is always cork. Inverting it in
// dark mode produced a near-black surface indistinguishable from the CAD
// canvas we are leaving behind, which is exactly the complaint. The app
// chrome around it still follows the system.

import SwiftUI

public enum VisionWallPalette {

    /// Plaster, lit from the top left.
    public static let surface: [Color] = [
        Color(hex: "#EDE7DA"), Color(hex: "#D8CEBA"),
    ]

    /// A thing lying ON the wall, not a panel floating in space: a warm,
    /// soft shadow rather than flat black.
    public static let scrapShadow = Color(hex: "#4A3B26").opacity(0.32)

    /// Paper a word clipping is cut from.
    public static let clipping = Color(hex: "#F8F3E7")

    /// Ink on that paper.
    public static let ink = Color(hex: "#211E19")

    /// The one accent the wall allows itself: a grease-pencil red, for
    /// selection and nothing else.
    public static let greasePencil = Color(hex: "#C4453C")

    /// Stored text colours default to white — invisible as ink on paper.
    /// Anything near-white falls back to ink so older cards stay readable.
    public static func inkColor(fromStored hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .uppercased()
        let isNearWhite = cleaned.isEmpty || cleaned == "FFFFFF"
            || cleaned == "FFF" || cleaned == "FEFEFE" || cleaned == "FAFAFA"
        return isNearWhite ? ink : Color(hex: hex)
    }
}
