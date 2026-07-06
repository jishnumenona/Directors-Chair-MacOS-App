// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/CanvasImageCache.swift
//
// WS9.2 — no synchronous disk I/O inside Canvas draw closures.
//
// A draw-path lookup either returns an already-loaded image or kicks off a
// background load and returns nil (the caller draws a placeholder). When the
// load lands, `onImageLoaded` fires on the main queue so the view can bump a
// version counter and redraw with the image.

import AppKit

@MainActor
final class CanvasImageCache {
    private var images: [String: NSImage] = [:]
    private var inFlight: Set<String> = []
    private var failed: Set<String> = []

    /// Called on the main queue after a background load completes.
    var onImageLoaded: (() -> Void)?

    /// Draw-path lookup: cached image, or nil while a background load runs.
    func image(forRelativePath path: String, base: URL) -> NSImage? {
        if let img = images[path] { return img }
        guard !inFlight.contains(path), !failed.contains(path) else { return nil }
        inFlight.insert(path)

        let fullPath = base.appendingPathComponent(path)
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = NSImage(contentsOf: fullPath)
            DispatchQueue.main.async {
                self.inFlight.remove(path)
                if let loaded {
                    self.images[path] = loaded
                    self.onImageLoaded?()
                } else {
                    // Remember the failure so a missing file doesn't retrigger
                    // a load on every redraw (retry storm).
                    self.failed.insert(path)
                }
            }
        }
        return nil
    }
}
