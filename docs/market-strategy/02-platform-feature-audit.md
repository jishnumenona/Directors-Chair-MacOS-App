# Platform Feature Audit — DirectorsChair

**Date**: March 2026
**Scope**: macOS Desktop, iPad (Slate), iOS (Planned), Cloud Server

---

## Platform Overview

| Platform | Status | Primary Function |
|----------|--------|-----------------|
| macOS Desktop | Production | Full production suite — writing, planning, management, AI |
| iPad (DirectorsChairSlate) | Production | Digital clapboard for on-set use |
| iOS Companion | Planned (17-week timeline) | On-set mobile workflows |
| Cloud Server | Production | AI proxy, auth, sync, usage tracking |

---

## Feature Inventory by Production Stage

### 1. Development / Writing

| Feature | Platform | Description |
|---------|----------|-------------|
| Screenplay Editor | Desktop | NSTextView-based rich text editor with paragraph-level element tracking |
| Script Elements | Desktop | Action, Dialogue, Narration, Note, SoundNote with parent-child grouping |
| Script Formatting | Desktop | Bold, italic, formatting toolbar; industry-standard screenplay layout |
| AI Script Import | Desktop | 5-pass AI pipeline: metadata → characters → props/locations → scene list → scene contents |
| Fountain Import/Export | Desktop | Industry-standard plain-text screenplay format |
| FDX Import/Export | Desktop | Final Draft XML format — full compatibility |
| PDF Export | Desktop | Print-ready screenplay with formatting |
| HTML Export | Desktop | Interactive web-viewable screenplay |
| Scene Navigation | Desktop | Scene jump navigator within screenplay |
| Transliteration | Desktop | Multi-language screenplay transliteration |
| Undo/Redo | Desktop | Full undo/redo with per-element dirty tracking, 500ms debounce |

### 2. Pre-Production / Story Design

| Feature | Platform | Description |
|---------|----------|-------------|
| Character Design | Desktop | 70+ physical appearance fields (height, weight, build, hair, eyes, skin, facial structure, distinguishing features) |
| **AI Psycho-Somatic Character Analysis** | Desktop | **INDUSTRY FIRST**: Reads all dialogue, actions, and narration for a character across the entire script. Produces structured 25-trait OCEAN (Big Five) personality profile (0-100 per trait) with per-trait explanations citing specific scenes, confidence scoring (0-100), archetype classification (Hero/Villain/Mentor/etc.), key character moments, 2-3 paragraph AI reasoning, and auto-extracted biography attributes (goals, fears, occupation). Uses Google Gemini at temperature 0.1 for precision. No other tool — screenwriting, production, or AI — does this. |
| Personality Traits (25 OCEAN) | Desktop | 5 categories × 5 traits: **Openness** (Creativity, Curiosity, Imagination, Open-mindedness, Artistic Interest), **Conscientiousness** (Organization, Diligence, Reliability, Self-discipline, Ambition), **Extraversion** (Sociability, Energy, Assertiveness, Enthusiasm, Talkativeness), **Agreeableness** (Empathy, Cooperation, Trust, Kindness, Politeness), **Neuroticism** (Anxiety, Moodiness, Sensitivity, Irritability, Self-consciousness). Pentagon chart visualization, category score bars, AI confidence ring gauge, per-trait gradient sliders. |
| Character Biography | Desktop | 8+ fields: Full Name, Nickname, Occupation, Affiliation, Background Story, Primary Goal, Secondary Goal, Hidden Motivation, Primary Fear, Weakness, Character Flaw, Character Arc Notes. AI auto-generation from top personality traits. |
| AI Confidence & Evidence | Desktop | AI analysis includes: confidence score (0-100) displayed as ring gauge, data sources (which scenes were analyzed), per-trait explanations with scene references, archetype classification, key character moments, trait ranges (min/max suggestions) |
| Character Image Generation | Desktop | 12-angle AI portraits (front, 3/4, profile, back, closeup, action pose) |
| Costume Management | Desktop | Multiple costumes per character with 4-angle images, scene associations, continuity tracking |
| Voice Personality Design | Desktop | 30 Gemini voices (14 female, 16 male) with AI auto-detection from personality profile. 7 voice parameters: voice selection, tone (8 options: Warm/Cold/Authoritative/Gentle/Intense/Playful/Serious/Mysterious), personality (8 options: Confident/Nervous/Sarcastic/Cheerful/Melancholic/Aggressive/Calm/Dramatic), pace (6 options), accent (6 presets + custom), age (Young/Middle-aged/Elderly), custom style override. TTS preview with audio playback. |
| Character Relationships | Desktop | Relationship mapping with 10 quick templates (Best friend, Romantic partner, Rival, Mentor, Student, Family, Colleague, Enemy, Ex-partner, Business partner), free-form descriptions, character avatar display |
| Location World-Building | Desktop | Location detail with floor plans, 3D cinema scenes, reference images, style attributes |
| Location AI Generation | Desktop | AI-generated location reference images from descriptions |
| Location 3D Virtual Cinema | Desktop | 3D environment configuration with camera position, focal length, lighting, 360° panoramas |
| Vision Board | Desktop | Pinterest-style mood board with draggable cards, image generation, multiple boards |
| Props Management | Desktop | Detailed prop tracking: specs, acquisition, rental, continuity states, fabrication details |
| Lighting Library | Desktop | Lighting setup presets: type, color, intensity, position |
| Film Style Presets | Desktop | Color grade, film look, aspect ratio, shutter angle, grain, LUT, lens profile |
| Effects Library | Desktop | VFX/SFX catalog with technical specs, scene/character associations |

### 3. Pre-Visualization / Cinematography

| Feature | Platform | Description |
|---------|----------|-------------|
| Shot Planning | Desktop | Camera angle, lens (mm), aperture, shot type, movement, duration, style override |
| Scene Connections | Desktop | Visual canvas linking dialogue/action to shots via Bezier curves |
| AI Shot Preview | Desktop | AI-generated shot preview images from description + camera settings |
| Shot Video Generation | Desktop | AI video generation with keyframe editing, multiple providers (Veo, Stability) |
| Keyframe Annotation | Desktop | Point-and-click image annotations for directing AI video generation |
| Take Management | Desktop | Take tracking: number, notes, rating (Circle/Alt/NG), timestamps, thumbnails |
| Reference Media | Desktop | Attach reference images/videos to shots with captions |
| Timeline View | Desktop | Interactive horizontal timeline with duration-based segments, viewport culling |
| Timeline Analysis | Desktop | AI scene duration estimation, dialogue rhythm analysis |
| Duration Estimation | Desktop | Automatic speech duration calculation from dialogue text |
| AI Chat Assistant | Desktop | Free-form AI queries about project, characters, story — real-time streaming |

### 4. Production / On-Set

| Feature | Platform | Description |
|---------|----------|-------------|
| Digital Clapboard | iPad | Smart slate with scene/shot/take metadata, sync markers |
| Live HDMI Capture | Desktop | Capture video from external cameras via HDMI capture cards |
| LUT Monitor | Desktop | Real-time color grading LUT application to live video feed |
| Video Playback | Desktop | Full playback: scrub, play/pause, speed control (0.5x-2.0x), metadata overlay |
| Audio Engine | Desktop | Synchronized audio playback with video |
| Production Schedule | Desktop | Calendar views (Monthly/Weekly/Daily), call times, wrap times, weather requirements |
| Daily Call Sheets | Desktop | Schedule items with required actors, crew, equipment, props per day |
| Equipment Allocation | Desktop | Assign equipment to specific shoots with condition tracking |
| TTS Dialogue Playback | Desktop | Text-to-speech for dialogue read-throughs per character voice |

### 5. Post-Production Bridge / Automated Assembly

| Feature | Platform | Description |
|---------|----------|-------------|
| Automated Footage Assembly | Desktop | Matches raw camera footage to script elements (scenes, shots, dialogue) using clapboard timecode sync, take metadata, and timeline positioning. Curates circle takes vs alternates vs no-goods. Builds a complete assembly edit automatically. |
| NLE Timeline Export (FCPXML) | Desktop | Exports pre-populated timeline to Final Cut Pro with footage placed on tracks by scene/shot order, markers for dialogue sync points, and take metadata as clip notes |
| NLE Timeline Export (AAF) | Desktop | Exports to Avid Media Composer's Advanced Authoring Format — the industry standard for studio post-production handoff |
| NLE Timeline Export (EDL) | Desktop | Exports Edit Decision List for DaVinci Resolve, Premiere Pro, and legacy systems — universal timeline interchange |
| Footage-to-Script Matching | Desktop, iPad | Clapboard sync markers from iPad slate + take timestamps are matched to shot/scene metadata. Each camera file is automatically associated with the correct script element. |
| Take Curation | Desktop | Circle takes (director's selects) are placed on the primary track. Alt takes on secondary tracks. NG takes excluded. Rating metadata preserved in NLE clip notes. |
| Multi-Camera Assembly | Desktop | Multiple camera angles for the same take are synced and placed on parallel tracks, enabling multi-cam editing workflow in the NLE |
| Assembly Preview | Desktop | Preview the auto-assembled timeline within DirectorsChair before export, with playback of footage in script order |
| Metadata Passthrough | Desktop | Scene name, shot description, character names, dialogue text, take notes, and ratings are embedded as clip metadata in the NLE export |

**Why this matters**: Today, every production relies on assistant editors to manually ingest footage, match it to script notes, and build an initial assembly. This takes 2-5 days on a short film and 4-12 weeks on a feature. DirectorsChair automates this entire process because it already knows the script structure, shot plan, scene connections, and take metadata. **No tool at any price point does this.**

### 6. Production Management

| Feature | Platform | Description |
|---------|----------|-------------|
| Budget Overview | Desktop | Total budget, spent, remaining, burn rate dashboard |
| Top Sheet | Desktop | High-level budget breakdown by category |
| Cost Report | Desktop | Detailed cost analysis by department |
| Expense Tracking | Desktop | Line-item expenses with approval workflow |
| Purchase Orders | Desktop | PO generation, vendor management, delivery tracking |
| Payroll | Desktop | Cast/crew rates, overtime, payment schedules |
| Cast Management | Desktop | Actor profiles, contact info, union status, contracts, agent details |
| Crew Management | Desktop | Department roles, expertise, availability, certifications |
| Team Organization | Desktop | Team groupings with responsibilities and department assignments |
| Equipment Library | Desktop | Inventory: brand, model, specs, condition, maintenance schedules, costs |

### 7. Collaboration / Cloud

| Feature | Platform | Description |
|---------|----------|-------------|
| Cloud Sync | Desktop, Server | Push/pull project sync via Gitea REST API |
| Git LFS | Desktop, Server | Large file support for media (images, videos, audio) |
| Per-User Isolation | Server | Projects stored under `/user/{username}/` |
| OAuth2 Authentication | Desktop, Server | PKCE flow with Gitea, Keychain storage, token refresh |
| AI Usage Tracking | Server | Per-user API call tracking, quotas, rate limiting |
| Offline Mode | Desktop | Full local editing without login; sync when reconnected |
| Project Explorer | Desktop | Browse and manage multiple projects |
| Version History | Desktop | Git-based project versioning |
| Comments | Desktop | Annotations/comments on project elements |

### 8. Onboarding / UX

| Feature | Platform | Description |
|---------|----------|-------------|
| Guided Tour | Desktop | Multi-step interactive tutorial with spotlight overlays |
| Splash Screen | Desktop | Welcome screen for first launch |
| Onboarding Flow | Desktop | Account setup, project creation, feature introduction |
| Example Projects | Desktop | Pre-loaded example projects for exploration |

---

## AI Provider Matrix

| Provider | Text | Image | Video | Speech | Status |
|----------|------|-------|-------|--------|--------|
| Google Gemini | ✅ Primary | — | — | — | Production |
| Google Imagen | — | ✅ Primary | — | — | Production |
| Google Veo | — | — | ✅ Primary | — | Production |
| OpenAI | ✅ | — | — | — | Available |
| Anthropic | ✅ | — | — | — | Available |
| DeepSeek | ✅ | — | — | — | Available (timeout issues) |
| Stability | — | ✅ | ✅ | — | Available |
| ElevenLabs | — | — | — | ✅ | Available |

---

## Data Model Depth

| Category | Models | Key Metrics |
|----------|--------|-------------|
| Story | Project, Sequence, Scene, Dialogue, Action, Narration, Note, SoundNote | 8 core models |
| Characters | Character, CharacterCostume | 70+ appearance fields, 25 personality traits, 12 image angles |
| Locations | Location, SceneLocationImage | Floor plans, 3D cinema, environment variations |
| Cinematography | Shot, Take, VideoKeyframe, KeyframeAnnotation, ReferenceMedia | Full shot-to-take pipeline |
| Production | ScheduleItem, CastMember, CrewMember, Team, EquipmentItem, EquipmentAllocation | 6 management models |
| Budget | ProjectBudget, BudgetCategory, Expense, PurchaseOrder, PayrollItem | 5 financial models |
| Assets | Prop, PropContinuityState, PropFabrication, Costume, Lighting, EffectDef, FilmStyle | 7 asset models |
| Collaboration | VisionCard, VisionCardBudget | Mood board system |
| **Total** | **40+ distinct data models** | |

---

## Export Format Coverage

| Format | Import | Export | Industry Use |
|--------|--------|--------|-------------|
| FDX (Final Draft XML) | ✅ | ✅ | Industry standard for professional screenwriting |
| Fountain | ✅ | ✅ | Open-source screenplay markup |
| PDF | — | ✅ | Universal distribution/printing |
| HTML | — | ✅ | Web viewing and sharing |
| FCPXML | — | ✅ | Final Cut Pro timeline interchange (footage assembly) |
| AAF | — | ✅ | Avid Media Composer timeline interchange (studio standard) |
| EDL | — | ✅ | Universal edit decision list (DaVinci Resolve, Premiere, legacy) |
| JSON | ✅ (native) | ✅ (native) | Internal project format |

---

## Technical Architecture

```
┌─────────────────────────────────────────────────┐
│                  macOS Desktop App               │
│  ┌──────────┐ ┌──────────────┐ ┌──────────────┐ │
│  │   Core   │ │    Views     │ │  Production  │ │
│  │  Models  │ │  (SwiftUI)   │ │   (Budget,   │ │
│  │  (40+)   │ │  (46+ files) │ │  Schedule)   │ │
│  └────┬─────┘ └──────┬───────┘ └──────┬───────┘ │
│       │               │                │         │
│  ┌────┴───────────────┴────────────────┴───────┐ │
│  │             Services Layer                   │ │
│  │  AI · Auth · Sync · TTS · Capture · Export   │ │
│  └────────────────────┬────────────────────────┘ │
└───────────────────────┼─────────────────────────┘
                        │ HTTPS
┌───────────────────────┼─────────────────────────┐
│              Cloud Server (Docker)               │
│  ┌─────────┐ ┌────────┐ ┌───────┐ ┌──────────┐ │
│  │ AI Proxy│ │  Auth  │ │ Gitea │ │ Postgres │ │
│  │ :8002   │ │ :8001  │ │ :3000 │ │  + Redis │ │
│  └─────────┘ └────────┘ └───────┘ └──────────┘ │
│              Nginx (SSL Termination)             │
└──────────────────────────────────────────────────┘
```
