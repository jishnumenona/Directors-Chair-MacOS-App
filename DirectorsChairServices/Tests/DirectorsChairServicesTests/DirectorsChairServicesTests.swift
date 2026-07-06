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
        // Model uses the OCEAN taxonomy: 5 categories x 5 sub-traits = 25.
        XCTAssertEqual(CharacterTraits.allTraits.count, 25)
        XCTAssertTrue(CharacterTraits.allTraits.contains("Creativity"))
        XCTAssertTrue(CharacterTraits.allTraits.contains("Empathy"))
        XCTAssertTrue(CharacterTraits.allTraits.contains("Anxiety"))
    }

    func testCharacterTraitCategories() {
        // OCEAN dimensions.
        XCTAssertEqual(CharacterTraits.categories.count, 5)
        XCTAssertNotNil(CharacterTraits.categories["Openness"])
        XCTAssertNotNil(CharacterTraits.categories["Conscientiousness"])
        XCTAssertNotNil(CharacterTraits.categories["Neuroticism"])
    }
    
    // MARK: - Character Analysis Result Tests

    func testCharacterAnalysisResultDefaults() {
        let result = CharacterAnalysisResult()
        XCTAssertTrue(result.traitScores.isEmpty)
        XCTAssertEqual(result.reasoning, "")
        XCTAssertEqual(result.confidenceScore, 0)
        XCTAssertEqual(result.archetype, "")
    }

    // MARK: - Gitea Client Tests

    func testGiteaClientInitialization() async {
        let client = GiteaClient(baseURL: URL(string: "https://git.example.com")!)
        XCTAssertNotNil(client)
    }

    func testGiteaClientConnectionTest() async {
        // Test with localhost (should fail gracefully)
        let client = GiteaClient(baseURL: URL(string: "http://localhost:9999")!)
        let connected = await client.testConnection()
        XCTAssertFalse(connected) // No server running
    }

    func testCreateGiteaClientConvenience() {
        let client = createGiteaClient()
        XCTAssertNotNil(client)
    }

    func testCollaboratorPermission() {
        XCTAssertEqual(CollaboratorPermission.read.rawValue, "read")
        XCTAssertEqual(CollaboratorPermission.write.rawValue, "write")
        XCTAssertEqual(CollaboratorPermission.admin.rawValue, "admin")
    }

    // MARK: - Remote Types Tests

    func testRemoteUser() {
        let user = RemoteUser(
            id: 1,
            username: "johndoe",
            email: "john@example.com",
            fullName: "John Doe",
            avatarURL: URL(string: "https://git.example.com/avatar/1")
        )

        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.username, "johndoe")
        XCTAssertEqual(user.fullName, "John Doe")
    }

    func testRemoteBranch() {
        let branch = RemoteBranch(
            name: "feature/new-scene",
            commitHash: "abc123def456",
            isProtected: false
        )

        XCTAssertEqual(branch.name, "feature/new-scene")
        XCTAssertEqual(branch.commitHash, "abc123def456")
        XCTAssertFalse(branch.isProtected)
    }

    // MARK: - Git Error Tests

    func testRemoteRepositoryErrorDescriptions() {
        let error1 = RemoteRepositoryError.authenticationFailed
        XCTAssertTrue(error1.errorDescription!.contains("authentication"))

        let error2 = RemoteRepositoryError.repositoryNotFound("test-repo")
        XCTAssertTrue(error2.errorDescription!.contains("test-repo"))

        let error3 = RemoteRepositoryError.rateLimitExceeded
        XCTAssertTrue(error3.errorDescription!.contains("rate limit"))
    }
}
