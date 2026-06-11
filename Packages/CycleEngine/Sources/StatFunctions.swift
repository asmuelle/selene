import Foundation

/// Deterministic special functions for the Bayesian engine.
///
/// Everything here is closed-form or fixed-iteration numerics — no randomness, no
/// platform-dependent math beyond IEEE-754 `Double`, so results are bit-reproducible.
public enum StatFunctions {
    /// Lanczos approximation of log(Γ(x)) for x > 0 (g = 7, n = 9).
    public static func logGamma(_ x: Double) -> Double {
        precondition(x > 0, "logGamma requires x > 0")
        let coefficients: [Double] = [
            0.99999999999980993, 676.5203681218851, -1259.1392167224028,
            771.32342877765313, -176.61502916214059, 12.507343278686905,
            -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7,
        ]
        if x < 0.5 {
            // Reflection formula keeps the small-argument branch accurate.
            return log(.pi / sin(.pi * x)) - logGamma(1 - x)
        }
        let z = x - 1
        var sum = coefficients[0]
        for (index, coefficient) in coefficients.enumerated() where index > 0 {
            sum += coefficient / (z + Double(index))
        }
        let t = z + 7.5
        return 0.5 * log(2 * .pi) + (z + 0.5) * log(t) - t + log(sum)
    }

    /// Regularized incomplete beta function I_x(a, b) via Lentz's continued fraction.
    public static func regularizedIncompleteBeta(a: Double, b: Double, x: Double) -> Double {
        precondition(a > 0 && b > 0, "shape parameters must be positive")
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        let logFront = logGamma(a + b) - logGamma(a) - logGamma(b)
            + a * log(x) + b * log(1 - x)
        let front = exp(logFront)
        if x < (a + 1) / (a + b + 2) {
            return front * betaContinuedFraction(a: a, b: b, x: x) / a
        }
        return 1 - front * betaContinuedFraction(a: b, b: a, x: 1 - x) / b
    }

    /// CDF of Student's t distribution with `df` degrees of freedom.
    public static func studentTCDF(_ t: Double, df: Double) -> Double {
        precondition(df > 0, "degrees of freedom must be positive")
        if t == 0 { return 0.5 }
        let x = df / (df + t * t)
        let tail = 0.5 * regularizedIncompleteBeta(a: df / 2, b: 0.5, x: x)
        return t > 0 ? 1 - tail : tail
    }

    /// Quantile of Student's t distribution, by deterministic bisection of the CDF.
    public static func studentTQuantile(_ p: Double, df: Double) -> Double {
        precondition(p > 0 && p < 1, "p must be in (0, 1)")
        precondition(df > 0, "degrees of freedom must be positive")
        if abs(p - 0.5) < 1e-15 { return 0 }
        let target = max(p, 1 - p)
        var hi = 1.0
        var iterations = 0
        while studentTCDF(hi, df: df) < target, iterations < 64 {
            hi *= 2
            iterations += 1
        }
        var lo = 0.0
        for _ in 0 ..< 200 {
            let mid = 0.5 * (lo + hi)
            if studentTCDF(mid, df: df) < target {
                lo = mid
            } else {
                hi = mid
            }
        }
        let magnitude = 0.5 * (lo + hi)
        return p < 0.5 ? -magnitude : magnitude
    }

    // MARK: - Private

    private static func betaContinuedFraction(a: Double, b: Double, x: Double) -> Double {
        let maxIterations = 300
        let epsilon = 3e-16
        let tiny = 1e-300
        let qab = a + b
        let qap = a + 1
        let qam = a - 1
        var c = 1.0
        var d = 1 - qab * x / qap
        if abs(d) < tiny { d = tiny }
        d = 1 / d
        var h = d
        for m in 1 ... maxIterations {
            let dm = Double(m)
            let aa = dm * (b - dm) * x / ((qam + 2 * dm) * (a + 2 * dm))
            d = 1 + aa * d
            if abs(d) < tiny { d = tiny }
            c = 1 + aa / c
            if abs(c) < tiny { c = tiny }
            d = 1 / d
            h *= d * c
            let bb = -(a + dm) * (qab + dm) * x / ((a + 2 * dm) * (qap + 2 * dm))
            d = 1 + bb * d
            if abs(d) < tiny { d = tiny }
            c = 1 + bb / c
            if abs(c) < tiny { c = tiny }
            d = 1 / d
            let delta = d * c
            h *= delta
            if abs(delta - 1) < epsilon { break }
        }
        return h
    }
}
