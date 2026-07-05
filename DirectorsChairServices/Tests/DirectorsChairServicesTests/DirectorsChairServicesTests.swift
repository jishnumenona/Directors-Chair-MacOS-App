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

    // MARK: - Git Serializer Tests

    func testGitSerializerInitialization() {
        let serializer = GitSerializer()
        XCTAssertNotNil(serializer)
    }

    func testGitSerializerSchemaVersion() {
        XCTAssertEqual(GitSerializer.schemaVersion, "1.0")
        XCTAssertEqual(GitSerializer.serializerVersion, "1.0.0")
    }

    func testGitSerializerLFSExtensions() {
        let extensions = GitSerializer.lfsTrackedExtensions
        XCTAssertTrue(extensions.contains("*.png"))
        XCTAssertTrue(extensions.contains("*.mp4"))
        XCTAssertTrue(extensions.contains("*.mp3"))
        XCTAssertTrue(extensions.contains("*.psd"))
    }

    func testGitSerializationStats() {
        let stats = GitSerializationStats(
            characters: 5,
            scenes: 10,
            sequences: 3,
            beats: 15,
            locations: 4
        )

        XCTAssertEqual(stats.characters, 5)
        XCTAssertEqual(stats.scenes, 10)
        XCTAssertEqual(stats.sequences, 3)
        XCTAssertEqual(stats.beats, 15)
        XCTAssertEqual(stats.locations, 4)
        XCTAssertEqual(stats.totalFiles, 37) // 5+10+3+15+4+0+0+0+0
    }

    func testGitSerializationStatsDefaults() {
        let stats = GitSerializationStats()
        XCTAssertEqual(stats.characters, 0)
        XCTAssertEqual(stats.scenes, 0)
        XCTAssertEqual(stats.sequences, 0)
        XCTAssertEqual(stats.totalFiles, 0)
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

    // MARK: - Git Types Tests

    func testGitFileStatus() {
        XCTAssertEqual(GitFileStatus.added.rawValue, "A")
        XCTAssertEqual(GitFileStatus.modified.rawValue, "M")
        XCTAssertEqual(GitFileStatus.deleted.rawValue, "D")
        XCTAssertEqual(GitFileStatus.renamed.rawValue, "R")
    }

    func testGitFileChange() {
        let change = GitFileChange(path: "characters/john.json", status: .modified)
        XCTAssertEqual(change.path, "characters/john.json")
        XCTAssertEqual(change.status, .modified)
    }

    func testGitAuthor() {
        let author = GitAuthor(name: "John Doe", email: "john@example.com")
        XCTAssertEqual(author.name, "John Doe")
        XCTAssertEqual(author.email, "john@example.com")
    }

    func testGitRemote() {
        let fetchURL = URL(string: "https://git.example.com/project.git")!
        let pushURL = URL(string: "git@git.example.com:project.git")!
        let remote = GitRemote(name: "origin", fetchURL: fetchURL, pushURL: pushURL)

        XCTAssertEqual(remote.name, "origin")
        XCTAssertEqual(remote.fetchURL, fetchURL)
        XCTAssertEqual(remote.pushURL, pushURL)
    }

    func testGitBranchList() {
        let branches = GitBranchList(
            current: "feature/new-scene",
            local: ["main", "develop", "feature/new-scene"],
            remote: ["origin/main", "origin/develop"]
        )

        XCTAssertEqual(branches.current, "feature/new-scene")
        XCTAssertEqual(branches.local.count, 3)
        XCTAssertEqual(branches.remote.count, 2)
    }

    func testGitPullResult() {
        let result = GitPullResult(
            success: true,
            message: "Already up to date",
            commitsReceived: 0,
            conflicts: []
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.commitsReceived, 0)
        XCTAssertTrue(result.conflicts.isEmpty)
    }

    func testGitDiff() {
        let file = GitDiffFile(
            path: "scenes/scene-001.json",
            status: .modified,
            additions: 10,
            deletions: 5
        )

        let diff = GitDiff(files: [file], additions: 10, deletions: 5)

        XCTAssertEqual(diff.files.count, 1)
        XCTAssertEqual(diff.additions, 10)
        XCTAssertEqual(diff.deletions, 5)
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

    func testGitSerializationErrorDescriptions() {
        let error1 = GitSerializationError.serializationFailed("Invalid data")
        XCTAssertTrue(error1.errorDescription!.contains("serialization failed"))

        let error2 = GitSerializationError.missingManifest
        XCTAssertTrue(error2.errorDescription!.contains("manifest.json"))

        let error3 = GitSerializationError.unsupportedSchemaVersion("2.0")
        XCTAssertTrue(error3.errorDescription!.contains("2.0"))
    }

    func testRemoteRepositoryErrorDescriptions() {
        let error1 = RemoteRepositoryError.authenticationFailed
        XCTAssertTrue(error1.errorDescription!.contains("authentication"))

        let error2 = RemoteRepositoryError.repositoryNotFound("test-repo")
        XCTAssertTrue(error2.errorDescription!.contains("test-repo"))

        let error3 = RemoteRepositoryError.rateLimitExceeded
        XCTAssertTrue(error3.errorDescription!.contains("rate limit"))
    }
}
