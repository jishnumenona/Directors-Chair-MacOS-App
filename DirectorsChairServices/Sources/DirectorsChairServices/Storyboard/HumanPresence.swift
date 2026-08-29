import Foundation
import CoreGraphics
import ImageIO
import Vision

/// Whether a drawing has a person in it — Apple Vision's human and face
/// detectors, which turn out to read ink and comic drawings well
/// (DC-0071 probe on 19 frames: every figure found at 0.6–0.85, every
/// empty plate and object study at zero).
///
/// Used by the engine to redraw a location plate or a prop study that
/// gained a figure: the model adds people to places it associates with
/// them (a chef to a kitchen, a walker to a path) often enough that a
/// prompt alone cannot be trusted.
public enum HumanPresence {
    public static let minimumConfidence: Float = 0.5

    public static func detected(in png: Data, minimumConfidence: Float = minimumConfidence) -> Bool {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return false }
        let humans = VNDetectHumanRectanglesRequest()
        humans.upperBodyOnly = true
        let faces = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([humans, faces]) } catch { return false }
        let found = (humans.results ?? []).contains { $0.confidence >= minimumConfidence }
            || (faces.results ?? []).contains { $0.confidence >= minimumConfidence }
        return found
    }
}
