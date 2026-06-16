import SeleneCore

/// All standing template copy that appears on the doctor-visit summary.
///
/// This is user-/clinician-facing text on a paywalled artifact, so it is held to
/// the same 1.4.1 / SaMD bar as paywall copy (AGENTS.md invariant #5): no
/// diagnosis, treatment, prevention, or accuracy claims. Every shipped string is
/// enumerated in `allShippedStrings` and scanned by `DoctorVisitCopyTests`.
public enum DoctorVisitCopy {
    public static let documentTitle = "Cycle & symptom summary"

    public static let subtitle =
        "A dated record of your own logs, prepared to share at an appointment."

    /// Standing disclaimer — pinned to the editorial clinician-handoff chunk.
    /// Worded to avoid any claim language (1.4.1 / SaMD line): it describes the
    /// user's own logs and hands interpretation to a clinician.
    public static let disclaimer =
        "Selene describes patterns in your own logged data. It does not interpret "
            + "what they mean. Bring any questions about symptoms or changes to your clinician."

    /// Standing note on the forecast section — pinned to the ovulation/cycle
    /// timing chunk, which itself frames estimates as ranges.
    public static let forecastNote =
        "Forecasts below are ranges of likely days, not single dates. The wider "
            + "the range, the less certain the estimate."

    public static let cycleStatsHeading = "Cycle history"
    public static let symptomHeading = "Symptoms logged in this range"
    public static let forecastHeading = "Current forecast windows"
    public static let nextPeriodTitle = "Next period (likely window)"
    public static let ovulationTitle = "Estimated ovulation window"

    public static let emptyClustersNote = "No symptoms were logged in this date range."
    public static let emptyCyclesNote = "No complete cycles fall in this date range yet."

    /// Citations the standing copy depends on. Every id/anchor here must resolve
    /// in `ContentPack` (asserted by `DoctorVisitCitationTests`).
    public static let standingCitations: [Citation] = [
        Citation(sourceID: "editorial-clinician-001", sectionAnchor: "overview"),
        Citation(sourceID: "acog-ovulation-timing-001", sectionAnchor: "cycle-tracking"),
    ]

    public static let allShippedStrings: [String] = [
        documentTitle, subtitle, disclaimer, forecastNote,
        cycleStatsHeading, symptomHeading, forecastHeading,
        nextPeriodTitle, ovulationTitle, emptyClustersNote, emptyCyclesNote,
    ]
}
