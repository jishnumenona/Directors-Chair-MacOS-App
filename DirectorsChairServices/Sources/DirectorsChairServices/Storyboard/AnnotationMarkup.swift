import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Owner regression 2026-08-29: annotation edits came back unchanged. Probed on
// the live model with the owner's own pictures: told a spot in percentages
// ("at 30% across, 42% down"), Gemini returned the picture untouched or
// changed the wrong person; shown the same picture with a numbered red circle
// at the spot, it edited exactly that person and dropped the marker from its
// output. So a cloud edit travels as a MARKED COPY of the picture and the
// instructions name each change by its circle. The on-device repaint never
// sees the markers — it inpaints the clean source inside the regions.

/// Draws the numbered circles of an edit onto a copy of its picture.
public enum AnnotationMarkup {
    /// A PNG copy of `source` with a red circle (the pin's reach) and a
    /// numbered badge at every spot pin. nil when there are no spot pins or
    /// the picture can't be decoded — callers then fall back to positions in
    /// words.
    public static func marked(source: Data, pins: [AnnotationPin]) -> Data? {
        let spots = pins.filter { !$0.coversWholePicture }
        guard !spots.isEmpty,
              let imageSource = CGImageSourceCreateWithData(source as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { return nil }
        let width = image.width, height = image.height
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let shorter = CGFloat(min(width, height))
        let red = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        for pin in spots.sorted(by: { $0.number < $1.number }) {
            let radius = max(8, CGFloat(pin.radius ?? EditRegion.defaultRadius) * shorter)
            // Pins are normalised from the top-left; CoreGraphics draws from the bottom-left.
            let center = CGPoint(x: CGFloat(pin.x) * CGFloat(width), y: (1 - CGFloat(pin.y)) * CGFloat(height))
            context.setStrokeColor(red)
            context.setLineWidth(max(4, shorter * 0.008))
            context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            let badgeRadius = max(12, radius * 0.28)
            let badge = CGPoint(x: center.x - radius * 0.75, y: center.y + radius * 0.75)
            context.setFillColor(red)
            context.fillEllipse(in: CGRect(x: badge.x - badgeRadius, y: badge.y - badgeRadius,
                                           width: badgeRadius * 2, height: badgeRadius * 2))
            drawNumber(pin.number, at: badge, size: badgeRadius * 1.3, in: context)
        }
        guard let output = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, output, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func drawNumber(_ number: Int, at point: CGPoint, size: CGFloat, in context: CGContext) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
        ]
        guard let string = CFAttributedStringCreate(nil, String(number) as CFString, attributes as CFDictionary) else { return }
        let line = CTLineCreateWithAttributedString(string)
        let bounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: point.x - bounds.midX, y: point.y - bounds.midY)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
