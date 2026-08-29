// DirectorsChairServices/Storyboard/KleinTextEncoder.swift
//
// The Qwen3-4B prompt encoder of the FLUX.2 klein core (DC-0068), ported
// from mflux's flux2 Qwen3TextEncoder (MIT). klein does not use one
// hidden state: it concatenates the outputs of layers 9, 18 and 27
// (index 0 = the embeddings) into a 7,680-wide feature per token. And
// it keeps the prompt padded to 512 tokens — every pad position rides
// into the transformer as a real token — so this encoder pads too, and
// masks pad KEYS (causal + padding mask) exactly like the reference.
// Hidden states stay in the model precision; RMS norms and attention
// accumulate in fp32, as in mflux.

#if arch(arm64)
import Foundation
import MLX
import MLXFast

struct KleinTextEncoderLayer {
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

    init(_ w: ZWeights, layer i: Int, eps: Float) throws {
        let p = "layers.\(i)"
        inputNorm = try ZRMSNorm(w, "\(p).input_layernorm.weight", eps: eps)
        postAttentionNorm = try ZRMSNorm(w, "\(p).post_attention_layernorm.weight", eps: eps)
        qProj = try QLinear(w, "\(p).self_attn.q_proj")
        kProj = try QLinear(w, "\(p).self_attn.k_proj")
        vProj = try QLinear(w, "\(p).self_attn.v_proj")
        oProj = try QLinear(w, "\(p).self_attn.o_proj")
        qNorm = try ZRMSNorm(w, "\(p).self_attn.q_norm.weight", eps: eps)
        kNorm = try ZRMSNorm(w, "\(p).self_attn.k_norm.weight", eps: eps)
        gateProj = try QLinear(w, "\(p).mlp.gate_proj")
        upProj = try QLinear(w, "\(p).mlp.up_proj")
        downProj = try QLinear(w, "\(p).mlp.down_proj")
    }
}

struct KleinTextEncoder {
    static let hiddenSize = 2560
    static let numLayers = 36
    /// Outputs of these layers (1-based over the layer stack; 0 would be
    /// the embeddings) are concatenated in this order → 3 × 2560.
    static let tapLayers = [9, 18, 27]
    static let numHeads = 32
    static let numKVHeads = 8
    static let headDim = 128
    static let ropeTheta: Float = 1_000_000
    static let eps: Float = 1e-6
    static let maxTokens = 512
    static let padToken: Int32 = 151_643   // <|endoftext|>

    let embedding: QEmbedding
    let layers: [KleinTextEncoderLayer]

    init(_ w: ZWeights) throws {
        embedding = try QEmbedding(w, "embed_tokens")
        layers = try (0 ..< Self.numLayers).map { try KleinTextEncoderLayer(w, layer: $0, eps: Self.eps) }
    }

    /// Prompt token ids (already templated, ≤ maxTokens) → the klein
    /// context [maxTokens, 7680] in the model precision. Returns all 512
    /// positions — the transformer consumes the padded sequence verbatim.
    func encode(_ tokenIds: [Int32]) -> MLXArray {
        let real = min(tokenIds.count, Self.maxTokens)
        let seqLen = Self.maxTokens
        let padded = Array(tokenIds.prefix(real)) + Array(repeating: Self.padToken, count: seqLen - real)
        var h = embedding(MLXArray(padded)).asType(KleinCore.precision)
            .reshaped([1, seqLen, Self.hiddenSize])

        // RoPE tables (fp32, rotate-half, θ=10⁶), positions 0…511.
        let invFreq = 1.0 / pow(Self.ropeTheta,
                                MLXArray(stride(from: 0, to: Self.headDim, by: 2)).asType(.float32) / Float(Self.headDim))
        let freqs = outer(MLXArray(0 ..< seqLen).asType(.float32), invFreq)
        let emb = concatenated([freqs, freqs], axis: -1)
        let cosTable = cos(emb).reshaped([1, seqLen, 1, Self.headDim])
        let sinTable = sin(emb).reshaped([1, seqLen, 1, Self.headDim])

        // Causal + padding mask: key j is visible from query i iff j ≤ i
        // and j is a real token. Pad queries still attend to real keys —
        // exactly the reference's additive mask.
        let idx = MLXArray(0 ..< seqLen)
        let causal = idx.reshaped([seqLen, 1]) .>= idx.reshaped([1, seqLen])
        let realKey = (idx .< Int32(real)).reshaped([1, seqLen])
        let mask = MLX.where(causal .&& realKey, MLXArray(Float(0)), MLXArray(-Float.infinity))
            .reshaped([1, 1, seqLen, seqLen])

        var taps: [MLXArray] = []
        for (i, layer) in layers.enumerated() {
            h = Self.step(layer: layer, h: h, mask: mask,
                          cosTable: cosTable, sinTable: sinTable, seqLen: seqLen)
            eval(h)                                                       // bound the graph (DC-0070)
            if Self.tapLayers.contains(i + 1) { taps.append(h) }
            if i + 1 == Self.tapLayers.max()! { break }   // later layers never matter
        }
        // [1, S, 3, 2560] → [S, 7680], layer-major within each token.
        return concatenated(taps, axis: -1).reshaped([seqLen, Self.tapLayers.count * Self.hiddenSize])
    }

    static func step(layer: KleinTextEncoderLayer, h: MLXArray, mask: MLXArray,
                             cosTable: MLXArray, sinTable: MLXArray, seqLen: Int) -> MLXArray {
        let normed = layer.inputNorm(h)
        var q = layer.qProj(normed).reshaped([1, seqLen, numHeads, headDim])
        var k = layer.kProj(normed).reshaped([1, seqLen, numKVHeads, headDim])
        var v = layer.vProj(normed).reshaped([1, seqLen, numKVHeads, headDim])
        q = rope(layer.qNorm(q), cosTable, sinTable)
        k = rope(layer.kNorm(k), cosTable, sinTable)
        k = repeated(k, count: numHeads / numKVHeads, axis: 2)
        v = repeated(v, count: numHeads / numKVHeads, axis: 2)
        // mflux runs the attention itself in fp32.
        let attn = MLXFast.scaledDotProductAttention(
            queries: q.transposed(0, 2, 1, 3).asType(.float32),
            keys: k.transposed(0, 2, 1, 3).asType(.float32),
            values: v.transposed(0, 2, 1, 3).asType(.float32),
            scale: pow(Float(headDim), -0.5),
            mask: mask
        ).asType(h.dtype).transposed(0, 2, 1, 3).reshaped([1, seqLen, numHeads * headDim])
        var out = h + layer.oProj(attn)
        let mlpIn = layer.postAttentionNorm(out)
        out = out + layer.downProj(zSilu(layer.gateProj(mlpIn)) * layer.upProj(mlpIn))
        return out
    }

    private static func rope(_ x: MLXArray, _ cosTable: MLXArray, _ sinTable: MLXArray) -> MLXArray {
        let half = headDim / 2
        let x1 = x[.ellipsis, ..<half]
        let x2 = x[.ellipsis, half...]
        let rotated = concatenated([-x2, x1], axis: -1)
        return (x * cosTable.asType(x.dtype) + rotated * sinTable.asType(x.dtype))
    }
}
#endif
