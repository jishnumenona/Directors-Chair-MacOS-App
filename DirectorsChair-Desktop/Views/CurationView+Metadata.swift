//
// CurationView+Metadata.swift
//
// Extracted from CurationView.swift (WS9.1 god-file decomposition).
// Members moved verbatim into an extension; private -> internal.
//

import SwiftUI
import AVKit
import DirectorsChairCore
import DirectorsChairViews

extension CurationView {

    // MARK: - Rating Card

    func ratingCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("RATING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
            }

            // Large rating buttons — vertical stack
            VStack(spacing: 6) {
                ratingButton(take: take, shot: shot, rating: .circle, color: .green, description: "Best / Print take")
                ratingButton(take: take, shot: shot, rating: .alt, color: .orange, description: "Backup alternative")
                ratingButton(take: take, shot: shot, rating: .ng, color: .red, description: "No good")
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
    }

    func ratingButton(take: Take, shot: Shot, rating: TakeRating, color: Color, description: String) -> some View {
        let isSelected = take.rating == rating

        return Button {
            updateTake(take, in: shot) { $0.rating = isSelected ? .none : rating }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: rating.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(rating.rawValue)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(description)
                        .font(.system(size: 8))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .gray.opacity(0.5))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color : Color(hex: "#3A3A3A"))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Metadata Card

    func metadataCard(take: Take) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("METADATA")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
            }

            // Duration — hero number
            VStack(alignment: .leading, spacing: 2) {
                Text("Duration")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                Text(viewModel.formatDuration(take.durationSeconds))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            Divider().opacity(0.3)

            // Record Start — camera-compatible timestamp for matching with camera file metadata
            VStack(alignment: .leading, spacing: 3) {
                Text("REC START — CAMERA MATCH TIMESTAMP")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(.gray.opacity(0.5))

                HStack(spacing: 8) {
                    Text(take.formattedStartTimestamp ?? "—")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()

                    if take.formattedStartTimestamp != nil {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(take.formattedStartTimestamp!, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 9))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Record End
            VStack(alignment: .leading, spacing: 3) {
                Text("REC END")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(.gray.opacity(0.5))

                Text(take.formattedEndTimestamp ?? "—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
    }

    func metadataRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.gray.opacity(0.5))
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .monospacedDigit()
        }
    }

    // MARK: - Notes Card

    func notesCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
            }

            TextField("Director's notes, performance comments...", text: Binding(
                get: { take.notes },
                set: { newValue in updateTake(take, in: shot) { $0.notes = newValue } }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(10)
            .background(Color(hex: "#1E1E1E"))
            .cornerRadius(6)
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    // MARK: - Camera Footage Metadata Card

    func cameraFootageMetadataCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("CAMERA FOOTAGE METADATA")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                if viewModel.isExtractingMetadata {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else {
                    Button {
                        guard let dir = projectDir else { return }
                        Task {
                            if let metadata = await viewModel.extractCameraMetadata(for: take, projectDir: dir),
                               metadata.hasData {
                                updateTake(take, in: shot) { t in
                                    metadata.apply(to: &t)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.viewfinder").font(.system(size: 9))
                            Text("Extract from Video").font(.system(size: 9, weight: .medium))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(take.capturedVideoPath == nil)
                    .opacity(take.capturedVideoPath == nil ? 0.4 : 1)
                }
            }

            if take.hasCameraMetadata {
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 8) {
                    cameraMetadataCell(icon: "doc.text", label: "Clip Name", value: take.cameraClipName, highlight: true)
                    cameraMetadataCell(icon: "rectangle.split.2x2", label: "Resolution", value: take.cameraResolution)
                    cameraMetadataCell(icon: "speedometer", label: "Frame Rate", value: take.cameraFrameRate)
                    cameraMetadataCell(icon: "sun.max", label: "ISO", value: take.cameraISO)
                    cameraMetadataCell(icon: "camera.aperture", label: "Aperture", value: take.cameraAperture)
                    cameraMetadataCell(icon: "thermometer.medium", label: "White Balance", value: take.cameraWhiteBalance)
                    cameraMetadataCell(icon: "clock", label: "Timecode", value: take.cameraTimecode)
                    cameraMetadataCell(icon: "slider.horizontal.3", label: "LUT / Gamma", value: take.cameraLUT)
                    cameraMetadataCell(icon: "scope", label: "Focus Mode", value: take.cameraFocusMode)
                }
            } else {
                VStack(spacing: 6) {
                    Text("No camera metadata extracted")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("Click \"Extract from Video\" to read viewfinder overlay via OCR")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    @ViewBuilder
    func cameraMetadataCell(icon: String, label: String, value: String?, highlight: Bool = false) -> some View {
        if let value {
            let isCopied = copiedMetadataLabel == label

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                copiedMetadataLabel = label
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedMetadataLabel == label { copiedMetadataLabel = nil }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : icon)
                        .font(.system(size: 10))
                        .foregroundColor(isCopied ? .green : (highlight ? .accentColor : .gray.opacity(0.5)))
                        .frame(width: 14)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(label.uppercased())
                            .font(.system(size: 7, weight: .semibold))
                            .tracking(0.8)
                            .foregroundColor(.gray.opacity(0.5))
                        Text(value)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(highlight ? .accentColor : .white)
                    }

                    Spacer()
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#1E1E1E")))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                hoveredMetadataLabel = hovering ? label : nil
                if hovering { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
            .overlay(alignment: .top) {
                if hoveredMetadataLabel == label || isCopied {
                    Text(isCopied ? "Copied!" : "Click to copy")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isCopied ? .green : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(hex: "#333333"))
                                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        )
                        .offset(y: -28)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: isCopied)
                }
            }
        }
    }

    // MARK: - Camera Source Card

    func cameraSourceCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sdcard.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("CAMERA SOURCE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                // Auto-match by timestamp
                if !viewModel.cameraFiles.isEmpty {
                    Button {
                        let results = viewModel.autoMatchByTimestamp(project: project)
                        if !results.isEmpty {
                            viewModel.applyAutoMatchResults(results, project: &project)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.2.circlepath").font(.system(size: 9))
                            Text("Auto-Match").font(.system(size: 9, weight: .medium))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    // Match by clip name — only when OCR data exists
                    let hasAnyClipName = project.sequences.flatMap { $0.scenes }.flatMap { $0.shots }.flatMap { $0.takes }.contains { $0.cameraClipName != nil }
                    if hasAnyClipName {
                        Button {
                            let results = viewModel.autoMatchByClipName(project: project)
                            if !results.isEmpty {
                                viewModel.applyAutoMatchResults(results, project: &project)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "text.magnifyingglass").font(.system(size: 9))
                                Text("Clip Name").font(.system(size: 9, weight: .medium))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Color(hex: "#3A3A3A")))
                            .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button { viewModel.selectCameraSourceDirectory() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus").font(.system(size: 9))
                        Text("Browse").font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: "#3A3A3A")))
                    .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            // Current mapping
            HStack(spacing: 8) {
                Image(systemName: take.cameraSourceFileName != nil ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 12))
                    .foregroundColor(take.cameraSourceFileName != nil ? .green : .gray.opacity(0.3))

                if let name = take.cameraSourceFileName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    Text("No camera file mapped")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.4))
                }

                Spacer()
            }

            // Camera files grid
            if !viewModel.cameraFiles.isEmpty {
                Divider().opacity(0.2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.cameraFiles) { file in
                            let isMapped = file.mappedToTakeId == take.id

                            Button {
                                mapCameraFileToCurrentTake(file, take: take, shot: shot)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: isMapped ? "film.fill" : "film")
                                        .font(.system(size: 14))
                                        .foregroundColor(isMapped ? .green : .gray.opacity(0.5))

                                    Text(file.fileName)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)

                                    Text(viewModel.formatFileSize(file.fileSize))
                                        .font(.system(size: 7))
                                        .foregroundColor(.gray.opacity(0.4))

                                    // Camera file creation date in same format as take timestamp
                                    if let created = file.creationDate {
                                        Text(Take.formatForCameraMatch(created))
                                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                                            .foregroundColor(.accentColor.opacity(0.7))
                                            .lineLimit(1)
                                            .monospacedDigit()
                                    }
                                }
                                .frame(width: 90)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isMapped ? Color.green.opacity(0.1) : Color(hex: "#2A2A2A"))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isMapped ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 80)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    // MARK: - External Audio Card

    func externalAudioCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("EXTERNAL AUDIO")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)

                Spacer()

                // "Audio from Video" toggle
                Button {
                    updateTake(take, in: shot) {
                        $0.useAudioFromVideo.toggle()
                        if $0.useAudioFromVideo { $0.externalAudioFileName = nil }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: take.useAudioFromVideo ? "checkmark.circle.fill" : "video.fill")
                            .font(.system(size: 9))
                        Text("Audio from Video")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(take.useAudioFromVideo ? Color.purple.opacity(0.2) : Color(hex: "#3A3A3A")))
                    .foregroundColor(take.useAudioFromVideo ? .purple : .gray)
                    .overlay(Capsule().stroke(take.useAudioFromVideo ? Color.purple.opacity(0.4) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Use audio track from the video file instead of external audio")

                if !take.useAudioFromVideo {
                    Button { viewModel.selectAudioDirectory() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus").font(.system(size: 9))
                            Text("Browse").font(.system(size: 9, weight: .medium))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: "#3A3A3A")))
                        .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Current mapping
            if take.useAudioFromVideo {
                HStack(spacing: 8) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text("Audio sourced from video file")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.purple.opacity(0.8))
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: take.externalAudioFileName != nil ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.system(size: 12))
                        .foregroundColor(take.externalAudioFileName != nil ? .green : .gray.opacity(0.3))

                    if let name = take.externalAudioFileName, !name.isEmpty {
                        Text(name)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)

                        Spacer()

                        Button {
                            viewModel.clearAudioMapping(for: take, inShot: shot, project: &project)
                            if let updatedTake = findTake(take.id, inShot: shot) {
                                viewModel.selectedTake = updatedTake
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("No external audio mapped")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.4))

                        Spacer()
                    }
                }
            }

            // Audio files grid
            if !take.useAudioFromVideo && !viewModel.audioFiles.isEmpty {
                Divider().opacity(0.2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.audioFiles) { file in
                            let isMapped = take.externalAudioFileName == file.fileName

                            Button {
                                viewModel.mapAudioFile(file, toTake: take, inShot: shot, project: &project)
                                if let updatedTake = findTake(take.id, inShot: shot) {
                                    viewModel.selectedTake = updatedTake
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: isMapped ? "waveform.circle.fill" : "waveform")
                                        .font(.system(size: 14))
                                        .foregroundColor(isMapped ? .green : .gray.opacity(0.5))

                                    Text(file.fileName)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)

                                    Text(viewModel.formatFileSize(file.fileSize))
                                        .font(.system(size: 7))
                                        .foregroundColor(.gray.opacity(0.4))

                                    if let created = file.creationDate {
                                        Text(Take.formatForCameraMatch(created))
                                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                                            .foregroundColor(.accentColor.opacity(0.7))
                                            .lineLimit(1)
                                            .monospacedDigit()
                                    }
                                }
                                .frame(width: 90)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isMapped ? Color.green.opacity(0.1) : Color(hex: "#2A2A2A"))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isMapped ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 80)
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    /// Helper to find a take in the project after mutation
    func findTake(_ takeId: String, inShot shot: Shot) -> Take? {
        for seq in project.sequences {
            for scene in seq.scenes {
                for s in scene.shots where s.id == shot.id {
                    return s.takes.first { $0.id == takeId }
                }
            }
        }
        return nil
    }

    // MARK: - Tags Card

    func tagsCard(take: Take, shot: Shot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("TAGS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.gray)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(take.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                            Button {
                                updateTake(take, in: shot) { $0.tags.removeAll { $0 == tag } }
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundColor(.white)
                        .background(Capsule().fill(Color.accentColor.opacity(0.6)))
                    }

                    // Add tag inline
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 8)).foregroundColor(.gray)
                        TextField("add tag", text: Binding(
                            get: { "" },
                            set: { newValue in
                                if newValue.last == "\n" || newValue.last == " " {
                                    let tag = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !tag.isEmpty {
                                        updateTake(take, in: shot) {
                                            if !$0.tags.contains(tag) { $0.tags.append(tag) }
                                        }
                                    }
                                }
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 9))
                        .frame(width: 50)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color(hex: "#3A3A3A")))
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#252525"))
        .cornerRadius(10)
    }

    // MARK: - Compare Panel

    enum CompareSide { case left, right }
}
