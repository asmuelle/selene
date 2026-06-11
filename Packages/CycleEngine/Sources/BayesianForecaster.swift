import SeleneCore

/// Errors the forecaster can produce. Explicit, typed, and user-mappable.
public enum ForecastError: Error, Equatable, Sendable {
    /// No cycle start has ever been logged — there is nothing to anchor a forecast to.
    case noCycleHistory
}

/// Deterministic hierarchical Bayesian cycle forecaster.
///
/// Every date, probability, and credible interval in the product originates here
/// (invariant #3: deterministic before LLM). Pure functions over value types, fixed
/// closed-form math — identical inputs produce bit-identical `Forecast`s.
///
/// Model: cycle lengths ~ Normal(μ, σ²) with a Normal-Inverse-Gamma conjugate prior.
/// The posterior predictive for the next cycle length is a Student-t, whose quantiles
/// give honest credible intervals — perimenopause mode widens them via its prior.
public enum BayesianForecaster {
    public static let engineVersion = "cycle-engine/1.0.0"

    /// Nested credible-interval levels rendered as wheel arcs.
    public static let credibleLevels: [Double] = [0.5, 0.8, 0.95]

    /// Mean luteal phase length in days (ovulation precedes the next period by this).
    public static let lutealMeanDays = 14.0

    /// Extra day-level spread of the luteal phase, combined into the ovulation window.
    public static let lutealSDDays = 1.5

    /// Produces a forecast from detected cycles and the user profile.
    ///
    /// - Parameters:
    ///   - cycles: output of `CycleDetector`; anomalous and open cycles are excluded
    ///     from the likelihood, but the latest start anchors the prediction.
    ///   - profile: tracking mode + optional typical-length prior recentering.
    ///   - today: generation day, recorded on the forecast.
    ///   - seed: recorded for reproducibility audits (no randomness is used in v1).
    public static func forecast(
        cycles: [Cycle],
        profile: UserProfile,
        today: DayNumber,
        seed: UInt64 = 0
    ) throws(ForecastError) -> Forecast {
        guard let anchor = cycles.map(\.startDay).max() else {
            throw .noCycleHistory
        }

        let usable = usableCycles(in: cycles)
        let lengths = usable.compactMap(\.length).map(Double.init)
        let priors = CyclePriors.priors(
            for: profile.mode,
            typicalCycleLength: profile.typicalCycleLengthPrior
        )
        let posterior = posteriorUpdate(priors: priors, lengths: lengths)

        let degreesOfFreedom = 2 * posterior.alpha
        let predictiveScale = (
            posterior.beta * (posterior.kappa + 1) / (posterior.alpha * posterior.kappa)
        ).squareRoot()

        let periodMedianDay = Double(anchor.value) + posterior.mu
        let nextPeriod = window(
            medianDay: periodMedianDay,
            scale: predictiveScale,
            degreesOfFreedom: degreesOfFreedom
        )

        let ovulationScale = (predictiveScale * predictiveScale + lutealSDDays * lutealSDDays)
            .squareRoot()
        let ovulation = window(
            medianDay: periodMedianDay - lutealMeanDays,
            scale: ovulationScale,
            degreesOfFreedom: degreesOfFreedom
        )

        return Forecast(
            id: deterministicForecastID(anchor: anchor, today: today, seed: seed),
            generatedAtDay: today,
            engineVersion: engineVersion,
            mode: profile.mode,
            nextPeriod: nextPeriod,
            ovulation: ovulation,
            posterior: posterior,
            inputRange: inputRange(of: usable),
            cycleCount: lengths.count,
            seed: seed
        )
    }

    // MARK: - Model internals (exposed for direct unit testing)

    /// Conjugate Normal-Inverse-Gamma update with observed cycle lengths.
    public static func posteriorUpdate(
        priors: CyclePriors,
        lengths: [Double]
    ) -> PosteriorSnapshot {
        let n = Double(lengths.count)
        guard n > 0 else {
            return PosteriorSnapshot(
                mu: priors.mu0, kappa: priors.kappa0, alpha: priors.alpha0, beta: priors.beta0
            )
        }
        let mean = lengths.reduce(0, +) / n
        let sumSquares = lengths.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        let kappaN = priors.kappa0 + n
        let muN = (priors.kappa0 * priors.mu0 + n * mean) / kappaN
        let alphaN = priors.alpha0 + n / 2
        let meanShift = mean - priors.mu0
        let betaN = priors.beta0 + sumSquares / 2
            + priors.kappa0 * n * meanShift * meanShift / (2 * kappaN)
        return PosteriorSnapshot(mu: muN, kappa: kappaN, alpha: alphaN, beta: betaN)
    }

    /// Builds the nested credible intervals of a Student-t predictive window.
    public static func window(
        medianDay: Double,
        scale: Double,
        degreesOfFreedom: Double
    ) -> ForecastWindow {
        let intervals = credibleLevels.map { level in
            let halfWidth = StatFunctions.studentTQuantile(
                0.5 + level / 2, df: degreesOfFreedom
            ) * scale
            return CredibleInterval(
                level: level,
                lowerDay: medianDay - halfWidth,
                upperDay: medianDay + halfWidth
            )
        }
        return ForecastWindow(medianDay: medianDay, intervals: intervals)
    }

    // MARK: - Private

    private static func usableCycles(in cycles: [Cycle]) -> [Cycle] {
        cycles
            .filter { $0.endDay != nil && !$0.isAnomalous }
            .sorted { $0.startDay < $1.startDay }
    }

    private static func inputRange(of usable: [Cycle]) -> ClosedRange<DayNumber>? {
        guard let first = usable.first?.startDay, let last = usable.last?.startDay else {
            return nil
        }
        return first ... last
    }

    /// Forecast ids are derived from (anchor, today, seed) so identical runs yield
    /// identical values — required for the bit-reproducibility guarantee.
    private static func deterministicForecastID(
        anchor: DayNumber,
        today: DayNumber,
        seed: UInt64
    ) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        write(UInt64(bitPattern: Int64(anchor.value)), into: &bytes, at: 0)
        write(UInt64(bitPattern: Int64(today.value)) ^ seed, into: &bytes, at: 8)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func write(_ value: UInt64, into bytes: inout [UInt8], at offset: Int) {
        for index in 0 ..< 8 {
            bytes[offset + index] = UInt8((value >> (8 * UInt64(index))) & 0xFF)
        }
    }
}

import struct Foundation.UUID
