import CycleEngine
import Foundation
import SeleneCore

/// A forecast window row carried into the document, preserving the engine's
/// credible levels and bounds VERBATIM. The doctor-visit summary must display
/// the engine's interval bounds unchanged (golden test) — no re-rounding, no
/// re-derivation (invariant #3).
public struct DocumentForecastInterval: Hashable, Sendable {
    public let level: Double
    public let lowerDay: Double
    public let upperDay: Double

    public init(level: Double, lowerDay: Double, upperDay: Double) {
        self.level = level
        self.lowerDay = lowerDay
        self.upperDay = upperDay
    }

    init(_ interval: CredibleInterval) {
        level = interval.level
        lowerDay = interval.lowerDay
        upperDay = interval.upperDay
    }
}

/// A predicted-window section of the document (next period / ovulation).
public struct DocumentForecastWindow: Hashable, Sendable {
    public let title: String
    public let medianDay: Double
    public let intervals: [DocumentForecastInterval]

    public init(title: String, medianDay: Double, intervals: [DocumentForecastInterval]) {
        self.title = title
        self.medianDay = medianDay
        self.intervals = intervals
    }
}

/// Deterministic cycle statistics over the included history.
public struct DocumentCycleStats: Hashable, Sendable {
    public let cycleCount: Int
    public let meanLengthDays: Double?
    public let shortestLengthDays: Int?
    public let longestLengthDays: Int?

    public init(
        cycleCount: Int,
        meanLengthDays: Double?,
        shortestLengthDays: Int?,
        longestLengthDays: Int?
    ) {
        self.cycleCount = cycleCount
        self.meanLengthDays = meanLengthDays
        self.shortestLengthDays = shortestLengthDays
        self.longestLengthDays = longestLengthDays
    }
}

/// A pure, render-agnostic doctor-visit summary.
///
/// Assembled ONLY from logged data in the store + `CycleEngine` outputs — no LLM
/// is required for the document structure (the optional prose summary is a
/// separate, citation-tagged layer). Every value here traces to the store or the
/// engine; nothing is fabricated (invariant #3). Pack references are pinned via
/// `citations` (invariant #4).
public struct DoctorVisitDocument: Hashable, Sendable {
    public let dateRange: ClosedRange<DayNumber>
    public let generatedAtDay: DayNumber
    public let stats: DocumentCycleStats
    public let symptomClusters: [SymptomClusterRow]
    public let forecastWindows: [DocumentForecastWindow]
    public let engineVersion: String?
    /// Pinned pack references for the standing template copy (e.g. the
    /// "estimates are ranges" and clinician-handoff passages).
    public let citations: [Citation]

    public init(
        dateRange: ClosedRange<DayNumber>,
        generatedAtDay: DayNumber,
        stats: DocumentCycleStats,
        symptomClusters: [SymptomClusterRow],
        forecastWindows: [DocumentForecastWindow],
        engineVersion: String?,
        citations: [Citation]
    ) {
        self.dateRange = dateRange
        self.generatedAtDay = generatedAtDay
        self.stats = stats
        self.symptomClusters = symptomClusters
        self.forecastWindows = forecastWindows
        self.engineVersion = engineVersion
        self.citations = citations
    }
}
