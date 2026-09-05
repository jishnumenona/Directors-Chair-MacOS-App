// DirectorsChairServices/Storyboard/CameraVantage.swift
//
// DC-0129 (owner 2026-09-05): "place the camera on a part of the image and
// then orient it towards a part of the image and then generate the image of
// what it would look like from that camera's vantage point."
//
// Probed on the live model with the owner's convenience-store picture
// (2026-09-05, seven variants). What the model does and does not do:
//   • Given the clean picture as well as a marked copy, it hands the clean
//     picture back with the markers removed — every time. So the render
//     step sends ONLY the marked copy.
//   • Geometry in words ("lower-left, turned 50° right") does not move it.
//   • Content words do: "taken from the tiled floor beside the entrance,
//     facing the beverage cooler; the glass doors are behind the camera and
//     must not appear" produced a genuinely new viewpoint — the doors gone,
//     the near shelf large at the edge, the aisle receding to the coolers.
// So a vantage render is two steps: a text call that names what is at C,
// at T and BEHIND the camera (from the marked copy), then the image call
// built from those words. CoreGraphics + ImageIO only — ships to the iPad.

import CoreGraphics
import CoreText
import DirectorsChairCore
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What the text model read off the marked copy: the fixture under the
/// camera, the fixture it looks at, and what lies behind it.
public struct CameraMarkerWords: Equatable, Sendable {
    public var atCamera: String
    public var atTarget: String
    public var behindCamera: String

    public init(atCamera: String, atTarget: String, behindCamera: String = "") {
        self.atCamera = atCamera
        self.atTarget = atTarget
        self.behindCamera = behindCamera
    }

    /// Parses the describe step's answer ("C: …", "T: …", "BEHIND: …").
    /// Nil when neither C nor T came back — the caller falls back to
    /// geometry words.
    public static func parse(_ text: String) -> CameraMarkerWords? {
        let decoration = CharacterSet(charactersIn: "*_-#`> ").union(.whitespaces)
        func line(_ tag: String) -> String? {
            for raw in text.components(separatedBy: .newlines) {
                // "**C:** the counter." — markdown emphasis and list bullets are noise.
                let trimmed = raw.trimmingCharacters(in: decoration)
                let upper = trimmed.uppercased()
                guard upper.hasPrefix(tag + ":") || upper.hasPrefix(tag + "**:") else { continue }
                var value = trimmed.dropFirst(tag.count).trimmingCharacters(in: decoration)
                if value.hasPrefix(":") { value = String(value.dropFirst()) }
                value = value.trimmingCharacters(in: decoration).trimmingCharacters(in: CharacterSet(charactersIn: ".*_ "))
                return value.isEmpty ? nil : value
            }
            return nil
        }
        guard let c = line("C"), let t = line("T") else { return nil }
        return CameraMarkerWords(atCamera: c, atTarget: t, behindCamera: line("BEHIND") ?? "")
    }
}

/// What a camera placed on a location picture should see.
public struct CameraVantageInput: Sendable {
    public let locationName: String
    public let locationDescription: String
    public let angleName: String
    public let angleDescription: String
    public let camera: CameraPlacement
    /// The picture with the C and T markers and the arrow — the only
    /// picture of the base the model sees (see the file comment).
    public let markedPNG: Data
    /// The describe step's words; nil falls back to geometry words.
    public let words: CameraMarkerWords?
    /// Other pictures of the same place (variations, other angles).
    public let references: [SketchElement]
    public let aspectRatio: String
    public let targetSize: ImageTargetSize

    public init(locationName: String, locationDescription: String = "",
                angleName: String, angleDescription: String = "",
                camera: CameraPlacement, markedPNG: Data,
                words: CameraMarkerWords? = nil,
                references: [SketchElement] = [],
                aspectRatio: String = "16:9", targetSize: ImageTargetSize = .projectPreview) {
        self.locationName = locationName
        self.locationDescription = locationDescription
        self.angleName = angleName
        self.angleDescription = angleDescription
        self.camera = camera
        self.markedPNG = markedPNG
        self.words = words
        self.references = references
        self.aspectRatio = aspectRatio
        self.targetSize = targetSize
    }
}

/// Draws the camera (C), its target (T) and the arrow between them onto a
/// copy of the picture.
public enum CameraMarkup {
    /// The picture re-encoded as PNG (location pictures may be JPEGs; the
    /// request labels every picture image/png). nil if it can't be decoded.
    public static func pngCopy(of source: Data) -> Data? {
        guard let imageSource = CGImageSourceCreateWithData(source as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    public static func marked(source: Data, camera: CameraPlacement) -> Data? {
        guard let imageSource = CGImageSourceCreateWithData(source as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { return nil }
        let width = image.width, height = image.height
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let shorter = CGFloat(min(width, height))
        let red = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        // Fractions are from the top-left; CoreGraphics draws from the bottom-left.
        let from = CGPoint(x: CGFloat(camera.x) * CGFloat(width), y: (1 - CGFloat(camera.y)) * CGFloat(height))
        let to = CGPoint(x: CGFloat(camera.targetX) * CGFloat(width), y: (1 - CGFloat(camera.targetY)) * CGFloat(height))
        let line = max(4, shorter * 0.008)
        let cameraRadius = max(14, shorter * 0.04)
        let targetRadius = max(12, shorter * 0.032)

        // The arrow C → T, stopping short of both circles.
        let dx = to.x - from.x, dy = to.y - from.y
        let length = max(1, (dx * dx + dy * dy).squareRoot())
        let unit = CGPoint(x: dx / length, y: dy / length)
        let start = CGPoint(x: from.x + unit.x * cameraRadius, y: from.y + unit.y * cameraRadius)
        let end = CGPoint(x: to.x - unit.x * targetRadius, y: to.y - unit.y * targetRadius)
        context.setStrokeColor(red)
        context.setFillColor(red)
        context.setLineWidth(line)
        context.setLineCap(.round)
        if length > cameraRadius + targetRadius + line {
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            let head = max(10, line * 3.5)
            let left = CGPoint(x: end.x - unit.x * head - unit.y * head * 0.6, y: end.y - unit.y * head + unit.x * head * 0.6)
            let right = CGPoint(x: end.x - unit.x * head + unit.y * head * 0.6, y: end.y - unit.y * head - unit.x * head * 0.6)
            context.move(to: end); context.addLine(to: left); context.addLine(to: right); context.closePath()
            context.fillPath()
        }
        // C: a filled red disc with a white letter — the camera itself.
        context.fillEllipse(in: CGRect(x: from.x - cameraRadius, y: from.y - cameraRadius,
                                       width: cameraRadius * 2, height: cameraRadius * 2))
        drawLabel("C", at: from, size: cameraRadius * 1.3, in: context)
        // T: a red ring with a small filled badge — what the camera looks at.
        context.strokeEllipse(in: CGRect(x: to.x - targetRadius, y: to.y - targetRadius,
                                         width: targetRadius * 2, height: targetRadius * 2))
        let badgeRadius = max(11, targetRadius * 0.6)
        let badge = CGPoint(x: to.x + targetRadius * 0.8, y: to.y + targetRadius * 0.8)
        context.fillEllipse(in: CGRect(x: badge.x - badgeRadius, y: badge.y - badgeRadius,
                                       width: badgeRadius * 2, height: badgeRadius * 2))
        drawLabel("T", at: badge, size: badgeRadius * 1.3, in: context)

        guard let output = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, output, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func drawLabel(_ text: String, at point: CGPoint, size: CGFloat, in context: CGContext) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
        ]
        guard let string = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary) else { return }
        let line = CTLineCreateWithAttributedString(string)
        let bounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: point.x - bounds.midX, y: point.y - bounds.midY)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

public extension SketchStudioComposer {

    // MARK: Step 1 — the describe question (a text call with the marked copy)

    /// The question the text model answers from the marked copy. Send with
    /// thinking off and ~1000 output tokens: with a small budget the model
    /// spends it all thinking and returns eight tokens (probe, 2026-09-05).
    static func vantageDescribePrompt(for camera: CameraPlacement, placeKind: String = "store") -> String {
        let surface = camera.isFloorPlan ? "floor plan" : "photograph"
        return "This is a \(surface) of a \(placeKind) with two red annotations drawn on it: a red disc labelled C and a red ring labelled T, joined by an arrow. "
            + "A camera will be placed at C and pointed at T. Ignore the annotations themselves and describe the PLACE: "
            + "what fixture or area is directly under the disc C; what fixture or area is inside the ring T; "
            + "and what fixtures or areas would be BEHIND a camera standing at C facing T (out of its view). "
            + "Use the things visible in the \(surface). One short phrase each, at most twelve words, no other text. "
            + "Answer exactly in this form:\nC: <what is there>\nT: <what is there>\nBEHIND: <what is behind the camera>"
    }

    static let vantageDescribeMaxTokens = 1024

    // MARK: Step 2 — the render

    /// The full prompt for a vantage render, exactly as sent.
    static func vantagePrompt(for input: CameraVantageInput) -> String {
        var lines: [String] = []
        let place = input.locationName.isEmpty ? "this location" : input.locationName
        let about = input.locationDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let camera = input.camera
        let from = input.words?.atCamera ?? geometryWords(camera).at
        let facing = input.words?.atTarget ?? geometryWords(camera).toward
        let behind = input.words?.behindCamera.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var opening = "A new photograph of \(place), taken from \(from), facing \(facing)."
        if !behind.isEmpty {
            opening += " \(behind.prefix(1).uppercased() + behind.dropFirst()) — behind the camera — must not appear."
        }
        lines.append(opening)
        if !about.isEmpty { lines.append("The place: \(about.prefix(300))") }
        if camera.isFloorPlan {
            lines.append("Image 1 is the FLOOR PLAN of the place, drawn from above, with two red markers: the disc C is where the camera stands on the plan (\(from)); the ring T is what it looks at (\(facing)); the arrow is the direction of view.")
            lines.append("Render a photograph of the place as a person standing at C and facing T would see it, at eye level: walls, openings and fixtures where the plan puts them, left and right as they fall from that viewpoint, in the materials, light and colour grade of the place's other pictures. \(facing.prefix(1).uppercased() + facing.dropFirst()) at the centre of the frame; whatever stands beside C at the near edges, large; everything behind C out of frame.")
        } else {
            lines.append("Image 1 is the same place seen from a different spot, with two red markers: the disc C is where the new camera stands (\(from)); the ring T is what it looks at (\(facing)); the arrow is the direction of view.")
            lines.append("The result must be a DIFFERENT photograph — not a copy or crop of Image 1: the camera has moved to C and turned to face T. Render what that camera sees at eye level: \(facing) at the centre of the frame, in the distance; whatever stands beside C at the near edges, large; what lies between C and T in the middle distance, receding. Same place: the same architecture, fixtures, materials, signage, floor, ceiling and lights, light direction, colour grade and time of day. Where the picture does not show a surface, continue the same materials and style.")
        }
        for (index, reference) in input.references.enumerated() {
            lines.append("Image \(index + 2) is another picture of the same place (\(reference.name)): match its surfaces, fittings and light wherever they apply — never its framing.")
        }
        let angleWords = input.angleDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !input.angleName.isEmpty || !angleWords.isEmpty {
            var line = "This angle is called \"\(input.angleName)\""
            if !angleWords.isEmpty { line += ": \(stripMentions(angleWords).prefix(300))" }
            lines.append(line + ".")
        }
        lines.append("Widescreen \(input.aspectRatio) photograph, full frame edge-to-edge, no black bars or letterboxing.")
        // The ink ban goes LAST — the sketch contract's proven placement.
        lines.append("The red markers, letters and arrow are annotations only: none of them may appear in the result.")
        return lines.joined(separator: "\n")
    }

    /// Fallback words from the placement alone, for when the describe step
    /// fails: where C and T sit on the picture, in thirds.
    static func geometryWords(_ camera: CameraPlacement) -> (at: String, toward: String) {
        func across(_ v: Double) -> String { v < 1.0 / 3 ? "the left side" : (v < 2.0 / 3 ? "the middle" : "the right side") }
        func depth(_ v: Double) -> String {
            if camera.isFloorPlan { return v < 1.0 / 3 ? "the top of the plan" : (v < 2.0 / 3 ? "the middle of the plan" : "the bottom of the plan") }
            return v < 1.0 / 3 ? "far back" : (v < 2.0 / 3 ? "the middle distance" : "close to where the picture was taken")
        }
        return ("the spot marked C — \(across(camera.x)) of the picture, \(depth(camera.y))",
                "the spot marked T — \(across(camera.targetX)) of the picture, \(depth(camera.targetY))")
    }

    /// The marked copy first (the only picture of the base), then the other
    /// pictures — the numbering the prompt uses.
    static func vantageReferenceImages(for input: CameraVantageInput) -> [ReferenceImage] {
        var refs = [ReferenceImage(base64: input.markedPNG.base64EncodedString(), mimeType: "image/png",
                                   label: input.camera.isFloorPlan ? "plan:marked floor plan" : "camera:marked copy")]
        for reference in input.references {
            refs.append(ReferenceImage(base64: reference.imageData.base64EncodedString(), mimeType: "image/png",
                                       label: "\(reference.kind):\(reference.name)"))
        }
        return refs
    }

    /// The request, complete in itself (no client-side preamble).
    static func vantageRequest(for input: CameraVantageInput) -> ImageGenerationRequest {
        ImageGenerationRequest(
            prompt: vantagePrompt(for: input),
            provider: AIProviderSelection.shared.provider(for: .image),
            aspectRatio: input.aspectRatio,
            numberOfImages: 1,
            referenceImages: vantageReferenceImages(for: input),
            brief: VisualBrief(purpose: .location,
                               subject: "\(input.locationName) seen from the angle \"\(input.angleName)\""),
            isEdit: false,
            targetSize: input.targetSize)
    }
}
