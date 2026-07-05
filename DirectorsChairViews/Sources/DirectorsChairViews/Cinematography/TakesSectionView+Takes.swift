//
// TakesSectionView+Takes.swift
//
// Extracted from TakesSectionView.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension; private -> internal so the
// main struct's body can still reach them. Behaviour unchanged.
//

import SwiftUI
import AVFoundation
import AVKit
import DirectorsChairCore
import DirectorsChairServices

extension TakesSectionView {

    // MARK: - LUT Selector

    var lutSelectorRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera.filters")
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.5))

            Text("LUT")
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(.gray.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(LUTPreset.allCases) { preset in
                        lutChip(preset)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    func lutChip(_ preset: LUTPreset) -> some View {
        let isSelected = captureService.selectedLUT == preset

        return Button {
            captureService.setLUT(preset)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: preset.icon)
                    .font(.system(size: 8))
                Text(preset.shortLabel)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundColor(isSelected ? .white : .gray)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(hex: "#3A3A3A"))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Review Bay

    func takeReviewBay(_ take: Take) -> some View {
        VStack(spacing: 0) {
            // Top: Video (left) + Metadata (right)
            reviewPanel(take)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Bottom: Horizontal take grid with filter
            takesGrid
        }
        .background(Color(hex: "#1A1A1A"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }

    // MARK: - Takes Grid (Bottom Pane)

    var takesGrid: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack(spacing: 8) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
                Text("TAKES")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.gray.opacity(0.5))

                Text("\(sortedTakes.count)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.4)))

                // Renumber takes
                if shot.takes.count > 1 {
                    Button { renumberTakes() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 8, weight: .semibold))
                            Text("Renumber")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("Renumber takes sequentially")
                }

                Spacer()

                // Rating filter chips
                takeFilterChip(label: "All", icon: "film.stack", filter: nil)
                takeFilterChip(label: "Circle", icon: "checkmark.circle.fill", filter: .circle, color: .green)
                takeFilterChip(label: "Alt", icon: "star.fill", filter: .alt, color: .orange)
                takeFilterChip(label: "NG", icon: "xmark.circle.fill", filter: .ng, color: .red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)

            // Horizontal scrolling grid of take cards
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 8) {
                    ForEach(filteredTakes) { take in
                        takeGridCard(take)
                    }
                }
                .padding(10)
            }
            .frame(height: 140)
        }
        .background(Color(hex: "#161616"))
    }

    func takeFilterChip(label: String, icon: String, filter: TakeRating?, color: Color = .accentColor) -> some View {
        let isActive = ratingFilter == filter
        let count = filter == nil ? sortedTakes.count : sortedTakes.filter { $0.rating == filter }.count

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { ratingFilter = filter }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 9, weight: isActive ? .semibold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(isActive ? .white : .gray)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundColor(isActive ? .white : color == .accentColor ? .gray : color)
            .background(
                Capsule().fill(isActive ? color.opacity(0.7) : Color(hex: "#2A2A2A"))
            )
        }
        .buttonStyle(.plain)
    }

    func takeGridCard(_ take: Take) -> some View {
        let isSelected = (selectedTakeId ?? sortedTakes.first?.id) == take.id
        let isHovered = hoveredTakeId == take.id

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTakeId = take.id }
        } label: {
            VStack(spacing: 0) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    if let videoPath = take.capturedVideoPath, let basePath = projectBasePath {
                        let fullURL = basePath.deletingLastPathComponent().appendingPathComponent(videoPath)
                        TakeThumbnailView(videoURL: fullURL)
                            .id("\(take.id)-\(take.endTimestamp?.timeIntervalSince1970 ?? 0)")
                            .frame(width: 150, height: 84)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(hex: "#1E1E1E"))
                            .frame(width: 150, height: 84)
                            .overlay(
                                Image(systemName: "video.slash")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray.opacity(0.2))
                            )
                    }

                    // Duration badge
                    if let dur = take.durationSeconds {
                        Text(formatDuration(dur))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(3)
                            .padding(4)
                    }
                }

                // Info bar: T#, rating label, film icon
                HStack(spacing: 5) {
                    Text("T\(take.takeNumber)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))

                    // Rating label badge
                    if take.rating != .none {
                        takeRatingBadge(take.rating)
                    }

                    Spacer()

                    if take.capturedVideoPath != nil {
                        Image(systemName: "film.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.green.opacity(0.5))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .frame(width: 150)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : isHovered ? Color.white.opacity(0.04) : Color(hex: "#222222"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.5) :
                            isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.03),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { h in hoveredTakeId = h ? take.id : nil }
        .contextMenu {
            Button { deleteTake(take) } label: {
                Label("Delete Take", systemImage: "trash")
            }
        }
    }

    func takeRatingBadge(_ rating: TakeRating) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(ratingColor(rating))
                .frame(width: 5, height: 5)
            Text(rating == .circle ? "Circle" : rating == .alt ? "Alt" : "NG")
                .font(.system(size: 8, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundColor(ratingColor(rating))
        .background(
            Capsule().fill(ratingColor(rating).opacity(0.15))
        )
    }

    // MARK: - Review Panel (Right Pane) — Video left, Metadata right

    func reviewPanel(_ take: Take) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Left half: Video + transport
            VStack(spacing: 0) {
                reviewVideoSection(take)
            }
            .frame(maxWidth: .infinity)
            .padding(12)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1)

            // Right half: Metadata
            ScrollView(.vertical, showsIndicators: false) {
                reviewMetadataCard(take)
            }
            .frame(maxWidth: .infinity)
        }
    }

    func reviewVideoSection(_ take: Take) -> some View {
        Group {
            if let videoPath = take.capturedVideoPath, let basePath = projectBasePath {
                let fullURL = basePath.deletingLastPathComponent().appendingPathComponent(videoPath)
                ReviewPlayerView(videoURL: fullURL)
                    .id("\(take.id)-\(take.endTimestamp?.timeIntervalSince1970 ?? 0)")
            } else {
                // No-video placeholder
                VStack(spacing: 0) {
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .aspectRatio(16/9, contentMode: .fit)

                        VStack(spacing: 10) {
                            Image(systemName: "film")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.25))
                            Text("No Video")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray.opacity(0.4))
                            Button { mapCameraFile(for: take) } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 9))
                                    Text("Map Camera File")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.accentColor))
                                .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
                    )
                }
            }
        }
    }

    func reviewMetadataCard(_ take: Take) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Take # + rating pills
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("#\(take.takeNumber)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    if let dur = take.durationSeconds {
                        Text(formatDuration(dur))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .monospacedDigit()
                    } else {
                        Text("--:--")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.3))
                    }

                    Button { deleteTake(take) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }

                // Rating pills
                HStack(spacing: 4) {
                    ratingPill(take: take, rating: .circle)
                    ratingPill(take: take, rating: .alt)
                    ratingPill(take: take, rating: .ng)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Timestamps
            if take.startTimestamp != nil || take.endTimestamp != nil {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.accentColor)
                        Text("TIMESTAMPS")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(.gray.opacity(0.5))
                        Spacer()
                        if let formatted = take.formattedStartTimestamp {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(formatted, forType: .string)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 7))
                                    Text("Copy")
                                        .font(.system(size: 7, weight: .medium))
                                }
                                .foregroundColor(.gray.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        if let formatted = take.formattedStartTimestamp {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("REC START")
                                    .font(.system(size: 7, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundColor(.gray.opacity(0.4))
                                Text(formatted)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .monospacedDigit()
                            }
                        }

                        if let formatted = take.formattedEndTimestamp {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("REC END")
                                    .font(.system(size: 7, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundColor(.gray.opacity(0.4))
                                Text(formatted)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(6)
            }

            // Notes
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "note.text")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("NOTES")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.gray.opacity(0.4))
                }

                TextField("Add notes...", text: Binding(
                    get: { editingNotesTakeId == take.id ? editingNotes : take.notes },
                    set: { newValue in
                        editingNotes = newValue
                        editingNotesTakeId = take.id
                        notesDebounceTask?.cancel()
                        notesDebounceTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            guard !Task.isCancelled else { return }
                            var updated = shot
                            if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
                                updated.takes[idx].notes = newValue
                                onShotUpdated(updated)
                            }
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(4)
                .onSubmit {
                    notesDebounceTask?.cancel()
                    var updated = shot
                    if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
                        updated.takes[idx].notes = editingNotes
                        onShotUpdated(updated)
                    }
                    editingNotesTakeId = nil
                }
            }

            // Tags
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("TAGS")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.gray.opacity(0.4))
                }

                FlowLayout(spacing: 4) {
                    ForEach(take.tags, id: \.self) { tag in
                        HStack(spacing: 3) {
                            Text(tag)
                                .font(.system(size: 9, weight: .medium))
                            Button { removeTag(tag, from: take) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 6, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .foregroundColor(.white)
                        .background(Capsule().fill(Color.accentColor.opacity(0.5)))
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 6, weight: .semibold))
                            .foregroundColor(.gray)
                        TextField("add", text: $newTagText, onCommit: {
                            addTag(newTagText, to: take)
                            newTagText = ""
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 9))
                        .frame(width: 36)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "#3A3A3A")))
                }
            }

            // Camera File
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("CAMERA FILE")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.gray.opacity(0.4))
                }

                Button { mapCameraFile(for: take) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: take.cameraSourceFileName != nil ? "checkmark.circle.fill" : "sdcard")
                            .font(.system(size: 9))
                            .foregroundColor(take.cameraSourceFileName != nil ? .green : .gray)
                        Text(take.cameraSourceFileName ?? "Map file...")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(take.cameraSourceFileName != nil ? .white : .gray)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: "#3A3A3A")))
                }
                .buttonStyle(.plain)
            }

            // File info
            if let videoPath = take.capturedVideoPath, let basePath = projectBasePath {
                let fullURL = basePath.deletingLastPathComponent().appendingPathComponent(videoPath)
                HStack(spacing: 5) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 7))
                        .foregroundColor(.gray.opacity(0.3))
                    Text(fullURL.lastPathComponent)
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.4))
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
    }

    // MARK: - Rating Pill

    func ratingPill(take: Take, rating: TakeRating) -> some View {
        let isSelected = take.rating == rating

        return Button {
            var updated = shot
            if let idx = updated.takes.firstIndex(where: { $0.id == take.id }) {
                updated.takes[idx].rating = isSelected ? .none : rating
                updated.updateStatusFromTakes()
                onShotUpdated(updated)

                // Regenerate collage when circle rating changes
                if rating == .circle {
                    regenerateTakePreview(for: updated)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: rating.icon)
                    .font(.system(size: 9))
                Text(rating.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundColor(isSelected ? .white : ratingColor(rating))
            .background(
                Capsule()
                    .fill(isSelected ? ratingColor(rating) : Color(hex: "#3A3A3A"))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack")
                .font(.system(size: 28))
                .foregroundColor(.gray.opacity(0.2))
            Text("No takes yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.5))
            Text("Connect a video source to record, or use timestamp logging to match footage later")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.3))
                .multilineTextAlignment(.center)

            Button { addManualTake() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 10))
                    Text("Add First Take")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.accentColor))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Full Screen Monitor

    var fullScreenMonitor: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Live preview — fills available space, conditional on LUT
            if captureService.selectedLUT != .none {
                LUTMonitorView(
                    processedFrame: captureService.processedFrame,
                    ciContext: captureService.lutProcessor.ciContext
                )
                .ignoresSafeArea()
            } else if let layer = captureService.previewLayer {
                LiveMonitorView(previewLayer: layer)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.2))
                    Text("No preview available")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }

            // HUD overlay
            VStack {
                HStack(alignment: .top) {
                    // REC badge — top left
                    if captureService.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .shadow(color: .red.opacity(0.6), radius: 6)
                            Text("REC")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                    }

                    Spacer()

                    // LUT selector — top center-right
                    HStack(spacing: 5) {
                        Image(systemName: "camera.filters")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))

                        ForEach(LUTPreset.allCases) { preset in
                            let isActive = captureService.selectedLUT == preset
                            Button { captureService.setLUT(preset) } label: {
                                Text(preset.shortLabel)
                                    .font(.system(size: 9, weight: isActive ? .semibold : .medium))
                                    .foregroundColor(isActive ? .white : .white.opacity(0.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(isActive ? Color.accentColor : Color.white.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.black.opacity(0.7))
                    )

                    // Timecode — top right
                    Text(captureService.formattedDuration)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                }
                .padding(20)

                Spacer()

                // Bottom transport bar
                HStack(spacing: 24) {
                    // Device name
                    HStack(spacing: 6) {
                        Circle()
                            .fill(captureService.isSessionRunning ? Color.green : Color.gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(captureService.selectedDevice?.localizedName ?? "No Device")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.7)))

                    Spacer()

                    // Record / Stop
                    Button {
                        if captureService.isRecording { stopRecording() }
                        else { startRecording() }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 3)
                                .frame(width: 56, height: 56)

                            if captureService.isRecording {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red)
                                    .frame(width: 22, height: 22)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 40, height: 40)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Close button
                    Button {
                        isFullScreen = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Exit")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(20)
            }
        }
    }
}
