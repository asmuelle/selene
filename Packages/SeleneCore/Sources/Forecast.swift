import Foundation

/// A symmetric credible interval around a predicted day, in fractional days
/// relative to the same epoch as `DayNumber`.
public struct CredibleInterval: Hashable, Codable, Sendable {
    /// Probability mass covered, e.g. 0.5, 0.8, 0.95.
    public let level: Double
    public let lowerDay: Double
    public let upperDay: Double

    public init(level: Double, lowerDay: Double, upperDay: Double) {
        self.level = level
        self.lowerDay = lowerDay
        self.upperDay = upperDay
    }

    public var widthDays: Double {
        upperDay - lowerDay
    }

    /// Whole-day bounds for calendar rendering (conservative: floor/ceil).
    public var dayRange: ClosedRange<DayNumber> {
        DayNumber(Int(lowerDay.rounded(.down))) ... DayNumber(Int(upperDay.rounded(.up)))
    }
}

/// A predicted event window: the posterior median plus nested credible intervals.
public struct ForecastWindow: Hashable, Codable, Sendable {
    public let medianDay: Double
    /// Sorted ascending by level; levels are unique.
    public let intervals: [CredibleInterval]

    public init(medianDay: Double, intervals: [CredibleInterval]) {
        self.medianDay = medianDay
        self.intervals = intervals.sorted { $0.level < $1.level }
    }

    public func interval(at level: Double) -> CredibleInterval? {
        intervals.first { abs($0.level - level) < 1e-9 }
    }

    public var medianDayNumber: DayNumber {
        DayNumber(Int(medianDay.rounded()))
    }
}

/// Posterior parameters of the Normal-Inverse-Gamma cycle-length model,
/// snapshotted for reproducibility and audit.
public struct PosteriorSnapshot: Hashable, Codable, Sendable {
    public let mu: Double
    public let kappa: Double
    public let alpha: Double
    public let beta: Double

    public init(mu: Double, kappa: Double, alpha: Double, beta: Double) {
        self.mu = mu
        self.kappa = kappa
        self.alpha = alpha
        self.beta = beta
    }
}

/// A cycle forecast. Written ONLY by `CycleEngine` (invariant #3: deterministic before
/// LLM — every date and probability in the product originates here).
public struct Forecast: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let generatedAtDay: DayNumber
    public let engineVersion: String
    public let mode: TrackingMode
    public let nextPeriod: ForecastWindow
    public let ovulation: ForecastWindow
    public let posterior: PosteriorSnapshot
    /// First and last cycle-start day that informed this forecast (nil when prior-only).
    public let inputRange: ClosedRange<DayNumber>?
    public let cycleCount: Int
    public let seed: UInt64

    public init(
        id: UUID = UUID(),
        generatedAtDay: DayNumber,
        engineVersion: String,
        mode: TrackingMode,
        nextPeriod: ForecastWindow,
        ovulation: ForecastWindow,
        posterior: PosteriorSnapshot,
        inputRange: ClosedRange<DayNumber>?,
        cycleCount: Int,
        seed: UInt64
    ) {
        self.id = id
        self.generatedAtDay = generatedAtDay
        self.engineVersion = engineVersion
        self.mode = mode
        self.nextPeriod = nextPeriod
        self.ovulation = ovulation
        self.posterior = posterior
        self.inputRange = inputRange
        self.cycleCount = cycleCount
        self.seed = seed
    }
}
