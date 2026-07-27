//
//  TurnPlanCardView.swift
//  DirectorsChair-Desktop
//
//  AI Assistant program, Phase A2.4: the TurnPlan review card (AD5) — every
//  mutating proposal from an assistant turn, as selectable old→new diffs
//  with Apply-selected / Decline-all — plus the live streaming bubble, the
//  tool-activity chip, and the whole-turn Undo row.
//

import SwiftUI
import DirectorsChairServices

// MARK: - TurnPlan review card

struct TurnPlanCardView: View {
    let plan: TurnPlan
    let onApply: (Set<String>) -> Void
    let onDismiss: () -> Void

    @State private var selectedIds: Set<String>

    /// Advisory per-batch spend guideline (A5.5); quotas are the hard wall.
    static let batchGuidelineUSD = 5.0

    /// Total estimated spend across the currently selected items.
    private var selectedTotal: Double {
        plan.items.filter { selectedIds.contains($0.id) }
            .reduce(0) { $0 + $1.plan.estimatedCost }
    }

    init(plan: TurnPlan, onApply: @escaping (Set<String>) -> Void,
         onDismiss: @escaping () -> Void) {
        self.plan = plan
        self.onApply = onApply
        self.onDismiss = onDismiss
        _selectedIds = State(initialValue: Set(plan.items.map(\.id)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .foregroundColor(.orange)
                Text("PROPOSED CHANGES")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                Spacer()
                if selectedTotal > 0 {
                    Text("≈ $\(String(format: "%.2f", selectedTotal))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                }
                Text("\(selectedIds.count) of \(plan.items.count) selected")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Batch budget guideline (A5.5): totals above the advisory cap
            // get a prominent flag — server quotas remain the hard wall.
            if selectedTotal > Self.batchGuidelineUSD {
                Label {
                    Text("This batch is ≈ $\(String(format: "%.2f", selectedTotal)) — above the $\(String(format: "%.0f", Self.batchGuidelineUSD)) guideline. Deselect items to trim it, or apply if intended.")
                } icon: {
                    Image(systemName: "dollarsign.circle.fill")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.orange)
            }

            ForEach(plan.items) { item in
                itemRow(item)
            }

            HStack(spacing: 8) {
                Button {
                    onApply(selectedIds)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text((selectedIds.count == plan.items.count
                              ? "Apply all" : "Apply selected")
                             + (selectedTotal > 0
                                ? " (~$\(String(format: "%.2f", selectedTotal)))" : ""))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(selectedIds.isEmpty)

                Button(action: onDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Decline")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.25), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func itemRow(_ item: ProposedActionItem) -> some View {
        let isSelected = selectedIds.contains(item.id)
        VStack(alignment: .leading, spacing: 4) {
            Button {
                if isSelected { selectedIds.remove(item.id) }
                else { selectedIds.insert(item.id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSelected
                          ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                    Text(item.plan.summary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            ForEach(Array(item.plan.previews.enumerated()), id: \.offset) { _, preview in
                previewRow(preview)
            }

            // Validator findings (AD6) — shown, never silently blocking
            ForEach(Array(item.plan.warnings.enumerated()), id: \.offset) { _, warning in
                Label {
                    Text(warning)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.system(size: 11))
                .foregroundColor(.orange)
                .padding(.leading, 22)
            }
        }
        .padding(8)
        .background(Color.white.opacity(isSelected ? 0.05 : 0.02))
        .cornerRadius(8)
    }

    private func previewRow(_ preview: ActionPreview) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(preview.title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            if let old = preview.oldValue, !old.isEmpty {
                Label {
                    Text(old).strikethrough()
                } icon: {
                    Image(systemName: "minus")
                }
                .font(.system(size: 11))
                .foregroundColor(.red.opacity(0.75))
            }
            if let new = preview.newValue, !new.isEmpty {
                Label {
                    Text(new)
                } icon: {
                    Image(systemName: "plus")
                }
                .font(.system(size: 11))
                .foregroundColor(.green.opacity(0.85))
            }
        }
        .padding(.leading, 22)
    }
}

// MARK: - Streaming bubble

/// The in-flight assistant reply, rendered live as deltas arrive (A2.4).
struct StreamingAssistantBubble: View {
    let text: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9))
                        .foregroundColor(.accentColor)
                    Text("AI ASSISTANT")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}

// MARK: - Tool activity chip

struct ToolActivityChip: View {
    let text: String

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(text)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 1)
    }
}

// MARK: - Undo row

struct UndoAssistantChangesRow: View {
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onUndo) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo assistant changes")
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .foregroundColor(Color(nsColor: .labelColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
