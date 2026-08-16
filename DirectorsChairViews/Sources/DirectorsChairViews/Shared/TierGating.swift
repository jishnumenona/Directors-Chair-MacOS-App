// DirectorsChairViews/Sources/DirectorsChairViews/Shared/TierGating.swift
//
// The per-feature gating affordance (Product-Versions §5.3 — lock badge,
// never hidden UI). A control above the session tier stays visible, wears
// a small lock badge, and taps open a "coming soon" sheet instead of
// performing its action. The session tier arrives via
// `EnvironmentValues.productTier` (default `.free`, fail-closed).

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

    func body(content: Content) -> AnyView {
        // Erased on purpose. Every gate used to add its wrapper to the
        // host view's VALUE type; with fifteen gates in the story-design
        // tree, copying that value overflowed the stack (SIGBUS in
        // initializeWithCopy — caught by the snapshot suite). AnyView caps
        // each gate at one fixed-size type, and these are leaf controls,
        // never the 120Hz canvas path, so erasure costs nothing real.
        let unlocked = sessionTier >= requiredTier
        return AnyView(
            content
                .allowsHitTesting(unlocked)
                .opacity(unlocked ? 1 : 0.55)
                .overlay(alignment: .topTrailing) {
                    if !unlocked { TierLockBadge() }
                }
                .overlay {
                    if !unlocked {
                        // Catches the click the disabled content no longer takes.
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { showingUpgradePrompt = true }
                            .help("\(feature) is part of \(requiredTier.displayName) — coming soon")
                    }
                }
                .sheet(isPresented: $showingUpgradePrompt) {
                    TierUpgradeSheet(feature: feature, requiredTier: requiredTier)
                })
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
            .accessibilityLabel("Locked — part of a plan coming soon")
            .accessibilityIdentifier("tier-lock-badge")
    }
}

// MARK: - Upgrade prompt

/// Locked-feature copy shared by the `.requiresTier` sheet and the app's
/// LockedFeatureView placeholder: feature name + "<Tier> — coming soon" +
/// the Product Versions document reference. Deliberately NO purchase
/// call-to-action: plans are not buyable until billing (DC-0011) ships
/// (owner decision 2026-08-12, Product-Versions §6).
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

            Text("\(requiredTier.displayName) — coming soon")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))

            Text("This feature is part of the \(requiredTier.displayName) "
                 + "plan, which is coming soon. Everything you make stays "
                 + "right here.")
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
/// Public so surfaces that cannot wear the modifier (menu-bar commands,
/// menu items, radial tools) can present the same sheet themselves.
public struct TierUpgradeSheet: View {
    let feature: String
    let requiredTier: ProductTier

    @Environment(\.dismiss) private var dismiss

    public init(feature: String, requiredTier: ProductTier) {
        self.feature = feature
        self.requiredTier = requiredTier
    }

    public var body: some View {
        VStack(spacing: 0) {
            TierUpgradePrompt(feature: feature, requiredTier: requiredTier)
            Button("OK") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 20)
                .accessibilityIdentifier("tier-sheet-ok")
        }
        .accessibilityIdentifier("tier-upgrade-sheet")
    }
}

// MARK: - Deferred prompt plumbing

/// A locked feature someone tried to use from a context that cannot
/// present its own sheet inline (menu-bar command, menu item, radial
/// tool). Stash one of these in local `@State` — or on AppCoordinator for
/// app-level surfaces — and present it with `.tierPromptSheet(_:)`.
public struct TierPromptRequest: Identifiable, Equatable {
    public let feature: String
    public let requiredTier: ProductTier
    public var id: String { feature }

    public init(feature: String, requiredTier: ProductTier) {
        self.feature = feature
        self.requiredTier = requiredTier
    }
}

public extension View {
    /// Presents the shared "coming soon" sheet whenever `request` is
    /// non-nil; dismissing clears it.
    func tierPromptSheet(_ request: Binding<TierPromptRequest?>) -> some View {
        sheet(item: request) { locked in
            TierUpgradeSheet(feature: locked.feature,
                             requiredTier: locked.requiredTier)
        }
    }
}
