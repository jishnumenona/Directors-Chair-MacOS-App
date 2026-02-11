# Director's Chair - AI Chat Feature Reference

## Overview
Director's Chair is a comprehensive filmmaking project management app for macOS built with SwiftUI. It provides tools for script editing, character design, shot planning, scheduling, budgeting, and more.

## AI Chat Assistant
- **Activation**: Double-Shift (rapid press) or Cmd+Shift+Space
- **Capabilities**: Project queries, character/scene analysis, web search, project modifications
- **Context-aware**: Automatically knows which view, scene, character, or shot is selected
- **Tool support**: Web search via DuckDuckGo, project modification with user confirmation, navigation

## App Views (Cmd+1 through Cmd+9)

### Overview (Cmd+1)
Project pitch deck with poster carousel, AI-generated summary, mood analysis radar chart, character cards, and key stats.

### Bubble View (Cmd+2)
Visual script editing where dialogues appear as colored bubbles, actions as gray blocks, and narrations as italic blocks. Scene selector at top. Right panel shows dialogue editor.

### Scenes (Cmd+3)
Scene list with detail view showing location, characters, props, shots, and production status. Scene overview image and emotional analysis.

### Assets (Cmd+4)
Media library for images, videos, and audio files organized by category.

### Vision Board (Cmd+5)
Freeform canvas with draggable mood/reference cards for visual brainstorming.

### Shot List (Cmd+6)
Cinematography planning with camera angle, lens (mm), aperture, shot type, movement. Reference media attachments. Links shots to script elements.

### Production (Cmd+7)
Four sub-tabs:
- **Schedule**: Shooting schedule with date/time/location planning
- **Cast & Crew**: Actor assignments, crew roles, contact info, rates
- **Accounting**: Budget categories, expenses, receipt scanning with AI
- **Equipment**: Camera, lighting, audio equipment library with allocations

### Story Design (Cmd+8)
Two sections:
- **Characters**: 25 personality traits (5 categories), physical appearance, biography, relationships, multi-angle AI portraits
- **Locations**: Location details, floor plans, environment variations, AI-generated images

### Settings (Cmd+9)
Project metadata: name, genre, type, duration, dates, director, company, languages.

## Panels
- **Navigator** (Cmd+Opt+1): Left sidebar with Outline, Markers, Versions, Comments
- **Timeline** (Cmd+Opt+2): Bottom panel with visual timeline, drag-to-reorder
- **Right Panel** (Cmd+Opt+3): Context-dependent detail panel

## Key Shortcuts
- Cmd+[/]: Navigate back/forward
- Cmd+Opt+A: Show all panels
- Cmd+Opt+H: Hide all panels
- Double-Shift: AI Chat
- Cmd+Shift+Space: AI Chat

## Export Formats
FDX (Final Draft), Fountain, HTML, PDF

## AI Features
- Character trait analysis from dialogue
- Character biography generation
- Character portrait generation (multi-angle)
- Location image generation
- Receipt analysis for budget
- Project summary generation
- AI Chat Assistant (this feature)
