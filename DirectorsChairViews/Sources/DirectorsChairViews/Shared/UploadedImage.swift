//
//  UploadedImage.swift
//  DirectorsChairViews
//
//  Shared custom-image upload pipeline: pick (panel/pasteboard) → normalize
//  to PNG → write into the project's assets tree → return the relative path
//  the models store. Every preview surface (scene overview, shot preview,
//  location gallery, character angles, …) funnels through these helpers so
//  validation and on-disk conventions stay identical app-wide.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

public enum UploadedImage {

    /// Present the standard open panel and return the chosen file's raw data.
    /// UI-only; must be called on the main thread.
    @MainActor
    public static func pickData(message: String) -> Data? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .webP, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = message
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Image data from the general pasteboard (PNG preferred, TIFF fallback).
    public static func pasteboardData() -> Data? {
        let pasteboard = NSPasteboard.general
        if let png = pasteboard.data(forType: .png) { return png }
        return pasteboard.data(forType: .tiff)
    }

    /// Decode arbitrary image data and re-encode as PNG. Returns nil when the
    /// data is not a decodable image — the caller must treat that as a
    /// rejected upload, never write the raw bytes through.
    public static func normalizedPNG(from data: Data) -> Data? {
        guard let nsImage = NSImage(data: data),
              let tiffRep = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRep),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        return png
    }

    /// Write normalized PNG data to {projectBasePath}/{relativeDirectory}/
    /// {filename}, creating directories as needed, and return the relative
    /// path string the models store (POSIX, no leading slash).
    @discardableResult
    public static func writePNG(_ png: Data, projectBasePath: URL,
                                relativeDirectory: String,
                                filename: String) throws -> String {
        let directory = projectBasePath.appendingPathComponent(relativeDirectory)
        _ = projectBasePath.startAccessingSecurityScopedResource()
        defer { projectBasePath.stopAccessingSecurityScopedResource() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent(filename)
        try png.write(to: target)
        return relativeDirectory.hasSuffix("/")
            ? relativeDirectory + filename
            : relativeDirectory + "/" + filename
    }

    /// Timestamp suffix matching the existing on-disk history convention
    /// (e.g. overview_20260719_183000.png).
    public static func historyTimestamp(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: now)
    }
}
