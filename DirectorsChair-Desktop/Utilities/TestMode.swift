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

enum TestMode {

    /// Any automated-test launch (UI E2E or QA fixture).
    static let isUITesting: Bool = {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--uitesting") || args.contains("--qa-fixture")
            || args.contains("--qa-fixture-keep")
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
}
