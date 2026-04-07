// DirectorsChairViews/Sources/DirectorsChairViews/Cinematography/LiveMonitorView.swift
//
// NSViewRepresentable wrapping AVCaptureVideoPreviewLayer for live HDMI capture preview

import SwiftUI
import AVFoundation
import AppKit

/// Displays a live preview from an AVCaptureVideoPreviewLayer
public struct LiveMonitorView: NSViewRepresentable {
    public let previewLayer: AVCaptureVideoPreviewLayer

    public init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
    }

    public func makeNSView(context: Context) -> LiveMonitorNSView {
        let view = LiveMonitorNSView()
        view.wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
        previewLayer.frame = view.bounds
        view.layer?.addSublayer(previewLayer)
        return view
    }

    public func updateNSView(_ nsView: LiveMonitorNSView, context: Context) {
        // Re-attach the preview layer if SwiftUI recreated the view
        if previewLayer.superlayer !== nsView.layer {
            previewLayer.removeFromSuperlayer()
            nsView.layer?.addSublayer(previewLayer)
        }
        previewLayer.frame = nsView.bounds
    }
}

/// NSView subclass that auto-sizes the preview layer
public class LiveMonitorNSView: NSView {
    override public var wantsUpdateLayer: Bool { true }

    override public func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = NSColor.black.cgColor
        return layer
    }

    override public func layout() {
        super.layout()
        if let sublayers = layer?.sublayers {
            for sublayer in sublayers {
                sublayer.frame = bounds
            }
        }
    }
}
