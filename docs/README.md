# DirectorsChair Swift/SwiftUI Migration Documentation

## Overview

This directory contains the complete documentation for the DirectorsChair Python/PyQt → Swift/SwiftUI migration project, coordinated across 5 parallel Claude Code agent instances.

---

## Project Structure

```
docs/
├── README.md (this file)
├── agents/
│   ├── agent_1_architect/
│   │   ├── INSTRUCTIONS.md - Agent 1's detailed instructions
│   │   ├── status.md - Current status and progress
│   │   └── session_logs/ - Timestamped session logs
│   ├── agent_2_core_editing/
│   │   ├── INSTRUCTIONS.md
│   │   ├── status.md
│   │   └── session_logs/
│   ├── agent_3_characters_ai/
│   │   ├── INSTRUCTIONS.md
│   │   ├── status.md
│   │   └── session_logs/
│   ├── agent_4_timeline_canvas/
│   │   ├── INSTRUCTIONS.md
│   │   ├── status.md
│   │   └── session_logs/
│   └── agent_5_qa/
│       ├── INSTRUCTIONS.md
│       ├── status.md
│       ├── bugs.md - Bug tracker
│       └── session_logs/
├── shared/
│   ├── integration_log.md - Cross-agent API changes and dependencies
│   └── messages.md - Agent-to-agent communication
└── migration/
    └── (migration guides, checklists, etc.)
```

---

## Agent Roles

### Agent 1: Architect & Integration Lead 🏗️
- **Responsibility**: Core data models, JSON persistence, EventBus, module interfaces, integration coordination
- **Module**: DirectorsChairCore (owns)
- **Phase**: Phase 1 (Weeks 1-2), ongoing integration
- **Status**: `docs/agents/agent_1_architect/status.md`

### Agent 2: Core Editing (Bubble, Story Design, Production) ✍️
- **Responsibility**: Dialogue editing, character management, production features, scheduling, cast/crew
- **Modules**: DirectorsChairViews (Bubble, Story Design), DirectorsChairProduction
- **Phase**: Phase 4 (Weeks 6-9), Phase 6 (Weeks 10-13)
- **Status**: `docs/agents/agent_2_core_editing/status.md`

### Agent 3: Characters & AI Services 🤖
- **Responsibility**: AI integration, TTS, character analysis, HTML/PDF exports, Git collaboration
- **Modules**: DirectorsChairServices, DirectorsChairExports
- **Phase**: Phase 2 (Weeks 3-5), Phase 7 (Weeks 12-15)
- **Status**: `docs/agents/agent_3_characters_ai/status.md`

### Agent 4: Timeline & Canvas Rendering 🎬
- **Responsibility**: Custom Canvas timeline with viewport culling, 60fps performance, vision board, cinematography
- **Module**: DirectorsChairViews (Timeline, VisionBoard, Cinematography)
- **Phase**: Phase 3 (Weeks 4-7), Phase 5 (Weeks 8-11)
- **Status**: `docs/agents/agent_4_timeline_canvas/status.md`

### Agent 5: QA & Testing ✅
- **Responsibility**: Test suites, JSON compatibility validation, performance benchmarking, feature parity checks
- **Module**: Tests (all modules)
- **Phase**: All phases (ongoing validation)
- **Status**: `docs/agents/agent_5_qa/status.md`

---

## Quick Start for Agents

### New Agent Session Checklist

1. **Read Your Instructions**
   - `docs/agents/agent_[N]/INSTRUCTIONS.md`

2. **Check Your Status**
   - `docs/agents/agent_[N]/status.md`
   - Update status at start and end of session

3. **Check Integration Log**
   - `docs/shared/integration_log.md`
   - Look for changes affecting you

4. **Check Messages**
   - `docs/shared/messages.md`
   - Respond to any messages

5. **Read Migration Plan**
   - `/Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md`

6. **Do Your Work**
   - Follow your INSTRUCTIONS.md
   - Reference Python codebase
   - Write tests

7. **Update Status Daily**
   - Update status.md with progress
   - Log session in session_logs/

8. **Communicate Changes**
   - Update integration_log.md if you make API changes
   - Post messages.md if you have questions

---

## Module Architecture

```
DirectorsChairApp (Main Target)
├── DirectorsChairCore (Agent 1)
│   ├── Models/ (25+ data models)
│   ├── Persistence/ (JSON I/O, atomic saves)
│   ├── EventBus/ (Combine-based event system)
│   └── Protocols/ (Interfaces for other modules)
│
├── DirectorsChairServices (Agent 3)
│   ├── AI/ (OpenAI, Anthropic, Google, Stability)
│   ├── Audio/ (TTS, AVFoundation)
│   ├── Git/ (Git/Gitea integration)
│   └── Tasks/ (Background task manager)
│
├── DirectorsChairViews (Agents 2 & 4)
│   ├── Bubble/ (Dialogue editor) - Agent 2
│   ├── StoryDesign/ (Character editor) - Agent 2
│   ├── Timeline/ (Canvas timeline) - Agent 4
│   ├── VisionBoard/ (Infinite canvas) - Agent 4
│   ├── Cinematography/ (Shot management) - Agent 4
│   └── Common/ (Reusable components)
│
├── DirectorsChairProduction (Agent 2)
│   ├── Schedule/ (Optimizer, calendar)
│   ├── CastCrew/ (Actor/crew management)
│   └── Budget/ (Budget tracking)
│
└── DirectorsChairExports (Agent 3)
    ├── HTML/ (9 HTML exporters)
    ├── PDF/ (Call sheets)
    └── FinalDraft/ (.fdx export)
```

---

## Timeline (18 Weeks)

### Phase 1: Foundation (Weeks 1-2) - Agent 1
Core data models, JSON persistence, EventBus

### Phase 2: Services (Weeks 3-5) - Agent 3
AI integration, TTS, background tasks

### Phase 3: Timeline Canvas (Weeks 4-7) - Agent 4
Custom canvas rendering, 60fps viewport culling

### Phase 4: Core Editing (Weeks 6-9) - Agent 2
Bubble view, Story Design, character management

### Phase 5: Advanced Views (Weeks 8-11) - Agents 2 & 4
Vision Board, Cinematography, Schedule

### Phase 6: Production (Weeks 10-13) - Agent 2
Schedule optimizer, cast/crew, budget

### Phase 7: Exports (Weeks 12-15) - Agent 3
HTML/PDF exports, Git integration

### Phase 8: Integration (Weeks 14-16) - Agent 1
Final integration, bug fixes, polish

### Phase 9: Testing (Weeks 17-18) - Agent 5
Regression testing, performance benchmarking, release prep

---

## Communication Protocol

### Daily (Async)
- Update your status.md
- Check integration_log.md
- Check messages.md

### Weekly (Coordinated by Agent 1)
- Integration sync
- Resolve conflicts
- Plan next week
- Update timeline if needed

---

## Critical Files Reference

### Python Codebase
**Location**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/`

**Key Files**:
- `data/project.py` (1,357 lines) - Root data model
- `data/character.py` (499 lines) - Character with 70+ fields
- `ui/timeline_view.py` (2,701 lines) - Timeline canvas (CRITICAL for Agent 4)
- `ui/bubble_view.py` (4,150 lines) - Dialogue editor (CRITICAL for Agent 2)
- `ui/story_design_view.py` (2,000+ lines) - Character editor (Agent 2)
- `services/ai_assistant.py` (850+ lines) - AI integration (Agent 3)
- All files in `data/`, `ui/`, `services/`, `exports/`

### Swift Codebase
**Location**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop/`

---

## Success Criteria

### Phase Gates
Each phase has specific deliverables and quality gates. See migration plan for details.

### Final Release Criteria
✅ All 118 UI components implemented
✅ All 25+ data models with JSON compatibility
✅ Timeline: 60fps with 100+ bubbles
✅ Save/Load: <500ms
✅ Python projects load in Swift app
✅ Tests: >80% coverage
✅ Zero P1/P2 bugs

---

## Resources

- **Migration Plan**: `/Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md`
- **Python Codebase**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/`
- **Swift Codebase**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop/`

---

## Getting Help

1. **Check Your INSTRUCTIONS.md** - Your specific role and tasks
2. **Read Migration Plan** - Complete architecture and strategy
3. **Post in messages.md** - Ask other agents
4. **Update integration_log.md** - Document issues affecting others

---

**Last Updated**: 2026-01-08
**Document Version**: 1.0