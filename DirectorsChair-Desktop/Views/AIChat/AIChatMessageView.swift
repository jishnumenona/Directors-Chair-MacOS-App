//
//  AIChatMessageView.swift
//  DirectorsChair-Desktop
//
//  Styled chat message bubbles for AI Chat overlay
//

import SwiftUI

struct AIChatMessageView: View {
    let message: ChatMessage
    let pendingModification: ProjectModification?
    let onApply: () -> Void
    let onDecline: () -> Void

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        case .system:
            systemBubble
        case .toolResult:
            toolResultBubble
        }
    }

    // MARK: - User Message

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 80)
            Text(message.content)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.85))
                .cornerRadius(16)
                .cornerRadius(4, corners: .bottomRight)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    // MARK: - Assistant Message

    private var assistantBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    Text("AI ASSISTANT")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }

                MarkdownTextView(text: message.content)

                // Show modification card if pending
                if let mod = pendingModification {
                    modificationCard(mod)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedCorner(radius: 16, corners: .allCorners)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .cornerRadius(16)
            .cornerRadius(4, corners: .bottomLeft)

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    // MARK: - System Message

    private var systemBubble: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(message.content)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 1)
    }

    // MARK: - Tool Result

    private var toolResultBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(.orange.opacity(0.8))
                    Text("SEARCH RESULTS")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(.orange.opacity(0.8))
                }

                Text(message.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(12)
                    .textSelection(.enabled)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.orange.opacity(0.15), lineWidth: 0.5)
            )

            Spacer(minLength: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    // MARK: - Modification Confirmation Card

    private func modificationCard(_ mod: ProjectModification) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.orange)
                Text("SUGGESTED CHANGE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.orange)
            }

            Text(mod.description)
                .font(.system(size: 12, weight: .medium))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WAS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(mod.oldValue)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(3)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEW")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(mod.newValue)
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                        .lineLimit(3)
                }
            }

            if !mod.reason.isEmpty {
                Text(mod.reason)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .italic()
            }

            HStack(spacing: 10) {
                Button(action: onApply) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Apply")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: onDecline) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Decline")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Markdown Text View

/// Renders markdown-formatted AI responses with bold, italic, bullets, and headers
struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parseLines().enumerated()), id: \.offset) { _, line in
                line.view
            }
        }
        .textSelection(.enabled)
    }

    private struct ParsedLine {
        enum Kind {
            case header(String)
            case bullet(AttributedString)
            case body(AttributedString)
            case blank
        }
        let kind: Kind

        @ViewBuilder var view: some View {
            switch kind {
            case .header(let text):
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .padding(.top, 6)
            case .bullet(let attributed):
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\u{2022}")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentColor)
                    Text(attributed)
                        .font(.system(size: 13))
                        .foregroundColor(Color(nsColor: .labelColor))
                }
            case .body(let attributed):
                Text(attributed)
                    .font(.system(size: 13))
                    .foregroundColor(Color(nsColor: .labelColor))
            case .blank:
                Spacer().frame(height: 4)
            }
        }
    }

    private func parseLines() -> [ParsedLine] {
        let lines = text.components(separatedBy: "\n")
        var result: [ParsedLine] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                result.append(ParsedLine(kind: .blank))
                continue
            }

            // Bullet: starts with "* " or "- "
            if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
                let content = String(trimmed.dropFirst(2))
                result.append(ParsedLine(kind: .bullet(renderInline(content))))
                continue
            }

            // Header: **SOMETHING:** pattern (entire line is bold, like section headers)
            if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") && !trimmed.dropFirst(2).dropLast(2).contains("**") {
                let inner = String(trimmed.dropFirst(2).dropLast(2))
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces)
                result.append(ParsedLine(kind: .header(inner)))
                continue
            }

            // Regular body text with inline markdown
            result.append(ParsedLine(kind: .body(renderInline(trimmed))))
        }

        return result
    }

    /// Converts inline **bold** and *italic* markdown into AttributedString
    private func renderInline(_ text: String) -> AttributedString {
        // Try SwiftUI's built-in markdown parsing first
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        // Fallback to plain text
        return AttributedString(text)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dotOffset: CGFloat = 0

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .offset(y: dotOffset(for: i))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)

            Spacer()
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                dotOffset = -4
            }
        }
    }

    private func dotOffset(for index: Int) -> CGFloat {
        let phase = Double(index) * 0.2
        return sin((Double(dotOffset) + phase) * .pi) * 4
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: RectCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        return path
    }
}
