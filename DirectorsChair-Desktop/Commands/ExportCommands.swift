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
import DirectorsChairExports
import DirectorsChairViews

struct ExportCommands: Commands {
    @ObservedObject private var shortcuts = ShortcutStore.shared
    // Injected app-scoped reference (see ViewCommands note re: @FocusedValue).
    var projectViewModelRef: ProjectViewModel?
    @FocusedValue(\.projectViewModel) var focusedProjectViewModel: ProjectViewModel?
    var projectViewModel: ProjectViewModel? { projectViewModelRef ?? focusedProjectViewModel }

    init(projectViewModelRef: ProjectViewModel? = nil) {
        self.projectViewModelRef = projectViewModelRef
    }

    var body: some Commands {
        CommandMenu("Export") {
            // §2.18: these were dead TODOs from the day the menu was
            // built — the generators sat finished in the Exports package
            // (97 tests) and were never wired. Each save panel picks the
            // destination; the WORK runs on the background queue.
            Button("Export as Fountain...") {
                if let vm = projectViewModel { enqueueScreenplay(.fountain, vm.project) }
            }
            .keyboardShortcut(shortcuts.spec(for: "export.fountain").keyboardShortcutOrDefault)
            .disabled(projectViewModel?.hasProject != true)

            Button("Export as Final Draft (FDX)...") {
                if let vm = projectViewModel { enqueueScreenplay(.fdx, vm.project) }
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export as PDF...") {
                if let vm = projectViewModel { enqueueScreenplay(.pdf, vm.project) }
            }
            .keyboardShortcut(shortcuts.spec(for: "export.pdf").keyboardShortcutOrDefault)
            .disabled(projectViewModel?.hasProject != true)

            Button("Export as HTML...") {
                if let vm = projectViewModel { enqueueScreenplay(.html, vm.project) }
            }
            .disabled(projectViewModel?.hasProject != true)

            Divider()

            Button("Export Character Profiles...") {
                if let vm = projectViewModel { enqueueCharacterProfiles(vm.project) }
            }
            .disabled(projectViewModel?.hasProject != true ||
                      projectViewModel?.project.characters.isEmpty != false)

            // Editorial handoff (§2.17): what other departments' tools eat.
            Button("Export Shot List EDL...") {
                if let vm = projectViewModel {
                    exportInterchange(
                        title: "Export Shot List EDL",
                        fileName: "\(vm.project.name) - planned cut.edl",
                        contentTypes: [],
                        content: EditorialInterchange.edl(project: vm.project))
                }
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export Final Cut Pro XML...") {
                if let vm = projectViewModel {
                    exportInterchange(
                        title: "Export Final Cut Pro XML",
                        fileName: "\(vm.project.name) - planned cut.fcpxml",
                        contentTypes: [UTType.xml],
                        content: EditorialInterchange.fcpxml(
                            project: vm.project))
                }
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export Stripboard CSV...") {
                if let vm = projectViewModel {
                    exportInterchange(
                        title: "Export Stripboard CSV",
                        fileName: "\(vm.project.name) - stripboard.csv",
                        contentTypes: [UTType.commaSeparatedText],
                        content: EditorialInterchange.stripboardCSV(
                            project: vm.project))
                }
            }
            .disabled(projectViewModel?.hasProject != true)

            Button("Export Cue Timeline (HTML)...") {
                if let vm = projectViewModel {
                    exportCueTimeline(project: vm.project)
                }
            }
            .disabled(projectViewModel?.hasProject != true)

            // Schedule/Budget exporters don't exist yet (tracked in the
            // tier matrix); a menu item that can never work is worse
            // than none, so those rows are gone until they're real.

            Divider()

            Button("Export All...") {
                if let vm = projectViewModel { enqueueExportAll(vm.project) }
            }
            .keyboardShortcut(shortcuts.spec(for: "export.batch").keyboardShortcutOrDefault)
            .disabled(projectViewModel?.hasProject != true)
        }
    }

    // MARK: - Cue Timeline HTML Export

    /// One save panel for every plain-text interchange document. EDL has
    /// no UTType — the extension in the suggested name carries it. The
    /// write itself rides the background queue like every other export.
    private func exportInterchange(title: String, fileName: String,
                                   contentTypes: [UTType], content: String) {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = fileName
        if !contentTypes.isEmpty { panel.allowedContentTypes = contentTypes }
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ExportQueue.shared.enqueue(title: title, destination: url) {
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Screenplay exports through the queue (§2.18)

    private func enqueueScreenplay(_ format: ScreenplayExportFormat,
                                   _ project: Project) {
        let panel = NSSavePanel()
        panel.title = format.panelTitle
        panel.nameFieldStringValue = "\(project.name).\(format.fileExtension)"
        if let type = format.contentType {
            panel.allowedContentTypes = [type]
        }
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if format.rendersOnMain {
            ExportQueue.shared.enqueueOnMain(title: format.panelTitle,
                                             destination: url) {
                try ScreenplayExportFormat.writePDF(project, to: url)
            }
        } else {
            ExportQueue.shared.enqueue(title: format.panelTitle,
                                       destination: url) {
                try format.writeText(project, to: url)
            }
        }
    }

    private func enqueueCharacterProfiles(_ project: Project) {
        let panel = NSOpenPanel()
        panel.title = "Export Character Profiles"
        panel.message = "Choose a folder for one PDF per character."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        ExportQueue.shared.enqueueOnMain(
            title: "Character Profiles (\(project.characters.count) PDFs)",
            destination: folder) {
            try ScreenplayExportFormat.writeCharacterSheets(project,
                                                            into: folder)
        }
    }

    /// One folder, every format — the batch handoff. Each format is its
    /// own queue job so one failure never takes the rest down.
    private func enqueueExportAll(_ project: Project) {
        let panel = NSOpenPanel()
        panel.title = "Export All"
        panel.message = "Choose a folder for the full export set."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        for format in ScreenplayExportFormat.allCases {
            let url = folder.appendingPathComponent(
                "\(project.name).\(format.fileExtension)")
            if format.rendersOnMain {
                ExportQueue.shared.enqueueOnMain(title: format.panelTitle,
                                                 destination: url) {
                    try ScreenplayExportFormat.writePDF(project, to: url)
                }
            } else {
                ExportQueue.shared.enqueue(title: format.panelTitle,
                                           destination: url) {
                    try format.writeText(project, to: url)
                }
            }
        }
        let edl = folder.appendingPathComponent("\(project.name) - planned cut.edl")
        ExportQueue.shared.enqueue(title: "Export Shot List EDL",
                                   destination: edl) {
            try EditorialInterchange.edl(project: project)
                .write(to: edl, atomically: true, encoding: .utf8)
        }
        let fcp = folder.appendingPathComponent("\(project.name) - planned cut.fcpxml")
        ExportQueue.shared.enqueue(title: "Export Final Cut Pro XML",
                                   destination: fcp) {
            try EditorialInterchange.fcpxml(project: project)
                .write(to: fcp, atomically: true, encoding: .utf8)
        }
        let csv = folder.appendingPathComponent("\(project.name) - stripboard.csv")
        ExportQueue.shared.enqueue(title: "Export Stripboard CSV",
                                   destination: csv) {
            try EditorialInterchange.stripboardCSV(project: project)
                .write(to: csv, atomically: true, encoding: .utf8)
        }
    }

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

// MARK: - Screenplay export formats (§2.18)

/// The format table the menu, the batch export, and the tests share: how
/// each format names itself, and how it writes a Project to disk. Every
/// generator is a pure function from the Exports package, so a job can
/// run it on any thread against the captured value snapshot.
enum ScreenplayExportFormat: String, CaseIterable, Sendable {
    case fountain
    case fdx
    case pdf
    case html

    var panelTitle: String {
        switch self {
        case .fountain: return "Export as Fountain"
        case .fdx: return "Export as Final Draft"
        case .pdf: return "Export as PDF"
        case .html: return "Export as HTML"
        }
    }

    var fileExtension: String {
        switch self {
        case .fountain: return "fountain"
        case .fdx: return "fdx"
        case .pdf: return "pdf"
        case .html: return "html"
        }
    }

    var contentType: UTType? {
        switch self {
        case .fountain: return nil            // no registered UTType
        case .fdx: return UTType.xml
        case .pdf: return UTType.pdf
        case .html: return UTType.html
        }
    }

    /// True for formats whose generator must render on the main actor
    /// (the PDF pipeline draws through NSGraphicsContext.current).
    var rendersOnMain: Bool { self == .pdf }

    /// The three text formats — pure string generators, safe on any
    /// thread. PDF goes through `writePDF`.
    func writeText(_ project: Project, to url: URL) throws {
        switch self {
        case .fountain:
            try FountainExportService.exportProject(project)
                .write(to: url, atomically: true, encoding: .utf8)
        case .fdx:
            try FDXExportService.exportProject(project)
                .write(to: url, atomically: true, encoding: .utf8)
        case .html:
            try HTMLExportService.exportScreenplay(project)
                .write(to: url, atomically: true, encoding: .utf8)
        case .pdf:
            throw ExportJobError("PDF renders on the main actor — writePDF.")
        }
    }

    @MainActor
    static func writePDF(_ project: Project, to url: URL) throws {
        guard let document = PDFExportService.exportScreenplay(project),
              PDFExportService.saveToFile(document, url: url) else {
            throw ExportJobError("Could not render the screenplay PDF.")
        }
    }

    /// One PDF per character into `folder`; the file carries the
    /// character's name (sanitized — a name is user text, not a path).
    @MainActor
    static func writeCharacterSheets(_ project: Project,
                                     into folder: URL) throws {
        for character in project.characters {
            guard let sheet = PDFExportService.exportCharacterSheet(
                character, project: project) else {
                throw ExportJobError(
                    "Could not render a sheet for \(character.name).")
            }
            let safeName = character.name
                .components(separatedBy: CharacterSet(charactersIn: "/:"))
                .joined(separator: "-")
            let url = folder.appendingPathComponent("\(safeName).pdf")
            guard PDFExportService.saveToFile(sheet, url: url) else {
                throw ExportJobError("Could not write \(safeName).pdf.")
            }
        }
    }
}

struct ExportJobError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
