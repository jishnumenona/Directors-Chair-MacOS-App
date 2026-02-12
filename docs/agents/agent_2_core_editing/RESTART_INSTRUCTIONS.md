# Agent 2 Restart Instructions - Core Editing Lead

## Your Role
You are **Agent 2: Core Editing Lead** for the DirectorsChair Swift migration project. You work on implementing SwiftUI views for dialogue editing, character design, and production planning features.

## Project Overview
**DirectorsChair** is a film pre-production application being migrated from Python/PyQt to Swift/SwiftUI. The project uses a 5-agent parallel development model with module-based isolation.

- **Original**: Python/PyQt desktop app (118 UI files, 60,000+ LOC)
- **Target**: Native macOS app with Swift/SwiftUI
- **Timeline**: 18 weeks (currently Week 3)
- **Your Package**: DirectorsChairViews + DirectorsChairProduction

## Current Project Status

### Phase 1: Foundation - ✅ COMPLETE
**Lead**: Agent 1 (Architect)
**Status**: All gates passed, 24/24 tests passing

**Completed**:
- ✅ DirectorsChairCore package (27 data models, 28/30 with custom decoders)
- ✅ JSON persistence layer (ProjectPersistence, DebouncedSaveManager)
- ✅ EventBus system (40+ event types, thread-safe actor)
- ✅ All protocol interfaces defined (AIServiceProtocol, ProductionServiceProtocol, etc.)
- ✅ Python JSON compatibility (snake_case ↔ camelCase mapping)

**Git Branch**: `agent-1-core` (37 commits, merged to main)

### Other Agents Status
- **Agent 3** (Characters & AI): Phase 2 in progress (DirectorsChairServices)
- **Agent 4** (Timeline Canvas): Phase 3 preparation (studying timeline_view.py)
- **Agent 5** (QA & Testing): Continuous validation

## YOUR Current Status - CRITICAL

### ⚠️ You Have Uncommitted Work (Phase 4)

You successfully completed Phase 4 (Core Editing Views) **3 weeks ahead of schedule**. However, your session froze before committing. You have **17 Swift files (~3,855 lines)** in your working directory that are NOT yet committed to Git.

**Uncommitted Files**:
```
Sources/DirectorsChairViews/Bubble/ (8 files)
  - BubbleView.swift (586 lines) - Main dialogue editing interface
  - DialogueBubbleCard.swift (230 lines) - Dialogue bubble component
  - ActionBubbleCard.swift (141 lines) - Action/stage direction component
  - NarrationBubbleCard.swift (142 lines) - Narration/voiceover component
  - NoteBubbleCard.swift (204 lines) - Production note component
  - SoundNoteBubbleCard.swift (259 lines) - Sound/music note component
  - DialogueEditorPanel.swift (283 lines) - Right panel editor
  - SceneListSidebar.swift (166 lines) - Scene navigation

Sources/DirectorsChairViews/StoryDesign/ (6 files)
  - StoryDesignView.swift (250 lines) - Main character design view
  - CharacterListSidebar.swift (250 lines) - Character list with search
  - PhysicalAppearanceTab.swift (330 lines) - Character customizer
  - PersonalityTraitsTab.swift (340 lines) - 25 traits with radar chart
  - BiographyTab.swift (220 lines) - Goals, fears, backstory
  - RelationshipsTab.swift (230 lines) - Character relationships

Sources/DirectorsChairViews/Shared/ (3 files)
  - CharacterAvatarView.swift (100 lines) - Circular avatar component
  - TagPillView.swift (80 lines) - Tag display component
  - ColorExtensions.swift (44 lines) - Hex color support
```

**Total**: 17 files, ~3,855 lines of Swift code

## Architect's Decision: Your Next Steps

As the Architect (Agent 1), I have decided your path forward:

### Step 1: Commit Your Phase 4 Work (IMMEDIATE)

1. **Create your Git branch**:
   ```bash
   git checkout -b agent-2-editing
   ```

2. **Verify your files exist**:
   ```bash
   git status
   ```
   You should see all 17 files as untracked (`??`)

3. **Stage all your files**:
   ```bash
   git add DirectorsChairViews/Sources/DirectorsChairViews/
   ```

4. **Commit with descriptive message**:
   ```bash
   git commit -m "$(cat <<'EOF'
   feat(views): Implement Phase 4 Core Editing Views

   Implemented complete Bubble View and Story Design View modules ahead of schedule.

   Bubble View (8 components, ~2,000 lines):
   - BubbleView: Main dialogue editing interface with chat-style layout
   - 5 bubble card types: Dialogue, Action, Narration, Note, SoundNote
   - DialogueEditorPanel: Right panel for editing dialogue properties
   - SceneListSidebar: Scene navigation with search and filtering

   Story Design View (6 components, ~1,620 lines):
   - StoryDesignView: Main character design interface with tabbed layout
   - CharacterListSidebar: Character list with search and avatar display
   - PhysicalAppearanceTab: Full character customizer (70+ fields)
   - PersonalityTraitsTab: 25-trait OCEAN model with custom radar chart
   - BiographyTab: Goals, fears, backstory, motivations
   - RelationshipsTab: Character relationship management

   Shared Components (3 components, ~224 lines):
   - CharacterAvatarView: Circular avatar with fallback initials
   - TagPillView: Reusable tag display component
   - ColorExtensions: Hex color parsing for SwiftUI

   Key Design Decisions:
   - DCScene typealias to avoid SwiftUI.Scene protocol ambiguity
   - BubbleItem enum for unified content handling with chronology sorting
   - Custom SwiftUI Shape/Path for personality radar chart
   - Placeholder callbacks for Agent 3's AI services

   Phase 4 Status: 90% complete (integration testing pending)

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
   EOF
   )"
   ```

5. **Update your status document**:
   ```bash
   # Open docs/agents/agent_2_core_editing/status.md
   # Mark Phase 4 tasks as complete
   # Update git commit count
   # Update session logs
   ```

6. **Notify Agent 1 in messages.md**:
   Add a message to `docs/shared/messages.md`:
   ```markdown
   ## 2026-01-13 - Agent 2: Phase 4 Complete - Committed All Work

   **To**: Agent 1 (Architect)
   **Status**: ✅ Phase 4 Core Editing Views - COMMITTED

   I have successfully committed all Phase 4 work to the `agent-2-editing` branch:
   - Bubble View module (8 components, ~2,000 lines)
   - Story Design View module (6 components, ~1,620 lines)
   - Shared components (3 components, ~224 lines)
   - Total: 17 files, ~3,855 lines Swift code

   Phase 4 delivered 3 weeks ahead of schedule (Week 3 instead of Week 6-9).

   Ready to proceed to Phase 6 (DirectorsChairProduction) as directed by Architect.

   **Requesting**: Review and merge approval for agent-2-editing branch
   ```

### Step 2: Proceed to Phase 6 - DirectorsChairProduction (NEW TASK)

After committing Phase 4, you will immediately start Phase 6: Production Features.

**Why Phase 6 instead of waiting?**
- Agent 3 is handling Services (Phase 2) and Exports (Phase 7)
- Agent 4 is handling Timeline (Phase 3)
- Phase 5 (Advanced Views) depends on Timeline being complete
- Phase 6 has minimal dependencies - you can start NOW
- This accelerates the timeline by 7 weeks

## Phase 6 Implementation Plan

### Module: DirectorsChairProduction

**Timeline**: Week 3-5 (Parallel with Agent 3's Services work)

**Reference Files**:
- `DirectorsChair-Python/ui/production_ui/schedule_view.py` (~1,200 lines)
- `DirectorsChair-Python/ui/production_ui/cast_crew_view.py` (~800 lines)
- `DirectorsChair-Python/ui/production_ui/budget_view.py` (~600 lines)

### Components to Implement

#### 1. Schedule Optimizer View (~1,200 lines)
**File**: `DirectorsChairProduction/Sources/DirectorsChairProduction/Schedule/ScheduleView.swift`

**Features**:
- Scene list with drag-and-drop reordering
- Shooting schedule calendar view
- Resource conflict detection (locations, actors, equipment)
- Schedule optimization suggestions (group by location/actor)
- Day breakdown with scene counts and estimated duration
- Call sheets generation preview
- Export to PDF/CSV

**Key UI Elements**:
- Left sidebar: Scene list with filters (by location, character, day/night)
- Center: Calendar grid showing shooting days
- Right panel: Day details (scenes, cast, crew, equipment)
- Bottom toolbar: Optimization tools

**Data Models** (already in DirectorsChairCore):
- `ScheduleItem` - Single scheduled scene with date, location, cast, crew
- `Scene` - Scene metadata with location, characters, estimated duration
- `CastMember`, `CrewMember`, `Team` - People assignments
- `Location` - Filming locations

**Protocol to Implement**:
```swift
// DirectorsChairCore/Sources/DirectorsChairCore/Protocols/ProductionServiceProtocol.swift
protocol SchedulingServiceProtocol: Sendable {
    func optimizeSchedule(scenes: [Scene], constraints: SchedulingConstraints) async throws -> [ScheduleItem]
    func detectConflicts(schedule: [ScheduleItem]) async throws -> [ScheduleConflict]
    func estimateShootingDays(scenes: [Scene]) async throws -> Int
}
```

#### 2. Cast & Crew Management View (~800 lines)
**File**: `DirectorsChairProduction/Sources/DirectorsChairProduction/CastCrew/CastCrewView.swift`

**Features**:
- Cast list with character assignments
- Crew roster with role assignments
- Availability calendar (who's available when)
- Contact information management
- Scene assignments (which actor in which scene)
- Team groupings (departments)
- Conflict warnings (double-booked actors)

**Key UI Elements**:
- Left sidebar: Cast/Crew tabs with search
- Center: Person detail form (name, role, contact, photos)
- Right panel: Scene assignments and availability calendar
- Bottom: Team assignments and notes

**Data Models** (already in DirectorsChairCore):
- `CastMember` - Actor with character assignment, availability, rate
- `CrewMember` - Crew with role, rate, availability
- `Team` - Department grouping (camera, sound, art, etc.)
- `Character` - Character linked to cast member

#### 3. Budget Estimator View (~600 lines)
**File**: `DirectorsChairProduction/Sources/DirectorsChairProduction/Budget/BudgetView.swift`

**Features**:
- Budget categories tree (pre-production, production, post, marketing)
- Expense line items with descriptions
- Cost estimation and tracking
- Actual vs. budget variance
- Pie chart visualization
- Export to Excel/CSV

**Key UI Elements**:
- Left sidebar: Category tree (expandable/collapsible)
- Center: Expense line items table
- Right panel: Category details and totals
- Bottom: Summary bar (total budget, spent, remaining, variance %)

**Data Models** (already in DirectorsChairCore):
- `ProjectBudget` - Root budget with total and categories
- `BudgetCategory` - Category with name, allocated amount, subcategories
- `Expense` - Line item with description, estimated/actual amount, paid status

**Protocol to Implement**:
```swift
// DirectorsChairCore/Sources/DirectorsChairCore/Protocols/ProductionServiceProtocol.swift
protocol BudgetServiceProtocol: Sendable {
    func estimateBudget(project: Project) async throws -> ProjectBudget
    func calculateVariance(budget: ProjectBudget) async throws -> [BudgetVariance]
    func forecastCosts(budget: ProjectBudget, progress: Double) async throws -> Double
}
```

### Implementation Order

1. **Week 3**: Schedule Optimizer View
   - Start with basic scene list and calendar grid
   - Add drag-and-drop reordering
   - Implement conflict detection algorithm
   - Add optimization suggestions

2. **Week 4**: Cast & Crew Management View
   - Build cast/crew list with search
   - Add person detail forms
   - Implement availability calendar
   - Add team assignments

3. **Week 5**: Budget Estimator View
   - Build category tree UI
   - Add expense line items table
   - Implement chart visualizations
   - Add export functionality

## Key Technical Guidelines

### 1. Import DirectorsChairCore
```swift
import DirectorsChairCore
```

All data models, protocols, and EventBus are in DirectorsChairCore.

### 2. Use EventBus for Communication
```swift
await EventBus.shared.publish(.dataModelModified(
    entityType: "Scene",
    entityID: sceneID,
    field: "scheduleDate",
    oldValue: nil,
    newValue: newDate
))
```

### 3. SwiftUI Best Practices
- Use `@StateObject` for ViewModels
- Use `@Published` for reactive data
- Keep views under 300 lines (extract subviews)
- Use `async/await` for all data operations

### 4. Python Reference Fidelity
- Match UI layout from Python reference files
- Preserve all features from Python version
- Maintain keyboard shortcuts and interactions
- Keep color schemes and styling consistent

### 5. Type Aliases for Ambiguity
If you encounter SwiftUI type conflicts:
```swift
typealias DCScene = DirectorsChairCore.Scene
```

### 6. Placeholder for AI Services
When you need AI features that Agent 3 will provide:
```swift
// TODO: Agent 3 - AI service integration
// Will be connected to AIServiceProtocol when Agent 3 completes Phase 2
```

## Files to Read First

Before starting implementation, read these files to understand the project:

1. **docs/AGENT_ONBOARDING.md** - Master onboarding document (architecture, all agents)
2. **docs/PROJECT_STATUS.md** - Current project status (phases, progress, metrics)
3. **docs/agents/agent_2_core_editing/status.md** - Your status document (update this regularly)
4. **docs/agents/agent_2_core_editing/INSTRUCTIONS.md** - Your detailed instructions
5. **docs/shared/messages.md** - Inter-agent communications (check daily)
6. **docs/shared/integration_log.md** - API changes and integration events (check daily)

## Git Workflow

1. **Always work on your branch**: `agent-2-editing`
2. **Commit frequently**: After each component or logical unit
3. **Descriptive commit messages**: Follow the format from Step 1
4. **Update status.md**: After each session
5. **Notify Agent 1**: Post in messages.md when you complete major milestones
6. **Pull from main**: Before starting each session (check for integration changes)

## Communication Protocol

### When to Message Agent 1 (Architect)
- You complete a major milestone (phase, module)
- You discover API issues in DirectorsChairCore
- You need clarification on data models or protocols
- You encounter blocking issues

### When to Message Agent 3 (AI Services)
- You need AI service integration
- You have questions about AIServiceProtocol

### When to Message Agent 4 (Timeline)
- You need Timeline component integration (later phases)

### When to Message Agent 5 (QA)
- You're ready for testing
- You want performance validation
- You need bug tracking

## Success Criteria - Phase 6 Gate

Your Phase 6 work will be validated against these criteria:

- [ ] All 3 production views compile and run
- [ ] Schedule optimizer can detect resource conflicts
- [ ] Cast/Crew view supports full CRUD operations
- [ ] Budget view calculates variances correctly
- [ ] All views integrate with DirectorsChairCore data models
- [ ] All views publish EventBus events on data changes
- [ ] Feature parity with Python reference files (100%)
- [ ] Code quality: Clear, documented, under 300 lines per view file

## Immediate Action Checklist

When you restart, execute these steps in order:

- [ ] Read this document completely
- [ ] Read docs/AGENT_ONBOARDING.md
- [ ] Read docs/PROJECT_STATUS.md
- [ ] Verify your 17 uncommitted files exist: `git status`
- [ ] Create branch: `git checkout -b agent-2-editing`
- [ ] Stage files: `git add DirectorsChairViews/Sources/DirectorsChairViews/`
- [ ] Commit Phase 4 work (use commit message from Step 1 above)
- [ ] Update docs/agents/agent_2_core_editing/status.md
- [ ] Post completion message in docs/shared/messages.md
- [ ] Read schedule_view.py reference file (~1,200 lines)
- [ ] Create DirectorsChairProduction package structure
- [ ] Start implementing ScheduleView.swift

## Questions?

If you have any questions or encounter issues:
1. Check docs/AGENT_ONBOARDING.md first
2. Check docs/shared/integration_log.md for recent changes
3. Read relevant Python reference files
4. Post a question in docs/shared/messages.md for Agent 1

---

**Your Mission**: Commit Phase 4 work, then build the DirectorsChairProduction module to bring scheduling, cast/crew management, and budgeting to the Swift app.

**Timeline**: Complete Phase 6 by end of Week 5 (3 weeks from now)

**Current Week**: Week 3 of 18

**Project Health**: 🟢 EXCELLENT - Phase 1 passed all gates, you're 3 weeks ahead of schedule

Let's build this! 🎬
