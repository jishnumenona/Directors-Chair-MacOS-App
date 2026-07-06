// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/ShotCollageRenderer.swift
//
// WS6.3 — the AI-preview/take comparison collage renderer, previously
// DUPLICATED byte-for-byte in TakesSectionView and CinematographyView.
// One canonical copy.

import AppKit

public enum ShotCollageRenderer {

    public static func createCollage(leftImage: CGImage, leftLabel: String, rightImage: CGImage, rightLabel: String) -> Data? {
        let canvasWidth: CGFloat = 1920
        let canvasHeight: CGFloat = 540
        let gap: CGFloat = 4
        let panelWidth = (canvasWidth - gap) / 2
        let labelHeight: CGFloat = 28
        let labelFontSize: CGFloat = 13

        guard let ctx = CGContext(
            data: nil,
            width: Int(canvasWidth),
            height: Int(canvasHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Fill background black
        ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

        func drawPanel(image: CGImage, label: String, originX: CGFloat) {
            let imgW = CGFloat(image.width)
            let imgH = CGFloat(image.height)
            let availableHeight = canvasHeight - labelHeight
            let scale = min(panelWidth / imgW, availableHeight / imgH)
            let drawW = imgW * scale
            let drawH = imgH * scale
            let x = originX + (panelWidth - drawW) / 2
            let y = labelHeight + (availableHeight - drawH) / 2
            ctx.draw(image, in: CGRect(x: x, y: y, width: drawW, height: drawH))

            // Label background
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
            ctx.fill(CGRect(x: originX, y: 0, width: panelWidth, height: labelHeight))

            // Label text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: labelFontSize, weight: .semibold),
                .foregroundColor: NSColor.white,
                .kern: 1.5
            ]
            let attrString = NSAttributedString(string: label, attributes: attributes)
            let textSize = attrString.size()
            let textX = originX + (panelWidth - textSize.width) / 2
            let textY = (labelHeight - textSize.height) / 2

            NSGraphicsContext.saveGraphicsState()
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.current = nsCtx
            attrString.draw(at: NSPoint(x: textX, y: textY))
            NSGraphicsContext.restoreGraphicsState()
        }

        drawPanel(image: leftImage, label: leftLabel, originX: 0)
        drawPanel(image: rightImage, label: rightLabel, originX: panelWidth + gap)

        guard let compositeImage = ctx.makeImage() else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: compositeImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }

}
