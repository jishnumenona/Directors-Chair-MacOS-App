//
//  ExportCommands.swift
//  DirectorsChair-Desktop
//
//  Phase 8C: Menu Bar & Commands
//  Export menu commands for various formats
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DirectorsChairCore

struct ExportCommands: Commands {
    // Injected app-scoped reference (see ViewCommands note re: @FocusedValue).
    var projectViewModelRef: ProjectViewModel?
    @FocusedValue(\.projectViewModel) var focusedProjectViewModel: ProjectViewModel?
    var projectViewModel: ProjectViewModel? { projectViewModelRef ?? focusedProjectViewModel }

    init(projectViewModelRef: ProjectViewModel? = nil) {
        self.projectViewModelRef = projectViewModelRef
    }

    var body: some Commands {
        CommandMenu("Export") {
            Button("Export as Fountain...") {
                // TODO: Implement Fountain export using DirectorsChairExports
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(projectViewModel?.hasProject != true)

            Button("Export as Final Draft (FDX)...") {
                // TODO: Implement FDX export using DirectorsChairExports
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export as PDF...") {
                // TODO: Implement PDF export using DirectorsChairExports
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(projectViewModel?.hasProject != true)

            Button("Export as HTML...") {
                // TODO: Implement HTML export using DirectorsChairExports
            }
            .disabled(projectViewModel?.hasProject != true)

            Divider()

            Button("Export Character Profiles...") {
                // TODO: Implement character profile export
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export Shot List...") {
                // TODO: Implement shot list export
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export Cue Timeline (HTML)...") {
                if let vm = projectViewModel {
                    exportCueTimeline(project: vm.project)
                }
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export Schedule...") {
                // TODO: Implement schedule export
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export Budget...") {
                // TODO: Implement budget export
            }
            .disabled(projectViewModel?.hasProject != true)

            Divider()

            Button("Export All...") {
                // TODO: Implement batch export
            }
            .keyboardShortcut("e", modifiers: [.command, .option, .shift])
            .disabled(projectViewModel?.hasProject != true)
        }
    }

    // MARK: - Cue Timeline HTML Export

    private func exportCueTimeline(project: Project) {
        let panel = NSSavePanel()
        panel.title = "Export Cue Timeline (HTML)"
        panel.nameFieldStringValue = "cue_timeline.html"
        panel.allowedContentTypes = [UTType.html]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let lc = project.lightCues.filter { $0.isActive }.sorted { $0.startTime < $1.startTime }
        let sc = project.sfxCues.filter { $0.isActive }.sorted { $0.startTime < $1.startTime }
        let sup = project.supportCues.filter { $0.isActive }.sorted { $0.startTime < $1.startTime }
        let html = Self.buildCueHTML(light: lc, sfx: sc, support: sup, name: project.name)
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch { NSAlert(error: error).runModal() }
    }

    private static func buildCueHTML(light: [LightCue], sfx: [SFXCue], support: [SupportCue], name: String) -> String {
        let maxT = max(light.map{$0.startTime+$0.duration}.max() ?? 0, sfx.map{$0.startTime+$0.duration}.max() ?? 0, support.map{$0.startTime+$0.duration}.max() ?? 0)
        let dur = max(maxT+10, 30), pps: Double = 10
        let tw = Int(dur*pps), lw = 180, rh = 40, rulerH = 32
        let sects = (light.isEmpty ? 0:1)+(sfx.isEmpty ? 0:1)+(support.isEmpty ? 0:1)
        let ch = (light.count+sfx.count+support.count+sects)*rh
        let tickI: Double = dur>300 ? 60:(dur>120 ? 30:(dur>60 ? 15:10))
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        let ds = df.string(from: Date())
        let gl = Int(pps*10)

        var h = "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><title>Cue Timeline</title><style>"
        h += "*{margin:0;padding:0;box-sizing:border-box}"
        h += "body{font-family:-apple-system,system-ui,sans-serif;background:#0f0f1a;color:#e0e0e0}"
        h += ".ph{padding:20px 24px 12px;background:#0f0f1a;border-bottom:1px solid #2a2a3e}"
        h += ".ph h1{font-size:20px;font-weight:600;color:#fff}.ph .sub{font-size:11px;color:#666;margin-top:2px}"
        h += ".tw{overflow:auto;height:calc(100vh - 70px)}"
        h += ".tg{display:grid;grid-template-columns:\(lw)px \(tw)px;grid-template-rows:\(rulerH)px \(ch)px;width:\(lw+tw+40)px}"
        h += ".cc{position:sticky;top:0;left:0;z-index:30;background:#12121f;border-bottom:1px solid #2a2a3e;border-right:1px solid #2a2a3e;display:flex;align-items:center;justify-content:center;font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:1.2px;color:#555}"
        h += ".tr{position:sticky;top:0;z-index:20;background:#12121f;border-bottom:1px solid #2a2a3e;height:\(rulerH)px}"
        h += ".tri{position:relative;width:100%;height:100%}"
        h += ".tk{position:absolute;top:8px;font-size:9px;font-family:'SF Mono',monospace;color:#666;padding-left:4px}"
        h += ".tk::before{content:'';position:absolute;left:0;bottom:-8px;width:1px;height:12px;background:#3a3a4e}"
        h += ".lc{position:sticky;left:0;z-index:10;background:#12121f;border-right:1px solid #2a2a3e}"
        h += ".lr{height:\(rh)px;display:flex;align-items:center;padding:0 12px;font-size:11px;font-weight:500;color:#bbb;border-bottom:1px solid rgba(255,255,255,0.03);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}"
        h += ".lr .cn{font-family:'SF Mono',monospace;font-size:10px;font-weight:600;margin-right:8px;padding:2px 6px;border-radius:3px;background:rgba(255,255,255,0.06);flex-shrink:0}"
        h += ".sl{height:\(rh)px;display:flex;align-items:center;padding:0 12px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:1px;border-bottom:1px solid rgba(255,255,255,0.05)}"
        h += ".sl.li{color:#fbbf24;background:rgba(251,191,36,0.05)}.sl.sf{color:#ff6b35;background:rgba(255,107,53,0.05)}.sl.su{color:#2dd4bf;background:rgba(45,212,191,0.05)}"
        h += ".tc{position:relative;background:repeating-linear-gradient(90deg,transparent,transparent \(gl-1)px,rgba(255,255,255,0.015) \(gl-1)px,rgba(255,255,255,0.015) \(gl)px)}"
        h += ".row{position:absolute;left:0;right:0;height:\(rh)px;border-bottom:1px solid rgba(255,255,255,0.02)}"
        h += ".sr{position:absolute;left:0;right:0;height:\(rh)px;background:rgba(255,255,255,0.01);border-bottom:1px solid rgba(255,255,255,0.04)}"
        h += ".cb{position:absolute;top:6px;height:28px;border-radius:6px;display:flex;align-items:center;padding:0 8px;font-size:10px;font-weight:600;color:#fff;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;cursor:default;transition:transform .12s,box-shadow .12s;box-shadow:0 2px 6px rgba(0,0,0,0.4)}"
        h += ".cb:hover{transform:translateY(-2px) scale(1.02);box-shadow:0 6px 20px rgba(0,0,0,0.5);z-index:5}"
        h += ".cb .tt{display:none;position:absolute;bottom:calc(100% + 10px);left:50%;transform:translateX(-50%);background:#1a1a2e;border:1px solid #3a3a5e;border-radius:8px;padding:10px 14px;font-size:10px;line-height:1.6;white-space:nowrap;z-index:100;color:#ccc;box-shadow:0 8px 28px rgba(0,0,0,0.7);pointer-events:none}"
        h += ".cb:hover .tt{display:block}.tt strong{color:#fff;font-size:11px;display:block;margin-bottom:4px}.tt .r{color:#aaa}"
        h += ".cb.fd::before{content:'';position:absolute;left:0;top:0;bottom:0;width:var(--fi,0);background:linear-gradient(90deg,rgba(0,0,0,0.45),transparent);border-radius:6px 0 0 6px;pointer-events:none}"
        h += ".cb.fd::after{content:'';position:absolute;right:0;top:0;bottom:0;width:var(--fo,0);background:linear-gradient(270deg,rgba(0,0,0,0.45),transparent);border-radius:0 6px 6px 0;pointer-events:none}"
        h += ".lg{position:sticky;left:0;padding:14px 24px;display:flex;gap:24px;font-size:11px;color:#888;background:#0f0f1a;border-top:1px solid #2a2a3e}.li2{display:flex;align-items:center;gap:6px}.sw{width:14px;height:14px;border-radius:4px}"
        h += "</style></head><body>"
        h += "<div class=\"ph\"><h1>Cue Timeline — \(esc(name))</h1><div class=\"sub\">Exported from DirectorsChair • \(ds) • Hover over bars for details</div></div>"
        h += "<div class=\"tw\"><div class=\"tg\"><div class=\"cc\">Cue</div><div class=\"tr\"><div class=\"tri\">"

        var t: Double = 0
        while t <= dur { h += "<span class=\"tk\" style=\"left:\(Int(t*pps))px\">\(mm(t))</span>"; t += tickI }
        h += "</div></div><div class=\"lc\">"

        if !light.isEmpty { h += "<div class=\"sl li\">Lighting</div>"; for c in light { h += "<div class=\"lr\"><span class=\"cn\" style=\"color:\(c.markerColor)\">\(esc(c.cueNumber))</span>\(esc(c.name))</div>" } }
        if !sfx.isEmpty { h += "<div class=\"sl sf\">Special Effects</div>"; for c in sfx { h += "<div class=\"lr\"><span class=\"cn\" style=\"color:\(c.markerColor)\">\(esc(c.cueNumber))</span>\(esc(c.name))</div>" } }
        if !support.isEmpty { h += "<div class=\"sl su\">Support</div>"; for c in support { h += "<div class=\"lr\"><span class=\"cn\" style=\"color:\(c.markerColor)\">\(esc(c.cueNumber))</span>\(esc(c.name))</div>" } }
        h += "</div><div class=\"tc\">"

        var ri = 0
        if !light.isEmpty {
            h += "<div class=\"sr\" style=\"top:\(ri*rh)px\"></div>"; ri += 1
            for c in light {
                let y=ri*rh, x=Int(c.startTime*pps), w=max(Int(c.duration*pps),24)
                let fi=Int(c.fadeInDuration*pps), fo=Int(c.fadeOutDuration*pps), fd=fi>0||fo>0
                h += "<div class=\"row\" style=\"top:\(y)px\"><div class=\"cb\(fd ? " fd":"")\" style=\"left:\(x)px;width:\(w)px;background:\(c.markerColor);\(fd ? "--fi:\(fi)px;--fo:\(fo)px;":"")\">\(esc(c.cueNumber)) \(esc(c.name))<div class=\"tt\"><strong>\(esc(c.cueNumber)) — \(esc(c.name))</strong><div class=\"r\">Type: \(c.fixtureType.rawValue) (\(c.workflow.rawValue))</div><div class=\"r\">Time: \(mm(c.startTime))→\(mm(c.startTime+c.duration)) (\(String(format:"%.1f",c.duration))s)</div><div class=\"r\">Intensity: \(Int(c.intensity*100))%</div><div class=\"r\">Fade: In \(String(format:"%.1f",c.fadeInDuration))s / Out \(String(format:"%.1f",c.fadeOutDuration))s</div></div></div></div>"
                ri += 1
            }
        }
        if !sfx.isEmpty {
            h += "<div class=\"sr\" style=\"top:\(ri*rh)px\"></div>"; ri += 1
            for c in sfx {
                let y=ri*rh, x=Int(c.startTime*pps), w=max(Int(c.duration*pps),24)
                let fi=Int(c.fadeInDuration*pps), fo=Int(c.fadeOutDuration*pps), fd=fi>0||fo>0
                h += "<div class=\"row\" style=\"top:\(y)px\"><div class=\"cb\(fd ? " fd":"")\" style=\"left:\(x)px;width:\(w)px;background:\(c.markerColor);\(fd ? "--fi:\(fi)px;--fo:\(fo)px;":"")\">\(esc(c.cueNumber)) \(esc(c.name))<div class=\"tt\"><strong>\(esc(c.cueNumber)) — \(esc(c.name))</strong><div class=\"r\">Effect: \(c.effectType.rawValue)</div><div class=\"r\">Time: \(mm(c.startTime))→\(mm(c.startTime+c.duration)) (\(String(format:"%.1f",c.duration))s)</div><div class=\"r\">Intensity: \(Int(c.intensity*100))% (\(c.intensityProfile.rawValue))</div><div class=\"r\">Placement: \(c.placement.rawValue) | Coverage: \(Int(c.coverage*100))%</div></div></div></div>"
                ri += 1
            }
        }
        if !support.isEmpty {
            h += "<div class=\"sr\" style=\"top:\(ri*rh)px\"></div>"; ri += 1
            for c in support {
                let y=ri*rh, x=Int(c.startTime*pps), w=max(Int(c.duration*pps),24)
                h += "<div class=\"row\" style=\"top:\(y)px\"><div class=\"cb\" style=\"left:\(x)px;width:\(w)px;background:\(c.markerColor)\">\(esc(c.cueNumber)) \(esc(c.name))<div class=\"tt\"><strong>\(esc(c.cueNumber)) — \(esc(c.name))</strong><div class=\"r\">Action: \(c.actionType.rawValue)</div><div class=\"r\">Time: \(mm(c.startTime))→\(mm(c.startTime+c.duration)) (\(String(format:"%.1f",c.duration))s)</div><div class=\"r\">Priority: \(c.priority.rawValue) | Area: \(c.stageArea.rawValue)</div><div class=\"r\">Assigned: \(c.assignedTo.isEmpty ? "Unassigned":esc(c.assignedTo))</div></div></div></div>"
                ri += 1
            }
        }

        h += "</div></div></div><div class=\"lg\"><div class=\"li2\"><div class=\"sw\" style=\"background:#fbbf24\"></div>Lighting</div><div class=\"li2\"><div class=\"sw\" style=\"background:#ff6b35\"></div>Special Effects</div><div class=\"li2\"><div class=\"sw\" style=\"background:#2dd4bf\"></div>Support</div></div></body></html>"
        return h
    }

    private static func mm(_ s: Double) -> String { String(format:"%d:%02d",Int(s)/60,Int(s)%60) }
    private static func esc(_ s: String) -> String { s.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;").replacingOccurrences(of:"\"",with:"&quot;") }
}
