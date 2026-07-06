//
//  ReceiptAnalysisService.swift
//  DirectorsChair-Desktop
//
//  WS6.4 — AI receipt analysis extracted from the ProductionContainer view
//  into a service with a PURE, unit-tested parser. Receipt contents are
//  financial data: logging stays at .debug lengths/counts, never raw values.
//

import Foundation
import DirectorsChairProduction
import DirectorsChairServices

enum ReceiptAnalysisService {

    // MARK: - Prompt

    static func buildPrompt(categoryNames: String) -> String {
        """
        Analyze this receipt image. If the receipt contains multiple distinct line items, return ALL items individually.
        Return ONLY valid JSON with this structure:
        {
          "vendor": "store/vendor name",
          "date": "YYYY-MM-DD format",
          "items": [
            {"description": "item 1 description", "amount": 12.99, "category": "best matching category"},
            {"description": "item 2 description", "amount": 45.00, "category": "best matching category"}
          ]
        }

        Rules:
        - "vendor" and "date" are shared across all items.
        - Each item in "items" should have its own description, amount, and category.
        - If the receipt has only one item or a single total, return a single item in the array.
        - Do NOT include tax/tip as separate items unless they are distinct line items on the receipt.
        - Available budget categories: \(categoryNames)
        - Choose the category that best matches each item. If no category matches well, use the most general one.
        - Return ONLY the JSON object, no other text.
        """
    }

    // MARK: - Parsing (pure)

    /// Parse the model's response text into typed results. Tolerates markdown
    /// code fences and amounts arriving as Double, Int, or String.
    static func parse(_ text: String) -> [ReceiptAnalysisResult] {
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

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }

        let sharedVendor = json["vendor"] as? String ?? ""
        let sharedDate = json["date"] as? String ?? ""
        guard let items = json["items"] as? [[String: Any]], !items.isEmpty else { return [] }

        return items.map { item in
            let parsedAmount: Double
            if let doubleVal = item["amount"] as? Double {
                parsedAmount = doubleVal
            } else if let intVal = item["amount"] as? Int {
                parsedAmount = Double(intVal)
            } else if let strVal = item["amount"] as? String, let numVal = Double(strVal) {
                parsedAmount = numVal
            } else {
                parsedAmount = 0
            }
            return ReceiptAnalysisResult(
                description: item["description"] as? String ?? "",
                vendor: sharedVendor,
                date: sharedDate,
                amount: parsedAmount,
                category: item["category"] as? String ?? ""
            )
        }
    }

    // MARK: - Full analysis (network)

    static func analyze(imageData: Data, mimeType: String, categoryNames: String) async -> [ReceiptAnalysisResult] {
        let aiClient = AIServiceClient.shared
        debugLog("Receipt analysis: \(imageData.count) bytes, mime \(mimeType)")

        guard await aiClient.testConnection() else {
            debugLog("Receipt analysis: AI server connection failed")
            return []
        }

        let request = TextGenerationRequest(
            prompt: buildPrompt(categoryNames: categoryNames),
            provider: .google,
            maxTokens: 4000,
            temperature: 0.1,
            imageBase64: imageData.base64EncodedString(),
            imageMimeType: mimeType
        )

        do {
            let response = try await aiClient.generateText(request)
            let results = parse(response.text)
            debugLog("Receipt analysis: \(results.count) results")
            return results
        } catch {
            debugLog("Receipt analysis error: \(error)")
            return []
        }
    }
}
