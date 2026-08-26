// DirectorsChairServices/Storyboard/ZImageTransformer.swift
//
// The S3-DiT denoiser of the Z-Image core (DC-0065), ported from mflux
// (MIT): 30 unified layers over [image ⧺ caption] tokens plus 2 noise
// refiners and 2 context refiners; 2×2 latent patches; 3-axis RoPE
// (θ=256, dims 32/48/48) where axis 0 orders caption-then-image and
// axes 1/2 are the patch grid; adaLN-tanh modulation from a 256-d
// timestep embedding; the model's output is NEGATED velocity.

#if arch(arm64)
import Foundation
import MLX
import MLXFast

struct ZDiTBlock {
    let toQ: QLinear
    let toK: QLinear
    let toV: QLinear
    let toOut: QLinear
    let normQ: ZRMSNorm
    let normK: ZRMSNorm
    let w1: QLinear
    let w2: QLinear
    let w3: QLinear
    let attentionNorm1: ZRMSNorm
    let attentionNorm2: ZRMSNorm
    let ffnNorm1: ZRMSNorm
    let ffnNorm2: ZRMSNorm
    /// Present on noise-refiner and main layers; absent on context blocks.
    let adaLN: QLinear?

    init(_ w: ZWeights, _ p: String, modulated: Bool) throws {
        toQ = try QLinear(w, "\(p).attention.to_q")
        toK = try QLinear(w, "\(p).attention.to_k")
        toV = try QLinear(w, "\(p).attention.to_v")
        toOut = try QLinear(w, "\(p).attention.to_out.0")
        normQ = try ZRMSNorm(w, "\(p).attention.norm_q.weight", eps: 1e-5)
        normK = try ZRMSNorm(w, "\(p).attention.norm_k.weight", eps: 1e-5)
        w1 = try QLinear(w, "\(p).feed_forward.w1")
        w2 = try QLinear(w, "\(p).feed_forward.w2")
        w3 = try QLinear(w, "\(p).feed_forward.w3")
        attentionNorm1 = try ZRMSNorm(w, "\(p).attention_norm1.weight", eps: 1e-5)
        attentionNorm2 = try ZRMSNorm(w, "\(p).attention_norm2.weight", eps: 1e-5)
        ffnNorm1 = try ZRMSNorm(w, "\(p).ffn_norm1.weight", eps: 1e-5)
        ffnNorm2 = try ZRMSNorm(w, "\(p).ffn_norm2.weight", eps: 1e-5)
        adaLN = modulated ? try QLinear(w, "\(p).adaLN_modulation.0") : nil
    }

    func callAsFunction(_ x: MLXArray, freqs: MLXArray, tEmb: MLXArray?) -> MLXArray {
        var x = x
        if let adaLN, let tEmb {
            let modulation = adaLN(tEmb).reshaped([1, 1, 4 * ZImageTransformerCore.dim])
            let parts = split(modulation, parts: 4, axis: 2)
            let scaleMSA = 1.0 + parts[0]
            let gateMSA = tanh(parts[1])
            let scaleMLP = 1.0 + parts[2]
            let gateMLP = tanh(parts[3])
            let attnOut = Self.attention(self, attentionNorm1(x) * scaleMSA, freqs: freqs)
            x = x + gateMSA * attentionNorm2(attnOut)
            let ffnOut = Self.feedForward(self, ffnNorm1(x) * scaleMLP)
            x = x + gateMLP * ffnNorm2(ffnOut)
        } else {
            let attnOut = Self.attention(self, attentionNorm1(x), freqs: freqs)
            x = x + attentionNorm2(attnOut)
            let ffnOut = Self.feedForward(self, ffnNorm1(x))
            x = x + ffnNorm2(ffnOut)
        }
        return x
    }

    private static func feedForward(_ b: ZDiTBlock, _ x: MLXArray) -> MLXArray {
        b.w2(zSilu(b.w1(x)) * b.w3(x))
    }

    private static func attention(_ b: ZDiTBlock, _ x: MLXArray, freqs: MLXArray) -> MLXArray {
        let (heads, headDim, dim) = (ZImageTransformerCore.heads,
                                     ZImageTransformerCore.headDim,
                                     ZImageTransformerCore.dim)
        let seqLen = x.dim(1)
        var q = b.normQ(b.toQ(x).reshaped([1, seqLen, heads, headDim]))
        var k = b.normK(b.toK(x).reshaped([1, seqLen, heads, headDim]))
        let v = b.toV(x).reshaped([1, seqLen, heads, headDim])
        q = rotate(q, freqs: freqs)
        k = rotate(k, freqs: freqs)
        let attn = MLXFast.scaledDotProductAttention(
            queries: q.transposed(0, 2, 1, 3),
            keys: k.transposed(0, 2, 1, 3),
            values: v.transposed(0, 2, 1, 3),
            scale: pow(Float(headDim), -0.5),
            mask: nil
        ).transposed(0, 2, 1, 3).reshaped([1, seqLen, dim])
        return b.toOut(attn)
    }

    /// Interleaved-pair rotary application: x viewed as […, 64, 2]
    /// complex, multiplied by freqs [L, 64, 2] (cos, sin).
    private static func rotate(_ x: MLXArray, freqs: MLXArray) -> MLXArray {
        let (b, l, h, d) = (x.dim(0), x.dim(1), x.dim(2), x.dim(3))
        let pairs = x.reshaped([b, l, h, d / 2, 2])
        let f = freqs.reshaped([1, l, 1, d / 2, 2])
        let xr = pairs[.ellipsis, 0], xi = pairs[.ellipsis, 1]
        let fc = f[.ellipsis, 0], fs = f[.ellipsis, 1]
        let outR = xr * fc - xi * fs
        let outI = xr * fs + xi * fc
        return stacked([outR, outI], axis: -1).reshaped([b, l, h, d])
    }
}

struct ZImageTransformerCore {
    static let dim = 3840
    static let heads = 30
    static let headDim = 128
    static let patch = 2
    static let inChannels = 16
    static let ropeTheta: Float = 256
    static let axesDims = [32, 48, 48]
    static let axesLens = [1024, 512, 512]
    static let tScale: Float = 1000

    let xEmbedder: QLinear             // all_x_embedder.2-1
    let finalLinear: QLinear           // all_final_layer.2-1.linear
    let finalAdaLN: QLinear            // all_final_layer.2-1.adaLN_modulation.0
    let tEmbedLinear1: QLinear
    let tEmbedLinear2: QLinear
    let capNorm: ZRMSNorm              // cap_embedder.0
    let capLinear: QLinear             // cap_embedder.1
    let xPadToken: MLXArray
    let capPadToken: MLXArray
    let noiseRefiner: [ZDiTBlock]
    let contextRefiner: [ZDiTBlock]
    let layers: [ZDiTBlock]
    /// Per-axis RoPE tables [len, dim/2, 2], fp32.
    let ropeTables: [MLXArray]

    init(_ w: ZWeights) throws {
        xEmbedder = try QLinear(w, "all_x_embedder.2-1")
        finalLinear = try QLinear(w, "all_final_layer.2-1.linear")
        finalAdaLN = try QLinear(w, "all_final_layer.2-1.adaLN_modulation.0")
        tEmbedLinear1 = try QLinear(w, "t_embedder.linear1")
        tEmbedLinear2 = try QLinear(w, "t_embedder.linear2")
        capNorm = try ZRMSNorm(w, "cap_embedder.0.weight", eps: 1e-5)
        capLinear = try QLinear(w, "cap_embedder.1")
        xPadToken = try w.tensor("x_pad_token")
        capPadToken = try w.tensor("cap_pad_token")
        noiseRefiner = try (0 ..< 2).map { try ZDiTBlock(w, "noise_refiner.\($0)", modulated: true) }
        contextRefiner = try (0 ..< 2).map { try ZDiTBlock(w, "context_refiner.\($0)", modulated: false) }
        layers = try (0 ..< 30).map { try ZDiTBlock(w, "layers.\($0)", modulated: true) }
        ropeTables = zip(Self.axesDims, Self.axesLens).map { d, len in
            let freqs = 1.0 / pow(Self.ropeTheta,
                                  MLXArray(stride(from: 0, to: d, by: 2)).asType(.float32) / Float(d))
            let angles = outer(MLXArray(0 ..< len).asType(.float32), freqs)
            return stacked([cos(angles), sin(angles)], axis: -1)   // [len, d/2, 2]
        }
    }

    /// One denoising evaluation: latents [16, 1, H8, W8] + caption
    /// features [L, 2560] + timestep (1 − σ) → negated velocity, same
    /// shape as latents.
    func callAsFunction(latents: MLXArray, capFeats: MLXArray, timestep: MLXArray) -> MLXArray {
        let h8 = latents.dim(2), w8 = latents.dim(3)
        let hT = h8 / Self.patch, wT = w8 / Self.patch

        // Timestep embedding (fp32 features through quantized MLP).
        let tFeatures = zTimestepFeatures(timestep.asType(.float32) * Self.tScale)
        let tEmb = tEmbedLinear2(zSilu(tEmbedLinear1(tFeatures)))   // [1, 256]

        // ---- Caption tokens: pad count to %32, replicate-last, pos axis0 = 1…n
        let capLen = capFeats.dim(0)
        let capPad = (32 - capLen % 32) % 32
        let capTotal = capLen + capPad
        var cap = capFeats
        if capPad > 0 {
            let lastRow = cap[(capLen - 1)...]
            cap = concatenated([cap, broadcast(lastRow, to: [capPad, cap.dim(1)])], axis: 0)
        }
        var capEmb = capLinear(capNorm(cap))
        if capPad > 0 {
            let mask = concatenated([MLXArray.zeros([capLen]).asType(.bool),
                                     MLXArray.ones([capPad]).asType(.bool)])
            capEmb = MLX.where(mask.reshaped([capTotal, 1]), capPadToken, capEmb)
        }
        let capFreqs = ropeFrequencies(
            axis0: Array(1 ... capTotal).map { Int32($0) },
            axis1: [Int32](repeating: 0, count: capTotal),
            axis2: [Int32](repeating: 0, count: capTotal))

        // ---- Image tokens: 2×2 patchify, pad to %32, pos axis0 = capTotal+1
        var x = latents.reshaped([Self.inChannels, 1, 1, hT, Self.patch, wT, Self.patch])
            .transposed(1, 3, 5, 2, 4, 6, 0)
            .reshaped([hT * wT, Self.patch * Self.patch * Self.inChannels])
        let xLen = hT * wT
        let xPad = (32 - xLen % 32) % 32
        let xTotal = xLen + xPad
        if xPad > 0 {
            let lastRow = x[(xLen - 1)...]
            x = concatenated([x, broadcast(lastRow, to: [xPad, x.dim(1)])], axis: 0)
        }
        var xEmb = xEmbedder(x)
        if xPad > 0 {
            let mask = concatenated([MLXArray.zeros([xLen]).asType(.bool),
                                     MLXArray.ones([xPad]).asType(.bool)])
            xEmb = MLX.where(mask.reshaped([xTotal, 1]), xPadToken, xEmb)
        }
        var axis0 = [Int32](repeating: Int32(capTotal + 1), count: xLen)
        var axis1: [Int32] = []
        var axis2: [Int32] = []
        axis1.reserveCapacity(xLen); axis2.reserveCapacity(xLen)
        for row in 0 ..< hT {
            for col in 0 ..< wT {
                axis1.append(Int32(row)); axis2.append(Int32(col))
            }
        }
        axis0 += [Int32](repeating: 0, count: xPad)
        axis1 += [Int32](repeating: 0, count: xPad)
        axis2 += [Int32](repeating: 0, count: xPad)
        let xFreqs = ropeFrequencies(axis0: axis0, axis1: axis1, axis2: axis2)

        // ---- Refiners
        var xSeq = xEmb.reshaped([1, xTotal, Self.dim])
        for block in noiseRefiner { xSeq = block(xSeq, freqs: xFreqs, tEmb: tEmb) }
        var capSeq = capEmb.reshaped([1, capTotal, Self.dim])
        for block in contextRefiner { capSeq = block(capSeq, freqs: capFreqs, tEmb: nil) }

        // ---- Unified stream
        var unified = concatenated([xSeq, capSeq], axis: 1)
        let unifiedFreqs = concatenated([xFreqs, capFreqs], axis: 0)
        for block in layers { unified = block(unified, freqs: unifiedFreqs, tEmb: tEmb) }

        // ---- Final layer (LayerNorm affine=false) and unpatchify
        let finalScale = (1.0 + finalAdaLN(zSilu(tEmb))).reshaped([1, 1, Self.dim])
        let normed = MLXFast.layerNorm(unified, weight: nil, bias: nil, eps: 1e-6) * finalScale
        let projected = finalLinear(normed)

        let out = projected[0, ..<xLen]
            .reshaped([1, hT, wT, 1, Self.patch, Self.patch, Self.inChannels])
            .transposed(6, 0, 3, 1, 4, 2, 5)
            .reshaped([Self.inChannels, 1, h8, w8])
        return -out
    }

    /// Concatenated per-axis table lookups → [L, 64, 2].
    private func ropeFrequencies(axis0: [Int32], axis1: [Int32], axis2: [Int32]) -> MLXArray {
        let parts = [
            take(ropeTables[0], MLXArray(axis0), axis: 0),
            take(ropeTables[1], MLXArray(axis1), axis: 0),
            take(ropeTables[2], MLXArray(axis2), axis: 0),
        ]
        return concatenated(parts, axis: 1)
    }
}
#endif
