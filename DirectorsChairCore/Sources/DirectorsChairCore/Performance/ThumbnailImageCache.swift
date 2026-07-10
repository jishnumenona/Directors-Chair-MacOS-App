//
//  ThumbnailImageCache.swift
//  DirectorsChairCore
//
//  Perf Tier 3 (UI audit D1/C3/C5): one shared, downsampling, async image
//  cache. The prior pattern loaded FULL-RESOLUTION NSImages synchronously in
//  list-row/canvas bodies on the main thread — a 4000px source photo decoded
//  and held in memory to draw a 40pt avatar, re-decoded on every scroll.
//
//  This cache:
//   - decodes a THUMBNAIL at the display pixel size via ImageIO
//     (CGImageSourceCreateThumbnailAtIndex) — a fraction of the memory and
//     GPU cost, never the full bitmap;
//   - runs the decode OFF the main thread;
//   - caches by (path, pixel-size bucket) in an NSCache (auto-evicting);
//   - memoizes failures so a missing file can't trigger a retry storm.
//
//  Used via the AsyncThumbnail SwiftUI view.
//

import Foundation
import ImageIO
import AppKit

public final class ThumbnailImageCache: @unchecked Sendable {

    public static let shared = ThumbnailImageCache()

    private let cache = NSCache<NSString, NSImage>()
    private let lock = NSLock()
    private var failed = Set<String>()

    private init() {
        cache.countLimit = 300
    }

    private func key(_ url: URL, _ maxPixel: Int) -> NSString {
        "\(url.path)|\(maxPixel)" as NSString
    }

    /// Synchronous cache peek — returns an already-decoded thumbnail or nil.
    /// Safe to call from a view body (no I/O).
    public func cached(_ url: URL, maxPixel: Int) -> NSImage? {
        cache.object(forKey: key(url, maxPixel))
    }

    private func isFailed(_ key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return failed.contains(key)
    }

    private func markFailed(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        failed.insert(key)
    }

    private func store(_ image: NSImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    /// Load + downsample off the main thread. Returns nil for a missing or
    /// undecodable file (and remembers the failure).
    public func thumbnail(_ url: URL, maxPixel: Int) async -> NSImage? {
        if let hit = cache.object(forKey: key(url, maxPixel)) { return hit }
        let failKey = "\(url.path)|\(maxPixel)"
        if isFailed(failKey) { return nil }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { continuation.resume(returning: nil); return }
                let img = Self.downsample(url: url, maxPixel: maxPixel)
                if let img {
                    self.store(img, forKey: failKey)
                } else {
                    self.markFailed(failKey)
                }
                continuation.resume(returning: img)
            }
        }
    }

    /// Decode a thumbnail no larger than `maxPixel` on its longest edge.
    /// Pure and synchronous — the async wrapper runs it off-main.
    public static func downsample(url: URL, maxPixel: Int) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // honor EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,          // decode now, off-main
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel)
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}
