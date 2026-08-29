//
//  EditorialInterchange.swift
//  DirectorsChairExports
//
//  Editorial handoff (P1, backlog §2.17): the three documents other
//  departments actually consume.
//
//  · CMX 3600 EDL — the lingua franca every NLE imports: the planned
//    shot order as a cut skeleton with estimated durations.
//  · FCPXML — the same skeleton for Final Cut Pro, as a spine of named,
//    noted title slugs on a timeline editorial can build into.
//  · Stripboard CSV — the AD department's view: one strip per scene in
//    shooting-relevant terms (set, INT/EXT, day/night, characters,
//    shot count, estimated running time).
//
//  Everything here is a pure function of the project — no I/O, no
//  state — so every format detail is unit-testable to the character.
//

import Foundation
import DirectorsChairCore

public enum EditorialInterchange {

    // MARK: - Shared timing

    /// One planned cut: a shot with its resolved duration in seconds.
    public struct CutEvent: Equatable, Sendable {
        public let sceneName: String
        public let shot: Shot
        public let seconds: Double
    }

    /// A shot's best-known duration: its own estimate first, then the
    /// video's, then the circled take's measured length, then any
    /// take's, then a 4-second slug — a skeleton cut needs SOME length,
    /// and editorial will retime everything anyway.
    public static func resolvedSeconds(for shot: Shot) -> Double {
        if let duration = shot.duration, duration > 0 { return duration }
        if let duration = shot.videoDuration, duration > 0 { return duration }
        let takes = shot.circledTakes + shot.takes
        for take in takes {
            if let start = take.startTimestamp, let end = take.endTimestamp {
                let measured = end.timeIntervalSince(start)
                if measured > 0.5 { return measured }
            }
        }
        return 4
    }

    /// The cut order: sequences, then scenes, then shots — the order the
    /// project tells its story in.
    public static func cutEvents(in project: Project) -> [CutEvent] {
        project.sequences.flatMap { sequence in
            sequence.scenes.flatMap { scene in
                scene.shots.map { shot in
                    CutEvent(sceneName: scene.name, shot: shot,
                             seconds: resolvedSeconds(for: shot))
                }
            }
        }
    }

    // MARK: - Timecode (pure, exact)

    /// Non-drop-frame timecode at an integer frame rate.
    public static func timecode(seconds: Double, fps: Int) -> String {
        let totalFrames = Int((seconds * Double(fps)).rounded())
        let frames = totalFrames % fps
        let totalSeconds = totalFrames / fps
        return String(format: "%02d:%02d:%02d:%02d",
                      totalSeconds / 3600, (totalSeconds / 60) % 60,
                      totalSeconds % 60, frames)
    }

    // MARK: - CMX 3600 EDL

    /// The skeleton cut as an EDL. Record times run sequentially from
    /// 01:00:00:00 (the industry's habitual first hour); source times
    /// run zero-based per event; reels carry the shot id (AX-style,
    /// 8-char field). Clip names ride the standard FROM CLIP NAME
    /// comment, which is what NLEs actually display.
    public static func edl(project: Project, fps: Int = 24) -> String {
        var lines: [String] = []
        lines.append("TITLE: \(project.name.uppercased())")
        lines.append("FCM: NON-DROP FRAME")
        lines.append("")

        var recordSeconds = 3600.0
        for (index, event) in cutEvents(in: project).enumerated() {
            let number = String(format: "%03d", index + 1)
            let reel = "SH\(event.shot.shotId)"
                .padding(toLength: 8, withPad: " ", startingAt: 0)
            let sourceIn = timecode(seconds: 0, fps: fps)
            let sourceOut = timecode(seconds: event.seconds, fps: fps)
            let recordIn = timecode(seconds: recordSeconds, fps: fps)
            let recordOut = timecode(seconds: recordSeconds + event.seconds,
                                     fps: fps)
            lines.append("\(number)  \(reel) V     C        "
                         + "\(sourceIn) \(sourceOut) \(recordIn) \(recordOut)")
            lines.append("* FROM CLIP NAME: \(clipName(for: event))")
            if !event.shot.description.isEmpty {
                lines.append("* COMMENT: \(event.shot.description.uppercased())")
            }
            if !event.shot.notes.isEmpty {
                lines.append("* COMMENT: \(event.shot.notes.uppercased())")
            }
            recordSeconds += event.seconds
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// The description and, when present, the user's notes (DC-0074).
    static func noteText(for shot: Shot) -> String {
        [shot.description, shot.notes].filter { !$0.isEmpty }.joined(separator: " — ")
    }

    static func clipName(for event: CutEvent) -> String {
        "\(event.sceneName) - SHOT \(event.shot.shotId) "
            + "(\(event.shot.shotType))"
    }

    // MARK: - FCPXML

    /// A Final Cut Pro timeline of named title slugs — one per planned
    /// shot, duration attached, description in the note field. Uses the
    /// stock Basic Title effect (present in every FCP install), frame
    /// durations expressed on FCP's rational clock.
    public static func fcpxml(project: Project, fps: Int = 24) -> String {
        let timebase = fps * 100
        func frames(_ seconds: Double) -> Int {
            Int((seconds * Double(fps)).rounded()) * 100
        }

        var offset = 0
        var clips: [String] = []
        for event in cutEvents(in: project) {
            let duration = max(frames(event.seconds), 100)
            clips.append("""
                        <title ref="r2" name="\(xml(clipName(for: event)))" \
            offset="\(offset)/\(timebase)s" duration="\(duration)/\(timebase)s">
                            <text>
                                <text-style ref="ts1">\(xml(clipName(for: event)))</text-style>
                            </text>
                            <note>\(xml(noteText(for: event.shot)))</note>
                        </title>
            """)
            offset += duration
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.10">
            <resources>
                <format id="r1" name="FFVideoFormat1080p\(fps)" \
        frameDuration="100/\(timebase)s" width="1920" height="1080"/>
                <effect id="r2" name="Basic Title" \
        uid=".../Titles.localized/Bumper:Opener.localized/Basic Title.localized/Basic Title.moti"/>
            </resources>
            <library>
                <event name="\(xml(project.name))">
                    <project name="\(xml(project.name)) — Planned Cut">
                        <sequence format="r1" duration="\(offset)/\(timebase)s" \
        tcStart="3600/1s" tcFormat="NDF">
                            <spine>
        \(clips.joined(separator: "\n"))
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """
    }

    static func xml(_ raw: String) -> String {
        raw.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Stripboard CSV

    /// One strip per scene, in story order, in the terms an AD schedules
    /// by. RFC-4180 quoting throughout — synopses contain commas.
    public static func stripboardCSV(project: Project) -> String {
        var rows: [[String]] = [[
            "Strip", "Sequence", "Scene", "Set / Location", "INT/EXT",
            "Time of Day", "Characters", "Shots", "Est. Minutes", "Synopsis",
        ]]
        var strip = 1
        for sequence in project.sequences {
            for scene in sequence.scenes {
                let heading = parseHeading(scene.location)
                let characters = Set(scene.dialogues.map(\.character))
                    .sorted().joined(separator: ", ")
                let seconds = scene.shots
                    .map(resolvedSeconds(for:)).reduce(0, +)
                rows.append([
                    String(strip),
                    sequence.name,
                    scene.name,
                    heading.set,
                    heading.intExt,
                    heading.time,
                    characters,
                    String(scene.shots.count),
                    String(format: "%.1f", seconds / 60),
                    scene.description,
                ])
                strip += 1
            }
        }
        return rows.map { row in
            row.map(csvField).joined(separator: ",")
        }.joined(separator: "\r\n") + "\r\n"
    }

    /// "INT. KITCHEN - DAY" → (INT, KITCHEN, DAY). Tolerant of the
    /// slug's real-world variants; unknowns come back empty, never
    /// invented.
    static func parseHeading(_ location: String?)
        -> (intExt: String, set: String, time: String) {
        guard var text = location?.trimmingCharacters(in: .whitespaces),
              !text.isEmpty else { return ("", "", "") }
        text = text.uppercased()
        var intExt = ""
        for prefix in ["INT./EXT.", "INT/EXT.", "INT/EXT", "I/E.",
                       "INT.", "EXT.", "INT ", "EXT "] {
            if text.hasPrefix(prefix) {
                // Combined slugs are checked first in the prefix list,
                // and classified first here — "INT./EXT." begins with
                // "INT." and must not be swallowed by it.
                intExt = prefix.contains("/") ? "INT/EXT"
                    : prefix.hasPrefix("INT") ? "INT" : "EXT"
                text = String(text.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
                break
            }
        }
        var time = ""
        if let dashRange = text.range(of: " - ", options: .backwards) {
            time = String(text[dashRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            text = String(text[..<dashRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        }
        return (intExt, text, time)
    }

    static func csvField(_ raw: String) -> String {
        if raw.contains(",") || raw.contains("\"") || raw.contains("\n") {
            return "\"" + raw.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return raw
    }
}
