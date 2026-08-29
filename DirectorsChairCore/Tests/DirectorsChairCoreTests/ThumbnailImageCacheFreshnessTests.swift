//
//  ThumbnailImageCacheFreshnessTests.swift
//  DirectorsChairCoreTests
//
//  Audit 2026-08-28: the cache was keyed by path alone and remembered a
//  miss forever, so a regenerated shot preview kept its old picture and a
//  card rendered before its image existed stayed on the placeholder.
//

import XCTest
import AppKit
@testable import DirectorsChairCore

final class ThumbnailImageCacheFreshnessTests: XCTestCase {

    private func png(side: Int, gray: CGFloat) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(white: gray, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    func testARegeneratedImageReplacesTheCachedThumbnail() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("thumb-fresh-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("latest.png")
        try png(side: 64, gray: 0.2).write(to: url)
        let firstLoad = await ThumbnailImageCache.shared.thumbnail(url, maxPixel: 128)
        let first = try XCTUnwrap(firstLoad)
        XCTAssertEqual(Int(first.size.width), 64)

        try await Task.sleep(nanoseconds: 1_100_000_000)   // a new write time
        try png(side: 96, gray: 0.8).write(to: url)          // regenerated at the same path
        let secondLoad = await ThumbnailImageCache.shared.thumbnail(url, maxPixel: 128)
        let second = try XCTUnwrap(secondLoad)
        XCTAssertEqual(Int(second.size.width), 96, "the regenerated picture, not the stale one")
        XCTAssertEqual(Int(ThumbnailImageCache.shared.cached(url, maxPixel: 128)?.size.width ?? 0), 96)
    }

    func testAPictureThatAppearsAfterAMissIsPickedUp() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("thumb-miss-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("not-yet.png")
        let miss = await ThumbnailImageCache.shared.thumbnail(url, maxPixel: 64)
        XCTAssertNil(miss)
        try png(side: 32, gray: 0.5).write(to: url)
        let hit = await ThumbnailImageCache.shared.thumbnail(url, maxPixel: 64)
        XCTAssertNotNil(hit, "a remembered miss must not outlive the file's absence")
    }
}
