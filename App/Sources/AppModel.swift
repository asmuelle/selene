import CycleEngine
import Foundation
import InsightKit
import Observation
import SeleneCore
import SeleneUI

/// Composition-root view model for the M1 vertical slice:
/// tap-log → encrypted store → CycleEngine forecast → cycle wheel.
///
/// Every number on screen comes from `CycleEngine` (invariant #3); narration is
/// the deterministic `TemplateNarrator` — no LLM in M1.
@MainActor
@Observable
final class AppModel {
    private let store: any SeleneStoring
    private let narrator: any InsightNarrating
    private let todayProvider: @Sendable () -> DayNumber
    private let storageLocation: DataInventory.StorageLocation

    private(set) var profile = UserProfile()
    private(set) var logs: [DailyLog] = []
    private(set) var todaySymptoms: [SymptomEvent] = []
    private(set) var totalSymptomCount = 0
    private(set) var cycles: [Cycle] = []
    private(set) var forecast: Forecast?
    private(set) var narration: String?
    private(set) var errorMessage: String?

    /// Latest detected cycle start — the wheel's day-zero.
    var anchorDay: DayNumber? {
        cycles.map(\.startDay).max()
    }

    var today: DayNumber {
        todayProvider()
    }

    var todayLog: DailyLog? {
        logs.first { $0.day == today }
    }

    /// Inputs for the privacy-proof screen — exact counts, honest storage kind.
    var dataInventory: DataInventory {
        DataInventory(
            dailyLogCount: logs.count,
            symptomEventCount: totalSymptomCount,
            hasForecast: forecast != nil,
            storage: storageLocation
        )
    }

    /// Credible-interval readout: the engine's own bounds, passed through
    /// `ForecastIntervalPresentation` (which never alters them — invariant #3).
    var intervalPresentation: ForecastIntervalPresentation? {
        forecast.map { ForecastIntervalPresentation(window: $0.nextPeriod, today: today) }
    }

    init(
        store: any SeleneStoring,
        narrator: any InsightNarrating = TemplateNarrator(),
        todayProvider: @escaping @Sendable () -> DayNumber = { DayNumber(date: Date()) },
        storageLocation: DataInventory.StorageLocation = .onDeviceEncrypted
    ) {
        self.store = store
        self.narrator = narrator
        self.todayProvider = todayProvider
        self.storageLocation = storageLocation
    }

    /// Loads persisted state and recomputes the forecast from the full log history.
    func refresh() {
        do {
            profile = try store.loadProfile() ?? UserProfile()
            logs = try store.dailyLogs()
            todaySymptoms = try store.symptomEvents(on: today)
            totalSymptomCount = try store.symptomEvents().count
            try recomputeForecast()
            errorMessage = nil
        } catch {
            errorMessage = "Selene couldn't read your local data. Nothing was lost — try again."
        }
    }

    /// Upserts today's flow level (nil clears it) and recomputes the forecast.
    func logFlow(_ level: FlowLevel?) {
        do {
            let updated = todayLog?.with(flow: level)
                ?? DailyLog(day: today, flow: level, source: .tap)
            try store.saveDailyLog(updated)
            logs = try store.dailyLogs()
            try recomputeForecast()
            errorMessage = nil
        } catch {
            errorMessage = "Selene couldn't save that entry. Your earlier data is untouched."
        }
    }

    /// Toggles a symptom for today (logged at moderate severity, user-confirmed).
    func toggleSymptom(_ code: SymptomCode) {
        do {
            if let existing = todaySymptoms.first(where: { $0.code == code }) {
                try store.deleteSymptomEvent(id: existing.id)
            } else {
                let event = SymptomEvent(
                    day: today, code: code, severity: .moderate, userConfirmed: true
                )
                try store.saveSymptomEvent(event)
            }
            todaySymptoms = try store.symptomEvents(on: today)
            totalSymptomCount = try store.symptomEvents().count
            errorMessage = nil
        } catch {
            errorMessage = "Selene couldn't update that symptom. Your earlier data is untouched."
        }
    }

    func isSymptomLogged(_ code: SymptomCode) -> Bool {
        todaySymptoms.contains { $0.code == code }
    }

    // MARK: - Engine wiring

    /// Deterministic pipeline: logs → CycleDetector → BayesianForecaster → store.
    private func recomputeForecast() throws {
        cycles = CycleDetector.detectCycles(from: logs)
        do {
            let fresh = try BayesianForecaster.forecast(
                cycles: cycles, profile: profile, today: today
            )
            try store.saveForecast(fresh)
            forecast = fresh
            narration = narrator.narrate(fresh, today: today)
        } catch ForecastError.noCycleHistory {
            forecast = nil
            narration = nil
        }
    }
}
