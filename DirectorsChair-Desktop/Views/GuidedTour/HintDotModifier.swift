//
//  HintDotModifier.swift
//  DirectorsChair-Desktop
//
//  Pulsing cyan hint dot overlay + tooltip popover
//

import SwiftUI

// MARK: - Hint Dot Modifier

struct HintDotModifier: ViewModifier {
    let hintId: String
    let title: String
    let hintDescription: String
    let alignment: Alignment

    @EnvironmentObject var tourManager: GuidedTourManager
    @State private var isPulsing = false

    // Accent color matching onboarding: RGB(186, 236, 248)
    private let accentCyan = Color(red: 186/255, green: 236/255, blue: 248/255)

    func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            if tourManager.shouldShowHint(hintId) {
                Button(action: {
                    if tourManager.activeHintPopover == hintId {
                        tourManager.discoverHint(hintId)
                    } else {
                        tourManager.activeHintPopover = hintId
                    }
                }) {
                    ZStack {
                        // Outer pulsing ring
                        Circle()
                            .stroke(accentCyan.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 16, height: 16)
                            .scaleEffect(isPulsing ? 1.6 : 1.0)
                            .opacity(isPulsing ? 0 : 0.6)

                        // Core dot
                        Circle()
                            .fill(accentCyan)
                            .frame(width: 8, height: 8)
                            .shadow(color: accentCyan.opacity(0.6), radius: 4)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: Binding(
                    get: { tourManager.activeHintPopover == hintId },
                    set: { if !$0 { tourManager.activeHintPopover = nil } }
                )) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accentCyan)

                        Text(hintDescription)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Got it") {
                            tourManager.discoverHint(hintId)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(accentCyan.opacity(0.3))
                        .cornerRadius(4)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(12)
                    .frame(width: 220)
                }
                .offset(x: alignment == .topTrailing ? -4 : (alignment == .topLeading ? 4 : 0),
                         y: alignment == .topTrailing || alignment == .topLeading ? 4 : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {
    func hintDot(
        id: String,
        title: String,
        description: String,
        alignment: Alignment = .topTrailing
    ) -> some View {
        self.modifier(HintDotModifier(
            hintId: id,
            title: title,
            hintDescription: description,
            alignment: alignment
        ))
    }
}
