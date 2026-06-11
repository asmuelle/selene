import Foundation
import GRDB
import SeleneCore

// GRDB row mappings, kept separate from the domain types so SeleneCore stays
// dependency-free. Enum raw values are validated on read — a corrupt row throws
// instead of silently producing wrong health data.

struct DailyLogRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "daily_log"

    var id: String
    var day: Int
    var flow: String?
    var basalTemperatureCelsius: Double?
    var sleepQuality: Int?
    var mood: Int?
    var note: String?
    var source: String

    init(_ log: DailyLog) {
        id = log.id.uuidString
        day = log.day.value
        flow = log.flow?.rawValue
        basalTemperatureCelsius = log.basalTemperatureCelsius
        sleepQuality = log.sleepQuality
        mood = log.mood
        note = log.note
        source = log.source.rawValue
    }

    func domainValue() throws(PersistenceError) -> DailyLog {
        guard let uuid = UUID(uuidString: id) else {
            throw .corruptRow(entity: "daily_log", detail: "invalid id")
        }
        guard let entrySource = EntrySource(rawValue: source) else {
            throw .corruptRow(entity: "daily_log", detail: "invalid source")
        }
        var flowLevel: FlowLevel?
        if let raw = flow {
            guard let level = FlowLevel(rawValue: raw) else {
                throw .corruptRow(entity: "daily_log", detail: "invalid flow")
            }
            flowLevel = level
        }
        return DailyLog(
            id: uuid,
            day: DayNumber(day),
            flow: flowLevel,
            basalTemperatureCelsius: basalTemperatureCelsius,
            sleepQuality: sleepQuality,
            mood: mood,
            note: note,
            source: entrySource
        )
    }
}

struct SymptomEventRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "symptom_event"

    var id: String
    var day: Int
    var code: String
    var severity: Int
    var extractionConfidence: Double?
    var userConfirmed: Bool

    init(_ event: SymptomEvent) {
        id = event.id.uuidString
        day = event.day.value
        code = event.code.rawValue
        severity = event.severity.value
        extractionConfidence = event.extractionConfidence
        userConfirmed = event.userConfirmed
    }

    func domainValue() throws(PersistenceError) -> SymptomEvent {
        guard let uuid = UUID(uuidString: id) else {
            throw .corruptRow(entity: "symptom_event", detail: "invalid id")
        }
        guard let symptomCode = SymptomCode(rawValue: code) else {
            throw .corruptRow(entity: "symptom_event", detail: "unknown symptom code")
        }
        guard let severityValue = Severity(severity) else {
            throw .corruptRow(entity: "symptom_event", detail: "severity out of range")
        }
        return SymptomEvent(
            id: uuid,
            day: DayNumber(day),
            code: symptomCode,
            severity: severityValue,
            extractionConfidence: extractionConfidence,
            userConfirmed: userConfirmed
        )
    }
}

/// Forecasts and the profile are stored as JSON payloads — they are engine
/// snapshots, not query targets, and JSON keeps their nested structure lossless.
struct ForecastRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "forecast"

    var id: String
    var generatedAtDay: Int
    var payload: Data

    init(_ forecast: Forecast) throws(PersistenceError) {
        id = forecast.id.uuidString
        generatedAtDay = forecast.generatedAtDay.value
        do {
            payload = try Self.encoder.encode(forecast)
        } catch {
            throw .writeFailed(entity: "forecast", underlying: String(describing: error))
        }
    }

    func domainValue() throws(PersistenceError) -> Forecast {
        do {
            return try JSONDecoder().decode(Forecast.self, from: payload)
        } catch {
            throw .corruptRow(entity: "forecast", detail: "payload decode failed")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()
}

struct ProfileRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_profile"
    static let singletonID = 1

    var id: Int
    var payload: Data

    init(_ profile: UserProfile) throws(PersistenceError) {
        id = Self.singletonID
        do {
            payload = try JSONEncoder().encode(profile)
        } catch {
            throw .writeFailed(entity: "user_profile", underlying: String(describing: error))
        }
    }

    func domainValue() throws(PersistenceError) -> UserProfile {
        do {
            return try JSONDecoder().decode(UserProfile.self, from: payload)
        } catch {
            throw .corruptRow(entity: "user_profile", detail: "payload decode failed")
        }
    }
}
