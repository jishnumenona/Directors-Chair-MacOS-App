// DirectorsChairServices/Tests/DirectorsChairServicesTests/DirectorsChairServicesTests.swift

import XCTest
@testable import DirectorsChairServices
@testable import DirectorsChairCore

final class DirectorsChairServicesTests: XCTestCase {
    
    // MARK: - AI Service Client Tests
    
    func testAIServiceClientInitialization() {
        let client = AIServiceClient()
        XCTAssertNotNil(client)
    }
    
    func testAIProviderCases() {
        XCTAssertEqual(AIProvider.defaultTextProvider, .deepseek)
        XCTAssertEqual(AIProvider.defaultImageProvider, .googleImagen)
        XCTAssertEqual(AIProvider.openai.rawValue, "openai")
        XCTAssertEqual(AIProvider.anthropic.rawValue, "anthropic")
        XCTAssertEqual(AIProvider.google.rawValue, "google")
    }
    
    func testTextGenerationRequestDefaults() {
        let request = TextGenerationRequest(prompt: "Test prompt")
        XCTAssertEqual(request.prompt, "Test prompt")
        XCTAssertEqual(request.provider, .deepseek)
        XCTAssertEqual(request.maxTokens, 1000)
        XCTAssertEqual(request.temperature, 0.7)
        XCTAssertNil(request.systemPrompt)
    }
    
    func testImageGenerationRequestDefaults() {
        let request = ImageGenerationRequest(prompt: "Test image")
        XCTAssertEqual(request.prompt, "Test image")
        XCTAssertEqual(request.provider, .googleImagen)
        XCTAssertEqual(request.aspectRatio, "16:9")
        XCTAssertEqual(request.numberOfImages, 1)
    }
    
    // MARK: - TTS Service Tests
    
    @MainActor
    func testTTSServiceInitialization() {
        let service = TTSService()
        XCTAssertNotNil(service)
        XCTAssertFalse(service.isSpeaking)
    }
    
    @MainActor
    func testVoiceGender() {
        XCTAssertEqual(VoiceGender.male.rawValue, "male")
        XCTAssertEqual(VoiceGender.female.rawValue, "female")
        XCTAssertEqual(VoiceGender.neutral.rawValue, "neutral")
    }
    
    // MARK: - Background Task Manager Tests
    
    func testBackgroundTaskManagerInitialization() async {
        let manager = BackgroundTaskManager()
        let count = await manager.runningTasksCount()
        XCTAssertEqual(count, 0)
    }
    
    func testTaskStatus() {
        XCTAssertFalse(TaskStatus.pending.isFinished)
        XCTAssertFalse(TaskStatus.running.isFinished)
        XCTAssertTrue(TaskStatus.completed.isFinished)
        XCTAssertTrue(TaskStatus.cancelled.isFinished)
        XCTAssertTrue(TaskStatus.failed("error").isFinished)
    }
    
    func testTaskPriority() {
        XCTAssertLessThan(TaskPriority.low, TaskPriority.normal)
        XCTAssertLessThan(TaskPriority.normal, TaskPriority.high)
        XCTAssertLessThan(TaskPriority.high, TaskPriority.critical)
    }
    
    func testBackgroundTaskSubmission() async {
        let manager = BackgroundTaskManager()
        
        let taskId = await manager.submit(name: "Test Task") {
            return "Success"
        }
        
        XCTAssertNotNil(taskId)
        
        // Wait for task to complete
        let task = await manager.waitForTask(taskId)
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.status, .completed)
    }
    
    // MARK: - Character Traits Tests
    
    func testCharacterTraitsDefinition() {
        XCTAssertEqual(CharacterTraits.allTraits.count, 25)
        XCTAssertTrue(CharacterTraits.allTraits.contains("confidence"))
        XCTAssertTrue(CharacterTraits.allTraits.contains("empathy"))
        XCTAssertTrue(CharacterTraits.allTraits.contains("wisdom"))
    }
    
    func testCharacterTraitCategories() {
        XCTAssertEqual(CharacterTraits.categories.count, 5)
        XCTAssertNotNil(CharacterTraits.categories["Core Traits"])
        XCTAssertNotNil(CharacterTraits.categories["Social Traits"])
        XCTAssertNotNil(CharacterTraits.categories["Emotional Traits"])
    }
    
    // MARK: - Character Analysis Result Tests
    
    func testCharacterAnalysisResultDefaults() {
        let result = CharacterAnalysisResult()
        XCTAssertTrue(result.traitScores.isEmpty)
        XCTAssertEqual(result.reasoning, "")
        XCTAssertEqual(result.confidenceScore, 0)
        XCTAssertEqual(result.archetype, "")
    }
}
