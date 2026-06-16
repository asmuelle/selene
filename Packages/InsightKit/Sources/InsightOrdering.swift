import CycleEngine
import SeleneCore

/// A surface the Today view can show, in priority order. Pure descriptor — the
/// app maps each to a real view. Ordering is the perimenopause-funnel behaviour
/// under test; it never changes any engine number, only what leads.
public enum TodaySurface: Hashable, Sendable {
    case forecastWheel
    case perimenopauseSymptomReport
    case symptomClusterReport
    case cycleNarrative
    case groundedQA
    case doctorVisitPrompt
}

/// Orders Today surfaces for a profile.
///
/// In perimenopause mode the perimenopause-relevant surfaces lead (the wedge);
/// in cycle / TTC mode the forecast wheel and cycle narrative lead. Deterministic
/// and pure — same profile in, same order out.
public enum InsightOrdering {
    public static func surfaces(
        for profile: UserProfile,
        hasRecentPerimenopauseSymptoms: Bool = false
    ) -> [TodaySurface] {
        switch profile.mode {
        case .perimenopause:
            perimenopauseOrder
        case .cycle, .tryingToConceive:
            standardOrder(boostPerimenopause: hasRecentPerimenopauseSymptoms)
        }
    }

    /// Convenience over the store-derived signal: are any perimenopause symptoms
    /// in the recent cluster table? Drives a soft boost in non-perimenopause modes.
    public static func surfaces(
        for profile: UserProfile,
        recentClusters: [SymptomClusterRow]
    ) -> [TodaySurface] {
        let hasPerimenopauseSignal = recentClusters.contains { $0.code.isPerimenopauseSymptom }
        return surfaces(for: profile, hasRecentPerimenopauseSymptoms: hasPerimenopauseSignal)
    }

    // MARK: - Private

    private static let perimenopauseOrder: [TodaySurface] = [
        .perimenopauseSymptomReport,
        .symptomClusterReport,
        .doctorVisitPrompt,
        .forecastWheel,
        .cycleNarrative,
        .groundedQA,
    ]

    private static func standardOrder(boostPerimenopause: Bool) -> [TodaySurface] {
        var order: [TodaySurface] = [
            .forecastWheel,
            .cycleNarrative,
            .symptomClusterReport,
            .groundedQA,
            .doctorVisitPrompt,
        ]
        if boostPerimenopause {
            order.insert(.perimenopauseSymptomReport, at: 2)
        }
        return order
    }
}
