import CycleEngine
@testable import DoctorVisit
import Foundation
import SeleneCore
import Testing

/// In-memory store fake so the assembler tests need no GRDB/Persistence.
private final class FakeStore: SeleneStoring, @unchecked Sendable {
    // @unchecked: tests are single-threaded; this fake holds plain arrays.
    var logs: [DailyLog] = []
    var events: [SymptomEvent] = []
    var profile: UserProfile?
    var forecast: Forecast?

    func saveDailyLog(_ log: DailyLog) throws {
        logs.append(log)
    }

    func dailyLogs() throws -> [DailyLog] {
        logs
    }

    func dailyLog(on day: DayNumber) throws -> DailyLog? {
        logs.first { $0.day == day }
    }

    func deleteDailyLog(id: UUID) throws {
        logs.removeAll { $0.id == id }
    }

    func saveSymptomEvent(_ event: SymptomEvent) throws {
        events.append(event)
    }

    func symptomEvents() throws -> [SymptomEvent] {
        events
    }

    func symptomEvents(on day: DayNumber) throws -> [SymptomEvent] {
        events.filter { $0.day == day }
    }

    func deleteSymptomEvent(id: UUID) throws {
        events.removeAll { $0.id == id }
    }

    func saveProfile(_ profile: UserProfile) throws {
        self.profile = profile
    }

    func loadProfile() throws -> UserProfile? {
        profile
    }

    func saveForecast(_ forecast: Forecast) throws {
        self.forecast = forecast
    }

    func latestForecast() throws -> Forecast? {
        forecast
    }

    func eraseAllContent() throws {
        logs = []; events = []; profile = nil; forecast = nil
    }
}

@Suite("Doctor-visit document")
struct DoctorVisitDocumentTests {
    /// Builds a store with three 28-day cycles of flow + symptoms, plus the
    /// engine's own forecast saved into it.
    private func seededStore(today: DayNumber) throws -> (FakeStore, Forecast) {
        let store = FakeStore()
        for cycleIndex in 0 ..< 3 {
            let start = DayNumber(20340 + 28 * cycleIndex)
            for offset in 0 ..< 4 {
                try store.saveDailyLog(DailyLog(
                    day: start.advanced(by: offset),
                    flow: offset == 0 ? .heavy : .medium
                ))
            }
            try store.saveSymptomEvent(SymptomEvent(
                day: start.advanced(by: 1), code: .nightSweats, severity: .moderate
            ))
            try store.saveSymptomEvent(SymptomEvent(
                day: start.advanced(by: 2), code: .hotFlashes, severity: .strong
            ))
        }
        let cycles = try CycleDetector.detectCycles(from: store.dailyLogs())
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles, profile: UserProfile(mode: .perimenopause), today: today
        )
        try store.saveForecast(forecast)
        return (store, forecast)
    }

    @Test("document forecast intervals equal the engine bounds verbatim (golden)")
    func intervalsEqualEngineBounds() throws {
        // Arrange
        let today = DayNumber(20454)
        let (store, forecast) = try seededStore(today: today)
        let range = DayNumber(20340) ... DayNumber(20454)

        // Act
        let document = try DoctorVisitAssembler(store: store).makeDocument(
            range: range, generatedAtDay: today, isEntitled: true
        )

        // Assert: every displayed interval bound is the engine's, unchanged.
        let periodSection = try #require(document.forecastWindows.first)
        #expect(periodSection.medianDay == forecast.nextPeriod.medianDay)
        #expect(periodSection.intervals.count == forecast.nextPeriod.intervals.count)
        for (rendered, engine) in zip(periodSection.intervals, forecast.nextPeriod.intervals) {
            #expect(rendered.level == engine.level)
            #expect(rendered.lowerDay == engine.lowerDay)
            #expect(rendered.upperDay == engine.upperDay)
        }
    }

    @Test("the 50/80/95 credible levels are all carried into the document")
    func allCredibleLevelsCarried() throws {
        let today = DayNumber(20454)
        let (store, _) = try seededStore(today: today)
        let document = try DoctorVisitAssembler(store: store).makeDocument(
            range: DayNumber(20340) ... today, generatedAtDay: today, isEntitled: true
        )
        let levels = Set(document.forecastWindows.first?.intervals.map(\.level) ?? [])
        #expect(levels == [0.5, 0.8, 0.95])
    }

    @Test("symptom cluster table aggregates only logged events in range")
    func clustersFromLoggedEventsOnly() throws {
        let today = DayNumber(20454)
        let (store, _) = try seededStore(today: today)
        let document = try DoctorVisitAssembler(store: store).makeDocument(
            range: DayNumber(20340) ... today, generatedAtDay: today, isEntitled: true
        )
        let codes = Set(document.symptomClusters.map(\.code))
        #expect(codes == [.nightSweats, .hotFlashes])
        // Each symptom logged once per cycle, three cycles.
        let nightSweats = try #require(document.symptomClusters.first { $0.code == .nightSweats })
        #expect(nightSweats.dayCount == 3)
    }

    @Test("cycle stats summarise complete cycles in range deterministically")
    func cycleStatsDeterministic() throws {
        let today = DayNumber(20454)
        let (store, _) = try seededStore(today: today)
        let document = try DoctorVisitAssembler(store: store).makeDocument(
            range: DayNumber(20340) ... today, generatedAtDay: today, isEntitled: true
        )
        // Three 28-day cycle starts → two closed cycles of length 28.
        #expect(document.stats.cycleCount == 2)
        #expect(document.stats.meanLengthDays == 28)
        #expect(document.stats.shortestLengthDays == 28)
        #expect(document.stats.longestLengthDays == 28)
    }

    @Test("identical store + range produce an identical document")
    func deterministicAssembly() throws {
        let today = DayNumber(20454)
        let (storeA, _) = try seededStore(today: today)
        let (storeB, _) = try seededStore(today: today)
        let range = DayNumber(20340) ... today
        let docA = try DoctorVisitAssembler(store: storeA).makeDocument(
            range: range, generatedAtDay: today, isEntitled: true
        )
        let docB = try DoctorVisitAssembler(store: storeB).makeDocument(
            range: range, generatedAtDay: today, isEntitled: true
        )
        #expect(docA == docB)
    }

    @Test("no document assembles without the entitlement (gate enforcement)")
    func gateEnforced() throws {
        let today = DayNumber(20454)
        let (store, _) = try seededStore(today: today)
        #expect(throws: DoctorVisitError.notEntitled) {
            try DoctorVisitAssembler(store: store).makeDocument(
                range: DayNumber(20340) ... today, generatedAtDay: today, isEntitled: false
            )
        }
    }

    @Test("an empty store yields a valid, empty-noted document")
    func emptyStoreDocument() throws {
        let store = FakeStore()
        let today = DayNumber(20454)
        let document = try DoctorVisitAssembler(store: store).makeDocument(
            range: DayNumber(20340) ... today, generatedAtDay: today, isEntitled: true
        )
        #expect(document.stats.cycleCount == 0)
        #expect(document.symptomClusters.isEmpty)
        #expect(document.forecastWindows.isEmpty)
    }
}
