// DirectorsChairServices/Assistant/AssistantChatModels.swift
//
// AssistantKit (AI Assistant program, Phase A2.1): the neutral chat wire
// contract shared with the gateway's POST /generate/chat (server plan §6.1).
// Value types only, Sendable throughout — the transport, engine, and tests
// all speak these shapes; no provider dialect ever leaks past the gateway.

import Foundation

// MARK: - JSONValue

/// A `Codable`, `Sendable`, `Equatable` representation of arbitrary JSON —
/// used for tool parameters (JSON Schema) and tool-call arguments, where
/// `[String: Any]` would be neither `Codable` nor `Sendable`.
public indirect enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// The value re-encoded as compact JSON `Data` — the form handed to an
    /// action's typed `Arguments` decoder.
    public func encodedData() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}

// MARK: - Messages

public enum ChatRole: String, Codable, Sendable {
    case system, user, assistant, tool
}

public struct ChatContentPart: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case text, image }

    public var type: Kind
    public var text: String?
    /// Base64 image payload (`type == .image`).
    public var data: String?
    public var mimeType: String?

    enum CodingKeys: String, CodingKey {
        case type, text, data
        case mimeType = "mime_type"
    }

    public static func text(_ text: String) -> ChatContentPart {
        ChatContentPart(type: .text, text: text, data: nil, mimeType: nil)
    }

    public static func image(base64: String, mimeType: String) -> ChatContentPart {
        ChatContentPart(type: .image, text: nil, data: base64, mimeType: mimeType)
    }
}

public struct AssistantToolCall: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var arguments: JSONValue

    public init(id: String, name: String, arguments: JSONValue) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

public struct ChatMessage: Codable, Equatable, Sendable {
    public var role: ChatRole
    public var content: [ChatContentPart]?
    public var toolCalls: [AssistantToolCall]?
    public var toolCallId: String?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }

    public init(role: ChatRole, content: [ChatContentPart]? = nil,
                toolCalls: [AssistantToolCall]? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }

    public static func system(_ text: String) -> ChatMessage {
        ChatMessage(role: .system, content: [.text(text)])
    }

    public static func user(_ parts: [ChatContentPart]) -> ChatMessage {
        ChatMessage(role: .user, content: parts)
    }

    public static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, content: [.text(text)])
    }

    public static func assistant(_ text: String,
                                 toolCalls: [AssistantToolCall]? = nil) -> ChatMessage {
        ChatMessage(role: .assistant,
                    content: text.isEmpty ? [] : [.text(text)],
                    toolCalls: toolCalls)
    }

    public static func toolResult(callId: String, _ text: String) -> ChatMessage {
        ChatMessage(role: .tool, content: [.text(text)], toolCallId: callId)
    }

    /// The concatenated text content, for display and persistence.
    public var textContent: String {
        (content ?? []).compactMap(\.text).joined()
    }
}

// MARK: - Tools

public struct ToolDefinition: Codable, Equatable, Sendable {
    public var name: String
    public var description: String
    /// JSON Schema for the arguments object.
    public var parameters: JSONValue

    public init(name: String, description: String, parameters: JSONValue) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - Request

public struct ChatRequestBody: Encodable, Sendable {
    public var messages: [ChatMessage]
    public var tools: [ToolDefinition]
    public var toolChoice: String
    public var provider: String?
    public var model: String?
    public var maxTokens: Int
    public var temperature: Double
    public var stream: Bool
    public var projectId: String?
    public var turnId: String?

    enum CodingKeys: String, CodingKey {
        case messages, tools, provider, model, stream, temperature
        case toolChoice = "tool_choice"
        case maxTokens = "max_tokens"
        case projectId = "project_id"
        case turnId = "turn_id"
    }

    public init(messages: [ChatMessage], tools: [ToolDefinition] = [],
                toolChoice: String = "auto", provider: String? = nil,
                model: String? = nil, maxTokens: Int = 4000,
                temperature: Double = 0.7, stream: Bool = true,
                projectId: String? = nil, turnId: String? = nil) {
        self.messages = messages
        self.tools = tools
        self.toolChoice = toolChoice
        self.provider = provider
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.stream = stream
        self.projectId = projectId
        self.turnId = turnId
    }
}

// MARK: - Stream events

public struct ChatUsage: Codable, Equatable, Sendable {
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

/// One decoded server-sent event from `/generate/chat` (gateway A1.2 wire).
public enum ChatStreamEvent: Equatable, Sendable {
    case delta(String)
    case toolCall(AssistantToolCall)
    case usage(ChatUsage)
    case done(finishReason: String, model: String?)
    case error(String)
}
