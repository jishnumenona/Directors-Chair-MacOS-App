// DirectorsChairServices/Storyboard/ZImageTextEncoder.swift
//
// The Qwen3-4B caption encoder of the Z-Image core (DC-0065), ported
// from mflux's z_image_text_encoder (MIT). Faithful details that matter:
// the whole encoder runs in float32; the caption feature is the hidden
// state BEFORE the last layer and BEFORE the final norm (mflux returns
// all_hidden_states[-2], so exactly 35 of the 36 layers execute); RoPE
// is the standard rotate-half formulation with θ=10⁶.
//
// One deliberate simplification, numerically identical: mflux pads the
// prompt to 512 and slices the valid prefix afterwards — under a causal
// mask, trailing pads can never influence valid positions, so we simply
// never feed them.

#if arch(arm64)
import Foundation
import MLX
import MLXFast

struct ZTextEncoderLayer {
    let inputNorm: ZRMSNorm
    let postAttentionNorm: ZRMSNorm
    let qProj: QLinear
    let kProj: QLinear
    let vProj: QLinear
    let oProj: QLinear
    let qNorm: ZRMSNorm
    let kNorm: ZRMSNorm
    let gateProj: QLinear
    let upProj: QLinear
    let downProj: QLinear

    init(_ w: ZWeights, layer i: Int) throws {
        let p = "layers.\(i)"
        inputNorm = try ZRMSNorm(w, "\(p).input_layernorm.weight", eps: 1e-6)
        postAttentionNorm = try ZRMSNorm(w, "\(p).post_attention_layernorm.weight", eps: 1e-6)
        qProj = try QLinear(w, "\(p).self_attn.q_proj")
        kProj = try QLinear(w, "\(p).self_attn.k_proj")
        vProj = try QLinear(w, "\(p).self_attn.v_proj")
        oProj = try QLinear(w, "\(p).self_attn.o_proj")
        qNorm = try ZRMSNorm(w, "\(p).self_attn.q_norm.weight", eps: 1e-5)
        kNorm = try ZRMSNorm(w, "\(p).self_attn.k_norm.weight", eps: 1e-5)
        gateProj = try QLinear(w, "\(p).mlp.gate_proj")
        upProj = try QLinear(w, "\(p).mlp.up_proj")
        downProj = try QLinear(w, "\(p).mlp.down_proj")
    }
}

struct ZTextEncoder {
    static let hiddenSize = 2560
    static let numLayers = 36
    static let usedLayers = 35   // all_hidden_states[-2]
    static let numHeads = 32
    static let numKVHeads = 8
    static let headDim = 128
    static let ropeTheta: Float = 1_000_000

    let embedding: QEmbedding
    let layers: [ZTextEncoderLayer]

    init(_ w: ZWeights) throws {
        embedding = try QEmbedding(w, "embed_tokens")
        layers = try (0 ..< Self.numLayers).map { try ZTextEncoderLayer(w, layer: $0) }
    }

    /// tokenIds → caption features [L, 2560] in the model precision.
    func encode(_ tokenIds: [Int32]) -> MLXArray {
        let seqLen = tokenIds.count
        var h = embedding(MLXArray(tokenIds)).asType(.float32)
            .reshaped([1, seqLen, Self.hiddenSize])

        // RoPE tables (fp32) and the additive causal mask.
        let invFreq = 1.0 / pow(Self.ropeTheta,
                                MLXArray(stride(from: 0, to: Self.headDim, by: 2)).asType(.float32) / Float(Self.headDim))
        let freqs = outer(MLXArray(0 ..< seqLen).asType(.float32), invFreq)
        let emb = concatenated([freqs, freqs], axis: -1)
        let cosTable = cos(emb).reshaped([1, seqLen, 1, Self.headDim])
        let sinTable = sin(emb).reshaped([1, seqLen, 1, Self.headDim])

        let idx = MLXArray(0 ..< seqLen)
        let causal = MLX.where(
            idx.reshaped([seqLen, 1]) .>= idx.reshaped([1, seqLen]),
            MLXArray(Float(0)),
            MLXArray(-Float.infinity)
        ).reshaped([1, 1, seqLen, seqLen])

        for layer in layers.prefix(Self.usedLayers) {
            h = Self.step(layer: layer, h: h, mask: causal,
                          cosTable: cosTable, sinTable: sinTable, seqLen: seqLen)
        }
        return h.reshaped([seqLen, Self.hiddenSize]).asType(ZImageCore.precision)
    }

    private static func step(layer: ZTextEncoderLayer, h: MLXArray, mask: MLXArray,
                             cosTable: MLXArray, sinTable: MLXArray, seqLen: Int) -> MLXArray {
        // Attention
        let normed = layer.inputNorm(h)
        var q = layer.qProj(normed).reshaped([1, seqLen, numHeads, headDim])
        var k = layer.kProj(normed).reshaped([1, seqLen, numKVHeads, headDim])
        var v = layer.vProj(normed).reshaped([1, seqLen, numKVHeads, headDim])
        q = rope(layer.qNorm(q), cosTable, sinTable)
        k = rope(layer.kNorm(k), cosTable, sinTable)
        k = repeated(k, count: numHeads / numKVHeads, axis: 2)
        v = repeated(v, count: numHeads / numKVHeads, axis: 2)
        let attn = MLXFast.scaledDotProductAttention(
            queries: q.transposed(0, 2, 1, 3),
            keys: k.transposed(0, 2, 1, 3),
            values: v.transposed(0, 2, 1, 3),
            scale: pow(Float(headDim), -0.5),
            mask: mask
        ).transposed(0, 2, 1, 3).reshaped([1, seqLen, numHeads * headDim])
        var out = h + layer.oProj(attn)

        // MLP
        let mlpIn = layer.postAttentionNorm(out)
        out = out + layer.downProj(zSilu(layer.gateProj(mlpIn)) * layer.upProj(mlpIn))
        return out
    }

    /// Standard rotate-half RoPE (HF/Qwen convention).
    private static func rope(_ x: MLXArray, _ cosTable: MLXArray, _ sinTable: MLXArray) -> MLXArray {
        let half = headDim / 2
        let x1 = x[.ellipsis, ..<half]
        let x2 = x[.ellipsis, half...]
        let rotated = concatenated([-x2, x1], axis: -1)
        return x * cosTable + rotated * sinTable
    }
}
#endif
