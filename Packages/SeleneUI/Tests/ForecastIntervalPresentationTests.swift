import CycleEngine
import SeleneCore
@testable import SeleneUI
import Testing

/// Forecast-trust golden contract (invariant #3): the interval the user sees is
/// the engine's interval — presentation must pass every bound through exactly,
/// never widening, narrowing, or re-deriving it.
@Suite("Forecast interval presentation — golden pass-through")
struct ForecastIntervalPresentationTests {
    /// The three canonical synthetic situations from the engine's golden suite.
    static let scenarios: [(name: String, mode: TrackingMode, lengths: [Int])] = [
        ("regular", .cycle, [28, 28, 29, 28, 27, 28]),
        ("irregular", .cycle, [26, 35, 22, 31, 24, 33]),
        ("perimenopausal", .perimenopause, [24, 38, 21, 45, 28, 35]),
    ]

    private static func cycles(startingAt firstStart: Int, lengths: [Int]) -> [Cycle] {
        var start = firstStart
        return lengths.map { length in
            defer { start += length }
            return Cycle(
                startDay: DayNumber(start), endDay: DayNumber(start + length)
            )
        }
    }

    @Test(
        "every displayed bound equals the engine's interval bound, both windows",
        arguments: scenarios.indices
    )
    func displayedBoundsMatchEngine(scenarioIndex: Int) throws {
        // Arrange
        let scenario = Self.scenarios[scenarioIndex]
        let cycles = Self.cycles(startingAt: 20300, lengths: scenario.lengths)
        let today = DayNumber(20300 + scenario.lengths.reduce(0, +) + 10)
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles,
            profile: UserProfile(mode: scenario.mode),
            today: today
        )

        for window in [forecast.nextPeriod, forecast.ovulation] {
            // Act
            let presentation = ForecastIntervalPresentation(window: window, today: today)

            // Assert — exact pass-through of every engine number.
            #expect(presentation.medianDay == window.medianDayNumber)
            #expect(presentation.rows.count == window.intervals.count)
            for interval in window.intervals {
                let row = try #require(
                    presentation.row(at: interval.level),
                    "\(scenario.name): missing row for level \(interval.level)"
                )
                #expect(row.lowerDay == interval.dayRange.lowerBound)
                #expect(row.upperDay == interval.dayRange.upperBound)
                #expect(row.level == interval.level)
                #expect(row.lowerOffsetDays == interval.dayRange.lowerBound.value - today.value)
                #expect(row.upperOffsetDays == interval.dayRange.upperBound.value - today.value)
            }
        }
    }

    @Test("fractional engine bounds pass through the engine's own day rounding, unaltered")
    func fractionalBoundsNotRedrived() {
        // Arrange: a window with awkward fractional bounds.
        let interval = CredibleInterval(level: 0.8, lowerDay: 20603.21, upperDay: 20611.97)
        let window = ForecastWindow(medianDay: 20607.5, intervals: [interval])

        // Act
        let presentation = ForecastIntervalPresentation(window: window, today: DayNumber(20600))

        // Assert: bounds equal the engine's dayRange (its floor/ceil rule) —
        // presentation adds no rounding rule of its own.
        let row = presentation.rows[0]
        #expect(row.lowerDay == interval.dayRange.lowerBound)
        #expect(row.upperDay == interval.dayRange.upperBound)
        #expect(row.lowerDay == DayNumber(20603))
        #expect(row.upperDay == DayNumber(20612))
    }

    @Test("levels are rendered as the engine's percentages, all three")
    func levelLabels() throws {
        let cycles = Self.cycles(startingAt: 20300, lengths: [28, 28, 28])
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles, profile: UserProfile(), today: DayNumber(20395)
        )
        let presentation = ForecastIntervalPresentation(
            window: forecast.nextPeriod, today: DayNumber(20395)
        )
        #expect(presentation.rows.map(\.levelLabel) == ["50%", "80%", "95%"])
    }

    @Test("wording derives only from the engine offsets")
    func phraseGoldens() {
        #expect(ForecastIntervalPresentation.phrase(lowerOffset: 3, upperOffset: 7) == "in 3–7 days")
        #expect(ForecastIntervalPresentation.phrase(lowerOffset: 4, upperOffset: 4) == "in 4 days")
        #expect(ForecastIntervalPresentation.phrase(lowerOffset: 1, upperOffset: 1) == "in 1 day")
        #expect(ForecastIntervalPresentation.phrase(lowerOffset: 0, upperOffset: 0) == "today")
        #expect(
            ForecastIntervalPresentation.phrase(lowerOffset: 0, upperOffset: 4)
                == "today – in 4 days"
        )
        #expect(
            ForecastIntervalPresentation.phrase(lowerOffset: -2, upperOffset: 0)
                == "2 days ago – today"
        )
        #expect(
            ForecastIntervalPresentation.phrase(lowerOffset: -2, upperOffset: 1)
                == "2 days ago – in 1 day"
        )
        #expect(
            ForecastIntervalPresentation.phrase(lowerOffset: -5, upperOffset: -2)
                == "2–5 days ago"
        )
    }

    @Test("presentation is deterministic for identical forecasts")
    func deterministicPresentation() throws {
        let cycles = Self.cycles(startingAt: 20300, lengths: [28, 30, 27])
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles, profile: UserProfile(), today: DayNumber(20400)
        )
        let first = ForecastIntervalPresentation(
            window: forecast.nextPeriod, today: DayNumber(20400)
        )
        let second = ForecastIntervalPresentation(
            window: forecast.nextPeriod, today: DayNumber(20400)
        )
        #expect(first == second)
    }
}
