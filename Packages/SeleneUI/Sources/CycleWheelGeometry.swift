import Foundation
import SeleneCore

/// Pure geometry for the moon-phase cycle wheel.
///
/// Maps cycle days onto ring angles. Day 0 (last period start) sits at the top
/// (12 o'clock) and days advance clockwise. Forecast windows become arcs whose
/// *width is the credible interval* — honest uncertainty as the aesthetic.
/// No SwiftUI here: every number is unit-testable on macOS.
public struct CycleWheelGeometry: Hashable, Sendable {
    /// One rendered uncertainty band.
    public struct Arc: Hashable, Sendable {
        public let level: Double
        public let startAngle: Double
        public let endAngle: Double

        public init(level: Double, startAngle: Double, endAngle: Double) {
            self.level = level
            self.startAngle = startAngle
            self.endAngle = endAngle
        }

        public var sweep: Double {
            endAngle - startAngle
        }
    }

    /// Ring scale in days; clamped to a sane floor so geometry never degenerates.
    public let ringDays: Double
    /// Day-number of the wheel's zero point (the anchoring period start).
    public let anchorDay: DayNumber

    private static let minimumRingDays = 10.0
    private static let topAngle = -Double.pi / 2

    public init(ringDays: Double, anchorDay: DayNumber) {
        self.ringDays = max(ringDays, Self.minimumRingDays)
        self.anchorDay = anchorDay
    }

    /// Builds wheel geometry from a forecast: the ring spans anchor → predicted
    /// period median, so the predicted start lands back at 12 o'clock.
    public init(forecast: Forecast, anchorDay: DayNumber) {
        let span = forecast.nextPeriod.medianDay - Double(anchorDay.value)
        self.init(ringDays: span, anchorDay: anchorDay)
    }

    /// Angle (radians) for a fractional day offset from the anchor.
    /// Offset 0 → top of the wheel; offset == ringDays → full revolution.
    public func angle(forDayOffset offset: Double) -> Double {
        Self.topAngle + (offset / ringDays) * 2 * .pi
    }

    /// Angle for an absolute day number.
    public func angle(for day: DayNumber) -> Double {
        angle(forDayOffset: Double(day.value - anchorDay.value))
    }

    /// Today's marker angle.
    public func todayAngle(today: DayNumber) -> Double {
        angle(for: today)
    }

    /// Uncertainty arcs for a forecast window, widest (95%) first so narrower
    /// bands render on top.
    public func arcs(for window: ForecastWindow) -> [Arc] {
        window.intervals
            .sorted { $0.level > $1.level }
            .map { interval in
                Arc(
                    level: interval.level,
                    startAngle: angle(forDayOffset: interval.lowerDay - Double(anchorDay.value)),
                    endAngle: angle(forDayOffset: interval.upperDay - Double(anchorDay.value))
                )
            }
    }

    /// Fraction (0...1) of the ring covered from anchor to `day`, clamped.
    public func progress(to day: DayNumber) -> Double {
        let raw = Double(day.value - anchorDay.value) / ringDays
        return min(max(raw, 0), 1)
    }
}
