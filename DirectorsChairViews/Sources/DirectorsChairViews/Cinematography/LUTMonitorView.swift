// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/LUTMonitorView.swift
//
// Metal-rendered monitor view for displaying LUT-corrected camera frames.
// Receives CIImage from LiveCaptureService.processedFrame and renders via MTKView.

import SwiftUI
import MetalKit
import CoreImage
import AppKit

/// Displays LUT-processed CIImage frames using Metal rendering.
public struct LUTMonitorView: NSViewRepresentable {
    public let processedFrame: CIImage?
    public let ciContext: CIContext

    public init(processedFrame: CIImage?, ciContext: CIContext) {
        self.processedFrame = processedFrame
        self.ciContext = ciContext
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(ciContext: ciContext)
    }

    public func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // Fallback: return an empty MTKView (won't render, but won't crash)
            return MTKView()
        }

        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true // We drive rendering manually
        context.coordinator.mtkView = mtkView
        return mtkView
    }

    public func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.currentFrame = processedFrame
        nsView.setNeedsDisplay(nsView.bounds)
    }

    public class Coordinator: NSObject, MTKViewDelegate {
        let ciContext: CIContext
        var currentFrame: CIImage?
        weak var mtkView: MTKView?
        private var commandQueue: MTLCommandQueue?

        init(ciContext: CIContext) {
            self.ciContext = ciContext
            super.init()
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // No-op; we recalculate on each draw
        }

        public func draw(in view: MTKView) {
            guard let frame = currentFrame,
                  let drawable = view.currentDrawable,
                  let device = view.device else { return }

            if commandQueue == nil {
                commandQueue = device.makeCommandQueue()
            }
            guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }

            let drawableSize = view.drawableSize
            let destination = CIRenderDestination(
                width: Int(drawableSize.width),
                height: Int(drawableSize.height),
                pixelFormat: view.colorPixelFormat,
                commandBuffer: commandBuffer
            ) {
                return drawable.texture
            }

            // Scale frame to fit drawable while maintaining aspect ratio (resizeAspect)
            let frameExtent = frame.extent
            guard frameExtent.width > 0, frameExtent.height > 0 else { return }

            let scaleX = drawableSize.width / frameExtent.width
            let scaleY = drawableSize.height / frameExtent.height
            let scale = min(scaleX, scaleY)

            let scaledWidth = frameExtent.width * scale
            let scaledHeight = frameExtent.height * scale
            let offsetX = (drawableSize.width - scaledWidth) / 2
            let offsetY = (drawableSize.height - scaledHeight) / 2

            let scaledImage = frame
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))

            do {
                try ciContext.startTask(toRender: scaledImage, to: destination)
                commandBuffer.present(drawable)
                commandBuffer.commit()
            } catch {
                // Silently skip frame on render failure
            }
        }
    }
}
