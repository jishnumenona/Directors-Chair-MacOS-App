// DirectorsChairCore/Sources/DirectorsChairCore/Models/CastCrewTeamEquipment.swift
//
// Cast, Crew, Team, and Equipment models for production management

import Foundation

// MARK: - CastMember

/// Represents a cast member (actor) in the production
public struct CastMember: Codable, Identifiable, Hashable {
    public var id: String

    // Basic Info
    public var actorName: String
    public var characterName: String
    public var characterDescription: String

    // Contact Info
    public var email: String
    public var phone: String
    public var address: String
    public var emergencyContactName: String
    public var emergencyContactPhone: String
    public var emergencyContactRelationship: String

    // Role Details
    public var roleType: String  // "Principal", "Supporting", "Background", "Extra", "Stunt Double"
    public var unionStatus: String  // "SAG-AFTRA", "Non-Union", "Equity"

    // Availability
    public var availabilityNotes: String
    public var dailyRate: Double
    public var overtimeRate: Double

    // Physical Details
    public var height: String
    public var hairColor: String
    public var eyeColor: String
    public var wardrobeSize: String
    public var wardrobeNotes: String
    public var specialRequirements: String
    public var photoPath: String

    // Production Notes
    public var agentName: String
    public var agentCompany: String
    public var agentPhone: String
    public var agentEmail: String
    public var notes: String
    public var contractSigned: Bool
    public var contractNotes: String

    // External Management
    public var contractManagedExternally: Bool
    public var externalManagementSystem: String

    // Metadata
    public var createdDate: String
    public var modifiedDate: String

    public init(
        id: String = "cast_\(UUID().uuidString.prefix(12))",
        actorName: String = "",
        characterName: String = "",
        characterDescription: String = "",
        email: String = "",
        phone: String = "",
        address: String = "",
        emergencyContactName: String = "",
        emergencyContactPhone: String = "",
        emergencyContactRelationship: String = "",
        roleType: String = "Principal",
        unionStatus: String = "Non-Union",
        availabilityNotes: String = "",
        dailyRate: Double = 0.0,
        overtimeRate: Double = 0.0,
        height: String = "",
        hairColor: String = "",
        eyeColor: String = "",
        wardrobeSize: String = "",
        wardrobeNotes: String = "",
        specialRequirements: String = "",
        photoPath: String = "",
        agentName: String = "",
        agentCompany: String = "",
        agentPhone: String = "",
        agentEmail: String = "",
        notes: String = "",
        contractSigned: Bool = false,
        contractNotes: String = "",
        contractManagedExternally: Bool = false,
        externalManagementSystem: String = "",
        createdDate: String = ISO8601DateFormatter().string(from: Date()),
        modifiedDate: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.actorName = actorName
        self.characterName = characterName
        self.characterDescription = characterDescription
        self.email = email
        self.phone = phone
        self.address = address
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.emergencyContactRelationship = emergencyContactRelationship
        self.roleType = roleType
        self.unionStatus = unionStatus
        self.availabilityNotes = availabilityNotes
        self.dailyRate = dailyRate
        self.overtimeRate = overtimeRate
        self.height = height
        self.hairColor = hairColor
        self.eyeColor = eyeColor
        self.wardrobeSize = wardrobeSize
        self.wardrobeNotes = wardrobeNotes
        self.specialRequirements = specialRequirements
        self.photoPath = photoPath
        self.agentName = agentName
        self.agentCompany = agentCompany
        self.agentPhone = agentPhone
        self.agentEmail = agentEmail
        self.notes = notes
        self.contractSigned = contractSigned
        self.contractNotes = contractNotes
        self.contractManagedExternally = contractManagedExternally
        self.externalManagementSystem = externalManagementSystem
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }

    enum CodingKeys: String, CodingKey {
        case id
        case actorName = "actor_name"
        case characterName = "character_name"
        case characterDescription = "character_description"
        case email, phone, address
        case emergencyContactName = "emergency_contact_name"
        case emergencyContactPhone = "emergency_contact_phone"
        case emergencyContactRelationship = "emergency_contact_relationship"
        case roleType = "role_type"
        case unionStatus = "union_status"
        case availabilityNotes = "availability_notes"
        case dailyRate = "daily_rate"
        case overtimeRate = "overtime_rate"
        case height
        case hairColor = "hair_color"
        case eyeColor = "eye_color"
        case wardrobeSize = "wardrobe_size"
        case wardrobeNotes = "wardrobe_notes"
        case specialRequirements = "special_requirements"
        case photoPath = "photo_path"
        case agentName = "agent_name"
        case agentCompany = "agent_company"
        case agentPhone = "agent_phone"
        case agentEmail = "agent_email"
        case notes
        case contractSigned = "contract_signed"
        case contractNotes = "contract_notes"
        case contractManagedExternally = "contract_managed_externally"
        case externalManagementSystem = "external_management_system"
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
    }
}

// MARK: - CrewMember

/// Represents a crew member in the production
public struct CrewMember: Codable, Identifiable, Hashable {
    public var id: String

    // Basic Info
    public var name: String
    public var role: String  // Director, DP, Gaffer, Sound, Editor, etc.
    public var department: String  // Camera, Lighting, Sound, Art, Wardrobe, Makeup, Post, etc.

    // Contact Info
    public var email: String
    public var phone: String
    public var emergencyContact: String
    public var emergencyPhone: String

    // Employment Details
    public var employmentType: String  // "Staff", "Freelance", "Intern", "Volunteer"
    public var dailyRate: Double
    public var overtimeRate: Double
    public var kitFee: Double

    // Availability
    public var availabilityNotes: String
    public var startDate: String?
    public var endDate: String?

    // Skills & Equipment
    public var skills: [String]
    public var equipmentOwned: [String]
    public var certifications: String

    // Photo
    public var photoPath: String

    // Production Notes
    public var notes: String
    public var contractSigned: Bool
    public var w9Received: Bool

    // External Management
    public var contractManagedExternally: Bool
    public var externalManagementSystem: String

    // Metadata
    public var createdDate: String
    public var modifiedDate: String

    public init(
        id: String = "crew_\(UUID().uuidString.prefix(12))",
        name: String = "",
        role: String = "",
        department: String = "Production",
        email: String = "",
        phone: String = "",
        emergencyContact: String = "",
        emergencyPhone: String = "",
        employmentType: String = "Freelance",
        dailyRate: Double = 0.0,
        overtimeRate: Double = 0.0,
        kitFee: Double = 0.0,
        availabilityNotes: String = "",
        startDate: String? = nil,
        endDate: String? = nil,
        skills: [String] = [],
        equipmentOwned: [String] = [],
        certifications: String = "",
        photoPath: String = "",
        notes: String = "",
        contractSigned: Bool = false,
        w9Received: Bool = false,
        contractManagedExternally: Bool = false,
        externalManagementSystem: String = "",
        createdDate: String = ISO8601DateFormatter().string(from: Date()),
        modifiedDate: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.department = department
        self.email = email
        self.phone = phone
        self.emergencyContact = emergencyContact
        self.emergencyPhone = emergencyPhone
        self.employmentType = employmentType
        self.dailyRate = dailyRate
        self.overtimeRate = overtimeRate
        self.kitFee = kitFee
        self.availabilityNotes = availabilityNotes
        self.startDate = startDate
        self.endDate = endDate
        self.skills = skills
        self.equipmentOwned = equipmentOwned
        self.certifications = certifications
        self.photoPath = photoPath
        self.notes = notes
        self.contractSigned = contractSigned
        self.w9Received = w9Received
        self.contractManagedExternally = contractManagedExternally
        self.externalManagementSystem = externalManagementSystem
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }

    enum CodingKeys: String, CodingKey {
        case id, name, role, department
        case email, phone
        case emergencyContact = "emergency_contact"
        case emergencyPhone = "emergency_phone"
        case employmentType = "employment_type"
        case dailyRate = "daily_rate"
        case overtimeRate = "overtime_rate"
        case kitFee = "kit_fee"
        case availabilityNotes = "availability_notes"
        case startDate = "start_date"
        case endDate = "end_date"
        case skills
        case equipmentOwned = "equipment_owned"
        case certifications
        case photoPath = "photo_path"
        case notes
        case contractSigned = "contract_signed"
        case w9Received = "w9_received"
        case contractManagedExternally = "contract_managed_externally"
        case externalManagementSystem = "external_management_system"
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
    }
}

// MARK: - Team

/// Represents a team/unit of cast and crew members
public struct Team: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String

    // Description
    public var description: String
    public var teamType: String  // "Shooting Unit", "Department", "Special Team"

    // Members
    public var castMemberIds: [String]
    public var crewMemberIds: [String]

    // Team Lead
    public var teamLeadId: String?

    // Notes
    public var notes: String

    // Metadata
    public var createdDate: String
    public var modifiedDate: String

    public init(
        id: String = "team_\(UUID().uuidString.prefix(12))",
        name: String = "",
        description: String = "",
        teamType: String = "Shooting Unit",
        castMemberIds: [String] = [],
        crewMemberIds: [String] = [],
        teamLeadId: String? = nil,
        notes: String = "",
        createdDate: String = ISO8601DateFormatter().string(from: Date()),
        modifiedDate: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.teamType = teamType
        self.castMemberIds = castMemberIds
        self.crewMemberIds = crewMemberIds
        self.teamLeadId = teamLeadId
        self.notes = notes
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case teamType = "team_type"
        case castMemberIds = "cast_member_ids"
        case crewMemberIds = "crew_member_ids"
        case teamLeadId = "team_lead_id"
        case notes
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
    }
}

// MARK: - EquipmentItem

/// Represents a piece of equipment in the equipment library
public struct EquipmentItem: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String

    // Category
    public var category: String  // Camera, Lighting, Sound, Grip, Electric, G&E, Post, etc.
    public var subcategory: String

    // Details
    public var manufacturer: String
    public var model: String
    public var description: String

    // Quantity & Availability
    public var quantityOwned: Int
    public var quantityAvailable: Int

    // Rental Info
    public var isRental: Bool
    public var rentalCompany: String
    public var rentalDailyRate: Double
    public var rentalWeeklyRate: Double

    // Specs
    public var specs: [String: String]  // Flexible key-value specs

    // Maintenance
    public var serialNumber: String
    public var purchaseDate: String?
    public var lastMaintenanceDate: String?
    public var nextMaintenanceDue: String?
    public var condition: String  // "Excellent", "Good", "Fair", "Needs Repair"

    // Notes
    public var notes: String
    public var storageLocation: String

    // Responsibility
    public var responsibleCrewMemberId: String?
    public var responsibleCrewMemberName: String

    // External Management
    public var rentalManagedExternally: Bool
    public var externalManagementSystem: String

    // Metadata
    public var createdDate: String
    public var modifiedDate: String

    public init(
        id: String = "equip_\(UUID().uuidString.prefix(12))",
        name: String = "",
        category: String = "Camera",
        subcategory: String = "",
        manufacturer: String = "",
        model: String = "",
        description: String = "",
        quantityOwned: Int = 0,
        quantityAvailable: Int = 0,
        isRental: Bool = false,
        rentalCompany: String = "",
        rentalDailyRate: Double = 0.0,
        rentalWeeklyRate: Double = 0.0,
        specs: [String: String] = [:],
        serialNumber: String = "",
        purchaseDate: String? = nil,
        lastMaintenanceDate: String? = nil,
        nextMaintenanceDue: String? = nil,
        condition: String = "Good",
        notes: String = "",
        storageLocation: String = "",
        responsibleCrewMemberId: String? = nil,
        responsibleCrewMemberName: String = "",
        rentalManagedExternally: Bool = false,
        externalManagementSystem: String = "",
        createdDate: String = ISO8601DateFormatter().string(from: Date()),
        modifiedDate: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.manufacturer = manufacturer
        self.model = model
        self.description = description
        self.quantityOwned = quantityOwned
        self.quantityAvailable = quantityAvailable
        self.isRental = isRental
        self.rentalCompany = rentalCompany
        self.rentalDailyRate = rentalDailyRate
        self.rentalWeeklyRate = rentalWeeklyRate
        self.specs = specs
        self.serialNumber = serialNumber
        self.purchaseDate = purchaseDate
        self.lastMaintenanceDate = lastMaintenanceDate
        self.nextMaintenanceDue = nextMaintenanceDue
        self.condition = condition
        self.notes = notes
        self.storageLocation = storageLocation
        self.responsibleCrewMemberId = responsibleCrewMemberId
        self.responsibleCrewMemberName = responsibleCrewMemberName
        self.rentalManagedExternally = rentalManagedExternally
        self.externalManagementSystem = externalManagementSystem
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, subcategory
        case manufacturer, model, description
        case quantityOwned = "quantity_owned"
        case quantityAvailable = "quantity_available"
        case isRental = "is_rental"
        case rentalCompany = "rental_company"
        case rentalDailyRate = "rental_daily_rate"
        case rentalWeeklyRate = "rental_weekly_rate"
        case specs
        case serialNumber = "serial_number"
        case purchaseDate = "purchase_date"
        case lastMaintenanceDate = "last_maintenance_date"
        case nextMaintenanceDue = "next_maintenance_due"
        case condition, notes
        case storageLocation = "storage_location"
        case responsibleCrewMemberId = "responsible_crew_member_id"
        case responsibleCrewMemberName = "responsible_crew_member_name"
        case rentalManagedExternally = "rental_managed_externally"
        case externalManagementSystem = "external_management_system"
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
    }
}
