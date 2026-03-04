//
//  PreferencesManager.swift
//  DirectorsChair-Desktop
//
//  Centralized application preferences using @AppStorage.
//  All keys are namespaced with "pref." to avoid collision with existing UserDefaults.
//

import SwiftUI
import Combine

// MARK: - Preference Keys

enum PrefKey {
    // General > Appearance
    static let colorScheme = "pref.general.colorScheme"            // "system" | "light" | "dark"
    static let sidebarIconSize = "pref.general.sidebarIconSize"    // "small" | "medium" | "large"

    // General > Startup
    static let defaultView = "pref.general.defaultView"            // AppView rawValue
    static let restoreLastProject = "pref.general.restoreLastProject"
    static let showSplashScreen = "pref.general.showSplashScreen"

    // General > Saving
    static let autoSaveEnabled = "pref.general.autoSaveEnabled"
    static let autoSaveInterval = "pref.general.autoSaveInterval"  // ms
    static let saveConfirmation = "pref.general.saveConfirmation"

    // General > Tour
    static let showHints = "pref.general.showHints"

    // Editor > Typography
    static let editorFontFamily = "pref.editor.fontFamily"        // "Courier Prime" etc.
    static let editorFontSize = "pref.editor.fontSize"            // 10-24
    static let editorLineHeight = "pref.editor.lineHeight"        // 1.0-2.0 multiplier
    static let editorPageWidth = "pref.editor.pageWidth"          // "narrow" | "standard" | "wide"

    // Editor > Behavior
    static let autoCapSceneHeadings = "pref.editor.autoCapSceneHeadings"
    static let autoUpperCharNames = "pref.editor.autoUpperCharNames"
    static let smartQuotes = "pref.editor.smartQuotes"
    static let tabCyclesType = "pref.editor.tabCyclesType"
    static let transliteration = "pref.editor.transliteration"

    // Editor > Display
    static let showElementColors = "pref.editor.showElementColors"
    static let showPageBreaks = "pref.editor.showPageBreaks"
    static let defaultZoom = "pref.editor.defaultZoom"            // 0.5-4.0
    static let highlightActiveLine = "pref.editor.highlightActiveLine"

    // Timeline > Playback
    static let timelineWPM = "pref.timeline.wpm"                  // 80-260
    static let timelineCommaPause = "pref.timeline.commaPause"    // seconds
    static let timelineSentencePause = "pref.timeline.sentencePause"
    static let timelineEllipsisPause = "pref.timeline.ellipsisPause"
    static let timelineActionDuration = "pref.timeline.actionDuration"
    static let timelineSoundNoteDuration = "pref.timeline.soundNoteDuration"

    // Timeline > Layout
    static let timelineDefaultZoom = "pref.timeline.defaultZoom"  // px/sec 20-240
    static let timelineRowHeight = "pref.timeline.rowHeight"      // "compact" | "standard" | "spacious"
    static let timelineRowGap = "pref.timeline.rowGap"            // "tight" | "standard" | "loose"

    // Timeline > Visibility
    static let showDialogueTrack = "pref.timeline.showDialogue"
    static let showActionTrack = "pref.timeline.showAction"
    static let showNarrationTrack = "pref.timeline.showNarration"
    static let showSoundNotes = "pref.timeline.showSoundNotes"
    static let showShotLabels = "pref.timeline.showShotLabels"
    static let showShotMarkers = "pref.timeline.showShotMarkers"
    static let showShotConnections = "pref.timeline.showShotConnections"
    static let showUserMarkers = "pref.timeline.showUserMarkers"
    static let showCharAvatars = "pref.timeline.showCharAvatars"

    // Timeline > Colors
    static let colorDialogue = "pref.timeline.colorDialogue"
    static let colorAction = "pref.timeline.colorAction"
    static let colorNarration = "pref.timeline.colorNarration"
    static let colorSoundNote = "pref.timeline.colorSoundNote"
    static let colorSceneBoundary = "pref.timeline.colorSceneBoundary"

    // Cinematography > Defaults
    static let defaultShotStatus = "pref.cinema.defaultShotStatus"
    static let defaultShotType = "pref.cinema.defaultShotType"

    // Cinematography > Video Generation
    static let videoProvider = "pref.cinema.videoProvider"
    static let videoDuration = "pref.cinema.videoDuration"
    static let videoQuality = "pref.cinema.videoQuality"
    static let videoAspectRatio = "pref.cinema.videoAspectRatio"
    static let videoCameraMotion = "pref.cinema.videoCameraMotion"

    // Cinematography > Shot Colors
    static let colorShotWide = "pref.cinema.colorShotWide"
    static let colorShotMedium = "pref.cinema.colorShotMedium"
    static let colorShotCloseUp = "pref.cinema.colorShotCloseUp"
    static let colorShotOTS = "pref.cinema.colorShotOTS"
    static let colorShotPOV = "pref.cinema.colorShotPOV"
    static let colorShotInsert = "pref.cinema.colorShotInsert"

    // AI > Connection
    static let aiProxyURL = "pref.ai.proxyURL"
    static let aiTimeout = "pref.ai.timeout"                      // seconds

    // AI > Defaults
    static let aiTextProvider = "pref.ai.textProvider"
    static let aiImageProvider = "pref.ai.imageProvider"
    static let aiVideoProvider = "pref.ai.videoProvider"

    // AI > Generation
    static let aiTemperature = "pref.ai.temperature"              // 0.0-1.0
    static let aiMaxTokensChat = "pref.ai.maxTokensChat"
    static let aiMaxTokensImport = "pref.ai.maxTokensImport"

    // AI > Usage
    static let aiShowCostEstimates = "pref.ai.showCostEstimates"
    static let aiMonthlyBudget = "pref.ai.monthlyBudget"          // dollar amount, 0 = disabled

    // Export > Screenplay
    static let exportDefaultFormat = "pref.export.defaultFormat"   // "fountain" | "fdx" | "pdf" | "html"
    static let exportIncludeTitlePage = "pref.export.includeTitlePage"
    static let exportIncludePageNumbers = "pref.export.includePageNumbers"

    // Export > PDF
    static let exportPaperSize = "pref.export.paperSize"          // "letter" | "a4"
    static let exportIncludeWatermark = "pref.export.includeWatermark"
    static let exportWatermarkText = "pref.export.watermarkText"

    // Advanced > Performance
    static let maxTimelineTextLength = "pref.advanced.maxTimelineTextLength"
    static let viewportBuffer = "pref.advanced.viewportBuffer"
    static let animationScale = "pref.advanced.animationScale"

    // Advanced > Storage
    static let projectDirectory = "pref.advanced.projectDirectory"

    // Advanced > Debug
    static let enableDebugLogging = "pref.advanced.enableDebugLogging"
    static let showDeveloperInfo = "pref.advanced.showDeveloperInfo"
}

// MARK: - Preferences Manager

@MainActor
class PreferencesManager: ObservableObject {

    static let shared = PreferencesManager()

    // MARK: - General > Appearance

    @AppStorage(PrefKey.colorScheme) var colorScheme: String = "system"
    @AppStorage(PrefKey.sidebarIconSize) var sidebarIconSize: String = "medium"

    // MARK: - General > Startup

    @AppStorage(PrefKey.defaultView) var defaultView: String = "overview"
    @AppStorage(PrefKey.restoreLastProject) var restoreLastProject: Bool = true
    @AppStorage(PrefKey.showSplashScreen) var showSplashScreen: Bool = true

    // MARK: - General > Saving

    @AppStorage(PrefKey.autoSaveEnabled) var autoSaveEnabled: Bool = true
    @AppStorage(PrefKey.autoSaveInterval) var autoSaveInterval: Double = 500  // ms
    @AppStorage(PrefKey.saveConfirmation) var saveConfirmation: Bool = true

    // MARK: - General > Tour

    @AppStorage(PrefKey.showHints) var showHints: Bool = true

    // MARK: - Editor > Typography

    @AppStorage(PrefKey.editorFontFamily) var editorFontFamily: String = "Courier Prime"
    @AppStorage(PrefKey.editorFontSize) var editorFontSize: Double = 12
    @AppStorage(PrefKey.editorLineHeight) var editorLineHeight: Double = 1.17
    @AppStorage(PrefKey.editorPageWidth) var editorPageWidth: String = "standard"

    // MARK: - Editor > Behavior

    @AppStorage(PrefKey.autoCapSceneHeadings) var autoCapSceneHeadings: Bool = true
    @AppStorage(PrefKey.autoUpperCharNames) var autoUpperCharNames: Bool = true
    @AppStorage(PrefKey.smartQuotes) var smartQuotes: Bool = true
    @AppStorage(PrefKey.tabCyclesType) var tabCyclesType: Bool = true
    @AppStorage(PrefKey.transliteration) var transliteration: Bool = false

    // MARK: - Editor > Display

    @AppStorage(PrefKey.showElementColors) var showElementColors: Bool = true
    @AppStorage(PrefKey.showPageBreaks) var showPageBreaks: Bool = true
    @AppStorage(PrefKey.defaultZoom) var defaultZoom: Double = 2.0
    @AppStorage(PrefKey.highlightActiveLine) var highlightActiveLine: Bool = false

    // MARK: - Timeline > Playback

    @AppStorage(PrefKey.timelineWPM) var timelineWPM: Int = 150
    @AppStorage(PrefKey.timelineCommaPause) var timelineCommaPause: Double = 0.25
    @AppStorage(PrefKey.timelineSentencePause) var timelineSentencePause: Double = 0.50
    @AppStorage(PrefKey.timelineEllipsisPause) var timelineEllipsisPause: Double = 0.60
    @AppStorage(PrefKey.timelineActionDuration) var timelineActionDuration: Double = 2.0
    @AppStorage(PrefKey.timelineSoundNoteDuration) var timelineSoundNoteDuration: Double = 3.0

    // MARK: - Timeline > Layout

    @AppStorage(PrefKey.timelineDefaultZoom) var timelineDefaultZoom: Double = 60
    @AppStorage(PrefKey.timelineRowHeight) var timelineRowHeight: String = "standard"
    @AppStorage(PrefKey.timelineRowGap) var timelineRowGap: String = "standard"

    // MARK: - Timeline > Visibility

    @AppStorage(PrefKey.showDialogueTrack) var showDialogueTrack: Bool = true
    @AppStorage(PrefKey.showActionTrack) var showActionTrack: Bool = true
    @AppStorage(PrefKey.showNarrationTrack) var showNarrationTrack: Bool = true
    @AppStorage(PrefKey.showSoundNotes) var showSoundNotes: Bool = true
    @AppStorage(PrefKey.showShotLabels) var showShotLabels: Bool = true
    @AppStorage(PrefKey.showShotMarkers) var showShotMarkers: Bool = true
    @AppStorage(PrefKey.showShotConnections) var showShotConnections: Bool = false
    @AppStorage(PrefKey.showUserMarkers) var showUserMarkers: Bool = true
    @AppStorage(PrefKey.showCharAvatars) var showCharAvatars: Bool = true

    // MARK: - Timeline > Colors

    @AppStorage(PrefKey.colorDialogue) var colorDialogue: String = "#5D5D5D"
    @AppStorage(PrefKey.colorAction) var colorAction: String = "#FF9500"
    @AppStorage(PrefKey.colorNarration) var colorNarration: String = "#9966CC"
    @AppStorage(PrefKey.colorSoundNote) var colorSoundNote: String = "#17A2B8"
    @AppStorage(PrefKey.colorSceneBoundary) var colorSceneBoundary: String = "#6AA9FF"

    // MARK: - Cinematography > Defaults

    @AppStorage(PrefKey.defaultShotStatus) var defaultShotStatus: String = "planning"
    @AppStorage(PrefKey.defaultShotType) var defaultShotType: String = "wide"

    // MARK: - Cinematography > Video Generation

    @AppStorage(PrefKey.videoProvider) var videoProvider: String = "veo3"
    @AppStorage(PrefKey.videoDuration) var videoDuration: Double = 5.0
    @AppStorage(PrefKey.videoQuality) var videoQuality: String = "High"
    @AppStorage(PrefKey.videoAspectRatio) var videoAspectRatio: String = "16:9"
    @AppStorage(PrefKey.videoCameraMotion) var videoCameraMotion: String = "Static"

    // MARK: - Cinematography > Shot Colors

    @AppStorage(PrefKey.colorShotWide) var colorShotWide: String = "#00897B"
    @AppStorage(PrefKey.colorShotMedium) var colorShotMedium: String = "#F57F17"
    @AppStorage(PrefKey.colorShotCloseUp) var colorShotCloseUp: String = "#D32F2F"
    @AppStorage(PrefKey.colorShotOTS) var colorShotOTS: String = "#7B1FA2"
    @AppStorage(PrefKey.colorShotPOV) var colorShotPOV: String = "#388E3C"
    @AppStorage(PrefKey.colorShotInsert) var colorShotInsert: String = "#E64A19"

    // MARK: - AI > Connection

    @AppStorage(PrefKey.aiProxyURL) var aiProxyURL: String = "http://localhost:8002"
    @AppStorage(PrefKey.aiTimeout) var aiTimeout: Double = 120

    // MARK: - AI > Defaults

    @AppStorage(PrefKey.aiTextProvider) var aiTextProvider: String = "google"
    @AppStorage(PrefKey.aiImageProvider) var aiImageProvider: String = "google_imagen"
    @AppStorage(PrefKey.aiVideoProvider) var aiVideoProvider: String = "google_veo"

    // MARK: - AI > Generation

    @AppStorage(PrefKey.aiTemperature) var aiTemperature: Double = 0.7
    @AppStorage(PrefKey.aiMaxTokensChat) var aiMaxTokensChat: Int = 4000
    @AppStorage(PrefKey.aiMaxTokensImport) var aiMaxTokensImport: Int = 65000

    // MARK: - AI > Usage

    @AppStorage(PrefKey.aiShowCostEstimates) var aiShowCostEstimates: Bool = true
    @AppStorage(PrefKey.aiMonthlyBudget) var aiMonthlyBudget: Double = 0

    // MARK: - Export > Screenplay

    @AppStorage(PrefKey.exportDefaultFormat) var exportDefaultFormat: String = "fountain"
    @AppStorage(PrefKey.exportIncludeTitlePage) var exportIncludeTitlePage: Bool = true
    @AppStorage(PrefKey.exportIncludePageNumbers) var exportIncludePageNumbers: Bool = true

    // MARK: - Export > PDF

    @AppStorage(PrefKey.exportPaperSize) var exportPaperSize: String = "letter"
    @AppStorage(PrefKey.exportIncludeWatermark) var exportIncludeWatermark: Bool = false
    @AppStorage(PrefKey.exportWatermarkText) var exportWatermarkText: String = "DRAFT"

    // MARK: - Advanced > Performance

    @AppStorage(PrefKey.maxTimelineTextLength) var maxTimelineTextLength: Int = 200
    @AppStorage(PrefKey.viewportBuffer) var viewportBuffer: Double = 10
    @AppStorage(PrefKey.animationScale) var animationScale: Double = 1.0

    // MARK: - Advanced > Storage

    @AppStorage(PrefKey.projectDirectory) var projectDirectory: String = ""

    // MARK: - Advanced > Debug

    @AppStorage(PrefKey.enableDebugLogging) var enableDebugLogging: Bool = false
    @AppStorage(PrefKey.showDeveloperInfo) var showDeveloperInfo: Bool = false

    // MARK: - Reset Helpers

    func resetTimelineColors() {
        colorDialogue = "#5D5D5D"
        colorAction = "#FF9500"
        colorNarration = "#9966CC"
        colorSoundNote = "#17A2B8"
        colorSceneBoundary = "#6AA9FF"
    }

    func resetShotColors() {
        colorShotWide = "#00897B"
        colorShotMedium = "#F57F17"
        colorShotCloseUp = "#D32F2F"
        colorShotOTS = "#7B1FA2"
        colorShotPOV = "#388E3C"
        colorShotInsert = "#E64A19"
    }

    func resetAllToDefaults() {
        // General
        colorScheme = "system"
        sidebarIconSize = "medium"
        defaultView = "overview"
        restoreLastProject = true
        showSplashScreen = true
        autoSaveEnabled = true
        autoSaveInterval = 500
        saveConfirmation = true
        showHints = true

        // Editor
        editorFontFamily = "Courier Prime"
        editorFontSize = 12
        editorLineHeight = 1.17
        editorPageWidth = "standard"
        autoCapSceneHeadings = true
        autoUpperCharNames = true
        smartQuotes = true
        tabCyclesType = true
        transliteration = false
        showElementColors = true
        showPageBreaks = true
        defaultZoom = 2.0
        highlightActiveLine = false

        // Timeline
        timelineWPM = 150
        timelineCommaPause = 0.25
        timelineSentencePause = 0.50
        timelineEllipsisPause = 0.60
        timelineActionDuration = 2.0
        timelineSoundNoteDuration = 3.0
        timelineDefaultZoom = 60
        timelineRowHeight = "standard"
        timelineRowGap = "standard"
        showDialogueTrack = true
        showActionTrack = true
        showNarrationTrack = true
        showSoundNotes = true
        showShotLabels = true
        showShotMarkers = true
        showShotConnections = false
        showUserMarkers = true
        showCharAvatars = true
        resetTimelineColors()

        // Cinematography
        defaultShotStatus = "planning"
        defaultShotType = "wide"
        videoProvider = "veo3"
        videoDuration = 5.0
        videoQuality = "High"
        videoAspectRatio = "16:9"
        videoCameraMotion = "Static"
        resetShotColors()

        // AI
        aiProxyURL = "http://localhost:8002"
        aiTimeout = 120
        aiTextProvider = "google"
        aiImageProvider = "google_imagen"
        aiVideoProvider = "google_veo"
        aiTemperature = 0.7
        aiMaxTokensChat = 4000
        aiMaxTokensImport = 65000
        aiShowCostEstimates = true
        aiMonthlyBudget = 0

        // Export
        exportDefaultFormat = "fountain"
        exportIncludeTitlePage = true
        exportIncludePageNumbers = true
        exportPaperSize = "letter"
        exportIncludeWatermark = false
        exportWatermarkText = "DRAFT"

        // Advanced
        maxTimelineTextLength = 200
        viewportBuffer = 10
        animationScale = 1.0
        projectDirectory = ""
        enableDebugLogging = false
        showDeveloperInfo = false
    }
}
