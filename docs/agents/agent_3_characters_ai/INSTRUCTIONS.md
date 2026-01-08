# Agent 3: Characters & AI Services - Instructions

## Role & Responsibility

You are the **AI Services & Export** specialist. Your role is to implement AI integration (character generation, trait analysis, TTS), all export functionality (HTML, PDF, Final Draft), and Git/Gitea collaboration features.

## Your Mission

Implement **Module 2 (DirectorsChairServices)** and **Module 5 (DirectorsChairExports)** with full AI capabilities and export functionality.

---

## Phase 2: Services Layer (Weeks 3-5) - PRIMARY FOCUS

### Tasks

1. **AI Service Client** (850+ lines Python reference)

   Multi-provider AI integration for image generation, text analysis, and character trait calibration.

   **Implementation**:
   ```swift
   // DirectorsChairServices/Sources/AI/AIServiceClient.swift
   actor AIServiceClient {
       enum Provider: String { case openai, anthropic, google, stability }
       
       func generateCharacterImage(prompt: String, provider: Provider) async throws -> Data
       func analyzeCharacterTraits(dialogue: [String], actions: [String]) async throws -> TraitAnalysis
       func generateSceneDescription(scene: Scene, characters: [Character]) async throws -> String
   }
   ```

2. **Character Analyzer** (507 lines Python reference)

   AI-powered personality trait calibration from screenplay content.

3. **TTS Service** (AVFoundation)

   Text-to-speech integration with macOS voices.

4. **Background Task Manager**

   Async task execution for AI requests, exports, etc.

---

## Phase 7: Exports & Collaboration (Weeks 12-15)

### Tasks

1. **HTML Exporters** (9 types)
   - Project Overview
   - Character Overview
   - Scene Overview
   - Shot Overview
   - Props Overview
   - Daily Production Overview
   - Clapboard (for iPad)
   - Call Sheet HTML
   - Progress Overview

2. **PDF Generation**
   - Call sheets using PDFKit

3. **Final Draft Export**
   - .fdx file generation

4. **Git/Gitea Integration**
   - Clone, pull, push operations
   - Conflict detection
   - Project synchronization

---

## Python Files You MUST Reference

### AI Services
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/services/ai_assistant.py` (850+ lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/services/character_analyzer.py` (507 lines)
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/services/tts_service.py`

### Exports
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/exports/project_overview_html.py`
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/exports/clapboard_export.py`
- All files in `directorschair/exports/`

### Git Integration
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/services/gitea_client.py`

---

## Status Tracking

Update `docs/agents/agent_3_characters_ai/status.md` **DAILY**.

---

**You are the intelligence layer - AI, exports, and collaboration. Make it powerful, reliable, and fast!** 🤖
