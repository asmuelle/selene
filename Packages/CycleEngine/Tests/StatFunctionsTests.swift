@testable import CycleEngine
import Testing

@Suite("StatFunctions")
struct StatFunctionsTests {
    @Test("logGamma matches known values")
    func logGammaKnownValues() {
        // Γ(1) = 1, Γ(2) = 1, Γ(5) = 24, Γ(0.5) = √π
        #expect(abs(StatFunctions.logGamma(1)) < 1e-12)
        #expect(abs(StatFunctions.logGamma(2)) < 1e-12)
        #expect(abs(StatFunctions.logGamma(5) - 3.1780538303479458) < 1e-12)
        #expect(abs(StatFunctions.logGamma(0.5) - 0.5723649429247001) < 1e-12)
    }

    @Test("logGamma small-argument reflection branch matches reference values")
    func logGammaReflectionBranch() {
        // Reference values from C lgamma (x < 0.5 exercises the reflection formula).
        #expect(abs(StatFunctions.logGamma(0.3) - 1.0957979948180754) < 1e-10)
        #expect(abs(StatFunctions.logGamma(0.05) - 2.968879201051731) < 1e-10)
    }

    @Test("regularized incomplete beta hits boundary and symmetric values")
    func incompleteBetaValues() {
        #expect(StatFunctions.regularizedIncompleteBeta(a: 2, b: 3, x: 0) == 0)
        #expect(StatFunctions.regularizedIncompleteBeta(a: 2, b: 3, x: 1) == 1)
        // I_0.5(a, a) = 0.5 by symmetry.
        #expect(abs(StatFunctions.regularizedIncompleteBeta(a: 4, b: 4, x: 0.5) - 0.5) < 1e-12)
        // I_x(1, 1) = x (uniform CDF).
        #expect(abs(StatFunctions.regularizedIncompleteBeta(a: 1, b: 1, x: 0.3) - 0.3) < 1e-12)
    }

    @Test("student t CDF matches reference values")
    func studentTCDFReference() {
        // df = 1 (Cauchy): CDF(1) = 0.75.
        #expect(abs(StatFunctions.studentTCDF(1, df: 1) - 0.75) < 1e-10)
        // Symmetry around zero.
        #expect(abs(StatFunctions.studentTCDF(0, df: 7) - 0.5) < 1e-15)
        let upper = StatFunctions.studentTCDF(1.5, df: 7)
        let lower = StatFunctions.studentTCDF(-1.5, df: 7)
        #expect(abs(upper + lower - 1) < 1e-12)
        // df = 10, t = 2.228 ≈ 97.5th percentile (classic table value).
        #expect(abs(StatFunctions.studentTCDF(2.228, df: 10) - 0.975) < 5e-4)
    }

    @Test("quantile inverts the CDF", arguments: [0.05, 0.25, 0.5, 0.75, 0.9, 0.975])
    func quantileInvertsCDF(p: Double) {
        let df = 9.0
        let t = StatFunctions.studentTQuantile(p, df: df)
        #expect(abs(StatFunctions.studentTCDF(t, df: df) - p) < 1e-9)
    }

    @Test("quantile is antisymmetric")
    func quantileAntisymmetry() {
        let upper = StatFunctions.studentTQuantile(0.9, df: 5)
        let lower = StatFunctions.studentTQuantile(0.1, df: 5)
        #expect(abs(upper + lower) < 1e-12)
        #expect(upper > 0)
    }

    @Test("repeated evaluation is bit-identical")
    func bitReproducibility() {
        let first = StatFunctions.studentTQuantile(0.9, df: 12.34)
        let second = StatFunctions.studentTQuantile(0.9, df: 12.34)
        #expect(first.bitPattern == second.bitPattern)
    }
}
