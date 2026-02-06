// DirectorsChairServices/Sources/DirectorsChairServices/AI/AIServiceClient.swift
//
// Multi-provider AI Service Client for DirectorsChair
// Supports OpenAI, Anthropic, Google, Stability, DeepSeek

import Foundation
import DirectorsChairCore

// MARK: - AI Provider

/// Available AI providers
public enum AIProvider: String, Sendable, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case googleGemini = "google_gemini"
    case googleImagen = "google_imagen"
    case stability = "stability"
    case deepseek = "deepseek"
    case elevenlabs = "elevenlabs"
    
    /// Default provider for text generation
    public static var defaultTextProvider: AIProvider { .deepseek }
    
    /// Default provider for image generation
    public static var defaultImageProvider: AIProvider { .googleImagen }
}

// MARK: - AI Service Error

/// Errors specific to the AI service client
public enum AIClientError: LocalizedError, Sendable {
    case serverUnavailable(String)
    case providerNotAvailable(String)
    case requestFailed(String)
    case invalidResponse(String)
    case generationFailed(String)
    case timeout
    case networkError(String)
    case invalidConfiguration(String)
    
    public var errorDescription: String? {
        switch self {
        case .serverUnavailable(let url):
            return "AI server unavailable at \(url). Please ensure the server is running."
        case .providerNotAvailable(let provider):
            return "AI provider '\(provider)' is not available. Please configure API key."
        case .requestFailed(let reason):
            return "AI request failed: \(reason)"
        case .invalidResponse(let reason):
            return "Invalid AI response: \(reason)"
        case .generationFailed(let reason):
            return "AI generation failed: \(reason)"
        case .timeout:
            return "AI request timed out. AI operations can take time."
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        }
    }
}

// MARK: - AI Generation Type

/// Types of AI content generation
public enum AIGenerationType: String, Sendable {
    case text
    case image
    case audio
    case video
    case characterAnalysis
    case sceneDescription
    case dialogueEnhancement
}

// MARK: - Text Generation Request

/// Request for text generation
public struct TextGenerationRequest: Sendable {
    public var prompt: String
    public var provider: AIProvider
    public var model: String?
    public var maxTokens: Int
    public var temperature: Double
    public var systemPrompt: String?
    public var imageBase64: String?
    public var imageMimeType: String
    
    public init(
        prompt: String,
        provider: AIProvider = .deepseek,
        model: String? = nil,
        maxTokens: Int = 1000,
        temperature: Double = 0.7,
        systemPrompt: String? = nil,
        imageBase64: String? = nil,
        imageMimeType: String = "image/png"
    ) {
        self.prompt = prompt
        self.provider = provider
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.systemPrompt = systemPrompt
        self.imageBase64 = imageBase64
        self.imageMimeType = imageMimeType
    }
}

// MARK: - Text Generation Response

/// Response from text generation
public struct TextGenerationResponse: Sendable {
    public var text: String
    public var provider: AIProvider
    public var model: String
    public var usage: TokenUsage
    
    public init(text: String, provider: AIProvider, model: String, usage: TokenUsage) {
        self.text = text
        self.provider = provider
        self.model = model
        self.usage = usage
    }
}

/// Token usage information
public struct TokenUsage: Sendable {
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalTokens: Int
    
    public init(promptTokens: Int = 0, completionTokens: Int = 0, totalTokens: Int = 0) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

// MARK: - Image Generation Request

/// Request for image generation
public struct ImageGenerationRequest: Sendable {
    public var prompt: String
    public var provider: AIProvider
    public var model: String?
    public var aspectRatio: String
    public var numberOfImages: Int
    public var referenceImageBase64: String?
    public var referenceMimeType: String?
    
    public init(
        prompt: String,
        provider: AIProvider = .googleImagen,
        model: String? = nil,
        aspectRatio: String = "16:9",
        numberOfImages: Int = 1,
        referenceImageBase64: String? = nil,
        referenceMimeType: String? = nil
    ) {
        self.prompt = prompt
        self.provider = provider
        self.model = model
        self.aspectRatio = aspectRatio
        self.numberOfImages = numberOfImages
        self.referenceImageBase64 = referenceImageBase64
        self.referenceMimeType = referenceMimeType
    }
}

// MARK: - Image Generation Response

/// Response from image generation
public struct ImageGenerationResponse: Sendable {
    public var images: [Data]
    public var provider: AIProvider
    public var model: String
    
    public init(images: [Data], provider: AIProvider, model: String) {
        self.images = images
        self.provider = provider
        self.model = model
    }
}

// MARK: - Server Health Response

/// Health check response from AI server
public struct AIServerHealth: Sendable {
    public var status: String
    public var service: String
    public var timestamp: Date
    public var providers: [String: Bool]
    
    public var isHealthy: Bool {
        status == "healthy"
    }
    
    public func isProviderAvailable(_ provider: AIProvider) -> Bool {
        // Normalize provider names
        let normalizedKey: String
        switch provider {
        case .googleGemini, .googleImagen:
            normalizedKey = "google"
        default:
            normalizedKey = provider.rawValue
        }
        return providers[normalizedKey] ?? false
    }
}

// MARK: - AI Service Client Actor

/// Thread-safe AI service client
/// Handles all communication with the AI Proxy server
public actor AIServiceClient {
    
    // MARK: - Properties
    
    private let baseURL: URL
    private let timeout: TimeInterval
    private let session: URLSession
    private var projectName: String
    
    /// Shared instance with default configuration
    public static let shared = AIServiceClient()
    
    // MARK: - Initialization
    
    /// Initialize with custom configuration
    /// - Parameters:
    ///   - baseURL: AI Proxy server URL (default: http://165.22.172.244:8002)
    ///   - timeout: Request timeout in seconds (default: 120)
    ///   - projectName: Current project name for usage tracking
    public init(
        baseURL: String = "http://165.22.172.244:8002",
        timeout: TimeInterval = 120,
        projectName: String = ""
    ) {
        self.baseURL = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))!
        self.timeout = timeout
        self.projectName = projectName
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Configuration
    
    /// Update the project name for usage tracking
    public func setProjectName(_ name: String) {
        self.projectName = name
    }
    
    // MARK: - Health & Status
    
    /// Check AI server health and available providers
    public func checkHealth() async throws -> AIServerHealth {
        let url = baseURL.appendingPathComponent("health")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse("Not an HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIClientError.serverUnavailable(baseURL.absoluteString)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        let status = json?["status"] as? String ?? "unknown"
        let service = json?["service"] as? String ?? "unknown"
        let timestampString = json?["timestamp"] as? String
        let providersDict = json?["providers"] as? [String: Bool] ?? [:]
        
        let timestamp: Date
        if let ts = timestampString {
            let formatter = ISO8601DateFormatter()
            timestamp = formatter.date(from: ts) ?? Date()
        } else {
            timestamp = Date()
        }
        
        return AIServerHealth(
            status: status,
            service: service,
            timestamp: timestamp,
            providers: providersDict
        )
    }
    
    /// Check if a specific provider is available
    public func isProviderAvailable(_ provider: AIProvider) async -> Bool {
        do {
            let health = try await checkHealth()
            return health.isProviderAvailable(provider)
        } catch {
            return false
        }
    }
    
    /// Test connection to AI server
    public func testConnection() async -> Bool {
        do {
            let health = try await checkHealth()
            return health.isHealthy
        } catch {
            return false
        }
    }
    
    // MARK: - Text Generation
    
    /// Generate text using AI
    public func generateText(_ request: TextGenerationRequest) async throws -> TextGenerationResponse {
        // Verify provider availability
        guard await isProviderAvailable(request.provider) else {
            throw AIClientError.providerNotAvailable(request.provider.rawValue)
        }
        
        let url = baseURL.appendingPathComponent("generate/text")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        var body: [String: Any] = [
            "prompt": request.prompt,
            "provider": request.provider.rawValue,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature
        ]
        
        if let model = request.model {
            body["model"] = model
        }
        if let systemPrompt = request.systemPrompt {
            body["system_prompt"] = systemPrompt
        }
        if let imageBase64 = request.imageBase64 {
            body["image_base64"] = imageBase64
            body["image_mime_type"] = request.imageMimeType
        }
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse("Not an HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIClientError.requestFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIClientError.invalidResponse("Invalid JSON response")
        }
        
        guard json["success"] as? Bool == true else {
            let error = json["error"] as? String ?? "Unknown error"
            throw AIClientError.generationFailed(error)
        }
        
        guard let dataDict = json["data"] as? [String: Any],
              let text = dataDict["text"] as? String else {
            throw AIClientError.invalidResponse("Missing text in response")
        }
        
        let model = dataDict["model"] as? String ?? request.model ?? "unknown"
        
        let usageDict = json["usage"] as? [String: Int] ?? [:]
        let usage = TokenUsage(
            promptTokens: usageDict["prompt_tokens"] ?? 0,
            completionTokens: usageDict["completion_tokens"] ?? 0,
            totalTokens: usageDict["total_tokens"] ?? 0
        )
        
        return TextGenerationResponse(
            text: text,
            provider: request.provider,
            model: model,
            usage: usage
        )
    }
    
    // MARK: - Image Generation
    
    /// Generate images using AI
    public func generateImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let url = baseURL.appendingPathComponent("generate/image")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        var body: [String: Any] = [
            "prompt": request.prompt,
            "provider": request.provider.rawValue,
            "aspect_ratio": request.aspectRatio,
            "n": request.numberOfImages
        ]
        
        if let model = request.model {
            body["model"] = model
        }
        if let refImage = request.referenceImageBase64 {
            body["reference_image_base64"] = refImage
            body["reference_mime_type"] = request.referenceMimeType ?? "image/png"
        }
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse("Not an HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIClientError.requestFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIClientError.invalidResponse("Invalid JSON response")
        }
        
        guard json["success"] as? Bool == true else {
            let error = json["error"] as? String ?? "Unknown error"
            throw AIClientError.generationFailed(error)
        }
        
        guard let dataDict = json["data"] as? [String: Any],
              let imagesBase64 = dataDict["images"] as? [String] else {
            throw AIClientError.invalidResponse("Missing images in response")
        }
        
        let model = dataDict["model"] as? String ?? request.model ?? "unknown"
        
        // Decode base64 images
        var images: [Data] = []
        for base64String in imagesBase64 {
            if let imageData = Data(base64Encoded: base64String) {
                images.append(imageData)
            }
        }
        
        return ImageGenerationResponse(
            images: images,
            provider: request.provider,
            model: model
        )
    }
    
    // MARK: - Specialized DirectorsChair Features
    
    /// Generate a scene description
    public func generateSceneDescription(
        sceneNumber: Int,
        sceneHeading: String,
        characters: [String],
        location: String,
        timeOfDay: String,
        brief: String = "",
        dialogue: [[String: String]]? = nil,
        actions: [[String: String]]? = nil,
        narrations: [String]? = nil,
        genre: String = "",
        provider: AIProvider = .deepseek
    ) async throws -> String {
        
        let systemPrompt = """
        You are a professional screenwriter with extensive experience in crafting vivid, cinematic scene descriptions for film scripts. Your descriptions:
        
        1. Establish location and atmosphere using sensory details
        2. Describe what characters are doing (actions, positioning, body language)
        3. Set the emotional tone of the scene
        4. Use proper screenplay formatting and present tense
        5. Are concise yet evocative (2-3 paragraphs, 150-250 words)
        6. Avoid including actual dialogue or camera directions
        7. Focus on what can be SEEN and FELT on screen
        
        When dialogue is provided:
        - Use dialogue to inform WHEN specific actions happen
        - Show how conversation affects body language and positioning
        - Reflect emotional shifts that the dialogue reveals
        - DO NOT repeat or paraphrase the actual dialogue
        - Focus on what the CAMERA captures beyond the words
        """
        
        var promptParts = ["Write a detailed scene description for:\n\nSCENE \(sceneNumber) - \(sceneHeading). \(location) - \(timeOfDay)"]
        
        if !genre.isEmpty {
            promptParts.append("Genre: \(genre)")
        }
        
        promptParts.append("Characters present: \(characters.joined(separator: ", "))")
        
        if !brief.isEmpty {
            promptParts.append("Context: \(brief)")
        }
        
        if let dialogue = dialogue, !dialogue.isEmpty {
            promptParts.append("\nScene Dialogue (for context - DO NOT include in description):")
            for line in dialogue {
                let character = line["character"] ?? "Unknown"
                let text = line["text"] ?? ""
                promptParts.append("\(character): \(text)")
            }
        }
        
        if let actions = actions, !actions.isEmpty {
            promptParts.append("\nExisting Actions:")
            for action in actions {
                let character = action["character"] ?? "Unknown"
                let actionText = action["action"] ?? ""
                promptParts.append("- \(character): \(actionText)")
            }
        }
        
        if let narrations = narrations, !narrations.isEmpty {
            promptParts.append("\nNarration notes:")
            for narration in narrations {
                promptParts.append("- \(narration)")
            }
        }
        
        promptParts.append("\nWrite a 2-3 paragraph scene description.")
        
        let prompt = promptParts.joined(separator: "\n")
        
        let request = TextGenerationRequest(
            prompt: prompt,
            provider: provider,
            maxTokens: 500,
            temperature: 0.8,
            systemPrompt: systemPrompt
        )
        
        let response = try await generateText(request)
        return response.text
    }
    
    /// Enhance dialogue with alternatives
    public func enhanceDialogue(
        characterName: String,
        dialogue: String,
        characterTraits: String = "",
        sceneContext: String = "",
        provider: AIProvider = .deepseek
    ) async throws -> [String] {
        
        let systemPrompt = """
        You are a professional screenwriter and dialogue coach. Generate alternative dialogue that maintains character voice while exploring different emotional tones and word choices.
        """
        
        var prompt = "Character: \(characterName)\n"
        if !characterTraits.isEmpty {
            prompt += "Traits: \(characterTraits)\n"
        }
        if !sceneContext.isEmpty {
            prompt += "Scene context: \(sceneContext)\n"
        }
        prompt += """
        
        Original dialogue: "\(dialogue)"
        
        Provide 3 alternative versions of this dialogue that:
        1. Maintain the character's voice and personality
        2. Explore different emotional approaches
        3. Are natural and cinematic
        
        Format each alternative on a new line starting with "1.", "2.", "3."
        """
        
        let request = TextGenerationRequest(
            prompt: prompt,
            provider: provider,
            maxTokens: 300,
            temperature: 0.9,
            systemPrompt: systemPrompt
        )
        
        let response = try await generateText(request)
        
        // Parse alternatives
        var alternatives: [String] = []
        for line in response.text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("1.") || trimmed.hasPrefix("2.") || trimmed.hasPrefix("3.") {
                var alt = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                alt = alt.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !alt.isEmpty {
                    alternatives.append(alt)
                }
            }
        }
        
        // Fallback if parsing fails
        if alternatives.isEmpty {
            alternatives = [response.text]
        }
        
        return Array(alternatives.prefix(3))
    }
    
    /// Generate character backstory
    public func generateCharacterBackstory(
        characterName: String,
        age: String = "",
        occupation: String = "",
        keyTraits: [String] = [],
        storyContext: String = "",
        provider: AIProvider = .deepseek
    ) async throws -> String {
        
        let systemPrompt = """
        You are a professional screenwriter specializing in character development. Create compelling, believable character backstories that inform their present-day motivations and behaviors.
        """
        
        let traitsStr = keyTraits.isEmpty ? "to be determined" : keyTraits.joined(separator: ", ")
        
        var prompt = "Create a character backstory for:\n\nName: \(characterName)\n"
        if !age.isEmpty {
            prompt += "Age: \(age)\n"
        }
        if !occupation.isEmpty {
            prompt += "Occupation: \(occupation)\n"
        }
        prompt += """
        Key traits: \(traitsStr)
        \(storyContext.isEmpty ? "" : "Story context: \(storyContext)\n")
        
        Write a 3-4 paragraph backstory that:
        1. Explains how they became who they are
        2. Includes a formative experience or trauma
        3. Establishes their primary motivation
        4. Connects to the present-day story
        """
        
        let request = TextGenerationRequest(
            prompt: prompt,
            provider: provider,
            maxTokens: 600,
            temperature: 0.8,
            systemPrompt: systemPrompt
        )
        
        let response = try await generateText(request)
        return response.text
    }
}
