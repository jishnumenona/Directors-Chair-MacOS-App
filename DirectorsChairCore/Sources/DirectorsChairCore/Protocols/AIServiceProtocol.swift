// DirectorsChairCore/Sources/DirectorsChairCore/Protocols/AIServiceProtocol.swift
//
// Protocol interfaces for AI service providers (Module 2)

import Foundation

// MARK: - AIServiceProtocol

/// Protocol for AI service providers
/// Implemented by Module 2: DirectorsChairServices
public protocol AIServiceProtocol: Sendable {
    /// Generate an image from a text prompt
    /// - Parameters:
    ///   - prompt: Text description of the image to generate
    ///   - options: Generation options (size, style, etc.)
    ///   - progress: Optional progress callback
    /// - Returns: URL to the generated image
    func generateImage(
        prompt: String,
        options: ImageGenerationOptions,
        progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> URL

    /// Generate character image with specific attributes
    /// - Parameters:
    ///   - character: Character model with traits and appearance
    ///   - filmStyle: Optional film style to apply
    ///   - progress: Progress callback
    /// - Returns: URL to generated character image
    func generateCharacterImage(
        character: Character,
        filmStyle: FilmStyle?,
        progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> URL

    /// Generate scene image/storyboard frame
    /// - Parameters:
    ///   - scene: Scene model with description
    ///   - characters: Characters in the scene
    ///   - filmStyle: Film style to apply
    ///   - progress: Progress callback
    /// - Returns: URL to generated scene image
    func generateSceneImage(
        scene: Scene,
        characters: [Character],
        filmStyle: FilmStyle?,
        progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> URL

    /// Generate dialogue using AI
    /// - Parameters:
    ///   - character: Character speaking
    ///   - context: Scene context
    ///   - previousDialogues: Previous dialogue for context
    ///   - tone: Desired tone (dramatic, comedic, etc.)
    /// - Returns: Generated dialogue text
    func generateDialogue(
        character: Character,
        context: String,
        previousDialogues: [Dialogue],
        tone: String?
    ) async throws -> String

    /// Generate voiceover audio from text
    /// - Parameters:
    ///   - text: Text to convert to speech
    ///   - voice: Voice characteristics
    ///   - options: Audio generation options
    ///   - progress: Progress callback
    /// - Returns: URL to generated audio file
    func generateVoiceover(
        text: String,
        voice: VoiceOptions,
        options: AudioGenerationOptions,
        progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> URL

    /// Generate video from scene
    /// - Parameters:
    ///   - scene: Scene to generate
    ///   - duration: Target duration in seconds
    ///   - options: Video generation options
    ///   - progress: Progress callback
    /// - Returns: URL to generated video
    func generateVideo(
        scene: Scene,
        duration: TimeInterval,
        options: VideoGenerationOptions,
        progress: (@Sendable (Double, String) -> Void)?
    ) async throws -> URL

    /// Estimate cost for AI generation
    /// - Parameters:
    ///   - type: Type of generation
    ///   - parameters: Generation parameters
    /// - Returns: Estimated cost in specified currency
    func estimateCost(
        type: AIGenerationType,
        parameters: [String: Any]
    ) async throws -> Decimal
}

// MARK: - Generation Options

/// Options for image generation
public struct ImageGenerationOptions: Sendable {
    public var size: ImageSize
    public var quality: ImageQuality
    public var style: String?
    public var negativePrompt: String?
    public var seed: Int?

    public init(
        size: ImageSize = .medium,
        quality: ImageQuality = .standard,
        style: String? = nil,
        negativePrompt: String? = nil,
        seed: Int? = nil
    ) {
        self.size = size
        self.quality = quality
        self.style = style
        self.negativePrompt = negativePrompt
        self.seed = seed
    }
}

/// Image size options
public enum ImageSize: String, Sendable {
    case small = "512x512"
    case medium = "1024x1024"
    case large = "2048x2048"
    case portrait = "1024x1792"
    case landscape = "1792x1024"
}

/// Image quality options
public enum ImageQuality: String, Sendable {
    case draft
    case standard
    case high
}

/// Voice options for TTS
public struct VoiceOptions: Sendable {
    public var voiceId: String?
    public var gender: String?
    public var age: String?
    public var accent: String?
    public var emotion: String?

    public init(
        voiceId: String? = nil,
        gender: String? = nil,
        age: String? = nil,
        accent: String? = nil,
        emotion: String? = nil
    ) {
        self.voiceId = voiceId
        self.gender = gender
        self.age = age
        self.accent = accent
        self.emotion = emotion
    }
}

/// Audio generation options
public struct AudioGenerationOptions: Sendable {
    public var format: AudioFormat
    public var sampleRate: Int
    public var speed: Double

    public init(
        format: AudioFormat = .mp3,
        sampleRate: Int = 44100,
        speed: Double = 1.0
    ) {
        self.format = format
        self.sampleRate = sampleRate
        self.speed = speed
    }
}

/// Audio format options
public enum AudioFormat: String, Sendable {
    case mp3
    case wav
    case aac
}

/// Video generation options
public struct VideoGenerationOptions: Sendable {
    public var resolution: VideoResolution
    public var frameRate: Int
    public var format: VideoFormat

    public init(
        resolution: VideoResolution = .hd1080,
        frameRate: Int = 30,
        format: VideoFormat = .mp4
    ) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.format = format
    }
}

/// Video resolution options
public enum VideoResolution: String, Sendable {
    case hd720 = "1280x720"
    case hd1080 = "1920x1080"
    case uhd4k = "3840x2160"
}

/// Video format options
public enum VideoFormat: String, Sendable {
    case mp4
    case mov
    case webm
}

// MARK: - AI Service Errors

/// Errors that can occur during AI service operations
public enum AIServiceError: LocalizedError, Sendable {
    case authenticationFailed
    case invalidPrompt(String)
    case generationFailed(String)
    case quotaExceeded
    case unsupportedOperation
    case networkError(Error)
    case invalidParameters(String)

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "AI service authentication failed"
        case .invalidPrompt(let reason):
            return "Invalid prompt: \(reason)"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        case .quotaExceeded:
            return "AI service quota exceeded"
        case .unsupportedOperation:
            return "Operation not supported by AI service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidParameters(let reason):
            return "Invalid parameters: \(reason)"
        }
    }
}
