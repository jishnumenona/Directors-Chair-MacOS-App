// DirectorsChairViews/Sources/DirectorsChairViews/Timeline/TimelineAnalysisReviewView.swift
//
// Review sheet for AI-proposed timeline changes

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices

/// Local typealias to disambiguate from SceneConnection's ScriptItemType
private typealias AnalysisScriptItemType = DirectorsChairServices.ScriptItemType

// MARK: - Timeline Analysis Review View

public struct TimelineAnalysisReviewView: View {
    public let result: TimelineAnalysisResult
    public let onApply: () -> Void
    public let onCancel: () -> Void

    @State private var expandedScenes: Set<String> = []

    public init(result: TimelineAnalysisResult, onApply: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.result = result
        self.onApply = onApply
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            if result.hasChanges {
                // Changes list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(result.scenesWithChanges) { sceneResult in
                            sceneSection(sceneResult)
                        }

                        // Failed scenes
                        if !result.failedScenes.isEmpty {
                            failedScenesSection
                        }
                    }
                    .padding(16)
                }
            } else {
                // No changes state
                noChangesView
            }

            Divider()

            // Footer
            footerView
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 600, maxWidth: 600, minHeight: 400, maxHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Timeline Analysis")
                    .font(.system(size: 16, weight: .semibold))

                if result.hasChanges {
                    Text("\(result.totalChanges) proposed change\(result.totalChanges == 1 ? "" : "s") across \(result.scenesWithChanges.count) scene\(result.scenesWithChanges.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Change type legend
            HStack(spacing: 12) {
                legendItem(icon: "arrow.up.arrow.down", label: "Order", color: .blue)
                legendItem(icon: "link", label: "Links", color: .green)
                legendItem(icon: "arrow.triangle.merge", label: "Group", color: .purple)
                legendItem(icon: "clock", label: "Duration", color: .orange)
            }
        }
    }

    private func legendItem(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Scene Section

    private func sceneSection(_ sceneResult: SceneAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Scene header (collapsible)
            Button {
                if expandedScenes.contains(sceneResult.sceneName) {
                    expandedScenes.remove(sceneResult.sceneName)
                } else {
                    expandedScenes.insert(sceneResult.sceneName)
                }
            } label: {
                HStack {
                    Image(systemName: expandedScenes.contains(sceneResult.sceneName) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)

                    Image(systemName: "film")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)

                    Text(sceneResult.sceneName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    changeBadges(sceneResult)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // Expanded content
            if expandedScenes.contains(sceneResult.sceneName) {
                VStack(alignment: .leading, spacing: 8) {
                    // Chronology changes
                    if !sceneResult.chronologyChanges.isEmpty {
                        changeGroup(
                            icon: "arrow.up.arrow.down",
                            title: "Chronology Reordering",
                            color: .blue,
                            count: sceneResult.chronologyChanges.count
                        ) {
                            ForEach(sceneResult.chronologyChanges) { change in
                                changeRow {
                                    HStack(spacing: 6) {
                                        itemTypeBadge(change.itemType)
                                        Text(change.label)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(change.oldNumber)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                        Text("\(change.newNumber)")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }

                    // Shot link changes
                    if !sceneResult.shotLinkChanges.isEmpty {
                        changeGroup(
                            icon: "link",
                            title: "Shot-Script Linking",
                            color: .green,
                            count: sceneResult.shotLinkChanges.count
                        ) {
                            ForEach(sceneResult.shotLinkChanges) { change in
                                changeRow {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(change.shotLabel)
                                            .font(.system(size: 11, weight: .medium))

                                        if !change.addedDialogueIds.isEmpty {
                                            linkChangeLabel("+\(change.addedDialogueIds.count) dialogue link\(change.addedDialogueIds.count == 1 ? "" : "s")", isAdd: true)
                                        }
                                        if !change.removedDialogueIds.isEmpty {
                                            linkChangeLabel("-\(change.removedDialogueIds.count) dialogue link\(change.removedDialogueIds.count == 1 ? "" : "s")", isAdd: false)
                                        }
                                        if !change.addedActionIds.isEmpty {
                                            linkChangeLabel("+\(change.addedActionIds.count) action link\(change.addedActionIds.count == 1 ? "" : "s")", isAdd: true)
                                        }
                                        if !change.removedActionIds.isEmpty {
                                            linkChangeLabel("-\(change.removedActionIds.count) action link\(change.removedActionIds.count == 1 ? "" : "s")", isAdd: false)
                                        }
                                        if !change.addedNarrationIds.isEmpty {
                                            linkChangeLabel("+\(change.addedNarrationIds.count) narration link\(change.addedNarrationIds.count == 1 ? "" : "s")", isAdd: true)
                                        }
                                        if !change.removedNarrationIds.isEmpty {
                                            linkChangeLabel("-\(change.removedNarrationIds.count) narration link\(change.removedNarrationIds.count == 1 ? "" : "s")", isAdd: false)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Parent-child changes
                    if !sceneResult.parentChildChanges.isEmpty {
                        changeGroup(
                            icon: "arrow.triangle.merge",
                            title: "Parent-Child Grouping",
                            color: .purple,
                            count: sceneResult.parentChildChanges.count
                        ) {
                            ForEach(sceneResult.parentChildChanges) { change in
                                changeRow {
                                    HStack(spacing: 6) {
                                        itemTypeBadge(change.itemType)
                                        Text(change.label)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                        Spacer()
                                        Text(change.oldParentDialogueId == nil ? "unlinked" : "linked")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                        Text(change.newParentDialogueId == nil ? "unlinked" : "linked")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }

                    // Shot duration changes
                    if !sceneResult.shotDurationChanges.isEmpty {
                        changeGroup(
                            icon: "clock",
                            title: "Shot Durations",
                            color: .orange,
                            count: sceneResult.shotDurationChanges.count
                        ) {
                            ForEach(sceneResult.shotDurationChanges) { change in
                                changeRow {
                                    HStack(spacing: 6) {
                                        Text(change.shotLabel)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                        Spacer()
                                        Text(change.oldDuration.map { String(format: "%.1fs", $0) } ?? "unset")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                        Text(String(format: "%.1fs", change.newDuration))
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            // Auto-expand if only one scene
            if result.scenesWithChanges.count == 1 {
                expandedScenes.insert(sceneResult.sceneName)
            }
        }
    }

    // MARK: - Change Display Helpers

    private func changeBadges(_ sceneResult: SceneAnalysisResult) -> some View {
        HStack(spacing: 4) {
            if !sceneResult.chronologyChanges.isEmpty {
                badge(count: sceneResult.chronologyChanges.count, icon: "arrow.up.arrow.down", color: .blue)
            }
            if !sceneResult.shotLinkChanges.isEmpty {
                badge(count: sceneResult.shotLinkChanges.count, icon: "link", color: .green)
            }
            if !sceneResult.parentChildChanges.isEmpty {
                badge(count: sceneResult.parentChildChanges.count, icon: "arrow.triangle.merge", color: .purple)
            }
            if !sceneResult.shotDurationChanges.isEmpty {
                badge(count: sceneResult.shotDurationChanges.count, icon: "clock", color: .orange)
            }
        }
    }

    private func badge(count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text("\(count)")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func changeGroup<Content: View>(
        icon: String,
        title: String,
        color: Color,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text("(\(count))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)

            content()
        }
    }

    private func changeRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func itemTypeBadge(_ type: AnalysisScriptItemType) -> some View {
        Text(type.rawValue.prefix(1).uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(
                type == .dialogue ? Color.blue :
                type == .action ? Color.orange : Color.purple
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func linkChangeLabel(_ text: String, isAdd: Bool) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(isAdd ? Color.green : Color.red)
            .padding(.leading, 4)
    }

    // MARK: - Failed Scenes

    private var failedScenesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                Text("Failed Scenes")
                    .font(.system(size: 12, weight: .semibold))
            }

            ForEach(Array(result.failedScenes.enumerated()), id: \.offset) { _, failed in
                HStack {
                    Text(failed.sceneName)
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text(failed.error)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - No Changes

    private var noChangesView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("No Changes Detected")
                .font(.system(size: 16, weight: .semibold))
            Text("The timeline is already well-organized.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            if !result.failedScenes.isEmpty {
                Divider()
                    .padding(.horizontal, 40)
                failedScenesSection
                    .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if result.hasChanges {
                Text("Review changes before applying")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            if result.hasChanges {
                Button("Apply Changes") {
                    onApply()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
