//
//  LockedFeatureView.swift
//  DirectorsChair-Desktop
//
//  Product-tiering Phase 2: the placeholder a navigator destination above
//  the session tier routes to (Product-Versions §5.3 — lock badge, never
//  hidden UI: the destination stays discoverable and explains its tier).
//  Until billing every session resolves to `.studio`, so this view is
//  unreachable today — it ships dark with the rest of the scaffold.
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
