import Foundation
import GRDB
import SeleneCore

// MARK: - SeleneStoring conformance

extension SeleneDatabase: SeleneStoring {
    // MARK: Daily logs

    public func saveDailyLog(_ log: DailyLog) throws {
        try write(entity: "daily_log") { db in
            try DailyLogRecord(log).save(db)
        }
    }

    public func dailyLogs() throws -> [DailyLog] {
        try read(entity: "daily_log") { db in
            try DailyLogRecord.order(Column("day")).fetchAll(db)
        }
        .map { try $0.domainValue() }
    }

    public func dailyLog(on day: DayNumber) throws -> DailyLog? {
        try read(entity: "daily_log") { db in
            try DailyLogRecord.filter(Column("day") == day.value).fetchOne(db)
        }
        .map { try $0.domainValue() }
    }

    public func deleteDailyLog(id: UUID) throws {
        try write(entity: "daily_log") { db in
            _ = try DailyLogRecord.deleteOne(db, key: id.uuidString)
        }
    }

    // MARK: Symptom events

    public func saveSymptomEvent(_ event: SymptomEvent) throws {
        try write(entity: "symptom_event") { db in
            try SymptomEventRecord(event).save(db)
        }
    }

    public func symptomEvents() throws -> [SymptomEvent] {
        try read(entity: "symptom_event") { db in
            try SymptomEventRecord.order(Column("day")).fetchAll(db)
        }
        .map { try $0.domainValue() }
    }

    public func symptomEvents(on day: DayNumber) throws -> [SymptomEvent] {
        try read(entity: "symptom_event") { db in
            try SymptomEventRecord.filter(Column("day") == day.value).fetchAll(db)
        }
        .map { try $0.domainValue() }
    }

    public func deleteSymptomEvent(id: UUID) throws {
        try write(entity: "symptom_event") { db in
            _ = try SymptomEventRecord.deleteOne(db, key: id.uuidString)
        }
    }

    // MARK: Profile

    public func saveProfile(_ profile: UserProfile) throws {
        let record = try ProfileRecord(profile)
        try write(entity: "user_profile") { db in
            try record.save(db)
        }
    }

    public func loadProfile() throws -> UserProfile? {
        try read(entity: "user_profile") { db in
            try ProfileRecord.fetchOne(db, key: ProfileRecord.singletonID)
        }
        .map { try $0.domainValue() }
    }

    // MARK: Forecasts

    public func saveForecast(_ forecast: Forecast) throws {
        let record = try ForecastRecord(forecast)
        try write(entity: "forecast") { db in
            try record.save(db)
        }
    }

    public func latestForecast() throws -> Forecast? {
        try read(entity: "forecast") { db in
            try ForecastRecord
                .order(Column("generatedAtDay").desc, Column("id").desc)
                .fetchOne(db)
        }
        .map { try $0.domainValue() }
    }

    // MARK: Erase

    public func eraseAllContent() throws {
        try write(entity: "all") { db in
            _ = try DailyLogRecord.deleteAll(db)
            _ = try SymptomEventRecord.deleteAll(db)
            _ = try ForecastRecord.deleteAll(db)
            _ = try ProfileRecord.deleteAll(db)
        }
    }

    // MARK: - Error-wrapping helpers

    private func read<T>(entity: String, _ body: (Database) throws -> T) throws -> T {
        do {
            return try queue.read(body)
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.readFailed(entity: entity, underlying: String(describing: error))
        }
    }

    private func write<T>(entity: String, _ body: (Database) throws -> T) throws -> T {
        do {
            return try queue.write(body)
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.writeFailed(entity: entity, underlying: String(describing: error))
        }
    }
}
