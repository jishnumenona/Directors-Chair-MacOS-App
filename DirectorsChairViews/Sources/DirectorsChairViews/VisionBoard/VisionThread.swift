// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionThread.swift
//
// The Wall — what the cord is made of.
//
// Every thread on the board was the same crimson, which is fine for one
// connection and useless for six: colour is how a physical board carries
// meaning without labels. One colour per line of thinking — red for the
// through-line, blue for a second timeline, jute for "maybe".
//
// These are dyed twines, not UI accents. Each carries four tones, because
// the cord is drawn as a round body rather than a stroke: the dyed fibre
// itself, the lit top edge, and two twist tones that read as strands
// wound together. Picking them together here is what keeps a green cord
// from looking like a green line.

import SwiftUI

public enum VisionThread: String, CaseIterable, Identifiable, Sendable {
    case crimson
    case ink
    case navy
    case forest
    case mustard
    case jute
    case cotton
    case violet

    public var id: String { rawValue }

    /// Old boards have no thread colour stored, and every one of their
    /// cords was crimson — so that stays the default.
    public static func resolve(_ raw: String?) -> VisionThread {
        raw.flatMap(VisionThread.init(rawValue:)) ?? .crimson
    }

    public var displayName: String {
        switch self {
        case .crimson: return "Crimson"
        case .ink: return "Ink"
        case .navy: return "Navy"
        case .forest: return "Forest"
        case .mustard: return "Mustard"
        case .jute: return "Jute"
        case .cotton: return "Cotton"
        case .violet: return "Violet"
        }
    }

    /// The dyed fibre.
    public var cord: Color {
        switch self {
        case .crimson: return Color(hex: "#8E2C24")
        case .ink: return Color(hex: "#26241F")
        case .navy: return Color(hex: "#243A5E")
        case .forest: return Color(hex: "#2C4A33")
        case .mustard: return Color(hex: "#A8801F")
        case .jute: return Color(hex: "#A88C5F")
        case .cotton: return Color(hex: "#E4DCCB")
        case .violet: return Color(hex: "#4E2F5E")
        }
    }

    /// The top edge, where the light catches the twist.
    public var lit: Color {
        switch self {
        case .crimson: return Color(hex: "#E0796A")
        case .ink: return Color(hex: "#6E6A60")
        case .navy: return Color(hex: "#6E8CBF")
        case .forest: return Color(hex: "#6E9B76")
        case .mustard: return Color(hex: "#E8C766")
        case .jute: return Color(hex: "#DCC79B")
        case .cotton: return Color(hex: "#FFFFFF")
        case .violet: return Color(hex: "#9873AB")
        }
    }

    /// The shadowed side of each strand.
    public var twistShade: Color {
        switch self {
        case .crimson: return Color(hex: "#5E1A14")
        case .ink: return Color(hex: "#0E0D0B")
        case .navy: return Color(hex: "#14213A")
        case .forest: return Color(hex: "#182B1D")
        case .mustard: return Color(hex: "#6B4E0C")
        case .jute: return Color(hex: "#6E5836")
        case .cotton: return Color(hex: "#A89C85")
        case .violet: return Color(hex: "#2E192F")
        }
    }

    /// The lit side of each strand.
    public var twistLight: Color {
        switch self {
        case .crimson: return Color(hex: "#C9584A")
        case .ink: return Color(hex: "#4A4740")
        case .navy: return Color(hex: "#47679E")
        case .forest: return Color(hex: "#4C7355")
        case .mustard: return Color(hex: "#CFA843")
        case .jute: return Color(hex: "#C4AC7D")
        case .cotton: return Color(hex: "#F7F2E6")
        case .violet: return Color(hex: "#77517F")
        }
    }

    /// Pale cotton needs a heavier cast than dark twine or it floats off
    /// the plaster; dark cord needs less or the shadow reads as a smudge.
    public var castOpacity: Double {
        switch self {
        case .cotton: return 0.30
        case .ink: return 0.16
        default: return 0.22
        }
    }
}
