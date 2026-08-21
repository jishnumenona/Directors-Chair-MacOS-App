//
//  SoftwarePreferencesView.swift
//  DirectorsChair-Desktop
//
//  Application-level preferences (Cmd+,).
//  Modern sidebar-driven layout matching the app's design vocabulary.
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit
import DirectorsChairViews

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
    // DC-0056: what the server can actually serve, per /health, plus the
    // on-device insights engine's state — drives the AI Services pane.
    @StateObject private var serviceHealth = ServiceHealthModel()
    @State private var selectedSection: PreferenceSection = .general
    @State private var showResetAlert = false

    // §2.18 remappable shortcuts.
    @ObservedObject private var shortcutStore = ShortcutStore.shared
    @State private var recordingShortcutId: String?
    @State private var shortcutConflictMessage: String?
    @State private var shortcutMonitor: Any?

    /// §2.17 proxy playback — stored under ProxyPlayback.preferenceKey so
    /// the Core resolver and this toggle can never disagree.
    @AppStorage(ProxyPlayback.preferenceKey) private var useProxyMedia = true

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

            // Media
            PrefCard(title: "MEDIA", icon: "film.stack") {
                VStack(alignment: .leading, spacing: 12) {
                    PrefToggle(label: "Play proxy media when available",
                               icon: "rectangle.compress.vertical",
                               isOn: $useProxyMedia)
                    Text("Takes and dailies play from lightweight 720p "
                         + "proxies generated in the background, so 4K "
                         + "footage scrubs smoothly. Originals are always "
                         + "kept and used for anything but playback.")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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

    /// The preferences field each AI function's choice lives in. The keys
    /// are asserted equal in tests — the pane and AIProviderSelection must
    /// read the same storage or a choice here would silently not apply.
    private func providerBinding(for function: AIFunction) -> Binding<String> {
        switch function {
        case .chat: return $prefs.aiChatProvider
        case .text: return $prefs.aiTextProvider
        case .image: return $prefs.aiImageProvider
        case .video: return $prefs.aiVideoProvider
        case .speech: return $prefs.aiSpeechProvider
        case .voiceReplies: return $prefs.voiceReplyEngine
        }
    }

    private var serviceHealthStatusRow: some View {
        HStack(spacing: 8) {
            switch serviceHealth.state {
            case .unchecked, .checking:
                ProgressView().controlSize(.mini)
                Text("Checking which services the server can offer…")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            case .checked(let health):
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                Text("Availability checked \(health.checkedAt.formatted(date: .omitted, time: .shortened)) — greyed services aren't enabled on the server")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            case .unreachable:
                Image(systemName: "wifi.slash")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                Text("Couldn't reach the server — availability unknown, choices still save")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Refresh") {
                Task { await serviceHealth.refresh() }
            }
            .font(.system(size: 10))
            .buttonStyle(.link)
            .accessibilityIdentifier("ai-services-refresh")
        }
    }

    /// On-device insights (DC-0055) run through their own engine, not the
    /// gateway — shown here so the pane covers EVERY AI function, with the
    /// engine's honest state instead of a picker it doesn't need yet (a
    /// second engine arrives with Apple FoundationModels).
    private var insightsEngineRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text("On-device Insights")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(insightsStateText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private var insightsStateText: String {
        switch serviceHealth.insightsAvailability {
        case .ready: return "Local model ready — runs on this Mac, free on every plan"
        case .needsDownload: return "Local model not downloaded yet — start it from any project's Overview"
        case .downloading(let progress): return "Downloading local model… \(Int(progress * 100))%"
        case .unavailable(let reason): return reason
        case nil: return "Checking…"
        }
    }

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

            // Services by function (DC-0056): every AI function lists the
            // services that can genuinely do it (AIProviderCatalog — the
            // same table the generation calls resolve through), and each
            // chip wears the server's live availability from /health. The
            // old hardcoded lists offered providers the wire had dropped.
            PrefCard(title: "SERVICES BY FUNCTION", icon: "cpu") {
                VStack(alignment: .leading, spacing: 14) {
                    serviceHealthStatusRow

                    ForEach(AIFunction.allCases) { function in
                        PrefServiceRow(
                            function: function,
                            health: serviceHealth.health,
                            selection: providerBinding(for: function)
                        )
                    }

                    Divider().opacity(0.5)
                    insightsEngineRow
                }
            }
            .task { await serviceHealth.refreshIfNeeded() }

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

    // §2.18: LIVE and editable, replacing a hand-typed reference list
    // that had already drifted from the real bindings (it claimed ⌘2 was
    // Script; ⌘2 is Bubble). Rows render what the store actually binds,
    // so the documentation can never lie again.
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Keyboard Shortcuts",
                          subtitle: "Click Rebind, then press the new keys. "
                          + "One combo drives one command.")

            let groups = Dictionary(grouping: ShortcutStore.commands,
                                    by: \.group)
            ForEach(["Navigation", "Panels", "Tools", "File", "Export"],
                    id: \.self) { group in
                if let commands = groups[group] {
                    PrefCard(title: group.uppercased(), icon: groupIcon(group)) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(commands) { command in
                                rebindableRow(command)
                            }
                        }
                    }
                }
            }

            if let message = shortcutConflictMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }

            HStack {
                Spacer()
                Button("Reset All to Defaults") {
                    shortcutStore.resetAll()
                    shortcutConflictMessage = nil
                }
                .disabled(shortcutStore.overrides.isEmpty)
            }

            PrefCard(title: "FIXED", icon: "lock") {
                VStack(alignment: .leading, spacing: 6) {
                    shortcutRow("Save / Open / New / Close",
                                shortcut: "⌘S · ⌘O · ⌘N · ⌘W")
                    shortcutRow("AI Chat Assistant", shortcut: "⇧⌘Space")
                    shortcutRow("Navigate Back / Forward", shortcut: "⌘[ · ⌘]")
                }
            }
        }
    }

    private func groupIcon(_ group: String) -> String {
        switch group {
        case "Navigation": return "rectangle.grid.1x2"
        case "Panels": return "sidebar.left"
        case "Tools": return "command"
        case "File": return "folder"
        case "Export": return "square.and.arrow.up"
        default: return "keyboard"
        }
    }

    private func rebindableRow(_ command: RebindableCommand) -> some View {
        HStack {
            Text(command.label)
                .font(.system(size: 11))
                .foregroundColor(.primary)
            if shortcutStore.isOverridden(command.id) {
                Button {
                    shortcutStore.reset(command.id)
                    shortcutConflictMessage = nil
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Back to \(command.defaultSpec.display)")
            }
            Spacer()
            if recordingShortcutId == command.id {
                Text("Press keys…  (esc cancels)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor)
                    .cornerRadius(4)
            } else {
                Text(shortcutStore.spec(for: command.id).display)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .cornerRadius(4)
                Button("Rebind") {
                    beginRecording(command.id)
                }
                .font(.system(size: 10))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    /// One local keyDown monitor while armed: the next chord becomes the
    /// binding (the store may refuse and say why), escape cancels. The
    /// monitor swallows the event so the chord doesn't ALSO fire whatever
    /// it currently means.
    private func beginRecording(_ id: String) {
        recordingShortcutId = id
        shortcutConflictMessage = nil
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer {
                if let monitor = shortcutMonitor {
                    NSEvent.removeMonitor(monitor)
                    shortcutMonitor = nil
                }
                recordingShortcutId = nil
            }
            if event.keyCode == 53 { return nil }   // escape = cancel
            guard let characters = event.charactersIgnoringModifiers,
                  let key = characters.first else { return nil }
            let flags = event.modifierFlags
            let spec = ShortcutSpec(key: String(key),
                                    command: flags.contains(.command),
                                    shift: flags.contains(.shift),
                                    option: flags.contains(.option),
                                    control: flags.contains(.control))
            shortcutConflictMessage = shortcutStore.set(spec, for: id)
            return nil
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

// MARK: - AI service health model (DC-0056)

/// Fetches what the gateway can serve (/health providers) and the local
/// insights engine's state, once per pane visit plus manual refresh.
@MainActor
final class ServiceHealthModel: ObservableObject {
    enum CheckState {
        case unchecked
        case checking
        case checked(AIProviderHealth)
        case unreachable
    }

    @Published private(set) var state: CheckState = .unchecked
    @Published private(set) var insightsAvailability: InsightAvailability?

    var health: AIProviderHealth? {
        if case .checked(let health) = state { return health }
        return nil
    }

    func refreshIfNeeded() async {
        if case .unchecked = state { await refresh() }
    }

    func refresh() async {
        state = .checking
        insightsAvailability = await MLXInsightEngine.shared.availability()
        if let health = await AIProviderHealthClient().fetch() {
            state = .checked(health)
        } else {
            state = .unreachable
        }
    }
}

// MARK: - AI service row (DC-0056)

/// PrefChipRow's availability-aware sibling: chips come from the catalog
/// (never hand-listed), unavailable services stay VISIBLE but disabled —
/// a hidden option looks like a removed feature, a greyed one explains
/// itself — and a selected-but-unavailable service warns inline.
private struct PrefServiceRow: View {
    let function: AIFunction
    let health: AIProviderHealth?
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 6)]

    private var options: [AIServiceOption] {
        AIProviderCatalog.options(for: function)
    }

    private func isAvailable(_ option: AIServiceOption) -> Bool {
        guard let health else { return true }   // unknown = don't block choosing
        return health.isAvailable(option)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: function.systemImage)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(function.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(options) { option in
                    let available = isAvailable(option)
                    let selected = selection == option.wireId
                    Button {
                        selection = option.wireId
                    } label: {
                        HStack(spacing: 4) {
                            if health != nil {
                                Circle()
                                    .fill(available ? Color.green : Color.secondary.opacity(0.4))
                                    .frame(width: 5, height: 5)
                            }
                            Text(option.displayName)
                                .font(.system(size: 10, weight: selected ? .semibold : .regular))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected ? Color.accentColor : Color(nsColor: .quaternarySystemFill))
                        )
                        .foregroundColor(selected ? .white : .primary)
                        .opacity(available ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .disabled(!available && !selected)
                    .help(available
                          ? option.displayName
                          : "\(option.displayName) isn't enabled on the server right now")
                    .accessibilityIdentifier("ai-service-\(function.rawValue)-\(option.wireId)")
                }
            }

            if let chosen = options.first(where: { $0.wireId == selection }),
               !isAvailable(chosen) {
                Label("\(chosen.displayName) is currently unavailable — calls will fail until the server enables it or you pick another service.",
                      systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
    }
}

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
