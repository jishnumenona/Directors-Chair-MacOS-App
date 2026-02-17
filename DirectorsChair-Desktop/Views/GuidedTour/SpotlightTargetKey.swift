//
//  SpotlightTargetKey.swift
//  DirectorsChair-Desktop
//
//  PreferenceKey to collect spotlight target frames from the view hierarchy
//

import SwiftUI

// MARK: - Target Model

struct SpotlightTarget: Equatable {
    let id: String
    let frame: CGRect
}

// MARK: - PreferenceKey

struct SpotlightTargetKey: PreferenceKey {
    static var defaultValue: [SpotlightTarget] = []

    static func reduce(value: inout [SpotlightTarget], nextValue: () -> [SpotlightTarget]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - View Extension

extension View {
    /// Tags this view as a spotlight target with the given ID.
    /// The frame is collected via GeometryReader and reported up the hierarchy.
    func spotlightTarget(id: String) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: SpotlightTargetKey.self,
                    value: [SpotlightTarget(id: id, frame: geo.frame(in: .global))]
                )
            }
        )
    }
}
