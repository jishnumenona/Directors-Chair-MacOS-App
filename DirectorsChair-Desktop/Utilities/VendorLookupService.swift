//
//  VendorLookupService.swift
//  DirectorsChair-Desktop
//
//  DC-0133 — the network half of "autodetect a vendor from a Google result
//  link". Mirrors ReceiptAnalysisService: the pure parsing lives in the
//  DirectorsChairProduction package (VendorLookup), this asks the AI server
//  for the vendor's attributes and, best-effort, downloads a representative
//  picture into the project's assets/vendors/ folder.
//
//  The model has no live web access here, so attributes come from its
//  parametric knowledge (good for well-known businesses) and are asked for
//  conservatively — empty rather than fabricated. The picture is fetched from
//  the vendor's own site (og:image) or a direct image URL the model supplied.
//

import Foundation
import AppKit
import DirectorsChairProduction
import DirectorsChairServices
import DirectorsChairViews

enum VendorLookupService {

    // MARK: - Prompt

    static func buildPrompt(vendorName: String) -> String {
        """
        A film production wants to add "\(vendorName)" to its vendor directory.
        Identify this real-world business or supplier and return ONLY valid JSON:
        {
          "name": "official business name (correct obvious misspellings)",
          "category": "short vendor category, e.g. Hotel, Catering, Equipment rental, Location, Transportation",
          "phone": "main phone number in local format",
          "email": "contact email if commonly known, else empty",
          "website": "official website URL (https://…)",
          "address": "street address",
          "city": "city",
          "region": "state or province",
          "country": "country",
          "description": "one concise sentence describing the business",
          "rating": 4.5,
          "image_url": "a direct https URL to a representative photo if you know one, else empty"
        }

        Rules:
        - Return ONLY the JSON object, no prose, no markdown fences.
        - Use "" for any field you are not confident about. NEVER invent a phone
          number, address or email — an empty string is correct when unsure.
        - "rating" is a number 0–5 or omit it if unknown.
        - Prefer the official website for "website".
        """
    }

    // MARK: - Full lookup (network)

    /// Look up a vendor from a pasted Google/Maps/result link. Returns nil if
    /// the name can't be extracted, the AI is unreachable, or nothing usable
    /// comes back. On success, attempts to download a picture into
    /// `projectBasePath/assets/vendors/` and reports its project-relative path.
    static func lookup(googleURL: URL, projectBasePath: URL?) async -> VendorLookupResult? {
        let name = VendorLookup.vendorName(fromGoogleURL: googleURL.absoluteString)
        guard !name.isEmpty else {
            debugLog("Vendor lookup: no name in URL")
            return nil
        }

        let aiClient = AIServiceClient.shared
        guard await aiClient.testConnection() else {
            debugLog("Vendor lookup: AI server connection failed")
            await ErrorPresenter.shared.present(title: "Vendor lookup failed",
                                                message: "Could not reach the AI server. Check your connection in Settings.")
            return nil
        }

        let request = TextGenerationRequest(
            prompt: buildPrompt(vendorName: name),
            provider: AIProviderSelection.shared.provider(for: .text),
            maxTokens: 1200,
            temperature: 0.1
        )

        var result: VendorLookupResult
        do {
            let response = try await aiClient.generateText(request)
            guard let parsed = VendorLookup.parse(response.text) else {
                debugLog("Vendor lookup: could not parse model reply")
                return nil
            }
            result = parsed
        } catch {
            debugLog("Vendor lookup error: \(error)")
            await ErrorPresenter.shared.present(error, context: "Vendor lookup")
            return nil
        }

        // Fall back to the extracted name if the model didn't return one.
        if result.name.isEmpty { result.name = name }

        // Best-effort picture: a direct image URL, else the site's og:image.
        if let imagePath = await downloadPicture(for: result, projectBasePath: projectBasePath) {
            result.imagePath = imagePath
        }
        debugLog("Vendor lookup: resolved \"\(result.name)\", picture: \(result.imagePath != nil)")
        return result
    }

    // MARK: - Picture download

    /// Try to obtain a photo and store it under assets/vendors/. Order:
    /// 1) the model's `image_url` if it decodes to an image;
    /// 2) the vendor website's og:image / twitter:image.
    static func downloadPicture(for result: VendorLookupResult, projectBasePath: URL?) async -> String? {
        guard let basePath = projectBasePath else { return nil }

        // 1) Direct image URL from the model.
        if let raw = result.imageUrl, let url = URL(string: raw), url.scheme?.hasPrefix("http") == true {
            if let stored = await fetchAndStoreImage(from: url, basePath: basePath) { return stored }
        }

        // 2) og:image from the official website.
        if !result.website.isEmpty, let site = normalizedURL(result.website) {
            if let html = await fetchText(from: site),
               let ogURL = VendorLookup.ogImageURL(inHTML: html, pageURL: site) {
                if let stored = await fetchAndStoreImage(from: ogURL, basePath: basePath) { return stored }
            }
        }
        return nil
    }

    private static func normalizedURL(_ s: String) -> URL? {
        if let u = URL(string: s), u.scheme != nil { return u }
        return URL(string: "https://\(s)")
    }

    private static func fetchText(from url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0 (Macintosh) DirectorsChair", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else { return nil }
            // Only parse a reasonable amount of HTML for meta tags.
            let slice = data.prefix(400_000)
            return String(data: slice, encoding: .utf8) ?? String(decoding: slice, as: UTF8.self)
        } catch {
            debugLog("Vendor lookup: page fetch failed \(error.localizedDescription)")
            return nil
        }
    }

    /// Download an image, verify it decodes, re-encode to JPEG (bounded size)
    /// and write it to assets/vendors/. Returns the project-relative path.
    private static func fetchAndStoreImage(from url: URL, basePath: URL) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (Macintosh) DirectorsChair", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            guard data.count < 20_000_000, let image = NSImage(data: data) else { return nil }

            let jpeg = jpegData(from: image, maxPixel: 1400) ?? data
            let dir = basePath.appendingPathComponent("assets/vendors")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let filename = "\(UUID().uuidString).jpg"
            let dest = dir.appendingPathComponent(filename)
            try jpeg.write(to: dest)
            return "assets/vendors/\(filename)"
        } catch {
            debugLog("Vendor lookup: image download failed \(error.localizedDescription)")
            return nil
        }
    }

    /// Downscale to a max dimension and encode JPEG at 0.85.
    private static func jpegData(from image: NSImage, maxPixel: CGFloat) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        let w = CGFloat(rep.pixelsWide), h = CGFloat(rep.pixelsHigh)
        guard w > 0, h > 0 else { return nil }
        let scale = min(1, maxPixel / max(w, h))
        let targetW = Int(w * scale), targetH = Int(h * scale)

        guard scale < 1,
              let resized = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: targetW, pixelsHigh: targetH,
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else {
            // No downscale needed (or couldn't build a context) — encode as-is.
            return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        }
        resized.size = NSSize(width: targetW, height: targetH)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: resized)
        image.draw(in: NSRect(x: 0, y: 0, width: targetW, height: targetH),
                   from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return resized.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
