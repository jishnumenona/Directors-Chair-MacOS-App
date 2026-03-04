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
        view.layer?.addSublayer(previewLayer)
        return view
    }

    public func updateNSView(_ nsView: LiveMonitorNSView, context: Context) {
        previewLayer.frame = nsView.bounds
    }
}

/// NSView subclass that auto-sizes the preview layer
public class LiveMonitorNSView: NSView {
    override public func layout() {
        super.layout()
        if let sublayer = layer?.sublayers?.first {
            sublayer.frame = bounds
        }
    }
}
