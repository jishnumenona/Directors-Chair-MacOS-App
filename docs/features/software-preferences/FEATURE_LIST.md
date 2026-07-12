# Software Preferences - Complete Feature List

## Overview
Comprehensive list of all configurable preferences for Director's Chair, organized by category. These are **application-level** preferences (Cmd+,), distinct from **project-level** settings which live in the Project Settings view.

---

## 1. GENERAL

### 1.1 Appearance
- [ ] **Color Scheme**: System / Light / Dark
- [ ] **Accent Color**: Default (blue) / Custom picker
- [ ] **Sidebar Icon Size**: Small / Medium / Large
- [ ] **Window Restore**: Reopen last window on launch (toggle)

### 1.2 Startup
- [ ] **Default View**: Which view to open on project load (Overview, Script, Bubble, etc.)
- [ ] **Restore Last Project**: Auto-load last opened project on launch (toggle)
- [ ] **Show Splash Screen**: Toggle splash animation on app launch

### 1.3 Saving
- [ ] **Auto-Save**: Enable/disable auto-save
- [ ] **Auto-Save Interval**: Debounce delay (250ms / 500ms / 1s / 2s)
- [ ] **Save Confirmation**: Prompt before closing unsaved projects

### 1.4 Guided Tour
- [ ] **Reset Guided Tour**: Re-enable spotlight tour
- [ ] **Reset Hint Dots**: Clear all discovered hints
- [ ] **Show Hints**: Global toggle for hint dot system

---

## 2. EDITOR (Script View)

### 2.1 Typography
- [ ] **Font Family**: Courier Prime / Courier / Courier New / System Monospace
- [ ] **Font Size**: Slider (10-24pt, default 12)
- [ ] **Line Height**: Multiplier (1.0x - 2.0x, default ~1.17)
- [ ] **Page Width**: Narrow / Standard / Wide

### 2.2 Behavior
- [ ] **Auto-Capitalize Scene Headings**: Toggle
- [ ] **Auto-Uppercase Character Names**: Toggle
- [ ] **Smart Quotes**: Replace straight quotes with curly
- [ ] **Tab Behavior**: Cycle element type / Insert tab character
- [ ] **Transliteration**: Enable transliteration input support

### 2.3 Display
- [ ] **Show Element Colors**: Color-code dialogue/action/narration
- [ ] **Show Page Breaks**: Visual page break indicators
- [ ] **Default Zoom Level**: Slider (0.5x - 4.0x, default 2.0x)
- [ ] **Highlight Active Line**: Subtle background on current line

---

## 3. TIMELINE

### 3.1 Playback & Estimation
- [ ] **Default WPM**: Words-per-minute for duration estimation (80-260, default 150)
- [ ] **Comma Pause**: Duration in seconds (0.1-0.5, default 0.25)
- [ ] **Sentence Pause**: Duration in seconds (0.25-1.0, default 0.50)
- [ ] **Ellipsis Pause**: Duration in seconds (0.3-1.0, default 0.60)
- [ ] **Action Duration**: Default action block duration (1-5s, default 2.0)
- [ ] **Sound Note Duration**: Default SFX block duration (1-10s, default 3.0)

### 3.2 Layout
- [ ] **Default Zoom (px/sec)**: Slider (20-240, default 60)
- [ ] **Row Height**: Compact (40) / Standard (56) / Spacious (72)
- [ ] **Row Gap**: Tight (6) / Standard (12) / Loose (18)

### 3.3 Default Visibility
- [ ] **Show Dialogue Track**: Toggle (default on)
- [ ] **Show Action Track**: Toggle (default on)
- [ ] **Show Narration Track**: Toggle (default on)
- [ ] **Show Sound Notes**: Toggle (default on)
- [ ] **Show Shot Labels**: Toggle (default on)
- [ ] **Show Shot Markers**: Toggle (default on)
- [ ] **Show Shot Connections**: Toggle (default off)
- [ ] **Show User Markers**: Toggle (default on)
- [ ] **Show Character Avatars**: Toggle (default on)

### 3.4 Colors
- [ ] **Dialogue Bubble Color**: Color picker (default #5D5D5D)
- [ ] **Action Bubble Color**: Color picker (default #FF9500)
- [ ] **Narration Bubble Color**: Color picker (default #9966CC)
- [ ] **Sound Note Color**: Color picker (default #17A2B8)
- [ ] **Scene Boundary Color**: Color picker (default #6AA9FF)
- [ ] **Reset Colors to Defaults**: Button

---

## 4. CINEMATOGRAPHY

### 4.1 Shot Defaults
- [ ] **Default Shot Status**: Planning / Storyboarded / Filmed / Edited
- [ ] **Default Shot Type**: Wide / Medium / Close-up / etc.

### 4.2 Video Generation
- [ ] **Default Video Provider**: Veo 3 / Sora 2 / Kling
- [ ] **Default Duration**: Slider (3-20s, default 5s)
- [ ] **Default Quality**: Standard / High / Ultra
- [ ] **Default Aspect Ratio**: 16:9 / 9:16 / 1:1
- [ ] **Default Camera Motion**: Static / Pan Left / Pan Right / Zoom In / Zoom Out / Dolly / Crane / Tracking

### 4.3 Shot Type Colors
- [ ] **Wide/Extreme Wide**: Color picker (default #00897B)
- [ ] **Medium**: Color picker (default #F57F17)
- [ ] **Close-up/Extreme Close-up**: Color picker (default #D32F2F)
- [ ] **Over-the-shoulder**: Color picker (default #7B1FA2)
- [ ] **POV**: Color picker (default #388E3C)
- [ ] **Insert/Cutaway**: Color picker (default #E64A19)
- [ ] **Reset Shot Colors**: Button

---

## 5. AI SERVICES

### 5.1 Connection
- [ ] **Proxy Server URL**: Text field (default from `AI_PROXY_URL` config / env; no hard-coded server address)
- [ ] **Connection Timeout**: Slider (30-300s, default 120s)
- [ ] **Health Check**: Button with status indicator

### 5.2 Defaults
- [ ] **Default Text Provider**: Dropdown (DeepSeek / Google / OpenAI / Anthropic)
- [ ] **Default Image Provider**: Dropdown (Google Imagen / Stability)
- [ ] **Default Video Provider**: Dropdown (Google Veo / Sora / Kling)

### 5.3 Generation Parameters
- [ ] **Default Temperature**: Slider (0.0-1.0, default 0.7)
- [ ] **Default Max Tokens (Chat)**: Number (500-8000, default 4000)
- [ ] **Default Max Tokens (Import)**: Number (1000-65000, default 65000)

### 5.4 Usage & Cost
- [ ] **Show Cost Estimates**: Toggle cost display before AI requests
- [ ] **Monthly Budget Alert**: Set a spending threshold for notifications
- [ ] **Reset Session Stats**: Button

---

## 6. EXPORT

### 6.1 Screenplay Export
- [ ] **Default Format**: Fountain / Final Draft FDX / PDF / HTML
- [ ] **Include Title Page**: Toggle
- [ ] **Include Page Numbers**: Toggle

### 6.2 PDF Settings
- [ ] **Paper Size**: US Letter / A4
- [ ] **Include Watermark**: Toggle with text field

### 6.3 Batch Export
- [ ] **Default Export Set**: Checkboxes (Script, Characters, Shot List, Schedule, Budget)

---

## 7. KEYBOARD SHORTCUTS

### 7.1 Display
- [ ] **Show All Shortcuts**: Searchable reference table
- [ ] **AI Chat Activation**: Double-Shift / Cmd+Shift+Space / Custom
- [ ] **View Navigation**: Display Cmd+1 through Cmd+9 mappings

---

## 8. ADVANCED

### 8.1 Performance
- [ ] **Max Timeline Text Length**: Characters before truncation (50-500, default 200)
- [ ] **Viewport Buffer**: Seconds of off-screen content to pre-render (5-30s, default 10)
- [ ] **Animation Duration**: Scale factor (0.5x-2.0x, default 1.0x)

### 8.2 Storage
- [ ] **Project Directory**: Default location for new projects
- [ ] **Chat History Location**: Path display
- [ ] **Clear Chat History**: Button with confirmation
- [ ] **Clear AI Usage Data**: Button with confirmation

### 8.3 Debug
- [ ] **Enable Debug Logging**: Toggle file-based debug log
- [ ] **Open Debug Log**: Button to reveal /tmp/directorschair_debug.log
- [ ] **Show Developer Info**: Toggle additional diagnostic info in UI

---

## Summary Statistics

| Category | Preference Count |
|----------|-----------------|
| General | 12 |
| Editor | 14 |
| Timeline | 22 |
| Cinematography | 14 |
| AI Services | 12 |
| Export | 7 |
| Keyboard Shortcuts | 3 |
| Advanced | 9 |
| **Total** | **93** |
