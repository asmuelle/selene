import SeleneCore

/// Presentation of a forecast window's credible intervals for the UI layer.
///
/// Forecast-trust contract (invariant #3): every bound shown to the user is the
/// engine's own `CredibleInterval.dayRange` — presentation code never recomputes,
/// widens, narrows, or "rounds for friendliness". The only transformation here
/// is wording; the numbers pass through bit-exact.
public struct ForecastIntervalPresentation: Hashable, Sendable {
    public struct Row: Hashable, Sendable, Identifiable {
        /// The engine's probability level, untouched (0.5 / 0.8 / 0.95).
        public let level: Double
        public let levelLabel: String
        /// Exactly `interval.dayRange.lowerBound` / `.upperBound` from the engine.
        public let lowerDay: DayNumber
        public let upperDay: DayNumber
        /// Whole-day offsets of those same bounds relative to today.
        public let lowerOffsetDays: Int
        public let upperOffsetDays: Int
        /// User-facing wording derived only from the offsets above.
        public let text: String

        public var id: Double {
            level
        }
    }

    /// The engine's posterior median day, untouched.
    public let medianDay: DayNumber
    /// One row per engine interval, narrowest level first.
    public let rows: [Row]

    public init(window: ForecastWindow, today: DayNumber) {
        medianDay = window.medianDayNumber
        rows = window.intervals.map { interval in
            let range = interval.dayRange
            let lower = range.lowerBound.value - today.value
            let upper = range.upperBound.value - today.value
            return Row(
                level: interval.level,
                levelLabel: "\(Int((interval.level * 100).rounded()))%",
                lowerDay: range.lowerBound,
                upperDay: range.upperBound,
                lowerOffsetDays: lower,
                upperOffsetDays: upper,
                text: Self.phrase(lowerOffset: lower, upperOffset: upper)
            )
        }
    }

    public func row(at level: Double) -> Row? {
        rows.first { abs($0.level - level) < 1e-9 }
    }

    /// Deterministic wording over the engine's whole-day offsets. No arithmetic
    /// beyond sign handling — the bounds themselves are never altered.
    static func phrase(lowerOffset: Int, upperOffset: Int) -> String {
        switch (lowerOffset, upperOffset) {
        case (0, 0):
            "today"
        case let (lower, upper) where lower > 0:
            lower == upper ? "in \(dayCount(lower))" : "in \(lower)–\(upper) days"
        case let (lower, upper) where upper < 0:
            lower == upper ? "\(dayCount(-lower)) ago" : "\(-upper)–\(-lower) days ago"
        case let (0, upper):
            "today – in \(dayCount(upper))"
        case let (lower, 0):
            "\(dayCount(-lower)) ago – today"
        case let (lower, upper):
            "\(dayCount(-lower)) ago – in \(dayCount(upper))"
        }
    }

    private static func dayCount(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }
}
