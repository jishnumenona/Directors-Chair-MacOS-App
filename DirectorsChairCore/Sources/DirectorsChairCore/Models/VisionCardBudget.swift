// DirectorsChairCore/Sources/DirectorsChairCore/Models/VisionCardBudget.swift
//
// VisionCard, Budget, and related models

import Foundation

// MARK: - VisionCard

/// Represents a vision card - visual reference for filmmaking pre-production
/// Formerly known as Beat cards - maintains backward compatibility
public struct VisionCard: Codable, Identifiable, Hashable {
    // Core Identity
    public var id: String
    public var title: String
    public var description: String
    public var character: String?
    public var text: String

    // Tags and References
    public var tags: [String]
    public var props: [String]
    public var costumes: [String]
    public var effects: [String]

    // Image/Media
    public var imagePath: String?
    public var videoUrl: String?

    // Scene References
    public var sequenceName: String?
    public var sceneName: String?
    public var position: Int

    // Vision Board Fields
    public var cardType: String  // image, color_palette, video, text, texture, lighting, location
    public var boardId: String  // ID of the board this card belongs to
    public var colorPalette: [String]  // Hex color codes
    public var sourceUrl: String?  // URL source of reference
    public var credit: String?  // Photographer/artist credit
    public var pinned: Bool  // Whether card is pinned to top
    public var size: String  // small, medium, large
    public var department: String?  // cinematography, costume, production_design, etc.

    // Canvas Positioning (for freeform canvas layout)
    public var canvasX: Double?  // X position on canvas (nil for auto-positioning)
    public var canvasY: Double?  // Y position on canvas
    public var zOrder: Double  // Z-order for stacking (higher values on top)
    public var canvasWidth: Double?  // Width of card on canvas
    public var canvasHeight: Double?  // Height of card on canvas

    // Text Card Specific
    public var textColor: String  // Hex color code for text cards

    public init(
        id: String = UUID().uuidString,
        title: String = "",
        description: String = "",
        character: String? = nil,
        text: String = "",
        tags: [String] = [],
        props: [String] = [],
        costumes: [String] = [],
        effects: [String] = [],
        imagePath: String? = nil,
        videoUrl: String? = nil,
        sequenceName: String? = nil,
        sceneName: String? = nil,
        position: Int = 0,
        cardType: String = "image",
        boardId: String = "master",
        colorPalette: [String] = [],
        sourceUrl: String? = nil,
        credit: String? = nil,
        pinned: Bool = false,
        size: String = "medium",
        department: String? = nil,
        canvasX: Double? = nil,
        canvasY: Double? = nil,
        zOrder: Double = 0,
        canvasWidth: Double? = nil,
        canvasHeight: Double? = nil,
        textColor: String = "#FFFFFF"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.character = character
        self.text = text
        self.tags = tags
        self.props = props
        self.costumes = costumes
        self.effects = effects
        self.imagePath = imagePath
        self.videoUrl = videoUrl
        self.sequenceName = sequenceName
        self.sceneName = sceneName
        self.position = position
        self.cardType = cardType
        self.boardId = boardId
        self.colorPalette = colorPalette
        self.sourceUrl = sourceUrl
        self.credit = credit
        self.pinned = pinned
        self.size = size
        self.department = department
        self.canvasX = canvasX
        self.canvasY = canvasY
        self.zOrder = zOrder
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.textColor = textColor
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, character, text
        case tags, props, costumes, effects
        case imagePath = "image_path"
        case videoUrl = "video_url"
        case sequenceName = "sequence_name"
        case sceneName = "scene_name"
        case position
        case cardType = "card_type"
        case boardId = "board_id"
        case colorPalette = "color_palette"
        case sourceUrl = "source_url"
        case credit, pinned, size, department
        case canvasX = "canvas_x"
        case canvasY = "canvas_y"
        case zOrder = "z_order"
        case canvasWidth = "canvas_width"
        case canvasHeight = "canvas_height"
        case textColor = "text_color"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to auto-generate ID and provide defaults for missing fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Auto-generate ID if missing
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString

        // Core fields with defaults
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        character = try container.decodeIfPresent(String.self, forKey: .character)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""

        // Arrays with empty defaults
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        props = try container.decodeIfPresent([String].self, forKey: .props) ?? []
        costumes = try container.decodeIfPresent([String].self, forKey: .costumes) ?? []
        effects = try container.decodeIfPresent([String].self, forKey: .effects) ?? []

        // Media fields
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        videoUrl = try container.decodeIfPresent(String.self, forKey: .videoUrl)

        // Scene references
        sequenceName = try container.decodeIfPresent(String.self, forKey: .sequenceName)
        sceneName = try container.decodeIfPresent(String.self, forKey: .sceneName)
        position = try container.decodeIfPresent(Int.self, forKey: .position) ?? 0

        // Vision board fields
        cardType = try container.decodeIfPresent(String.self, forKey: .cardType) ?? "image"
        boardId = try container.decodeIfPresent(String.self, forKey: .boardId) ?? "master"
        colorPalette = try container.decodeIfPresent([String].self, forKey: .colorPalette) ?? []
        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        credit = try container.decodeIfPresent(String.self, forKey: .credit)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        size = try container.decodeIfPresent(String.self, forKey: .size) ?? "medium"
        department = try container.decodeIfPresent(String.self, forKey: .department)

        // Canvas positioning
        canvasX = try container.decodeIfPresent(Double.self, forKey: .canvasX)
        canvasY = try container.decodeIfPresent(Double.self, forKey: .canvasY)
        zOrder = try container.decodeIfPresent(Double.self, forKey: .zOrder) ?? 0
        canvasWidth = try container.decodeIfPresent(Double.self, forKey: .canvasWidth)
        canvasHeight = try container.decodeIfPresent(Double.self, forKey: .canvasHeight)

        // Text card specific
        textColor = try container.decodeIfPresent(String.self, forKey: .textColor) ?? "#FFFFFF"
    }
}

// MARK: - BudgetCategory

/// A budget category with allocated and spent amounts
public struct BudgetCategory: Codable, Identifiable, Hashable {
    /// Stable identity, independent of name, so a category can be renamed
    /// without losing the edit or orphaning its expenses. Legacy files without
    /// an id get one on load.
    public var id: String
    public var name: String
    public var allocated: Double  // Budgeted amount
    public var spent: Double  // Actual spent
    public var description: String
    public var isCustom: Bool  // User-added category
    public var accountCode: String  // Industry standard account code (e.g., "1100")
    public var categoryGroup: String  // "ATL", "BTL", "Post", "Other"

    public var remaining: Double {
        allocated - spent
    }

    public var variancePercentage: Double {
        guard allocated != 0 else { return 0.0 }
        return ((spent - allocated) / allocated) * 100
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        allocated: Double = 0.0,
        spent: Double = 0.0,
        description: String = "",
        isCustom: Bool = false,
        accountCode: String = "",
        categoryGroup: String = ""
    ) {
        self.id = id
        self.name = name
        self.allocated = allocated
        self.spent = spent
        self.description = description
        self.isCustom = isCustom
        self.accountCode = accountCode
        self.categoryGroup = categoryGroup
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name, allocated, spent, description
        case isCustom = "is_custom"
        case accountCode = "account_code"
        case categoryGroup = "category_group"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for missing fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        allocated = try container.decodeIfPresent(Double.self, forKey: .allocated) ?? 0.0
        spent = try container.decodeIfPresent(Double.self, forKey: .spent) ?? 0.0
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        accountCode = try container.decodeIfPresent(String.self, forKey: .accountCode) ?? ""
        categoryGroup = try container.decodeIfPresent(String.self, forKey: .categoryGroup) ?? ""
    }
}

// MARK: - Expense

/// A single expense entry
public struct Expense: Codable, Identifiable, Hashable {
    public var id: String
    public var date: String  // YYYY-MM-DD format
    public var category: String
    public var amount: Double
    public var description: String
    public var vendor: String
    public var sceneId: String?  // Link to scene
    public var shotId: String?  // Link to shot
    public var receiptPath: String?  // Path to receipt image/PDF
    public var department: String  // Links to department for departmental reporting
    public var accountCode: String  // Industry account code
    public var paymentMethod: String  // "Check", "Card", "PettyCash", "Wire", "PO"
    public var purchaseOrderId: String?  // Links to PO
    public var status: String  // "Pending", "Approved", "Paid"
    public var isQualifyingExpense: Bool  // For tax incentive tracking
    public var addedBy: String  // Name of person who added the expense
    public var locationId: String?  // Links to location
    public var equipmentId: String?  // Links to equipment

    public init(
        id: String = UUID().uuidString,
        date: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }(),
        category: String = "",
        amount: Double = 0.0,
        description: String = "",
        vendor: String = "",
        sceneId: String? = nil,
        shotId: String? = nil,
        receiptPath: String? = nil,
        department: String = "",
        accountCode: String = "",
        paymentMethod: String = "Card",
        purchaseOrderId: String? = nil,
        status: String = "Pending",
        isQualifyingExpense: Bool = false,
        addedBy: String = "",
        locationId: String? = nil,
        equipmentId: String? = nil
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.amount = amount
        self.description = description
        self.vendor = vendor
        self.sceneId = sceneId
        self.shotId = shotId
        self.receiptPath = receiptPath
        self.department = department
        self.accountCode = accountCode
        self.paymentMethod = paymentMethod
        self.purchaseOrderId = purchaseOrderId
        self.status = status
        self.isQualifyingExpense = isQualifyingExpense
        self.addedBy = addedBy
        self.locationId = locationId
        self.equipmentId = equipmentId
    }

    enum CodingKeys: String, CodingKey {
        case id, date, category, amount, description, vendor
        case sceneId = "scene_id"
        case shotId = "shot_id"
        case receiptPath = "receipt_path"
        case department
        case accountCode = "account_code"
        case paymentMethod = "payment_method"
        case purchaseOrderId = "purchase_order_id"
        case status
        case isQualifyingExpense = "is_qualifying_expense"
        case addedBy = "added_by"
        case locationId = "location_id"
        case equipmentId = "equipment_id"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to auto-generate ID and provide defaults for missing fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Auto-generate ID if missing
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString

        // Date with default
        let defaultDate: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }()
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? defaultDate

        // All other fields with defaults
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0.0
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        vendor = try container.decodeIfPresent(String.self, forKey: .vendor) ?? ""
        sceneId = try container.decodeIfPresent(String.self, forKey: .sceneId)
        shotId = try container.decodeIfPresent(String.self, forKey: .shotId)
        receiptPath = try container.decodeIfPresent(String.self, forKey: .receiptPath)
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        accountCode = try container.decodeIfPresent(String.self, forKey: .accountCode) ?? ""
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod) ?? "Card"
        purchaseOrderId = try container.decodeIfPresent(String.self, forKey: .purchaseOrderId)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "Pending"
        isQualifyingExpense = try container.decodeIfPresent(Bool.self, forKey: .isQualifyingExpense) ?? false
        addedBy = try container.decodeIfPresent(String.self, forKey: .addedBy) ?? ""
        locationId = try container.decodeIfPresent(String.self, forKey: .locationId)
        equipmentId = try container.decodeIfPresent(String.self, forKey: .equipmentId)
    }
}

// MARK: - PurchaseOrder

/// A purchase order for production expenses
public struct PurchaseOrder: Codable, Identifiable, Hashable {
    public var id: String
    public var poNumber: String           // User-facing PO number (e.g., "PO-001")
    public var vendor: String
    public var department: String          // Camera, Lighting, Art, etc.
    public var accountCode: String         // Industry account code (e.g., "3300")
    public var description: String
    public var amount: Double
    public var status: String              // "Draft", "Approved", "Committed", "Paid", "Cancelled"
    public var dateCreated: String
    public var dateApproved: String?
    public var datePaid: String?
    public var notes: String
    public var sceneId: String?
    public var approvedBy: String
    public var attachments: [String]  // Relative paths to attached files

    public init(
        id: String = UUID().uuidString,
        poNumber: String = "",
        vendor: String = "",
        department: String = "",
        accountCode: String = "",
        description: String = "",
        amount: Double = 0.0,
        status: String = "Draft",
        dateCreated: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }(),
        dateApproved: String? = nil,
        datePaid: String? = nil,
        notes: String = "",
        sceneId: String? = nil,
        approvedBy: String = "",
        attachments: [String] = []
    ) {
        self.id = id
        self.poNumber = poNumber
        self.vendor = vendor
        self.department = department
        self.accountCode = accountCode
        self.description = description
        self.amount = amount
        self.status = status
        self.dateCreated = dateCreated
        self.dateApproved = dateApproved
        self.datePaid = datePaid
        self.notes = notes
        self.sceneId = sceneId
        self.approvedBy = approvedBy
        self.attachments = attachments
    }

    enum CodingKeys: String, CodingKey {
        case id, vendor, department, description, amount, status, notes, attachments
        case poNumber = "po_number"
        case accountCode = "account_code"
        case dateCreated = "date_created"
        case dateApproved = "date_approved"
        case datePaid = "date_paid"
        case sceneId = "scene_id"
        case approvedBy = "approved_by"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        poNumber = try container.decodeIfPresent(String.self, forKey: .poNumber) ?? ""
        vendor = try container.decodeIfPresent(String.self, forKey: .vendor) ?? ""
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        accountCode = try container.decodeIfPresent(String.self, forKey: .accountCode) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0.0
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "Draft"

        let defaultDate: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }()
        dateCreated = try container.decodeIfPresent(String.self, forKey: .dateCreated) ?? defaultDate
        dateApproved = try container.decodeIfPresent(String.self, forKey: .dateApproved)
        datePaid = try container.decodeIfPresent(String.self, forKey: .datePaid)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        sceneId = try container.decodeIfPresent(String.self, forKey: .sceneId)
        approvedBy = try container.decodeIfPresent(String.self, forKey: .approvedBy) ?? ""
        attachments = try container.decodeIfPresent([String].self, forKey: .attachments) ?? []
    }
}

// MARK: - ProjectBudget

/// Complete budget for a project
public struct ProjectBudget: Codable, Hashable {
    public var categories: [BudgetCategory]
    public var expenses: [Expense]
    public var totalBudget: Double
    public var currency: String
    public var aiBudgetLimit: Double  // Custom limit for AI services
    public var aiProductionEstimates: [String: Double]?  // AI video production cost estimates
    public var purchaseOrders: [PurchaseOrder]
    public var contingencyPercentage: Double  // Typically 10% of BTL+Post
    public var fringeRate: Double  // Default fringe percentage (e.g., 0.30 = 30%)

    public var totalSpent: Double {
        categories.reduce(0) { $0 + $1.spent }
    }

    public var totalRemaining: Double {
        totalBudget - totalSpent
    }

    public init(
        categories: [BudgetCategory] = [],
        expenses: [Expense] = [],
        totalBudget: Double = 0.0,
        currency: String = "USD",
        aiBudgetLimit: Double = 0.0,
        aiProductionEstimates: [String: Double]? = nil,
        purchaseOrders: [PurchaseOrder] = [],
        contingencyPercentage: Double = 0.10,
        fringeRate: Double = 0.30
    ) {
        self.categories = categories
        self.expenses = expenses
        self.totalBudget = totalBudget
        self.currency = currency
        self.aiBudgetLimit = aiBudgetLimit
        self.aiProductionEstimates = aiProductionEstimates
        self.purchaseOrders = purchaseOrders
        self.contingencyPercentage = contingencyPercentage
        self.fringeRate = fringeRate
    }

    enum CodingKeys: String, CodingKey {
        case categories, expenses
        case totalBudget = "total_budget"
        case currency
        case aiBudgetLimit = "ai_budget_limit"
        case aiProductionEstimates = "ai_production_estimates"
        case purchaseOrders = "purchase_orders"
        case contingencyPercentage = "contingency_percentage"
        case fringeRate = "fringe_rate"
    }

    // MARK: - Custom Decoder (Python Compatibility)

    /// Custom decoder to provide defaults for missing fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        categories = try container.decodeIfPresent([BudgetCategory].self, forKey: .categories) ?? []
        expenses = try container.decodeIfPresent([Expense].self, forKey: .expenses) ?? []
        totalBudget = try container.decodeIfPresent(Double.self, forKey: .totalBudget) ?? 0.0
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        aiBudgetLimit = try container.decodeIfPresent(Double.self, forKey: .aiBudgetLimit) ?? 0.0
        aiProductionEstimates = try container.decodeIfPresent([String: Double].self, forKey: .aiProductionEstimates)
        purchaseOrders = try container.decodeIfPresent([PurchaseOrder].self, forKey: .purchaseOrders) ?? []
        contingencyPercentage = try container.decodeIfPresent(Double.self, forKey: .contingencyPercentage) ?? 0.10
        fringeRate = try container.decodeIfPresent(Double.self, forKey: .fringeRate) ?? 0.30
    }
}
