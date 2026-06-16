import CycleEngine
import Foundation
import SeleneCore

/// The rendering seam for a doctor-visit summary.
///
/// The document model is pure and fully tested; rendering to bytes is a thin
/// boundary so the UIKit/ImageRenderer path stays out of `swift test`. The
/// deterministic plain-text renderer carries the unit tests on macOS with no
/// graphics stack; the real PDF renderer is availability-guarded.
public protocol DoctorVisitRendering: Sendable {
    /// Renders the document to a shareable byte blob (PDF for the real renderer,
    /// UTF-8 text for the deterministic test renderer).
    func render(_ document: DoctorVisitDocument) throws -> Data
}

/// Deterministic plain-text renderer: same document in, same bytes out.
///
/// Used by tests and as a guaranteed fallback when no graphics stack exists. The
/// text it emits is built ONLY from the document (which is built only from the
/// store + engine), so it never introduces a value the document did not carry.
public struct PlainTextDoctorVisitRenderer: DoctorVisitRendering {
    public init() {}

    public func render(_ document: DoctorVisitDocument) throws -> Data {
        Data(plainText(document).utf8)
    }

    /// The rendered text. Exposed so tests can assert structure without decoding.
    public func plainText(_ document: DoctorVisitDocument) -> String {
        var lines: [String] = []
        lines.append(DoctorVisitCopy.documentTitle)
        lines.append(DoctorVisitCopy.subtitle)
        lines.append("Range: day \(document.dateRange.lowerBound.value)"
            + " to day \(document.dateRange.upperBound.value)")
        lines.append("")
        lines.append(contentsOf: statsLines(document.stats))
        lines.append("")
        lines.append(contentsOf: symptomLines(document.symptomClusters))
        lines.append("")
        lines.append(contentsOf: forecastLines(document.forecastWindows))
        lines.append("")
        lines.append(DoctorVisitCopy.disclaimer)
        return lines.joined(separator: "\n")
    }

    private func statsLines(_ stats: DocumentCycleStats) -> [String] {
        var lines = [DoctorVisitCopy.cycleStatsHeading]
        guard stats.cycleCount > 0, let mean = stats.meanLengthDays else {
            lines.append(DoctorVisitCopy.emptyCyclesNote)
            return lines
        }
        lines.append("Complete cycles: \(stats.cycleCount)")
        lines.append("Mean length: \(formatted(mean)) days")
        if let shortest = stats.shortestLengthDays, let longest = stats.longestLengthDays {
            lines.append("Range: \(shortest)–\(longest) days")
        }
        return lines
    }

    private func symptomLines(_ clusters: [SymptomClusterRow]) -> [String] {
        var lines = [DoctorVisitCopy.symptomHeading]
        guard !clusters.isEmpty else {
            lines.append(DoctorVisitCopy.emptyClustersNote)
            return lines
        }
        for row in clusters {
            lines.append("\(row.code.label): \(row.dayCount) day(s)"
                + ", mean severity \(formatted(row.meanSeverity))"
                + ", peak \(row.peakSeverity.value)")
        }
        return lines
    }

    private func forecastLines(_ windows: [DocumentForecastWindow]) -> [String] {
        var lines = [DoctorVisitCopy.forecastHeading, DoctorVisitCopy.forecastNote]
        guard !windows.isEmpty else {
            return lines
        }
        for window in windows {
            lines.append(window.title)
            lines.append("  median: day \(formatted(window.medianDay))")
            for interval in window.intervals {
                let pct = Int((interval.level * 100).rounded())
                lines.append("  \(pct)% window: day \(formatted(interval.lowerDay))"
                    + " to day \(formatted(interval.upperDay))")
            }
        }
        return lines
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
