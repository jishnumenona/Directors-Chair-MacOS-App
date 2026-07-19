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
    let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false

    init() {
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
