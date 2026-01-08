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
}

// MARK: - BudgetCategory

/// A budget category with allocated and spent amounts
public struct BudgetCategory: Codable, Hashable {
    public var name: String
    public var allocated: Double  // Budgeted amount
    public var spent: Double  // Actual spent
    public var description: String
    public var isCustom: Bool  // User-added category

    public var remaining: Double {
        allocated - spent
    }

    public var variancePercentage: Double {
        guard allocated != 0 else { return 0.0 }
        return ((spent - allocated) / allocated) * 100
    }

    public init(
        name: String,
        allocated: Double = 0.0,
        spent: Double = 0.0,
        description: String = "",
        isCustom: Bool = false
    ) {
        self.name = name
        self.allocated = allocated
        self.spent = spent
        self.description = description
        self.isCustom = isCustom
    }

    enum CodingKeys: String, CodingKey {
        case name, allocated, spent, description
        case isCustom = "is_custom"
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
        receiptPath: String? = nil
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
    }

    enum CodingKeys: String, CodingKey {
        case id, date, category, amount, description, vendor
        case sceneId = "scene_id"
        case shotId = "shot_id"
        case receiptPath = "receipt_path"
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
        aiProductionEstimates: [String: Double]? = nil
    ) {
        self.categories = categories
        self.expenses = expenses
        self.totalBudget = totalBudget
        self.currency = currency
        self.aiBudgetLimit = aiBudgetLimit
        self.aiProductionEstimates = aiProductionEstimates
    }

    enum CodingKeys: String, CodingKey {
        case categories, expenses
        case totalBudget = "total_budget"
        case currency
        case aiBudgetLimit = "ai_budget_limit"
        case aiProductionEstimates = "ai_production_estimates"
    }
}
