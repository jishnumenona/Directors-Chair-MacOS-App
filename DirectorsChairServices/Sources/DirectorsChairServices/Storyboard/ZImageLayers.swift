// DirectorsChairServices/Storyboard/ZImageLayers.swift
//
// Primitive layers for the native Z-Image core (DC-0065), ported from
// mflux (MIT) — the exact implementation that produced the reference
// frames. Deliberately written as plain structs over MLXArrays, not
// nn.Module machinery: every weight is loaded by its verbatim key from
// the mflux-saved safetensors, so there is no reflection layer to
// mismatch. Faithfulness rule: no dtype casts that aren't in the mflux
// source — parity against the reference frames is the correctness bar.

#if arch(arm64)
import Foundation
import MLX
import MLXFast

// MARK: - Weight store

/// All tensors of one model component (transformer / text_encoder / vae),
/// merged across its numbered safetensors shards, keyed verbatim.
struct ZWeights {
    let tensors: [String: MLXArray]

    init(componentDirectory: URL) throws {
        var merged: [String: MLXArray] = [:]
        let files = try FileManager.default
            .contentsOfDirectory(at: componentDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "safetensors" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !files.isEmpty else {
            throw StoryboardEngineError.generationFailed(
                "No weight shards found in \(componentDirectory.lastPathComponent) — re-download the Storyboard model.")
        }
        for file in files {
            for (key, value) in try MLX.loadArrays(url: file) {
                merged[key] = value
            }
        }
        self.tensors = merged
    }

    func tensor(_ key: String) throws -> MLXArray {
        guard let value = tensors[key] else {
            throw StoryboardEngineError.generationFailed(
                "Model weight '\(key)' is missing — the download may be damaged; re-download the Storyboard model.")
        }
        return value
    }

    func optional(_ key: String) -> MLXArray? { tensors[key] }
}

// MARK: - Quantized linear

/// A 4-bit group-64 quantized Linear as mflux saves it: packed uint32
/// `weight` + bf16 `scales`/`biases` (quantization zero-points), plus an
/// optional additive `bias` for layers built with bias=True.
struct QLinear {
    let weight: MLXArray
    let scales: MLXArray
    let biases: MLXArray
    let bias: MLXArray?

    static let groupSize = 64
    static let bits = 4

    init(_ weights: ZWeights, _ prefix: String) throws {
        self.weight = try weights.tensor("\(prefix).weight")
        self.scales = try weights.tensor("\(prefix).scales")
        self.biases = try weights.tensor("\(prefix).biases")
        self.bias = weights.optional("\(prefix).bias")
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        var y = quantizedMatmul(
            x, weight, scales: scales, biases: biases,
            transpose: true, groupSize: Self.groupSize, bits: Self.bits)
        if let bias { y = y + bias }
        return y
    }
}

/// A quantized embedding table — rows are gathered packed, then
/// dequantized, so the full 151k×2560 table never materializes.
struct QEmbedding {
    let weight: MLXArray
    let scales: MLXArray
    let biases: MLXArray

    init(_ weights: ZWeights, _ prefix: String) throws {
        self.weight = try weights.tensor("\(prefix).weight")
        self.scales = try weights.tensor("\(prefix).scales")
        self.biases = try weights.tensor("\(prefix).biases")
    }

    func callAsFunction(_ ids: MLXArray) -> MLXArray {
        dequantized(
            take(weight, ids, axis: 0),
            scales: take(scales, ids, axis: 0),
            biases: take(biases, ids, axis: 0),
            groupSize: QLinear.groupSize, bits: QLinear.bits)
    }
}

// MARK: - Norms

struct ZRMSNorm {
    let weight: MLXArray
    let eps: Float

    init(_ weights: ZWeights, _ key: String, eps: Float) throws {
        self.weight = try weights.tensor(key)
        self.eps = eps
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        MLXFast.rmsNorm(x, weight: weight, eps: eps)
    }
}

/// PyTorch-compatible GroupNorm over NHWC input (32 groups), matching
/// mlx.nn.GroupNorm(pytorch_compatible: true): statistics span the
/// spatial extent AND the channels of each group.
struct ZGroupNorm {
    let weight: MLXArray
    let bias: MLXArray
    let groups: Int
    let eps: Float

    init(_ weights: ZWeights, _ prefix: String, groups: Int = 32, eps: Float = 1e-6) throws {
        self.weight = try weights.tensor("\(prefix).weight")
        self.bias = try weights.tensor("\(prefix).bias")
        self.groups = groups
        self.eps = eps
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // Mirror mlx.nn.GroupNorm._pytorch_compatible_group_norm exactly:
        // fold each group's (spatial × channels) extent into one axis and
        // normalize it through the fast layer-norm kernel — which
        // accumulates in fp32. Hand-rolled bf16 mean/variance over ~10⁵
        // elements loses enough precision to tint whole frames (found by
        // the seed-42 parity check).
        let (b, h, w, c) = (x.dim(0), x.dim(1), x.dim(2), x.dim(3))
        let groupSize = c / groups
        var g = x.reshaped([b, h * w, groups, groupSize])
            .transposed(0, 2, 1, 3)
            .reshaped([b, groups, h * w * groupSize])
        g = MLXFast.layerNorm(g, weight: nil, bias: nil, eps: eps)
        let out = g.reshaped([b, groups, h * w, groupSize])
            .transposed(0, 2, 1, 3)
            .reshaped([b, h, w, c])
        return weight * out + bias
    }
}

// MARK: - Conv

/// 3×3/1×1 convolution over NHWC input; mflux/MLX weight layout is
/// [outC, kH, kW, inC] exactly as stored.
struct ZConv2d {
    let weight: MLXArray
    let bias: MLXArray
    let padding: Int

    init(_ weights: ZWeights, _ prefix: String, padding: Int) throws {
        self.weight = try weights.tensor("\(prefix).weight")
        self.bias = try weights.tensor("\(prefix).bias")
        self.padding = padding
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        conv2d(x, weight, stride: .init(1), padding: .init(padding)) + bias
    }
}

// MARK: - Small math helpers

@inline(__always) func zSilu(_ x: MLXArray) -> MLXArray { x * sigmoid(x) }

/// Sinusoidal timestep features (dim 256, max period 10⁴) — fp32, as in
/// mflux TimestepEmbedder._timestep_embedding.
func zTimestepFeatures(_ t: MLXArray, dim: Int = 256) -> MLXArray {
    let half = dim / 2
    let freqs = exp(-log(Float(10_000)) * MLXArray(0 ..< half).asType(.float32) / Float(half))
    let args = t.reshaped([t.dim(0), 1]).asType(.float32) * freqs.reshaped([1, half])
    return concatenated([cos(args), sin(args)], axis: -1)
}
#endif
