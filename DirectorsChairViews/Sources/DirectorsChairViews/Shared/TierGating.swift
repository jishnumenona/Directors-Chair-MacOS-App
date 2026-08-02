// DirectorsChairViews/Sources/DirectorsChairViews/Shared/TierGating.swift
//
// Product-tiering Phase 2: the per-feature gating affordance
// (Product-Versions §5.3 — lock badge, never hidden UI). A control above
// the session tier stays visible, wears a small lock badge, and taps open
// an upgrade prompt instead of performing its action. The session tier
// arrives via `EnvironmentValues.productTier` (default `.studio`, fail-open:
// until billing ships every account is top tier and no lock ever renders).

import SwiftUI
import DirectorsChairServices

// MARK: - View modifier

public extension View {
    /// Gates this control behind a product tier. At or above the session
    /// tier the content is untouched; below it, the content renders locked
    /// (badge + dim) and tapping presents the upgrade prompt.
    ///
    /// - Parameters:
    ///   - tier: the minimum tier that includes the feature (§3 matrix).
    ///   - feature: short feature name for the upgrade copy
    ///     (e.g. "Lookbook PDF export").
    func requiresTier(_ tier: ProductTier,
                      feature: String = "This feature") -> some View {
        modifier(RequiresTierModifier(requiredTier: tier, feature: feature))
    }
}

private struct RequiresTierModifier: ViewModifier {
    let requiredTier: ProductTier
    let feature: String

    @Environment(\.productTier) private var sessionTier
    @State private var showingUpgradePrompt = false

    func body(content: Content) -> some View {
        if sessionTier >= requiredTier {
            content
        } else {
            Button {
                showingUpgradePrompt = true
            } label: {
                content
                    .allowsHitTesting(false)
                    .opacity(0.55)
                    .overlay(alignment: .topTrailing) {
                        TierLockBadge()
                    }
            }
            .buttonStyle(.plain)
            .help("\(feature) is included in \(requiredTier.displayName)")
            .sheet(isPresented: $showingUpgradePrompt) {
                TierUpgradeSheet(feature: feature, requiredTier: requiredTier)
            }
        }
    }
}

// MARK: - Lock badge

/// The small 🔒 worn by locked controls and navigator entries.
public struct TierLockBadge: View {
    public init() {}

    public var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(2)
            .background(Circle().fill(.thinMaterial))
            .accessibilityLabel("Locked — requires an upgrade")
    }
}

// MARK: - Upgrade prompt

/// Branded upgrade copy shared by the `.requiresTier` sheet and the app's
/// LockedFeatureView placeholder: feature name + "Included in <tier>" +
/// the Product Versions document reference.
public struct TierUpgradePrompt: View {
    public let feature: String
    public let requiredTier: ProductTier

    public init(feature: String, requiredTier: ProductTier) {
        self.feature = feature
        self.requiredTier = requiredTier
    }

    public var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Color.accentColor)

            Text(feature)
                .font(.title3.weight(.semibold))

            Text("Included in \(requiredTier.displayName)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))

            Text("Upgrade to the \(requiredTier.displayName) plan to unlock "
                 + "this feature. Everything you make stays right here.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Product Versions — Free, Creator, Studio (§3 feature matrix)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 340)
    }
}

/// The `.requiresTier` sheet: the shared prompt plus a dismiss button.
struct TierUpgradeSheet: View {
    let feature: String
    let requiredTier: ProductTier

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TierUpgradePrompt(feature: feature, requiredTier: requiredTier)
            Button("OK") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 20)
        }
    }
}
