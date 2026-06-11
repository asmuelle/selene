import Foundation
@testable import Persistence
import SeleneCore
import Testing

@Suite("SeleneDatabase CRUD")
struct SeleneDatabaseTests {
    private func makeStore() throws -> SeleneDatabase {
        try SeleneDatabase(inMemory: ())
    }

    @Test("daily log round-trips losslessly")
    func dailyLogRoundTrip() throws {
        // Arrange
        let store = try makeStore()
        let log = DailyLog(
            day: DayNumber(20614),
            flow: .medium,
            basalTemperatureCelsius: 36.55,
            sleepQuality: 3,
            mood: 2,
            note: "short note",
            source: .tap
        )

        // Act
        try store.saveDailyLog(log)
        let fetched = try store.dailyLog(on: DayNumber(20614))

        // Assert
        #expect(fetched == log)
    }

    @Test("saving the same log id twice updates instead of duplicating")
    func upsertSemantics() throws {
        // Arrange
        let store = try makeStore()
        let original = DailyLog(day: DayNumber(100), flow: .light)

        // Act
        try store.saveDailyLog(original)
        try store.saveDailyLog(original.with(flow: .heavy))
        let all = try store.dailyLogs()

        // Assert
        #expect(all.count == 1)
        #expect(all[0].flow == .heavy)
    }

    @Test("daily logs come back sorted by day")
    func logsSortedByDay() throws {
        // Arrange
        let store = try makeStore()
        try store.saveDailyLog(DailyLog(day: DayNumber(300), flow: .light))
        try store.saveDailyLog(DailyLog(day: DayNumber(100), flow: .medium))
        try store.saveDailyLog(DailyLog(day: DayNumber(200)))

        // Act
        let days = try store.dailyLogs().map(\.day.value)

        // Assert
        #expect(days == [100, 200, 300])
    }

    @Test("deleting a daily log removes only that log")
    func deleteDailyLog() throws {
        // Arrange
        let store = try makeStore()
        let keep = DailyLog(day: DayNumber(1), flow: .light)
        let drop = DailyLog(day: DayNumber(2), flow: .heavy)
        try store.saveDailyLog(keep)
        try store.saveDailyLog(drop)

        // Act
        try store.deleteDailyLog(id: drop.id)

        // Assert
        #expect(try store.dailyLogs() == [keep])
    }

    @Test("symptom events round-trip with severity and confidence")
    func symptomEventRoundTrip() throws {
        // Arrange
        let store = try makeStore()
        let event = SymptomEvent(
            day: DayNumber(20614),
            code: .nightSweats,
            severity: .strong,
            extractionConfidence: 0.92,
            userConfirmed: true
        )

        // Act
        try store.saveSymptomEvent(event)
        let onDay = try store.symptomEvents(on: DayNumber(20614))
        let all = try store.symptomEvents()

        // Assert
        #expect(onDay == [event])
        #expect(all == [event])
    }

    @Test("deleting a symptom event removes it")
    func deleteSymptomEvent() throws {
        // Arrange
        let store = try makeStore()
        let event = SymptomEvent(day: DayNumber(5), code: .cramps, severity: .mild)
        try store.saveSymptomEvent(event)

        // Act
        try store.deleteSymptomEvent(id: event.id)

        // Assert
        #expect(try store.symptomEvents().isEmpty)
    }

    @Test("profile is a singleton row that round-trips")
    func profileSingleton() throws {
        // Arrange
        let store = try makeStore()
        #expect(try store.loadProfile() == nil)

        // Act
        try store.saveProfile(UserProfile(mode: .perimenopause, typicalCycleLengthPrior: 31))
        try store.saveProfile(UserProfile(mode: .cycle, hasSeenBackupGuidance: true))
        let loaded = try store.loadProfile()

        // Assert: second save replaced the first.
        #expect(loaded == UserProfile(mode: .cycle, hasSeenBackupGuidance: true))
    }

    @Test("latest forecast wins by generation day")
    func latestForecast() throws {
        // Arrange
        let store = try makeStore()
        let older = makeForecast(generatedAtDay: 100)
        let newer = makeForecast(generatedAtDay: 200)
        try store.saveForecast(newer)
        try store.saveForecast(older)

        // Act
        let latest = try store.latestForecast()

        // Assert
        #expect(latest == newer)
    }

    @Test("erase removes every entity")
    func eraseAllContent() throws {
        // Arrange
        let store = try makeStore()
        try store.saveDailyLog(DailyLog(day: DayNumber(1), flow: .light))
        try store.saveSymptomEvent(SymptomEvent(day: DayNumber(1), code: .cramps, severity: .mild))
        try store.saveProfile(UserProfile())
        try store.saveForecast(makeForecast(generatedAtDay: 1))

        // Act
        try store.eraseAllContent()

        // Assert
        #expect(try store.dailyLogs().isEmpty)
        #expect(try store.symptomEvents().isEmpty)
        #expect(try store.loadProfile() == nil)
        #expect(try store.latestForecast() == nil)
    }

    // MARK: - Helpers

    private func makeForecast(generatedAtDay: Int) -> Forecast {
        let window = ForecastWindow(
            medianDay: Double(generatedAtDay) + 28,
            intervals: [CredibleInterval(level: 0.8, lowerDay: 24, upperDay: 32)]
        )
        return Forecast(
            generatedAtDay: DayNumber(generatedAtDay),
            engineVersion: "test-engine",
            mode: .cycle,
            nextPeriod: window,
            ovulation: window,
            posterior: PosteriorSnapshot(mu: 28, kappa: 5, alpha: 4, beta: 30),
            inputRange: DayNumber(0) ... DayNumber(generatedAtDay),
            cycleCount: 3,
            seed: 0
        )
    }
}
