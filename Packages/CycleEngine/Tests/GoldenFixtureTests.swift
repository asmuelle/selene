@testable import CycleEngine
import Foundation
import SeleneCore
import Testing

/// Golden-fixture contract: each fixture holds a synthetic flow history plus the
/// exact bit patterns of every number the engine must produce for it. Any change
/// to engine math fails these tests until the fixtures are deliberately
/// re-recorded (run with SELENE_RECORD_GOLDEN=1, then review the diff).
@Suite("Golden fixtures")
struct GoldenFixtureTests {
    static let fixtureNames = ["regular", "irregular", "perimenopausal"]

    @Test("engine reproduces golden forecasts bit-identically", arguments: fixtureNames)
    func goldenForecast(name: String) throws {
        // Arrange
        let fixture = try GoldenFixture.load(named: name)
        let logs = fixture.dailyLogs
        let profile = UserProfile(
            mode: fixture.trackingMode,
            typicalCycleLengthPrior: fixture.typicalCycleLengthPrior
        )

        // Act
        let cycles = CycleDetector.detectCycles(from: logs)
        let forecast = try BayesianForecaster.forecast(
            cycles: cycles,
            profile: profile,
            today: DayNumber(fixture.todayDay),
            seed: fixture.seed
        )

        // Assert — record mode rewrites the fixture instead of asserting.
        if GoldenFixture.isRecording {
            try GoldenFixture.record(fixture: fixture, forecast: forecast, named: name)
            return
        }
        let expected = try #require(fixture.expected, "fixture \(name) has no expected block")
        expected.assertMatches(forecast)
    }

    @Test("fixtures cover all three tracking situations")
    func fixtureCoverage() throws {
        let modes = try Self.fixtureNames
            .map { try GoldenFixture.load(named: $0).trackingMode }
        #expect(modes.contains(.cycle))
        #expect(modes.contains(.perimenopause))
    }
}

// MARK: - Fixture model

struct GoldenFixture: Codable {
    struct FlowDay: Codable {
        let day: Int
        let flow: String
    }

    struct ExpectedInterval: Codable {
        let level: Double
        let lowerBits: String
        let upperBits: String
        let lowerApprox: Double
        let upperApprox: Double
    }

    struct ExpectedWindow: Codable {
        let medianBits: String
        let medianApprox: Double
        let intervals: [ExpectedInterval]

        func assertMatches(_ window: ForecastWindow, label: String) {
            #expect(
                window.medianDay.bitPattern == UInt64(medianBits),
                "\(label) median drifted: \(window.medianDay) vs approx \(medianApprox)"
            )
            #expect(window.intervals.count == intervals.count)
            for (actual, expected) in zip(window.intervals, intervals) {
                #expect(actual.level == expected.level)
                #expect(
                    actual.lowerDay.bitPattern == UInt64(expected.lowerBits),
                    "\(label) \(expected.level) lower drifted"
                )
                #expect(
                    actual.upperDay.bitPattern == UInt64(expected.upperBits),
                    "\(label) \(expected.level) upper drifted"
                )
            }
        }
    }

    struct Expected: Codable {
        let engineVersion: String
        let forecastID: String
        let cycleCount: Int
        let inputRangeStart: Int?
        let inputRangeEnd: Int?
        let posteriorMuBits: String
        let posteriorKappaBits: String
        let posteriorAlphaBits: String
        let posteriorBetaBits: String
        let nextPeriod: ExpectedWindow
        let ovulation: ExpectedWindow

        func assertMatches(_ forecast: Forecast) {
            #expect(forecast.engineVersion == engineVersion)
            #expect(forecast.id.uuidString == forecastID)
            #expect(forecast.cycleCount == cycleCount)
            #expect(forecast.inputRange?.lowerBound.value == inputRangeStart)
            #expect(forecast.inputRange?.upperBound.value == inputRangeEnd)
            #expect(forecast.posterior.mu.bitPattern == UInt64(posteriorMuBits))
            #expect(forecast.posterior.kappa.bitPattern == UInt64(posteriorKappaBits))
            #expect(forecast.posterior.alpha.bitPattern == UInt64(posteriorAlphaBits))
            #expect(forecast.posterior.beta.bitPattern == UInt64(posteriorBetaBits))
            nextPeriod.assertMatches(forecast.nextPeriod, label: "nextPeriod")
            ovulation.assertMatches(forecast.ovulation, label: "ovulation")
        }
    }

    let name: String
    let mode: String
    let todayDay: Int
    let seed: UInt64
    let typicalCycleLengthPrior: Double?
    let flowDays: [FlowDay]
    var expected: Expected?

    var trackingMode: TrackingMode {
        TrackingMode(rawValue: mode) ?? .cycle
    }

    var dailyLogs: [DailyLog] {
        flowDays.map {
            DailyLog(day: DayNumber($0.day), flow: FlowLevel(rawValue: $0.flow))
        }
    }

    // MARK: Loading & recording

    static var isRecording: Bool {
        ProcessInfo.processInfo.environment["SELENE_RECORD_GOLDEN"] == "1"
    }

    static func load(named name: String) throws -> GoldenFixture {
        let url = try fixtureURL(named: name)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(GoldenFixture.self, from: data)
    }

    /// Resolves the fixture from the test bundle resources; in record mode it
    /// resolves the repo source path instead so updates land in git.
    static func fixtureURL(named name: String) throws -> URL {
        if isRecording { return sourceFixtureURL(named: name) }
        guard let url = Bundle.module.url(
            forResource: name, withExtension: "json", subdirectory: "Fixtures"
        ) else {
            throw FixtureError.missing(name)
        }
        return url
    }

    static func sourceFixtureURL(named name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name).json")
    }

    static func record(fixture: GoldenFixture, forecast: Forecast, named name: String) throws {
        var updated = fixture
        updated.expected = Expected(forecast: forecast)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updated).write(to: sourceFixtureURL(named: name))
    }

    enum FixtureError: Error {
        case missing(String)
    }
}

extension GoldenFixture.Expected {
    init(forecast: Forecast) {
        self.init(
            engineVersion: forecast.engineVersion,
            forecastID: forecast.id.uuidString,
            cycleCount: forecast.cycleCount,
            inputRangeStart: forecast.inputRange?.lowerBound.value,
            inputRangeEnd: forecast.inputRange?.upperBound.value,
            posteriorMuBits: String(forecast.posterior.mu.bitPattern),
            posteriorKappaBits: String(forecast.posterior.kappa.bitPattern),
            posteriorAlphaBits: String(forecast.posterior.alpha.bitPattern),
            posteriorBetaBits: String(forecast.posterior.beta.bitPattern),
            nextPeriod: GoldenFixture.ExpectedWindow(window: forecast.nextPeriod),
            ovulation: GoldenFixture.ExpectedWindow(window: forecast.ovulation)
        )
    }
}

extension GoldenFixture.ExpectedWindow {
    init(window: ForecastWindow) {
        self.init(
            medianBits: String(window.medianDay.bitPattern),
            medianApprox: window.medianDay,
            intervals: window.intervals.map { interval in
                GoldenFixture.ExpectedInterval(
                    level: interval.level,
                    lowerBits: String(interval.lowerDay.bitPattern),
                    upperBits: String(interval.upperDay.bitPattern),
                    lowerApprox: interval.lowerDay,
                    upperApprox: interval.upperDay
                )
            }
        )
    }
}
