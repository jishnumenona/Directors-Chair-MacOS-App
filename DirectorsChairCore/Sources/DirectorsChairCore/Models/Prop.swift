// DirectorsChairCore/Sources/DirectorsChairCore/Models/Prop.swift
//
// Enhanced production prop with comprehensive tracking

import Foundation

/// Enhanced production prop with comprehensive tracking
/// Backward compatible: old props only have name/thumbnail; new props have full tracking
public struct Prop: Codable, Identifiable, Hashable {
    // MARK: - Core Fields (existing - backward compatible)
    public var id: String
    public var name: String
    public var thumbnail: String?  // Relative path inside project

    // MARK: - Basic Info
    public var description: String  // Visual appearance description
    public var detailedSpecs: String  // Detailed specifications for prop makers
    public var category: String  // Weapon, Furniture, Food, Document, etc.
    public var tags: [String]  // fragile, period-piece, hero-prop, etc.

    // MARK: - Acquisition
    public var acquisitionType: String?  // "Own", "Rental", "Purchase", "Build", "Borrow"
    public var source: String?  // Vendor/shop name or owner
    public var acquisitionCost: Double?
    public var rentalDailyRate: Double?  // For rentals
    public var rentalStartDate: String?  // ISO date
    public var rentalEndDate: String?  // ISO date
    public var purchaseDate: String?  // ISO date for purchased items
    public var returnDate: String?  // For borrowed/rented items
    public var depositAmount: Double?  // Security deposit

    // MARK: - Inventory
    public var quantity: Int?  // How many we have
    public var quantityHero: Int?  // Hero versions (pristine for close-ups)
    public var quantityStunt: Int?  // Stunt versions (breakable, can be damaged)
    public var storageLocation: String?  // Where it's stored
    public var barcodeId: String?  // Barcode for tracking

    // MARK: - Continuity
    public var continuityStates: [PropContinuityState]?  // States across scenes
    public var continuityNotes: String?  // General continuity notes
    public var continuityCritical: Bool?  // Flag for props requiring strict tracking

    // MARK: - Crew Assignment
    public var propsMasterId: String?  // Crew member ID responsible
    public var propsMasterName: String?  // Name for display

    // MARK: - Fabrication (for built props)
    public var requiresFabrication: Bool?
    public var fabrication: PropFabrication?

    // MARK: - Scene Usage
    public var sceneNames: [String]?  // Which scenes use this prop
    public var firstAppearanceScene: String?  // First scene it appears
    public var lastAppearanceScene: String?  // Last scene it appears

    // MARK: - Photos & References
    public var referencePhotos: [String]  // Additional reference photos
    public var receiptPath: String?  // Receipt/invoice scan

    // MARK: - Production Notes
    public var notes: String  // General notes
    public var handlingInstructions: String  // Special handling (fragile, dangerous, etc.)
    public var safetyNotes: String  // Safety considerations

    // MARK: - Status
    public var status: String?  // "Available", "In Use", "Damaged", "Lost", "Returned"

    // MARK: - Metadata
    public var createdDate: String?
    public var modifiedDate: String?

    public init(
        id: String = "prop_\(UUID().uuidString.prefix(12))",
        name: String,
        thumbnail: String? = nil,
        description: String = "",
        detailedSpecs: String = "",
        category: String = "",
        tags: [String] = [],
        acquisitionType: String? = nil,
        source: String? = nil,
        acquisitionCost: Double? = nil,
        rentalDailyRate: Double? = nil,
        rentalStartDate: String? = nil,
        rentalEndDate: String? = nil,
        purchaseDate: String? = nil,
        returnDate: String? = nil,
        depositAmount: Double? = nil,
        quantity: Int? = nil,
        quantityHero: Int? = nil,
        quantityStunt: Int? = nil,
        storageLocation: String? = nil,
        barcodeId: String? = nil,
        continuityStates: [PropContinuityState]? = nil,
        continuityNotes: String? = nil,
        continuityCritical: Bool? = nil,
        propsMasterId: String? = nil,
        propsMasterName: String? = nil,
        requiresFabrication: Bool? = nil,
        fabrication: PropFabrication? = nil,
        sceneNames: [String]? = nil,
        firstAppearanceScene: String? = nil,
        lastAppearanceScene: String? = nil,
        referencePhotos: [String] = [],
        receiptPath: String? = nil,
        notes: String = "",
        handlingInstructions: String = "",
        safetyNotes: String = "",
        status: String? = nil,
        createdDate: String? = nil,
        modifiedDate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.thumbnail = thumbnail
        self.description = description
        self.detailedSpecs = detailedSpecs
        self.category = category
        self.tags = tags
        self.acquisitionType = acquisitionType
        self.source = source
        self.acquisitionCost = acquisitionCost
        self.rentalDailyRate = rentalDailyRate
        self.rentalStartDate = rentalStartDate
        self.rentalEndDate = rentalEndDate
        self.purchaseDate = purchaseDate
        self.returnDate = returnDate
        self.depositAmount = depositAmount
        self.quantity = quantity
        self.quantityHero = quantityHero
        self.quantityStunt = quantityStunt
        self.storageLocation = storageLocation
        self.barcodeId = barcodeId
        self.continuityStates = continuityStates
        self.continuityNotes = continuityNotes
        self.continuityCritical = continuityCritical
        self.propsMasterId = propsMasterId
        self.propsMasterName = propsMasterName
        self.requiresFabrication = requiresFabrication
        self.fabrication = fabrication
        self.sceneNames = sceneNames
        self.firstAppearanceScene = firstAppearanceScene
        self.lastAppearanceScene = lastAppearanceScene
        self.referencePhotos = referencePhotos
        self.receiptPath = receiptPath
        self.notes = notes
        self.handlingInstructions = handlingInstructions
        self.safetyNotes = safetyNotes
        self.status = status
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case thumbnail
        case description
        case detailedSpecs = "detailed_specs"
        case category
        case tags
        case acquisitionType = "acquisition_type"
        case source
        case acquisitionCost = "acquisition_cost"
        case rentalDailyRate = "rental_daily_rate"
        case rentalStartDate = "rental_start_date"
        case rentalEndDate = "rental_end_date"
        case purchaseDate = "purchase_date"
        case returnDate = "return_date"
        case depositAmount = "deposit_amount"
        case quantity
        case quantityHero = "quantity_hero"
        case quantityStunt = "quantity_stunt"
        case storageLocation = "storage_location"
        case barcodeId = "barcode_id"
        case continuityStates = "continuity_states"
        case continuityNotes = "continuity_notes"
        case continuityCritical = "continuity_critical"
        case propsMasterId = "props_master_id"
        case propsMasterName = "props_master_name"
        case requiresFabrication = "requires_fabrication"
        case fabrication
        case sceneNames = "scene_names"
        case firstAppearanceScene = "first_appearance_scene"
        case lastAppearanceScene = "last_appearance_scene"
        case referencePhotos = "reference_photos"
        case receiptPath = "receipt_path"
        case notes
        case handlingInstructions = "handling_instructions"
        case safetyNotes = "safety_notes"
        case status
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
    }
}
