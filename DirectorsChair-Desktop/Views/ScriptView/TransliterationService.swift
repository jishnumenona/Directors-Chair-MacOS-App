//
//  TransliterationService.swift
//  DirectorsChair-Desktop
//
//  Varnam API client for Manglish-to-Malayalam transliteration.
//  GET https://api.varnamproject.com/tl/{language}/{word}
//

import Foundation

struct VarnamResponse: Decodable {
    let success: Bool
    let result: [String]
    let input: String
}

class TransliterationService {
    private let baseURL = "https://api.varnamproject.com/tl"
    private var cache: [String: [String]] = [:]
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        session = URLSession(configuration: config)
    }

    func transliterate(_ input: String, language: String = "ml") async throws -> [String] {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        // Check cache
        let cacheKey = "\(language):\(trimmed)"
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/\(language)/\(encoded)") else {
            return []
        }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(VarnamResponse.self, from: data)

        let result = Array(response.result.prefix(5))

        // Cache result
        cache[cacheKey] = result
        return result
    }
}
