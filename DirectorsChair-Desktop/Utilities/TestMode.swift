//
//  TestMode.swift
//  DirectorsChair-Desktop
//
//  Centralizes the launch-time flags that make the app deterministic for
//  automated UI (E2E) testing. The prior `--uitesting` only skipped
//  onboarding; the app still restored the auth session, which hit the
//  (now dead) server on a machine with a cached token — its variable network
//  timing raced with fixture setup and made the UI suite flaky.
//
//  In UI-test mode the app launches FULLY OFFLINE and deterministically:
//  no auth/session restore, no network, no splash delay, no global key
//  monitors that could swallow the test driver's keystrokes.
//

import Foundation
import DirectorsChairServices

enum TestMode {

    /// Any automated-test launch (UI E2E or QA fixture).
    static let isUITesting: Bool = {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--uitesting") || args.contains("--qa-fixture")
            || args.contains("--qa-fixture-keep")
    }()

    /// The product tier a test launch runs as. The suite was authored
    /// against the unlocked app, so test mode defaults to `.studio`;
    /// `--session-tier=free|creator|studio` overrides it (DC-0016 runs
    /// the whole suite as `.free`). Real launches never read this — the
    /// tier comes from the JWT claim, fail-closed to `.free`.
    static let sessionTier: ProductTier = {
        let args = ProcessInfo.processInfo.arguments
        if let flag = args.first(where: { $0.hasPrefix("--session-tier=") }),
           let tier = ProductTier(rawValue:
                String(flag.dropFirst("--session-tier=".count))) {
            return tier
        }
        return .studio
    }()

    /// Skip auth/session restore and all launch network activity.
    static var skipAuthAndNetwork: Bool { isUITesting }

    /// Skip the animated splash + its ~2.4s of delays; show the main window
    /// immediately so the test driver sees a stable UI without racing the
    /// splash→main transition.
    static var skipSplash: Bool { isUITesting }

    /// Don't install the global key monitor (it can intercept the keystrokes
    /// XCUITest sends to the editor).
    static var skipGlobalKeyMonitors: Bool { isUITesting }

    /// True when this process is the UNIT-test host (xcodebuild test
    /// injecting the suites into the app). It launches with no special
    /// arguments, so `isUITesting` misses it — XCTest's environment is
    /// the tell. Crash telemetry must treat it as a test, not a session:
    /// before this gate, every test-suite crash and test-driver kill
    /// became a "crash report" in the OWNER's archive and a scary alert
    /// on their next real launch.
    nonisolated static var isTestHost: Bool {
        isUITesting || ProcessInfo.processInfo
            .environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
