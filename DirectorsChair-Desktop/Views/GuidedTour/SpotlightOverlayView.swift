//
//  SpotlightOverlayView.swift
//  DirectorsChair-Desktop
//
//  Full-window overlay with dimmed backdrop, spotlight cutout, and tooltip card
//

import SwiftUI

struct SpotlightOverlayView: View {
    @EnvironmentObject var tourManager: GuidedTourManager

    // Accent color matching onboarding: RGB(186, 236, 248)
    private let accentCyan = Color(red: 186/255, green: 236/255, blue: 248/255)

    var body: some View {
        GeometryReader { geometry in
            let windowFrame = geometry.frame(in: .global)

            ZStack {
                // Dimmed backdrop with cutout
                if let targetFrame = tourManager.currentTargetFrame {
                    let cutoutRect = paddedRect(targetFrame, padding: 8, in: windowFrame)

                    SpotlightCutoutShape(cutoutRect: cutoutRect, cornerRadius: 10)
                        .fill(Color.black.opacity(0.6))
                        .ignoresSafeArea()

                    // Cyan glow border around cutout
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentCyan.opacity(0.6), lineWidth: 2)
                        .shadow(color: accentCyan.opacity(0.4), radius: 8)
                        .frame(width: cutoutRect.width, height: cutoutRect.height)
                        .position(x: cutoutRect.midX, y: cutoutRect.midY)

                    // Tooltip card
                    if let step = tourManager.currentStep {
                        tooltipCard(step: step, cutoutRect: cutoutRect, windowSize: geometry.size)
                    }
                } else {
                    // No target frame yet — show dimmed backdrop only
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()

                    if let step = tourManager.currentStep {
                        // Show tooltip in center
                        tooltipCardCentered(step: step)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                tourManager.advanceStep()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: tourManager.currentStepIndex)
    }

    // MARK: - Tooltip Card

    private func tooltipCard(step: TourStep, cutoutRect: CGRect, windowSize: CGSize) -> some View {
        let cardWidth: CGFloat = 300
        let cardOffset: CGFloat = 16

        // Calculate position based on tooltip position preference
        let position: CGPoint = {
            switch step.tooltipPosition {
            case .below:
                let x = clamp(cutoutRect.midX, min: cardWidth / 2 + 16, max: windowSize.width - cardWidth / 2 - 16)
                let y = cutoutRect.maxY + cardOffset + 60
                return CGPoint(x: x, y: y)
            case .above:
                let x = clamp(cutoutRect.midX, min: cardWidth / 2 + 16, max: windowSize.width - cardWidth / 2 - 16)
                let y = cutoutRect.minY - cardOffset - 60
                return CGPoint(x: x, y: y)
            case .right:
                let x = cutoutRect.maxX + cardOffset + cardWidth / 2
                let y = clamp(cutoutRect.midY, min: 80, max: windowSize.height - 80)
                return CGPoint(x: min(x, windowSize.width - cardWidth / 2 - 16), y: y)
            case .left:
                let x = cutoutRect.minX - cardOffset - cardWidth / 2
                let y = clamp(cutoutRect.midY, min: 80, max: windowSize.height - 80)
                return CGPoint(x: max(x, cardWidth / 2 + 16), y: y)
            }
        }()

        return tooltipContent(step: step, width: cardWidth)
            .position(position)
    }

    private func tooltipCardCentered(step: TourStep) -> some View {
        tooltipContent(step: step, width: 300)
    }

    private func tooltipContent(step: TourStep, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(accentCyan)

            Text(step.description)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                // Step counter
                Text("\(tourManager.currentStepIndex + 1) of \(tourManager.totalSteps)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                if !tourManager.isLastStep {
                    Button("Skip") {
                        tourManager.skipTour()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                }

                Button(tourManager.isLastStep ? "Done" : "Next") {
                    tourManager.advanceStep()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(accentCyan)
                .cornerRadius(6)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.12))
                .shadow(color: .black.opacity(0.5), radius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentCyan.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    /// Convert a global frame into the overlay's local coordinate space
    private func paddedRect(_ globalFrame: CGRect, padding: CGFloat, in windowFrame: CGRect) -> CGRect {
        CGRect(
            x: globalFrame.minX - windowFrame.minX - padding,
            y: globalFrame.minY - windowFrame.minY - padding,
            width: globalFrame.width + padding * 2,
            height: globalFrame.height + padding * 2
        )
    }

    private func clamp(_ value: CGFloat, min minVal: CGFloat, max maxVal: CGFloat) -> CGFloat {
        Swift.min(maxVal, Swift.max(minVal, value))
    }
}

// MARK: - Spotlight Cutout Shape

/// A shape that fills the entire frame except for a rounded-rect cutout (even-odd fill)
struct SpotlightCutoutShape: Shape {
    var cutoutX: CGFloat
    var cutoutY: CGFloat
    var cutoutWidth: CGFloat
    var cutoutHeight: CGFloat
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>, CGFloat> {
        get {
            AnimatablePair(
                AnimatablePair(
                    AnimatablePair(cutoutX, cutoutY),
                    AnimatablePair(cutoutWidth, cutoutHeight)
                ),
                cornerRadius
            )
        }
        set {
            cutoutX = newValue.first.first.first
            cutoutY = newValue.first.first.second
            cutoutWidth = newValue.first.second.first
            cutoutHeight = newValue.first.second.second
            cornerRadius = newValue.second
        }
    }

    init(cutoutRect: CGRect, cornerRadius: CGFloat) {
        self.cutoutX = cutoutRect.origin.x
        self.cutoutY = cutoutRect.origin.y
        self.cutoutWidth = cutoutRect.size.width
        self.cutoutHeight = cutoutRect.size.height
        self.cornerRadius = cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        let cutoutRect = CGRect(x: cutoutX, y: cutoutY, width: cutoutWidth, height: cutoutHeight)
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(in: cutoutRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}
