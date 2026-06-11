import SeleneCore

/// Narration boundary. Implementations turn engine output into copy; they have
/// read-only access to `Forecast` and can never alter its numbers (invariant #3).
public protocol InsightNarrating: Sendable {
    func narrate(_ forecast: Forecast, today: DayNumber) -> String
}

/// Deterministic template narrator — the permanent fallback behind every LLM
/// surface (invariant #4: grounded or silent; refusals degrade to this, never to
/// an error screen). It states the user's own engine numbers and makes no
/// medical claims, so it needs no citations.
public struct TemplateNarrator: InsightNarrating {
    public init() {}

    public func narrate(_ forecast: Forecast, today: DayNumber) -> String {
        let daysToPeriod = forecast.nextPeriod.medianDayNumber.value - today.value
        let window = forecast.nextPeriod.interval(at: 0.8)
        let windowText = window.map { interval -> String in
            let lower = interval.dayRange.lowerBound.value - today.value
            let upper = interval.dayRange.upperBound.value - today.value
            return " The 80% window spans day \(lower) to day \(upper) from today."
        } ?? ""

        let lead = switch daysToPeriod {
        case ..<0:
            "Your period is past its most likely start (day \(-daysToPeriod) over)."
        case 0:
            "Today is the most likely start of your period."
        default:
            "Your next period is most likely in \(daysToPeriod) days."
        }

        let confidence = confidenceNote(for: forecast)
        return lead + windowText + confidence
    }

    private func confidenceNote(for forecast: Forecast) -> String {
        switch forecast.cycleCount {
        case 0:
            " This is a first estimate — it will sharpen as you log cycles."
        case 1 ... 2:
            " Based on \(forecast.cycleCount) logged cycle(s); expect the window to narrow."
        default:
            " Based on \(forecast.cycleCount) logged cycles."
        }
    }
}
