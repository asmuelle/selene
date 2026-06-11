import Foundation

/// Menstrual flow level for a logged day.
public enum FlowLevel: String, CaseIterable, Codable, Sendable {
    case spotting
    case light
    case medium
    case heavy

    /// Flow that counts as a period day (spotting alone does not start a cycle).
    public var isPeriodFlow: Bool {
        self != .spotting
    }

    public var label: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

/// How an entry got into the store.
public enum EntrySource: String, Codable, Sendable {
    case tap
    case text
    case voice
    case strip
}

/// One logged day. Everything optional except the day itself — partial logs are normal.
public struct DailyLog: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let day: DayNumber
    public let flow: FlowLevel?
    public let basalTemperatureCelsius: Double?
    public let sleepQuality: Int?
    public let mood: Int?
    public let note: String?
    public let source: EntrySource

    public init(
        id: UUID = UUID(),
        day: DayNumber,
        flow: FlowLevel? = nil,
        basalTemperatureCelsius: Double? = nil,
        sleepQuality: Int? = nil,
        mood: Int? = nil,
        note: String? = nil,
        source: EntrySource = .tap
    ) {
        self.id = id
        self.day = day
        self.flow = flow
        self.basalTemperatureCelsius = basalTemperatureCelsius
        self.sleepQuality = sleepQuality
        self.mood = mood
        self.note = note
        self.source = source
    }

    /// Returns a copy with the flow replaced — immutably, per coding standards.
    public func with(flow newFlow: FlowLevel?) -> DailyLog {
        DailyLog(
            id: id, day: day, flow: newFlow,
            basalTemperatureCelsius: basalTemperatureCelsius,
            sleepQuality: sleepQuality, mood: mood, note: note, source: source
        )
    }
}

/// A symptom occurrence on a given day.
public struct SymptomEvent: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let day: DayNumber
    public let code: SymptomCode
    public let severity: Severity
    public let extractionConfidence: Double?
    public let userConfirmed: Bool

    public init(
        id: UUID = UUID(),
        day: DayNumber,
        code: SymptomCode,
        severity: Severity,
        extractionConfidence: Double? = nil,
        userConfirmed: Bool = true
    ) {
        self.id = id
        self.day = day
        self.code = code
        self.severity = severity
        self.extractionConfidence = extractionConfidence
        self.userConfirmed = userConfirmed
    }
}

/// How a cycle boundary was established.
public enum CycleSource: String, Codable, Sendable {
    case logged
    case inferred
}

/// One menstrual cycle. `endDay` is nil while the cycle is open.
public struct Cycle: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let startDay: DayNumber
    public let endDay: DayNumber?
    public let source: CycleSource
    public let isAnomalous: Bool

    public init(
        id: UUID = UUID(),
        startDay: DayNumber,
        endDay: DayNumber? = nil,
        source: CycleSource = .logged,
        isAnomalous: Bool = false
    ) {
        self.id = id
        self.startDay = startDay
        self.endDay = endDay
        self.source = source
        self.isAnomalous = isAnomalous
    }

    /// Cycle length in days (start of this cycle to start of the next), if closed.
    public var length: Int? {
        endDay.map { startDay.distance(to: $0) }
    }
}

/// Tracking mode — drives priors, copy, and which surfaces lead.
public enum TrackingMode: String, CaseIterable, Codable, Sendable {
    case cycle
    case tryingToConceive
    case perimenopause
}

/// Local-only profile. No name, no email, no account id — by invariant #6.
public struct UserProfile: Hashable, Codable, Sendable {
    public let mode: TrackingMode
    public let typicalCycleLengthPrior: Double?
    public let hasSeenBackupGuidance: Bool

    public init(
        mode: TrackingMode = .cycle,
        typicalCycleLengthPrior: Double? = nil,
        hasSeenBackupGuidance: Bool = false
    ) {
        self.mode = mode
        self.typicalCycleLengthPrior = typicalCycleLengthPrior
        self.hasSeenBackupGuidance = hasSeenBackupGuidance
    }
}
