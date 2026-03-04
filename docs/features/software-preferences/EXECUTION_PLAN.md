# Software Preferences - Execution Plan

## Objective
Design and implement a comprehensive, modern Software Preferences window (Cmd+,) for Director's Chair. The preferences must be app-level (not project-level), persisted via @AppStorage/UserDefaults, and styled to match the existing design vocabulary (AttributeCard, chips, measurement fields, etc.).

---

## Architecture

### Separation of Concerns
- **Software Preferences (Cmd+,)**: App-wide defaults that persist across all projects. Lives in the macOS `Settings` scene.
- **Project Settings (in-app)**: Per-project configuration stored in project.json. Already exists in `ProjectSettingsView.swift`.

### Data Flow
```
PreferencesManager (@AppStorage)
    ↓ .environmentObject
SoftwarePreferencesView (Settings scene)
    ↓ reads/writes
UserDefaults (automatic via @AppStorage)
    ↓ observed by
ViewModels & Views (read preferences for defaults)
```

### Files to Create
1. `DirectorsChair-Desktop/Models/AppPreferences.swift` - Constants, keys, default values
2. `DirectorsChair-Desktop/ViewModels/PreferencesManager.swift` - ObservableObject with @AppStorage
3. `DirectorsChair-Desktop/Views/Preferences/SoftwarePreferencesView.swift` - Main view with sidebar nav
4. `DirectorsChair-Desktop/Views/Preferences/PreferencesSections/` - Individual section views

### Files to Modify
1. `DirectorsChair_DesktopApp.swift` - Replace placeholder Settings scene
2. Wire PreferencesManager into environment chain

---

## Action Items

### Phase 1: Foundation
- [x] AI-1: Deep-dive codebase exploration (all features, settings, constants)
- [x] AI-2: Audit existing UserDefaults / @AppStorage usage
- [x] AI-3: Study UI design vocabulary (cards, chips, colors)
- [x] AI-4: Create FEATURE_LIST.md (93 configurable preferences cataloged)
- [x] AI-5: Create EXECUTION_PLAN.md (this document)
- [x] AI-6: Create PROGRESS.md (tracking document)

### Phase 2: Data Layer
- [x] AI-7: Create PrefKey enum + PreferencesManager.swift with all key constants and defaults
- [x] AI-8: Create PreferencesManager.swift (ObservableObject with @AppStorage bindings)

### Phase 3: UI Implementation
- [x] AI-9: Create SoftwarePreferencesView.swift (sidebar + content layout)
- [x] AI-10: Implement General section (Appearance, Startup, Saving, Tour)
- [x] AI-11: Implement Editor section (Typography, Behavior, Display)
- [x] AI-12: Implement Timeline section (Playback, Layout, Visibility, Colors)
- [x] AI-13: Implement Cinematography section (Shot Defaults, Video Gen, Colors)
- [x] AI-14: Implement AI Services section (Connection, Defaults, Generation, Usage)
- [x] AI-15: Implement Export section (Screenplay, PDF, Batch)
- [x] AI-16: Implement Keyboard Shortcuts section
- [x] AI-17: Implement Advanced section (Performance, Storage, Debug)

### Phase 4: Integration
- [x] AI-18: Wire SoftwarePreferencesView into macOS Settings scene
- [x] AI-19: Inject PreferencesManager as @EnvironmentObject through app hierarchy

### Phase 5: Verification
- [x] AI-20: Build project with xcodebuild
- [x] AI-21: Close running instance and relaunch
- [x] AI-22: Verify Cmd+, opens preferences window

---

## UI Design Specifications

### Layout: Sidebar + Content (macOS Settings Style)
```
┌─────────────────────────────────────────────────┐
│  Director's Chair Preferences                    │
├──────────┬──────────────────────────────────────┤
│          │                                       │
│ General  │  ┌─ APPEARANCE ─────────────────┐    │
│ Editor   │  │ Color Scheme   [System ▼]    │    │
│ Timeline │  │ Accent Color   [● Blue  ]    │    │
│ Cinema.  │  │ Sidebar Icons  [S] [M] [L]   │    │
│ AI       │  └──────────────────────────────┘    │
│ Export   │                                       │
│ Keys     │  ┌─ STARTUP ───────────────────┐    │
│ Advanced │  │ Default View   [Overview ▼]  │    │
│          │  │ Restore Last   [●──────]     │    │
│          │  └──────────────────────────────┘    │
│          │                                       │
└──────────┴──────────────────────────────────────┘
```

### Design Tokens (from PhysicalAppearanceTab.swift)
- Cards: `cornerRadius: 12`, `controlBackgroundColor.opacity(0.5)`, `separatorColor.opacity(0.3)` border
- Chips: `cornerRadius: 8`, accent on selected, `quaternarySystemFill` on unselected
- Text fields: `.plain` style, `quaternarySystemFill` background, `cornerRadius: 6`
- Section headers: 11pt semibold, uppercase, `.tracking(1.2)`, accent icon
- Spacing: 24pt between cards, 16pt within cards
- Window size: 780 x 560 (sidebar 180pt + content 600pt)

---

## Risk Mitigation
- No changes to existing settings behavior
- All new preferences default to current hardcoded values (zero behavior change)
- @AppStorage keys namespaced with "pref." prefix to avoid collision
- Preferences only read by views/ViewModels when available; graceful fallback
