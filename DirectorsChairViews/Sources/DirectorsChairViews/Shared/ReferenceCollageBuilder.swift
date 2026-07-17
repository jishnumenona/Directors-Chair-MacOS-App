//
// ReferenceCollageBuilder.swift
//
// Veo accepts at most 3 reference images, so story-design imagery is packed
// into collages: one grid of every character in the shot, one of the location
// (and, once they have imagery, its props). Cells are square, aspect-fit on a
// dark background, laid out in a near-square grid.
//

import AppKit

enum ReferenceCollageBuilder {

    /// Grid shape for a given image count: near-square, wider than tall.
    /// Pure — tested.
    static func gridDimensions(for count: Int) -> (columns: Int, rows: Int) {
        guard count > 1 else { return (1, 1) }
        let columns = Int(ceil(Double(count).squareRoot()))
        let rows = Int(ceil(Double(count) / Double(columns)))
        return (columns, rows)
    }

    /// Compose images into a single collage. One image returns itself; nil for
    /// an empty input.
    static func collage(_ images: [NSImage], maxDimension: CGFloat = 1536) -> NSImage? {
        guard !images.isEmpty else { return nil }
        if images.count == 1 { return images[0] }

        let (columns, rows) = gridDimensions(for: images.count)
        let cell = floor(maxDimension / CGFloat(columns))
        let width = Int(cell) * columns
        let height = Int(cell) * rows

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high

        NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        for (index, image) in images.enumerated() {
            let column = index % columns
            // Row 0 at the top (bitmap origin is bottom-left).
            let row = rows - 1 - (index / columns)
            let cellRect = NSRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell,
                                  width: cell, height: cell).insetBy(dx: 4, dy: 4)

            let size = image.size
            guard size.width > 0, size.height > 0 else { continue }
            let scale = min(cellRect.width / size.width, cellRect.height / size.height)
            let drawSize = NSSize(width: size.width * scale, height: size.height * scale)
            let drawRect = NSRect(
                x: cellRect.midX - drawSize.width / 2,
                y: cellRect.midY - drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        let result = NSImage(size: NSSize(width: width, height: height))
        result.addRepresentation(bitmap)
        return result
    }

    /// PNG-encode a collage for the wire.
    static func encodePNG(_ image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return png.base64EncodedString()
    }
}
