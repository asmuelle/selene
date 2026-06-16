import SeleneCore

/// One symptom's frequency/severity profile over a date range. Pure aggregation
/// of logged `SymptomEvent`s — no inference, no model, no fabricated values
/// (invariant #3: every number the product shows originates in deterministic
/// code or `CycleEngine`).
public struct SymptomClusterRow: Hashable, Sendable {
    public let code: SymptomCode
    /// Number of distinct days the symptom was logged in range.
    public let dayCount: Int
    /// Total occurrences (a day can carry the symptom once).
    public let occurrences: Int
    /// Mean severity over the occurrences, on the fixed 1...4 scale.
    public let meanSeverity: Double
    /// Peak severity seen in range.
    public let peakSeverity: Severity

    public init(
        code: SymptomCode,
        dayCount: Int,
        occurrences: Int,
        meanSeverity: Double,
        peakSeverity: Severity
    ) {
        self.code = code
        self.dayCount = dayCount
        self.occurrences = occurrences
        self.meanSeverity = meanSeverity
        self.peakSeverity = peakSeverity
    }
}

/// Deterministic symptom-cluster aggregation over a day range.
///
/// Same events in, same table out — sorted by occurrences (desc), then mean
/// severity (desc), then taxonomy order (stable) so the table is reproducible.
/// Perimenopause symptoms can be surfaced first for the wedge.
public enum SymptomClusterAnalyzer {
    /// Aggregates symptom events that fall within `range` (inclusive) into a
    /// reproducible cluster table.
    public static func clusters(
        from events: [SymptomEvent],
        in range: ClosedRange<DayNumber>
    ) -> [SymptomClusterRow] {
        let inRange = events.filter { range.contains($0.day) }
        let grouped = Dictionary(grouping: inRange, by: \.code)
        return grouped
            .map { code, codeEvents in row(code: code, events: codeEvents) }
            .sorted(by: ranking)
    }

    /// The perimenopause-relevant subset of the cluster table, preserving the
    /// same ordering — the doctor-visit highlight for the 35–55 wedge.
    public static func perimenopauseClusters(
        from events: [SymptomEvent],
        in range: ClosedRange<DayNumber>
    ) -> [SymptomClusterRow] {
        clusters(from: events, in: range).filter(\.code.isPerimenopauseSymptom)
    }

    // MARK: - Private

    private static func row(code: SymptomCode, events: [SymptomEvent]) -> SymptomClusterRow {
        let days = Set(events.map(\.day))
        let severities = events.map { Double($0.severity.value) }
        let mean = severities.isEmpty ? 0 : severities.reduce(0, +) / Double(severities.count)
        let peak = events.map(\.severity).max() ?? .mild
        return SymptomClusterRow(
            code: code,
            dayCount: days.count,
            occurrences: events.count,
            meanSeverity: mean,
            peakSeverity: peak
        )
    }

    private static func ranking(_ lhs: SymptomClusterRow, _ rhs: SymptomClusterRow) -> Bool {
        if lhs.occurrences != rhs.occurrences {
            return lhs.occurrences > rhs.occurrences
        }
        if lhs.meanSeverity != rhs.meanSeverity {
            return lhs.meanSeverity > rhs.meanSeverity
        }
        return taxonomyIndex(lhs.code) < taxonomyIndex(rhs.code)
    }

    private static func taxonomyIndex(_ code: SymptomCode) -> Int {
        SymptomCode.allCases.firstIndex(of: code) ?? .max
    }
}
