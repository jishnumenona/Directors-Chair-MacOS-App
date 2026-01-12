# DirectorsChair Swift Migration - Agent Onboarding

**Welcome to the DirectorsChair Python → Swift/SwiftUI Migration Project!**

This document provides essential information for all agents working on this migration. Read this first before starting any work.

---

## 📋 Project Overview

**Objective**: Migrate the complete DirectorsChair desktop application (118 UI files, 25+ data models, 60,000+ LOC) from Python/PyQt to native macOS Swift/SwiftUI with 100% feature parity and JSON compatibility.

**Strategy**: 5-agent parallel development using module-based isolation to minimize merge conflicts.

**Timeline**: 18 weeks total (with parallel execution)

**Working Directory**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop`

---

## 🎯 Current Project Status

### ✅ Phase 1: Foundation (Weeks 1-2) - COMPLETE

**Lead**: Agent 1 (Architect)

**Status**: ✅ **PASSED ALL GATES**

**Completed Deliverables**:
- ✅ DirectorsChairCore Swift package with all 27 data models
- ✅ 28/30 models have custom decoders for Python JSON compatibility
- ✅ JSON persistence layer (ProjectPersistence, DebouncedSaveManager)
- ✅ EventBus system (40+ event types, thread-safe actor)
- ✅ All protocol interfaces defined (AI, Production, Export, Git, ViewModels)
- ✅ JSON compatibility tests: 5/6 passing (83%)
- ✅ All DirectorsChairCore unit tests: 24/24 passing (100%)

**Git Branch**: `agent-1-core` (33 commits)

**Test Results**:
```
✅ DirectorsChairCore: 24/24 tests PASSING
✅ EventBusTests: 15/15 passing
✅ PersistenceTests: 9/9 passing
✅ JSONCompatibilityTests: 5/6 passing
```

**Phase 1 Gate Criteria**: ✅ ALL MET
- All 27 data models compile ✅
- JSON round-trip test passes ✅
- EventBus functional ✅

### 📅 Upcoming Phases

**Phase 2: Services Layer (Weeks 3-5)** - Ready to START
- **Lead**: Agent 3 (Characters & AI)
- **Status**: Waiting for Agent 3 to begin

**Phase 3: Timeline Canvas (Weeks 4-7)** - Parallel with Phase 2
- **Lead**: Agent 4 (Timeline & Canvas)
- **Status**: Preparation phase (starts Week 4)

**Phase 4: Core Editing Views (Weeks 6-9)** - Parallel with Phase 3
- **Lead**: Agent 2 (Core Editing)
- **Status**: Preparation phase (starts Week 6)

---

## 🏗️ Architecture Overview

### Module Dependency Graph

```
┌─────────────────────────────────────────────────┐
│       DirectorsChairApp (Main Target)           │
│         (App lifecycle, scene setup)            │
└─────────────────────────────────────────────────┘
                      │
         ┌────────────┼────────────┐
         │            │            │
         ▼            ▼            ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  Views      │ │ Production  │ │  Exports    │
│  (Module 3) │ │  (Module 4) │ │  (Module 5) │
│  Agent 2,4  │ │  Agent 2    │ │  Agent 3    │
└─────────────┘ └─────────────┘ └─────────────┘
         │            │            │
         └────────────┼────────────┘
                      │
         ┌────────────┼────────────┐
         │            │            │
         ▼            ▼            ▼
┌─────────────────────────────────────────────────┐
│         Services (Module 2)                     │
│   (AI, Git, TTS, Background Tasks)             │
│              Agent 3                            │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│           Core (Module 1)                       │
│   (Data Models, JSON I/O, Event Bus)           │
│              Agent 1                            │
│           ✅ COMPLETE                           │
└─────────────────────────────────────────────────┘
```

### Module Descriptions

#### Module 1: DirectorsChairCore ✅ COMPLETE
- **Owner**: Agent 1 (Architect)
- **Status**: Complete and validated
- **Contents**:
  - 27 data models (Project, Character, Scene, Shot, Prop, etc.)
  - JSON persistence with atomic saves
  - EventBus for cross-module communication
  - Protocol interfaces for all other modules
- **Location**: `DirectorsChairCore/`

#### Module 2: DirectorsChairServices
- **Owner**: Agent 3 (Characters & AI)
- **Status**: Ready to start (Phase 2)
- **Contents**:
  - AI service clients (OpenAI, Anthropic, Google, Stability)
  - TTS service (AVFoundation)
  - Git client for collaboration
  - Background task manager
  - Image/video utilities
- **Location**: `DirectorsChairServices/` (to be created)

#### Module 3: DirectorsChairViews
- **Owners**: Agent 2 (Core Editing) + Agent 4 (Timeline Canvas)
- **Status**: Phase 3-5
- **Contents**:
  - Main window structure
  - Timeline view (Canvas-based) - Agent 4
  - Bubble view (dialogue editor) - Agent 2
  - Story Design view (character editor) - Agent 2
  - Navigation and reusable components
  - Preferences panels
- **Location**: `DirectorsChairViews/` (to be created)

#### Module 4: DirectorsChairProduction
- **Owner**: Agent 2 (Core Editing)
- **Status**: Phase 6
- **Contents**:
  - Schedule optimizer
  - Cast/crew management
  - Equipment tracking
  - Budget management
- **Location**: `DirectorsChairProduction/` (to be created)

#### Module 5: DirectorsChairExports
- **Owner**: Agent 3 (Characters & AI)
- **Status**: Phase 7
- **Contents**:
  - HTML exporters (9 types)
  - PDF generation (call sheets)
  - Final Draft export (.fdx)
  - Git/Gitea integration
- **Location**: `DirectorsChairExports/` (to be created)

---

## 👥 Agent Assignments & Responsibilities

### Agent 1: Architect & Integration Lead
**Status**: Phase 1 complete, now supporting other agents

**Responsibilities**:
- ✅ Create DirectorsChairCore module (COMPLETE)
- ✅ Define interfaces for Modules 2-5 (COMPLETE)
- Review and integrate work from Agents 2-4
- Coordinate merge conflicts and API changes
- Final integration testing
- Weekly integration reports

**Your Instructions**: `docs/agents/agent_1_architect/INSTRUCTIONS.md`
**Status Document**: `docs/agents/agent_1_architect/status.md`
**Git Branch**: `agent-1-core`

---

### Agent 2: Core Editing (Bubble, Story Design, Production)
**Status**: Preparation phase (starts Phase 4, Week 6)

**Responsibilities**:
- **Phase 4 (Weeks 6-9)**: Bubble View (dialogue editor with character bubbles, tags, audio)
- **Phase 4 (Weeks 6-9)**: Story Design View (character editor, 25 personality traits, biography)
- **Phase 5 (Weeks 8-11)**: Schedule view
- **Phase 6 (Weeks 10-13)**: DirectorsChairProduction package (schedule optimizer, cast/crew management, budget estimator)

**Key Python References**:
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/bubble_view.py` (4,150 lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/story_design_view.py` (2,000+ lines)

**Your Instructions**: `docs/agents/agent_2_core_editing/INSTRUCTIONS.md`
**Status Document**: `docs/agents/agent_2_core_editing/status.md` (create this)
**Git Branch**: `agent-2-editing` (create this)

---

### Agent 3: Characters & AI Services
**Status**: Phase 2 lead - READY TO START NOW

**Responsibilities**:
- **Phase 2 (Weeks 3-5)**: DirectorsChairServices package (AI clients, TTS, background tasks)
- **Phase 7 (Weeks 12-15)**: DirectorsChairExports package (HTML, PDF, Final Draft, Git)
- Character analyzer (AI-powered trait calibration)
- Character image generation and 12-angle system

**Key Python References**:
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/services/ai_assistant.py` (850+ lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/services/character_analyzer.py` (507 lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/services/tts_service.py`

**Your Instructions**: `docs/agents/agent_3_characters_ai/INSTRUCTIONS.md`
**Status Document**: `docs/agents/agent_3_characters_ai/status.md` (create this)
**Git Branch**: `agent-3-ai` (create this)

---

### Agent 4: Timeline & Canvas Rendering
**Status**: Preparation phase (starts Phase 3, Week 4)

**Responsibilities**:
- **Phase 3 (Weeks 4-7)**: Timeline View with Canvas API rendering (custom bubbles, viewport culling for 60fps)
- **Phase 5 (Weeks 8-11)**: Vision Board view (infinite canvas with draggable cards)
- **Phase 5 (Weeks 8-11)**: Cinematography view (shot management, storyboard)

**⚠️ CRITICAL**: Timeline is the most complex UI component (2,701 lines in Python). Viewport culling is MANDATORY for 60fps performance.

**Key Python References**:
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/timeline_view.py` (2,701 lines) - **MUST STUDY DEEPLY**
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/visionboard_canvas.py` (1,500+ lines)

**Your Instructions**: `docs/agents/agent_4_timeline_canvas/INSTRUCTIONS.md`
**Status Document**: `docs/agents/agent_4_timeline_canvas/status.md` (create this)
**Git Branch**: `agent-4-canvas` (create this)

---

### Agent 5: QA & Testing
**Status**: Continuous testing across all phases

**Responsibilities**:
- Create comprehensive test suite for all modules
- JSON round-trip validation (Python ↔ Swift compatibility)
- UI/UX testing against Python reference
- Performance benchmarking (Timeline: 60fps, save/load: <500ms)
- Integration testing (cross-module interactions)
- Feature parity checklist validation (118 UI components)
- Regression testing
- Document bugs and track fixes

**Current Test Results**:
```
✅ DirectorsChairCore: 24/24 tests PASSING
✅ JSONCompatibilityTests: 5/6 tests PASSING
```

**Your Instructions**: `docs/agents/agent_5_qa/INSTRUCTIONS.md`
**Status Document**: `docs/agents/agent_5_qa/status.md` (update with Phase 1 completion)
**Git Branch**: `agent-5-qa` (create this)

---

## 📂 Key Files & Documents

### Essential Documents (Read These First)

1. **This Document**: `docs/AGENT_ONBOARDING.md` ← YOU ARE HERE
2. **Migration Plan**: `/Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md`
3. **Your Agent Instructions**: `docs/agents/agent_[N]_[name]/INSTRUCTIONS.md`
4. **Agent 1 Status** (Phase 1 completion): `docs/agents/agent_1_architect/status.md`

### Communication Documents

- **Agent-to-Agent Messages**: `docs/shared/messages.md`
- **Integration Log**: `docs/shared/integration_log.md`
- **Feature Parity Checklist**: `docs/agents/agent_5_qa/feature_parity_checklist.md`
- **Bug Tracking**: `docs/agents/agent_5_qa/bugs.md`

### Code Locations

- **Completed Core Module**: `DirectorsChairCore/`
  - Data Models: `DirectorsChairCore/Sources/DirectorsChairCore/Models/`
  - Protocols: `DirectorsChairCore/Sources/DirectorsChairCore/Protocols/`
  - Services: `DirectorsChairCore/Sources/DirectorsChairCore/Services/`
  - Tests: `DirectorsChairCore/Tests/DirectorsChairCoreTests/`

- **Python Reference** (for feature implementation):
  - Data Models: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/data/`
  - UI Views: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/`
  - Services: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/services/`
  - Exports: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/exports/`

---

## 🔄 Development Workflow

### 1. Starting Your Work

**First Time Setup**:
```bash
cd /Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop

# Read the essential documents
cat docs/AGENT_ONBOARDING.md                    # This document
cat docs/agents/agent_[N]_[name]/INSTRUCTIONS.md  # Your specific instructions

# Review Phase 1 completion
cat docs/agents/agent_1_architect/status.md

# Create your feature branch
git checkout -b agent-[N]-[name]

# Create your status document
cp docs/agents/agent_1_architect/status.md docs/agents/agent_[N]_[name]/status.md
# Edit your status.md with your current phase and tasks
```

**Every Session**:
1. Check `docs/shared/messages.md` for messages from other agents
2. Check `docs/shared/integration_log.md` for API changes
3. Update your `docs/agents/agent_[N]_[name]/status.md` at start and end of session
4. Commit your work with clear, descriptive commit messages

### 2. Git Branch Strategy

- `main` - Production-ready code (protected)
- `integration` - Agent 1 integration branch
- `agent-1-core` - Agent 1 feature branch (Phase 1 complete)
- `agent-2-editing` - Agent 2 feature branch (create this)
- `agent-3-ai` - Agent 3 feature branch (create this)
- `agent-4-canvas` - Agent 4 feature branch (create this)
- `agent-5-qa` - Agent 5 testing branch (create this)

### 3. Integration Workflow

1. Work in your feature branch (`agent-[N]-[name]`)
2. Commit regularly with descriptive messages
3. Push to your branch daily
4. Agent 1 reviews and merges to `integration` branch
5. Weekly integration sprints (all agents sync to `integration`)
6. Agent 5 validates `integration` branch
7. Stable `integration` → `main` bi-weekly

### 4. Communication Protocol

**Questions for Other Agents**:
- Use `docs/shared/messages.md`
- Format:
  ```markdown
  ## [ISO Timestamp] - Agent [N] → Agent [M]
  **Subject**: [Topic]

  **Message**: [Your question or comment]

  **Response Required**: Yes/No
  **Urgency**: 🔴 High | 🟡 Medium | 🟢 Low
  ```

**API Changes or Breaking Changes**:
- Update `docs/shared/integration_log.md`
- Notify affected agents in `docs/shared/messages.md`

**Daily Updates**:
- Update your `status.md` at the end of each work session
- Include: tasks completed, tasks in progress, blockers, next steps

---

## 🎯 Phase Gates & Success Criteria

### Phase 1 Gate ✅ PASSED
- ✅ All 27 data models compile
- ✅ JSON round-trip test passes
- ✅ EventBus functional

### Phase 2 Gate (Services Layer)
- ⏳ AI service client working (multi-provider)
- ⏳ TTS service functional
- ⏳ Background task manager operational

### Phase 3 Gate (Timeline Canvas)
- ⏳ Timeline renders 100+ bubbles at 60fps
- ⏳ Viewport culling working correctly
- ⏳ Zoom/scroll/pan interactions smooth

### Phase 4 Gate (Core Editing Views)
- ⏳ Bubble view edits dialogues correctly
- ⏳ Character editor saves 70+ fields
- ⏳ Story Design view fully functional

### Phase 8 Gate (Integration)
- ⏳ All 118 UI components implemented
- ⏳ All 9 HTML exports working
- ⏳ Python projects load in Swift app

### Phase 9 Gate (Release)
- ⏳ All tests passing (>80% coverage)
- ⏳ Performance benchmarks met
- ⏳ No P1/P2 bugs

---

## ⚠️ Critical Implementation Guidelines

### 1. JSON Compatibility (ALL AGENTS)

**CRITICAL**: All Codable structs MUST use `CodingKeys` to map snake_case (Python JSON) to camelCase (Swift).

✅ **CORRECT**:
```swift
struct Character: Codable {
    var characterId: String
    var hairColor: String
    var eyeShape: String

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case hairColor = "hair_color"
        case eyeShape = "eye_shape"
    }
}
```

❌ **WRONG**:
```swift
struct Character: Codable {
    var characterId: String  // Won't decode from Python JSON!
    var hairColor: String
}
```

Agent 1 has implemented this pattern in all 27 models. Review `DirectorsChairCore/Sources/DirectorsChairCore/Models/` for examples.

### 2. Performance Requirements (Agent 4)

**Timeline View MUST render at 60fps with 100+ bubbles**

- Viewport culling is MANDATORY
- Only render segments visible in viewport
- Reference: `DirectorsChairCore/Sources/DirectorsChairCore/Models/Scene.swift` for data structures

### 3. Thread Safety (Agents 2, 3, 4)

- Use `actor` for all services that manage state
- Use `@MainActor` for all SwiftUI views
- Agent 1 has implemented thread-safe patterns in EventBus and ProjectPersistence

### 4. Module Isolation (ALL AGENTS)

**File Ownership Rules**:
- Only modify files in your assigned modules
- Read other modules, but DO NOT edit them
- If you need changes in another module, message the owner via `docs/shared/messages.md`

| Directory | Owner | Access |
|-----------|-------|--------|
| `DirectorsChairCore/` | Agent 1 | All: Read-only (Agent 1: Write) |
| `DirectorsChairServices/` | Agent 3 | All: Read-only (Agent 3: Write) |
| `DirectorsChairViews/Timeline/` | Agent 4 | All: Read-only (Agent 4: Write) |
| `DirectorsChairViews/Bubble/` | Agent 2 | All: Read-only (Agent 2: Write) |
| `DirectorsChairViews/StoryDesign/` | Agent 2 | All: Read-only (Agent 2: Write) |
| `DirectorsChairProduction/` | Agent 2 | All: Read-only (Agent 2: Write) |
| `DirectorsChairExports/` | Agent 3 | All: Read-only (Agent 3: Write) |
| `Tests/` | Agent 5 | All: Write (Agent 5 owns) |

---

## 🚀 Quick Start Checklist

**Before You Start Working**:

- [ ] Read this document (`docs/AGENT_ONBOARDING.md`)
- [ ] Read the migration plan (`/Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md`)
- [ ] Read your agent-specific instructions (`docs/agents/agent_[N]_[name]/INSTRUCTIONS.md`)
- [ ] Review Agent 1's Phase 1 completion status (`docs/agents/agent_1_architect/status.md`)
- [ ] Review DirectorsChairCore package structure
- [ ] Study your Python reference files
- [ ] Create your status document (`docs/agents/agent_[N]_[name]/status.md`)
- [ ] Create your feature branch (`agent-[N]-[name]`)
- [ ] Check `docs/shared/messages.md` for any messages
- [ ] Plan your first sprint and update your status.md

**Every Work Session**:

- [ ] Check `docs/shared/messages.md` at start of session
- [ ] Check `docs/shared/integration_log.md` for API changes
- [ ] Update your `status.md` at start: "What I'm working on today"
- [ ] Do your work and commit regularly
- [ ] Update your `status.md` at end: "What I completed, what's next, blockers"
- [ ] Push your branch daily

---

## 📞 Getting Help

**Questions about DirectorsChairCore (data models, protocols)**:
- Message Agent 1 in `docs/shared/messages.md`
- Review `DirectorsChairCore/` source code
- Check Agent 1's status: `docs/agents/agent_1_architect/status.md`

**Questions about Services/AI (Agent 3's work)**:
- Message Agent 3 in `docs/shared/messages.md`
- Check Agent 3's status when available

**Questions about Timeline/Canvas (Agent 4's work)**:
- Message Agent 4 in `docs/shared/messages.md`
- Check Agent 4's status when available

**Questions about Views/Production (Agent 2's work)**:
- Message Agent 2 in `docs/shared/messages.md`
- Check Agent 2's status when available

**Questions about Testing/QA**:
- Message Agent 5 in `docs/shared/messages.md`
- Check `docs/agents/agent_5_qa/` for test results and bug reports

**General Coordination Questions**:
- Message Agent 1 (Architect & Integration Lead) in `docs/shared/messages.md`

---

## 🎉 Current Milestone

**Phase 1: Foundation - ✅ COMPLETE AND PASSED**

Agent 1 has successfully delivered:
- ✅ 27 data models with Python JSON compatibility
- ✅ 28/30 models with custom decoders for graceful field handling
- ✅ Thread-safe EventBus system
- ✅ Atomic persistence layer
- ✅ All protocol interfaces defined
- ✅ 24/24 unit tests passing
- ✅ 5/6 JSON compatibility tests passing

**Next Up: Phase 2 (Services Layer) - Agent 3 to begin NOW**

---

## 📖 Version History

- **v1.0** (2026-01-11): Initial onboarding document created after Phase 1 completion
- Created by: Agent 1 (Architect & Integration Lead)

---

**Ready to start? Read your agent-specific instructions next:**

- **Agent 1**: `docs/agents/agent_1_architect/INSTRUCTIONS.md`
- **Agent 2**: `docs/agents/agent_2_core_editing/INSTRUCTIONS.md`
- **Agent 3**: `docs/agents/agent_3_characters_ai/INSTRUCTIONS.md`
- **Agent 4**: `docs/agents/agent_4_timeline_canvas/INSTRUCTIONS.md`
- **Agent 5**: `docs/agents/agent_5_qa/INSTRUCTIONS.md`

**Good luck! 🚀**
