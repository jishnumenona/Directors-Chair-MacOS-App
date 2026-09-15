// DirectorsChairProduction/Sources/DirectorsChairProduction/Budget/BudgetView+Vendors.swift
//
// DC-0133 — the Vendors tab of Accounting: a directory of suppliers, each with
// a picture and contact details. A vendor can be typed in by hand, given a
// picture from a file, or autodetected from a pasted Google/Maps result link
// (the app target's onLookupVendor does the AI call + downloads the photo).

import SwiftUI
import AppKit
import DirectorsChairCore

// MARK: - Vendors directory

extension BudgetView {

    var vendorsView: some View {
        Group {
            if viewModel.vendors.isEmpty {
                vendorsEmptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                        ForEach(viewModel.vendors) { vendor in
                            VendorCard(vendor: vendor, basePath: viewModel.projectBasePath) {
                                selectedVendor = vendor
                                showingEditVendorSheet = true
                            } onDelete: {
                                viewModel.removeVendor(vendor)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var vendorsEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "building.2")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No vendors yet")
                .font(.system(size: 15, weight: .semibold))
            Text("Add suppliers with a picture and contact details. Paste a Google result\nlink to autodetect a vendor's name, category, address and photo.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            ProductionActionButton(icon: "plus", "Add Vendor", prominent: true) {
                selectedVendor = nil
                showingAddVendorSheet = true
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Vendor card

struct VendorCard: View {
    let vendor: Vendor
    let basePath: URL?
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 0) {
                VendorThumbnail(imagePath: vendor.imagePath, basePath: basePath, height: 130)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(vendor.name.isEmpty ? "Untitled vendor" : vendor.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        if let rating = vendor.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating)).font(.system(size: 10)).foregroundColor(.secondary)
                            }
                        }
                    }
                    if !vendor.category.isEmpty {
                        Text(vendor.category)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    if !vendor.locationLine.isEmpty {
                        Label(vendor.locationLine, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if !vendor.phone.isEmpty {
                        Label(vendor.phone, systemImage: "phone")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(10)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor).opacity(isHovered ? 0.6 : 0.3), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .help("Delete vendor")
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Vendor thumbnail (loads a project-relative picture)

struct VendorThumbnail: View {
    let imagePath: String?
    let basePath: URL?
    var height: CGFloat = 130

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(nsColor: .quaternarySystemFill))
                    .overlay(
                        Image(systemName: "building.2")
                            .font(.system(size: 26))
                            .foregroundColor(.secondary.opacity(0.6))
                    )
            }
        }
        .frame(height: height)
        .task(id: imagePath) { load() }
    }

    private func load() {
        image = VendorImageIO.load(imagePath: imagePath, basePath: basePath)
    }
}

// MARK: - Vendor editor sheet

struct VendorEditorSheet: View {
    @ObservedObject var viewModel: BudgetViewModel
    let vendor: Vendor?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var address = ""
    @State private var city = ""
    @State private var region = ""
    @State private var country = ""
    @State private var notes = ""
    @State private var rating: Double?
    @State private var imagePath: String?
    @State private var sourceUrl: String?
    @State private var pictureImage: NSImage?

    @State private var linkText = ""
    @State private var isLooking = false
    @State private var lookupError: String?
    @State private var lookupSuccess: String?

    var body: some View {
        VStack(spacing: 0) {
            ProductionEditorHeader(
                title: vendor == nil ? "Add Vendor" : "Edit Vendor",
                canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                dismiss()
            } onSave: {
                save()
                dismiss()
            }

            Divider()

            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    leftColumn.frame(width: 240)
                    rightColumn
                }
                .padding(16)
            }
        }
        .frame(width: 680, height: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: loadExisting)
    }

    // MARK: Left — picture + autodetect

    private var leftColumn: some View {
        VStack(spacing: 16) {
            ProductionCard(icon: "photo", title: "PICTURE") {
                VStack(spacing: 10) {
                    if let shownImage = pictureImage {
                        Image(nsImage: shownImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 150)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                            )
                        HStack(spacing: 6) {
                            Button { addPicture() } label: {
                                Label("Replace", systemImage: "photo").font(.system(size: 10))
                            }
                            .buttonStyle(.bordered).controlSize(.mini)
                            Button {
                                imagePath = nil
                                pictureImage = nil
                            } label: {
                                Label("Remove", systemImage: "xmark").font(.system(size: 10))
                            }
                            .buttonStyle(.bordered).controlSize(.mini)
                        }
                    } else {
                        Button { addPicture() } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                                Text("Add Picture")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .background(Color(nsColor: .quaternarySystemFill))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ProductionCard(icon: "sparkle.magnifyingglass", title: "AUTODETECT") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste a Google result or Maps link (or a business name) and fill this in automatically.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    StyledTextField("Google result link", text: $linkText)
                    Button {
                        autodetect()
                    } label: {
                        HStack(spacing: 4) {
                            if isLooking {
                                ProgressView().controlSize(.mini).scaleEffect(0.7)
                            }
                            Label("Autodetect", systemImage: "sparkles").font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isLooking || linkText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.onLookupVendor == nil)

                    if viewModel.onLookupVendor == nil {
                        Text("AI lookup unavailable — check Settings.")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    if let lookupError {
                        Text(lookupError).font(.system(size: 10)).foregroundColor(.red).lineLimit(3)
                    }
                    if let lookupSuccess {
                        Text(lookupSuccess).font(.system(size: 10)).foregroundColor(.green).lineLimit(2)
                    }
                }
            }
        }
    }

    // MARK: Right — details

    private var rightColumn: some View {
        VStack(spacing: 16) {
            ProductionCard(icon: "building.2", title: "VENDOR DETAILS") {
                VStack(spacing: 12) {
                    StyledTextField("Name", text: $name)
                    StyledTextField("Category (e.g. Catering, Location, Equipment rental)", text: $category)
                    HStack(spacing: 10) {
                        StyledTextField("Phone", text: $phone)
                        StyledTextField("Email", text: $email)
                    }
                    StyledTextField("Website", text: $website)
                }
            }

            ProductionCard(icon: "mappin.and.ellipse", title: "ADDRESS") {
                VStack(spacing: 12) {
                    StyledTextField("Street address", text: $address)
                    HStack(spacing: 10) {
                        StyledTextField("City", text: $city)
                        StyledTextField("State / region", text: $region)
                    }
                    StyledTextField("Country", text: $country)
                }
            }

            ProductionCard(icon: "note.text", title: "NOTES") {
                TextEditor(text: $notes)
                    .font(.system(size: 12))
                    .frame(height: 70)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .quaternarySystemFill)))
            }
        }
    }

    // MARK: Actions

    private func loadExisting() {
        guard let vendor else { return }
        name = vendor.name
        category = vendor.category
        phone = vendor.phone
        email = vendor.email
        website = vendor.website
        address = vendor.address
        city = vendor.city
        region = vendor.region
        country = vendor.country
        notes = vendor.notes
        rating = vendor.rating
        imagePath = vendor.imagePath
        sourceUrl = vendor.sourceUrl
        pictureImage = VendorImageIO.load(imagePath: vendor.imagePath, basePath: viewModel.projectBasePath)
    }

    private func save() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        var built = vendor ?? Vendor()
        built.name = name.trimmingCharacters(in: .whitespaces)
        built.category = category.trimmingCharacters(in: .whitespaces)
        built.phone = phone.trimmingCharacters(in: .whitespaces)
        built.email = email.trimmingCharacters(in: .whitespaces)
        built.website = website.trimmingCharacters(in: .whitespaces)
        built.address = address.trimmingCharacters(in: .whitespaces)
        built.city = city.trimmingCharacters(in: .whitespaces)
        built.region = region.trimmingCharacters(in: .whitespaces)
        built.country = country.trimmingCharacters(in: .whitespaces)
        built.notes = trimmedNotes
        built.rating = rating
        built.imagePath = imagePath
        built.sourceUrl = sourceUrl
        if vendor == nil {
            viewModel.addVendor(built)
        } else {
            viewModel.updateVendor(built)
        }
    }

    /// Pick an image from disk and copy it into the project's assets/vendors/.
    private func addPicture() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a picture for this vendor"
        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        if let stored = VendorImageIO.importPicture(from: sourceURL, basePath: viewModel.projectBasePath) {
            imagePath = stored
            pictureImage = VendorImageIO.load(imagePath: stored, basePath: viewModel.projectBasePath)
        } else {
            pictureImage = NSImage(contentsOf: sourceURL)
            imagePath = sourceURL.path
        }
    }

    /// Resolve the pasted text to a URL (a real link, or a Google search built
    /// from a typed name) and hand it to the app target's vendor lookup.
    private func autodetect() {
        lookupError = nil
        lookupSuccess = nil
        let raw = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        let url: URL?
        if let direct = URL(string: raw), direct.scheme != nil {
            url = direct
        } else if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            url = URL(string: "https://www.google.com/search?q=\(encoded)")
        } else {
            url = nil
        }
        guard let url else { lookupError = "That doesn't look like a link."; return }

        isLooking = true
        Task {
            let result = await viewModel.lookupVendor(from: url)
            isLooking = false
            guard let result else {
                lookupError = "Couldn't detect a vendor from that link."
                return
            }
            apply(result, sourceLink: url.absoluteString)
        }
    }

    /// Fill only the empty fields so a partial detection never wipes what the
    /// user already typed; the name always takes the detected value if present.
    private func apply(_ result: VendorLookupResult, sourceLink: String) {
        if !result.name.isEmpty { name = result.name }
        if category.isEmpty { category = result.category }
        if phone.isEmpty { phone = result.phone }
        if email.isEmpty { email = result.email }
        if website.isEmpty { website = result.website }
        if address.isEmpty { address = result.address }
        if city.isEmpty { city = result.city }
        if region.isEmpty { region = result.region }
        if country.isEmpty { country = result.country }
        if notes.isEmpty { notes = result.description }
        if rating == nil { rating = result.rating }
        sourceUrl = sourceLink
        if let path = result.imagePath {
            imagePath = path
            pictureImage = VendorImageIO.load(imagePath: path, basePath: viewModel.projectBasePath)
        }
        lookupSuccess = "Filled from \(result.name.isEmpty ? "the link" : result.name)."
    }
}

// MARK: - Vendor picture file IO

/// Small helpers for reading/writing vendor pictures under the project's
/// assets/vendors/ folder. Kept here so both the card and the sheet share it.
enum VendorImageIO {

    static func load(imagePath: String?, basePath: URL?) -> NSImage? {
        guard let imagePath, !imagePath.isEmpty else { return nil }
        let url: URL
        if imagePath.hasPrefix("/") {
            url = URL(fileURLWithPath: imagePath)
        } else if let basePath {
            url = basePath.appendingPathComponent(imagePath)
        } else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    /// Copy an on-disk picture into assets/vendors/, returning the
    /// project-relative path (or nil to signal "fall back to absolute").
    static func importPicture(from sourceURL: URL, basePath: URL?) -> String? {
        guard let basePath else { return nil }
        let dir = basePath.appendingPathComponent("assets/vendors")
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let dest = dir.appendingPathComponent(filename)
        do {
            try fm.copyItem(at: sourceURL, to: dest)
            return "assets/vendors/\(filename)"
        } catch {
            return nil
        }
    }
}
