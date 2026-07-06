// DirectorsChairViews/Sources/DirectorsChairViews/Shared/ErrorPresenter.swift
//
// WS6.5 — one funnel so service failures always reach the user instead of
// vanishing in `catch {}` / `return []`. Views call
// `ErrorPresenter.shared.present(...)`; the app root hosts a single alert
// bound to `currentError`.

import SwiftUI

public struct PresentedError: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

@MainActor
public final class ErrorPresenter: ObservableObject {
    public static let shared = ErrorPresenter()

    /// The error currently shown to the user (alert host binds to this).
    @Published public var currentError: PresentedError?

    public init() {}

    /// Present a user-facing failure. Later errors replace the current one —
    /// the newest failure is the one the user acts on.
    public func present(title: String, message: String) {
        currentError = PresentedError(title: title, message: message)
    }

    /// Present a thrown error with a human context ("Generating shot preview").
    public func present(_ error: Error, context: String) {
        present(title: "\(context) failed", message: error.localizedDescription)
    }
}
