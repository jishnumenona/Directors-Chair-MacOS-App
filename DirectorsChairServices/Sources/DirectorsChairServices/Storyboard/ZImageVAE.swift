// DirectorsChairServices/Storyboard/ZImageVAE.swift
//
// The VAE decoder of the Z-Image core (DC-0065), ported from mflux
// (MIT). FLUX-family 16-channel latent space: scale 0.3611, shift
// 0.1159, 8× spatial. Runs NHWC end-to-end (mflux transposes around
// every block; the math is identical). Two fp32 islands are faithful to
// the source: the mid-block attention's group norm and the final
// conv_norm_out — resnet norms stay in model precision.

#if arch(arm64)
import Foundation
import MLX
import MLXFast

struct ZVAEResnet {
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
        var h = conv1(zSilu(norm1(x)))
        h = conv2(zSilu(norm2(h)))
        let skip = shortcut.map { $0(x) } ?? x
        return skip + h
    }
}

struct ZVAEAttention {
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
        toOut = try QLinear(w, "\(p).to_out.0")
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let (b, h, w, c) = (x.dim(0), x.dim(1), x.dim(2), x.dim(3))
        let normed = groupNorm(x.asType(.float32)).asType(ZImageCore.precision)
        let q = toQ(normed).reshaped([b, h * w, 1, c]).transposed(0, 2, 1, 3)
        let k = toK(normed).reshaped([b, h * w, 1, c]).transposed(0, 2, 1, 3)
        let v = toV(normed).reshaped([b, h * w, 1, c]).transposed(0, 2, 1, 3)
        let attn = MLXFast.scaledDotProductAttention(
            queries: q, keys: k, values: v,
            scale: pow(Float(c), -0.5), mask: nil
        ).transposed(0, 2, 1, 3).reshaped([b, h, w, c])
        return x + toOut(attn)
    }
}

struct ZVAEDecoder {
    static let scalingFactor: Float = 0.3611
    static let shiftFactor: Float = 0.1159

    let convIn: ZConv2d
    let midResnet1: ZVAEResnet
    let midAttention: ZVAEAttention
    let midResnet2: ZVAEResnet
    /// (resnets, upsampler?) per up block.
    let upBlocks: [(resnets: [ZVAEResnet], upsampler: ZConv2d?)]
    let normOut: ZGroupNorm
    let convOut: ZConv2d

    init(_ w: ZWeights) throws {
        convIn = try ZConv2d(w, "decoder.conv_in.conv", padding: 1)
        midResnet1 = try ZVAEResnet(w, "decoder.mid_block.resnets.0", hasShortcut: false)
        midAttention = try ZVAEAttention(w, "decoder.mid_block.attentions.0")
        midResnet2 = try ZVAEResnet(w, "decoder.mid_block.resnets.1", hasShortcut: false)
        // Channel plan 512→512→512→256→128; the first resnet of a
        // channel-changing block carries the 1×1 shortcut.
        let shrinks = [false, false, true, true]
        let upsamples = [true, true, true, false]
        var blocks: [(resnets: [ZVAEResnet], upsampler: ZConv2d?)] = []
        for i in 0 ..< 4 {
            let resnets = try (0 ..< 3).map { j in
                try ZVAEResnet(w, "decoder.up_blocks.\(i).resnets.\(j)",
                               hasShortcut: shrinks[i] && j == 0)
            }
            let upsampler = upsamples[i]
                ? try ZConv2d(w, "decoder.up_blocks.\(i).upsamplers.0.conv", padding: 1)
                : nil
            blocks.append((resnets, upsampler))
        }
        upBlocks = blocks
        normOut = try ZGroupNorm(w, "decoder.conv_norm_out.norm")
        convOut = try ZConv2d(w, "decoder.conv_out.conv", padding: 1)
    }

    /// [1, H8, W8, 16] scaled latents (NHWC) → RGB in [-1, 1], [1, H, W, 3].
    func callAsFunction(_ latentsNHWC: MLXArray) -> MLXArray {
        var h = convIn(latentsNHWC)
        h = midResnet1(h)
        h = midAttention(h)
        h = midResnet2(h)
        for block in upBlocks {
            for resnet in block.resnets { h = resnet(h) }
            if let upsampler = block.upsampler {
                h = upsampler(Self.upsampleNearest2x(h))
            }
        }
        h = normOut(h.asType(.float32)).asType(ZImageCore.precision)
        return convOut(zSilu(h))
    }

    static func upsampleNearest2x(_ x: MLXArray) -> MLXArray {
        let (b, h, w, c) = (x.dim(0), x.dim(1), x.dim(2), x.dim(3))
        return broadcast(x.reshaped([b, h, 1, w, 1, c]), to: [b, h, 2, w, 2, c])
            .reshaped([b, h * 2, w * 2, c])
    }
}
#endif
