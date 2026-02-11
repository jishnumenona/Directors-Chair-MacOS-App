//
//  WebSearchClient.swift
//  DirectorsChair-Desktop
//
//  Client-side web search via DuckDuckGo for AI Chat tool execution
//

import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let snippet: String
}

actor WebSearchClient {
    static let shared = WebSearchClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    func search(query: String, maxResults: Int = 5) async -> [SearchResult] {
        // Try HTML search first
        if let results = await searchHTML(query: query, maxResults: maxResults), !results.isEmpty {
            return results
        }
        // Fallback to instant answer API
        return await searchInstantAnswer(query: query, maxResults: maxResults)
    }

    private func searchHTML(query: String, maxResults: Int) async -> [SearchResult]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await session.data(for: request),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        return parseHTMLResults(html, maxResults: maxResults)
    }

    private func parseHTMLResults(_ html: String, maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []

        // Pattern for DuckDuckGo HTML results
        let linkPattern = try? NSRegularExpression(
            pattern: #"<a[^>]+class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>"#,
            options: [.dotMatchesLineSeparators]
        )
        let snippetPattern = try? NSRegularExpression(
            pattern: #"<a[^>]+class="result__snippet"[^>]*>(.*?)</a>"#,
            options: [.dotMatchesLineSeparators]
        )

        let nsHTML = html as NSString
        let linkMatches = linkPattern?.matches(in: html, range: NSRange(location: 0, length: nsHTML.length)) ?? []
        let snippetMatches = snippetPattern?.matches(in: html, range: NSRange(location: 0, length: nsHTML.length)) ?? []

        for i in 0..<min(linkMatches.count, maxResults) {
            let linkMatch = linkMatches[i]
            let rawURL = nsHTML.substring(with: linkMatch.range(at: 1))
            let rawTitle = nsHTML.substring(with: linkMatch.range(at: 2))

            // Extract actual URL from DuckDuckGo redirect
            let actualURL = extractURL(from: rawURL)
            let title = stripHTML(rawTitle)
            let snippet = i < snippetMatches.count ? stripHTML(nsHTML.substring(with: snippetMatches[i].range(at: 1))) : ""

            if !title.isEmpty && !actualURL.isEmpty {
                results.append(SearchResult(title: title, url: actualURL, snippet: snippet))
            }
        }

        return results
    }

    private func searchInstantAnswer(query: String, maxResults: Int) async -> [SearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1") else {
            return []
        }

        guard let (data, _) = try? await session.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var results: [SearchResult] = []

        // Abstract result
        if let abstract = json["AbstractText"] as? String, !abstract.isEmpty,
           let abstractURL = json["AbstractURL"] as? String, !abstractURL.isEmpty,
           let abstractSource = json["AbstractSource"] as? String {
            results.append(SearchResult(title: abstractSource, url: abstractURL, snippet: abstract))
        }

        // Related topics
        if let topics = json["RelatedTopics"] as? [[String: Any]] {
            for topic in topics.prefix(maxResults - results.count) {
                if let text = topic["Text"] as? String,
                   let firstURL = topic["FirstURL"] as? String, !firstURL.isEmpty {
                    let title = String(text.prefix(80))
                    results.append(SearchResult(title: title, url: firstURL, snippet: text))
                }
            }
        }

        return Array(results.prefix(maxResults))
    }

    private func extractURL(from ddgURL: String) -> String {
        // DuckDuckGo wraps URLs like //duckduckgo.com/l/?uddg=ENCODED_URL&...
        if ddgURL.contains("uddg="),
           let components = URLComponents(string: ddgURL.hasPrefix("//") ? "https:\(ddgURL)" : ddgURL),
           let uddg = components.queryItems?.first(where: { $0.name == "uddg" })?.value {
            return uddg
        }
        if ddgURL.hasPrefix("//") {
            return "https:\(ddgURL)"
        }
        return ddgURL
    }

    private func stripHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
