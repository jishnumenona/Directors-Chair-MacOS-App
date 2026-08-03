// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionScrapPhysics.swift
//
// The Wall, pass 2 — paper hangs from a pin.
//
// A scrap is stuck to the wall with a thumbtack, and the tack is a PIVOT,
// not a decoration. Drag a scrap and the paper trails behind the tack the
// way a hanging sign lags the hand carrying it; let go and it swings a
// couple of times and settles.
//
// Where it settles is the one place we part with textbook physics. A free
// pendulum comes to rest hanging plumb — which would rotate every scrap on
// the wall to the same angle and flatten the collage. A real tack pushed
// through paper has friction: it holds the sheet at whatever angle you left
// it. So gravity governs the SWING, and friction governs the REST: the
// scrap returns to its own tilt.
//
// Pure math, no SwiftUI, so the feel is unit-testable.

import CoreGraphics
import Foundation

public enum VisionScrapPhysics {

    /// How far the paper lags behind a moving tack, in degrees. The swing
    /// follows horizontal speed — carrying a hanging sign sideways makes it
    /// trail; lifting it straight up barely turns it.
    ///
    /// - Parameters:
    ///   - horizontalVelocity: points per second of the tack's motion.
    ///   - maxSwing: the paper never folds back on itself.
    public static func swing(horizontalVelocity: CGFloat,
                             maxSwing: Double = 11,
                             sensitivity: Double = 0.016) -> Double {
        let raw = -Double(horizontalVelocity) * sensitivity
        return min(max(raw, -maxSwing), maxSwing)
    }

    /// One step of a damped spring, semi-implicit Euler — stable at the
    /// frame rates SwiftUI actually delivers, unlike explicit Euler which
    /// gains energy and shakes itself apart.
    ///
    /// - Parameters:
    ///   - stiffness: how hard it is pulled back to `target` (ω²).
    ///   - damping: friction in the tack. Below the critical value
    ///     (2·√stiffness) the paper oscillates before it settles, which is
    ///     the whole point.
    public static func step(angle: Double, velocity: Double, target: Double,
                            dt: Double, stiffness: Double = 210,
                            damping: Double = 11) -> (angle: Double, velocity: Double) {
        guard dt > 0 else { return (angle, velocity) }
        let acceleration = -stiffness * (angle - target) - damping * velocity
        let newVelocity = velocity + acceleration * dt
        return (angle + newVelocity * dt, newVelocity)
    }

    /// True once the paper has stopped moving enough to matter — the
    /// animation can be torn down instead of burning a frame timer.
    public static func atRest(angle: Double, velocity: Double, target: Double,
                              angleEpsilon: Double = 0.05,
                              velocityEpsilon: Double = 0.6) -> Bool {
        abs(angle - target) < angleEpsilon && abs(velocity) < velocityEpsilon
    }

    /// Where the tack goes through the paper: near the top, and a little
    /// off-centre so a wall of scraps doesn't look machine-placed. Stable
    /// per scrap (the same FNV walk the tilt uses), never `random`.
    public static func tackAnchor(seed: String) -> CGPoint {
        var hash: UInt64 = 1469598103934665603
        for byte in seed.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        let drift = Double(hash % 1001) / 1000.0 - 0.5      // −0.5…0.5
        return CGPoint(x: 0.5 + drift * 0.34, y: 0.055)
    }
}
