//
//  UpdateCommands.swift
//  DirectorsChair-Desktop
//
//  Sparkle auto-update (docs/release-pipeline.md §7): the standard updater
//  starts at launch and checks the appcast at directorschair.app; this
//  command surfaces the manual check in the app menu. Update archives are
//  EdDSA-verified against SUPublicEDKey (Info.plist) — no Apple Developer
//  ID involved.
//

import Combine
import Sparkle
import SwiftUI

final class UpdaterViewModel: ObservableObject {
    /// The app's one updater, reachable from anywhere that must offer an
    /// update (DC-0116: a project saved by a newer version).
    nonisolated(unsafe) static weak var shared: UpdaterViewModel?
    let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false

    /// Sparkle's interactive check: finds the latest version and installs it.
    func checkForUpdates() { controller.checkForUpdates(nil) }

    init() {
        defer { UpdaterViewModel.shared = self }
        // Harness runs must never hit the network or pop update sheets.
        let harnessArgs = ["--uitesting", "--perf-scenario", "--qa-fixture", "--qa-fixture-keep"]
        let isHarnessRun = ProcessInfo.processInfo.arguments.contains(where: harnessArgs.contains)
        controller = SPUStandardUpdaterController(startingUpdater: !isHarnessRun,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct UpdateCommands: Commands {
    @ObservedObject var updater: UpdaterViewModel

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                updater.controller.checkForUpdates(nil)
            }
            .disabled(!updater.canCheckForUpdates)
        }
    }
}
