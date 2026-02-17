//
//  TourStepDefinitions.swift
//  DirectorsChair-Desktop
//
//  Static definitions for spotlight tour steps and hint dot configurations
//

import Foundation

// MARK: - Tour Step Model

enum TooltipPosition {
    case above
    case below
    case left
    case right
}

struct TourStep {
    let targetId: String
    let title: String
    let description: String
    let tooltipPosition: TooltipPosition
}

// MARK: - Hint Dot Model

struct HintDotConfig {
    let id: String
    let title: String
    let description: String
}

// MARK: - Step Definitions

enum TourStepDefinitions {
    static let spotlightSteps: [TourStep] = [
        TourStep(
            targetId: "toolbar-Overview",
            title: "Project Overview",
            description: "Your project's home base — pitch deck, characters, and story at a glance.",
            tooltipPosition: .below
        ),
        TourStep(
            targetId: "toolbar-Script",
            title: "Screenplay Editor",
            description: "Write with professional formatting, AI assistance, and transliteration.",
            tooltipPosition: .below
        ),
        TourStep(
            targetId: "navigator-sidebar",
            title: "Navigator Sidebar",
            description: "Browse your outline, markers, versions, and comments.",
            tooltipPosition: .right
        ),
        TourStep(
            targetId: "toolbar-Scenes",
            title: "Scenes View",
            description: "Manage all your scenes — reorder, add details, track status.",
            tooltipPosition: .below
        ),
        TourStep(
            targetId: "timeline-panel",
            title: "Timeline",
            description: "See every scene, dialogue, and shot on a visual timeline. Drag the divider to resize.",
            tooltipPosition: .above
        ),
        TourStep(
            targetId: "toolbar-Story Design",
            title: "Story Design",
            description: "Build character profiles, design locations with AI-generated visuals.",
            tooltipPosition: .below
        ),
        TourStep(
            targetId: "toolbar-Production",
            title: "Production",
            description: "Schedule shoot days, manage cast & crew, track budgets.",
            tooltipPosition: .below
        ),
        TourStep(
            targetId: "toggle-navigator",
            title: "Panel Toggles",
            description: "Show or hide the navigator, timeline, and right panel. Cmd+Opt+1/2/3.",
            tooltipPosition: .below
        ),
    ]

    static let hintDots: [HintDotConfig] = [
        HintDotConfig(
            id: "hint-ai-chat",
            title: "AI Chat Assistant",
            description: "Press Shift twice to open the AI Chat assistant"
        ),
        HintDotConfig(
            id: "hint-export",
            title: "Export Screenplay",
            description: "Export screenplay to FDX, Fountain, or PDF"
        ),
        HintDotConfig(
            id: "hint-vision-board",
            title: "Vision Board",
            description: "Create mood boards and visual references"
        ),
        HintDotConfig(
            id: "hint-timeline-resize",
            title: "Resize Timeline",
            description: "Double-click to expand, drag to resize"
        ),
        HintDotConfig(
            id: "hint-transliteration",
            title: "Transliteration",
            description: "Write in Malayalam with real-time transliteration"
        ),
        HintDotConfig(
            id: "hint-shot-connections",
            title: "Shot Connections",
            description: "Connect script elements to shots visually"
        ),
    ]
}
