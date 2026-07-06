//
// LightingGanttView+Export.swift
//
// Extracted from LightingGanttView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import UniformTypeIdentifiers
import DirectorsChairCore

extension LightingGanttView {

    // MARK: - CSV Export

    func exportCSV() {
        let panel = NSSavePanel()
        panel.title = "Export Cue Sheet"
        panel.nameFieldStringValue = "cue_sheet.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var csv = ""

        // Lighting section
        if !filteredCues.isEmpty {
            csv += "--- LIGHTING CUES ---\n"
            csv += "Cue #,Cue Name,Fixture Type,Workflow,Start Time (s),Duration (s),End Time (s),Start Time (MM:SS),End Time (MM:SS),Intensity (%),End Intensity (%),Color (Hex),Color Temp (K),Gel Filter,Position,Angle,Elevation,Transition In,Fade In (s),Transition Out,Fade Out (s),Motivation,DMX Channel,DMX Universe,Gobo,Scene,Notes\n"

            for cue in filteredCues {
                let endTime = cue.startTime + cue.duration
                let startFormatted = DurationEstimator.formatTime(CGFloat(cue.startTime))
                let endFormatted = DurationEstimator.formatTime(CGFloat(endTime))
                let endIntensity = cue.intensityEnd.map { "\(Int($0 * 100))" } ?? ""
                let colorTemp = cue.colorTemperature.map { "\($0)" } ?? ""
                let gel = csvEscape(cue.gelFilter ?? "")
                let posCustom = cue.position == .custom ? (cue.positionCustom ?? cue.position.rawValue) : cue.position.rawValue
                let angle = cue.angle.map { "\(Int($0))" } ?? ""
                let elevation = cue.elevation.map { "\(Int($0))" } ?? ""
                let dmxCh = cue.dmxChannel.map { "\($0)" } ?? ""
                let dmxUni = cue.dmxUniverse.map { "\($0)" } ?? ""
                let gobo = csvEscape(cue.goboPattern ?? "")
                let scene = csvEscape(cue.sceneName ?? "")
                let notes = csvEscape(cue.notes)

                csv += "\(csvEscape(cue.cueNumber)),\(csvEscape(cue.name)),\(csvEscape(cue.fixtureType.rawValue)),\(cue.workflow.rawValue),\(String(format: "%.1f", cue.startTime)),\(String(format: "%.1f", cue.duration)),\(String(format: "%.1f", endTime)),\(startFormatted),\(endFormatted),\(Int(cue.intensity * 100)),\(endIntensity),\(cue.color),\(colorTemp),\(gel),\(csvEscape(posCustom)),\(angle),\(elevation),\(cue.transitionIn.rawValue),\(String(format: "%.1f", cue.fadeInDuration)),\(cue.transitionOut.rawValue),\(String(format: "%.1f", cue.fadeOutDuration)),\(cue.motivation.rawValue),\(dmxCh),\(dmxUni),\(gobo),\(scene),\(notes)\n"
            }
        }

        // SFX section
        if !filteredSFXCues.isEmpty {
            csv += "\n--- SPECIAL EFFECTS CUES ---\n"
            csv += "Cue #,Cue Name,Effect Type,Start Time (s),Duration (s),End Time (s),Start Time (MM:SS),End Time (MM:SS),Intensity (%),End Intensity (%),Intensity Profile,Color (Hex),Placement,Coverage (%),Transition In,Fade In (s),Transition Out,Fade Out (s),Requires Ventilation,Operator Required,Safety Notes,Notes\n"

            for cue in filteredSFXCues {
                let endTime = cue.startTime + cue.duration
                let startFormatted = DurationEstimator.formatTime(CGFloat(cue.startTime))
                let endFormatted = DurationEstimator.formatTime(CGFloat(endTime))
                let endIntensity = cue.intensityEnd.map { "\(Int($0 * 100))" } ?? ""
                let coverage = Int(cue.coverage * 100)
                let safetyNotes = csvEscape(cue.safetyNotes)
                let notes = csvEscape(cue.notes)

                csv += "\(csvEscape(cue.cueNumber)),\(csvEscape(cue.name)),\(cue.effectType.rawValue),\(String(format: "%.1f", cue.startTime)),\(String(format: "%.1f", cue.duration)),\(String(format: "%.1f", endTime)),\(startFormatted),\(endFormatted),\(Int(cue.intensity * 100)),\(endIntensity),\(cue.intensityProfile.rawValue),\(cue.color),\(cue.placement.rawValue),\(coverage),\(cue.transitionIn.rawValue),\(String(format: "%.1f", cue.fadeInDuration)),\(cue.transitionOut.rawValue),\(String(format: "%.1f", cue.fadeOutDuration)),\(cue.requiresVentilation),\(cue.operatorRequired),\(safetyNotes),\(notes)\n"
            }
        }

        // Support section
        if !filteredSupportCues.isEmpty {
            csv += "\n--- SUPPORT CUES ---\n"
            csv += "Cue #,Cue Name,Action Type,Start Time (s),Duration (s),End Time (s),Start Time (MM:SS),End Time (MM:SS),Priority,Stage Area,Assigned To,Equipment,Safety Notes,Notes\n"

            for cue in filteredSupportCues {
                let endTime = cue.startTime + cue.duration
                let startFormatted = DurationEstimator.formatTime(CGFloat(cue.startTime))
                let endFormatted = DurationEstimator.formatTime(CGFloat(endTime))
                let equipment = csvEscape(cue.equipment)
                let safetyNotes = csvEscape(cue.safetyNotes)
                let notes = csvEscape(cue.notes)

                csv += "\(csvEscape(cue.cueNumber)),\(csvEscape(cue.name)),\(cue.actionType.rawValue),\(String(format: "%.1f", cue.startTime)),\(String(format: "%.1f", cue.duration)),\(String(format: "%.1f", endTime)),\(startFormatted),\(endFormatted),\(cue.priority.rawValue),\(cue.stageArea.rawValue),\(csvEscape(cue.assignedTo)),\(equipment),\(safetyNotes),\(notes)\n"
            }
        }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    // MARK: - HTML Timeline Export

    func exportHTML() {
        let panel = NSSavePanel()
        panel.title = "Export Cue Timeline (HTML)"
        panel.nameFieldStringValue = "cue_timeline.html"
        panel.allowedContentTypes = [UTType.html]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let allCues = filteredCues
        let allSFX = filteredSFXCues
        let allSupport = filteredSupportCues

        let maxTime = max(
            allCues.map { $0.startTime + $0.duration }.max() ?? 0,
            allSFX.map { $0.startTime + $0.duration }.max() ?? 0,
            allSupport.map { $0.startTime + $0.duration }.max() ?? 0
        )
        let dur = max(maxTime + 10, 30)
        let pps: Double = 10
        let tw = Int(dur * pps)
        let lw = 180
        let rh = 40
        let rulerH = 32

        let lightCount = allCues.count
        let sfxCount = allSFX.count
        let supportCount = allSupport.count
        let sections = (lightCount > 0 ? 1 : 0) + (sfxCount > 0 ? 1 : 0) + (supportCount > 0 ? 1 : 0)
        let totalRows = lightCount + sfxCount + supportCount + sections
        let ch = totalRows * rh

        let tickInterval: Double = dur > 300 ? 60 : (dur > 120 ? 30 : (dur > 60 ? 15 : 10))
        let dateStr = Self.currentDateString()

        var html = Self.stickyHTMLHead(tw: tw, lw: lw, rh: rh, rulerH: rulerH, ch: ch, pps: pps, dateStr: dateStr)

        // Time ticks
        var tick: Double = 0
        while tick <= dur {
            let x = Int(tick * pps)
            html += "<span class=\"tick\" style=\"left:\(x)px\">\(Self.fmtMMSS(tick))</span>"
            tick += tickInterval
        }
        html += "</div></div>\n"

        // Labels column
        html += "<div class=\"labels-column\">\n"
        if !allCues.isEmpty {
            html += "<div class=\"section-label light\">Lighting</div>\n"
            for cue in allCues {
                html += "<div class=\"label-row\"><span class=\"cue-num\" style=\"color:\(cue.markerColor)\">\(Self.htmlEsc(cue.cueNumber))</span>\(Self.htmlEsc(cue.name))</div>\n"
            }
        }
        if !allSFX.isEmpty {
            html += "<div class=\"section-label sfx\">Special Effects</div>\n"
            for cue in allSFX {
                html += "<div class=\"label-row\"><span class=\"cue-num\" style=\"color:\(cue.markerColor)\">\(Self.htmlEsc(cue.cueNumber))</span>\(Self.htmlEsc(cue.name))</div>\n"
            }
        }
        if !allSupport.isEmpty {
            html += "<div class=\"section-label support\">Support</div>\n"
            for cue in allSupport {
                html += "<div class=\"label-row\"><span class=\"cue-num\" style=\"color:\(cue.markerColor)\">\(Self.htmlEsc(cue.cueNumber))</span>\(Self.htmlEsc(cue.name))</div>\n"
            }
        }
        html += "</div>\n<div class=\"timeline-content\">\n"

        // Timeline bars
        var rowIdx = 0
        if !allCues.isEmpty {
            html += "<div class=\"section-row\" style=\"top:\(rowIdx * rh)px\"></div>\n"
            rowIdx += 1
            for cue in allCues {
                let y = rowIdx * rh
                let x = Int(cue.startTime * pps)
                let w = max(Int(cue.duration * pps), 24)
                let fiW = Int(cue.fadeInDuration * pps)
                let foW = Int(cue.fadeOutDuration * pps)
                let cls = (fiW > 0 || foW > 0) ? " has-fade" : ""
                let fv = (fiW > 0 || foW > 0) ? "--fade-in-w:\(fiW)px;--fade-out-w:\(foW)px;" : ""
                let end = cue.startTime + cue.duration
                html += "<div class=\"timeline-row\" style=\"top:\(y)px\"><div class=\"cue-bar\(cls)\" style=\"left:\(x)px;width:\(w)px;background:\(cue.markerColor);\(fv)\">\(Self.htmlEsc(cue.cueNumber)) \(Self.htmlEsc(cue.name))<div class=\"tooltip\"><strong>\(Self.htmlEsc(cue.cueNumber)) \u{2014} \(Self.htmlEsc(cue.name))</strong><div class=\"tt-row\">Type: \(cue.fixtureType.rawValue) (\(cue.workflow.rawValue))</div><div class=\"tt-row\">Time: \(Self.fmtMMSS(cue.startTime)) \u{2192} \(Self.fmtMMSS(end)) (\(String(format: "%.1f", cue.duration))s)</div><div class=\"tt-row\">Intensity: \(Int(cue.intensity * 100))%</div><div class=\"tt-row\">Fade: In \(String(format: "%.1f", cue.fadeInDuration))s / Out \(String(format: "%.1f", cue.fadeOutDuration))s</div></div></div></div>\n"
                rowIdx += 1
            }
        }
        if !allSFX.isEmpty {
            html += "<div class=\"section-row\" style=\"top:\(rowIdx * rh)px\"></div>\n"
            rowIdx += 1
            for cue in allSFX {
                let y = rowIdx * rh
                let x = Int(cue.startTime * pps)
                let w = max(Int(cue.duration * pps), 24)
                let fiW = Int(cue.fadeInDuration * pps)
                let foW = Int(cue.fadeOutDuration * pps)
                let cls = (fiW > 0 || foW > 0) ? " has-fade" : ""
                let fv = (fiW > 0 || foW > 0) ? "--fade-in-w:\(fiW)px;--fade-out-w:\(foW)px;" : ""
                let end = cue.startTime + cue.duration
                html += "<div class=\"timeline-row\" style=\"top:\(y)px\"><div class=\"cue-bar\(cls)\" style=\"left:\(x)px;width:\(w)px;background:\(cue.markerColor);\(fv)\">\(Self.htmlEsc(cue.cueNumber)) \(Self.htmlEsc(cue.name))<div class=\"tooltip\"><strong>\(Self.htmlEsc(cue.cueNumber)) \u{2014} \(Self.htmlEsc(cue.name))</strong><div class=\"tt-row\">Effect: \(cue.effectType.rawValue)</div><div class=\"tt-row\">Time: \(Self.fmtMMSS(cue.startTime)) \u{2192} \(Self.fmtMMSS(end)) (\(String(format: "%.1f", cue.duration))s)</div><div class=\"tt-row\">Intensity: \(Int(cue.intensity * 100))% (\(cue.intensityProfile.rawValue))</div><div class=\"tt-row\">Placement: \(cue.placement.rawValue) | Coverage: \(Int(cue.coverage * 100))%</div></div></div></div>\n"
                rowIdx += 1
            }
        }
        if !allSupport.isEmpty {
            html += "<div class=\"section-row\" style=\"top:\(rowIdx * rh)px\"></div>\n"
            rowIdx += 1
            for cue in allSupport {
                let y = rowIdx * rh
                let x = Int(cue.startTime * pps)
                let w = max(Int(cue.duration * pps), 24)
                let end = cue.startTime + cue.duration
                html += "<div class=\"timeline-row\" style=\"top:\(y)px\"><div class=\"cue-bar\" style=\"left:\(x)px;width:\(w)px;background:\(cue.markerColor)\">\(Self.htmlEsc(cue.cueNumber)) \(Self.htmlEsc(cue.name))<div class=\"tooltip\"><strong>\(Self.htmlEsc(cue.cueNumber)) \u{2014} \(Self.htmlEsc(cue.name))</strong><div class=\"tt-row\">Action: \(cue.actionType.rawValue)</div><div class=\"tt-row\">Time: \(Self.fmtMMSS(cue.startTime)) \u{2192} \(Self.fmtMMSS(end)) (\(String(format: "%.1f", cue.duration))s)</div><div class=\"tt-row\">Priority: \(cue.priority.rawValue) | Area: \(cue.stageArea.rawValue)</div><div class=\"tt-row\">Assigned: \(cue.assignedTo.isEmpty ? "Unassigned" : Self.htmlEsc(cue.assignedTo))</div></div></div></div>\n"
                rowIdx += 1
            }
        }

        html += "</div></div></div>\n"
        html += "<div class=\"legend\"><div class=\"legend-item\"><div class=\"legend-swatch\" style=\"background:#fbbf24\"></div>Lighting</div><div class=\"legend-item\"><div class=\"legend-swatch\" style=\"background:#ff6b35\"></div>Special Effects</div><div class=\"legend-item\"><div class=\"legend-swatch\" style=\"background:#2dd4bf\"></div>Support</div></div></body></html>"

        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    static func stickyHTMLHead(tw: Int, lw: Int, rh: Int, rulerH: Int, ch: Int, pps: Double, dateStr: String) -> String {
        """
        <!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Cue Timeline</title>
        <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',system-ui,sans-serif;background:#0f0f1a;color:#e0e0e0}
        .page-header{padding:20px 24px 12px;background:#0f0f1a;border-bottom:1px solid #2a2a3e}
        .page-header h1{font-size:20px;font-weight:600;color:#fff}
        .page-header .subtitle{font-size:11px;color:#666;margin-top:2px}
        .timeline-wrapper{position:relative;overflow:auto;height:calc(100vh - 70px)}
        .timeline-grid{display:grid;grid-template-columns:\(lw)px \(tw)px;grid-template-rows:\(rulerH)px \(ch)px;width:\(lw + tw + 40)px}
        .corner-cell{position:sticky;top:0;left:0;z-index:30;background:#12121f;border-bottom:1px solid #2a2a3e;border-right:1px solid #2a2a3e;display:flex;align-items:center;justify-content:center;font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:1.2px;color:#555}
        .time-ruler{position:sticky;top:0;z-index:20;background:#12121f;border-bottom:1px solid #2a2a3e;height:\(rulerH)px}
        .time-ruler-inner{position:relative;width:100%;height:100%}
        .tick{position:absolute;top:8px;font-size:9px;font-family:'SF Mono','Menlo',monospace;color:#666;padding-left:4px}
        .tick::before{content:'';position:absolute;left:0;bottom:-8px;width:1px;height:12px;background:#3a3a4e}
        .labels-column{position:sticky;left:0;z-index:10;background:#12121f;border-right:1px solid #2a2a3e}
        .label-row{height:\(rh)px;display:flex;align-items:center;padding:0 12px;font-size:11px;font-weight:500;color:#bbb;border-bottom:1px solid rgba(255,255,255,0.03);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
        .label-row .cue-num{font-family:'SF Mono',monospace;font-size:10px;font-weight:600;margin-right:8px;padding:2px 6px;border-radius:3px;background:rgba(255,255,255,0.06);flex-shrink:0}
        .section-label{height:\(rh)px;display:flex;align-items:center;padding:0 12px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:1px;border-bottom:1px solid rgba(255,255,255,0.05)}
        .section-label.light{color:#fbbf24;background:rgba(251,191,36,0.05)}
        .section-label.sfx{color:#ff6b35;background:rgba(255,107,53,0.05)}
        .section-label.support{color:#2dd4bf;background:rgba(45,212,191,0.05)}
        .timeline-content{position:relative;background:repeating-linear-gradient(90deg,transparent,transparent \(Int(pps * 10) - 1)px,rgba(255,255,255,0.015) \(Int(pps * 10) - 1)px,rgba(255,255,255,0.015) \(Int(pps * 10))px)}
        .timeline-row{position:absolute;left:0;right:0;height:\(rh)px;border-bottom:1px solid rgba(255,255,255,0.02)}
        .section-row{position:absolute;left:0;right:0;height:\(rh)px;background:rgba(255,255,255,0.01);border-bottom:1px solid rgba(255,255,255,0.04)}
        .cue-bar{position:absolute;top:6px;height:28px;border-radius:6px;display:flex;align-items:center;padding:0 8px;font-size:10px;font-weight:600;color:#fff;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;cursor:default;transition:transform .12s ease,box-shadow .12s ease;box-shadow:0 2px 6px rgba(0,0,0,0.4)}
        .cue-bar:hover{transform:translateY(-2px) scale(1.02);box-shadow:0 6px 20px rgba(0,0,0,0.5);z-index:5}
        .cue-bar .tooltip{display:none;position:absolute;bottom:calc(100% + 10px);left:50%;transform:translateX(-50%);background:#1a1a2e;border:1px solid #3a3a5e;border-radius:8px;padding:10px 14px;font-size:10px;font-weight:400;line-height:1.6;white-space:nowrap;z-index:100;color:#ccc;box-shadow:0 8px 28px rgba(0,0,0,0.7);pointer-events:none}
        .cue-bar:hover .tooltip{display:block}
        .tooltip strong{color:#fff;font-size:11px;display:block;margin-bottom:4px}
        .tooltip .tt-row{color:#aaa}
        .cue-bar.has-fade::before{content:'';position:absolute;left:0;top:0;bottom:0;width:var(--fade-in-w,0px);background:linear-gradient(90deg,rgba(0,0,0,0.45),transparent);border-radius:6px 0 0 6px;pointer-events:none}
        .cue-bar.has-fade::after{content:'';position:absolute;right:0;top:0;bottom:0;width:var(--fade-out-w,0px);background:linear-gradient(270deg,rgba(0,0,0,0.45),transparent);border-radius:0 6px 6px 0;pointer-events:none}
        .legend{position:sticky;left:0;padding:14px 24px;display:flex;gap:24px;font-size:11px;color:#888;background:#0f0f1a;border-top:1px solid #2a2a3e}
        .legend-item{display:flex;align-items:center;gap:6px}
        .legend-swatch{width:14px;height:14px;border-radius:4px}
        </style></head><body>
        <div class="page-header"><h1>Cue Timeline</h1><div class="subtitle">Exported from DirectorsChair \u{2022} \(dateStr) \u{2022} Hover over bars for details</div></div>
        <div class="timeline-wrapper"><div class="timeline-grid">
        <div class="corner-cell">Cue</div>
        <div class="time-ruler"><div class="time-ruler-inner">
        """
    }

    static func fmtMMSS(_ seconds: Double) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }

    static func htmlEsc(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}
