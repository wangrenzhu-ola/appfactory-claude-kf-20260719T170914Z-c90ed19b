import Foundation

/// Bow categories supported by ArrowTune sessions and gear profiles.
public enum BowType: String, Codable, CaseIterable, Identifiable, Sendable {
    case recurve
    case compound

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .recurve: return "Recurve"
        case .compound: return "Compound"
        }
    }
}

/// Standard WA target faces. Ring geometry is expressed in centimeters.
public enum TargetFace: String, Codable, CaseIterable, Identifiable, Sendable {
    case full40cm
    case full60cm

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .full40cm: return "40 cm Face"
        case .full60cm: return "60 cm Face"
        }
    }

    /// Radius of one scoring ring in centimeters (10 equal rings).
    public var ringWidthCm: Double {
        switch self {
        case .full40cm: return 2.0
        case .full60cm: return 3.0
        }
    }

    /// Outer radius of the scoring area in centimeters.
    public var scoringRadiusCm: Double { ringWidthCm * 10.0 }
}

/// How one arrow impact was captured.
public enum ImpactSource: String, Codable, Sendable {
    case photo
    case manual
}

public struct Session: Codable, Identifiable, Equatable, Sendable {
    public let sessionID: UUID
    public var id: UUID { sessionID }
    public var date: Date
    public var bowType: BowType
    public var distanceM: Int
    public var targetFace: TargetFace
    public var arrowsPerEnd: Int
    public var note: String
    public var gearID: UUID?

    public init(
        sessionID: UUID = UUID(),
        date: Date = Date(),
        bowType: BowType,
        distanceM: Int,
        targetFace: TargetFace,
        arrowsPerEnd: Int,
        note: String = "",
        gearID: UUID? = nil
    ) {
        self.sessionID = sessionID
        self.date = date
        self.bowType = bowType
        self.distanceM = distanceM
        self.targetFace = targetFace
        self.arrowsPerEnd = arrowsPerEnd
        self.note = note
        self.gearID = gearID
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case date
        case bowType = "bow_type"
        case distanceM = "distance_m"
        case targetFace = "target_face"
        case arrowsPerEnd = "arrows_per_end"
        case note
        case gearID = "gear_id"
    }
}

public struct End: Codable, Identifiable, Equatable, Sendable {
    public let endID: UUID
    public var id: UUID { endID }
    public let sessionID: UUID
    public var endIndex: Int
    public var scoreTotal: Int

    public init(endID: UUID = UUID(), sessionID: UUID, endIndex: Int, scoreTotal: Int = 0) {
        self.endID = endID
        self.sessionID = sessionID
        self.endIndex = endIndex
        self.scoreTotal = scoreTotal
    }

    enum CodingKeys: String, CodingKey {
        case endID = "end_id"
        case sessionID = "session_id"
        case endIndex = "end_index"
        case scoreTotal = "score_total"
    }
}

public struct ArrowImpact: Codable, Identifiable, Equatable, Sendable {
    public let impactID: UUID
    public var id: UUID { impactID }
    public let endID: UUID
    /// Normalized horizontal offset from target center, in units of the scoring radius.
    public var xNorm: Double
    /// Normalized vertical offset from target center, in units of the scoring radius.
    public var yNorm: Double
    public var ringValue: Int
    public var source: ImpactSource
    public var confirmed: Bool

    public init(
        impactID: UUID = UUID(),
        endID: UUID,
        xNorm: Double,
        yNorm: Double,
        ringValue: Int,
        source: ImpactSource,
        confirmed: Bool
    ) {
        self.impactID = impactID
        self.endID = endID
        self.xNorm = xNorm
        self.yNorm = yNorm
        self.ringValue = ringValue
        self.source = source
        self.confirmed = confirmed
    }

    enum CodingKeys: String, CodingKey {
        case impactID = "impact_id"
        case endID = "end_id"
        case xNorm = "x_norm"
        case yNorm = "y_norm"
        case ringValue = "ring_value"
        case source = "source_photo_or_manual"
        case confirmed
    }
}

public struct GearSetup: Codable, Identifiable, Equatable, Sendable {
    public let gearID: UUID
    public var id: UUID { gearID }
    public var name: String
    public var bowType: BowType
    public var limbSpec: String
    public var arrowSpec: String
    public var sightMark: String
    public var createdAt: Date

    public init(
        gearID: UUID = UUID(),
        name: String,
        bowType: BowType,
        limbSpec: String = "",
        arrowSpec: String = "",
        sightMark: String = "",
        createdAt: Date = Date()
    ) {
        self.gearID = gearID
        self.name = name
        self.bowType = bowType
        self.limbSpec = limbSpec
        self.arrowSpec = arrowSpec
        self.sightMark = sightMark
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case gearID = "gear_id"
        case name
        case bowType = "bow_type"
        case limbSpec = "limb_spec"
        case arrowSpec = "arrow_spec"
        case sightMark = "sight_mark"
        case createdAt = "created_at"
    }
}

public struct TuningChange: Codable, Identifiable, Equatable, Sendable {
    public let changeID: UUID
    public var id: UUID { changeID }
    public let gearID: UUID
    public var changedAt: Date
    public var component: String
    public var fromValue: String
    public var toValue: String
    public var note: String

    public init(
        changeID: UUID = UUID(),
        gearID: UUID,
        changedAt: Date = Date(),
        component: String,
        fromValue: String,
        toValue: String,
        note: String = ""
    ) {
        self.changeID = changeID
        self.gearID = gearID
        self.changedAt = changedAt
        self.component = component
        self.fromValue = fromValue
        self.toValue = toValue
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case changeID = "change_id"
        case gearID = "gear_id"
        case changedAt = "changed_at"
        case component
        case fromValue = "from_value"
        case toValue = "to_value"
        case note
    }
}

public struct DiagnosisReport: Codable, Identifiable, Equatable, Sendable {
    public let reportID: UUID
    public var id: UUID { reportID }
    public let sessionID: UUID
    public var centerOffsetX: Double
    public var centerOffsetY: Double
    public var densityRadius: Double
    public var spreadH: Double
    public var spreadV: Double
    public var patternLabel: String
    public var confidence: Double
    public var userNote: String
    public var confirmedAt: Date?

    public init(
        reportID: UUID = UUID(),
        sessionID: UUID,
        centerOffsetX: Double,
        centerOffsetY: Double,
        densityRadius: Double,
        spreadH: Double,
        spreadV: Double,
        patternLabel: String,
        confidence: Double,
        userNote: String = "",
        confirmedAt: Date? = nil
    ) {
        self.reportID = reportID
        self.sessionID = sessionID
        self.centerOffsetX = centerOffsetX
        self.centerOffsetY = centerOffsetY
        self.densityRadius = densityRadius
        self.spreadH = spreadH
        self.spreadV = spreadV
        self.patternLabel = patternLabel
        self.confidence = confidence
        self.userNote = userNote
        self.confirmedAt = confirmedAt
    }

    enum CodingKeys: String, CodingKey {
        case reportID = "report_id"
        case sessionID = "session_id"
        case centerOffsetX = "center_offset_x"
        case centerOffsetY = "center_offset_y"
        case densityRadius = "density_radius"
        case spreadH = "spread_h"
        case spreadV = "spread_v"
        case patternLabel = "pattern_label"
        case confidence
        case userNote = "user_note"
        case confirmedAt = "confirmed_at"
    }
}
