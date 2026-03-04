// DirectorsChairServices/Sources/DirectorsChairServices/Capture/LUTProcessor.swift
//
// GPU-accelerated LUT color correction for live camera preview.
// Generates CIColorCube filters from standard log-to-display transfer functions.

import Foundation
import CoreImage
import CoreMedia
import Metal

// MARK: - LUT Preset

public enum LUTPreset: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case rec709 = "Rec.709"
    case slog3ToRec709 = "S-Log3 \u{2192} Rec.709"
    case slog2ToRec709 = "S-Log2 \u{2192} Rec.709"
    case arriLogCToRec709 = "ARRI LogC \u{2192} Rec.709"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .none: return "circle.slash"
        case .rec709: return "tv"
        case .slog3ToRec709: return "camera.fill"
        case .slog2ToRec709: return "camera"
        case .arriLogCToRec709: return "film"
        }
    }

    public var shortLabel: String {
        switch self {
        case .none: return "None"
        case .rec709: return "Rec.709"
        case .slog3ToRec709: return "S-Log3"
        case .slog2ToRec709: return "S-Log2"
        case .arriLogCToRec709: return "LogC"
        }
    }
}

// MARK: - LUT Processor

public class LUTProcessor {
    private var currentFilter: CIFilter?
    private var currentPreset: LUTPreset = .none
    public let ciContext: CIContext

    public init() {
        if let device = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: device, options: [
                .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                .outputColorSpace: CGColorSpaceCreateDeviceRGB()
            ])
        } else {
            ciContext = CIContext(options: [
                .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                .outputColorSpace: CGColorSpaceCreateDeviceRGB()
            ])
        }
    }

    // MARK: - Public API

    public func setPreset(_ preset: LUTPreset) {
        guard preset != currentPreset else { return }
        currentPreset = preset
        if preset == .none {
            currentFilter = nil
        } else {
            currentFilter = buildColorCubeFilter(for: preset)
        }
    }

    /// Process a sample buffer through the current LUT. Returns nil if preset is .none.
    public func processFrame(_ sampleBuffer: CMSampleBuffer) -> CIImage? {
        guard currentPreset != .none, let filter = currentFilter else { return nil }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let sourceImage = CIImage(cvPixelBuffer: pixelBuffer)

        filter.setValue(sourceImage, forKey: kCIInputImageKey)
        return filter.outputImage
    }

    /// Process a CIImage through the current LUT.
    public func processImage(_ image: CIImage) -> CIImage? {
        guard currentPreset != .none, let filter = currentFilter else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage
    }

    // MARK: - Color Cube Generation

    private static let cubeSize = 33 // 33x33x33 = 35,937 entries

    private func buildColorCubeFilter(for preset: LUTPreset) -> CIFilter? {
        guard preset != .none else { return nil }

        let size = Self.cubeSize
        let count = size * size * size
        var cubeData = [Float](repeating: 0, count: count * 4)

        let transform: (Float, Float, Float) -> (Float, Float, Float) = {
            switch preset {
            case .none:
                return { r, g, b in (r, g, b) }
            case .rec709:
                return { r, g, b in
                    (Self.linearToRec709(r), Self.linearToRec709(g), Self.linearToRec709(b))
                }
            case .slog3ToRec709:
                return { r, g, b in
                    let lr = Self.slog3ToLinear(r)
                    let lg = Self.slog3ToLinear(g)
                    let lb = Self.slog3ToLinear(b)
                    return (Self.linearToRec709(lr), Self.linearToRec709(lg), Self.linearToRec709(lb))
                }
            case .slog2ToRec709:
                return { r, g, b in
                    let lr = Self.slog2ToLinear(r)
                    let lg = Self.slog2ToLinear(g)
                    let lb = Self.slog2ToLinear(b)
                    return (Self.linearToRec709(lr), Self.linearToRec709(lg), Self.linearToRec709(lb))
                }
            case .arriLogCToRec709:
                return { r, g, b in
                    let lr = Self.arriLogCToLinear(r)
                    let lg = Self.arriLogCToLinear(g)
                    let lb = Self.arriLogCToLinear(b)
                    return (Self.linearToRec709(lr), Self.linearToRec709(lg), Self.linearToRec709(lb))
                }
            }
        }()

        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let rf = Float(r) / Float(size - 1)
                    let gf = Float(g) / Float(size - 1)
                    let bf = Float(b) / Float(size - 1)

                    let (ro, go, bo) = transform(rf, gf, bf)

                    let index = (b * size * size + g * size + r) * 4
                    cubeData[index + 0] = Self.clamp01(ro)
                    cubeData[index + 1] = Self.clamp01(go)
                    cubeData[index + 2] = Self.clamp01(bo)
                    cubeData[index + 3] = 1.0
                }
            }
        }

        let data = cubeData.withUnsafeBufferPointer { Data(buffer: $0) }

        let filter = CIFilter(name: "CIColorCube")
        filter?.setValue(size, forKey: "inputCubeDimension")
        filter?.setValue(data, forKey: "inputCubeData")
        return filter
    }

    // MARK: - Transfer Functions

    /// Rec.709 OETF: linear scene → display (gamma encode)
    private static func linearToRec709(_ x: Float) -> Float {
        if x < 0.018 {
            return 4.5 * x
        } else {
            return 1.099 * powf(x, 0.45) - 0.099
        }
    }

    /// Sony S-Log3 inverse: encoded value → linear scene
    private static func slog3ToLinear(_ x: Float) -> Float {
        if x >= 171.2102946929 / 1023.0 {
            return powf(10.0, (x * 1023.0 - 420.0) / 261.5) * (0.18 + 0.01) - 0.01
        } else {
            return (x * 1023.0 - 95.0) * 0.01125000 / (171.2102946929 - 95.0)
        }
    }

    /// Sony S-Log2 inverse: encoded value → linear scene
    private static func slog2ToLinear(_ x: Float) -> Float {
        // S-Log2 formula (Sony spec)
        if x >= 0.030001222851889303 {
            return powf(10.0, ((x - 0.616596 - 0.03) / 0.432699)) - 0.037584
        } else {
            return (x - 0.030001222851889303) / 5.0 + 0.001
        }
    }

    /// ARRI LogC (EI 800) inverse: encoded value → linear scene
    private static func arriLogCToLinear(_ x: Float) -> Float {
        // ARRI LogC3 constants for EI 800
        let cut: Float = 0.010591
        let a: Float = 5.555556
        let b: Float = 0.052272
        let c: Float = 0.247190
        let d: Float = 0.385537
        let e: Float = 5.367655
        let f: Float = 0.092809

        if x > e * cut + f {
            return (powf(10.0, (x - d) / c) - b) / a
        } else {
            return (x - f) / e
        }
    }

    private static func clamp01(_ v: Float) -> Float {
        return min(max(v, 0), 1)
    }
}
