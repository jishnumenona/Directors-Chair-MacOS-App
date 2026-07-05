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
    case googleVeo = "google_veo"

    /// Default provider for text generation
    public static var defaultTextProvider: AIProvider { .deepseek }

    /// Default provider for image generation
    public static var defaultImageProvider: AIProvider { .googleImagen }

    /// Default provider for video generation
    public static var defaultVideoProvider: AIProvider { .googleVeo }
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
    case authenticationRequired
    case quotaExceeded(String)
    case rateLimited(retryAfter: Int)

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
        case .authenticationRequired:
            return "Your session has expired. Please sign out and sign back in from the account menu to continue using AI features."
        case .quotaExceeded(let detail):
            return "Usage quota exceeded: \(detail)"
        case .rateLimited(let retryAfter):
            return "Rate limited. Please wait \(retryAfter) seconds."
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

/// A labeled reference image sent alongside the generation prompt.
public struct ReferenceImage: Sendable {
    public var base64: String
    public var mimeType: String
    public var label: String

    public init(base64: String, mimeType: String = "image/png", label: String) {
        self.base64 = base64
        self.mimeType = mimeType
        self.label = label
    }
}

/// Request for image generation
public struct ImageGenerationRequest: Sendable {
    public var prompt: String
    public var provider: AIProvider
    public var model: String?
    public var aspectRatio: String
    public var numberOfImages: Int
    public var referenceImageBase64: String?
    public var referenceMimeType: String?
    /// Multiple labeled reference images (location, character, costume).
    public var referenceImages: [ReferenceImage]?

    public init(
        prompt: String,
        provider: AIProvider = .googleImagen,
        model: String? = nil,
        aspectRatio: String = "16:9",
        numberOfImages: Int = 1,
        referenceImageBase64: String? = nil,
        referenceMimeType: String? = nil,
        referenceImages: [ReferenceImage]? = nil
    ) {
        self.prompt = prompt
        self.provider = provider
        self.model = model
        self.aspectRatio = aspectRatio
        self.numberOfImages = numberOfImages
        self.referenceImageBase64 = referenceImageBase64
        self.referenceMimeType = referenceMimeType
        self.referenceImages = referenceImages
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

// MARK: - Video Generation Request

/// Request for video generation
public struct VideoGenerationRequest: Sendable {
    public var prompt: String
    public var provider: AIProvider
    public var durationSeconds: Double
    public var quality: String              // "Standard", "High", "Ultra"
    public var aspectRatio: String           // "16:9", "9:16", "1:1"
    public var fps: Int
    public var cameraMotion: String          // "Static", "Pan", "Zoom", "Tracking"
    public var subjectMotion: String         // "Static", "Walking", "Running"
    public var negativePrompt: String?
    public var startFrameBase64: String?     // Base64 of start keyframe
    public var endFrameBase64: String?       // Base64 of end keyframe
    public var shotId: String?
    public var projectId: String?

    public init(
        prompt: String,
        provider: AIProvider = .googleVeo,
        durationSeconds: Double = 5.0,
        quality: String = "High",
        aspectRatio: String = "16:9",
        fps: Int = 24,
        cameraMotion: String = "Static",
        subjectMotion: String = "Static",
        negativePrompt: String? = nil,
        startFrameBase64: String? = nil,
        endFrameBase64: String? = nil,
        shotId: String? = nil,
        projectId: String? = nil
    ) {
        self.prompt = prompt
        self.provider = provider
        self.durationSeconds = durationSeconds
        self.quality = quality
        self.aspectRatio = aspectRatio
        self.fps = fps
        self.cameraMotion = cameraMotion
        self.subjectMotion = subjectMotion
        self.negativePrompt = negativePrompt
        self.startFrameBase64 = startFrameBase64
        self.endFrameBase64 = endFrameBase64
        self.shotId = shotId
        self.projectId = projectId
    }
}

// MARK: - Video Generation Response

/// Response from video generation
public struct VideoGenerationResponse: Sendable {
    public var jobId: String
    public var status: VideoJobStatus
    public var videoURL: String?
    public var thumbnailURL: String?
    public var progress: Double?             // 0-100
    public var estimatedTimeSeconds: Int?
    public var errorMessage: String?
    public var cost: Double?

    public init(
        jobId: String,
        status: VideoJobStatus = .pending,
        videoURL: String? = nil,
        thumbnailURL: String? = nil,
        progress: Double? = nil,
        estimatedTimeSeconds: Int? = nil,
        errorMessage: String? = nil,
        cost: Double? = nil
    ) {
        self.jobId = jobId
        self.status = status
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.progress = progress
        self.estimatedTimeSeconds = estimatedTimeSeconds
        self.errorMessage = errorMessage
        self.cost = cost
    }
}

/// Video generation job status
public enum VideoJobStatus: String, Sendable {
    case pending
    case processing
    case completed
    case failed
}

// MARK: - Speech Generation Request

/// Request for speech generation via TTS
public struct SpeechGenerationRequest: Sendable {
    public var text: String
    public var provider: AIProvider
    public var voiceName: String?
    public var emotion: String?
    public var characterName: String?
    public var voiceTone: String?
    public var voicePersonality: String?
    public var voicePace: String?
    public var voiceAccent: String?
    public var voiceAge: String?

    public init(
        text: String,
        provider: AIProvider = .google,
        voiceName: String? = nil,
        emotion: String? = nil,
        characterName: String? = nil,
        voiceTone: String? = nil,
        voicePersonality: String? = nil,
        voicePace: String? = nil,
        voiceAccent: String? = nil,
        voiceAge: String? = nil
    ) {
        self.text = text
        self.provider = provider
        self.voiceName = voiceName
        self.emotion = emotion
        self.characterName = characterName
        self.voiceTone = voiceTone
        self.voicePersonality = voicePersonality
        self.voicePace = voicePace
        self.voiceAccent = voiceAccent
        self.voiceAge = voiceAge
    }

    /// Compose all structured voice fields into a single natural language style instruction
    public var composedStyleInstruction: String? {
        var parts: [String] = []
        if let tone = voiceTone, !tone.isEmpty { parts.append("in a \(tone) tone") }
        if let personality = voicePersonality, !personality.isEmpty { parts.append("\(personality)") }
        if let pace = voicePace, !pace.isEmpty { parts.append("at a \(pace) pace") }
        if let accent = voiceAccent, !accent.isEmpty { parts.append("with a \(accent) accent") }
        if let age = voiceAge, !age.isEmpty { parts.append("like a \(age) person") }
        if let extra = emotion, !extra.isEmpty { parts.append(extra) }
        return parts.isEmpty ? nil : "Speak " + parts.joined(separator: ", ")
    }
}

// MARK: - Speech Generation Response

/// Response from speech generation
public struct SpeechGenerationResponse: Sendable {
    public var audioData: Data
    public var mimeType: String

    public init(audioData: Data, mimeType: String) {
        self.audioData = audioData
        self.mimeType = mimeType
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

    /// Auth token for authenticated API requests.
    /// Set by AuthManager on login/refresh/logout.
    private var authToken: String?

    /// Optional closure that provides the current access token dynamically.
    /// When set, this is called before each request to get the freshest token,
    /// so token refreshes in AuthManager are automatically picked up.
    public var tokenProvider: (() -> String?)?

    /// Optional async closure that attempts to refresh the auth token.
    /// Called automatically when a 401 is received. Should refresh the token
    /// and return the new access token, or nil if refresh failed.
    public var tokenRefresher: (() async -> String?)?

    /// Shared instance with default configuration
    public static let shared = AIServiceClient()

    // MARK: - Initialization

    /// Initialize with custom configuration
    /// - Parameters:
    ///   - baseURL: AI Proxy server URL (default: https://directorschair.app/ai)
    ///   - timeout: Request timeout in seconds (default: 120)
    ///   - projectName: Current project name for usage tracking
    public init(
        baseURL: String = "https://directorschair.app/ai",
        timeout: TimeInterval = 120,
        projectName: String = ""
    ) {
        // baseURL can come from a user-editable preference, so fall back to the
        // known-good default rather than force-unwrapping (a bad string would
        // otherwise crash the app on first AI call).
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.baseURL = URL(string: trimmed) ?? URL(string: "https://directorschair.app/ai")!
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

    /// Update the auth token (called by AuthManager on login/refresh/logout).
    public func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    /// Apply auth header to a URLRequest if a token is available.
    /// Prefers the dynamic tokenProvider over the static authToken.
    private func applyAuthHeader(to request: inout URLRequest) {
        let token = tokenProvider?() ?? authToken
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Perform a URLRequest with automatic token refresh on 401.
    /// If the first attempt returns 401 and a tokenRefresher is available,
    /// refreshes the token, updates the auth header, and retries once.
    private func performWithAutoRefresh(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var req = request

        let (data, response) = try await session.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse("Not an HTTP response")
        }

        if httpResponse.statusCode == 401, let refresher = tokenRefresher {
            // Attempt token refresh
            if let newToken = await refresher() {
                self.authToken = newToken
                req.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await session.data(for: req)
                guard let retryHttp = retryResponse as? HTTPURLResponse else {
                    throw AIClientError.invalidResponse("Not an HTTP response")
                }
                return (retryData, retryHttp)
            }
        }

        return (data, httpResponse)
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
        applyAuthHeader(to: &urlRequest)

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

        let (data, httpResponse) = try await performWithAutoRefresh(urlRequest)

        // Handle auth/quota/rate-limit errors
        switch httpResponse.statusCode {
        case 401:
            throw AIClientError.authenticationRequired
        case 429:
            let retryAfter = Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            if errorBody.contains("quota") {
                throw AIClientError.quotaExceeded(errorBody)
            }
            throw AIClientError.rateLimited(retryAfter: retryAfter)
        case 200:
            break
        default:
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
        
        let textResponse = TextGenerationResponse(
            text: text,
            provider: request.provider,
            model: model,
            usage: usage
        )

        // Track usage
        let finalUsage = usage
        let finalProvider = request.provider.rawValue
        let finalModel = model
        await MainActor.run {
            AIUsageTracker.shared.recordTextUsage(
                provider: finalProvider,
                model: finalModel,
                promptTokens: finalUsage.promptTokens,
                completionTokens: finalUsage.completionTokens
            )
        }

        return textResponse
    }
    
    // MARK: - Image Generation
    
    /// Generate images using AI
    public func generateImage(_ request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let url = baseURL.appendingPathComponent("generate/image")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthHeader(to: &urlRequest)

        var body: [String: Any] = [
            "prompt": request.prompt,
            "provider": request.provider.rawValue,
            "aspect_ratio": request.aspectRatio,
            "n": request.numberOfImages
        ]
        
        if let model = request.model {
            body["model"] = model
        }
        if let refs = request.referenceImages, !refs.isEmpty {
            body["reference_images"] = refs.map { ref in
                ["base64": ref.base64, "mime_type": ref.mimeType, "label": ref.label]
            }
        } else if let refImage = request.referenceImageBase64 {
            body["reference_image_base64"] = refImage
            body["reference_mime_type"] = request.referenceMimeType ?? "image/png"
        }
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await performWithAutoRefresh(urlRequest)

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw AIClientError.authenticationRequired
            }
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
        
        let imageResponse = ImageGenerationResponse(
            images: images,
            provider: request.provider,
            model: model
        )

        // Track usage
        let imageCount = images.count
        let finalProvider = request.provider.rawValue
        let finalModel = model
        await MainActor.run {
            AIUsageTracker.shared.recordImageUsage(
                provider: finalProvider,
                model: finalModel,
                imageCount: imageCount
            )
        }

        return imageResponse
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
    
    // MARK: - Video Generation

    /// Submit a video generation job
    public func submitVideoGeneration(_ request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        let url = baseURL.appendingPathComponent("generate/video")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthHeader(to: &urlRequest)

        var body: [String: Any] = [
            "prompt": request.prompt,
            "provider": request.provider.rawValue,
            "duration_seconds": request.durationSeconds,
            "quality": request.quality,
            "aspect_ratio": request.aspectRatio,
            "fps": request.fps,
            "camera_motion": request.cameraMotion,
            "subject_motion": request.subjectMotion
        ]

        if let negativePrompt = request.negativePrompt {
            body["negative_prompt"] = negativePrompt
        }
        if let startFrame = request.startFrameBase64 {
            body["start_frame_base64"] = startFrame
        }
        if let endFrame = request.endFrameBase64 {
            body["end_frame_base64"] = endFrame
        }
        if let shotId = request.shotId {
            body["shot_id"] = shotId
        }
        if let projectId = request.projectId {
            body["project_id"] = projectId
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

        // Server returns video fields at top level (not wrapped in success/data)
        if let errorMsg = json["error_message"] as? String, !errorMsg.isEmpty {
            throw AIClientError.generationFailed(errorMsg)
        }

        return VideoGenerationResponse(
            jobId: json["job_id"] as? String ?? "",
            status: VideoJobStatus(rawValue: json["status"] as? String ?? "pending") ?? .pending,
            videoURL: json["video_url"] as? String,
            thumbnailURL: json["thumbnail_url"] as? String,
            progress: json["progress"] as? Double,
            estimatedTimeSeconds: json["estimated_time_seconds"] as? Int,
            errorMessage: json["error_message"] as? String,
            cost: json["cost"] as? Double
        )
    }

    /// Poll video generation status
    public func checkVideoStatus(jobId: String, provider: AIProvider) async throws -> VideoGenerationResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("generate/video/\(jobId)/status"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "provider", value: provider.rawValue)]

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthHeader(to: &urlRequest)

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

        return VideoGenerationResponse(
            jobId: json["job_id"] as? String ?? jobId,
            status: VideoJobStatus(rawValue: json["status"] as? String ?? "pending") ?? .pending,
            videoURL: json["video_url"] as? String,
            thumbnailURL: json["thumbnail_url"] as? String,
            progress: json["progress"] as? Double,
            estimatedTimeSeconds: json["estimated_time_seconds"] as? Int,
            errorMessage: json["error_message"] as? String,
            cost: json["cost"] as? Double
        )
    }

    /// Cancel a video generation job
    public func cancelVideoGeneration(jobId: String, provider: AIProvider) async throws -> Bool {
        var components = URLComponents(url: baseURL.appendingPathComponent("generate/video/\(jobId)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "provider", value: provider.rawValue)]

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthHeader(to: &urlRequest)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse("Not an HTTP response")
        }

        return httpResponse.statusCode == 200
    }

    /// Download completed video to local path via proxy
    public func downloadVideo(jobId: String, provider: AIProvider, to localPath: URL) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("generate/video/\(jobId)/download"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "provider", value: provider.rawValue)]

        guard let url = components.url else {
            throw AIClientError.invalidConfiguration("Invalid download URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 120
        applyAuthHeader(to: &urlRequest)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIClientError.requestFailed("Failed to download video: \(errorText)")
        }

        try FileManager.default.createDirectory(at: localPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: localPath)
    }

    // MARK: - Speech Generation

    /// Generate speech audio from text using TTS
    public func generateSpeech(_ request: SpeechGenerationRequest) async throws -> SpeechGenerationResponse {
        let url = baseURL.appendingPathComponent("generate/speech")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeader(to: &urlRequest)

        var body: [String: Any] = [
            "text": request.text,
            "provider": request.provider.rawValue
        ]

        if let voiceName = request.voiceName {
            body["voice_name"] = voiceName
        }
        // Send composed style instruction as emotion, falling back to raw emotion
        if let composed = request.composedStyleInstruction {
            body["emotion"] = composed
        } else if let emotion = request.emotion {
            body["emotion"] = emotion
        }
        if let characterName = request.characterName {
            body["character_name"] = characterName
        }
        // Also send structured fields for server-side fallback composition
        if let tone = request.voiceTone { body["voice_tone"] = tone }
        if let personality = request.voicePersonality { body["voice_personality"] = personality }
        if let pace = request.voicePace { body["voice_pace"] = pace }
        if let accent = request.voiceAccent { body["voice_accent"] = accent }
        if let age = request.voiceAge { body["voice_age"] = age }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await performWithAutoRefresh(urlRequest)

        switch httpResponse.statusCode {
        case 401:
            throw AIClientError.authenticationRequired
        case 429:
            let retryAfter = Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            throw AIClientError.rateLimited(retryAfter: retryAfter)
        case 200:
            break
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIClientError.requestFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        let mimeType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "audio/wav"
        return SpeechGenerationResponse(audioData: data, mimeType: mimeType)
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
