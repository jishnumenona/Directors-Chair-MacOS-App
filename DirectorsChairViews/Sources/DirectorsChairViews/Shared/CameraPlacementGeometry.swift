// DirectorsChairViews/Shared/CameraPlacementGeometry.swift
//
// DC-0129: the picture is shown fitted inside a view; the camera and its
// target are stored as fractions of the picture. This is the one mapping
// between the two, so the desktop and the iPad place markers identically.

import CoreGraphics
import DirectorsChairCore

enum CameraPlacementGeometry {
    /// Where a picture of `imageSize` sits when fitted (aspect-preserving,
    /// centred) inside `bounds`.
    static func fittedRect(imageSize: CGSize, in bounds: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    /// A view point as a fraction of the fitted picture, clamped to it.
    static func fraction(of point: CGPoint, in rect: CGRect) -> CGPoint {
        guard rect.width > 0, rect.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(x: min(1, max(0, (point.x - rect.minX) / rect.width)),
                       y: min(1, max(0, (point.y - rect.minY) / rect.height)))
    }

    /// A fraction of the picture as a view point.
    static func point(x: Double, y: Double, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + CGFloat(x) * rect.width, y: rect.minY + CGFloat(y) * rect.height)
    }

    /// The camera's view point, the target's, and whether both are set.
    static func camera(_ placement: CameraPlacement, in rect: CGRect) -> CGPoint {
        point(x: placement.x, y: placement.y, in: rect)
    }

    static func target(_ placement: CameraPlacement, in rect: CGRect) -> CGPoint {
        point(x: placement.targetX, y: placement.targetY, in: rect)
    }

    /// Which handle a press lands on, if any.
    enum Handle { case camera, target }
    static func handle(at point: CGPoint, placement: CameraPlacement?, in rect: CGRect, radius: CGFloat = 22) -> Handle? {
        guard let placement else { return nil }
        func near(_ p: CGPoint) -> Bool { hypot(p.x - point.x, p.y - point.y) <= radius }
        if near(camera(placement, in: rect)) { return .camera }
        if near(target(placement, in: rect)) { return .target }
        return nil
    }
}
