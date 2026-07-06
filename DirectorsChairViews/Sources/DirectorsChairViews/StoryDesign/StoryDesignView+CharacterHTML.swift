//
// StoryDesignView+CharacterHTML.swift
//
// Extracted from StoryDesignView.swift (WS9.1 tier decomposition).
//

import SwiftUI
import DirectorsChairCore
import AppKit
import UniformTypeIdentifiers

extension StoryDesignView {

    func applyInitialSelection() {
        if let locId = initialLocationId,
           let loc = project.locations.first(where: { $0.id == locId }) {
            selectedMode = .locations
            selectedLocation = loc
        } else if let charId = initialCharacterId,
                  let char = project.characters.first(where: { $0.id == charId }) {
            selectedMode = .characters
            selectedCharacter = char
        } else if preferredMode == "lighting" {
            selectedMode = .lighting
        } else if preferredMode == "locations" {
            selectedMode = .locations
            if selectedLocation == nil, let firstLocation = project.locations.first {
                selectedLocation = firstLocation
            }
        } else {
            // Default: select first character
            if selectedCharacter == nil, let firstCharacter = project.characters.first {
                selectedCharacter = firstCharacter
            }
            if selectedLocation == nil, let firstLocation = project.locations.first {
                selectedLocation = firstLocation
            }
        }
    }

    // MARK: - Export Character HTML

    func exportCharacterHTML(_ character: Character) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "\(character.name) — Character Sheet.html"
        panel.title = "Export Character Sheet"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let html = buildCharacterHTML(character)
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            debugLog("Failed to export character HTML: \(error)")
        }
    }

    func imageDataURI(relativePath: String?) -> String? {
        guard let path = relativePath, !path.isEmpty, let basePath = projectBasePath else { return nil }
        let fullPath = basePath.appendingPathComponent(path)
        guard let data = try? Data(contentsOf: fullPath) else { return nil }
        let ext = fullPath.pathExtension.lowercased()
        let mime = ext == "jpg" || ext == "jpeg" ? "image/jpeg" : "image/png"
        return "data:\(mime);base64,\(data.base64EncodedString())"
    }

    func buildCharacterHTML(_ c: Character) -> String {
        let accent = "#4A90D9"
        let accentDim = "#3A7BC8"

        // Resolve base image
        let discovered = DiscoveredCharacterImages.discover(for: c.name, basePath: projectBasePath)
        let baseImgPath = c.baseImage ?? discovered.baseImage
        let baseImgURI = imageDataURI(relativePath: baseImgPath)

        // Angle images
        let angleImages: [(String, String?)] = [
            ("Front", imageDataURI(relativePath: c.imageFront ?? discovered.front)),
            ("3/4 Left", imageDataURI(relativePath: c.imageThreeQuarterLeft ?? discovered.threeQuarterLeft)),
            ("3/4 Right", imageDataURI(relativePath: c.imageThreeQuarterRight ?? discovered.threeQuarterRight)),
            ("Profile Left", imageDataURI(relativePath: c.imageProfileLeft ?? discovered.profileLeft)),
            ("Profile Right", imageDataURI(relativePath: c.imageProfileRight ?? discovered.profileRight)),
            ("Back", imageDataURI(relativePath: c.imageBack ?? discovered.back)),
        ].filter { $0.1 != nil }

        // Helper to build a detail row
        func row(_ label: String, _ value: String?) -> String {
            guard let v = value, !v.isEmpty else { return "" }
            return """
            <div class="detail-row">
                <span class="detail-label">\(label)</span>
                <span class="detail-value">\(v)</span>
            </div>
            """
        }

        func colorSwatch(_ hex: String, _ label: String) -> String {
            guard !hex.isEmpty else { return "" }
            // Check if it looks like a hex color
            let isHex = hex.hasPrefix("#") && hex.count >= 4
            if isHex {
                return """
                <div class="detail-row">
                    <span class="detail-label">\(label)</span>
                    <span class="detail-value"><span class="color-swatch" style="background:\(hex)"></span>\(hex)</span>
                </div>
                """
            } else {
                return row(label, hex)
            }
        }

        // Height/Weight formatting
        let heightStr: String? = {
            guard let h = c.heightCm, h > 0 else { return nil }
            let feet = Int(h / 2.54) / 12
            let inches = Int(h / 2.54) % 12
            return "\(Int(h)) cm (\(feet)'\(inches)\")"
        }()
        let weightStr: String? = {
            guard let w = c.weightKg, w > 0 else { return nil }
            let lbs = Int(w * 2.205)
            return "\(Int(w)) kg (\(lbs) lbs)"
        }()

        // Trait categories (OCEAN model matching PersonalityTraitsTab)
        let traitCategories: [(String, String, [String])] = [
            ("Openness", "#9B59B6", ["Creativity", "Curiosity", "Imagination", "Open-mindedness", "Artistic Interest"]),
            ("Conscientiousness", "#3498DB", ["Organization", "Diligence", "Reliability", "Self-discipline", "Ambition"]),
            ("Extraversion", "#E67E22", ["Sociability", "Energy", "Assertiveness", "Enthusiasm", "Talkativeness"]),
            ("Agreeableness", "#27AE60", ["Empathy", "Cooperation", "Trust", "Kindness", "Politeness"]),
            ("Neuroticism", "#E74C3C", ["Anxiety", "Moodiness", "Sensitivity", "Irritability", "Self-consciousness"]),
        ]

        // Case-insensitive trait lookup (handles both "Creativity" and "creativity" keys)
        func traitScore(_ key: String) -> Double {
            if let v = c.traits[key] { return v }
            // Try lowercase match
            let lower = key.lowercased()
            for (k, v) in c.traits {
                if k.lowercased() == lower { return v }
            }
            return 50.0
        }

        var traitsHTML = ""
        for (category, catColor, traitNames) in traitCategories {
            var catRows = ""
            for trait in traitNames {
                let score = traitScore(trait)
                let barColor: String
                if score >= 70 { barColor = "#4CAF50" }
                else if score >= 40 { barColor = catColor }
                else { barColor = "#E57373" }

                catRows += """
                <div class="trait-row">
                    <span class="trait-name">\(trait)</span>
                    <div class="trait-bar-bg">
                        <div class="trait-bar" style="width:\(Int(score))%;background:\(barColor)"></div>
                    </div>
                    <span class="trait-score">\(Int(score))</span>
                </div>
                """
            }
            traitsHTML += """
            <div class="trait-category">
                <div class="trait-category-title">\(category.uppercased())</div>
                \(catRows)
            </div>
            """
        }

        // Costumes
        var costumesHTML = ""
        if let costumes = c.costumes, !costumes.isEmpty {
            for costume in costumes {
                let costumeImgURI = imageDataURI(relativePath: costume.imageFront)
                let costumeImgTag = costumeImgURI.map { "<img src=\"\($0)\" class=\"costume-img\">" } ?? ""

                var details = ""
                if let gt = costume.garmentTop, !gt.isEmpty { details += row("Top", gt) }
                if let gb = costume.garmentBottom, !gb.isEmpty { details += row("Bottom", gb) }
                if let fw = costume.footwear, !fw.isEmpty { details += row("Footwear", fw) }
                if let ow = costume.outerwear, !ow.isEmpty { details += row("Outerwear", ow) }
                if let hw = costume.headwear, !hw.isEmpty { details += row("Headwear", hw) }
                if let acc = costume.accessories, !acc.isEmpty { details += row("Accessories", acc.joined(separator: ", ")) }
                if let era = costume.era, !era.isEmpty { details += row("Era", era) }
                if let sc = costume.styleCategory, !sc.isEmpty { details += row("Style", sc) }

                let palette = (costume.colorPalette ?? []).map {
                    "<span class=\"palette-dot\" style=\"background:\($0)\"></span>"
                }.joined()
                let paletteRow = palette.isEmpty ? "" : "<div class=\"palette-row\">\(palette)</div>"

                costumesHTML += """
                <div class="costume-card">
                    \(costumeImgTag)
                    <div class="costume-info">
                        <div class="costume-name">\(costume.name)</div>
                        <div class="costume-desc">\(costume.description)</div>
                        \(details)
                        \(paletteRow)
                    </div>
                </div>
                """
            }
        }

        // Biography
        func bioBlock(_ title: String, _ value: String?) -> String {
            guard let v = value, !v.isEmpty else { return "" }
            let escaped = v.replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return """
            <div class="bio-block">
                <div class="bio-block-title">\(title)</div>
                <div class="bio-text">\(escaped)</div>
            </div>
            """
        }

        var biographyHTML = ""
        biographyHTML += bioBlock("Full Name", c.fullName)
        biographyHTML += bioBlock("Nickname", c.nickname)
        biographyHTML += bioBlock("Occupation", c.occupation)
        biographyHTML += bioBlock("Affiliation", c.affiliation)
        biographyHTML += bioBlock("Background", c.backgroundStory)
        biographyHTML += bioBlock("Primary Goal", c.primaryGoal)
        biographyHTML += bioBlock("Secondary Goal", c.secondaryGoal)
        biographyHTML += bioBlock("Hidden Motivation", c.hiddenMotivation)
        biographyHTML += bioBlock("Primary Fear", c.primaryFear)
        biographyHTML += bioBlock("Weakness", c.weakness)
        biographyHTML += bioBlock("Character Flaw", c.flaw)
        biographyHTML += bioBlock("Character Arc", c.characterArcNotes)

        // Relationships
        var relationshipsHTML = ""
        if let rels = c.relationships, !rels.isEmpty {
            for (name, desc) in rels.sorted(by: { $0.key < $1.key }) {
                relationshipsHTML += """
                <div class="relationship-row">
                    <span class="rel-name">\(name)</span>
                    <span class="rel-desc">\(desc)</span>
                </div>
                """
            }
        }

        // Base image section
        let baseImageHTML: String
        if let uri = baseImgURI {
            baseImageHTML = "<img src=\"\(uri)\" class=\"hero-img\">"
        } else {
            baseImageHTML = """
            <div class="hero-placeholder">
                <svg width="80" height="80" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.3)" stroke-width="1.5">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                    <circle cx="12" cy="7" r="4"/>
                </svg>
            </div>
            """
        }

        // Angle gallery
        var angleGalleryHTML = ""
        if !angleImages.isEmpty {
            var thumbs = ""
            for (label, uri) in angleImages {
                if let u = uri {
                    thumbs += """
                    <div class="angle-thumb">
                        <img src="\(u)">
                        <span>\(label)</span>
                    </div>
                    """
                }
            }
            angleGalleryHTML = """
            <div class="section">
                <div class="section-title">CHARACTER ANGLES</div>
                <div class="angle-grid">\(thumbs)</div>
            </div>
            """
        }

        let dateStr: String = {
            let f = DateFormatter()
            f.dateStyle = .long
            return f.string(from: Date())
        }()

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(c.name) — Character Sheet</title>
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

            :root {
                --bg: #0f0f17;
                --surface: #1a1a2e;
                --surface-2: #222240;
                --border: rgba(255,255,255,0.08);
                --border-accent: rgba(74,144,217,0.3);
                --text: #e8e8f0;
                --text-dim: #8888a8;
                --text-muted: #5a5a78;
                --accent: \(accent);
                --accent-dim: \(accentDim);
                --card-radius: 12px;
            }

            * { margin:0; padding:0; box-sizing:border-box; }

            body {
                font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
                background: var(--bg);
                color: var(--text);
                line-height: 1.6;
                -webkit-font-smoothing: antialiased;
            }

            .container {
                max-width: 900px;
                margin: 0 auto;
                padding: 40px 24px 80px;
            }

            /* Header */
            .header {
                text-align: center;
                margin-bottom: 40px;
            }
            .header .badge {
                display: inline-block;
                font-size: 10px;
                font-weight: 600;
                letter-spacing: 2px;
                text-transform: uppercase;
                color: var(--accent);
                border: 1px solid var(--border-accent);
                padding: 4px 14px;
                border-radius: 20px;
                margin-bottom: 16px;
            }
            .header h1 {
                font-size: 36px;
                font-weight: 700;
                letter-spacing: -0.5px;
                margin-bottom: 4px;
            }
            .header .role {
                font-size: 15px;
                color: var(--text-dim);
                font-weight: 400;
            }
            .header .meta {
                font-size: 11px;
                color: var(--text-muted);
                margin-top: 12px;
            }

            /* Hero image */
            .hero-wrapper {
                display: flex;
                justify-content: center;
                margin-bottom: 32px;
            }
            .hero-img {
                max-width: 400px;
                width: 100%;
                height: auto;
                object-fit: contain;
                border-radius: 16px;
                border: 2px solid var(--border);
                box-shadow: 0 8px 32px rgba(0,0,0,0.4);
            }
            .hero-placeholder {
                width: 280px;
                height: 280px;
                border-radius: 16px;
                border: 2px dashed var(--border);
                display: flex;
                align-items: center;
                justify-content: center;
                background: var(--surface);
            }

            /* Sections */
            .section {
                margin-bottom: 28px;
            }
            .section-title {
                font-size: 10px;
                font-weight: 600;
                letter-spacing: 1.5px;
                text-transform: uppercase;
                color: var(--accent);
                margin-bottom: 12px;
                padding-bottom: 8px;
                border-bottom: 1px solid var(--border);
            }

            /* Cards */
            .card {
                background: var(--surface);
                border: 1px solid var(--border);
                border-radius: var(--card-radius);
                padding: 20px;
                margin-bottom: 16px;
            }

            /* Two column grid */
            .two-col {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 16px;
            }
            @media (max-width: 640px) {
                .two-col { grid-template-columns: 1fr; }
            }

            /* Detail rows */
            .detail-row {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 6px 0;
                border-bottom: 1px solid var(--border);
            }
            .detail-row:last-child { border-bottom: none; }
            .detail-label {
                font-size: 12px;
                color: var(--text-dim);
                font-weight: 500;
            }
            .detail-value {
                font-size: 13px;
                font-weight: 500;
                color: var(--text);
                display: flex;
                align-items: center;
                gap: 6px;
            }
            .color-swatch {
                display: inline-block;
                width: 14px;
                height: 14px;
                border-radius: 50%;
                border: 1.5px solid rgba(255,255,255,0.2);
                vertical-align: middle;
            }

            /* Traits */
            .traits-grid {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 16px;
            }
            @media (max-width: 640px) {
                .traits-grid { grid-template-columns: 1fr; }
            }
            .trait-category {
                background: var(--surface);
                border: 1px solid var(--border);
                border-radius: var(--card-radius);
                padding: 16px;
            }
            .trait-category-title {
                font-size: 10px;
                font-weight: 600;
                letter-spacing: 1.2px;
                color: var(--accent);
                margin-bottom: 10px;
            }
            .trait-row {
                display: flex;
                align-items: center;
                gap: 8px;
                margin-bottom: 6px;
            }
            .trait-row:last-child { margin-bottom: 0; }
            .trait-name {
                font-size: 11px;
                color: var(--text-dim);
                width: 90px;
                flex-shrink: 0;
            }
            .trait-bar-bg {
                flex: 1;
                height: 6px;
                background: rgba(255,255,255,0.06);
                border-radius: 3px;
                overflow: hidden;
            }
            .trait-bar {
                height: 100%;
                border-radius: 3px;
                transition: width 0.3s ease;
            }
            .trait-score {
                font-size: 11px;
                font-weight: 600;
                color: var(--text-dim);
                width: 28px;
                text-align: right;
            }

            /* Biography */
            .bio-text {
                font-size: 13px;
                color: var(--text-dim);
                line-height: 1.7;
                white-space: pre-wrap;
            }
            .bio-block {
                margin-bottom: 12px;
            }
            .bio-block-title {
                font-size: 11px;
                font-weight: 600;
                color: var(--text);
                margin-bottom: 4px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
            }

            /* Costumes */
            .costume-card {
                display: flex;
                gap: 16px;
                background: var(--surface);
                border: 1px solid var(--border);
                border-radius: var(--card-radius);
                padding: 16px;
                margin-bottom: 12px;
            }
            .costume-img {
                width: 120px;
                height: 120px;
                object-fit: cover;
                border-radius: 8px;
                flex-shrink: 0;
                border: 1px solid var(--border);
            }
            .costume-info { flex: 1; }
            .costume-name {
                font-size: 14px;
                font-weight: 600;
                margin-bottom: 4px;
            }
            .costume-desc {
                font-size: 12px;
                color: var(--text-dim);
                margin-bottom: 8px;
            }
            .palette-row {
                display: flex;
                gap: 6px;
                margin-top: 8px;
            }
            .palette-dot {
                width: 20px;
                height: 20px;
                border-radius: 50%;
                border: 1.5px solid rgba(255,255,255,0.15);
            }

            /* Relationships */
            .relationship-row {
                display: flex;
                gap: 12px;
                padding: 8px 0;
                border-bottom: 1px solid var(--border);
            }
            .relationship-row:last-child { border-bottom: none; }
            .rel-name {
                font-size: 13px;
                font-weight: 600;
                color: var(--accent);
                min-width: 120px;
            }
            .rel-desc {
                font-size: 13px;
                color: var(--text-dim);
            }

            /* Angle gallery */
            .angle-grid {
                display: flex;
                gap: 12px;
                flex-wrap: wrap;
            }
            .angle-thumb {
                text-align: center;
            }
            .angle-thumb img {
                width: 100px;
                height: 100px;
                object-fit: cover;
                border-radius: 8px;
                border: 1px solid var(--border);
            }
            .angle-thumb span {
                display: block;
                font-size: 10px;
                color: var(--text-muted);
                margin-top: 4px;
            }

            /* Footer */
            .footer {
                text-align: center;
                padding-top: 32px;
                border-top: 1px solid var(--border);
                margin-top: 40px;
            }
            .footer span {
                font-size: 11px;
                color: var(--text-muted);
                letter-spacing: 0.5px;
            }

            @media print {
                body { background: #fff; color: #222; }
                .card, .trait-category, .costume-card { border-color: #ddd; background: #f9f9f9; }
                .section-title, .trait-category-title, .badge, .accent { color: \(accent) !important; }
                .detail-label, .trait-name, .trait-score, .bio-text, .costume-desc, .rel-desc { color: #555; }
            }
        </style>
        </head>
        <body>
        <div class="container">

            <div class="header">
                <div class="badge">Character Sheet</div>
                <h1>\(c.name)</h1>
                <div class="role">\(c.role)\(c.occupation.map { " — \($0)" } ?? "")</div>
                <div class="meta">Exported \(dateStr) &middot; Director's Chair</div>
            </div>

            <div class="hero-wrapper">
                \(baseImageHTML)
            </div>

            \(angleGalleryHTML)

            <div class="section">
                <div class="section-title">PHYSICAL APPEARANCE</div>
                <div class="two-col">
                    <div class="card">
                        \(row("Gender", c.gender.capitalized))
                        \(row("Age", c.age > 0 ? "\\(c.age)" : nil))
                        \(row("Build", c.build.isEmpty ? nil : c.build))
                        \(row("Height", heightStr))
                        \(row("Weight", weightStr))
                        \(row("Ethnicity", c.ethnicity.isEmpty ? nil : c.ethnicity))
                        \(row("Facial Structure", c.facialStructure.isEmpty ? nil : c.facialStructure))
                    </div>
                    <div class="card">
                        \(colorSwatch(c.hairColor, "Hair Color"))
                        \(row("Hair Style", c.hairStyle.isEmpty ? nil : c.hairStyle))
                        \(row("Hair Length", c.hairLength.isEmpty ? nil : c.hairLength))
                        \(colorSwatch(c.eyeColor, "Eye Color"))
                        \(row("Eye Description", c.eyeColorDescription.isEmpty ? nil : c.eyeColorDescription))
                        \(row("Eye Shape", c.eyeShape.isEmpty ? nil : c.eyeShape))
                        \(colorSwatch(c.skinTone, "Skin Tone"))
                    </div>
                </div>
                \(!c.distinguishingFeatures.isEmpty ? """
                <div class="card" style="margin-top:0">
                    \(row("Distinguishing Features", c.distinguishingFeatures))
                </div>
                """ : "")
            </div>

            \(!c.traits.isEmpty ? """
            <div class="section">
                <div class="section-title">PERSONALITY TRAITS</div>
                <div class="traits-grid">
                    \(traitsHTML)
                </div>
            </div>
            """ : "")

            \(!biographyHTML.isEmpty ? """
            <div class="section">
                <div class="section-title">BIOGRAPHY</div>
                <div class="card">
                    \(biographyHTML)
                </div>
            </div>
            """ : "")

            \(!costumesHTML.isEmpty ? """
            <div class="section">
                <div class="section-title">COSTUMES</div>
                \(costumesHTML)
            </div>
            """ : "")

            \(!relationshipsHTML.isEmpty ? """
            <div class="section">
                <div class="section-title">RELATIONSHIPS</div>
                <div class="card">
                    \(relationshipsHTML)
                </div>
            </div>
            """ : "")

            <div class="footer">
                <span>CONFIDENTIAL &middot; \(c.name) Character Sheet &middot; Director's Chair</span>
            </div>

        </div>
        </body>
        </html>
        """
    }

    func hasBiography(_ c: Character) -> Bool {
        return [c.fullName, c.nickname, c.occupation, c.affiliation,
                c.backgroundStory, c.primaryGoal, c.secondaryGoal,
                c.hiddenMotivation, c.primaryFear, c.weakness, c.flaw,
                c.characterArcNotes].contains(where: { $0 != nil && !($0?.isEmpty ?? true) })
    }
}
