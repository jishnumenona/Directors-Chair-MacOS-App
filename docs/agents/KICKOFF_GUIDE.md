# DirectorsChair Migration - Agent Kickoff Guide

## Overview

You are about to launch 5 parallel Claude Code instances to migrate DirectorsChair from Python/PyQt to Swift/SwiftUI. This guide explains how to initialize and manage each agent.

---

## Pre-Launch Checklist

✅ Migration plan approved (`/Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md`)
✅ Swift Xcode project created (`DirectorsChair-Desktop.xcodeproj`)
✅ Agent documentation created (13 files in `docs/`)
✅ Python reference codebase accessible (`../DirectorsChair/directorschair/`)
✅ Git repository initialized

---

## Agent Launch Order

### Step 1: Launch Agent 1 (Architect) - MUST GO FIRST

**Why First**: Agent 1 creates the foundation (DirectorsChairCore module) that all other agents depend on.

**How to Launch**:

```bash
cd /Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop

# Launch Claude Code in this directory
claude-code .

# Or open in your preferred IDE and start Claude Code session
```

**What to Tell Agent 1**:

```
I'm Agent 1: Architect & Integration Lead for the DirectorsChair Swift migration.

Please read:
1. docs/agents/agent_1_architect/INSTRUCTIONS.md
2. /Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md

Then begin Phase 1: Create DirectorsChairCore module with all 25+ data models.

Update docs/agents/agent_1_architect/status.md daily.
```

**Agent 1 Timeline**: Weeks 1-2 (Phase 1), then ongoing integration

---

### Step 2: Launch Agent 5 (QA) - PARALLEL WITH AGENT 1

**Why Second**: Agent 5 can set up test infrastructure while Agent 1 builds Core module.

**How to Launch**:

```bash
# Open a NEW Claude Code instance in the SAME directory
cd /Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop
claude-code .
```

**What to Tell Agent 5**:

```
I'm Agent 5: QA & Testing for the DirectorsChair Swift migration.

Please read:
1. docs/agents/agent_5_qa/INSTRUCTIONS.md
2. /Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md

Then begin Phase 1: Set up test infrastructure, create JSON test fixtures from Python app, create feature parity checklist (118 items).

Update docs/agents/agent_5_qa/status.md daily.
```

**Agent 5 Timeline**: All phases (ongoing testing and validation)

---

### Step 3: Wait for Agent 1 to Complete Phase 1

**Gate Check** (End of Week 2):

Agent 1 must complete and Agent 5 must validate:
- ✅ All 25+ data models compile
- ✅ JSON decode test passes (load Python project.json)
- ✅ JSON encode test passes (save to JSON)
- ✅ Round-trip test passes (load → save → load)
- ✅ EventBus functional

**If ANY test fails, DO NOT proceed. Agent 1 must fix.**

---

### Step 4: Launch Agent 3 (Characters & AI) - WEEK 3

**Why Third**: Agent 3 can start services layer once Core interfaces are defined.

**How to Launch**:

```bash
# Open a NEW Claude Code instance
cd /Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop
claude-code .
```

**What to Tell Agent 3**:

```
I'm Agent 3: Characters & AI Services for the DirectorsChair Swift migration.

Please read:
1. docs/agents/agent_3_characters_ai/INSTRUCTIONS.md
2. /Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md
3. Check docs/shared/integration_log.md for Agent 1's interface definitions

Then begin Phase 2: Implement DirectorsChairServices module (AI client, TTS, background tasks).

Update docs/agents/agent_3_characters_ai/status.md daily.
```

**Agent 3 Timeline**: Weeks 3-5 (Phase 2), Weeks 12-15 (Phase 7)

---

### Step 5: Launch Agent 4 (Timeline Canvas) - WEEK 4 (PARALLEL WITH AGENT 3)

**Why Fourth**: Agent 4 can start timeline while Agent 3 builds services.

**How to Launch**:

```bash
# Open a NEW Claude Code instance
cd /Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop
claude-code .
```

**What to Tell Agent 4**:

```
I'm Agent 4: Timeline & Canvas Rendering for the DirectorsChair Swift migration.

Please read:
1. docs/agents/agent_4_timeline_canvas/INSTRUCTIONS.md
2. /Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md
3. DEEP STUDY: /Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/timeline_view.py (2,701 lines)

Then begin Phase 3: Implement Timeline View with Canvas API rendering, viewport culling, 60fps performance.

CRITICAL: You MUST achieve 60fps with 100+ bubbles.

Update docs/agents/agent_4_timeline_canvas/status.md daily.
```

**Agent 4 Timeline**: Weeks 4-7 (Phase 3), Weeks 8-11 (Phase 5)

---

### Step 6: Launch Agent 2 (Core Editing) - WEEK 6 (PARALLEL WITH AGENT 4)

**Why Fifth**: Agent 2 starts editing views once timeline is well underway.

**How to Launch**:

```bash
# Open a NEW Claude Code instance
cd /Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop
claude-code .
```

**What to Tell Agent 2**:

```
I'm Agent 2: Core Editing (Bubble, Story Design, Production) for the DirectorsChair Swift migration.

Please read:
1. docs/agents/agent_2_core_editing/INSTRUCTIONS.md
2. /Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md
3. Reference: directorschair/ui/bubble_view.py (4,150 lines)
4. Reference: directorschair/ui/story_design_view.py (2,000+ lines)

Then begin Phase 4: Implement Bubble View (dialogue editor) and Story Design View (character editor).

Update docs/agents/agent_2_core_editing/status.md daily.
```

**Agent 2 Timeline**: Weeks 6-9 (Phase 4), Weeks 10-13 (Phase 6)

---

## Managing 5 Parallel Sessions

### Directory Structure for Sessions

**Recommended Terminal/IDE Setup**:

```
Terminal/IDE Layout:

┌─────────────────┬─────────────────┬─────────────────┐
│  Agent 1        │  Agent 2        │  Agent 3        │
│  (Architect)    │  (Editing)      │  (AI/Exports)   │
│                 │                 │                 │
│  Week 1-2 + all │  Week 6-13      │  Week 3-5,      │
│  integration    │                 │  12-15          │
└─────────────────┴─────────────────┴─────────────────┘

┌─────────────────┬─────────────────────────────────────┐
│  Agent 4        │  Agent 5                            │
│  (Timeline)     │  (QA)                               │
│                 │                                     │
│  Week 4-11      │  Week 1-18 (ongoing)                │
└─────────────────┴─────────────────────────────────────┘
```

### Git Branch Strategy

Each agent works on their own branch:

```bash
# Agent 1
git checkout -b agent-1-core

# Agent 2
git checkout -b agent-2-editing

# Agent 3
git checkout -b agent-3-ai

# Agent 4
git checkout -b agent-4-canvas

# Agent 5
git checkout -b agent-5-qa
```

**Integration Branch** (Agent 1 manages):
```bash
git checkout -b integration
```

**Merge Workflow**:
1. Agents push to their branches daily
2. Agent 1 reviews and merges to `integration` weekly
3. Agent 5 validates `integration` branch
4. Stable `integration` → `main` bi-weekly

---

## Daily Agent Workflow

### Morning (Each Agent)
1. Check `docs/shared/integration_log.md` for changes
2. Check `docs/shared/messages.md` for communications
3. Update `docs/agents/agent_[N]/status.md` with today's plan
4. Pull latest from integration branch (if needed)

### During Work
5. Implement assigned tasks
6. Reference Python codebase
7. Write tests (or coordinate with Agent 5)
8. Document decisions

### Evening (Each Agent)
9. Commit and push to agent branch
10. Update `docs/agents/agent_[N]/status.md` with progress
11. Log session in `session_logs/session_[timestamp].md`
12. Update `integration_log.md` if API changes made
13. Post questions in `messages.md` if needed

---

## Weekly Integration Sprint (Sundays or End of Week)

**Coordinated by Agent 1**:

1. **Review Integration Log**
   - All agents read `docs/shared/integration_log.md`
   - Resolve conflicts
   - Address blockers

2. **Status Review**
   - Each agent summarizes progress
   - Update timeline if needed

3. **Merge to Integration**
   - Agent 1 merges all agent branches to `integration`
   - Agent 5 validates merged code
   - Fix integration issues

4. **Plan Next Week**
   - Assign tasks for coming week
   - Identify dependencies

---

## Communication Channels

### Real-Time (Synchronous)
- **NOT RECOMMENDED** - Agents work asynchronously
- Use messages.md for async communication

### Async (Preferred)
- **integration_log.md** - API changes, breaking changes
- **messages.md** - Questions, clarifications
- **status.md** - Daily progress updates
- **session_logs/** - Detailed session records

---

## Monitoring Progress

### Daily Checks (You as Manager)

```bash
# Check all agent statuses
for agent in agent_1_architect agent_2_core_editing agent_3_characters_ai agent_4_timeline_canvas agent_5_qa; do
  echo "=== $agent ==="
  cat docs/agents/$agent/status.md | grep "Status:"
  echo ""
done
```

### Weekly Reports

Check these files:
- `docs/agents/agent_1_architect/status.md` - Core module progress
- `docs/agents/agent_2_core_editing/status.md` - Editing views progress
- `docs/agents/agent_3_characters_ai/status.md` - Services/exports progress
- `docs/agents/agent_4_timeline_canvas/status.md` - Timeline performance
- `docs/agents/agent_5_qa/status.md` - Test coverage, bugs, feature parity

### Phase Gate Checks

**End of Phase 1** (Week 2):
- Agent 5: Validate all data models, JSON round-trip
- Gate: MUST PASS before Phase 2

**End of Phase 3** (Week 7):
- Agent 5: Validate timeline 60fps performance
- Gate: MUST achieve 60fps before proceeding

**End of Phase 8** (Week 16):
- Agent 5: Full integration test
- Gate: MUST pass all tests before release

---

## Handling Issues

### Agent Blocked
1. Agent posts in `messages.md` with 🔴 High urgency
2. Blocking agent responds ASAP
3. Agent 1 coordinates resolution

### API Breaking Change
1. Agent posts in `integration_log.md` with 🟡 Breaking Change
2. Lists all affected agents
3. Provides migration guide
4. Affected agents acknowledge and update

### Performance Issue
1. Agent posts issue
2. Agent 5 benchmarks
3. Agent 1 prioritizes fix
4. Responsible agent optimizes

### Merge Conflict
1. Agent pulls integration branch
2. Resolves conflicts locally
3. Runs tests
4. Pushes resolved branch
5. Agent 1 re-reviews

---

## Success Indicators

### Week 2 (Phase 1 Gate)
✅ All data models compile
✅ JSON tests pass
✅ Agent 5 approves

### Week 7 (Phase 3 Gate)
✅ Timeline renders 60fps
✅ Agent 5 benchmarks pass

### Week 16 (Phase 8 Gate)
✅ All 118 features implemented
✅ Integration tests pass
✅ Performance benchmarks met

### Week 18 (Release)
✅ Zero P1/P2 bugs
✅ >80% test coverage
✅ Python projects load in Swift
✅ Production-ready

---

## Emergency Protocols

### Agent Session Crashes
- Session logs in `session_logs/` preserve context
- Resume by reading last session log
- Update status.md to reflect current state

### Agent Falls Behind Schedule
- Agent 1 reassigns tasks if possible
- Consider reducing scope (defer to v2.0)
- Update timeline and notify all agents

### Critical Bug Blocks Progress
- Agent 5 files P1 bug in `bugs.md`
- Agent 1 prioritizes fix
- All agents pause dependent work

---

## Quick Reference

### File Locations
- **Migration Plan**: `/Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md`
- **Python Codebase**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/`
- **Swift Project**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop/`
- **Agent Docs**: `docs/agents/agent_[N]/`
- **Shared Docs**: `docs/shared/`

### Key Commands
```bash
# Check agent status
cat docs/agents/agent_[N]/status.md

# Check integration log
cat docs/shared/integration_log.md

# Check messages
cat docs/shared/messages.md

# View plan
cat /Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md

# List all documentation
find docs -type f -name "*.md"
```

---

## Ready to Launch?

### Pre-Flight Checklist
- [ ] All 13 documentation files created
- [ ] Migration plan reviewed
- [ ] Python codebase accessible
- [ ] Swift Xcode project ready
- [ ] Git initialized
- [ ] You understand agent roles
- [ ] You understand communication protocol

### Launch Sequence
1. ✅ Week 1: Launch Agent 1 + Agent 5
2. ⏸️ Week 3: Launch Agent 3 (wait for Phase 1 gate)
3. ⏸️ Week 4: Launch Agent 4 (parallel with Agent 3)
4. ⏸️ Week 6: Launch Agent 2 (parallel with Agent 4)

---

**You are the project manager. Coordinate, communicate, and keep everyone on track. Good luck!** 🚀

---

**Last Updated**: 2026-01-08
**Document Version**: 1.0