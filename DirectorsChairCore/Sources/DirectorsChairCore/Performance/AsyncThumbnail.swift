//
//  AsyncThumbnail.swift
//  DirectorsChairCore
//
//  Drop-in SwiftUI view for list-row / grid / canvas thumbnails. Loads a
//  downsampled image via ThumbnailImageCache OFF the main thread, showing a
//  placeholder until it lands — replacing the synchronous full-resolution
//  NSImage(contentsOf:) decodes that stalled scrolling (UI audit D1).
//
//  Usage:
//    AsyncThumbnail(url: photoURL, displaySize: 40, contentMode: .fill) {
//        InitialsAvatar(name: actorName, size: 40)
//    }
//    .frame(width: 40, height: 40)
//    .clipShape(Circle())
//

import SwiftUI
import AppKit

public struct AsyncThumbnail<Placeholder: View>: View {

    private let url: URL?
    private let maxPixel: Int
    private let contentMode: ContentMode
    private let placeholder: Placeholder

    @State private var image: NSImage?

    /// - Parameters:
    ///   - url: file URL of the source image (nil → always placeholder).
    ///   - displaySize: the point size the thumbnail renders at; the decode
    ///     target is 3× for retina crispness.
    ///   - contentMode: fill (default, for avatars/cards) or fit.
    public init(url: URL?,
                displaySize: CGFloat,
                contentMode: ContentMode = .fill,
                @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.maxPixel = max(1, Int(displaySize * 3))
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    public var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .task(id: taskKey) { await load() }
    }

    /// Re-run the loader when the url or size bucket changes.
    private var taskKey: String { "\(url?.path ?? "")|\(maxPixel)" }

    private func load() async {
        guard let url else { image = nil; return }
        // Instant path: already-decoded thumbnail.
        if let hit = ThumbnailImageCache.shared.cached(url, maxPixel: maxPixel) {
            image = hit
            return
        }
        let loaded = await ThumbnailImageCache.shared.thumbnail(url, maxPixel: maxPixel)
        // Guard against reuse: only apply if still the current request.
        if !Task.isCancelled { image = loaded }
    }
}
