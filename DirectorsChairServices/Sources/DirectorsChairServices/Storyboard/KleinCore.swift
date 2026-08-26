// DirectorsChairServices/Storyboard/KleinCore.swift
//
// The native on-device image core (DC-0068): FLUX.2 [klein] 4B running
// entirely in MLX-Swift against the weights the consent flow downloads.
// Ported from mflux 0.19 (MIT) and validated against its fixtures — the
// same pipeline that drew the frames the owner approved. One model,
// three jobs: text-to-image, instruction editing and multi-reference
// composition — references are simply more image tokens, encoded by
// the VAE and placed on their own time plane, so the transformer can
// look at them while it draws. 4 distilled steps, no guidance.
//
// An actor: one picture at a time — a second concurrent render would
// double a ~5GB working set for no wall-clock win.

#if arch(arm64)
import CoreGraphics
import Foundation
import ImageIO
import MLX
import MLXRandom
import Tokenizers
import UniformTypeIdentifiers

public actor KleinCore: OnDeviceImageGenerating {

    static let precision: DType = .bfloat16
    static let steps = 4
    /// References are conditioned at no more than this many pixels
    /// (aspect-preserving downscale, then a centre crop to 16px multiples).
    static let maxReferenceArea = 1024 * 1024

    private struct Bundle {
        let tokenizer: any Tokenizer
        let textEncoder: KleinTextEncoder
        let transformer: KleinTransformer
        let vae: KleinVAE
    }

    private var bundle: Bundle?

    public init() {}

    public func renderFrame(prompt: String, width: Int, height: Int,
                            seed: UInt64?, references: [Data],
                            weightsDirectory: URL) async throws -> Data {
        let w = max(256, 16 * (width / 16))
        let h = max(256, 16 * (height / 16))
        let bundle = try await loadedBundle(weightsDirectory: weightsDirectory)

        // 1. Prompt → the klein context (Qwen chat template, thinking off,
        //    padded to 512 inside the encoder).
        let ids = Self.tokenIds(for: prompt, tokenizer: bundle.tokenizer)
        let context = bundle.textEncoder.encode(ids).expandedDimensions(axis: 0)   // [1, 512, 7680]
        let textIds = Self.textIds(count: KleinTextEncoder.maxTokens)

        // 2. Seeded noise in patch space, packed row-major.
        let (lh, lw) = (h / 16, w / 16)
        let frameSeed = seed ?? UInt64.random(in: 0 ..< UInt64(Int32.max))
        var latents = MLXRandom.normal([1, KleinVAE.packedChannels, lh, lw],
                                       key: MLXRandom.key(frameSeed))
            .asType(Self.precision)
            .reshaped([1, KleinVAE.packedChannels, lh * lw])
            .transposed(0, 2, 1)                                          // [1, N, 128]
        let imageIds = Self.gridIds(height: lh, width: lw, t: 0)

        // 3. References → extra image tokens on time planes 10, 20, …
        var refTokens: [MLXArray] = []
        var refIds: [MLXArray] = []
        for (i, data) in references.enumerated() {
            guard let image = Self.referenceArray(from: data) else {
                throw StoryboardEngineError.generationFailed("A reference picture could not be read.")
            }
            let encoded = bundle.vae.encodeReference(image)
            refTokens.append(encoded.tokens)
            refIds.append(Self.gridIds(height: encoded.height, width: encoded.width, t: Int32(10 + 10 * i)))
            eval(encoded.tokens)
        }
        let allIds = concatenated([imageIds] + refIds, axis: 0)
        let n = lh * lw

        // 4. Resolution-shifted schedule and the Euler loop.
        let sigmas = Self.schedule(imageTokens: n, steps: Self.steps)
        for t in 0 ..< Self.steps {
            let hidden = refTokens.isEmpty ? latents : concatenated([latents] + refTokens, axis: 1)
            let velocity = bundle.transformer(
                latents: hidden, context: context,
                timestep: MLXArray(sigmas[t] * 1000),
                imageIds: allIds, textIds: textIds)[0..., ..<n, 0...]
            let dt = MLXArray(sigmas[t + 1] - sigmas[t]).asType(latents.dtype)
            latents = latents + dt * velocity.asType(latents.dtype)
            eval(latents)
        }

        // 5. Decode and encode PNG.
        let rgb = bundle.vae.decodePacked(latents, height: lh, width: lw)   // [1, H, W, 3] in [-1, 1]
        let pixels = MLX.round(clip(rgb.asType(.float32) / 2 + 0.5, min: 0, max: 1) * 255)
            .asType(.uint8).squeezed(axis: 0)
        eval(pixels)
        return try Self.encodePNG(pixels: pixels.asArray(UInt8.self), width: w, height: h)
    }

    // MARK: - Loading

    private func loadedBundle(weightsDirectory: URL) async throws -> Bundle {
        if let bundle { return bundle }
        do {
            let tokenizer = try await AutoTokenizer.from(
                modelFolder: weightsDirectory.appendingPathComponent("tokenizer"))
            let loaded = Bundle(
                tokenizer: tokenizer,
                textEncoder: try KleinTextEncoder(
                    ZWeights(componentDirectory: weightsDirectory.appendingPathComponent("text_encoder"))),
                transformer: try KleinTransformer(
                    ZWeights(componentDirectory: weightsDirectory.appendingPathComponent("transformer"))),
                vae: try KleinVAE(
                    ZWeights(componentDirectory: weightsDirectory.appendingPathComponent("vae"))))
            bundle = loaded
            return loaded
        } catch let error as StoryboardEngineError {
            throw error
        } catch {
            throw StoryboardEngineError.generationFailed(
                "Couldn't load the image model: \(String(describing: error))")
        }
    }

    // MARK: - Prompt

    /// The Qwen3 chat template with thinking disabled — exactly what
    /// mflux's tokenizer renders (`enable_thinking: false`).
    static func templated(_ prompt: String) -> String {
        "<|im_start|>user\n\(prompt)<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
    }

    static func tokenIds(for prompt: String, tokenizer: any Tokenizer) -> [Int32] {
        let ids = tokenizer.encode(text: templated(prompt)).map { Int32($0) }
        return Array(ids.prefix(KleinTextEncoder.maxTokens))
    }

    // MARK: - Positions

    /// Text ids: (0, 0, 0, token index).
    static func textIds(count: Int) -> MLXArray {
        let zeros = MLXArray.zeros([count], type: Int32.self)
        return stacked([zeros, zeros, zeros, MLXArray(0 ..< Int32(count))], axis: 1)
    }

    /// Image-grid ids: (t, row, col, 0), row-major.
    static func gridIds(height: Int, width: Int, t: Int32) -> MLXArray {
        let rows = repeated(MLXArray(0 ..< Int32(height)).reshaped([height, 1]), count: width, axis: 1).reshaped([height * width])
        let cols = repeated(MLXArray(0 ..< Int32(width)).reshaped([1, width]), count: height, axis: 0).reshaped([height * width])
        let ts = MLXArray.full([height * width], values: MLXArray(t)).asType(.int32)
        let zeros = MLXArray.zeros([height * width], type: Int32.self)
        return stacked([ts, rows, cols, zeros], axis: 1)
    }

    // MARK: - Schedule

    /// FlowMatchEulerDiscrete with klein's empirical resolution shift:
    /// linspace(1, 1/steps) through exp(μ)/(exp(μ) + 1/σ − 1), terminal 0.
    static func schedule(imageTokens: Int, steps: Int) -> [Float] {
        let seq = Float(imageTokens)
        let (a1, b1): (Float, Float) = (8.73809524e-05, 1.89833333)
        let (a2, b2): (Float, Float) = (0.00016927, 0.45666666)
        let mu: Float
        if seq > 4300 {
            mu = a2 * seq + b2
        } else {
            let m200 = a2 * seq + b2
            let m10 = a1 * seq + b1
            let a = (m200 - m10) / 190
            let b = m200 - 200 * a
            mu = a * Float(steps) + b
        }
        var sigmas = (0 ..< steps).map { i -> Float in
            let s = 1 - Float(i) * (1 - 1 / Float(steps)) / Float(max(steps - 1, 1))
            return exp(mu) / (exp(mu) + (1 / s - 1))
        }
        sigmas.append(0)
        return sigmas
    }

    // MARK: - Reference pictures

    /// Decodes a PNG/JPEG into [1, H, W, 3] in [-1, 1] at the conditioning
    /// size: aspect-preserving downscale to ≤ 1024² pixels, then a centre
    /// crop so both sides are multiples of 16 (mflux prepare_reference_image).
    static func referenceArray(from data: Data) -> MLXArray? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        var (w, h) = (image.width, image.height)
        if w * h > maxReferenceArea {
            let scale = (Float(maxReferenceArea) / Float(w * h)).squareRoot()
            w = Int((Float(w) * scale).rounded()); h = Int((Float(h) * scale).rounded())
        }
        let tw = w - w % 16, th = h - h % 16
        guard tw > 0, th > 0 else { return nil }
        let bytesPerRow = tw * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * th)
        let ok: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: tw, height: th, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.interpolationQuality = .high
            // Centre-crop: draw the resized picture offset so the crop is central.
            let origin = CGPoint(x: -CGFloat((w - tw) / 2), y: -CGFloat((h - th) / 2))
            context.draw(image, in: CGRect(origin: origin, size: CGSize(width: w, height: h)))
            return true
        }
        guard ok else { return nil }
        var floats = [Float](repeating: 0, count: tw * th * 3)
        for i in 0 ..< (tw * th) {
            floats[i * 3] = Float(pixels[i * 4]) / 255
            floats[i * 3 + 1] = Float(pixels[i * 4 + 1]) / 255
            floats[i * 3 + 2] = Float(pixels[i * 4 + 2]) / 255
        }
        return (MLXArray(floats, [1, th, tw, 3]) * 2 - 1).asType(precision)
    }

    // MARK: - PNG

    static func encodePNG(pixels: [UInt8], width: Int, height: Int) throws -> Data {
        guard pixels.count == width * height * 3,
              let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: width * 3,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent)
        else {
            throw StoryboardEngineError.generationFailed("Couldn't assemble the rendered frame.")
        }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            out, UTType.png.identifier as CFString, 1, nil)
        else {
            throw StoryboardEngineError.generationFailed("Couldn't create the PNG encoder.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw StoryboardEngineError.generationFailed("PNG encoding failed.")
        }
        return out as Data
    }
}
#endif
