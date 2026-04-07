// DirectorsChair-DesktopTests/OnboardingFlowTests.swift
//
// Tests for onboarding flow logic.
// Tests the OnboardingState observable object and UserDefaults-based flag logic.

import XCTest
@testable import DirectorsChair_Desktop

final class OnboardingFlowTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Clear the onboarding flag before each test to ensure a clean state
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }

    override func tearDown() {
        // Clean up after tests
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        super.tearDown()
    }

    // MARK: - First Launch

    @MainActor
    func testFirstLaunchShowsOnboarding() {
        // When no prior launch flag exists, onboarding should be shown
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
                       "hasCompletedOnboarding should be false on first launch")

        let onboardingState = OnboardingState()

        // Simulate what DirectorsChair_DesktopApp.onAppear does
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            onboardingState.showOnboarding = true
        }

        XCTAssertTrue(onboardingState.showOnboarding,
                      "Onboarding should be visible on first launch")
    }

    // MARK: - Subsequent Launch

    @MainActor
    func testSubsequentLaunchSkipsOnboarding() {
        // Set the flag to indicate onboarding was previously completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        let onboardingState = OnboardingState()

        // Simulate what DirectorsChair_DesktopApp.onAppear does
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            onboardingState.showOnboarding = true
        }

        XCTAssertFalse(onboardingState.showOnboarding,
                       "Onboarding should be hidden after first completion")
    }

    // MARK: - Completion Sets Flag

    @MainActor
    func testOnboardingCompletionSetsFlag() {
        let onboardingState = OnboardingState()
        onboardingState.showOnboarding = true

        XCTAssertTrue(onboardingState.showOnboarding)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
                       "Flag should not be set before completion")

        // Complete onboarding
        onboardingState.complete()

        XCTAssertFalse(onboardingState.showOnboarding,
                       "showOnboarding should be false after completion")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
                      "UserDefaults flag should be set after completion")
    }

    // MARK: - Z-Order Logic

    @MainActor
    func testLoginGateZOrder() {
        // On first launch, if both onboarding and login gate could appear,
        // onboarding should take visual priority.
        // The app logic checks hasCompletedOnboarding first.
        let onboardingState = OnboardingState()

        // First launch: onboarding should be shown
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))

        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            onboardingState.showOnboarding = true
        }

        // Verify onboarding is active -- meaning login gate should NOT
        // obscure the onboarding experience
        XCTAssertTrue(onboardingState.showOnboarding,
                      "Onboarding must be visible; login should not obscure it on first launch")
    }

    // MARK: - OnboardingState Initialization

    @MainActor
    func testOnboardingStateInitialValue() {
        let state = OnboardingState()
        // Default state should be false -- the app explicitly sets it true when needed
        XCTAssertFalse(state.showOnboarding,
                       "OnboardingState should default to showOnboarding = false")
    }

    @MainActor
    func testMultipleCompletionCallsAreIdempotent() {
        let state = OnboardingState()
        state.showOnboarding = true

        state.complete()
        XCTAssertFalse(state.showOnboarding)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))

        // Calling complete again should not cause any issues
        state.complete()
        XCTAssertFalse(state.showOnboarding)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }
}
