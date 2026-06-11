import SeleneCore

/// Population-shaped Normal-Inverse-Gamma priors over cycle length.
///
/// These are shipped constants (invariant: no server data ever informs them).
/// Perimenopause mode deliberately widens variance instead of pretending precision.
public struct CyclePriors: Hashable, Sendable {
    /// Prior mean cycle length in days.
    public let mu0: Double
    /// Pseudo-observation count behind the mean.
    public let kappa0: Double
    /// Inverse-gamma shape for cycle-length variance.
    public let alpha0: Double
    /// Inverse-gamma rate for cycle-length variance.
    public let beta0: Double

    public init(mu0: Double, kappa0: Double, alpha0: Double, beta0: Double) {
        self.mu0 = mu0
        self.kappa0 = kappa0
        self.alpha0 = alpha0
        self.beta0 = beta0
    }

    /// Standard cycle prior: mean 28 days, prior sd ≈ 3.5 days (E[σ²] = β/(α−1)).
    public static let cycle = CyclePriors(mu0: 28.0, kappa0: 4.0, alpha0: 3.0, beta0: 24.5)

    /// Perimenopause prior: same center, far wider variance (sd ≈ 5.9 days) and a
    /// weaker mean weight, because irregularity is the expected signal, not noise.
    public static let perimenopause = CyclePriors(mu0: 28.0, kappa0: 1.5, alpha0: 2.2, beta0: 42.0)

    /// Priors for a tracking mode, optionally re-centered on the user's own
    /// typical cycle length (a local preference, never population data).
    public static func priors(for mode: TrackingMode, typicalCycleLength: Double?) -> CyclePriors {
        let base: CyclePriors = switch mode {
        case .cycle, .tryingToConceive: .cycle
        case .perimenopause: .perimenopause
        }
        guard let typical = typicalCycleLength, (15.0 ... 90.0).contains(typical) else {
            return base
        }
        return CyclePriors(mu0: typical, kappa0: base.kappa0, alpha0: base.alpha0, beta0: base.beta0)
    }
}
