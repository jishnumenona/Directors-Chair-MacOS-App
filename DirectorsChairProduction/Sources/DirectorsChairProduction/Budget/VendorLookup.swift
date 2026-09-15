// DirectorsChairProduction/Sources/DirectorsChairProduction/Budget/VendorLookup.swift
//
// DC-0133 — the PURE half of "autodetect a vendor from a Google result link":
// pull the business name out of a Google/Maps URL, and parse the AI model's
// JSON reply into typed attributes. The networking, AI call and picture
// download live in the app target's VendorLookupService (this package depends
// only on Core), which calls these functions. Kept pure so both are unit-tested
// without a server.

import Foundation

// MARK: - Result

/// What a vendor lookup produced. Every field is optional-by-emptiness so a
/// partial answer still fills what it can; `imagePath` is project-relative when
/// the app target managed to download a picture.
public struct VendorLookupResult: Sendable, Equatable {
    public var name: String
    public var category: String
    public var phone: String
    public var email: String
    public var website: String
    public var address: String
    public var city: String
    public var region: String
    public var country: String
    public var description: String
    public var rating: Double?
    public var imageUrl: String?      // Remote URL the model/site suggested
    public var imagePath: String?     // Project-relative path once downloaded

    public init(
        name: String = "",
        category: String = "",
        phone: String = "",
        email: String = "",
        website: String = "",
        address: String = "",
        city: String = "",
        region: String = "",
        country: String = "",
        description: String = "",
        rating: Double? = nil,
        imageUrl: String? = nil,
        imagePath: String? = nil
    ) {
        self.name = name
        self.category = category
        self.phone = phone
        self.email = email
        self.website = website
        self.address = address
        self.city = city
        self.region = region
        self.country = country
        self.description = description
        self.rating = rating
        self.imageUrl = imageUrl
        self.imagePath = imagePath
    }
}

// MARK: - Pure logic

public enum VendorLookup {

    /// Pull a business name out of a pasted link. Handles a Google search URL
    /// (`?q=Arizona+grand+resort`), a Maps place URL (`/maps/place/Name/@…`),
    /// or falls back to the last meaningful path/query text. Strips the noise
    /// word "google" people leave in their search, decodes `+`/percent-escapes,
    /// and collapses whitespace. Returns "" when nothing usable is present.
    public static func vendorName(fromGoogleURL raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // A bare business name (not a URL) — use it as-is.
        guard let comps = URLComponents(string: trimmed), comps.scheme != nil || trimmed.contains("/") || trimmed.contains("?") else {
            return clean(trimmed)
        }

        // 1) Google Maps place: /maps/place/<Name>/...
        if let path = comps.percentEncodedPath.removingPercentEncoding ?? comps.path as String?,
           let range = path.range(of: "/place/") {
            let after = path[range.upperBound...]
            let name = after.split(separator: "/").first.map(String.init) ?? ""
            let decoded = name.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? name
            let cleaned = clean(decoded)
            if !cleaned.isEmpty { return cleaned }
        }

        // 2) A search query parameter (q= or query=).
        if let items = comps.queryItems {
            for key in ["q", "query", "search"] {
                if let value = items.first(where: { $0.name == key })?.value, !value.isEmpty {
                    let decoded = value.replacingOccurrences(of: "+", with: " ")
                    let cleaned = clean(decoded)
                    if !cleaned.isEmpty { return cleaned }
                }
            }
        }

        // 3) Fall back to the host (minus www/TLD) so at least something seeds.
        if let host = comps.host {
            let core = host.replacingOccurrences(of: "www.", with: "")
                .split(separator: ".").first.map(String.init) ?? host
            return clean(core.replacingOccurrences(of: "-", with: " "))
        }
        return ""
    }

    /// Normalise an extracted name: collapse whitespace and drop the stray
    /// "google" search token people paste (but never turn a real name empty).
    static func clean(_ s: String) -> String {
        let collapsed = s.replacingOccurrences(of: "%20", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let dropped = collapsed.filter { $0.lowercased() != "google" }
        let words = dropped.isEmpty ? collapsed : dropped
        return words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse the model's JSON reply into a result. Tolerates ```json fences and
    /// rating arriving as Double/Int/String; unknown/missing fields stay empty.
    public static func parse(_ text: String) -> VendorLookupResult? {
        var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        func str(_ keys: String...) -> String {
            for k in keys {
                if let v = json[k] as? String, !v.isEmpty { return v.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            return ""
        }

        var rating: Double?
        if let d = json["rating"] as? Double { rating = d }
        else if let i = json["rating"] as? Int { rating = Double(i) }
        else if let s = json["rating"] as? String, let d = Double(s) { rating = d }

        let name = str("name", "vendor", "business_name")
        // Nothing usable came back.
        let imageUrl = str("image_url", "imageUrl", "photo_url", "image")
        let result = VendorLookupResult(
            name: name,
            category: str("category", "type"),
            phone: str("phone", "phone_number", "telephone"),
            email: str("email"),
            website: str("website", "url", "site"),
            address: str("address", "street", "street_address"),
            city: str("city", "locality"),
            region: str("region", "state", "province"),
            country: str("country"),
            description: str("description", "summary", "about"),
            rating: rating,
            imageUrl: imageUrl.isEmpty ? nil : imageUrl,
            imagePath: nil
        )
        // Consider the parse a success only if it named the vendor or gave a
        // detail we can actually show.
        if result.name.isEmpty && result.website.isEmpty && result.address.isEmpty && result.phone.isEmpty {
            return nil
        }
        return result
    }

    /// Extract the first `og:image` (or `twitter:image`) URL from a page's
    /// HTML, resolved against the page URL. Used to grab a real photo when the
    /// model didn't supply a usable image link. Pure string work.
    public static func ogImageURL(inHTML html: String, pageURL: URL?) -> URL? {
        // Match <meta property="og:image" content="..."> in either attribute order.
        let patterns = [
            #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']"#,
            #"<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range),
               match.numberOfRanges >= 2,
               let r = Range(match.range(at: 1), in: html) {
                let value = String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let abs = URL(string: value), abs.scheme != nil { return abs }
                if let page = pageURL, let rel = URL(string: value, relativeTo: page) { return rel.absoluteURL }
            }
        }
        return nil
    }
}
