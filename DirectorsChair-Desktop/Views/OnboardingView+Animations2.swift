//
// OnboardingView+Animations2.swift
//
// Extracted from OnboardingView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore


// MARK: - AI Video Generation Preview Animation

struct AIVideoPreviewAnimation: View {
    let accentCyan: Color
    @State private var animationPhase = 0
    @State private var playbackProgress: CGFloat = 0
    @State private var currentFrame = 0
    @State private var isPlaying = false

    private let frameColors: [Color] = [
        Color(red: 0.2, green: 0.15, blue: 0.1),
        Color(red: 0.25, green: 0.18, blue: 0.12),
        Color(red: 0.15, green: 0.2, blue: 0.25),
        Color(red: 0.1, green: 0.15, blue: 0.25),
        Color(red: 0.2, green: 0.12, blue: 0.18),
        Color(red: 0.12, green: 0.22, blue: 0.18),
    ]

    private let storyboardFrames = [
        ("Wide shot — Coffee shop", "building.2"),
        ("Sarah enters — door push", "figure.walk"),
        ("CU — Sarah sits down", "person.crop.circle"),
        ("Hands on laptop — typing", "hand.raised"),
        ("Reaction — looks up", "eye"),
        ("Wide — stands up, exits", "figure.walk.departure"),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Image(systemName: "film.stack")
                        .font(.system(size: 9))
                        .foregroundColor(accentCyan)
                    Text("AI Video Studio")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    if animationPhase >= 3 {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text("Ready")
                                .font(.system(size: 7))
                                .foregroundColor(.green.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                // Main video preview area
                ZStack {
                    // Video canvas
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: animationPhase >= 3 ?
                                    [frameColors[currentFrame % frameColors.count], frameColors[(currentFrame + 1) % frameColors.count]] :
                                    [Color(red: 0.08, green: 0.08, blue: 0.1), Color(red: 0.06, green: 0.06, blue: 0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    if animationPhase < 2 {
                        // Storyboard -> video conversion indicator
                        VStack(spacing: 8) {
                            Image(systemName: "rectangle.3.group")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.2))
                            Text("Storyboard frames loaded")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    } else if animationPhase == 2 {
                        // Generating
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(accentCyan)
                            Text("Generating video from storyboard...")
                                .font(.system(size: 8))
                                .foregroundColor(accentCyan.opacity(0.7))
                        }
                    } else {
                        // Playing video
                        VStack(spacing: 6) {
                            Image(systemName: storyboardFrames[currentFrame % storyboardFrames.count].1)
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.5))
                            Text(storyboardFrames[currentFrame % storyboardFrames.count].0)
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        // Play button overlay (brief)
                        if !isPlaying {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .offset(x: 1)
                                )
                        }

                        // Timecode
                        VStack {
                            HStack {
                                Spacer()
                                Text(String(format: "00:%02d:%02d", currentFrame * 4, (currentFrame * 17) % 30))
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(3)
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 180)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Playback controls + progress bar
                VStack(spacing: 6) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accentCyan)
                                .frame(width: geo.size.width * playbackProgress)
                        }
                    }
                    .frame(height: 3)

                    // Controls
                    HStack(spacing: 16) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(accentCyan)
                        Image(systemName: "forward.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text("1080p  •  24fps  •  AI Generated")
                            .font(.system(size: 6))
                            .foregroundColor(.white.opacity(0.25))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                // Storyboard film strip at bottom
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(storyboardFrames.enumerated()), id: \.offset) { idx, frame in
                            VStack(spacing: 2) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(frameColors[idx % frameColors.count])
                                    Image(systemName: frame.1)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .frame(width: 58, height: 34)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(idx == currentFrame && animationPhase >= 3 ? accentCyan : Color.white.opacity(0.08), lineWidth: idx == currentFrame && animationPhase >= 3 ? 1.5 : 0.5)
                                )

                                Text("F\(idx + 1)")
                                    .font(.system(size: 5))
                                    .foregroundColor(.white.opacity(0.25))
                            }
                            .opacity(animationPhase > idx ? 1.0 : 0.3)
                            .scaleEffect(animationPhase > idx ? 1.0 : 0.9)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Phase 1: Storyboard frames slide in
        for i in 1...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    animationPhase = i
                }
            }
        }

        // Phase 2: Start generating (at 1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { animationPhase = 2 }
        }

        // Phase 3: Video ready, start playing (at 2.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.4)) { animationPhase = 3 }
        }

        // Start playback (at 3.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isPlaying = true
            // Animate playback progress
            withAnimation(.linear(duration: 6.0)) {
                playbackProgress = 1.0
            }
            // Cycle through frames
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentFrame = (currentFrame + 1) % storyboardFrames.count
                }
                if currentFrame == 0 {
                    timer.invalidate()
                    isPlaying = false
                }
            }
        }
    }
}

// MARK: - Editing Automation Preview Animation (DaVinci Resolve + Smart Clapboard)

struct EditingAutomationPreviewAnimation: View {
    let accentCyan: Color
    @State private var animationPhase = 0
    @State private var timelineClips = 0
    @State private var clapboardFlash = false
    @State private var exportProgress: CGFloat = 0

    private let trackColors: [Color] = [
        Color(red: 0.3, green: 0.6, blue: 0.9),
        Color(red: 0.3, green: 0.8, blue: 0.5),
        Color(red: 0.9, green: 0.5, blue: 0.3),
        Color(red: 0.6, green: 0.3, blue: 0.8),
    ]

    private let clipWidths: [[CGFloat]] = [
        [60, 45, 70, 55, 40, 65],
        [50, 70, 35, 60, 55, 45],
        [40, 55, 65, 45, 70, 50],
        [70, 40, 50, 60, 35, 55],
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Image(systemName: "slider.horizontal.below.rectangle")
                        .font(.system(size: 9))
                        .foregroundColor(accentCyan)
                    Text("Editing Automation")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                HStack(alignment: .top, spacing: 10) {
                    // Left: DaVinci Resolve timeline mockup
                    VStack(alignment: .leading, spacing: 0) {
                        // DaVinci header
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red.opacity(0.7))
                                .frame(width: 10, height: 10)
                            Text("DaVinci Resolve Timeline")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            if animationPhase >= 6 {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 7))
                                        .foregroundColor(.green)
                                    Text("Synced")
                                        .font(.system(size: 6))
                                        .foregroundColor(.green.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.12))

                        // Timecode ruler
                        HStack(spacing: 0) {
                            ForEach(0..<12, id: \.self) { i in
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 1, height: 8)
                                    Text("\(i)s")
                                        .font(.system(size: 5))
                                        .foregroundColor(.white.opacity(0.2))
                                }
                                .frame(width: 28)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)

                        // Timeline tracks
                        VStack(spacing: 3) {
                            ForEach(0..<4, id: \.self) { trackIdx in
                                HStack(spacing: 0) {
                                    // Track label
                                    Text(["V1", "V2", "A1", "A2"][trackIdx])
                                        .font(.system(size: 6, weight: .bold))
                                        .foregroundColor(.white.opacity(0.3))
                                        .frame(width: 20)

                                    // Clips
                                    HStack(spacing: 2) {
                                        ForEach(0..<min(timelineClips, 6), id: \.self) { clipIdx in
                                            let w = clipWidths[trackIdx][clipIdx]
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(trackColors[trackIdx].opacity(0.5))
                                                .frame(width: w, height: 18)
                                                .overlay(
                                                    Text("Sc\(clipIdx + 1)")
                                                        .font(.system(size: 5))
                                                        .foregroundColor(.white.opacity(0.4))
                                                )
                                                .transition(.scale(scale: 0, anchor: .leading).combined(with: .opacity))
                                        }
                                    }
                                }
                                .frame(height: 20)
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(.vertical, 4)
                        .background(Color(red: 0.07, green: 0.07, blue: 0.09))

                        // Scene markers
                        if animationPhase >= 5 {
                            HStack(spacing: 6) {
                                ForEach(["Sc1", "Sc2", "Sc3", "Sc4", "Sc5", "Sc6"], id: \.self) { marker in
                                    VStack(spacing: 1) {
                                        Triangle()
                                            .fill(accentCyan.opacity(0.6))
                                            .frame(width: 6, height: 4)
                                        Text(marker)
                                            .font(.system(size: 5))
                                            .foregroundColor(accentCyan.opacity(0.5))
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 4)
                            .transition(.opacity)
                        }

                        Spacer()

                        // Export status
                        if animationPhase >= 7 {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 7))
                                    .foregroundColor(accentCyan)
                                Text("Exported: timeline.xml")
                                    .font(.system(size: 7))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.08))
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(accentCyan)
                                            .frame(width: geo.size.width * exportProgress)
                                    }
                                }
                                .frame(width: 60, height: 4)
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                            .transition(.opacity)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )

                    // Right: Smart Clapboard
                    VStack(spacing: 8) {
                        // Clapboard
                        VStack(spacing: 0) {
                            // Clapper sticks
                            ZStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                                    .frame(height: 24)

                                // Diagonal stripes
                                HStack(spacing: 6) {
                                    ForEach(0..<8, id: \.self) { _ in
                                        Rectangle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 8)
                                            .rotationEffect(.degrees(-45))
                                    }
                                }
                                .clipped()
                                .frame(height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .opacity(clapboardFlash ? 0.6 : 0.3)
                            }

                            // Slate content
                            VStack(spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("SCENE")
                                            .font(.system(size: 5, weight: .bold))
                                            .foregroundColor(.white.opacity(0.3))
                                        Text("1")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("TAKE")
                                            .font(.system(size: 5, weight: .bold))
                                            .foregroundColor(.white.opacity(0.3))
                                        Text("3")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("SHOT")
                                            .font(.system(size: 5, weight: .bold))
                                            .foregroundColor(.white.opacity(0.3))
                                        Text("1A")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }

                                Divider().background(Color.white.opacity(0.1))

                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("INT. COFFEE SHOP")
                                            .font(.system(size: 6, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                        Text("Wide establishing")
                                            .font(.system(size: 5))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    Spacer()
                                }

                                if animationPhase >= 2 {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.red).frame(width: 5, height: 5)
                                        Text("SYNCING")
                                            .font(.system(size: 5, weight: .bold))
                                            .foregroundColor(.red.opacity(0.8))
                                        Spacer()
                                        Image(systemName: "ipad.landscape")
                                            .font(.system(size: 7))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                    .transition(.opacity)
                                }
                            }
                            .padding(8)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .scaleEffect(animationPhase >= 1 ? 1.0 : 0.9)
                        .opacity(animationPhase >= 1 ? 1.0 : 0.0)

                        // Metadata sync status
                        if animationPhase >= 3 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("METADATA SYNC")
                                    .font(.system(size: 5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.3))
                                    .tracking(0.8)

                                ForEach(["Scene info", "Take notes", "Timecode", "Camera settings"], id: \.self) { item in
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 6))
                                            .foregroundColor(.green.opacity(0.7))
                                        Text(item)
                                            .font(.system(size: 6))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(width: 140)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Phase 1: Clapboard appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { animationPhase = 1 }
        }

        // Phase 2: Clapboard flash + sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.1)) { clapboardFlash = true }
            withAnimation { animationPhase = 2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.3)) { clapboardFlash = false }
            }
        }

        // Phase 3: Metadata sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.5)) { animationPhase = 3 }
        }

        // Phase 4: Timeline clips start populating
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            animationPhase = 4
            for i in 1...6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        timelineClips = i
                    }
                }
            }
        }

        // Phase 5: Scene markers appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeOut(duration: 0.4)) { animationPhase = 5 }
        }

        // Phase 6: Synced badge
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            withAnimation(.easeOut(duration: 0.3)) { animationPhase = 6 }
        }

        // Phase 7: Export
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.3)) { animationPhase = 7 }
            withAnimation(.easeOut(duration: 1.5)) { exportProgress = 1.0 }
        }
    }
}

// Triangle shape for scene markers
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Smart Clapboard Preview Animation

struct SmartClapboardPreviewAnimation: View {
    let accentCyan: Color

    @State private var clapAngle: Double = 0          // clapper stick rotation
    @State private var currentSlate = 0                // which scene/shot/take combo to show
    @State private var slateOpacity: Double = 1.0
    @State private var syncPulse = false
    @State private var connectedBadge = false
    @State private var takeNotes: [String] = []

    private let slates: [(scene: String, shot: String, take: String, location: String, desc: String)] = [
        ("1",  "1A", "1", "INT. COFFEE SHOP — MORNING", "Wide establishing"),
        ("1",  "1B", "2", "INT. COFFEE SHOP — MORNING", "CU Sarah's face"),
        ("3",  "2A", "1", "EXT. CITY STREET — DAY",     "Tracking shot"),
        ("5",  "3A", "3", "INT. SARAH'S APT — EVENING",  "OTS laptop"),
        ("6",  "4A", "1", "EXT. ROOFTOP — NIGHT",        "Low angle wide"),
        ("1",  "1A", "4", "INT. COFFEE SHOP — MORNING", "Wide establishing — circle take"),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            VStack(spacing: 0) {
                // Top bar — iPad frame hint
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "ipad.landscape")
                            .font(.system(size: 9))
                            .foregroundColor(accentCyan)
                        Text("Director's Chair — Smart Clapboard")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    if connectedBadge {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                                .scaleEffect(syncPulse ? 1.3 : 1.0)
                            Text("Connected")
                                .font(.system(size: 7))
                                .foregroundColor(.green.opacity(0.8))
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                Spacer().frame(height: 10)

                // The Clapboard
                ZStack {
                    VStack(spacing: 0) {
                        // Clapper sticks (top part that rotates)
                        ZStack {
                            clapperSticks
                                .rotationEffect(.degrees(-clapAngle), anchor: .leading)
                        }
                        .frame(height: 32)
                        .zIndex(1)

                        // Slate body
                        VStack(spacing: 0) {
                            // Fixed top stripe bar (bottom half of clapper)
                            clapperSticks
                                .frame(height: 32)

                            // Slate content
                            slateContent
                        }
                        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 30)

                Spacer().frame(height: 10)

                // Take notes panel
                if !takeNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TAKE NOTES")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                            .tracking(0.8)

                        ForEach(Array(takeNotes.enumerated()), id: \.offset) { _, note in
                            HStack(spacing: 4) {
                                let isCircled = note.contains("CIRCLED")
                                Image(systemName: isCircled ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 6))
                                    .foregroundColor(isCircled ? .green : .white.opacity(0.25))
                                Text(note)
                                    .font(.system(size: 7))
                                    .foregroundColor(isCircled ? .green.opacity(0.8) : .white.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
        }
        .onAppear { startClapSequence() }
    }

    // MARK: - Clapper Sticks

    private var clapperSticks: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.17))

            // Diagonal stripes
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<20, id: \.self) { i in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: geo.size.width / 20)
                            Rectangle()
                                .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                                .frame(width: geo.size.width / 20)
                        }
                    }
                }
                .rotationEffect(.degrees(-20))
                .offset(y: -4)
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 32)
    }

    // MARK: - Slate Content

    private var slateContent: some View {
        let slate = slates[currentSlate % slates.count]

        return VStack(spacing: 8) {
            // Production title
            Text("DIRECTOR'S CHAIR")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(accentCyan)
                .tracking(2)
                .padding(.top, 10)

            // Main fields
            HStack(spacing: 0) {
                slateField(label: "SCENE", value: slate.scene, large: true)
                slateDivider
                slateField(label: "SHOT", value: slate.shot, large: true)
                slateDivider
                slateField(label: "TAKE", value: slate.take, large: true)
            }
            .padding(.horizontal, 12)
            .opacity(slateOpacity)

            // Location + description
            VStack(spacing: 3) {
                Text(slate.location)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Text(slate.desc)
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.4))
            }
            .opacity(slateOpacity)

            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 16)

            // Bottom row — camera, date, FPS
            HStack {
                slateFieldSmall(label: "CAMERA", value: "A")
                Spacer()
                slateFieldSmall(label: "DATE", value: "03/15/26")
                Spacer()
                slateFieldSmall(label: "FPS", value: "24")
                Spacer()
                slateFieldSmall(label: "LENS", value: "35mm")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Sync indicator
            if syncPulse {
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 7))
                        .foregroundColor(accentCyan)
                        .opacity(syncPulse ? 1.0 : 0.3)
                    Text("Syncing to Director's Chair Desktop...")
                        .font(.system(size: 6))
                        .foregroundColor(accentCyan.opacity(0.6))
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
    }

    private func slateField(label: String, value: String, large: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 5, weight: .bold))
                .foregroundColor(.white.opacity(0.3))
                .tracking(0.8)
            Text(value)
                .font(.system(size: large ? 28 : 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    private var slateDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 40)
    }

    private func slateFieldSmall(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 4, weight: .bold))
                .foregroundColor(.white.opacity(0.25))
                .tracking(0.5)
            Text(value)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Animation Sequence

    private func startClapSequence() {
        // Connected badge
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.3)) { connectedBadge = true }
        }

        // Start cycling through slates with clap animation
        performClap(atDelay: 1.0, toSlate: 1, note: "Sc1 Shot1B Take2 — Good energy")
        performClap(atDelay: 3.0, toSlate: 2, note: "Sc3 Shot2A Take1 — Tracking steady")
        performClap(atDelay: 5.0, toSlate: 3, note: "Sc5 Shot3A Take3 — Adjust lighting")
        performClap(atDelay: 7.0, toSlate: 4, note: "Sc6 Shot4A Take1 — Night setup")
        performClap(atDelay: 9.0, toSlate: 5, note: "Sc1 Shot1A Take4 — CIRCLED ★")
    }

    private func performClap(atDelay delay: Double, toSlate: Int, note: String) {
        // Clap down
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.08)) {
                clapAngle = 25
            }
        }

        // Fade out old content during clap
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.05) {
            withAnimation(.easeOut(duration: 0.06)) {
                slateOpacity = 0.0
            }
        }

        // Change slate content
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.12) {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                currentSlate = toSlate
            }
        }

        // Clap back up
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.15) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                clapAngle = 0
            }
            withAnimation(.easeIn(duration: 0.15)) {
                slateOpacity = 1.0
            }
        }

        // Sync pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.4) {
            withAnimation(.easeInOut(duration: 0.3)) { syncPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.3)) { syncPulse = false }
            }
        }

        // Add take note
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.6) {
            withAnimation(.spring(response: 0.3)) {
                takeNotes.append(note)
                if takeNotes.count > 4 { takeNotes.removeFirst() }
            }
        }
    }
}
