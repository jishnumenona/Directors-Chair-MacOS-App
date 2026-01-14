//
//  ErrorAlert.swift
//  DirectorsChair-Desktop
//
//  Phase 8F: Polish & Testing
//  User-facing error alert system
//

import SwiftUI

/// Error alert presenter for user-facing error messages
struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let dismissButton: Alert.Button?

    init(title: String, message: String, dismissButton: Alert.Button? = nil) {
        self.title = title
        self.message = message
        self.dismissButton = dismissButton
    }

    init(error: Error, title: String = "Error") {
        self.title = title
        self.message = error.localizedDescription
        self.dismissButton = nil
    }

    var alert: Alert {
        if let dismissButton = dismissButton {
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: dismissButton
            )
        } else {
            return Alert(
                title: Text(title),
                message: Text(message)
            )
        }
    }
}

/// View modifier to present error alerts
struct ErrorAlertModifier: ViewModifier {
    @Binding var errorAlert: ErrorAlert?

    func body(content: Content) -> some View {
        content
            .alert(item: $errorAlert) { alert in
                alert.alert
            }
    }
}

extension View {
    /// Present error alerts using the ErrorAlert system
    func errorAlert(_ errorAlert: Binding<ErrorAlert?>) -> some View {
        modifier(ErrorAlertModifier(errorAlert: errorAlert))
    }
}
