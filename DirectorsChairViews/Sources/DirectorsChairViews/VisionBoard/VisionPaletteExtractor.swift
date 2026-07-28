// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionPaletteExtractor.swift
//
// Vision board roadmap #2: palette-from-image. The color-script workflow
// starts from reference frames, not hand-picked hex values — one click on
// an image card yields a 4–6 swatch palette card. Deterministic histogram
// extraction (no randomized clustering) so results are stable and testable.

import AppKit

public enum VisionPaletteExtractor {

    /// Dominant colors of an image: a 4-bits-per-channel histogram over a
    /// 32×32 sample grid, buckets ranked by population and averaged, then
    /// greedily filtered so picks stay visually distinct. Falls back to
    /// plain rank order when an image is near-monochrome.
    public static func extract(from image: NSImage, count: Int = 5) -> [String] {
        guard count > 0,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              rep.pixelsWide > 0, rep.pixelsHigh > 0 else { return [] }

        let sample = 32
        var histogram: [Int: (count: Int, r: Int, g: Int, b: Int)] = [:]
        for sampleY in 0..<sample {
            for sampleX in 0..<sample {
                let x = sampleX * rep.pixelsWide / sample
                let y = sampleY * rep.pixelsHigh / sample
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                let srgb = color.usingColorSpace(.sRGB) ?? color
                let r = Int(srgb.redComponent * 255)
                let g = Int(srgb.greenComponent * 255)
                let b = Int(srgb.blueComponent * 255)
                let key = (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4)
                var entry = histogram[key] ?? (0, 0, 0, 0)
                entry.count += 1
                entry.r += r; entry.g += g; entry.b += b
                histogram[key] = entry
            }
        }

        let ranked = histogram.values
            .sorted { $0.count > $1.count }
            .map { entry -> (r: Int, g: Int, b: Int) in
                (entry.r / entry.count, entry.g / entry.count, entry.b / entry.count)
            }

        var picks: [(r: Int, g: Int, b: Int)] = []
        for candidate in ranked where picks.count < count {
            let distinct = picks.allSatisfy { pick in
                abs(pick.r - candidate.r) + abs(pick.g - candidate.g)
                    + abs(pick.b - candidate.b) > 60
            }
            if distinct { picks.append(candidate) }
        }
        // Near-monochrome images starve the distance filter — top up.
        for candidate in ranked where picks.count < count {
            if !picks.contains(where: { $0 == candidate }) {
                picks.append(candidate)
            }
        }

        return picks.map { String(format: "#%02X%02X%02X", $0.r, $0.g, $0.b) }
    }
}
