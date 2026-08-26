// DirectorsChairServices/Storyboard/ZImageCore.swift
//
// The native on-device diffusion core (DC-0065): Z-Image Turbo running
// entirely in MLX-Swift against the weights the consent flow downloads.
// Ported from mflux (MIT) and validated against its reference frames —
// tokenize (Qwen chat template, ≤512), encode the caption (35 Qwen3
// layers, fp32), 8 flow-matching steps through the S3-DiT at the
// resolution-shifted sigmas, decode through the 16-channel VAE, encode
// PNG. An actor: one frame at a time — a second concurrent render would
// double a ~6GB working set for no wall-clock win.

#if arch(arm64)
import CoreGraphics
import Foundation
import ImageIO
import MLX
import MLXRandom
import Tokenizers
import UniformTypeIdentifiers

public actor ZImageCore: OnDeviceImageGenerating {

    static let precision: DType = .bfloat16
    static let maxPromptTokens = 512

    private struct Bundle {
        let tokenizer: any Tokenizer
        let textEncoder: ZTextEncoder
        let transformer: ZImageTransformerCore
        let decoder: ZVAEDecoder
    }

    private var bundle: Bundle?

    public init() {}

    public func renderFrame(prompt: String, width: Int, height: Int,
                            seed: UInt64?, weightsDirectory: URL) async throws -> Data {
        // Dimensions ride the 16px latent grid (spec guarantees it; clamp
        // defensively rather than crash the reshape).
        let w = max(256, 16 * (width / 16))
        let h = max(256, 16 * (height / 16))

        let bundle = try await loadedBundle(weightsDirectory: weightsDirectory)

        // 1. Prompt → ids via the exact template mflux applies
        //    (Qwen chat template, add_generation_prompt, thinking enabled).
        let templated = "<|im_start|>user\n\(prompt)<|im_end|>\n<|im_start|>assistant\n"
        var ids = bundle.tokenizer.encode(text: templated).map { Int32($0) }
        if ids.count > Self.maxPromptTokens { ids = Array(ids.prefix(Self.maxPromptTokens)) }
        guard !ids.isEmpty else {
            throw StoryboardEngineError.generationFailed("Empty prompt after tokenization.")
        }

        // 2. Caption features [L, 2560].
        let capFeats = bundle.textEncoder.encode(ids)

        // 3. Resolution-shifted turbo schedule (8 steps).
        let steps = 8
        let sigmas = Self.shiftedSigmas(steps: steps, width: w, height: h)

        // 4. Seeded noise, identical to mx.random.normal(key(seed)).
        let frameSeed = seed ?? UInt64.random(in: 0 ..< UInt64(Int32.max))
        var latents = MLXRandom.normal(
            [16, 1, h / 8, w / 8],
            key: MLXRandom.key(frameSeed)
        ).asType(Self.precision)

        // 5. Denoising loop: x ← x + v·(σₜ₊₁ − σₜ), timestep = 1 − σₜ.
        for t in 0 ..< steps {
            let sigmaT = sigmas[t ..< (t + 1)]
            let timestep = 1.0 - sigmaT
            let velocity = bundle.transformer(
                latents: latents, capFeats: capFeats, timestep: timestep)
            let dt = (sigmas[t + 1 ..< (t + 2)] - sigmaT).asType(latents.dtype)
            latents = latents + velocity.asType(latents.dtype) * dt
            eval(latents)
        }

        // 6. VAE decode (NHWC) and PNG encode.
        let scaled = latents.squeezed(axis: 1)                    // [16, H8, W8]
            .expandedDimensions(axis: 0)                          // [1, 16, H8, W8]
            .transposed(0, 2, 3, 1)                               // NHWC
            / ZVAEDecoder.scalingFactor + ZVAEDecoder.shiftFactor
        let rgb = bundle.decoder(scaled)                          // [1, H, W, 3] in [-1, 1]
        let pixels = MLX.round(
            clip(rgb.asType(.float32) / 2 + 0.5, min: 0, max: 1) * 255
        ).asType(.uint8).squeezed(axis: 0)                        // [H, W, 3] u8
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
                textEncoder: try ZTextEncoder(
                    ZWeights(componentDirectory: weightsDirectory.appendingPathComponent("text_encoder"))),
                transformer: try ZImageTransformerCore(
                    ZWeights(componentDirectory: weightsDirectory.appendingPathComponent("transformer"))),
                decoder: try ZVAEDecoder(
                    ZWeights(componentDirectory: weightsDirectory.appendingPathComponent("vae"))))
            bundle = loaded
            return loaded
        } catch let error as StoryboardEngineError {
            throw error
        } catch {
            throw StoryboardEngineError.generationFailed(
                "Couldn't load the storyboard model: \(String(describing: error))")
        }
    }

    // MARK: - Schedule

    /// linspace(1, 1/steps) put through the resolution shift
    /// (base 0.5 @ 256 tokens → 1.15 @ 4096 tokens), terminal 0 appended
    /// — LinearScheduler + the z-image-turbo registry values, verbatim.
    static func shiftedSigmas(steps: Int, width: Int, height: Int) -> MLXArray {
        let base = linspace(Float(1), 1 / Float(steps), count: steps).asType(.float32)
        let m: Float = (1.15 - 0.5) / (4096 - 256)
        let b: Float = 0.5 - m * 256
        let mu = m * Float(width) * Float(height) / 256 + b
        let shifted = exp(mu) / (exp(mu) + (1 / base - 1))
        return concatenated([shifted, MLXArray.zeros([1]).asType(.float32)])
    }

    // MARK: - PNG

    private static func encodePNG(pixels: [UInt8], width: Int, height: Int) throws -> Data {
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
