//
//  ChatToolParser.swift
//  DirectorsChair-Desktop
//
//  Parses [TOOL:name]{json}[/TOOL] blocks from AI responses
//

import Foundation

struct ToolInvocation: Identifiable {
    let id = UUID()
    let name: String
    let parameters: [String: Any]
}

struct ParsedResponse {
    let displayText: String
    let tools: [ToolInvocation]
}

enum ChatToolParser {
    private static let toolPattern = try! NSRegularExpression(
        pattern: #"\[TOOL:(\w+)\]\s*(\{[^}]*(?:\{[^}]*\}[^}]*)*\})\s*\[/TOOL\]"#,
        options: [.dotMatchesLineSeparators]
    )

    static func parse(_ text: String) -> ParsedResponse {
        let nsText = text as NSString
        let matches = toolPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        guard !matches.isEmpty else {
            return ParsedResponse(displayText: text.trimmingCharacters(in: .whitespacesAndNewlines), tools: [])
        }

        var tools: [ToolInvocation] = []
        var displayText = text

        // Process matches in reverse so ranges stay valid
        for match in matches.reversed() {
            let nameRange = match.range(at: 1)
            let jsonRange = match.range(at: 2)
            let fullRange = match.range(at: 0)

            let name = nsText.substring(with: nameRange)
            let jsonString = nsText.substring(with: jsonRange)

            var params: [String: Any] = [:]
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                params = json
            }

            tools.insert(ToolInvocation(name: name, parameters: params), at: 0)

            // Remove tool block from display text
            let swiftRange = Range(fullRange, in: displayText)!
            displayText.removeSubrange(swiftRange)
        }

        return ParsedResponse(
            displayText: displayText.trimmingCharacters(in: .whitespacesAndNewlines),
            tools: tools
        )
    }
}
