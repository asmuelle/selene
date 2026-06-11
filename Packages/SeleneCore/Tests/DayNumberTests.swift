import Foundation
@testable import SeleneCore
import Testing

@Suite("DayNumber")
struct DayNumberTests {
    @Test("epoch date maps to day zero")
    func epochIsDayZero() {
        // Arrange
        let epoch = Date(timeIntervalSince1970: 0)

        // Act
        let day = DayNumber(date: epoch)

        // Assert
        #expect(day == DayNumber(0))
    }

    @Test("mid-day timestamps truncate to the same UTC day")
    func midDayTruncatesToUTCDay() {
        // Arrange: 2026-06-10T15:30:00Z = 20614 days + 15.5h after epoch
        let timestamp = Date(timeIntervalSince1970: 20614 * 86400 + 15 * 3600 + 1800)

        // Act
        let day = DayNumber(date: timestamp)

        // Assert
        #expect(day.value == 20614)
        #expect(day.dateValue == Date(timeIntervalSince1970: 20614 * 86400))
    }

    @Test("distance and advance are inverse operations")
    func distanceAndAdvanceRoundTrip() {
        // Arrange
        let start = DayNumber(100)

        // Act
        let later = start.advanced(by: 28)

        // Assert
        #expect(start.distance(to: later) == 28)
        #expect(later.distance(to: start) == -28)
    }

    @Test("comparable ordering follows day value")
    func comparableOrdering() {
        #expect(DayNumber(5) < DayNumber(6))
        #expect(!(DayNumber(6) < DayNumber(6)))
    }

    @Test("codable round-trip preserves value")
    func codableRoundTrip() throws {
        // Arrange
        let original = DayNumber(20614)

        // Act
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DayNumber.self, from: data)

        // Assert
        #expect(decoded == original)
    }
}

@Suite("Symptom taxonomy")
struct SymptomTaxonomyTests {
    @Test("perimenopause set is a strict subset of all codes")
    func perimenopauseSetIsSubset() {
        let all = Set(SymptomCode.allCases)
        #expect(SymptomCode.perimenopauseSet.isSubset(of: all))
        #expect(SymptomCode.perimenopauseSet.count < all.count)
    }

    @Test("hot flashes belong to the perimenopause set, cramps do not")
    func perimenopauseMembership() {
        #expect(SymptomCode.hotFlashes.isPerimenopauseSymptom)
        #expect(!SymptomCode.cramps.isPerimenopauseSymptom)
    }

    @Test("every code has a non-empty label")
    func labelsAreNonEmpty() {
        for code in SymptomCode.allCases {
            #expect(!code.label.isEmpty)
        }
    }

    @Test("severity rejects values outside 1...4")
    func severityValidatesRange() {
        #expect(Severity(0) == nil)
        #expect(Severity(5) == nil)
        #expect(Severity(1)?.value == 1)
        #expect(Severity(4)?.value == 4)
    }

    @Test("severity orders by value")
    func severityOrdering() {
        #expect(Severity.mild < Severity.severe)
    }
}

@Suite("Entities")
struct EntityTests {
    @Test("spotting is not period flow, all other levels are")
    func spottingIsNotPeriodFlow() {
        #expect(!FlowLevel.spotting.isPeriodFlow)
        #expect(FlowLevel.light.isPeriodFlow)
        #expect(FlowLevel.medium.isPeriodFlow)
        #expect(FlowLevel.heavy.isPeriodFlow)
    }

    @Test("daily log with(flow:) returns a new value and leaves the original untouched")
    func dailyLogImmutableUpdate() {
        // Arrange
        let original = DailyLog(day: DayNumber(10), flow: .light)

        // Act
        let updated = original.with(flow: .heavy)

        // Assert
        #expect(original.flow == .light)
        #expect(updated.flow == .heavy)
        #expect(updated.id == original.id)
        #expect(updated.day == original.day)
    }

    @Test("open cycle has no length, closed cycle reports start-to-end days")
    func cycleLength() {
        let open = Cycle(startDay: DayNumber(100))
        let closed = Cycle(startDay: DayNumber(100), endDay: DayNumber(128))
        #expect(open.length == nil)
        #expect(closed.length == 28)
    }

    @Test("user profile holds no identity fields, only local preferences")
    func userProfileDefaults() {
        let profile = UserProfile()
        #expect(profile.mode == .cycle)
        #expect(profile.typicalCycleLengthPrior == nil)
        #expect(!profile.hasSeenBackupGuidance)
    }
}

@Suite("Forecast types")
struct ForecastTypeTests {
    @Test("credible interval width and conservative day range")
    func intervalWidthAndRange() {
        // Arrange
        let interval = CredibleInterval(level: 0.8, lowerDay: 100.3, upperDay: 104.7)

        // Act & Assert
        #expect(abs(interval.widthDays - 4.4) < 1e-9)
        #expect(interval.dayRange == DayNumber(100) ... DayNumber(105))
    }

    @Test("forecast window sorts intervals ascending by level and finds them")
    func windowSortsAndLooksUp() {
        // Arrange
        let window = ForecastWindow(medianDay: 102, intervals: [
            CredibleInterval(level: 0.95, lowerDay: 98, upperDay: 106),
            CredibleInterval(level: 0.5, lowerDay: 101, upperDay: 103),
        ])

        // Act & Assert
        #expect(window.intervals.map(\.level) == [0.5, 0.95])
        #expect(window.interval(at: 0.5)?.lowerDay == 101)
        #expect(window.interval(at: 0.8) == nil)
        #expect(window.medianDayNumber == DayNumber(102))
    }
}
