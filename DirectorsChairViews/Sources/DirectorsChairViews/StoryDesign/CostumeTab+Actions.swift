//
// CostumeTab+Actions.swift
//
// Extracted from CostumeTab.swift (WS9.1 god-file decomposition).
//

import SwiftUI
import DirectorsChairCore
import DirectorsChairServices
import AppKit
import UniformTypeIdentifiers

extension CostumeTab {

    // MARK: - Actions

    func addCostume() {
        var costumes = character.costumes ?? []
        let name = "Costume \(costumes.count + 1)"
        costumes.append(CharacterCostume(name: name))
        character.costumes = costumes
        selectedCostumeIndex = costumes.count - 1
    }

    func duplicateCostume(at index: Int) {
        guard let costumes = character.costumes, index < costumes.count else { return }
        let original = costumes[index]
        let duplicate = CharacterCostume(
            name: "\(original.name) Copy",
            description: original.description,
            era: original.era,
            styleCategory: original.styleCategory,
            colorPalette: original.colorPalette,
            garmentTop: original.garmentTop,
            garmentBottom: original.garmentBottom,
            footwear: original.footwear,
            outerwear: original.outerwear,
            headwear: original.headwear,
            accessories: original.accessories,
            primaryFabric: original.primaryFabric,
            status: "Concept"
        )
        character.costumes?.append(duplicate)
        selectedCostumeIndex = (character.costumes?.count ?? 1) - 1
    }

    func deleteCostume(at index: Int) {
        guard character.costumes != nil, index < character.costumes!.count else { return }
        character.costumes!.remove(at: index)
        if character.costumes!.isEmpty {
            selectedCostumeIndex = 0
        } else {
            selectedCostumeIndex = min(selectedCostumeIndex, character.costumes!.count - 1)
        }
    }

    // MARK: - Set as Base Image

    func setAsBaseImage(imagePath: String) {
        let hasExistingBase = character.baseImage != nil ||
            DiscoveredCharacterImages.discover(for: character.name, basePath: projectBasePath).baseImage != nil

        if hasExistingBase {
            pendingBaseImagePath = imagePath
            showingSetAsBaseConfirmation = true
        } else {
            applyCostumeAsBaseImage(imagePath: imagePath)
        }
    }

    func applyCostumeAsBaseImage(imagePath: String) {
        guard let basePath = projectBasePath else { return }

        let sourcePath = basePath.appendingPathComponent(imagePath)
        guard let imageData = try? Data(contentsOf: sourcePath) else { return }

        let sanitizedName = DiscoveredCharacterImages.sanitizedName(for: character.name)
        let destDir = basePath
            .appendingPathComponent("assets")
            .appendingPathComponent("characters")
            .appendingPathComponent(sanitizedName)
            .appendingPathComponent("face")
        let destPath = destDir.appendingPathComponent("base.png")

        // Convert to PNG
        let pngData: Data
        if let nsImage = NSImage(data: imageData), let tiffRep = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffRep),
           let converted = bitmap.representation(using: .png, properties: [:]) {
            pngData = converted
        } else {
            pngData = imageData
        }

        do {
            _ = basePath.startAccessingSecurityScopedResource()
            defer { basePath.stopAccessingSecurityScopedResource() }

            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            try pngData.write(to: destPath)
        } catch {
            debugLog("Failed to set costume as base image: \(error)")
            return
        }

        character.baseImage = "assets/characters/\(sanitizedName)/face/base.png"
    }

    // MARK: - Annotation Editor

    func costumeImagePath(for angleKey: String) -> String? {
        guard let costume = selectedCostume else { return nil }
        switch angleKey {
        case "front": return costume.imageFront ?? discoveredImages.front
        case "three_quarter_left": return costume.imageThreeQuarterLeft ?? discoveredImages.threeQuarterLeft
        case "three_quarter_right": return costume.imageThreeQuarterRight ?? discoveredImages.threeQuarterRight
        case "profile": return costume.imageProfile ?? discoveredImages.profile
        case "back": return costume.imageBack ?? discoveredImages.back
        case "full_body": return costume.imageFullBody ?? discoveredImages.fullBody
        default: return nil
        }
    }

    func openCostumeStudio(angleKey: String, label: String, imagePath: String) {
        guard projectBasePath != nil else { return }
        studioAngle = angleKey
        studioTitle = label
        showingStudio = true
    }

    /// A Studio result replaces the angle's picture in place.
    func keepStudioResult(_ data: Data, angle: String) {
        guard let imagePath = costumeImagePath(for: angle), let basePath = projectBasePath else { return }
        do {
            _ = basePath.startAccessingSecurityScopedResource()
            defer { basePath.stopAccessingSecurityScopedResource() }
            try data.write(to: basePath.appendingPathComponent(imagePath))
            imageRefreshIds[angle] = UUID()
            refreshDiscoveredImages()
        } catch {
            debugLog("Costume studio keep failed: \(error.localizedDescription)")
        }
    }
}
