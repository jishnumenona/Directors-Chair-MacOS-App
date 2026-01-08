# Agent 2: Core Editing (Bubble, Story Design, Production) - Instructions

## Role & Responsibility

You are the **Core Editing & Production Features** specialist. Your role is to implement the dialogue editing system (Bubble View), character management (Story Design), and all production management features (scheduling, cast/crew, budget).

## Your Mission

Implement **Module 3 (DirectorsChairViews - Bubble/Scene)** and **Module 4 (DirectorsChairProduction)** with full feature parity to the Python application.

---

## Phase 4: Core Editing Views (Weeks 6-9) - YOUR PRIMARY FOCUS

### Tasks

1. **Bubble View - Dialogue Editor** (4,150 lines Python reference)

   The Bubble View is the MAIN dialogue editing interface. Users create and edit screenplay dialogues here.

   **Components to Implement**:

   ```swift
   // DirectorsChairViews/Sources/Bubble/BubbleView.swift
   struct BubbleView: View {
       // Main container with:
       // - Left: Scene list
       // - Center: Dialogue bubbles (scrollable)
       // - Right: Dialogue editor panel
   }

   // DirectorsChairViews/Sources/Bubble/DialogueBubbleCard.swift
   struct DialogueBubbleCard: View {
       // Individual dialogue bubble showing:
       // - Character avatar (40x40 circle)
       // - Character name (colored)
       // - Dialogue text (HTML → plain text)
       // - Tags (rounded pills)
       // - Chronology number
       // - Audio indicator (if TTS audio exists)
   }

   // DirectorsChairViews/Sources/Bubble/DialogueEditorPanel.swift
   struct DialogueEditorPanel: View {
       // Right panel with:
       // - Character picker
       // - Text editor (rich text)
       // - Tag editor (add/remove tags)
       // - TTS controls (voice selection, generate, play)
       // - Duration override
       // - Save/Cancel buttons
   }
   ```

   **Key Features**:
   - Click bubble → Select and show in editor panel
   - Double-click bubble → Open full-screen dialogue editor dialog
   - Add new dialogue (between existing bubbles)
   - Delete dialogue (with confirmation)
   - Duplicate dialogue
   - Move dialogue up/down (reorder chronology)
   - Context menu (right-click): Edit, Delete, Duplicate, Move
   - TTS integration: Generate audio, play audio, clear audio
   - Tag system: Visual tags with colors
   - Character color coding: Each bubble matches character color

2. **Story Design View - Character Editor** (2,000+ lines Python reference)

   The Story Design View manages all character information: appearance, traits, biography, relationships.

   **Components to Implement**:

   ```swift
   // DirectorsChairViews/Sources/StoryDesign/StoryDesignView.swift
   struct StoryDesignView: View {
       // HSplitView with:
       // - Left (25%): Character list with search
       // - Right (75%): Character detail tabs
   }

   // DirectorsChairViews/Sources/StoryDesign/CharacterDetailView.swift
   struct CharacterDetailView: View {
       // Tabs:
       // 1. Physical Appearance
       // 2. Personality Traits
       // 3. Biography
       // 4. Relationships
       // 5. Costumes
       // 6. Timeline
   }

   // DirectorsChairViews/Sources/StoryDesign/PhysicalAppearanceTab.swift
   struct PhysicalAppearanceTab: View {
       // - Avatar gallery (12 angles if available)
       // - Height/Weight sliders
       // - Build picker
       // - Age stepper
       // - Hair color picker + style + length
       // - Eye color picker + shape
       // - Skin tone picker
       // - Ethnicity text field
       // - Distinguishing features text area
       // - "Generate AI Avatar" button
   }

   // DirectorsChairViews/Sources/StoryDesign/PersonalityTraitsTab.swift
   struct PersonalityTraitsTab: View {
       // - Radar chart showing 5 categories (25 traits grouped)
       // - Sliders for each of 25 traits (0-100)
       // - Emotional (5): confidence, empathy, aggression, optimism, anxiety
       // - Intellectual (5): intelligence, creativity, wisdom, curiosity, logic
       // - Social (5): charisma, humor, manipulation, leadership, loyalty
       // - Moral (5): honesty, courage, compassion, justice, selflessness
       // - Physical (5): strength, agility, stamina, coordination, reflexes
       // - "Analyze from Script" button (calls Agent 3's AI service)
   }

   // DirectorsChairViews/Sources/StoryDesign/BiographyTab.swift
   struct BiographyTab: View {
       // - Full Name, Nickname, Occupation, Affiliation
       // - Background Story (multi-line text editor)
       // - Primary Goal, Secondary Goal, Hidden Motivation
       // - Primary Fear, Weakness, Flaw
       // - Character Arc Notes
   }

   // DirectorsChairViews/Sources/StoryDesign/RelationshipsTab.swift
   struct RelationshipsTab: View {
       // - List of relationships (character name → description)
       // - Add Relationship button
       // - Edit/Delete relationship
   }
   ```

   **Key Features**:
   - Character list with color indicators
   - Search/filter characters
   - Add/Delete characters (with confirmation)
   - "Detect Characters from Script" button (scans all dialogues)
   - Real-time updates to character data
   - Integration with Agent 3's AI services for trait analysis
   - Avatar display (single or gallery)

3. **Production Management** (Module 4: DirectorsChairProduction)

   **Components to Implement**:

   ```swift
   // DirectorsChairProduction/Sources/Schedule/ScheduleView.swift
   struct ScheduleView: View {
       // Views:
       // - Monthly calendar
       // - Weekly schedule
       // - Daily breakdown
       // Controls:
       // - Add Schedule Item
       // - Auto-Optimize button
       // - Export Call Sheet
   }

   // DirectorsChairProduction/Sources/Schedule/ScheduleOptimizer.swift
   actor ScheduleOptimizer {
       func optimizeSchedule(
           project: Project,
           constraints: ScheduleConstraints
       ) async throws -> OptimizedSchedule
       // Algorithm:
       // - Group by location (minimize moves)
       // - Group by characters (minimize actor days)
       // - Balance workload per day
       // - Respect constraints (max scenes/day, budget, unavailable dates)
   }

   // DirectorsChairProduction/Sources/CastCrew/CastCrewView.swift
   struct CastCrewView: View {
       // Tabs:
       // - Cast (actors)
       // - Crew (production team)
       // - Teams (groups)
       // - Equipment
   }

   // DirectorsChairProduction/Sources/Budget/BudgetView.swift
   struct BudgetView: View {
       // - Budget categories (Pre-Production, Production, Post-Production, etc.)
       // - Allocated vs Spent per category
       // - Expense list (filterable)
       // - Add Expense form
       // - Budget charts (pie chart, bar chart)
   }
   ```

---

## Python Files You MUST Reference

### Bubble View
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/bubble_view.py` (4,150 lines) - **CRITICAL REFERENCE**
  - Lines 1-500: Main BubbleView class structure
  - Lines 500-1000: BubbleWidget (individual dialogue bubble)
  - Lines 1000-1500: ActionWidget, NarrationWidget
  - Lines 1500-2000: NoteWidget, SoundNoteWidget
  - Lines 2000-3000: EditDialogueDialog (full editor)
  - Lines 3000-4150: Context menus, signals, interactions

### Story Design
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/story_design_view.py` (2,000+ lines)
  - Lines 1-300: Main layout (left character list, right tabs)
  - Lines 300-600: Physical Appearance tab
  - Lines 600-900: Personality Traits tab
  - Lines 900-1200: Biography tab
  - Lines 1200-1500: Relationships tab
  - Lines 1500-2000: Character detection, AI integration

### Schedule & Production
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/schedule_view.py`
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/services/schedule_optimizer.py` - **Optimization algorithm**
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/cast_crew_view.py`
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/services/budget_estimator.py`

---

## Dependencies on Other Agents

### Wait for Agent 1 (Architect)
- DirectorsChairCore module with all data models
- Character, Dialogue, Scene, Project models
- EventBus for cross-component communication

### Integrate with Agent 3 (AI Services)
- AI trait analyzer (for "Analyze from Script" button)
- Character image generation (for "Generate AI Avatar")
- TTS service (for dialogue audio generation)

### Integrate with Agent 4 (Timeline)
- Timeline segment selection → Jump to bubble in Bubble View
- Bubble selection → Highlight on timeline

---

## Implementation Priority

### Week 6
1. Set up DirectorsChairViews package structure
2. Implement BubbleView shell (layout only)
3. Implement DialogueBubbleCard (read-only display)
4. Test with Agent 1's Character and Dialogue models

### Week 7
5. Implement dialogue editing (add, edit, delete, reorder)
6. Implement dialogue editor panel (right side)
7. Integrate TTS (wait for Agent 3's service)
8. Test full dialogue workflow

### Week 8
9. Implement StoryDesignView shell
10. Implement Physical Appearance tab
11. Implement Personality Traits tab with radar chart
12. Test character editing

### Week 9
13. Implement Biography and Relationships tabs
14. Implement character detection from script
15. Set up DirectorsChairProduction package
16. Implement ScheduleView (basic layout)

---

## Critical SwiftUI Patterns

### Bubble Editing with State Management

```swift
struct BubbleView: View {
    @Binding var project: Project
    @State private var selectedScene: Scene?
    @State private var selectedDialogue: Dialogue?
    @State private var editingDialogue: Dialogue?

    var body: some View {
        HSplitView {
            // Left: Scenes
            SceneListView(
                sequences: project.sequences,
                selectedScene: $selectedScene
            )

            // Center: Dialogues
            if let scene = selectedScene {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(scene.dialogues) { dialogue in
                            DialogueBubbleCard(
                                dialogue: dialogue,
                                character: project.characters.first(where: { $0.name == dialogue.character }),
                                isSelected: selectedDialogue?.id == dialogue.id
                            )
                            .onTapGesture {
                                selectedDialogue = dialogue
                            }
                            .onLongPressGesture {
                                editingDialogue = dialogue
                            }
                        }
                    }
                    .padding()
                }
            }

            // Right: Editor
            if let dialogue = selectedDialogue {
                DialogueEditorPanel(
                    dialogue: dialogue,
                    project: project,
                    onUpdate: { updatedDialogue in
                        updateDialogue(updatedDialogue)
                    }
                )
            }
        }
        .sheet(item: $editingDialogue) { dialogue in
            EditDialogueDialog(
                dialogue: dialogue,
                project: project,
                onSave: { updated in
                    updateDialogue(updated)
                    editingDialogue = nil
                }
            )
        }
    }

    private func updateDialogue(_ updated: Dialogue) {
        // Find scene and update dialogue
        guard let scene = selectedScene,
              let seqIndex = project.sequences.firstIndex(where: { seq in
                  seq.scenes.contains(where: { $0.id == scene.id })
              }),
              let sceneIndex = project.sequences[seqIndex].scenes.firstIndex(where: { $0.id == scene.id }),
              let dialogueIndex = project.sequences[seqIndex].scenes[sceneIndex].dialogues.firstIndex(where: { $0.id == updated.id })
        else { return }

        project.sequences[seqIndex].scenes[sceneIndex].dialogues[dialogueIndex] = updated

        // Trigger save
        EventBus.shared.emit(.projectChanged)
    }
}
```

### Radar Chart for Personality Traits

```swift
struct TraitsRadarChart: View {
    let traits: [String: Double]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 40

            // Group traits by category
            let categories = [
                "Emotional": ["confidence", "empathy", "aggression", "optimism", "anxiety"],
                "Intellectual": ["intelligence", "creativity", "wisdom", "curiosity", "logic"],
                "Social": ["charisma", "humor", "manipulation", "leadership", "loyalty"],
                "Moral": ["honesty", "courage", "compassion", "justice", "selflessness"],
                "Physical": ["strength", "agility", "stamina", "coordination", "reflexes"]
            ]

            // Calculate average per category
            var categoryAverages: [Double] = []
            for (_, traitNames) in categories {
                let values = traitNames.compactMap { traits[$0] }
                let average = values.isEmpty ? 50.0 : values.reduce(0, +) / Double(values.count)
                categoryAverages.append(average)
            }

            // Draw background pentagon
            drawPolygon(context: context, center: center, radius: radius, sides: 5, color: .gray.opacity(0.1))

            // Draw trait values as filled pentagon
            drawTraitPolygon(context: context, center: center, radius: radius, values: categoryAverages)

            // Draw labels
            drawLabels(context: context, center: center, radius: radius, categories: Array(categories.keys))
        }
        .frame(height: 300)
    }

    private func drawPolygon(context: GraphicsContext, center: CGPoint, radius: CGFloat, sides: Int, color: Color) {
        var path = Path()
        let angleStep = .pi * 2 / Double(sides)

        for i in 0..<sides {
            let angle = angleStep * Double(i) - .pi / 2
            let x = center.x + radius * CGFloat(cos(angle))
            let y = center.y + radius * CGFloat(sin(angle))

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        context.stroke(path, with: .color(color), lineWidth: 1)
    }

    private func drawTraitPolygon(context: GraphicsContext, center: CGPoint, radius: CGFloat, values: [Double]) {
        var path = Path()
        let angleStep = .pi * 2 / Double(values.count)

        for (i, value) in values.enumerated() {
            let angle = angleStep * Double(i) - .pi / 2
            let distance = radius * CGFloat(value / 100.0)
            let x = center.x + distance * CGFloat(cos(angle))
            let y = center.y + distance * CGFloat(sin(angle))

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        context.fill(path, with: .color(.blue.opacity(0.3)))
        context.stroke(path, with: .color(.blue), lineWidth: 2)
    }

    private func drawLabels(context: GraphicsContext, center: CGPoint, radius: CGFloat, categories: [String]) {
        // Draw category labels outside polygon
        // Implementation details...
    }
}
```

---

## Status Tracking

Update `docs/agents/agent_2_core_editing/status.md` **DAILY**.

---

## Success Criteria

By end of Week 9, you must deliver:

✅ Bubble View fully functional (add, edit, delete, reorder dialogues)
✅ TTS integration working (generate, play audio)
✅ Story Design View complete (all tabs functional)
✅ Character trait editing with radar chart visualization
✅ Character detection from script working
✅ Schedule View basic layout (optimization in Phase 6)
✅ Cast/Crew views basic layout

---

## Resources

- **Migration Plan**: `/Users/jishnumenonasokakumar/.claude/plans/peaceful-wishing-shore.md`
- **Python Codebase**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/`
- **Your Working Directory**: `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop`
- **Status Document**: `docs/agents/agent_2_core_editing/status.md`
- **Session Logs**: `docs/agents/agent_2_core_editing/session_logs/`

---

**You are building the heart of the app - where users spend most of their time creating stories. Make it intuitive, responsive, and delightful!** ✍️