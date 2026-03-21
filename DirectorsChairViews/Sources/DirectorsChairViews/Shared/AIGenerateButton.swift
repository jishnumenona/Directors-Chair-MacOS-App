// DirectorsChairViews/Sources/DirectorsChairViews/Shared/AIGenerateButton.swift
//
// Non-blocking AI action button with inline progress indicator

import SwiftUI

/// A button with an integrated progress bar for AI operations.
struct AIGenerateButton: View {
    let title: String
    let icon: String
    let loadingText: String
    let isLoading: Bool
    var progress: Int? = nil
    let action: () -> Void

    var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            Label(isLoading ? loadingText : title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ProgressButtonStyle(isLoading: isLoading, progress: progress))
        .disabled(isLoading)
    }
}

/// Custom button style that overlays a thin progress bar along the bottom edge.
private struct ProgressButtonStyle: ButtonStyle {
    let isLoading: Bool
    let progress: Int?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background {
                ZStack(alignment: .bottom) {
                    // Base fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                        .opacity(configuration.isPressed ? 0.7 : (isLoading ? 0.6 : 1.0))

                    // Progress fill from left
                    if isLoading {
                        GeometryReader { geo in
                            let pct = Double(progress ?? 0) / 100.0
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                                .frame(width: geo.size.width * pct)
                                .animation(.easeInOut(duration: 0.5), value: progress)
                        }
                    }

                    // Bottom progress track
                    if isLoading {
                        GeometryReader { geo in
                            let pct = Double(progress ?? 0) / 100.0
                            VStack {
                                Spacer()
                                ZStack(alignment: .leading) {
                                    // Track
                                    Rectangle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(height: 2)
                                    // Fill
                                    Rectangle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: geo.size.width * pct, height: 2)
                                        .animation(.easeInOut(duration: 0.5), value: progress)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
    }
}
