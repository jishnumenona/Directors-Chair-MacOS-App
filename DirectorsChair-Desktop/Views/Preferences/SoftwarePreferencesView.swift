//
//  SoftwarePreferencesView.swift
//  DirectorsChair-Desktop
//
//  Application-level preferences (Cmd+,).
//  Modern sidebar-driven layout matching the app's design vocabulary.
//

import SwiftUI
import AppKit

// MARK: - Preference Section Enum

enum PreferenceSection: String, CaseIterable, Identifiable {
    case general = "General"
    case editor = "Editor"
    case timeline = "Timeline"
    case cinematography = "Cinematography"
    case ai = "AI Services"
    case export = "Export"
    case shortcuts = "Shortcuts"
    case advanced = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .editor: return "doc.text"
        case .timeline: return "timeline.selection"
        case .cinematography: return "camera.aperture"
        case .ai: return "sparkles"
        case .export: return "square.and.arrow.up"
        case .shortcuts: return "keyboard"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Main Preferences View

struct SoftwarePreferencesView: View {
    @ObservedObject var prefs: PreferencesManager = .shared
    @State private var selectedSection: PreferenceSection = .general
    @State private var showResetAlert = false

    var body: some View {
        HSplitView {
            // Sidebar
            preferencesSidebar
                .frame(width: 180)

            // Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    sectionContent
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 780, height: 560)
        .alert("Reset All Preferences", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                prefs.resetAllToDefaults()
            }
        } message: {
            Text("This will reset all preferences to their default values. This cannot be undone.")
        }
    }

    // MARK: - Sidebar

    private var preferencesSidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(PreferenceSection.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.icon)
                            .font(.system(size: 12))
                            .foregroundColor(selectedSection == section ? .white : .accentColor)
                            .frame(width: 18)

                        Text(section.rawValue)
                            .font(.system(size: 12, weight: selectedSection == section ? .semibold : .regular))
                            .foregroundColor(selectedSection == section ? .white : .primary)

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedSection == section ? Color.accentColor : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Reset all button at bottom of sidebar
            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            Button {
                showResetAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                    Text("Reset All")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Reset all preferences to defaults")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Section Router

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .general:
            generalSection
        case .editor:
            editorSection
        case .timeline:
            timelineSection
        case .cinematography:
            cinematographySection
        case .ai:
            aiSection
        case .export:
            exportSection
        case .shortcuts:
            shortcutsSection
        case .advanced:
            advancedSection
        }
    }

    // =========================================================================
    // MARK: - 1. GENERAL
    // =========================================================================

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("General", subtitle: "Appearance, startup behavior, and saving")

            // Appearance
            PrefCard(title: "APPEARANCE", icon: "paintbrush") {
                VStack(alignment: .leading, spacing: 14) {
                    PrefChipRow(
                        label: "Color Scheme",
                        icon: "circle.lefthalf.filled",
                        options: ["system", "light", "dark"],
                        displayNames: ["System", "Light", "Dark"],
                        selection: $prefs.colorScheme
                    )

                    PrefChipRow(
                        label: "Sidebar Icon Size",
                        icon: "square.resize",
                        options: ["small", "medium", "large"],
                        displayNames: ["Small", "Medium", "Large"],
                        selection: $prefs.sidebarIconSize
                    )
                }
            }

            // Startup
            PrefCard(title: "STARTUP", icon: "power") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefChipRow(
                        label: "Default View on Launch",
                        icon: "rectangle.on.rectangle",
                        options: ["overview", "script", "bubble", "scenes", "storyDesign"],
                        displayNames: ["Overview", "Script", "Bubble", "Scenes", "Story Design"],
                        selection: $prefs.defaultView
                    )

                    PrefToggle(label: "Restore last project on launch", icon: "arrow.uturn.backward", isOn: $prefs.restoreLastProject)

                    PrefToggle(label: "Show splash screen animation", icon: "sparkle", isOn: $prefs.showSplashScreen)
                }
            }

            // Saving
            PrefCard(title: "SAVING", icon: "externaldrive") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefToggle(label: "Enable auto-save", icon: "arrow.triangle.2.circlepath", isOn: $prefs.autoSaveEnabled)

                    if prefs.autoSaveEnabled {
                        PrefSliderRow(
                            label: "Auto-save delay",
                            icon: "timer",
                            value: $prefs.autoSaveInterval,
                            range: 250...2000,
                            step: 250,
                            unit: "ms",
                            formatter: { "\(Int($0))" }
                        )
                    }

                    PrefToggle(label: "Confirm before closing unsaved projects", icon: "exclamationmark.triangle", isOn: $prefs.saveConfirmation)
                }
            }

            // Guided Tour
            PrefCard(title: "GUIDED TOUR", icon: "questionmark.circle") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefToggle(label: "Show hint dots throughout the app", icon: "lightbulb", isOn: $prefs.showHints)

                    HStack(spacing: 8) {
                        PrefActionButton(label: "Reset Guided Tour", icon: "arrow.counterclockwise") {
                            UserDefaults.standard.set(false, forKey: "tour.hasCompletedSpotlightTour")
                        }

                        PrefActionButton(label: "Reset Hint Dots", icon: "circle.dotted") {
                            UserDefaults.standard.removeObject(forKey: "tour.discoveredHints")
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: - 2. EDITOR
    // =========================================================================

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Editor", subtitle: "Script view typography, behavior, and display")

            // Typography
            PrefCard(title: "TYPOGRAPHY", icon: "textformat") {
                VStack(alignment: .leading, spacing: 14) {
                    PrefChipRow(
                        label: "Font Family",
                        icon: "a.magnify",
                        options: ["Courier Prime", "Courier", "Courier New", "Menlo"],
                        displayNames: ["Courier Prime", "Courier", "Courier New", "Menlo"],
                        selection: $prefs.editorFontFamily
                    )

                    PrefSliderRow(
                        label: "Font Size",
                        icon: "textformat.size",
                        value: $prefs.editorFontSize,
                        range: 10...24,
                        step: 1,
                        unit: "pt",
                        formatter: { "\(Int($0))" }
                    )

                    PrefSliderRow(
                        label: "Line Height",
                        icon: "arrow.up.and.down.text.horizontal",
                        value: $prefs.editorLineHeight,
                        range: 1.0...2.0,
                        step: 0.05,
                        unit: "x",
                        formatter: { String(format: "%.2f", $0) }
                    )

                    PrefChipRow(
                        label: "Page Width",
                        icon: "arrow.left.and.right",
                        options: ["narrow", "standard", "wide"],
                        displayNames: ["Narrow", "Standard", "Wide"],
                        selection: $prefs.editorPageWidth
                    )
                }
            }

            // Behavior
            PrefCard(title: "BEHAVIOR", icon: "hand.tap") {
                VStack(alignment: .leading, spacing: 10) {
                    PrefToggle(label: "Auto-capitalize scene headings", icon: "textformat.abc.dottedunderline", isOn: $prefs.autoCapSceneHeadings)
                    PrefToggle(label: "Auto-uppercase character names", icon: "person.text.rectangle", isOn: $prefs.autoUpperCharNames)
                    PrefToggle(label: "Smart quotes (curly)", icon: "quote.opening", isOn: $prefs.smartQuotes)
                    PrefToggle(label: "Tab key cycles element type", icon: "arrow.right.to.line", isOn: $prefs.tabCyclesType)
                    PrefToggle(label: "Enable transliteration input", icon: "globe", isOn: $prefs.transliteration)
                }
            }

            // Display
            PrefCard(title: "DISPLAY", icon: "eye") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefToggle(label: "Color-code script elements", icon: "paintpalette", isOn: $prefs.showElementColors)
                    PrefToggle(label: "Show page break indicators", icon: "arrow.down.to.line", isOn: $prefs.showPageBreaks)
                    PrefToggle(label: "Highlight active line", icon: "line.horizontal.star.fill.line.horizontal", isOn: $prefs.highlightActiveLine)

                    PrefSliderRow(
                        label: "Default Zoom Level",
                        icon: "magnifyingglass",
                        value: $prefs.defaultZoom,
                        range: 0.5...4.0,
                        step: 0.25,
                        unit: "x",
                        formatter: { String(format: "%.1f", $0) }
                    )
                }
            }
        }
    }

    // =========================================================================
    // MARK: - 3. TIMELINE
    // =========================================================================

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Timeline", subtitle: "Playback estimation, layout, track visibility, and colors")

            // Playback & Estimation
            PrefCard(title: "PLAYBACK ESTIMATION", icon: "speedometer") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefSliderRow(
                        label: "Words Per Minute",
                        icon: "text.word.spacing",
                        value: Binding(
                            get: { Double(prefs.timelineWPM) },
                            set: { prefs.timelineWPM = Int($0) }
                        ),
                        range: 80...260,
                        step: 5,
                        unit: "WPM",
                        formatter: { "\(Int($0))" }
                    )

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        PrefMiniSlider(label: "Comma Pause", value: $prefs.timelineCommaPause, range: 0.1...0.5, unit: "s")
                        PrefMiniSlider(label: "Sentence Pause", value: $prefs.timelineSentencePause, range: 0.25...1.0, unit: "s")
                        PrefMiniSlider(label: "Ellipsis Pause", value: $prefs.timelineEllipsisPause, range: 0.3...1.0, unit: "s")
                        PrefMiniSlider(label: "Action Duration", value: $prefs.timelineActionDuration, range: 1...5, unit: "s")
                    }

                    PrefSliderRow(
                        label: "Sound Note Duration",
                        icon: "speaker.wave.2",
                        value: $prefs.timelineSoundNoteDuration,
                        range: 1...10,
                        step: 0.5,
                        unit: "s",
                        formatter: { String(format: "%.1f", $0) }
                    )
                }
            }

            // Layout
            PrefCard(title: "LAYOUT", icon: "rectangle.split.3x1") {
                VStack(alignment: .leading, spacing: 14) {
                    PrefSliderRow(
                        label: "Default Zoom (pixels/sec)",
                        icon: "magnifyingglass",
                        value: $prefs.timelineDefaultZoom,
                        range: 20...240,
                        step: 10,
                        unit: "px/s",
                        formatter: { "\(Int($0))" }
                    )

                    PrefChipRow(
                        label: "Row Height",
                        icon: "arrow.up.and.down",
                        options: ["compact", "standard", "spacious"],
                        displayNames: ["Compact (40)", "Standard (56)", "Spacious (72)"],
                        selection: $prefs.timelineRowHeight
                    )

                    PrefChipRow(
                        label: "Row Gap",
                        icon: "distribute.vertical.center",
                        options: ["tight", "standard", "loose"],
                        displayNames: ["Tight (6)", "Standard (12)", "Loose (18)"],
                        selection: $prefs.timelineRowGap
                    )
                }
            }

            // Track Visibility
            PrefCard(title: "DEFAULT VISIBILITY", icon: "eye.slash") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    PrefToggle(label: "Dialogue Track", icon: "text.bubble", isOn: $prefs.showDialogueTrack)
                    PrefToggle(label: "Action Track", icon: "figure.walk", isOn: $prefs.showActionTrack)
                    PrefToggle(label: "Narration Track", icon: "text.quote", isOn: $prefs.showNarrationTrack)
                    PrefToggle(label: "Sound Notes", icon: "speaker.wave.2", isOn: $prefs.showSoundNotes)
                    PrefToggle(label: "Shot Labels", icon: "camera", isOn: $prefs.showShotLabels)
                    PrefToggle(label: "Shot Markers", icon: "mappin", isOn: $prefs.showShotMarkers)
                    PrefToggle(label: "Shot Connections", icon: "line.diagonal", isOn: $prefs.showShotConnections)
                    PrefToggle(label: "User Markers", icon: "flag", isOn: $prefs.showUserMarkers)
                    PrefToggle(label: "Character Avatars", icon: "person.crop.circle", isOn: $prefs.showCharAvatars)
                }
            }

            // Timeline Colors
            PrefCard(title: "ELEMENT COLORS", icon: "paintpalette") {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        PrefColorRow(label: "Dialogue", hex: $prefs.colorDialogue)
                        PrefColorRow(label: "Action", hex: $prefs.colorAction)
                        PrefColorRow(label: "Narration", hex: $prefs.colorNarration)
                        PrefColorRow(label: "Sound Note", hex: $prefs.colorSoundNote)
                        PrefColorRow(label: "Scene Boundary", hex: $prefs.colorSceneBoundary)
                    }

                    PrefActionButton(label: "Reset Colors to Defaults", icon: "arrow.counterclockwise") {
                        prefs.resetTimelineColors()
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: - 4. CINEMATOGRAPHY
    // =========================================================================

    private var cinematographySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Cinematography", subtitle: "Shot defaults, video generation, and shot type colors")

            // Shot Defaults
            PrefCard(title: "SHOT DEFAULTS", icon: "camera.viewfinder") {
                VStack(alignment: .leading, spacing: 14) {
                    PrefChipRow(
                        label: "Default Shot Status",
                        icon: "checkmark.circle",
                        options: ["planning", "storyboarded", "filmed", "edited"],
                        displayNames: ["Planning", "Storyboarded", "Filmed", "Edited"],
                        selection: $prefs.defaultShotStatus
                    )

                    PrefChipRow(
                        label: "Default Shot Type",
                        icon: "camera.metering.spot",
                        options: ["wide", "medium", "close-up", "over-the-shoulder", "pov", "insert", "cutaway"],
                        displayNames: ["Wide", "Medium", "Close-up", "OTS", "POV", "Insert", "Cutaway"],
                        selection: $prefs.defaultShotType
                    )
                }
            }

            // Video Generation
            PrefCard(title: "VIDEO GENERATION", icon: "film") {
                VStack(alignment: .leading, spacing: 14) {
                    PrefChipRow(
                        label: "Default Provider",
                        icon: "cpu",
                        options: ["veo3", "sora2", "kling"],
                        displayNames: ["Veo 3", "Sora 2", "Kling"],
                        selection: $prefs.videoProvider
                    )

                    PrefSliderRow(
                        label: "Default Duration",
                        icon: "timer",
                        value: $prefs.videoDuration,
                        range: 3...20,
                        step: 1,
                        unit: "s",
                        formatter: { "\(Int($0))" }
                    )

                    PrefChipRow(
                        label: "Default Quality",
                        icon: "dial.high",
                        options: ["Standard", "High", "Ultra"],
                        displayNames: ["Standard", "High", "Ultra"],
                        selection: $prefs.videoQuality
                    )

                    PrefChipRow(
                        label: "Aspect Ratio",
                        icon: "aspectratio",
                        options: ["16:9", "9:16", "1:1"],
                        displayNames: ["16:9", "9:16", "1:1"],
                        selection: $prefs.videoAspectRatio
                    )

                    PrefChipRow(
                        label: "Default Camera Motion",
                        icon: "move.3d",
                        options: ["Static", "Pan Left", "Pan Right", "Zoom In", "Zoom Out", "Dolly", "Crane", "Tracking"],
                        displayNames: ["Static", "Pan L", "Pan R", "Zoom In", "Zoom Out", "Dolly", "Crane", "Track"],
                        selection: $prefs.videoCameraMotion
                    )
                }
            }

            // Shot Type Colors
            PrefCard(title: "SHOT TYPE COLORS", icon: "swatchpalette") {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        PrefColorRow(label: "Wide / Ext. Wide", hex: $prefs.colorShotWide)
                        PrefColorRow(label: "Medium", hex: $prefs.colorShotMedium)
                        PrefColorRow(label: "Close-up / Ext. CU", hex: $prefs.colorShotCloseUp)
                        PrefColorRow(label: "Over-the-shoulder", hex: $prefs.colorShotOTS)
                        PrefColorRow(label: "POV", hex: $prefs.colorShotPOV)
                        PrefColorRow(label: "Insert / Cutaway", hex: $prefs.colorShotInsert)
                    }

                    PrefActionButton(label: "Reset Shot Colors to Defaults", icon: "arrow.counterclockwise") {
                        prefs.resetShotColors()
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: - 5. AI SERVICES
    // =========================================================================

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("AI Services", subtitle: "Connection, provider defaults, and generation parameters")

            // Connection
            PrefCard(title: "CONNECTION", icon: "network") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefTextField(label: "Proxy Server URL", icon: "link", placeholder: "http://...", text: $prefs.aiProxyURL)

                    PrefSliderRow(
                        label: "Connection Timeout",
                        icon: "clock",
                        value: $prefs.aiTimeout,
                        range: 30...300,
                        step: 10,
                        unit: "s",
                        formatter: { "\(Int($0))" }
                    )
                }
            }

            // Provider Defaults
            PrefCard(title: "DEFAULT PROVIDERS", icon: "cpu") {
                VStack(alignment: .leading, spacing: 14) {
                    PrefChipRow(
                        label: "Text Generation",
                        icon: "text.bubble",
                        options: ["deepseek", "google", "openai", "anthropic"],
                        displayNames: ["DeepSeek", "Google Gemini", "OpenAI", "Anthropic"],
                        selection: $prefs.aiTextProvider
                    )

                    PrefChipRow(
                        label: "Image Generation",
                        icon: "photo",
                        options: ["google_imagen", "stability"],
                        displayNames: ["Google Imagen", "Stability AI"],
                        selection: $prefs.aiImageProvider
                    )

                    PrefChipRow(
                        label: "Video Generation",
                        icon: "film",
                        options: ["google_veo", "sora", "kling"],
                        displayNames: ["Google Veo", "Sora", "Kling"],
                        selection: $prefs.aiVideoProvider
                    )
                }
            }

            // Generation Parameters
            PrefCard(title: "GENERATION PARAMETERS", icon: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefSliderRow(
                        label: "Temperature (creativity)",
                        icon: "thermometer.medium",
                        value: $prefs.aiTemperature,
                        range: 0.0...1.0,
                        step: 0.05,
                        unit: "",
                        formatter: { String(format: "%.2f", $0) }
                    )

                    PrefSliderRow(
                        label: "Max Tokens (Chat)",
                        icon: "number",
                        value: Binding(
                            get: { Double(prefs.aiMaxTokensChat) },
                            set: { prefs.aiMaxTokensChat = Int($0) }
                        ),
                        range: 500...8000,
                        step: 500,
                        unit: "tokens",
                        formatter: { "\(Int($0))" }
                    )

                    PrefSliderRow(
                        label: "Max Tokens (Import)",
                        icon: "doc.text.magnifyingglass",
                        value: Binding(
                            get: { Double(prefs.aiMaxTokensImport) },
                            set: { prefs.aiMaxTokensImport = Int($0) }
                        ),
                        range: 1000...65000,
                        step: 1000,
                        unit: "tokens",
                        formatter: { "\(Int($0))" }
                    )
                }
            }

            // Usage & Cost
            PrefCard(title: "USAGE & COST", icon: "dollarsign.circle") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefToggle(label: "Show cost estimates before AI requests", icon: "exclamationmark.bubble", isOn: $prefs.aiShowCostEstimates)

                    PrefSliderRow(
                        label: "Monthly Budget Alert",
                        icon: "bell.badge",
                        value: $prefs.aiMonthlyBudget,
                        range: 0...100,
                        step: 5,
                        unit: "$",
                        formatter: { $0 == 0 ? "Off" : String(format: "$%.0f", $0) }
                    )
                }
            }
        }
    }

    // =========================================================================
    // MARK: - 6. EXPORT
    // =========================================================================

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Export", subtitle: "Default formats, PDF settings, and batch export")

            // Screenplay Export
            PrefCard(title: "SCREENPLAY EXPORT", icon: "doc.richtext") {
                VStack(alignment: .leading, spacing: 14) {
                    PrefChipRow(
                        label: "Default Format",
                        icon: "doc",
                        options: ["fountain", "fdx", "pdf", "html"],
                        displayNames: ["Fountain", "Final Draft FDX", "PDF", "HTML"],
                        selection: $prefs.exportDefaultFormat
                    )

                    PrefToggle(label: "Include title page", icon: "rectangle.and.text.magnifyingglass", isOn: $prefs.exportIncludeTitlePage)
                    PrefToggle(label: "Include page numbers", icon: "number.circle", isOn: $prefs.exportIncludePageNumbers)
                }
            }

            // PDF Settings
            PrefCard(title: "PDF SETTINGS", icon: "doc.text.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    PrefChipRow(
                        label: "Paper Size",
                        icon: "doc",
                        options: ["letter", "a4"],
                        displayNames: ["US Letter", "A4"],
                        selection: $prefs.exportPaperSize
                    )

                    PrefToggle(label: "Include watermark", icon: "drop.triangle", isOn: $prefs.exportIncludeWatermark)

                    if prefs.exportIncludeWatermark {
                        PrefTextField(label: "Watermark Text", icon: "textformat", placeholder: "DRAFT", text: $prefs.exportWatermarkText)
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: - 7. KEYBOARD SHORTCUTS
    // =========================================================================

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Keyboard Shortcuts", subtitle: "Quick reference for all keyboard shortcuts")

            PrefCard(title: "VIEW NAVIGATION", icon: "rectangle.grid.1x2") {
                VStack(alignment: .leading, spacing: 6) {
                    shortcutRow("Overview", shortcut: "Cmd + 1")
                    shortcutRow("Script", shortcut: "Cmd + 2")
                    shortcutRow("Bubble View", shortcut: "Cmd + 3")
                    shortcutRow("Shot List", shortcut: "Cmd + 4")
                    shortcutRow("Scenes", shortcut: "Cmd + 5")
                    shortcutRow("Assets", shortcut: "Cmd + 6")
                    shortcutRow("Vision Board", shortcut: "Cmd + 7")
                    shortcutRow("Production", shortcut: "Cmd + 8")
                    shortcutRow("Story Design", shortcut: "Cmd + 9")
                    shortcutRow("Project Settings", shortcut: "Cmd + 0")
                }
            }

            PrefCard(title: "AI & TOOLS", icon: "sparkles") {
                VStack(alignment: .leading, spacing: 6) {
                    shortcutRow("AI Chat Assistant", shortcut: "Double-Shift or Cmd + Shift + Space")
                    shortcutRow("Navigate Back", shortcut: "Cmd + [")
                    shortcutRow("Navigate Forward", shortcut: "Cmd + ]")
                }
            }

            PrefCard(title: "EXPORT", icon: "square.and.arrow.up") {
                VStack(alignment: .leading, spacing: 6) {
                    shortcutRow("Export Fountain", shortcut: "Cmd + Shift + E")
                    shortcutRow("Export PDF", shortcut: "Cmd + Shift + P")
                    shortcutRow("Batch Export", shortcut: "Cmd + Shift + Opt + E")
                }
            }
        }
    }

    // =========================================================================
    // MARK: - 8. ADVANCED
    // =========================================================================

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Advanced", subtitle: "Performance tuning, storage, and debug options")

            // Performance
            PrefCard(title: "PERFORMANCE", icon: "gauge.with.dots.needle.67percent") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefSliderRow(
                        label: "Max Timeline Text Length",
                        icon: "text.line.last.and.arrowtriangle.forward",
                        value: Binding(
                            get: { Double(prefs.maxTimelineTextLength) },
                            set: { prefs.maxTimelineTextLength = Int($0) }
                        ),
                        range: 50...500,
                        step: 25,
                        unit: "chars",
                        formatter: { "\(Int($0))" }
                    )

                    PrefSliderRow(
                        label: "Viewport Buffer",
                        icon: "rectangle.dashed",
                        value: $prefs.viewportBuffer,
                        range: 5...30,
                        step: 1,
                        unit: "s",
                        formatter: { "\(Int($0))" }
                    )

                    PrefSliderRow(
                        label: "Animation Speed Scale",
                        icon: "hare",
                        value: $prefs.animationScale,
                        range: 0.5...2.0,
                        step: 0.25,
                        unit: "x",
                        formatter: { String(format: "%.2f", $0) }
                    )
                }
            }

            // Storage
            PrefCard(title: "STORAGE", icon: "internaldrive") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Project Directory")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Text(prefs.projectDirectory.isEmpty ? "~/Directors Chair/" : prefs.projectDirectory)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(6)

                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                prefs.projectDirectory = url.path
                            }
                        } label: {
                            Text("Browse...")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(nsColor: .quaternarySystemFill))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().opacity(0.3)

                    HStack(spacing: 10) {
                        PrefActionButton(label: "Clear Chat History", icon: "trash") {
                            let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                                .appendingPathComponent("DirectorsChair/chat_history")
                            if let path = path {
                                try? FileManager.default.removeItem(at: path)
                            }
                        }

                        PrefActionButton(label: "Clear AI Usage Data", icon: "chart.bar.xaxis") {
                            let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                                .appendingPathComponent("DirectorsChair/ai_usage")
                            if let path = path {
                                try? FileManager.default.removeItem(at: path)
                            }
                        }
                    }
                }
            }

            // Debug
            PrefCard(title: "DEBUG", icon: "ladybug") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefToggle(label: "Enable file-based debug logging", icon: "doc.text", isOn: $prefs.enableDebugLogging)
                    PrefToggle(label: "Show developer info in UI", icon: "info.circle", isOn: $prefs.showDeveloperInfo)

                    PrefActionButton(label: "Open Debug Log", icon: "doc.text.magnifyingglass") {
                        NSWorkspace.shared.selectFile("/tmp/directorschair_debug.log", inFileViewerRootedAtPath: "/tmp")
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: - Shared Helpers
    // =========================================================================

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private func shortcutRow(_ action: String, shortcut: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 11))
                .foregroundColor(.primary)
            Spacer()
            Text(shortcut)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(4)
        }
    }
}

// =========================================================================
// MARK: - Reusable Preference Components
// =========================================================================

// MARK: - Preference Card

private struct PrefCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preference Toggle

private struct PrefToggle: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.primary)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }
}

// MARK: - Preference Chip Row

private struct PrefChipRow: View {
    let label: String
    let icon: String
    let options: [String]
    let displayNames: [String]
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 80), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(Array(zip(options, displayNames)), id: \.0) { option, display in
                    Button {
                        selection = option
                    } label: {
                        Text(display)
                            .font(.system(size: 10, weight: selection == option ? .semibold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selection == option ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                            )
                            .foregroundColor(selection == option ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Preference Slider Row

private struct PrefSliderRow: View {
    let label: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let formatter: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(formatter(value))\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
            }

            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
                .tint(.accentColor.opacity(0.6))
        }
    }
}

// MARK: - Preference Mini Slider (compact, for grids)

private struct PrefMiniSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f\(unit)", value))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
            }

            Slider(value: $value, in: range)
                .controlSize(.mini)
                .tint(.accentColor.opacity(0.6))
        }
        .padding(8)
        .background(Color(nsColor: .quaternarySystemFill))
        .cornerRadius(8)
    }
}

// MARK: - Preference Text Field

private struct PrefTextField: View {
    let label: String
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
                .background(Color(nsColor: .quaternarySystemFill))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preference Color Row

private struct PrefColorRow: View {
    let label: String
    @Binding var hex: String
    @State private var color: Color = .gray

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1))

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.primary)

            Spacer()

            Text(hex)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))

            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 24, height: 24)
        }
        .padding(.vertical, 2)
        .onAppear { color = Color(hex: hex) }
        .onChange(of: color) {
            hex = color.toHex()
        }
        .onChange(of: hex) {
            color = Color(hex: hex)
        }
    }
}

// MARK: - Preference Action Button

private struct PrefActionButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .quaternarySystemFill))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Hex Conversion Helpers

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0.5; g = 0.5; b = 0.5
        }
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return "#808080" }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
