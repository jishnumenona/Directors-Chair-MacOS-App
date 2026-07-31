//
//  StorytellerTimeline.swift
//  DirectorsChair-Desktop
//
//  Pure math for storyteller MODE of the playback engine (unit-tested,
//  no side effects):
//
//  - StorytellerTimeline.retime(...) rebuilds the playback playlist so each
//    scene's span equals its narration chunk's REAL measured duration, with
//    every shot getting a proportional sub-span (shot order and relative
//    WPM weights preserved). Item metadata — linked ids, media, shot — is
//    copied verbatim so every sidebar card resolves identically in both
//    modes. The playback scrubber/timecode therefore run on uniform
//    narration time: 1 s of audio == 1 s of playhead.
//  - StorytellerTimeline.editTime(forStoryTime:) maps story time back onto
//    the EDIT timeline's WPM time linearly PER SCENE, for the bottom
//    timeline playhead and for cue windows (light/SFX/support, subtitles)
//    whose start times live in WPM time. The edit-timeline lanes are
//    WPM-scaled, so the playhead's rate differs across scenes there BY
//    DESIGN — the playback scrubber and timecode are the uniform clock.
//  - StorytellerMapping keeps the slide-window math: the viewfinder
//    slideshow (scene overview + shot stills) is keyed by the
//    storyteller-timed windows.
//

import Foundation

// MARK: - Storyteller-timed playlist + per-scene time maps

enum StorytellerTimeline {

    /// One narrated scene's span on both clocks: [storyStart, storyEnd] in
    /// uniform narration time, [editStart, editEnd] in WPM edit-timeline
    /// time. A chunk whose audio hasn't been generated yet has a zero-width
    /// story span at its boundary.
    struct SceneMap: Equatable {
        let sceneIndex: Int
        let storyStart: CGFloat
        let storyEnd: CGFloat
        let editStart: CGFloat
        let editEnd: CGFloat
    }

    struct Retimed {
        let items: [PlaybackItem]
        let boundaries: [SceneBoundary]
        let totalDuration: CGFloat
        let sceneMaps: [SceneMap]
    }

    /// Rebuild the playlist on the story clock. Chunks come in scene order;
    /// each scene starts at the cumulative narration time before it and
    /// spans its chunk's measured duration. Scenes without a chunk (nothing
    /// to narrate) are skipped entirely; scenes whose chunk hasn't been
    /// generated yet (duration 0) contribute a zero-width boundary so
    /// playback can wait there, but no items until the audio lands.
    static func retime(normalItems: [PlaybackItem],
                       normalBoundaries: [SceneBoundary],
                       normalTotalDuration: CGFloat,
                       chunkSpans: [(sceneIndex: Int, duration: TimeInterval)]) -> Retimed {
        var items: [PlaybackItem] = []
        var boundaries: [SceneBoundary] = []
        var maps: [SceneMap] = []
        var cursor: CGFloat = 0

        for span in chunkSpans {
            guard span.sceneIndex >= 0, span.sceneIndex < normalBoundaries.count else { continue }
            let editStart = normalBoundaries[span.sceneIndex].time
            let editEnd = span.sceneIndex + 1 < normalBoundaries.count
                ? normalBoundaries[span.sceneIndex + 1].time
                : normalTotalDuration
            let storyStart = cursor
            let storyEnd = cursor + CGFloat(span.duration)
            boundaries.append(SceneBoundary(time: storyStart,
                                            name: normalBoundaries[span.sceneIndex].name))
            maps.append(SceneMap(sceneIndex: span.sceneIndex,
                                 storyStart: storyStart, storyEnd: storyEnd,
                                 editStart: editStart, editEnd: editEnd))

            if span.duration > 0 {
                let sceneItems = normalItems.filter { $0.sceneIndex == span.sceneIndex }
                let editSpan = editEnd - editStart
                let storySpan = storyEnd - storyStart
                for (index, item) in sceneItems.enumerated() {
                    let newStart: CGFloat
                    let newDuration: CGFloat
                    if editSpan > 0 {
                        // Proportional sub-span: same fraction of the scene
                        // as on the WPM timeline (relative weights kept).
                        let startFraction = min(max((item.startTime - editStart) / editSpan, 0), 1)
                        newStart = storyStart + startFraction * storySpan
                        newDuration = min(item.duration / editSpan * storySpan,
                                          storyEnd - newStart)
                    } else {
                        // Degenerate edit span: spread shots evenly.
                        let count = CGFloat(sceneItems.count)
                        newStart = storyStart + storySpan * CGFloat(index) / count
                        newDuration = storySpan / count
                    }
                    items.append(item.retimed(startTime: newStart,
                                              duration: max(newDuration, 0)))
                }
            }
            cursor = storyEnd
        }
        return Retimed(items: items, boundaries: boundaries,
                       totalDuration: cursor, sceneMaps: maps)
    }

    /// The span containing a time instant. Spans are ordered and
    /// non-overlapping; a zero-width span (a scene whose narration isn't
    /// generated yet) claims the instant exactly at its boundary, so
    /// playback waits there instead of skipping ahead. Past the last span
    /// resolves to the last span (park at the end).
    static func spanIndex(at time: CGFloat,
                          spans: [(start: CGFloat, end: CGFloat)]) -> Int? {
        guard !spans.isEmpty else { return nil }
        for (index, span) in spans.enumerated() {
            if time < span.end { return index }
            if span.start == span.end && time <= span.start { return index }
        }
        return spans.count - 1
    }

    /// Story clock → edit-timeline (WPM) clock, linear per scene.
    static func editTime(forStoryTime time: CGFloat, maps: [SceneMap]) -> CGFloat {
        guard let index = spanIndex(at: time,
                                    spans: maps.map { ($0.storyStart, $0.storyEnd) })
        else { return time }
        let map = maps[index]
        return StorytellerMapping.timelineTime(
            narrationTime: Double(time - map.storyStart),
            narrationDuration: Double(map.storyEnd - map.storyStart),
            sceneStart: map.editStart, sceneEnd: map.editEnd)
    }

    /// Edit-timeline (WPM) clock → story clock, the inverse per-scene map.
    /// Edit times inside a scene that has no narration (skipped chunk-less
    /// scenes) snap to the next narrated scene's start.
    static func storyTime(forEditTime time: CGFloat, maps: [SceneMap]) -> CGFloat {
        guard let index = spanIndex(at: time,
                                    spans: maps.map { ($0.editStart, $0.editEnd) })
        else { return time }
        let map = maps[index]
        let editSpan = map.editEnd - map.editStart
        guard editSpan > 0, time > map.editStart else { return map.storyStart }
        let fraction = min(max((time - map.editStart) / editSpan, 0), 1)
        return map.storyStart + fraction * (map.storyEnd - map.storyStart)
    }
}

// MARK: - Slides + pure mapping math (unit-tested)

/// One slideshow image with its window on the storyteller clock (the same
/// proportional sub-spans as the retimed playlist).
struct StorytellerSlide: Equatable {
    let imagePath: String   // relative to the project base path
    var start: CGFloat
    var end: CGFloat
}

enum StorytellerMapping {
    /// Linear map of progress within one span onto another span — the
    /// primitive behind the per-scene story↔edit time mapping.
    static func timelineTime(narrationTime: Double, narrationDuration: Double,
                             sceneStart: CGFloat, sceneEnd: CGFloat) -> CGFloat {
        guard narrationDuration > 0, sceneEnd > sceneStart else { return sceneStart }
        let fraction = min(max(narrationTime / narrationDuration, 0), 1)
        return sceneStart + CGFloat(fraction) * (sceneEnd - sceneStart)
    }

    /// Slideshow sequence for one scene: the overview image leads, then the
    /// shot stills in shot order (shots without images are skipped — their
    /// span is absorbed by the previous slide). The overview gets the
    /// pre-first-shot span when one exists; when the first shot starts at
    /// the scene start, the colliding slide is pushed to the midpoint of
    /// the space up to the next boundary so both get a window.
    static func buildSlides(sceneStart: CGFloat, sceneEnd: CGFloat,
                            overviewImagePath: String?,
                            shots: [(imagePath: String?, startTime: CGFloat)])
    -> [StorytellerSlide] {
        guard sceneEnd > sceneStart else { return [] }

        var entries: [(path: String, start: CGFloat)] = []
        if let overview = overviewImagePath, !overview.isEmpty {
            entries.append((overview, sceneStart))
        }
        let shotEntries = shots
            .filter { !($0.imagePath ?? "").isEmpty }
            .sorted { $0.startTime < $1.startTime }
            .map { (path: $0.imagePath!,
                    start: min(max($0.startTime, sceneStart), sceneEnd)) }
        entries.append(contentsOf: shotEntries)
        guard !entries.isEmpty else { return [] }

        // Stable order: by start, overview-before-shot on ties.
        entries = entries.enumerated()
            .sorted { a, b in
                a.element.start != b.element.start
                    ? a.element.start < b.element.start
                    : a.offset < b.offset
            }
            .map(\.element)

        // Enforce strictly increasing starts so every slide gets a window.
        for i in 1..<entries.count where entries[i].start <= entries[i - 1].start {
            let nextBoundary = entries[(i + 1)...]
                .first(where: { $0.start > entries[i - 1].start })?.start ?? sceneEnd
            entries[i].start = entries[i - 1].start
                + (nextBoundary - entries[i - 1].start) / 2
        }

        var slides: [StorytellerSlide] = []
        for i in entries.indices {
            let end = i + 1 < entries.count ? entries[i + 1].start : sceneEnd
            if end > entries[i].start {
                slides.append(StorytellerSlide(imagePath: entries[i].path,
                                               start: entries[i].start, end: end))
            }
        }
        return slides
    }

    /// The slide showing at an instant (last slide whose start has passed;
    /// nil only when there are no slides).
    static func slideIndex(at timelineTime: CGFloat,
                           in slides: [StorytellerSlide]) -> Int? {
        guard !slides.isEmpty else { return nil }
        var best = 0
        for (i, slide) in slides.enumerated() where slide.start <= timelineTime {
            best = i
        }
        return best
    }
}
