import Foundation

/// A calendar day expressed as whole days since 1970-01-01 in UTC.
///
/// All engine math operates on `DayNumber` instead of `Date` so that forecasts are
/// bit-reproducible regardless of device time zone or daylight-saving transitions.
/// Conversion to `Date` happens only at the UI boundary.
public struct DayNumber: Hashable, Comparable, Codable, Sendable {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    public static func < (lhs: DayNumber, rhs: DayNumber) -> Bool {
        lhs.value < rhs.value
    }

    /// Whole days from `self` to `other` (positive when `other` is later).
    public func distance(to other: DayNumber) -> Int {
        other.value - value
    }

    public func advanced(by days: Int) -> DayNumber {
        DayNumber(value + days)
    }
}

public extension DayNumber {
    /// The fixed UTC Gregorian calendar used for every day/date conversion.
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static let secondsPerDay = 86400.0

    /// Creates a day number from a `Date`, truncating to the UTC day boundary.
    init(date: Date) {
        let startOfDay = Self.utcCalendar.startOfDay(for: date)
        self.init(Int((startOfDay.timeIntervalSince1970 / Self.secondsPerDay).rounded(.down)))
    }

    /// Midnight UTC of this day.
    var dateValue: Date {
        Date(timeIntervalSince1970: Double(value) * Self.secondsPerDay)
    }
}
