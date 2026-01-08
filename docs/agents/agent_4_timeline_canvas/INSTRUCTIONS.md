# Agent 4: Timeline & Canvas Rendering - Instructions

## Role & Responsibility

You are the **Timeline & Canvas Specialist**. Your role is to implement the most complex UI component: the Timeline View with custom Canvas rendering, viewport culling, and 60fps performance.

## Your Mission

Implement the **Timeline View** (Module 3) with SwiftUI Canvas API, achieving 60fps smooth scrolling with 100+ dialogue bubbles visible.

---

## Phase 3: Timeline Canvas (Weeks 4-7) - PRIMARY FOCUS

### THE TIMELINE IS CRITICAL

The Timeline View is THE MOST IMPORTANT UI component. Users spend 40% of their time here. It MUST be performant (60fps), visually accurate (match Python), and feature-complete.

### Python Reference Analysis Required

**YOU MUST** deep-study this file before writing any code:
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/timeline_view.py` (2,701 lines)

Key sections:
- Lines 1-200: Data structures (Segment, Marker)
- Lines 200-500: Layout constants and calculations
- Lines 500-1000: Canvas rendering (QPainter)
- Lines 1000-1500: Viewport culling algorithm
- Lines 1500-2000: User interactions (click, drag, zoom)
- Lines 2000-2701: Markers, time ruler, character lanes

### Tasks

1. **Timeline Segment Data Structure**

   ```swift
   struct TimelineSegment: Identifiable {
       let id = UUID()
       var start: CGFloat  // Time in seconds
       var duration: CGFloat
       var character: String
       var text: String  // Dialogue text
       var scene: Scene
       var dialogue: Dialogue
       var avatarPath: String?
       var color: String
       var textColor: String
   }
   ```

2. **Timeline Canvas Rendering**

   **CRITICAL**: Use SwiftUI `Canvas` API for GPU-accelerated rendering.

   ```swift
   struct TimelineCanvas: View {
       let segments: [TimelineSegment]
       let markers: [TimelineMarker]
       let pxPerSec: CGFloat
       @Binding var selectedSegment: TimelineSegment?
       let viewportSize: CGSize
       
       var body: some View {
           Canvas { context, size in
               drawTimeRuler(context, size)
               drawCharacterLanes(context, size)
               drawMarkers(context, size)
               drawSegments(context, size)  // Only visible segments!
           }
       }
   }
   ```

3. **Viewport Culling** (MANDATORY for 60fps)

   ```swift
   private func updateVisibleSegments(viewportBounds: CGRect) {
       let visibleStart = viewportBounds.minX / pxPerSec - 10  // 10s buffer
       let visibleEnd = viewportBounds.maxX / pxPerSec + 10
       
       visibleSegments = segments.filter { segment in
           let segmentEnd = segment.start + segment.duration
           return segmentEnd >= visibleStart && segment.start <= visibleEnd
       }
   }
   ```

4. **Speech Bubble Drawing**

   Custom bubble shapes with tails (speech bubble pointer).

5. **Character Lanes**

   Horizontal lanes per character, alternating background colors.

6. **Time Ruler**

   Top ruler with tick marks every second, labels every 10 seconds.

7. **Markers**

   Vertical lines for scene/sequence/user markers.

8. **Zoom & Scroll**

   - Zoom: 10-100 pixels per second
   - Horizontal scroll: Smooth panning
   - Vertical scroll: Character lanes

9. **Interactions**

   - Click bubble → Select and emit event
   - Double-click bubble → Open dialogue editor
   - Right-click → Context menu

---

## Performance Requirements

**YOU MUST ACHIEVE**:
- ✅ 60fps smooth scrolling with 100+ bubbles
- ✅ Viewport culling working (render only visible)
- ✅ No frame drops during zoom
- ✅ Instant response to click (<16ms)

**If you don't achieve 60fps, Agent 5 will reject your implementation.**

---

## Python File Reference

**CRITICAL FILE**:
- `/Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair/directorschair/ui/timeline_view.py` (2,701 lines)

You must read and understand EVERY line of this file.

---

## Status Tracking

Update `docs/agents/agent_4_timeline_canvas/status.md` **DAILY**.

---

**You are building the most technically challenging component. Performance is non-negotiable. 60fps or bust!** 🎬
