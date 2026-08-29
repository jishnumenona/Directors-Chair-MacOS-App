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
// Local edits (DC-0069): when the request carries edit regions, the
// render becomes an inpaint of the first reference at its own size —
// outside the marked regions the latents are pinned to the original's
// (re-noised to each step's σ, RePaint-style) and the final pixels are
// composited back, so an annotation changes what was marked and
// nothing else.
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
    /// References (and therefore inpaint outputs) are conditioned at no
    /// more than this many pixels — aspect-preserving downscale, then a
    /// centre crop to 16px multiples. Scaled to the Mac: the VAE's peak
    /// working set grows with area (measured 11 GB at 1024² before the
    /// bf16 path), so smaller-memory Macs edit at a smaller size rather
    /// than run out of memory (DC-0070).
    static let maxReferenceArea: Int = {
        let gib = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        if gib >= 30 { return 1024 * 1024 }
        if gib >= 20 { return 832 * 832 }
        return 640 * 640
    }()
    /// Soft edge of an edit region, as a fraction of the shorter side.
    static let regionFeather = 0.06

    private struct Bundle {
        let tokenizer: any Tokenizer
        let textEncoder: KleinTextEncoder
        let transformer: KleinTransformer
        let vae: KleinVAE
    }

    private var bundle: Bundle?
    /// Bumped per render; the idle-release task only fires if no newer
    /// render has started since it was scheduled.
    private var generation = 0

    /// Construction touches no MLX state (the metallib rule: SPM test
    /// runners abort on first MLX use) — the memory policy is applied on
    /// the first load instead.
    public init() {}

    // MARK: - Memory instrumentation (DC-0070)

    /// Opt-in per-stage memory trace: DC_KLEIN_MEMTRACE=1 prints MLX
    /// active / cache / peak and the process footprint after each stage.
    static let memoryTrace = ProcessInfo.processInfo.environment["DC_KLEIN_MEMTRACE"] == "1"

    public struct MemorySample: Sendable {
        public let label: String
        public let activeMB: Int
        public let cacheMB: Int
        public let peakMB: Int
        public let footprintMB: Int
    }

    /// MLX + process memory right now.
    public static func memorySample(_ label: String) -> MemorySample {
        let snap = GPU.snapshot()
        return MemorySample(label: label,
                            activeMB: snap.activeMemory / 1_048_576,
                            cacheMB: snap.cacheMemory / 1_048_576,
                            peakMB: snap.peakMemory / 1_048_576,
                            footprintMB: physicalFootprintMB())
    }

    /// The process's physical footprint (what Activity Monitor and the
    /// out-of-memory dialog report), in MB.
    public static func physicalFootprintMB() -> Int {
        var usage = rusage_info_v4()
        let rc = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
            }
        }
        return rc == 0 ? Int(usage.ri_phys_footprint / 1_048_576) : -1
    }

    @inline(__always) static func trace(_ label: String) {
        guard memoryTrace else { return }
        let m = memorySample(label)
        print("[KleinMem] \(label): active \(m.activeMB) MB · cache \(m.cacheMB) MB · peak \(m.peakMB) MB · footprint \(m.footprintMB) MB")
    }

    public func render(_ request: OnDeviceRenderRequest, weightsDirectory: URL) async throws -> Data {
        generation += 1
        defer { finishRender() }
        let bundle = try await loadedBundle(weightsDirectory: weightsDirectory)
        Self.trace("loaded")

        // 0. Decode references. An inpaint renders at the source's size.
        //    A composition from several pictures shares the reference token
        //    budget between them (identity survives 512²; time does not
        //    survive four 1024² references).
        let inpaintAsk = !request.editRegions.isEmpty && !request.references.isEmpty
        let perReferenceArea = inpaintAsk
            ? Self.maxReferenceArea
            : max(512 * 512, Self.maxReferenceArea / max(1, request.references.count))
        var sources: [MLXArray] = []
        for data in request.references {
            guard let image = Self.referenceArray(from: data, maxArea: perReferenceArea) else {
                throw StoryboardEngineError.generationFailed("A reference picture could not be read.")
            }
            sources.append(image)
        }
        let inpainting = !request.editRegions.isEmpty && !sources.isEmpty
        let (w, h): (Int, Int) = inpainting
            ? (sources[0].dim(2), sources[0].dim(1))
            : (max(256, 16 * (request.width / 16)), max(256, 16 * (request.height / 16)))

        // 1. Prompt → the klein context (Qwen chat template, thinking off,
        //    padded to 512 inside the encoder).
        let ids = Self.tokenIds(for: request.prompt, tokenizer: bundle.tokenizer)
        let context = bundle.textEncoder.encode(ids).expandedDimensions(axis: 0)   // [1, 512, 7680]
        eval(context)
        Self.trace("text encoded")
        let textIds = Self.textIds(count: KleinTextEncoder.maxTokens)

        // 2. Seeded noise in patch space, packed row-major.
        let (lh, lw) = (h / 16, w / 16)
        let frameSeed = request.seed ?? UInt64.random(in: 0 ..< UInt64(Int32.max))
        let noise = MLXRandom.normal([1, KleinVAE.packedChannels, lh, lw],
                                     key: MLXRandom.key(frameSeed))
            .asType(Self.precision)
            .reshaped([1, KleinVAE.packedChannels, lh * lw])
            .transposed(0, 2, 1)                                          // [1, N, 128]
        var latents = noise
        let imageIds = Self.gridIds(height: lh, width: lw, t: 0)

        // 3. References → extra image tokens on time planes 10, 20, …
        var refTokens: [MLXArray] = []
        var refIds: [MLXArray] = []
        var clean: MLXArray?
        for (i, image) in sources.enumerated() {
            let encoded = bundle.vae.encodeReference(image.asType(Self.precision))
            refTokens.append(encoded.tokens)
            refIds.append(Self.gridIds(height: encoded.height, width: encoded.width, t: Int32(10 + 10 * i)))
            eval(encoded.tokens)
            if i == 0 && inpainting { clean = encoded.tokens }             // same grid as the output
        }
        let allIds = concatenated([imageIds] + refIds, axis: 0)
        let n = lh * lw
        Self.trace("references encoded")

        // Token-space keep mask for an inpaint: 1 = repaint, 0 = keep.
        var tokenMask: MLXArray?
        if inpainting {
            let values = Self.regionMask(regions: request.editRegions, width: w, height: h,
                                         gridWidth: lw, gridHeight: lh, feather: Self.regionFeather)
            tokenMask = MLXArray(values, [1, n, 1]).asType(Self.precision)
        }

        // 4. Resolution-shifted schedule and the Euler loop.
        let sigmas = Self.schedule(imageTokens: n, steps: Self.steps)
        for t in 0 ..< Self.steps {
            let hidden = refTokens.isEmpty ? latents : concatenated([latents] + refTokens, axis: 1)
            let velocity = bundle.transformer(
                latents: hidden, context: context,
                timestep: MLXArray(sigmas[t] * 1000),
                imageIds: allIds, textIds: textIds)[0..., ..<n, 0...]
            let next = sigmas[t + 1]
            let dt = MLXArray(next - sigmas[t]).asType(latents.dtype)
            latents = latents + dt * velocity.asType(latents.dtype)
            if let tokenMask, let clean {
                // Outside the marked regions, the trajectory is the
                // original re-noised to σ_{t+1}; at σ=0 that is the original.
                let pinned = clean * (1 - next) + noise * next
                latents = tokenMask * latents + (1 - tokenMask) * pinned
            }
            eval(latents)
            Self.trace("step \(t + 1)/\(Self.steps)")
        }

        // 5. Decode; for an inpaint, composite the untouched pixels back.
        var rgb = bundle.vae.decodePacked(latents, height: lh, width: lw).asType(.float32) // [1, H, W, 3] in [-1, 1]
        if inpainting {
            let pixelMask = MLXArray(
                Self.regionMask(regions: request.editRegions, width: w, height: h,
                                gridWidth: w, gridHeight: h, feather: Self.regionFeather),
                [1, h, w, 1])
            rgb = pixelMask * rgb + (1 - pixelMask) * sources[0]
        }
        let pixels = MLX.round(clip(rgb / 2 + 0.5, min: 0, max: 1) * 255)
            .asType(.uint8).squeezed(axis: 0)
        eval(pixels)
        Self.trace("decoded")
        return try Self.encodePNG(pixels: pixels.asArray(UInt8.self), width: w, height: h)
    }

    // MARK: - Loading

    /// Drops the resident weights and returns MLX's buffer cache to the
    /// system. The next render reloads (~1s from disk cache).
    public func releaseModel() {
        bundle = nil
        MLXMemoryPolicy.releaseCache()
        Self.trace("released")
    }

    /// After every render: hand the cache back immediately (the working
    /// set is rebuilt in milliseconds) and arm the idle release.
    private func finishRender() {
        MLXMemoryPolicy.releaseCache()
        Self.trace("cache released")
        let mine = generation
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(MLXMemoryPolicy.idleReleaseInterval * 1_000_000_000))
            await self?.releaseIfIdle(since: mine)
        }
    }

    private func releaseIfIdle(since scheduled: Int) {
        guard scheduled == generation, bundle != nil else { return }
        releaseModel()
    }

    /// Whether weights are resident (tests and the Settings status).
    public var isModelResident: Bool { bundle != nil }

    private func loadedBundle(weightsDirectory: URL) async throws -> Bundle {
        if let bundle { return bundle }
        MLXMemoryPolicy.apply()
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

    // MARK: - Edit regions

    /// Soft mask over a grid (token grid or pixel grid) for the marked
    /// regions: 1 inside a region, falling to 0 over `feather`, distances
    /// measured as fractions of the picture's shorter side. Pure Swift so
    /// it is testable without MLX.
    static func regionMask(regions: [EditRegion], width: Int, height: Int,
                           gridWidth: Int, gridHeight: Int, feather: Double) -> [Float] {
        let shorter = Double(min(width, height))
        var values = [Float](repeating: 0, count: gridWidth * gridHeight)
        for row in 0 ..< gridHeight {
            let cy = (Double(row) + 0.5) / Double(gridHeight)
            for col in 0 ..< gridWidth {
                let cx = (Double(col) + 0.5) / Double(gridWidth)
                var best = 0.0
                for region in regions {
                    let dx = (cx - region.x) * Double(width)
                    let dy = (cy - region.y) * Double(height)
                    let distance = (dx * dx + dy * dy).squareRoot() / shorter
                    let value = feather > 0
                        ? min(1, max(0, (region.radius + feather - distance) / feather))
                        : (distance <= region.radius ? 1 : 0)
                    best = max(best, value)
                }
                values[row * gridWidth + col] = Float(best)
            }
        }
        return values
    }

    // MARK: - Reference pictures

    /// Decodes a PNG/JPEG into [1, H, W, 3] fp32 in [-1, 1] at the
    /// conditioning size: aspect-preserving downscale to ≤ 1024² pixels,
    /// then a centre crop so both sides are multiples of 16 (mflux
    /// prepare_reference_image).
    static func referenceArray(from data: Data, maxArea: Int = KleinCore.maxReferenceArea) -> MLXArray? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        var (w, h) = (image.width, image.height)
        if w * h > maxArea {
            let scale = (Float(maxArea) / Float(w * h)).squareRoot()
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
        return MLXArray(floats, [1, th, tw, 3]) * 2 - 1
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
