//
//  GuidedTourManager.swift
//  DirectorsChair-Desktop
//
//  Manages the guided tour state: spotlight walkthrough + hint dots
//

import SwiftUI

@MainActor
class GuidedTourManager: ObservableObject {
    // MARK: - Spotlight Tour State

    @Published var isSpotlightTourActive = false
    @Published var currentStepIndex = 0
    @Published var targetFrames: [String: CGRect] = [:]

    // MARK: - Hint Dot State

    @Published var discoveredHints: Set<String> = []
    @Published var activeHintPopover: String? = nil

    // MARK: - Persistence Keys

    private let completedKey = "tour.hasCompletedSpotlightTour"
    private let hintsKey = "tour.discoveredHints"

    // MARK: - Computed

    var hasCompletedTour: Bool {
        get { UserDefaults.standard.bool(forKey: completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    var currentStep: TourStep? {
        guard isSpotlightTourActive,
              currentStepIndex >= 0,
              currentStepIndex < TourStepDefinitions.spotlightSteps.count else { return nil }
        return TourStepDefinitions.spotlightSteps[currentStepIndex]
    }

    var currentTargetFrame: CGRect? {
        guard let step = currentStep else { return nil }
        return targetFrames[step.targetId]
    }

    var totalSteps: Int {
        TourStepDefinitions.spotlightSteps.count
    }

    var isLastStep: Bool {
        currentStepIndex >= totalSteps - 1
    }

    // MARK: - Init

    init() {
        // Restore discovered hints from UserDefaults
        if let saved = UserDefaults.standard.array(forKey: hintsKey) as? [String] {
            discoveredHints = Set(saved)
        }
    }

    // MARK: - Spotlight Tour Actions

    func startSpotlightTour() {
        currentStepIndex = 0
        isSpotlightTourActive = true
    }

    func advanceStep() {
        if isLastStep {
            completeTour()
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                currentStepIndex += 1
            }
        }
    }

    func skipTour() {
        completeTour()
    }

    func completeTour() {
        withAnimation(.easeOut(duration: 0.3)) {
            isSpotlightTourActive = false
        }
        hasCompletedTour = true
        objectWillChange.send()
    }

    // MARK: - Hint Dot Actions

    func discoverHint(_ id: String) {
        discoveredHints.insert(id)
        UserDefaults.standard.set(Array(discoveredHints), forKey: hintsKey)
        activeHintPopover = nil
    }

    func isHintDiscovered(_ id: String) -> Bool {
        discoveredHints.contains(id)
    }

    func shouldShowHint(_ id: String) -> Bool {
        hasCompletedTour && !isHintDiscovered(id) && !isSpotlightTourActive
    }

    // MARK: - Reset

    func resetTour() {
        isSpotlightTourActive = false
        currentStepIndex = 0
        discoveredHints.removeAll()
        hasCompletedTour = false
        UserDefaults.standard.removeObject(forKey: hintsKey)
        activeHintPopover = nil
        objectWillChange.send()

        // Start the tour after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startSpotlightTour()
        }
    }
}
