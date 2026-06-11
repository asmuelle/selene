@testable import CycleEngine
import SeleneCore
import Testing

@Suite("BayesianForecaster")
struct BayesianForecasterTests {
    private func closedCycles(lengths: [Int], firstStart: Int = 20000) -> [Cycle] {
        var cycles: [Cycle] = []
        var start = firstStart
        for length in lengths {
            cycles.append(Cycle(startDay: DayNumber(start), endDay: DayNumber(start + length)))
            start += length
        }
        cycles.append(Cycle(startDay: DayNumber(start)))
        return cycles
    }

    @Test("forecasting with no history throws a typed error")
    func noHistoryThrows() {
        #expect(throws: ForecastError.noCycleHistory) {
            try BayesianForecaster.forecast(
                cycles: [], profile: UserProfile(), today: DayNumber(20600)
            )
        }
    }

    @Test("posterior update with no data returns the prior unchanged")
    func priorOnlyPosterior() {
        // Arrange
        let priors = CyclePriors.cycle

        // Act
        let posterior = BayesianForecaster.posteriorUpdate(priors: priors, lengths: [])

        // Assert
        #expect(posterior.mu == priors.mu0)
        #expect(posterior.kappa == priors.kappa0)
        #expect(posterior.alpha == priors.alpha0)
        #expect(posterior.beta == priors.beta0)
    }

    @Test("posterior mean moves toward the data as evidence accumulates")
    func posteriorMeanShrinksTowardData() {
        // Arrange: user runs consistently long 32-day cycles.
        let few = BayesianForecaster.posteriorUpdate(priors: .cycle, lengths: [32, 32])
        let many = BayesianForecaster.posteriorUpdate(
            priors: .cycle, lengths: Array(repeating: 32.0, count: 12)
        )

        // Assert: both pulled above the 28-day prior, more data pulls harder.
        #expect(few.mu > 28)
        #expect(many.mu > few.mu)
        #expect(many.mu < 32.0001)
    }

    @Test("a regular history yields a forecast centered one mean length after the anchor")
    func regularHistoryForecast() throws {
        // Arrange
        let cycles = closedCycles(lengths: [28, 28, 28, 28, 28])
        let anchor = try #require(cycles.map(\.startDay).max())

        // Act
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles, profile: UserProfile(), today: anchor.advanced(by: 10)
        )

        // Assert
        #expect(abs(forecast.nextPeriod.medianDay - (Double(anchor.value) + 28)) < 0.01)
        #expect(forecast.cycleCount == 5)
        #expect(forecast.engineVersion == BayesianForecaster.engineVersion)
        // Ovulation precedes the predicted period by the luteal constant.
        let gap = forecast.nextPeriod.medianDay - forecast.ovulation.medianDay
        #expect(abs(gap - BayesianForecaster.lutealMeanDays) < 1e-12)
    }

    @Test("credible intervals are nested and ordered 50 < 80 < 95")
    func intervalsAreNested() throws {
        // Arrange
        let cycles = closedCycles(lengths: [27, 29, 28, 30, 26])

        // Act
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles, profile: UserProfile(), today: DayNumber(20200)
        )

        // Assert
        let widths = forecast.nextPeriod.intervals.map(\.widthDays)
        #expect(widths.count == 3)
        #expect(widths[0] < widths[1])
        #expect(widths[1] < widths[2])
        let outer = try #require(forecast.nextPeriod.interval(at: 0.95))
        let inner = try #require(forecast.nextPeriod.interval(at: 0.5))
        #expect(outer.lowerDay < inner.lowerDay)
        #expect(outer.upperDay > inner.upperDay)
    }

    @Test("an irregular history widens the window versus a regular one")
    func irregularityWidensIntervals() throws {
        // Arrange
        let regular = closedCycles(lengths: [28, 28, 28, 28, 28])
        let irregular = closedCycles(lengths: [21, 38, 25, 35, 22])

        // Act
        let regularForecast = try BayesianForecaster.forecast(
            cycles: regular, profile: UserProfile(), today: DayNumber(20200)
        )
        let irregularForecast = try BayesianForecaster.forecast(
            cycles: irregular, profile: UserProfile(), today: DayNumber(20200)
        )

        // Assert
        let regularWidth = try #require(regularForecast.nextPeriod.interval(at: 0.8)?.widthDays)
        let irregularWidth = try #require(irregularForecast.nextPeriod.interval(at: 0.8)?.widthDays)
        #expect(irregularWidth > regularWidth)
    }

    @Test("perimenopause mode widens the window for the same history")
    func perimenopauseWidensIntervals() throws {
        // Arrange: identical history, different mode.
        let cycles = closedCycles(lengths: [28, 30, 27, 29])

        // Act
        let cycleMode = try BayesianForecaster.forecast(
            cycles: cycles, profile: UserProfile(mode: .cycle), today: DayNumber(20200)
        )
        let periMode = try BayesianForecaster.forecast(
            cycles: cycles, profile: UserProfile(mode: .perimenopause), today: DayNumber(20200)
        )

        // Assert
        let cycleWidth = try #require(cycleMode.nextPeriod.interval(at: 0.8)?.widthDays)
        let periWidth = try #require(periMode.nextPeriod.interval(at: 0.8)?.widthDays)
        #expect(periWidth > cycleWidth)
        #expect(periMode.mode == .perimenopause)
    }

    @Test("anomalous cycles are excluded from the likelihood")
    func anomalousCyclesExcluded() throws {
        // Arrange: clean 28s plus one absurd 120-day cycle flagged anomalous.
        let clean = closedCycles(lengths: [28, 28, 28])
        let polluted = clean + [
            Cycle(startDay: DayNumber(30000), endDay: DayNumber(30120), isAnomalous: true),
        ]

        // Act
        let cleanForecast = try BayesianForecaster.forecast(
            cycles: clean, profile: UserProfile(), today: DayNumber(20200)
        )
        let pollutedForecast = try BayesianForecaster.forecast(
            cycles: polluted, profile: UserProfile(), today: DayNumber(20200)
        )

        // Assert: posterior identical; only the anchor moved.
        #expect(cleanForecast.posterior == pollutedForecast.posterior)
        #expect(pollutedForecast.cycleCount == 3)
    }

    @Test("a single open cycle forecasts from the prior alone")
    func priorOnlyForecast() throws {
        // Arrange: first-ever period logged, nothing closed yet.
        let cycles = [Cycle(startDay: DayNumber(20614))]

        // Act
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles, profile: UserProfile(), today: DayNumber(20616)
        )

        // Assert
        #expect(forecast.cycleCount == 0)
        #expect(forecast.inputRange == nil)
        #expect(abs(forecast.nextPeriod.medianDay - Double(20614 + 28)) < 1e-9)
    }

    @Test("the user's typical-length prior recenters a prior-only forecast")
    func typicalLengthRecentersPrior() throws {
        // Arrange
        let cycles = [Cycle(startDay: DayNumber(20614))]
        let profile = UserProfile(typicalCycleLengthPrior: 31)

        // Act
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles, profile: profile, today: DayNumber(20616)
        )

        // Assert
        #expect(abs(forecast.nextPeriod.medianDay - Double(20614 + 31)) < 1e-9)
    }

    @Test("an implausible typical-length prior is ignored")
    func implausibleTypicalLengthIgnored() {
        let priors = CyclePriors.priors(for: .cycle, typicalCycleLength: 400)
        #expect(priors == .cycle)
    }

    @Test("identical inputs produce bit-identical forecasts including ids")
    func bitIdenticalForecasts() throws {
        // Arrange
        let cycles = closedCycles(lengths: [26, 31, 28, 29])
        let profile = UserProfile(mode: .perimenopause)

        // Act
        let first = try BayesianForecaster.forecast(
            cycles: cycles, profile: profile, today: DayNumber(20200), seed: 7
        )
        let second = try BayesianForecaster.forecast(
            cycles: cycles, profile: profile, today: DayNumber(20200), seed: 7
        )

        // Assert
        #expect(first == second)
        #expect(first.id == second.id)
        #expect(first.nextPeriod.medianDay.bitPattern == second.nextPeriod.medianDay.bitPattern)
    }
}
