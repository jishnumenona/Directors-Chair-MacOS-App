// DirectorsChairViews/Sources/DirectorsChairViews/Logging.swift
//
// Package-internal debug logging routed through os.Logger at the .debug level.
// Not persisted in release builds and never writes to a file — replaces bare
// print() so shipped targets do not spam the console or leak to it (WS3.4).

import Foundation
import os

private let packageLog = Logger(subsystem: "com.directorschair", category: "views")

func debugLog(_ message: String) {
    packageLog.debug("\(message, privacy: .public)")
}
