// DirectorsChairViews/Sources/DirectorsChairViews/VisionBoard/VisionBoardAbsorb.swift
//
// The Wall, pass 1 — "the board absorbs; it never asks."
//
// Everything that can land on the wall arrives as an AbsorbPayload: a file
// dragged from Finder, an image dragged out of a browser, a screenshot on
// the clipboard, a line of text. Classification is pure and testable here;
// the view model turns payloads into scraps (VisionBoardViewModel.absorb)
// and the canvas supplies the drop point.
//
// Capture asks nothing: no type picker, no title, no department. A scrap
// carries only what the payload itself gave us.

import Foundation
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

/// One thing on its way onto the wall.
public enum AbsorbPayload: Equatable, Sendable {
    /// A file on disk — imported into the project by the asset pipeline.
    case fileURL(URL)
    /// Raw image bytes (clipboard screenshots, drags that carry pixels).
    case imageData(Data)
    /// A remote image, downloaded at commit time.
    case remoteURL(URL)
    /// A word, a phrase, a stray thought.
    case text(String)
}

public enum VisionBoardAbsorb {

    /// Drops and pastes we accept. Order matters: the richest
    /// representation an item can offer wins.
    public static var acceptedTypes: [UTType] {
        [.fileURL, .image, .url, .utf8PlainText, .plainText]
    }

    // MARK: - Classification

    /// A dropped/pasted string is a picture if it points at one; otherwise
    /// it is a word for the wall. Bare `example.com/x.jpg` counts — people
    /// copy URLs without their scheme all the time.
    public static func classify(text raw: String) -> AbsorbPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text(raw) }
        guard !trimmed.contains(where: \.isWhitespace) else { return .text(trimmed) }

        let candidate = trimmed.lowercased().hasPrefix("http")
            ? trimmed
            : (looksLikeBareImageHost(trimmed) ? "https://\(trimmed)" : nil) ?? trimmed
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return .text(trimmed)
        }
        return isImagePath(url.path) ? .remoteURL(url) : .text(trimmed)
    }

    private static func looksLikeBareImageHost(_ value: String) -> Bool {
        value.contains("/") && value.contains(".") && isImagePath(value)
    }

    /// Extensions we can render as a scrap.
    public static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "tif",
        "bmp", "webp", "pdf",
    ]

    public static func isImagePath(_ path: String) -> Bool {
        imageExtensions.contains((path as NSString).pathExtension.lowercased())
    }

    /// A dropped file is a scrap if it is an image; anything else (a PSD,
    /// a folder, a zip) is ignored rather than landing as a broken tile.
    public static func payload(forFile url: URL) -> AbsorbPayload? {
        isImagePath(url.path) ? .fileURL(url) : nil
    }

    // MARK: - Pasteboard (⌘V)

    #if canImport(AppKit)
    /// Reads the wall-worthy content out of a pasteboard, richest first:
    /// files, then pixels, then text. Injectable pasteboard so this is
    /// unit-tested without touching the user's clipboard.
    public static func payloads(from pasteboard: NSPasteboard) -> [AbsorbPayload] {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           !urls.isEmpty {
            let payloads = urls.compactMap { url -> AbsorbPayload? in
                if url.isFileURL { return payload(forFile: url) }
                guard let scheme = url.scheme?.lowercased(),
                      scheme == "http" || scheme == "https" else { return nil }
                return isImagePath(url.path) ? .remoteURL(url) : nil
            }
            if !payloads.isEmpty { return payloads }
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type), !data.isEmpty {
                return [.imageData(pngData(from: data) ?? data)]
            }
        }
        if let string = pasteboard.string(forType: .string),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [classify(text: string)]
        }
        return []
    }

    /// TIFF from the clipboard becomes PNG so staged files stay small and
    /// portable.
    static func pngData(from data: Data) -> Data? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: - Drag providers

    /// Turns a dropped item into a payload. Providers advertise several
    /// representations; we take the richest one they actually carry.
    /// Main-actor isolated: NSItemProvider isn't Sendable, so it never
    /// crosses an actor boundary.
    @MainActor
    public static func payload(from provider: NSItemProvider) async -> AbsorbPayload? {
        let fileType = UTType.fileURL.identifier
        if provider.hasItemConformingToTypeIdentifier(fileType),
           let item = await loadItem(from: provider, typeIdentifier: fileType),
           let url = fileURL(from: item) {
            return payload(forFile: url)
        }
        let imageType = UTType.image.identifier
        if provider.hasItemConformingToTypeIdentifier(imageType),
           let data = await imageData(from: provider, typeIdentifier: imageType),
           !data.isEmpty {
            return .imageData(data)
        }
        for textType in [UTType.utf8PlainText.identifier, UTType.plainText.identifier,
                         UTType.url.identifier] {
            guard provider.hasItemConformingToTypeIdentifier(textType),
                  let item = await loadItem(from: provider, typeIdentifier: textType)
            else { continue }
            if let url = item as? URL { return classify(text: url.absoluteString) }
            if let data = item as? Data,
               let string = String(data: data, encoding: .utf8) {
                return classify(text: string)
            }
            if let string = item as? String { return classify(text: string) }
        }
        return nil
    }

    /// Bridges the completion-handler item API. NSItemProvider is not
    /// Sendable, so the async spellings would hop actors and warn; these
    /// continuations keep the provider on the main actor throughout.
    @MainActor
    static func loadItem(from provider: NSItemProvider,
                         typeIdentifier: String) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier,
                              options: nil) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }

    @MainActor
    static func imageData(from provider: NSItemProvider,
                          typeIdentifier: String) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(
                forTypeIdentifier: typeIdentifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    static func fileURL(from item: NSSecureCoding) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let string = item as? String { return URL(string: string) }
        return nil
    }
    #endif

    // MARK: - Scrap sizing

    /// Scraps keep the picture's own proportions — a wall of identical
    /// squares is the "engineered" look we are leaving behind. The long
    /// edge lands at `longEdge`, clamped so nothing arrives unusably small.
    public static func scrapSize(aspectRatio: CGFloat?,
                                 longEdge: CGFloat = 260,
                                 minEdge: CGFloat = 110) -> CGSize {
        guard let ratio = aspectRatio, ratio.isFinite, ratio > 0 else {
            return CGSize(width: longEdge * 0.85, height: longEdge * 0.85)
        }
        var width = ratio >= 1 ? longEdge : longEdge * ratio
        var height = ratio >= 1 ? longEdge / ratio : longEdge
        if min(width, height) < minEdge {
            let scale = minEdge / min(width, height)
            width *= scale
            height *= scale
        }
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    #if canImport(AppKit)
    /// Natural aspect ratio of an image on disk, or nil when it can't be read.
    public static func aspectRatio(ofImageAt url: URL) -> CGFloat? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        return size.width / size.height
    }
    #endif
}
