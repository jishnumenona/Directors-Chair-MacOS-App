#!/usr/bin/env swift
//
// generate-dmg-background.swift
// Generates the cinematic DMG background image for DirectorsChair installer
//
// Usage: swift generate-dmg-background.swift
// Output: installer/dmg-background.png and installer/dmg-background@2x.png

import AppKit

// MARK: - Configuration

let standardSize = NSSize(width: 660, height: 460)
let retinaSize = NSSize(width: 1320, height: 920)

// Colors matching SplashScreenView.swift
let bgColorTop = NSColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 1.0)
let bgColorBottom = NSColor(red: 0.02, green: 0.04, blue: 0.06, alpha: 1.0)
let cyanGlow = NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)

// MARK: - Drawing

func drawBackground(size: NSSize, scale: CGFloat) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // 1. Dark cinematic gradient background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [bgColorTop.cgColor, bgColorBottom.cgColor] as CFArray
    let gradientLocations: [CGFloat] = [0.0, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: size.width / 2, y: size.height),
            end: CGPoint(x: size.width / 2, y: 0),
            options: []
        )
    }

    // 2. Subtle film grain texture (random noise dots)
    context.setAlpha(0.03)
    for _ in 0..<Int(size.width * size.height * 0.002) {
        let x = CGFloat.random(in: 0...size.width)
        let y = CGFloat.random(in: 0...size.height)
        let brightness = CGFloat.random(in: 0.3...1.0)
        context.setFillColor(NSColor(white: brightness, alpha: 1.0).cgColor)
        context.fill(CGRect(x: x, y: y, width: scale, height: scale))
    }
    context.setAlpha(1.0)

    // 3. Faint film sprocket holes at top and bottom
    let sprocketColor = NSColor(white: 1.0, alpha: 0.04)
    context.setFillColor(sprocketColor.cgColor)
    let sprocketSize = 8 * scale
    let sprocketSpacing = 24 * scale
    let sprocketY_top = size.height - 16 * scale
    let sprocketY_bottom = 8 * scale

    var x: CGFloat = 30 * scale
    while x < size.width {
        // Top edge sprockets
        let topRect = CGRect(x: x, y: sprocketY_top, width: sprocketSize, height: sprocketSize)
        context.fillEllipse(in: topRect)
        // Bottom edge sprockets
        let bottomRect = CGRect(x: x, y: sprocketY_bottom, width: sprocketSize, height: sprocketSize)
        context.fillEllipse(in: bottomRect)
        x += sprocketSpacing
    }

    // 4. "Director's Chair" title text (centered, subtle)
    let titleFont = NSFont.systemFont(ofSize: 26 * scale, weight: .light)
    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor(white: 1.0, alpha: 0.35)
    ]
    let titleString = "Director's Chair" as NSString
    let titleSize = titleString.size(withAttributes: titleAttributes)
    let titlePoint = CGPoint(
        x: (size.width - titleSize.width) / 2,
        y: size.height * 0.72
    )
    titleString.draw(at: titlePoint, withAttributes: titleAttributes)

    // 5. Tagline
    let tagFont = NSFont.systemFont(ofSize: 12 * scale, weight: .regular)
    let tagAttributes: [NSAttributedString.Key: Any] = [
        .font: tagFont,
        .foregroundColor: NSColor(white: 1.0, alpha: 0.18)
    ]
    let tagString = "Your story. Your vision." as NSString
    let tagSize = tagString.size(withAttributes: tagAttributes)
    let tagPoint = CGPoint(
        x: (size.width - tagSize.width) / 2,
        y: size.height * 0.72 - titleSize.height - 6 * scale
    )
    tagString.draw(at: tagPoint, withAttributes: tagAttributes)

    // 6. Subtle curved arrow from app icon zone to Applications zone
    let arrowPath = NSBezierPath()
    let arrowStartX = 220 * scale
    let arrowEndX = 440 * scale
    let arrowY = size.height * 0.48
    let controlY = arrowY + 30 * scale

    arrowPath.move(to: CGPoint(x: arrowStartX, y: arrowY))
    arrowPath.curve(
        to: CGPoint(x: arrowEndX, y: arrowY),
        controlPoint1: CGPoint(x: arrowStartX + 60 * scale, y: controlY),
        controlPoint2: CGPoint(x: arrowEndX - 60 * scale, y: controlY)
    )

    // Arrow glow
    context.saveGState()
    context.setShadow(offset: .zero, blur: 8 * scale, color: cyanGlow.withAlphaComponent(0.3).cgColor)
    cyanGlow.withAlphaComponent(0.15).setStroke()
    arrowPath.lineWidth = 1.5 * scale
    arrowPath.stroke()
    context.restoreGState()

    // Arrowhead
    let arrowHead = NSBezierPath()
    arrowHead.move(to: CGPoint(x: arrowEndX - 8 * scale, y: arrowY + 5 * scale))
    arrowHead.line(to: CGPoint(x: arrowEndX, y: arrowY))
    arrowHead.line(to: CGPoint(x: arrowEndX - 8 * scale, y: arrowY - 5 * scale))
    cyanGlow.withAlphaComponent(0.2).setStroke()
    arrowHead.lineWidth = 1.5 * scale
    arrowHead.stroke()

    // 7. Version text (bottom-right)
    let versionFont = NSFont.systemFont(ofSize: 9 * scale, weight: .regular)
    let versionAttributes: [NSAttributedString.Key: Any] = [
        .font: versionFont,
        .foregroundColor: NSColor(white: 1.0, alpha: 0.12)
    ]
    let versionString = "v1.0" as NSString
    let versionSize = versionString.size(withAttributes: versionAttributes)
    let versionPoint = CGPoint(
        x: size.width - versionSize.width - 16 * scale,
        y: 16 * scale
    )
    versionString.draw(at: versionPoint, withAttributes: versionAttributes)

    image.unlockFocus()
    return image
}

func saveImage(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Error: Could not convert image to PNG")
        return
    }

    let url = URL(fileURLWithPath: path)
    do {
        try pngData.write(to: url)
        print("Saved: \(path)")
    } catch {
        print("Error saving \(path): \(error)")
    }
}

// MARK: - Generate

print("Generating DMG background images...")

let standardImage = drawBackground(size: standardSize, scale: 1.0)
saveImage(standardImage, to: "installer/dmg-background.png")

let retinaImage = drawBackground(size: retinaSize, scale: 2.0)
saveImage(retinaImage, to: "installer/dmg-background@2x.png")

print("Done!")
