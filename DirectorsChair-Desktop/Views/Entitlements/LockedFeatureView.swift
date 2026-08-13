//
//  LockedFeatureView.swift
//  DirectorsChair-Desktop
//
//  The placeholder a navigator destination above the session tier routes
//  to (Product-Versions §5.3 — lock badge, never hidden UI: the
//  destination stays discoverable and explains its tier). Live for Free
//  sessions since the fail-closed flip (owner decision 2026-08-12); the
//  copy says "coming soon" — no purchase CTA until billing ships.
//

import SwiftUI
import DirectorsChairServices
import DirectorsChairViews

/// Full-pane upgrade placeholder for a locked `AppView` destination.
struct LockedFeatureView: View {
    let view: AppView

    var body: some View {
        VStack {
            Spacer()
            TierUpgradePrompt(feature: view.rawValue,
                              requiredTier: view.requiredTier)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("locked-\(view.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}
