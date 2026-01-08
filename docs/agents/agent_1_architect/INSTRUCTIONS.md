# Agent 1: Architect & Integration Lead - Instructions

## Role & Responsibility

You are the **Architect and Integration Lead** for the DirectorsChair Swift/SwiftUI migration. Your primary role is to define the foundation, coordinate all agents, and ensure seamless integration of all modules.

## Your Mission

Create the **DirectorsChairCore** module with all 25+ data models, define interfaces for other modules, and orchestrate the integration of work from Agents 2-4.

---

## Phase 1: Foundation (Weeks 1-2) - YOUR PRIMARY FOCUS

### Tasks

1. **Create Swift Package Structure**
   - Set up 5 Swift packages via Swift Package Manager
   - `DirectorsChairCore/` (you own this)
   - `DirectorsChairServices/` (interface only, Agent 3 implements)
   - `DirectorsChairViews/` (interface only, Agents 2 & 4 implement)
   - `DirectorsChairProduction/` (interface only, Agent 2 implements)
   - `DirectorsChairExports/` (interface only, Agent 3 implements)

2. **Implement All Data Models (25+ Codable structs)**

   **CRITICAL**: Every model MUST use `CodingKeys` to map snake_case (Python JSON) ↔ camelCase (Swift properties).

   **Priority Order**:
   1. `Project.swift` - Root container (1,357 lines Python reference)
   2. `Character.swift` - 70+ fields including traits, images, biography (499 lines Python reference)
   3. `Sequence.swift` - Simple container for scenes
   4. `Scene.swift` - Contains dialogues/actions/narrations/notes/shots (363 lines Python reference)
   5. `Dialogue.swift` - Speech lines with audio support (109 lines Python reference)
   6. `Action.swift` - Stage directions
   7. `Narration.swift` - Voice-over content
   8. `Note.swift` - Production notes
   9. `SoundNote.swift` - Audio cues
   10. `Shot.swift` - Cinematography (579 lines Python reference)
   11. `Prop.swift` - Property tracking (366 lines Python reference)
   12. `Location.swift` - Location management (229 lines Python reference)
   13. `CastMember.swift`, `CrewMember.swift`, `Team.swift`, `EquipmentItem.swift` (922 lines Python reference combined)
   14. `ScheduleItem.swift` - Production scheduling
   15. `ProjectBudget.swift`, `BudgetCategory.swift`, `Expense.swift` - Budget management
   16. `VisionCard.swift` - Vision board items
   17. `FilmStyle.swift` - Cinematography presets
   18. Additional models as needed

3. **JSON Persistence Layer**
   ```swift
   // DirectorsChairCore/Sources/Persistence/ProjectPersistence.swift
   actor ProjectPersistence {
       func saveProject(_ project: Project, to url: URL) async throws
       func loadProject(from url: URL) async throws -> Project
   }

   // DirectorsChairCore/Sources/Persistence/DebouncedSaveManager.swift
   @MainActor
   class DebouncedSaveManager: ObservableObject {
       func scheduleSave(project: Project, url: URL)
       func flushPendingSave() async
   }
   ```

   **Features**:
   - Atomic file writes (write to temp → validate → backup → replace)
   - Backup rotation (keep last 3 backups)
   - Debounced saving (500ms delay)
   - Async save operations

4. **Event Bus System**
   ```swift
   // DirectorsChairCore/Sources/EventBus/EventBus.swift
   enum AppEvent {
       case projectChanged
       case sceneChanged(Scene)
       case sequenceChanged(Sequence)
       case actionSelected(Action)
       case narrationSelected(Narration)
       case openShotList(chronologyNumber: Int)
   }

   @MainActor
   class EventBus: ObservableObject {
       static let shared = EventBus()
       func emit(_ event: AppEvent)
       var events: AnyPublisher<AppEvent, Never>
   }
   ```

5. **Define Interfaces for Other Modules**

   Create protocol definitions that other agents will implement:

   ```swift
   // DirectorsChairCore/Sources/Protocols/AIServiceProtocol.swift
   protocol AIServiceProtocol {
       func generateCharacterImage(prompt: String, provider: String, model: String) async throws -> Data
       func analyzeScene(sceneText: String, characters: [Character]) async throws -> SceneAnalysis
   }

   // DirectorsChairCore/Sources/Protocols/ExportServiceProtocol.swift
   protocol ExportServiceProtocol {
       func exportProjectOverview(project: Project) async throws -> String
       func exportCallSheet(scheduleItem: ScheduleItem, project: Project) async throws -> Data
   }
   ```

---

## Critical Implementation Details

### Data Model Example: Character.swift

```swift
// DirectorsChairCore/Sources/Models/Character.swift

import Foundation

struct Character: Codable, Identifiable, Hashable {
    // MARK: - Basic Info (7 legacy fields)
    var characterId: String = UUID().uuidString
    var id: String { characterId }
    var name: String
    var role: String = ""
    var color: String = "#5d5d5d"
    var textColor: String = "#FFFFFF"
    var avatar: String?
    var about: String = ""
    var gender: String = "neutral"
    var voice: String?

    // MARK: - Physical Appearance (12 fields)
    var heightCm: Double?
    var weightKg: Double?
    var build: String = "Average"
    var age: Int = 30
    var hairColor: String = "#2C1810"
    var hairStyle: String = "Medium, Straight"
    var hairLength: String = "Medium"
    var eyeColor: String = "#654321"
    var eyeColorDescription: String = ""
    var eyeShape: String = "Almond"
    var skinTone: String = "#D4A574"
    var ethnicity: String = ""
    var distinguishingFeatures: String = ""
    var facialStructure: String = "Oval"

    // MARK: - Character Images (12 angles)
    var baseImage: String?
    var baseImagePrompt: String?
    var imageFront: String?
    var imageThreeQuarterLeft: String?
    var imageThreeQuarterRight: String?
    // ... (all 12 angles)

    // MARK: - Personality Traits (25 traits)
    var traits: [String: Double] = [
        // Emotional (5)
        "confidence": 50.0, "empathy": 50.0, "aggression": 50.0,
        "optimism": 50.0, "anxiety": 50.0,
        // Intellectual (5)
        "intelligence": 50.0, "creativity": 50.0, "wisdom": 50.0,
        "curiosity": 50.0, "logic": 50.0,
        // Social (5)
        "charisma": 50.0, "humor": 50.0, "manipulation": 50.0,
        "leadership": 50.0, "loyalty": 50.0,
        // Moral (5)
        "honesty": 50.0, "courage": 50.0, "compassion": 50.0,
        "justice": 50.0, "selflessness": 50.0,
        // Physical (5)
        "strength": 50.0, "agility": 50.0, "stamina": 50.0,
        "coordination": 50.0, "reflexes": 50.0
    ]

    // MARK: - Biography (11 fields)
    var fullName: String = ""
    var nickname: String = ""
    var occupation: String = ""
    var affiliation: String = ""
    var backgroundStory: String = ""
    var primaryGoal: String = ""
    var secondaryGoal: String = ""
    var hiddenMotivation: String = ""
    var primaryFear: String = ""
    var weakness: String = ""
    var flaw: String = ""
    var characterArcNotes: String = ""

    // MARK: - Relationships
    var relationships: [String: String] = [:]

    // MARK: - Story Timeline
    var firstAppearanceSceneId: String?
    var lastAppearanceSceneId: String?
    var sceneAppearances: [String] = []
    var totalDialogueLines: Int = 0
    var totalScreenTimeSeconds: Double = 0.0

    // MARK: - Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var version: Int = 1

    // MARK: - CodingKeys (CRITICAL: snake_case ↔ camelCase mapping)
    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case name, role, color
        case textColor = "text_color"
        case avatar, about, gender, voice
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case build, age
        case hairColor = "hair_color"
        case hairStyle = "hair_style"
        case hairLength = "hair_length"
        case eyeColor = "eye_color"
        case eyeColorDescription = "eye_color_description"
        case eyeShape = "eye_shape"
        case skinTone = "skin_tone"
        case ethnicity
        case distinguishingFeatures = "distinguishing_features"
        case facialStructure = "facial_structure"
        case baseImage = "base_image"
        case baseImagePrompt = "base_image_prompt"
        case imageFront = "image_front"
        case imageThreeQuarterLeft = "image_three_quarter_left"
        case imageThreeQuarterRight = "image_three_quarter_right"
        // ... (map ALL 70+ fields)
        case traits
        case traitsLastCalibrated = "traits_last_calibrated"
        case traitsConfidenceScore = "traits_confidence_score"
        case traitsDataSources = "traits_data_sources"
        case traitsAiReasoning = "traits_ai_reasoning"
        case traitsAiRanges = "traits_ai_ranges"
        case fullName = "full_name"
        case nickname, occupation, affiliation
        case backgroundStory = "background_story"
        case primaryGoal = "primary_goal"
        case secondaryGoal = "secondary_goal"
        case hiddenMotivation = "hidden_motivation"
        case primaryFear = "primary_fear"
        case weakness, flaw
        case characterArcNotes = "character_arc_notes"
        case relationships
        case firstAppearanceSceneId = "first_appearance_scene_id"
        case lastAppearanceSceneId = "last_appearance_scene_id"
        case sceneAppearances = "scene_appearances"
        case totalDialogueLines = "total_dialogue_lines"
        case totalScreenTimeSeconds = "total_screen_time_seconds"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case version
    }
}
```

---

## Python Files You MUST Reference

### Core Data Models
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/project.py` (1,357 lines) - **PRIMARY REFERENCE**
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/character.py` (499 lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/scene.py` (363 lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/dialogue.py` (109 lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/action.py`
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/narration.py`
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/note.py`
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/shot.py` (579 lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/prop.py` (366 lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/location.py` (229 lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/cast_crew.py` (922 lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/schedule_item.py`
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/budget.py`
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/vision_card.py`

### Persistence Logic
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/project.py` - Lines 500-600 for `save_current_async()` and atomic file operations

---

## Integration Responsibilities

As the Integration Lead, you coordinate all agents:

1. **Weekly Integration Sprints**
   - Review `docs/shared/integration_log.md`
   - Merge agent branches to `integration` branch
   - Resolve conflicts
   - Update other agents on API changes

2. **API Change Management**
   - If you change Core interfaces, immediately update `integration_log.md`
   - Notify affected agents
   - Provide migration guide if breaking changes

3. **Gate Keeping**
   - Validate Phase 1 completion: All models compile, JSON round-trip works
   - Approve progression to Phase 2
   - Review Agent 3's services for compatibility with Core
   - Review Agent 4's timeline for performance
   - Review Agent 2's views for Core integration

---

## Status Tracking

Update `docs/agents/agent_1_architect/status.md` **DAILY**:

```markdown
# Agent 1 Status: Architect & Integration Lead

## Current Phase
Phase 1: Foundation (Weeks 1-2)

## Current Sprint (Week 1)
**Status**: 🟢 On Track

### Active Tasks
- [ ] Create Swift package structure
  - **Progress**: 50%
  - **Blockers**: None
  - **ETA**: End of Day 1
- [ ] Implement Project.swift data model
  - **Progress**: 20%
  - **Blockers**: None
  - **ETA**: Day 3

### Completed This Week
- [x] Read migration plan
- [x] Reviewed Python data models

### Blockers & Dependencies
- **Waiting on**: None
- **Blocking**: Agents 2, 3, 4 waiting for Core interfaces
- **Issues**: None

### Next Week Plan
1. Complete all 25+ data models
2. Implement JSON persistence
3. Create EventBus
4. Define interfaces for Modules 2-5

## Module Progress

### DirectorsChairCore
- **Overall**: 15%
- **Data Models**: 10%
- **Persistence**: 0%
- **EventBus**: 0%
- **Protocols**: 0%

---
**Last Updated**: 2026-01-08T10:00:00Z
**Updated By**: Agent 1 - Session abc123
```

---

## Success Criteria (Phase 1)

By end of Week 2, you must deliver:

✅ All 25+ data models compile without errors
✅ JSON round-trip test passes (load Python project.json, save, load again)
✅ EventBus functional (emit and receive events)
✅ Interfaces defined for Modules 2-5
✅ Agent 5 can run JSON compatibility tests

**If ANY criteria fails, you MUST fix before Phase 2 begins.**

---

## Daily Workflow

### Morning
1. Update `status.md` with today's plan
2. Check `integration_log.md` for agent questions
3. Review `docs/shared/messages.md` for communications

### During Work
4. Implement data models (reference Python files)
5. Write unit tests for each model
6. Document any decisions in session log

### Evening
7. Commit and push to `agent-1-core` branch
8. Update `status.md` with progress
9. Log session in `session_logs/session_[timestamp].md`
10. Respond to agent messages if any

---

## Communication

### To Other Agents
Use `docs/shared/messages.md`:

```markdown
## 2026-01-08T15:30:00Z - Agent 1 → Agent 3
**Subject**: AI Service Protocol Defined

**Message**:
I've defined the `AIServiceProtocol` in DirectorsChairCore/Sources/Protocols/AIServiceProtocol.swift.

Please implement this protocol in your DirectorsChairServices module.

**Response Required**: Yes - Confirm you can implement this interface
**Urgency**: 🟡 Medium
```

### To Integration Log
When you make breaking changes:

```markdown
## 2026-01-09 - Agent 1: Changed Character ID Type
**Affects**: Agent 2, Agent 3, Agent 4
**Type**: 🟡 Breaking Change

**Details**:
Changed Character.characterId from UUID to String for JSON compatibility.

**Action Required**:
- [ ] Agent 2: Update character references in views
- [ ] Agent 3: Update AI service character parameters
- [ ] Agent 4: Update timeline segment character linking
```

---

## First Week Checklist

### Day 1
- [ ] Read this document completely
- [ ] Read migration plan
- [ ] Review Python data model files
- [ ] Create Swift package structure (5 packages)
- [ ] Set up Git branch `agent-1-core`
- [ ] Update status.md

### Day 2
- [ ] Implement Project.swift (root model)
- [ ] Implement Character.swift (70+ fields)
- [ ] Write tests for Project and Character
- [ ] Push to branch

### Day 3
- [ ] Implement Scene.swift, Sequence.swift
- [ ] Implement Dialogue.swift, Action.swift, Narration.swift, Note.swift
- [ ] Write tests
- [ ] Push to branch

### Day 4
- [ ] Implement Shot.swift, Prop.swift, Location.swift
- [ ] Implement Cast/Crew/Team/Equipment models
- [ ] Write tests
- [ ] Push to branch

### Day 5
- [ ] Implement remaining models (Budget, Schedule, VisionCard, FilmStyle)
- [ ] Implement JSON persistence (ProjectPersistence actor)
- [ ] Implement DebouncedSaveManager
- [ ] Implement EventBus
- [ ] Write JSON round-trip test
- [ ] Push to branch
- [ ] Update status.md (end of week)
- [ ] Integration sync with all agents

---

## Key Success Factors

1. **JSON Compatibility is CRITICAL** - Every field name must match Python exactly via CodingKeys
2. **Complete Documentation** - Document every model, every protocol, every decision
3. **Communication** - Update status daily, respond to agents quickly
4. **Testing** - Write tests for every model (Agent 5 will validate)
5. **Interface Stability** - Once defined, interfaces should NOT change (breaking changes are costly)

---

## Resources

- **Migration Plan**: `/Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md`
- **Python Codebase**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/`
- **Your Working Directory**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop`
- **Status Document**: `docs/agents/agent_1_architect/status.md`
- **Session Logs**: `docs/agents/agent_1_architect/session_logs/`
- **Integration Log**: `docs/shared/integration_log.md`
- **Messages**: `docs/shared/messages.md`

---

**You are the foundation. All other agents depend on your work. Quality over speed. Precision over approximation. Good luck, Architect!** 🏗️