// DirectorsChairServices/Storyboard/KleinVAE.swift
//
// The FLUX.2 VAE of the klein core (DC-0068), ported from mflux (MIT):
// a 32-channel latent space, 8× spatial, with BOTH directions — the
// encoder is what turns a reference picture into tokens the transformer
// can look at. Runs NHWC end-to-end (mflux transposes around every
// block; the math is identical). Every GroupNorm computes in fp32, as in
// the source. The transformer never sees raw latents: it sees 2×2
// patches (128 channels) normalised by the checkpoint's BatchNorm
// statistics — that packing lives here so encode and decode cannot drift
// apart.

#if arch(arm64)
import Foundation
import MLX
import MLXFast

struct KleinVAEResnet {
    let norm1: ZGroupNorm
    let conv1: ZConv2d
    let norm2: ZGroupNorm
    let conv2: ZConv2d
    let shortcut: ZConv2d?

    init(_ w: ZWeights, _ p: String, hasShortcut: Bool) throws {
        norm1 = try ZGroupNorm(w, "\(p).norm1")
        conv1 = try ZConv2d(w, "\(p).conv1", padding: 1)
        norm2 = try ZGroupNorm(w, "\(p).norm2")
        conv2 = try ZConv2d(w, "\(p).conv2", padding: 1)
        shortcut = hasShortcut ? try ZConv2d(w, "\(p).conv_shortcut", padding: 0) : nil
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        // Norm statistics accumulate in fp32 inside the fast kernel; the
        // tensors stay bf16 — half the working set of casting a 1024²
        // activation to fp32 (DC-0070), parity-checked against mflux.
        var h = conv1(zSilu(norm1(x)))
        h = conv2(zSilu(norm2(h)))
        let skip = shortcut.map { $0(x) } ?? x
        return skip + h
    }
}

struct KleinVAEAttention {
    let groupNorm: ZGroupNorm
    let toQ: QLinear
    let toK: QLinear
    let toV: QLinear
    let toOut: QLinear

    init(_ w: ZWeights, _ p: String) throws {
        groupNorm = try ZGroupNorm(w, "\(p).group_norm")
        toQ = try QLinear(w, "\(p).to_q")
        toK = try QLinear(w, "\(p).to_k")
        toV = try QLinear(w, "\(p).to_v")
        toOut = try QLinear(w, "\(p).to_out")
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let (b, h, w, c) = (x.dim(0), x.dim(1), x.dim(2), x.dim(3))
        let normed = groupNorm(x)
        let q = toQ(normed).reshaped([b, h * w, 1, c]).transposed(0, 2, 1, 3)
        let k = toK(normed).reshaped([b, h * w, 1, c]).transposed(0, 2, 1, 3)
        let v = toV(normed).reshaped([b, h * w, 1, c]).transposed(0, 2, 1, 3)
        let attn = MLXFast.scaledDotProductAttention(
            queries: q, keys: k, values: v, scale: pow(Float(c), -0.5), mask: nil
        ).transposed(0, 2, 1, 3).reshaped([b, h, w, c])
        return x + toOut(attn)
    }
}

struct KleinVAEMidBlock {
    let resnet0: KleinVAEResnet
    let attention: KleinVAEAttention
    let resnet1: KleinVAEResnet

    init(_ w: ZWeights, _ p: String) throws {
        resnet0 = try KleinVAEResnet(w, "\(p).resnets.0", hasShortcut: false)
        attention = try KleinVAEAttention(w, "\(p).attentions.0")
        resnet1 = try KleinVAEResnet(w, "\(p).resnets.1", hasShortcut: false)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray { resnet1(attention(resnet0(x))) }
}

struct KleinVAE {
    static let latentChannels = 32
    static let packedChannels = 128        // 32 × (2×2 patch)
    static let bnEps: Float = 1e-4
    static let channelPlan = [128, 256, 512, 512]

    // Encoder
    let encConvIn: ZConv2d
    let downBlocks: [(resnets: [KleinVAEResnet], downsampler: ZConv2d?)]
    let encMid: KleinVAEMidBlock
    let encNormOut: ZGroupNorm
    let encConvOut: ZConv2d
    let quantConv: ZConv2d
    // Decoder
    let postQuantConv: ZConv2d
    let decConvIn: ZConv2d
    let decMid: KleinVAEMidBlock
    let upBlocks: [(resnets: [KleinVAEResnet], upsampler: ZConv2d?)]
    let decNormOut: ZGroupNorm
    let decConvOut: ZConv2d
    // Patch-space statistics (fp32).
    let bnMean: MLXArray
    let bnStd: MLXArray

    init(_ w: ZWeights) throws {
        let plan = Self.channelPlan
        encConvIn = try ZConv2d(w, "encoder.conv_in", padding: 1)
        var downs: [(resnets: [KleinVAEResnet], downsampler: ZConv2d?)] = []
        for i in 0 ..< plan.count {
            let inChannels = i == 0 ? plan[0] : plan[i - 1]
            let resnets = try (0 ..< 2).map { j in
                try KleinVAEResnet(w, "encoder.down_blocks.\(i).resnets.\(j)",
                                   hasShortcut: j == 0 && inChannels != plan[i])
            }
            let down = i < plan.count - 1
                ? try ZConv2d(w, "encoder.down_blocks.\(i).downsamplers.0.conv", padding: 0, stride: 2)
                : nil
            downs.append((resnets, down))
        }
        downBlocks = downs
        encMid = try KleinVAEMidBlock(w, "encoder.mid_block")
        encNormOut = try ZGroupNorm(w, "encoder.conv_norm_out")
        encConvOut = try ZConv2d(w, "encoder.conv_out", padding: 1)
        quantConv = try ZConv2d(w, "quant_conv", padding: 0)

        postQuantConv = try ZConv2d(w, "post_quant_conv", padding: 0)
        decConvIn = try ZConv2d(w, "decoder.conv_in", padding: 1)
        decMid = try KleinVAEMidBlock(w, "decoder.mid_block")
        let reversed = Array(plan.reversed())
        var ups: [(resnets: [KleinVAEResnet], upsampler: ZConv2d?)] = []
        for i in 0 ..< reversed.count {
            let inChannels = i == 0 ? reversed[0] : reversed[i - 1]
            let resnets = try (0 ..< 3).map { j in
                try KleinVAEResnet(w, "decoder.up_blocks.\(i).resnets.\(j)",
                                   hasShortcut: j == 0 && inChannels != reversed[i])
            }
            let up = i < reversed.count - 1
                ? try ZConv2d(w, "decoder.up_blocks.\(i).upsamplers.0.conv", padding: 1)
                : nil
            ups.append((resnets, up))
        }
        upBlocks = ups
        decNormOut = try ZGroupNorm(w, "decoder.conv_norm_out")
        decConvOut = try ZConv2d(w, "decoder.conv_out", padding: 1)

        bnMean = try w.tensor("bn.running_mean").asType(.float32)
        bnStd = sqrt(try w.tensor("bn.running_var").asType(.float32) + Self.bnEps)
    }

    // MARK: - Encode

    /// [1, H, W, 3] in [-1, 1] → latent mean [1, H/8, W/8, 32].
    func encode(_ image: MLXArray) -> MLXArray {
        var h = encConvIn(image)
        for block in downBlocks {
            // Evaluate per block: a lazy graph over a 1024² picture holds
            // every fp32 activation at once (DC-0070 — the VAE was the peak).
            for resnet in block.resnets { h = resnet(h); eval(h) }
            if let down = block.downsampler {
                // Asymmetric (0,1) padding then a stride-2 conv, as in the source.
                h = down(padded(h, widths: [.init((0, 0)), .init((0, 1)), .init((0, 1)), .init((0, 0))]))
                eval(h)
            }
        }
        h = encMid(h)
        eval(h)
        h = encNormOut(h)
        h = encConvOut(zSilu(h))
        h = quantConv(h)
        return h[.ellipsis, ..<Self.latentChannels]      // mean half; scale 1, shift 0
    }

    /// A reference picture → transformer tokens [1, (H/16)·(W/16), 128]
    /// plus its latent grid, exactly the reference conditioning mflux
    /// builds: encode, crop to an even latent grid, 2×2 patchify,
    /// BatchNorm-normalise, pack row-major.
    func encodeReference(_ image: MLXArray) -> (tokens: MLXArray, height: Int, width: Int) {
        var latent = encode(image)
        let evenH = latent.dim(1) - latent.dim(1) % 2
        let evenW = latent.dim(2) - latent.dim(2) % 2
        latent = latent[0..., ..<evenH, ..<evenW, 0...]
        let packed = Self.patchify(latent)                        // [1, h, w, 128]
        let normalised = (packed.asType(.float32) - bnMean) / bnStd
        let (h, w) = (packed.dim(1), packed.dim(2))
        return (normalised.asType(KleinCore.precision).reshaped([1, h * w, Self.packedChannels]), h, w)
    }

    // MARK: - Decode

    /// Transformer tokens [1, h·w, 128] → RGB [1, 2h·8, 2w·8, 3] in [-1, 1].
    func decodePacked(_ tokens: MLXArray, height h: Int, width w: Int) -> MLXArray {
        let denorm = tokens.asType(.float32) * bnStd + bnMean
        let latent = Self.unpatchify(denorm.reshaped([1, h, w, Self.packedChannels]))
            .asType(KleinCore.precision)                          // [1, 2h, 2w, 32]
        var x = postQuantConv(latent)
        x = decConvIn(x)
        x = decMid(x)
        for block in upBlocks {
            for resnet in block.resnets { x = resnet(x); eval(x) }     // bound the graph (DC-0070)
            if let up = block.upsampler { x = up(Self.upsampleNearest2x(x)); eval(x) }
        }
        x = decNormOut(x)
        return decConvOut(zSilu(x))
    }

    // MARK: - Patch space

    /// [B, H, W, C] → [B, H/2, W/2, C·4] with channel index c·4 + i·2 + j
    /// (i = row within the patch, j = column) — mflux's patchify order.
    static func patchify(_ x: MLXArray) -> MLXArray {
        let (b, h, w, c) = (x.dim(0), x.dim(1), x.dim(2), x.dim(3))
        return x.reshaped([b, h / 2, 2, w / 2, 2, c])
            .transposed(0, 1, 3, 5, 2, 4)
            .reshaped([b, h / 2, w / 2, c * 4])
    }

    static func unpatchify(_ x: MLXArray) -> MLXArray {
        let (b, h, w, c4) = (x.dim(0), x.dim(1), x.dim(2), x.dim(3))
        return x.reshaped([b, h, w, c4 / 4, 2, 2])
            .transposed(0, 1, 4, 2, 5, 3)
            .reshaped([b, h * 2, w * 2, c4 / 4])
    }

    static func upsampleNearest2x(_ x: MLXArray) -> MLXArray {
        let (b, h, w, c) = (x.dim(0), x.dim(1), x.dim(2), x.dim(3))
        return broadcast(x.reshaped([b, h, 1, w, 1, c]), to: [b, h, 2, w, 2, c])
            .reshaped([b, h * 2, w * 2, c])
    }
}
#endif
