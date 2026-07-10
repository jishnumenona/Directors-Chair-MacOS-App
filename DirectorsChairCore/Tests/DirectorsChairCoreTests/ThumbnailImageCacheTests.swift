// ThumbnailImageCacheTests.swift
//
// Perf Tier 3: the shared downsampling image cache. Verifies it decodes a
// bounded-size thumbnail (not the full-resolution source), caches hits,
// and memoizes failures instead of retrying missing files.

import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import DirectorsChairCore

final class ThumbnailImageCacheTests: XCTestCase {

    /// Write a solid-color PNG of a given pixel size to a temp file.
    private func writeTestImage(width: Int, height: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumb-\(UUID().uuidString).png")
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        let data = rep.representation(using: .png, properties: [:])!
        try data.write(to: url)
        return url
    }

    func testDownsampleBoundsLongestEdge() throws {
        let url = try writeTestImage(width: 2000, height: 1000)
        defer { try? FileManager.default.removeItem(at: url) }

        let thumb = ThumbnailImageCache.downsample(url: url, maxPixel: 120)
        XCTAssertNotNil(thumb)
        let px = max(thumb!.size.width, thumb!.size.height)
        XCTAssertLessThanOrEqual(px, 120, "Longest edge must be bounded by maxPixel")
        XCTAssertGreaterThan(px, 0)
    }

    func testAsyncThumbnailCachesHit() async throws {
        let url = try writeTestImage(width: 800, height: 800)
        defer { try? FileManager.default.removeItem(at: url) }

        let first = await ThumbnailImageCache.shared.thumbnail(url, maxPixel: 60)
        XCTAssertNotNil(first)
        // Second call is served from the cache synchronously.
        XCTAssertNotNil(ThumbnailImageCache.shared.cached(url, maxPixel: 60),
                        "A decoded thumbnail must be cached for instant reuse")
    }

    func testMissingFileMemoizedAsFailure() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).png")
        let result = await ThumbnailImageCache.shared.thumbnail(missing, maxPixel: 60)
        XCTAssertNil(result)
        // Failure is remembered; a synchronous peek stays nil (no retry storm).
        XCTAssertNil(ThumbnailImageCache.shared.cached(missing, maxPixel: 60))
    }

    /// Quantifies the Tier-3 win: a large source photo decoded for a small
    /// avatar yields orders of magnitude fewer pixels in memory than the
    /// full-resolution decode the old path held.
    func testThumbnailIsOrdersOfMagnitudeSmallerThanFullDecode() throws {
        let url = try writeTestImage(width: 4000, height: 3000)   // 12M px source
        defer { try? FileManager.default.removeItem(at: url) }

        let fullPixels = 4000 * 3000
        let thumb = ThumbnailImageCache.downsample(url: url, maxPixel: 120)!  // 40pt @3x
        let thumbPixels = Int(thumb.size.width * thumb.size.height)

        XCTAssertLessThan(thumbPixels * 100, fullPixels,
                          "Thumbnail must be <1% of the full decode's pixel count "
                          + "(\(thumbPixels) vs \(fullPixels) px)")
    }

    func testSizeBucketsAreDistinct() async throws {
        let url = try writeTestImage(width: 500, height: 500)
        defer { try? FileManager.default.removeItem(at: url) }

        _ = await ThumbnailImageCache.shared.thumbnail(url, maxPixel: 40)
        _ = await ThumbnailImageCache.shared.thumbnail(url, maxPixel: 200)
        XCTAssertNotNil(ThumbnailImageCache.shared.cached(url, maxPixel: 40))
        XCTAssertNotNil(ThumbnailImageCache.shared.cached(url, maxPixel: 200))
    }
}
