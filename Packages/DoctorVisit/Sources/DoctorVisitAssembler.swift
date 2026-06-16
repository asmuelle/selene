import CycleEngine
import SeleneCore

/// Errors assembling a doctor-visit document.
public enum DoctorVisitError: Error, Equatable, Sendable {
    /// The `.doctorVisitSummary` feature is not entitled — the document never
    /// assembles or renders without the paywall unlock (invariant #7 gates the
    /// AI layer; this is one of those surfaces).
    case notEntitled
    /// The requested range is empty/inverted.
    case invalidRange
}

/// Assembles a `DoctorVisitDocument` from the store + engine outputs only.
///
/// Deterministic: identical store contents + range produce an identical
/// document. The forecast intervals carried into the document equal the engine's
/// bounds verbatim (golden test). No LLM is involved in the document structure.
public struct DoctorVisitAssembler: Sendable {
    private let store: any SeleneStoring

    public init(store: any SeleneStoring) {
        self.store = store
    }

    /// Builds the document for `range`, gated by `isEntitled`.
    ///
    /// - Parameters:
    ///   - range: inclusive day range to include.
    ///   - generatedAtDay: the day the summary was prepared (recorded only).
    ///   - isEntitled: the caller's `.doctorVisitSummary` gate decision. When
    ///     false the assembler throws `.notEntitled` and produces nothing.
    public func makeDocument(
        range: ClosedRange<DayNumber>,
        generatedAtDay: DayNumber,
        isEntitled: Bool
    ) throws -> DoctorVisitDocument {
        guard isEntitled else {
            throw DoctorVisitError.notEntitled
        }

        let logs = try store.dailyLogs()
        let events = try store.symptomEvents()
        let cycles = CycleDetector.detectCycles(from: logs)

        let stats = cycleStats(cycles: cycles, range: range)
        let clusters = SymptomClusterAnalyzer.clusters(from: events, in: range)
        let forecastWindows = forecastWindows()
        let forecast = try? store.latestForecast()

        return DoctorVisitDocument(
            dateRange: range,
            generatedAtDay: generatedAtDay,
            stats: stats,
            symptomClusters: clusters,
            forecastWindows: forecastWindows,
            engineVersion: forecast?.engineVersion,
            citations: DoctorVisitCopy.standingCitations
        )
    }

    // MARK: - Private

    /// Closed cycles whose start falls within range, summarised. Only logged,
    /// closed cycles (which have a length) contribute statistics.
    private func cycleStats(
        cycles: [Cycle],
        range: ClosedRange<DayNumber>
    ) -> DocumentCycleStats {
        let lengths = cycles
            .filter { range.contains($0.startDay) }
            .compactMap(\.length)
        guard !lengths.isEmpty else {
            return DocumentCycleStats(
                cycleCount: 0, meanLengthDays: nil,
                shortestLengthDays: nil, longestLengthDays: nil
            )
        }
        let mean = Double(lengths.reduce(0, +)) / Double(lengths.count)
        return DocumentCycleStats(
            cycleCount: lengths.count,
            meanLengthDays: mean,
            shortestLengthDays: lengths.min(),
            longestLengthDays: lengths.max()
        )
    }

    /// Carries the latest engine forecast's windows into the document with their
    /// credible-interval bounds unchanged. Returns [] when no forecast exists.
    private func forecastWindows() -> [DocumentForecastWindow] {
        guard let forecast = try? store.latestForecast() else {
            return []
        }
        return [
            window(from: forecast.nextPeriod, title: DoctorVisitCopy.nextPeriodTitle),
            window(from: forecast.ovulation, title: DoctorVisitCopy.ovulationTitle),
        ]
    }

    private func window(from window: ForecastWindow, title: String) -> DocumentForecastWindow {
        DocumentForecastWindow(
            title: title,
            medianDay: window.medianDay,
            intervals: window.intervals.map(DocumentForecastInterval.init)
        )
    }
}
