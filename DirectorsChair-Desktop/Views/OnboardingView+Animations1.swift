//
// OnboardingView+Animations1.swift
//
// Extracted from OnboardingView.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore


// MARK: - Script Preview Animation (typing screenplay text)

struct ScriptPreviewAnimation: View {
    let accentCyan: Color
    @State private var visibleLines = 0
    @State private var cursorVisible = true

    private let scriptLines: [(String, ScriptLineType)] = [
        ("INT. COFFEE SHOP - MORNING", .sceneHeading),
        ("", .spacing),
        ("The morning sun filters through dusty windows.", .action),
        ("SARAH (30s, determined) sits at a corner table,", .action),
        ("laptop open, coffee untouched.", .action),
        ("", .spacing),
        ("SARAH", .character),
        ("I've been waiting for this moment", .dialogue),
        ("my entire life.", .dialogue),
        ("", .spacing),
        ("(looking up)", .parenthetical),
        ("", .spacing),
        ("SARAH", .character),
        ("And I'm not going to let anyone", .dialogue),
        ("stop me now.", .dialogue),
        ("", .spacing),
        ("EXT. CITY STREET - CONTINUOUS", .sceneHeading),
        ("", .spacing),
        ("Sarah bursts through the door, determination", .action),
        ("in every step.", .action),
    ]

    enum ScriptLineType {
        case sceneHeading, action, character, dialogue, parenthetical, spacing
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            HStack(spacing: 0) {
                // Mini sidebar
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(["Overview", "Script", "Timeline", "Story Design", "Production"], id: \.self) { item in
                        Text(item)
                            .font(.system(size: 8))
                            .foregroundColor(item == "Script" ? accentCyan : .white.opacity(0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                item == "Script" ?
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)) :
                                    RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                            )
                    }
                    Spacer()
                }
                .frame(width: 80)
                .padding(.top, 40)
                .padding(.leading, 8)
                .background(Color(red: 0.03, green: 0.04, blue: 0.06))

                // Script content
                VStack(alignment: .leading, spacing: 0) {
                    // Toolbar
                    HStack {
                        Text("Script")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                    // Script text area
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(scriptLines.prefix(visibleLines).enumerated()), id: \.offset) { index, line in
                                scriptLineView(line.0, type: line.1, isLast: index == visibleLines - 1)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Format bar at bottom
                    HStack(spacing: 0) {
                        ForEach(["Scene Heading", "Action", "Character", "Dialogue", "Transition"], id: \.self) { fmt in
                            Text(fmt)
                                .font(.system(size: 7))
                                .foregroundColor(fmt == "Dialogue" ? accentCyan : .white.opacity(0.3))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    fmt == "Dialogue" ?
                                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)) :
                                        RoundedRectangle(cornerRadius: 3).fill(Color.clear)
                                )
                        }
                    }
                    .padding(6)
                    .background(Color(red: 0.04, green: 0.05, blue: 0.07))
                }
            }
        }
        .onAppear {
            startTypingAnimation()
            startCursorBlink()
        }
    }

    private func scriptLineView(_ text: String, type: ScriptLineType, isLast: Bool) -> some View {
        HStack(spacing: 0) {
            switch type {
            case .sceneHeading:
                Text(text)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(accentCyan)
            case .action:
                Text(text)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.8))
            case .character:
                Spacer().frame(width: 100)
                Text(text)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            case .dialogue:
                Spacer().frame(width: 60)
                Text(text)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.75))
            case .parenthetical:
                Spacer().frame(width: 70)
                Text(text)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            case .spacing:
                Text(" ")
                    .font(.system(size: 6))
            }

            if isLast && cursorVisible {
                Rectangle()
                    .fill(accentCyan)
                    .frame(width: 1.5, height: 12)
                    .padding(.leading, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func startTypingAnimation() {
        for i in 1...scriptLines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.18) {
                withAnimation(.easeOut(duration: 0.15)) {
                    visibleLines = i
                }
            }
        }
    }

    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }
}

// MARK: - Timeline Preview Animation (sliding scene blocks)

struct TimelinePreviewAnimation: View {
    let accentCyan: Color
    @State private var animationPhase = 0

    private let sceneColors: [Color] = [
        Color(red: 0.3, green: 0.6, blue: 0.9),
        Color(red: 0.9, green: 0.4, blue: 0.3),
        Color(red: 0.3, green: 0.8, blue: 0.5),
        Color(red: 0.8, green: 0.6, blue: 0.2),
        Color(red: 0.6, green: 0.3, blue: 0.8),
        Color(red: 0.3, green: 0.7, blue: 0.7),
    ]

    private let scenes = ["INT. COFFEE\nSHOP", "EXT. CITY\nSTREET", "INT. OFFICE\nLOBBY", "EXT. PARK\nBENCH", "INT. SARAH'S\nAPT", "EXT. ROOFTOP\nNIGHT"]
    private let rows = ["Sarah", "James", "Coffee Cup", "Laptop", "City Sounds", "Music"]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            HStack(spacing: 0) {
                // Mini sidebar
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(["Overview", "Script", "Timeline", "Story Design", "Production"], id: \.self) { item in
                        Text(item)
                            .font(.system(size: 8))
                            .foregroundColor(item == "Timeline" ? accentCyan : .white.opacity(0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                item == "Timeline" ?
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)) :
                                    RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                            )
                    }
                    Spacer()
                }
                .frame(width: 80)
                .padding(.top, 40)
                .padding(.leading, 8)
                .background(Color(red: 0.03, green: 0.04, blue: 0.06))

                VStack(alignment: .leading, spacing: 0) {
                    // Toolbar
                    HStack {
                        Text("Timeline")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                    // Scene header blocks
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(scenes.enumerated()), id: \.offset) { i, scene in
                                let lines = scene.split(separator: "\n")
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(String(lines[0]))
                                        .font(.system(size: 6, weight: .bold))
                                    if lines.count > 1 {
                                        Text(String(lines[1]))
                                            .font(.system(size: 6))
                                    }
                                }
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                                .frame(width: CGFloat.random(in: 65...80), height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(sceneColors[i].opacity(0.7))
                                )
                                .scaleEffect(animationPhase > i ? 1.0 : 0.0)
                                .opacity(animationPhase > i ? 1.0 : 0.0)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }

                    // Timeline rows
                    VStack(spacing: 2) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, rowName in
                            HStack(spacing: 4) {
                                Text(rowName)
                                    .font(.system(size: 7))
                                    .foregroundColor(.white.opacity(0.35))
                                    .frame(width: 50, alignment: .leading)

                                ForEach(0..<6, id: \.self) { colIdx in
                                    let present = (rowIdx + colIdx) % 3 != 2
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(present ? sceneColors[colIdx].opacity(0.3) : Color.clear)
                                        .frame(width: CGFloat.random(in: 50...70), height: 16)
                                        .scaleEffect(x: animationPhase > 6 + rowIdx ? 1.0 : 0.0, y: 1.0, anchor: .leading)
                                        .opacity(animationPhase > 6 + rowIdx ? 1.0 : 0.0)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.top, 4)

                    Spacer()

                    // Shot list panel
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SHOT LIST — Scene 1")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(accentCyan)

                        ForEach(["Wide establishing", "CU Sarah's face", "OTS laptop screen", "Medium two-shot"], id: \.self) { shot in
                            Text(shot)
                                .font(.system(size: 7))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.04))
                                )
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .opacity(animationPhase > 12 ? 1.0 : 0.0)
                }
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Animate scene headers one by one, then rows, then shot list
        for i in 1...14 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    animationPhase = i
                }
            }
        }
    }
}

// MARK: - Production Preview Animation (schedule + budget)

struct ProductionPreviewAnimation: View {
    let accentCyan: Color
    @State private var animationPhase = 0
    @State private var budgetProgress: CGFloat = 0
    @State private var spentAmount = 0

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            HStack(spacing: 0) {
                // Mini sidebar
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(["Overview", "Script", "Timeline", "Story Design", "Production"], id: \.self) { item in
                        Text(item)
                            .font(.system(size: 8))
                            .foregroundColor(item == "Production" ? accentCyan : .white.opacity(0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                item == "Production" ?
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)) :
                                    RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                            )
                    }
                    Spacer()
                }
                .frame(width: 80)
                .padding(.top, 40)
                .padding(.leading, 8)
                .background(Color(red: 0.03, green: 0.04, blue: 0.06))

                VStack(alignment: .leading, spacing: 0) {
                    // Toolbar
                    HStack {
                        Text("Production")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                    // Sub-tabs
                    HStack(spacing: 12) {
                        ForEach(["Schedule", "Budget", "Cast & Crew"], id: \.self) { tab in
                            Text(tab)
                                .font(.system(size: 8))
                                .foregroundColor(tab == "Schedule" ? accentCyan : .white.opacity(0.3))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    tab == "Schedule" ?
                                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)) :
                                        RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                                )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    HStack(alignment: .top, spacing: 12) {
                        // Schedule cards
                        VStack(alignment: .leading, spacing: 8) {
                            // Day 1
                            scheduleCard(
                                day: "Day 1 — Monday, Mar 15",
                                callTime: "Call: 7:00 AM  |  Wrap: 6:00 PM",
                                scenes: [
                                    ("Sc 1", "INT. COFFEE SHOP", "Morning", Color(red: 0.3, green: 0.6, blue: 0.9)),
                                    ("Sc 3", "INT. OFFICE LOBBY", "Afternoon", Color(red: 0.3, green: 0.8, blue: 0.5)),
                                    ("Sc 5", "INT. SARAH'S APT", "Evening", Color(red: 0.6, green: 0.3, blue: 0.8)),
                                ],
                                visible: animationPhase > 0
                            )

                            // Day 2
                            scheduleCard(
                                day: "Day 2 — Tuesday, Mar 16",
                                callTime: "Call: 8:00 AM  |  Wrap: 7:00 PM",
                                scenes: [
                                    ("Sc 2", "EXT. CITY STREET", "Morning", Color(red: 0.9, green: 0.4, blue: 0.3)),
                                    ("Sc 6", "EXT. ROOFTOP", "Night", Color(red: 0.3, green: 0.7, blue: 0.7)),
                                ],
                                visible: animationPhase > 1
                            )
                        }
                        .frame(maxWidth: .infinity)

                        // Budget + Crew panels
                        VStack(spacing: 8) {
                            // Budget card
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Budget Overview")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.85))

                                HStack {
                                    Text("Total Budget")
                                        .font(.system(size: 7))
                                        .foregroundColor(.white.opacity(0.4))
                                    Spacer()
                                    Text("$125,000")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                }

                                HStack {
                                    Text("Spent")
                                        .font(.system(size: 7))
                                        .foregroundColor(.white.opacity(0.4))
                                    Spacer()
                                    Text("$\(spentAmount.formatted())")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                }

                                HStack {
                                    Text("Remaining")
                                        .font(.system(size: 7))
                                        .foregroundColor(.white.opacity(0.4))
                                    Spacer()
                                    Text("$\((125000 - spentAmount).formatted())")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
                                }

                                // Progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.08))
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(accentCyan)
                                            .frame(width: geo.size.width * budgetProgress)
                                    }
                                }
                                .frame(height: 4)

                                Text("\(Int(budgetProgress * 100))% spent")
                                    .font(.system(size: 6))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            .opacity(animationPhase > 2 ? 1.0 : 0.0)

                            // Cast card
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Cast & Crew")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.85))

                                ForEach([("Sarah Miller", "Lead"), ("James Chen", "Supporting"), ("Maria Lopez", "Director")], id: \.0) { name, role in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 14, height: 14)
                                        Text(name)
                                            .font(.system(size: 7))
                                            .foregroundColor(.white.opacity(0.7))
                                        Spacer()
                                        Text(role)
                                            .font(.system(size: 6))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            .opacity(animationPhase > 3 ? 1.0 : 0.0)
                        }
                        .frame(width: 150)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)

                    Spacer()
                }
            }
        }
        .onAppear { startAnimation() }
    }

    private func scheduleCard(day: String, callTime: String, scenes: [(String, String, String, Color)], visible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(day)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
            Text(callTime)
                .font(.system(size: 7))
                .foregroundColor(.white.opacity(0.35))

            ForEach(Array(scenes.enumerated()), id: \.offset) { _, scene in
                HStack(spacing: 6) {
                    Text(scene.0)
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(scene.3.opacity(0.7))
                        )
                    Text(scene.1)
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(scene.2)
                        .font(.system(size: 6))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(scene.3.opacity(0.1))
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.06, green: 0.08, blue: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .scaleEffect(visible ? 1.0 : 0.95)
        .opacity(visible ? 1.0 : 0.0)
    }

    private func startAnimation() {
        // Phase 1-4: cards appear
        for i in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animationPhase = i
                }
            }
        }

        // Budget counter animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 1.5)) {
                budgetProgress = 0.346
            }
            // Count up the spent amount
            let target = 43200
            let steps = 30
            for step in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.05) {
                    spentAmount = Int(Double(target) * Double(step) / Double(steps))
                }
            }
        }
    }
}

// MARK: - AI Image Generation Preview Animation

struct AIImagePreviewAnimation: View {
    let accentCyan: Color
    @State private var animationPhase = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var promptChars = 0

    private let promptText = "Wide shot, dimly lit coffee shop, golden morning light streaming through dusty windows, cinematic"

    private let shotThumbnails: [(String, String, Color)] = [
        ("Wide establishing", "camera", Color(red: 0.3, green: 0.6, blue: 0.9)),
        ("CU Sarah's face", "person.crop.circle", Color(red: 0.9, green: 0.5, blue: 0.3)),
        ("OTS laptop", "laptopcomputer", Color(red: 0.3, green: 0.8, blue: 0.5)),
        ("Low angle exterior", "building.2", Color(red: 0.8, green: 0.6, blue: 0.2)),
        ("Mood: warm tones", "sun.max", Color(red: 0.9, green: 0.7, blue: 0.3)),
        ("Mood: cool night", "moon.stars", Color(red: 0.4, green: 0.4, blue: 0.8)),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.09)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Image(systemName: "photo.fill.on.rectangle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(accentCyan)
                    Text("AI Image Studio")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("Scene 1: INT. COFFEE SHOP")
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.04, green: 0.05, blue: 0.07))

                // Prompt input area
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROMPT")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .tracking(1)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(accentCyan.opacity(0.3), lineWidth: 1)
                            )

                        HStack(spacing: 0) {
                            Text(String(promptText.prefix(promptChars)))
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.75))
                            if animationPhase < 2 {
                                Rectangle()
                                    .fill(accentCyan)
                                    .frame(width: 1, height: 10)
                                    .opacity(animationPhase >= 1 ? 1 : 0)
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                    .frame(height: 36)

                    // Generate button
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 7))
                            Text(animationPhase >= 2 ? "Generating..." : "Generate")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundColor(animationPhase >= 2 ? accentCyan : .black.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(animationPhase >= 2 ? accentCyan.opacity(0.15) : accentCyan)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Generated images grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(shotThumbnails.enumerated()), id: \.offset) { idx, shot in
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [shot.2.opacity(0.4), shot.2.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            // Shimmer loading effect
                            if animationPhase == 2 + idx {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .white.opacity(0.15), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .offset(x: shimmerOffset)
                                    .clipped()
                            }

                            if animationPhase > 2 + idx {
                                VStack(spacing: 4) {
                                    Image(systemName: shot.1)
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(shot.0)
                                        .font(.system(size: 6, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            } else if animationPhase <= 2 + idx && animationPhase >= 2 {
                                ProgressView()
                                    .scaleEffect(0.4)
                                    .tint(.white.opacity(0.4))
                            }
                        }
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(animationPhase > 2 + idx ? shot.2.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .opacity(animationPhase >= 2 ? 1.0 : 0.3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Style selector at bottom
                HStack(spacing: 8) {
                    ForEach(["Cinematic", "Photorealistic", "Storyboard", "Concept Art"], id: \.self) { style in
                        Text(style)
                            .font(.system(size: 7))
                            .foregroundColor(style == "Cinematic" ? accentCyan : .white.opacity(0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(style == "Cinematic" ? Color.white.opacity(0.06) : Color.clear)
                            )
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Phase 1: Start typing prompt
        animationPhase = 1
        let chars = promptText.count
        for i in 1...chars {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.025) {
                promptChars = i
            }
        }

        // Phase 2: Click generate
        let typingDuration = Double(chars) * 0.025 + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            withAnimation(.easeOut(duration: 0.2)) { animationPhase = 2 }
        }

        // Shimmer animation
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }

        // Phase 3-8: Images appear one by one
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration + 0.5 + Double(i) * 0.35) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    animationPhase = 3 + i
                }
            }
        }
    }
}
