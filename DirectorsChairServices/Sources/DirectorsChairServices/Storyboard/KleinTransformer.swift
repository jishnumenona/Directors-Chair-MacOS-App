// DirectorsChairServices/Storyboard/KleinTransformer.swift
//
// The FLUX.2 [klein] 4B rectified-flow transformer (DC-0068), ported
// from mflux (MIT). Shape of the thing: text tokens (7,680-wide Qwen3
// features) and image tokens (128-wide patches) are embedded to 3,072,
// pass through 5 double-stream blocks (separate weights for the two
// streams, one joint attention), are concatenated, pass through 20
// single-stream blocks (attention and MLP computed in parallel from one
// projection), and the image half is read out. Modulation is computed
// ONCE from the timestep and shared by every block — that is why the
// checkpoint has three modulation modules, not one per block. Position:
// a 4-axis RoPE (t, h, w, token) with θ=2000; reference pictures ride
// in as extra image tokens on their own t plane.

#if arch(arm64)
import Foundation
import MLX
import MLXFast

struct KleinDoubleBlock {
    let toQ: QLinear, toK: QLinear, toV: QLinear, toOut: QLinear
    let normQ: ZRMSNorm, normK: ZRMSNorm
    let addQ: QLinear, addK: QLinear, addV: QLinear, toAddOut: QLinear
    let normAddedQ: ZRMSNorm, normAddedK: ZRMSNorm
    let ffIn: QLinear, ffOut: QLinear
    let ffContextIn: QLinear, ffContextOut: QLinear

    init(_ w: ZWeights, _ p: String) throws {
        toQ = try QLinear(w, "\(p).attn.to_q"); toK = try QLinear(w, "\(p).attn.to_k")
        toV = try QLinear(w, "\(p).attn.to_v"); toOut = try QLinear(w, "\(p).attn.to_out")
        normQ = try ZRMSNorm(w, "\(p).attn.norm_q.weight", eps: 1e-5)
        normK = try ZRMSNorm(w, "\(p).attn.norm_k.weight", eps: 1e-5)
        addQ = try QLinear(w, "\(p).attn.add_q_proj"); addK = try QLinear(w, "\(p).attn.add_k_proj")
        addV = try QLinear(w, "\(p).attn.add_v_proj"); toAddOut = try QLinear(w, "\(p).attn.to_add_out")
        normAddedQ = try ZRMSNorm(w, "\(p).attn.norm_added_q.weight", eps: 1e-5)
        normAddedK = try ZRMSNorm(w, "\(p).attn.norm_added_k.weight", eps: 1e-5)
        ffIn = try QLinear(w, "\(p).ff.linear_in"); ffOut = try QLinear(w, "\(p).ff.linear_out")
        ffContextIn = try QLinear(w, "\(p).ff_context.linear_in")
        ffContextOut = try QLinear(w, "\(p).ff_context.linear_out")
    }
}

struct KleinSingleBlock {
    let toQKVMLP: QLinear
    let normQ: ZRMSNorm, normK: ZRMSNorm
    let toOut: QLinear

    init(_ w: ZWeights, _ p: String) throws {
        toQKVMLP = try QLinear(w, "\(p).attn.to_qkv_mlp_proj")
        normQ = try ZRMSNorm(w, "\(p).attn.norm_q.weight", eps: 1e-5)
        normK = try ZRMSNorm(w, "\(p).attn.norm_k.weight", eps: 1e-5)
        toOut = try QLinear(w, "\(p).attn.to_out")
    }
}

struct KleinTransformer {
    static let dim = 3072
    static let heads = 24
    static let headDim = 128
    static let mlpHidden = 9216            // dim × 3
    static let inChannels = 128
    static let contextDim = 7680
    static let numDouble = 5
    static let numSingle = 20
    static let ropeTheta: Float = 2000
    static let axesDim = [32, 32, 32, 32]

    let timeLinear1: QLinear, timeLinear2: QLinear
    let modImg: QLinear, modTxt: QLinear, modSingle: QLinear
    let xEmbedder: QLinear, contextEmbedder: QLinear
    let doubles: [KleinDoubleBlock]
    let singles: [KleinSingleBlock]
    let normOutLinear: QLinear
    let projOut: QLinear

    init(_ w: ZWeights) throws {
        timeLinear1 = try QLinear(w, "time_guidance_embed.linear_1")
        timeLinear2 = try QLinear(w, "time_guidance_embed.linear_2")
        modImg = try QLinear(w, "double_stream_modulation_img.linear")
        modTxt = try QLinear(w, "double_stream_modulation_txt.linear")
        modSingle = try QLinear(w, "single_stream_modulation.linear")
        xEmbedder = try QLinear(w, "x_embedder")
        contextEmbedder = try QLinear(w, "context_embedder")
        doubles = try (0 ..< Self.numDouble).map { try KleinDoubleBlock(w, "transformer_blocks.\($0)") }
        singles = try (0 ..< Self.numSingle).map { try KleinSingleBlock(w, "single_transformer_blocks.\($0)") }
        normOutLinear = try QLinear(w, "norm_out.linear")
        projOut = try QLinear(w, "proj_out")
    }

    /// One velocity prediction.
    /// - latents: [1, N, 128] image (and reference) tokens
    /// - context: [1, T, 7680]
    /// - timestep: σ·1000 as a scalar array
    /// - imageIds / textIds: [N, 4] / [T, 4] Int32 (t, h, w, token)
    func callAsFunction(latents: MLXArray, context: MLXArray, timestep: MLXArray,
                        imageIds: MLXArray, textIds: MLXArray) -> MLXArray {
        let precision = KleinCore.precision

        // Timestep embedding (sinusoidal fp32 → two quantized linears).
        let features = zTimestepFeatures(timestep.reshaped([1]), dim: 256).asType(precision)
        let temb = timeLinear2(zSilu(timeLinear1(features)))              // [1, 3072]

        var x = xEmbedder(latents)
        var ctx = contextEmbedder(context)

        // Rotary tables over the joint [text, image] sequence.
        let (cosT, sinT) = Self.ropeTables(concatenated([textIds, imageIds], axis: 0))

        // Shared modulation: (shift, scale, gate) × {msa, mlp} per stream.
        let modI = Self.split(modImg(zSilu(temb)), parts: 6)
        let modT = Self.split(modTxt(zSilu(temb)), parts: 6)
        let modS = Self.split(modSingle(zSilu(temb)), parts: 3)

        for b in doubles {
            (ctx, x) = Self.double(b, x: x, ctx: ctx, modI: modI, modT: modT, cosT: cosT, sinT: sinT)
            eval(ctx, x)                                                  // bound the graph (DC-0070)
        }
        var h = concatenated([ctx, x], axis: 1)
        for b in singles {
            h = Self.single(b, h, mod: modS, cosT: cosT, sinT: sinT)
            eval(h)
        }
        h = h[0..., ctx.dim(1)..., 0...]

        // AdaLayerNormContinuous: scale first, then shift.
        let ada = normOutLinear(zSilu(temb).asType(precision))
        let scale = ada[0..., ..<Self.dim].reshaped([1, 1, Self.dim])
        let shift = ada[0..., Self.dim...].reshaped([1, 1, Self.dim])
        h = zLayerNorm(h) * (1 + scale) + shift
        return projOut(h)
    }

    // MARK: - Blocks

    private static func double(_ b: KleinDoubleBlock, x: MLXArray, ctx: MLXArray,
                               modI: [MLXArray], modT: [MLXArray],
                               cosT: MLXArray, sinT: MLXArray) -> (MLXArray, MLXArray) {
        let (shiftMsa, scaleMsa, gateMsa, shiftMlp, scaleMlp, gateMlp) =
            (modI[0], modI[1], modI[2], modI[3], modI[4], modI[5])
        let (cShiftMsa, cScaleMsa, cGateMsa, cShiftMlp, cScaleMlp, cGateMlp) =
            (modT[0], modT[1], modT[2], modT[3], modT[4], modT[5])

        let normX = (1 + scaleMsa) * zLayerNorm(x) + shiftMsa
        let normC = (1 + cScaleMsa) * zLayerNorm(ctx) + cShiftMsa

        let (n, t) = (x.dim(1), ctx.dim(1))
        var q = qkvHeads(b.toQ(normX), n); var k = qkvHeads(b.toK(normX), n); let v = qkvHeads(b.toV(normX), n)
        q = rmsHeads(b.normQ, q); k = rmsHeads(b.normK, k)
        var cq = qkvHeads(b.addQ(normC), t); var ck = qkvHeads(b.addK(normC), t); let cv = qkvHeads(b.addV(normC), t)
        cq = rmsHeads(b.normAddedQ, cq); ck = rmsHeads(b.normAddedK, ck)

        // Joint sequence: [context, image].
        var jq = concatenated([cq, q], axis: 2)
        var jk = concatenated([ck, k], axis: 2)
        let jv = concatenated([cv, v], axis: 2)
        (jq, jk) = rope(jq, jk, cosT, sinT)
        let attn = MLXFast.scaledDotProductAttention(
            queries: jq, keys: jk, values: jv, scale: pow(Float(headDim), -0.5), mask: nil
        ).transposed(0, 2, 1, 3).reshaped([1, t + n, heads * headDim])

        let ctxAttn = b.toAddOut(attn[0..., ..<t, 0...])
        let xAttn = b.toOut(attn[0..., t..., 0...])

        var xOut = x + gateMsa * xAttn
        var cOut = ctx + cGateMsa * ctxAttn

        let normX2 = (1 + scaleMlp) * zLayerNorm(xOut) + shiftMlp
        xOut = xOut + gateMlp * b.ffOut(swiGLU(b.ffIn(normX2)))
        let normC2 = (1 + cScaleMlp) * zLayerNorm(cOut) + cShiftMlp
        cOut = cOut + cGateMlp * b.ffContextOut(swiGLU(b.ffContextIn(normC2)))
        return (cOut, xOut)
    }

    private static func single(_ b: KleinSingleBlock, _ h: MLXArray, mod: [MLXArray],
                               cosT: MLXArray, sinT: MLXArray) -> MLXArray {
        let (shift, scale, gate) = (mod[0], mod[1], mod[2])
        let normed = (1 + scale) * zLayerNorm(h) + shift
        let s = h.dim(1)
        let proj = b.toQKVMLP(normed)
        let inner = heads * headDim
        var q = qkvHeads(proj[0..., 0..., ..<inner], s)
        var k = qkvHeads(proj[0..., 0..., inner ..< (2 * inner)], s)
        let v = qkvHeads(proj[0..., 0..., (2 * inner) ..< (3 * inner)], s)
        let mlp = proj[0..., 0..., (3 * inner)...]
        q = rmsHeads(b.normQ, q); k = rmsHeads(b.normK, k)
        (q, k) = rope(q, k, cosT, sinT)
        let attn = MLXFast.scaledDotProductAttention(
            queries: q, keys: k, values: v, scale: pow(Float(headDim), -0.5), mask: nil
        ).transposed(0, 2, 1, 3).reshaped([1, s, inner])
        let out = b.toOut(concatenated([attn, swiGLU(mlp)], axis: -1))
        return h + gate * out
    }

    // MARK: - Helpers

    /// [1, S, H·D] → [1, H, S, D]
    @inline(__always) private static func qkvHeads(_ x: MLXArray, _ s: Int) -> MLXArray {
        x.reshaped([1, s, heads, headDim]).transposed(0, 2, 1, 3)
    }

    /// Per-head RMS norm computed in fp32, returned in the model precision.
    @inline(__always) private static func rmsHeads(_ norm: ZRMSNorm, _ x: MLXArray) -> MLXArray {
        norm(x.asType(.float32)).asType(x.dtype)
    }

    @inline(__always) private static func swiGLU(_ x: MLXArray) -> MLXArray {
        let half = x.dim(-1) / 2
        return zSilu(x[.ellipsis, ..<half]) * x[.ellipsis, half...]
    }

    private static func split(_ x: MLXArray, parts: Int) -> [MLXArray] {
        let width = x.dim(-1) / parts
        return (0 ..< parts).map { x[0..., ($0 * width) ..< (($0 + 1) * width)].reshaped([1, 1, width]) }
    }

    /// cos/sin tables [S, 64]: for each of the four id axes, 16 frequencies
    /// 1/θ^(2i/32), concatenated in axis order.
    static func ropeTables(_ ids: MLXArray) -> (MLXArray, MLXArray) {
        var cosParts: [MLXArray] = []
        var sinParts: [MLXArray] = []
        let pos = ids.asType(.float32)
        for (axis, dim) in axesDim.enumerated() {
            let scale = MLXArray(stride(from: 0, to: dim, by: 2)).asType(.float32) / Float(dim)
            let omega = 1.0 / pow(ropeTheta, scale)                          // [dim/2]
            let out = outer(pos[0..., axis], omega)                          // [S, dim/2]
            cosParts.append(cos(out)); sinParts.append(sin(out))
        }
        return (concatenated(cosParts, axis: -1), concatenated(sinParts, axis: -1))
    }

    /// Interleaved-pair rotation in fp32 (mflux apply_rope_bshd).
    private static func rope(_ q: MLXArray, _ k: MLXArray, _ cosT: MLXArray, _ sinT: MLXArray) -> (MLXArray, MLXArray) {
        let s = cosT.dim(0), half = cosT.dim(1)
        let c = cosT.reshaped([1, 1, s, half]), sn = sinT.reshaped([1, 1, s, half])
        func mix(_ x: MLXArray) -> MLXArray {
            let f = x.asType(.float32).reshaped([1, heads, s, half, 2])
            let real = f[.ellipsis, 0], imag = f[.ellipsis, 1]
            let out0 = real * c - imag * sn
            let out1 = imag * c + real * sn
            return stacked([out0, out1], axis: -1).reshaped([1, heads, s, headDim]).asType(x.dtype)
        }
        return (mix(q), mix(k))
    }
}
#endif
