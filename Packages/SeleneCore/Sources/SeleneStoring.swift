import Foundation

/// The storage boundary shared by the app, engine wiring, and tests.
///
/// Lives in SeleneCore (zero dependencies) so business logic depends on this
/// protocol, never on GRDB. `Persistence` provides the encrypted implementation;
/// tests may substitute in-memory fakes.
public protocol SeleneStoring: Sendable {
    // Daily logs
    func saveDailyLog(_ log: DailyLog) throws
    func dailyLogs() throws -> [DailyLog]
    func dailyLog(on day: DayNumber) throws -> DailyLog?
    func deleteDailyLog(id: UUID) throws

    // Symptom events
    func saveSymptomEvent(_ event: SymptomEvent) throws
    func symptomEvents() throws -> [SymptomEvent]
    func symptomEvents(on day: DayNumber) throws -> [SymptomEvent]
    func deleteSymptomEvent(id: UUID) throws

    // Profile (single local row — no accounts, by invariant #6)
    func saveProfile(_ profile: UserProfile) throws
    func loadProfile() throws -> UserProfile?

    // Forecasts (written only by CycleEngine output, invariant #3)
    func saveForecast(_ forecast: Forecast) throws
    func latestForecast() throws -> Forecast?

    /// Explicit local user action: wipe everything. Never networked, never synced.
    func eraseAllContent() throws
}
