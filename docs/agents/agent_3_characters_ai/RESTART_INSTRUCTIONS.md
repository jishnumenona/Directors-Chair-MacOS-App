# Agent 3 Restart Instructions - Characters & AI Services Lead

## Your Role
You are **Agent 3: Characters & AI Services Lead** for the DirectorsChair Swift migration project. You are responsible for implementing AI service integrations and export functionality.

## CRITICAL: You Are Behind Schedule

**Your Phase 2 should have started in Week 3 (NOW).** Your status document shows you're "Waiting on Agent 1" but **Agent 1 completed Phase 1 days ago**. All the protocols and data models you need are ready.

## Project Overview

**DirectorsChair** is a film pre-production application being migrated from Python/PyQt to Swift/SwiftUI. The project uses a 5-agent parallel development model.

- **Timeline**: 18 weeks (currently Week 3)
- **Your Packages**: DirectorsChairServices + DirectorsChairExports
- **Your Timeline**: Phase 2 (Weeks 3-5) - You should be starting NOW

## Current Project Status

### Phase 1: Foundation - ✅ COMPLETE
**Lead**: Agent 1 (Architect)
**Status**: All gates passed

**Delivered**:
- ✅ DirectorsChairCore package (27 data models)
- ✅ JSON persistence layer (ProjectPersistence, DebouncedSaveManager)
- ✅ EventBus system (40+ event types)
- ✅ **All protocol interfaces YOU need are defined**:
  - `AIServiceProtocol` - Image, character, scene, dialogue, voiceover, video generation
  - `ExportServiceProtocol` - PDF, FDX, Fountain, video exports
  - `ProductionServiceProtocol` - Script analysis, scheduling, budget
  - `GitServiceProtocol` - Version control integration
- ✅ 24/24 tests passing
- ✅ Python JSON compatibility validated

**Location**: `DirectorsChairCore/Sources/DirectorsChairCore/Protocols/`

### Other Agents - AHEAD OF YOU!

- **Agent 2**: Phase 4 complete (3 weeks early), now working on Phase 6
- **Agent 4**: Phase 3 at 95% complete (Timeline Canvas built and tested)
- **Agent 5**: Testing infrastructure ready

**You are the blocker.** Other agents need your services to complete their integrations.

## Phase 2: Services Layer - YOUR MISSION

### Timeline: Week 3-5 (START NOW → Complete by end of Week 5)

### Module 1: DirectorsChairServices (Priority 1)

**Package**: `DirectorsChairServices`
**Git Branch**: `agent-3-ai` (create this)

#### Component 1: AIServiceClient (~800 lines)
**File**: `DirectorsChairServices/Sources/DirectorsChairServices/AI/AIServiceClient.swift`

**Features**:
- Multi-provider support (OpenAI, Anthropic, Google, Stability AI)
- Implement `AIServiceProtocol` from DirectorsChairCore
- Image generation (character portraits, location images, storyboards)
- Character trait analysis from dialogue
- Scene description generation
- Dialogue generation
- Voiceover generation (TTS)
- Video generation (future)
- Cost estimation
- Progress tracking with EventBus
- Error handling and retries

**Protocol to Implement** (already defined in DirectorsChairCore):
```swift
// DirectorsChairCore/Sources/DirectorsChairCore/Protocols/AIServiceProtocol.swift
public protocol AIServiceProtocol: Sendable {
    func generateImage(prompt: String, options: ImageGenerationOptions) async throws -> Data
    func analyzeCharacterTraits(dialogue: [String]) async throws -> [String: Double]
    func generateSceneDescription(scene: Scene) async throws -> String
    func generateDialogue(character: Character, context: String, options: DialogueOptions) async throws -> String
    func generateVoiceover(text: String, voice: VoiceOptions) async throws -> Data
    func generateVideo(script: String, options: VideoGenerationOptions) async throws -> URL
    func estimateCost(operation: AIOperation) async throws -> Decimal
}
```

**Python Reference**: `DirectorsChair-Python/services/ai_service.py` (~1,200 lines)

**Implementation Steps**:
1. Create Swift package structure for DirectorsChairServices
2. Add dependencies (OpenAI, Anthropic, Google SDKs)
3. Implement provider abstraction layer
4. Implement AIServiceClient conforming to AIServiceProtocol
5. Add EventBus integration for progress tracking
6. Implement cost estimation
7. Add comprehensive error handling
8. Write unit tests

#### Component 2: TTSService (~400 lines)
**File**: `DirectorsChairServices/Sources/DirectorsChairServices/TTS/TTSService.swift`

**Features**:
- macOS AVFoundation integration
- Voice selection (50+ system voices)
- Rate, pitch, volume control
- Audio file export (WAV, M4A)
- Progress callbacks
- Background synthesis

**Python Reference**: `DirectorsChair-Python/services/tts_service.py` (~600 lines)

#### Component 3: BackgroundTaskManager (~300 lines)
**File**: `DirectorsChairServices/Sources/DirectorsChairServices/Tasks/BackgroundTaskManager.swift`

**Features**:
- Thread-safe task queue
- Priority scheduling
- Cancellation support
- Progress tracking
- Completion callbacks
- EventBus integration

**Python Reference**: `DirectorsChair-Python/services/task_manager.py` (~400 lines)

#### Component 4: ImageUtilities (~200 lines)
**File**: `DirectorsChairServices/Sources/DirectorsChairServices/Utils/ImageUtilities.swift`

**Features**:
- Image loading and caching
- Thumbnail generation
- Format conversion
- Compression
- Base64 encoding/decoding

---

### Module 2: DirectorsChairExports (Priority 2)

**Package**: `DirectorsChairExports` (use same branch: `agent-3-ai`)

#### Component 1: PDFExportService (~600 lines)
**File**: `DirectorsChairExports/Sources/DirectorsChairExports/PDF/PDFExportService.swift`

**Features**:
- Screenplay PDF export (industry standard formatting)
- Character sheets PDF
- Call sheets PDF
- Budget reports PDF
- Custom fonts and styling

**Protocol to Implement**:
```swift
// DirectorsChairCore/Sources/DirectorsChairCore/Protocols/ExportServiceProtocol.swift
public protocol ExportServiceProtocol: Sendable {
    func exportPDF(project: Project, options: ExportOptions) async throws -> URL
    func exportFDX(project: Project) async throws -> URL
    func exportFountain(project: Project) async throws -> URL
    func exportHTML(project: Project, template: String) async throws -> URL
    func exportVideo(project: Project, options: VideoExportOptions) async throws -> URL
}
```

**Python Reference**: `DirectorsChair-Python/exports/pdf_export.py` (~900 lines)

#### Component 2: FDX/Fountain Exporters (~400 lines)
**File**: `DirectorsChairExports/Sources/DirectorsChairExports/Screenplay/`

**Features**:
- Final Draft (FDX) XML export
- Fountain markdown export
- Script parsing and validation

**Python Reference**:
- `DirectorsChair-Python/exports/fdx_export.py` (~500 lines)
- `DirectorsChair-Python/exports/fountain_export.py` (~300 lines)

#### Component 3: HTMLExportService (~300 lines)
**File**: `DirectorsChairExports/Sources/DirectorsChairExports/HTML/HTMLExportService.swift`

**Features**:
- HTML screenplay export
- Character gallery export
- Production reports export
- Template support (Jinja2 → Swift Templates)

**Python Reference**: `DirectorsChair-Python/exports/html_export.py` (~400 lines)

---

## Implementation Priority Order

### Week 3 (Current Week) - AI Services Foundation
1. Create DirectorsChairServices package structure
2. Add OpenAI/Anthropic/Google SDK dependencies
3. Implement AIServiceClient (multi-provider)
4. Implement BackgroundTaskManager
5. Write unit tests for AI client

### Week 4 - TTS & Image Utilities
1. Implement TTSService (AVFoundation)
2. Implement ImageUtilities
3. Integration testing with DirectorsChairCore
4. Write unit tests

### Week 5 - Export Services
1. Create DirectorsChairExports package structure
2. Implement PDFExportService
3. Implement FDX/Fountain exporters
4. Implement HTMLExportService
5. Write unit tests
6. Phase 2 Gate validation

---

## Immediate Action Checklist

Execute these steps NOW:

- [ ] Read docs/AGENT_ONBOARDING.md (complete project context)
- [ ] Read docs/PROJECT_STATUS.md (overall status)
- [ ] Read docs/agents/agent_3_characters_ai/INSTRUCTIONS.md (your detailed instructions)
- [ ] Read DirectorsChairCore/Sources/DirectorsChairCore/Protocols/AIServiceProtocol.swift
- [ ] Read DirectorsChairCore/Sources/DirectorsChairCore/Protocols/ExportServiceProtocol.swift
- [ ] Read Python reference: `DirectorsChair-Python/services/ai_service.py`
- [ ] Create Git branch: `git checkout -b agent-3-ai`
- [ ] Create DirectorsChairServices package structure:
  ```bash
  cd DirectorsChairServices
  # Package.swift should already exist (created by Agent 1)
  mkdir -p Sources/DirectorsChairServices/{AI,TTS,Tasks,Utils}
  mkdir -p Tests/DirectorsChairServicesTests
  ```
- [ ] Start implementing AIServiceClient.swift
- [ ] Post progress update in docs/shared/messages.md

---

## Key Technical Guidelines

### 1. Import DirectorsChairCore
```swift
import DirectorsChairCore
```

All data models, protocols, and EventBus are in DirectorsChairCore.

### 2. Use EventBus for Progress Tracking
```swift
await EventBus.shared.publish(.aiServiceStarted(
    operation: "generateImage",
    provider: "openai",
    estimatedCost: 0.04
))

// ... operation ...

await EventBus.shared.publish(.aiServiceCompleted(
    operation: "generateImage",
    success: true,
    actualCost: 0.04
))
```

### 3. Async/Await for All Operations
All service methods must be `async throws` for proper concurrency.

### 4. Multi-Provider Pattern
```swift
enum AIProvider {
    case openai
    case anthropic
    case google
    case stability
}

class AIServiceClient: AIServiceProtocol {
    private let provider: AIProvider
    private let apiKey: String

    init(provider: AIProvider, apiKey: String) {
        self.provider = provider
        self.apiKey = apiKey
    }

    func generateImage(prompt: String, options: ImageGenerationOptions) async throws -> Data {
        switch provider {
        case .openai:
            return try await generateImageOpenAI(prompt, options)
        case .stability:
            return try await generateImageStability(prompt, options)
        // ...
        }
    }
}
```

### 5. Cost Estimation
Track API costs for all operations:
```swift
struct AIOperationCost {
    let operation: String
    let provider: AIProvider
    let inputTokens: Int?
    let outputTokens: Int?
    let imageCount: Int?
    let estimatedCost: Decimal
}
```

### 6. Error Handling
Use comprehensive error types:
```swift
enum AIServiceError: Error {
    case invalidAPIKey
    case rateLimitExceeded
    case insufficientCredits
    case networkError(Error)
    case providerError(String)
    case invalidResponse
}
```

---

## Phase 2 Gate Criteria (Week 5)

Your work will be validated against:

- [ ] AIServiceClient implements AIServiceProtocol completely
- [ ] Multi-provider support working (at least OpenAI + Anthropic)
- [ ] Image generation functional
- [ ] TTS service working with AVFoundation
- [ ] Background task manager operational
- [ ] PDF export produces valid screenplay format
- [ ] FDX/Fountain exports parse correctly
- [ ] All services integrate with EventBus
- [ ] Unit tests passing (90%+ coverage)
- [ ] Feature parity with Python services (100%)

---

## Communication Protocol

### When to Message Agent 1 (Architect)
- Questions about DirectorsChairCore protocols
- API issues or needed changes
- Integration blockers

### When to Message Agent 2 (Core Editing)
- Agent 2 needs your AI services for:
  - Character image generation
  - Trait analysis
  - TTS playback in Bubble View

### When to Message Agent 4 (Timeline)
- Agent 4 may need export services for Timeline

### When to Message Agent 5 (QA)
- When ready for testing
- Service performance validation needed

---

## Files to Read First

1. **docs/AGENT_ONBOARDING.md** - Complete project overview
2. **docs/PROJECT_STATUS.md** - Current status (you're behind!)
3. **docs/agents/agent_3_characters_ai/INSTRUCTIONS.md** - Your detailed instructions
4. **DirectorsChairCore/Sources/DirectorsChairCore/Protocols/** - All service protocols
5. **DirectorsChair-Python/services/ai_service.py** - Reference implementation
6. **docs/shared/messages.md** - Inter-agent communications

---

## Python Reference Files Location

All Python reference files are in:
```
DirectorsChair-Python/
├── services/
│   ├── ai_service.py (~1,200 lines)
│   ├── tts_service.py (~600 lines)
│   ├── task_manager.py (~400 lines)
│   └── image_utils.py (~300 lines)
└── exports/
    ├── pdf_export.py (~900 lines)
    ├── fdx_export.py (~500 lines)
    ├── fountain_export.py (~300 lines)
    └── html_export.py (~400 lines)
```

---

## Git Workflow

1. **Create your branch NOW**: `git checkout -b agent-3-ai`
2. **Commit frequently**: After each component
3. **Update status.md**: After each session
4. **Post in messages.md**: After major milestones
5. **Pull from main**: Check for integration changes daily

---

## Dependencies & Package.swift

Your Package.swift should depend on:

```swift
dependencies: [
    .package(path: "../DirectorsChairCore"),
    // Add as needed:
    .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.2.0"),
    .package(url: "https://github.com/anthropics/anthropic-sdk-swift.git", from: "0.1.0"),
    // ... other AI SDKs
],
targets: [
    .target(
        name: "DirectorsChairServices",
        dependencies: [
            "DirectorsChairCore",
            "OpenAI",
            // ... other dependencies
        ]
    ),
]
```

---

**Your Mission**: Build the DirectorsChairServices and DirectorsChairExports packages to provide AI capabilities and export functionality for the Swift app.

**Timeline**: Complete Phase 2 by end of Week 5 (3 weeks from NOW)

**Current Status**: 🔴 CRITICAL - You are the blocking path. Start immediately.

**Other agents are waiting for you!** Agent 2 needs your TTS and AI services. Agent 4 may need export services. Let's catch up! 🚀
