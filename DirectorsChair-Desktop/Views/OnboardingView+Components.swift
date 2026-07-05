//
// OnboardingView+Components.swift
//
// Extracted from OnboardingView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore


// MARK: - Supporting Types

struct FeatureItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct GenreChip: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(name)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .black.opacity(0.85) : .white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor : Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Particle Effect

struct ParticleView: View {
    @State private var particles: [Particle] = (0..<12).map { _ in Particle() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(Color.white)
                        .frame(width: particle.size, height: particle.size)
                        .position(
                            x: particle.x * geo.size.width,
                            y: particle.y * geo.size.height
                        )
                        .opacity(particle.opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                for i in particles.indices {
                    particles[i].y -= CGFloat.random(in: 0.1...0.3)
                    particles[i].opacity = Double.random(in: 0.05...0.2)
                }
            }
        }
    }

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat = CGFloat.random(in: 0...1)
        var y: CGFloat = CGFloat.random(in: 0...1)
        var size: CGFloat = CGFloat.random(in: 1...3)
        var opacity: Double = Double.random(in: 0.05...0.15)
    }
}
