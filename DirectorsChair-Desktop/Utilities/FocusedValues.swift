//
//  FocusedValues.swift
//  DirectorsChair-Desktop
//
//  Phase 8C: Menu Bar & Commands
//  Focused values for Commands to access view models
//

import SwiftUI

// MARK: - FocusedValue Keys

struct ProjectViewModelKey: FocusedValueKey {
    typealias Value = ProjectViewModel
}

struct AppCoordinatorKey: FocusedValueKey {
    typealias Value = AppCoordinator
}

extension FocusedValues {
    var projectViewModel: ProjectViewModel? {
        get { self[ProjectViewModelKey.self] }
        set { self[ProjectViewModelKey.self] = newValue }
    }

    var appCoordinator: AppCoordinator? {
        get { self[AppCoordinatorKey.self] }
        set { self[AppCoordinatorKey.self] = newValue }
    }
}
